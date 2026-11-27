//
//  MycoLiveActivityManager.swift
//  MycoLab
//
//  Manages ActivityKit Live Activities for Dynamic Island and Lock Screen.
//

import Foundation
import ActivityKit
import SwiftUI
import Combine

@MainActor
public final class MycoLiveActivityManager: ObservableObject {
    public static let shared = MycoLiveActivityManager()
    
    @Published public private(set) var isActivityActive: Bool = false
    @Published public private(set) var activeTimerTitle: String? = nil
    @Published public private(set) var activeTimerEndDate: Date? = nil
    
    private var currentActivity: Activity<MycoLiveActivityAttributes>?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        listenToTimerNotifications()
    }
    
    private func listenToTimerNotifications() {
        NotificationCenter.default.publisher(for: NSNotification.Name("MycoLabStartLabTimerFromVoice"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notif in
                guard let self = self else { return }
                if let userInfo = notif.userInfo,
                   let minutes = userInfo["minutes"] as? Int,
                   let title = userInfo["title"] as? String {
                    let endDate = Date().addingTimeInterval(Double(minutes * 60))
                    self.startTimerLiveActivity(title: title, endDate: endDate)
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: NSNotification.Name("MycoLabStopLabTimerFromVoice"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.clearActiveTimer()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Start or Update Live Activity
    public func startOrUpdateLiveActivity(
        batchName: String,
        phaseName: String,
        dayCount: Int,
        tempC: Double,
        humidityPct: Double,
        vpdKpa: Double,
        statusSummary: String = "Optimaal Kweekklimaat",
        activeDeviceSummary: String = "Apparaten Standby",
        timerTitle: String? = nil,
        timerEndDate: Date? = nil
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        
        let state = MycoLiveActivityAttributes.ContentState(
            tempC: tempC,
            humidityPct: humidityPct,
            vpdKpa: vpdKpa,
            statusSummary: statusSummary,
            activeDeviceSummary: activeDeviceSummary,
            timerTitle: timerTitle ?? self.activeTimerTitle,
            timerEndDate: timerEndDate ?? self.activeTimerEndDate
        )
        
        if let activity = currentActivity ?? Activity<MycoLiveActivityAttributes>.activities.first {
            self.currentActivity = activity
            Task {
                await activity.update(ActivityContent(state: state, staleDate: nil))
                self.isActivityActive = true
            }
        } else {
            let attributes = MycoLiveActivityAttributes(
                batchName: batchName,
                phaseName: phaseName,
                dayCount: dayCount
            )
            do {
                let activity = try Activity<MycoLiveActivityAttributes>.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
                self.currentActivity = activity
                self.isActivityActive = true
            } catch {
                print("⚠️ [MycoLiveActivityManager] Failed to start Live Activity: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Timer Specific Trigger
    public func startTimerLiveActivity(title: String, endDate: Date) {
        self.activeTimerTitle = title
        self.activeTimerEndDate = endDate
        
        // Sync with existing climate snapshot if available
        let snapshot = MycoWidgetDataManager.shared.loadSnapshot()
        startOrUpdateLiveActivity(
            batchName: snapshot.topBatchName.isEmpty ? "MycoLabs Lab" : snapshot.topBatchName,
            phaseName: snapshot.topBatchPhase,
            dayCount: snapshot.topBatchDaysInPhase,
            tempC: snapshot.temperatureC,
            humidityPct: snapshot.humidityPct,
            vpdKpa: snapshot.vpdKpa,
            statusSummary: "Timer actief: \(title)",
            activeDeviceSummary: "Timer Lopende",
            timerTitle: title,
            timerEndDate: endDate
        )
    }
    
    public func clearActiveTimer() {
        self.activeTimerTitle = nil
        self.activeTimerEndDate = nil
        
        let snapshot = MycoWidgetDataManager.shared.loadSnapshot()
        startOrUpdateLiveActivity(
            batchName: snapshot.topBatchName.isEmpty ? "MycoLabs Lab" : snapshot.topBatchName,
            phaseName: snapshot.topBatchPhase,
            dayCount: snapshot.topBatchDaysInPhase,
            tempC: snapshot.temperatureC,
            humidityPct: snapshot.humidityPct,
            vpdKpa: snapshot.vpdKpa,
            statusSummary: "Optimaal Kweekklimaat",
            activeDeviceSummary: "Apparaten Standby",
            timerTitle: nil,
            timerEndDate: nil
        )
    }
    
    public func endLiveActivity() {
        Task {
            if let activity = currentActivity ?? Activity<MycoLiveActivityAttributes>.activities.first {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            self.currentActivity = nil
            self.isActivityActive = false
            self.activeTimerTitle = nil
            self.activeTimerEndDate = nil
        }
    }
}
