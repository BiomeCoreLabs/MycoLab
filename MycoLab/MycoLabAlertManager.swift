//
//  MycoLabAlertManager.swift
//  MycoLab
//
//  Created for Real-Time Remote Grow Tent Monitoring & Push Alerting.
//  Evaluates optical hygrometer, sensors, battery & room climate,
//  and dispatches critical alerts to the viewer phone via LiveKit Data Channel & iCloud KVS.
//

import Foundation
import UIKit
import SwiftUI
import UserNotifications
import Combine
import LiveKit

@MainActor
final class MycoLabAlertManager: ObservableObject {
    static let shared = MycoLabAlertManager()
    
    @Published var activeAlerts: [LabAlertRecord] = []
    @Published var latestBannerAlert: LabAlertRecord? = nil
    
    public var isBroadcasterOrStreamDevice: Bool {
        LiveKitStreamManager.shared.currentRole == .broadcaster
        || MycoBackgroundHubManager.shared.isStreamHubRoleActive
        || UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
        || MycoCamStreamManager.shared.role == .host
    }
    
    private var lastDispatchedTimes: [LabAlertCategory: Date] = [:]
    private let dispatchCooldownSeconds: TimeInterval = 3600 // 60 minutes throttle between repetitive notifications
    
    private init() {
        setupCloudKVSListener()
        requestNotificationPermission()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("🔔 [MycoLabAlertManager] Notificatietoestemming verleend.")
            } else if let error = error {
                print("⚠️ [MycoLabAlertManager] Notificatietoestemming geweigerd: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Evaluate Tent Environment Conditions
    func evaluateConditions(
        humidity: Double?,
        temperature: Double?,
        batteryPct: Float?,
        isCharging: Bool,
        store: MycoStore? = nil
    ) {
        let config = store?.db.environmentConfig ?? GrowEnvironmentConfig()
        guard config.enableRemoteAlertNotifications else { return }
        
        // 1. Humidity Check
        if let h = humidity, h > 0 {
            if h < config.minHumidityAlertThresholdPct {
                dispatchAlert(
                    severity: .critical,
                    category: .lowHumidity,
                    title: "🚨 Luchtvochtigheid Te Laag in Tent",
                    message: "Luchtvochtigheid is gedaald naar \(Int(h))% (minimaal ingesteld op \(Int(config.minHumidityAlertThresholdPct))%). Controleer de bevochtiger direct om uitdroging te voorkomen!",
                    currentValue: h,
                    thresholdValue: config.minHumidityAlertThresholdPct,
                    store: store
                )
            } else if h > config.maxHumidityAlertThresholdPct {
                dispatchAlert(
                    severity: .warning,
                    category: .highHumidity,
                    title: "⚠️ Luchtvochtigheid Zeer Hoog",
                    message: "Luchtvochtigheid is \(Int(h))% (maximum \(Int(config.maxHumidityAlertThresholdPct))%). Zorg voor voldoende verse lucht (FAE) om condensdruppels te voorkomen.",
                    currentValue: h,
                    thresholdValue: config.maxHumidityAlertThresholdPct,
                    store: store
                )
            }
        }
        
        // 2. Temperature Check
        if let t = temperature, t > 0 {
            if t > config.maxTempAlertThresholdC {
                dispatchAlert(
                    severity: .critical,
                    category: .highTemperature,
                    title: "🚨 Kweektent Te Warm",
                    message: "Temperatuur is opgelopen naar \(String(format: "%.1f", t))°C (maximaal \(String(format: "%.1f", config.maxTempAlertThresholdC))°C). Schakel ventilatie of koeling in om contaminaties te vermijden.",
                    currentValue: t,
                    thresholdValue: config.maxTempAlertThresholdC,
                    store: store
                )
            } else if t < config.minTempAlertThresholdC {
                dispatchAlert(
                    severity: .warning,
                    category: .lowTemperature,
                    title: "❄️ Kweektent Te Koud",
                    message: "Temperatuur is gezakt naar \(String(format: "%.1f", t))°C (minimaal \(String(format: "%.1f", config.minTempAlertThresholdC))°C). De groei van de paddo's vertraagt.",
                    currentValue: t,
                    thresholdValue: config.minTempAlertThresholdC,
                    store: store
                )
            }
        }
        
        // 3. Camera Battery Check
        if let b = batteryPct, b > 0 && !isCharging {
            let pctInt = Int(b * 100)
            if pctInt <= config.minBatteryAlertThresholdPct {
                dispatchAlert(
                    severity: .critical,
                    category: .lowBattery,
                    title: "⚠️ Kweekcamera Bijna Leeg",
                    message: "De kweektelefoon op het statief heeft nog maar \(pctInt)% batterij en laadt niet op! Sluit de oplader aan om uitval van de livestream te voorkomen.",
                    currentValue: Double(pctInt),
                    thresholdValue: Double(config.minBatteryAlertThresholdPct),
                    store: store
                )
            }
        }
    }
    
    // MARK: - Dispatch Alert
    func dispatchAlert(
        severity: LabAlertSeverity,
        category: LabAlertCategory,
        title: String,
        message: String,
        currentValue: Double? = nil,
        thresholdValue: Double? = nil,
        store: MycoStore? = nil
    ) {
        if let lastSent = lastDispatchedTimes[category], Date().timeIntervalSince(lastSent) < dispatchCooldownSeconds {
            return
        }
        lastDispatchedTimes[category] = Date()
        
        let record = LabAlertRecord(
            severity: severity,
            category: category,
            title: title,
            message: message,
            currentValue: currentValue,
            thresholdValue: thresholdValue
        )
        
        // 1. Show banner & schedule silent notification only on viewer devices (NEVER on stream camera phone)
        if !isBroadcasterOrStreamDevice {
            self.activeAlerts.insert(record, at: 0)
            self.latestBannerAlert = record
            
            // Auto dismiss banner after 6 seconds so user isn't stuck with on-screen banners
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                if self.latestBannerAlert?.id == record.id {
                    withAnimation {
                        self.latestBannerAlert = nil
                    }
                }
            }
            
            scheduleSystemNotification(record: record)
        }
        
        // 2. Broadcast via iCloud KVS for 4G/remote viewers
        if let encoded = try? JSONEncoder().encode(record) {
            MycoKVS.set(encoded, forKey: "MycoLabActiveAlert")
            MycoKVS.set(Date().timeIntervalSince1970, forKey: "MycoLabActiveAlertTimestamp")
            MycoKVS.synchronize()
        }
        
        // 3. Broadcast via LiveKit Data Channel if connected
        Task {
            if let room = LiveKitStreamManager.shared.room, LiveKitStreamManager.shared.isConnected {
                let alertString = "alert:\(category.rawValue):\(severity.rawValue):\(title):\(message)"
                if let data = alertString.data(using: .utf8) {
                    _ = try? await room.localParticipant.publish(data: data, options: DataPublishOptions(topic: "mycolab_alert", reliable: true))
                }
            }
        }
        
        // 4. Save to store alert history
        store?.db.alertHistory.insert(record, at: 0)
        if (store?.db.alertHistory.count ?? 0) > 100 {
            store?.db.alertHistory.removeLast()
        }
        store?.saveImmediately()
    }
    
    // MARK: - Handle Incoming Remote Alert (On Viewer Device)
    func handleIncomingRemoteAlert(_ record: LabAlertRecord, store: MycoStore? = nil) {
        guard !isBroadcasterOrStreamDevice else { return }
        
        if let last = lastDispatchedTimes[record.category], Date().timeIntervalSince(last) < dispatchCooldownSeconds {
            return
        }
        lastDispatchedTimes[record.category] = Date()
        
        self.activeAlerts.insert(record, at: 0)
        self.latestBannerAlert = record
        
        // Auto-dismiss banner after 6 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if self.latestBannerAlert?.id == record.id {
                withAnimation {
                    self.latestBannerAlert = nil
                }
            }
        }
        
        scheduleSystemNotification(record: record)
        
        store?.db.alertHistory.insert(record, at: 0)
        if (store?.db.alertHistory.count ?? 0) > 100 {
            store?.db.alertHistory.removeLast()
        }
        store?.saveImmediately()
    }
    
    private func scheduleSystemNotification(record: LabAlertRecord) {
        guard !isBroadcasterOrStreamDevice else { return }
        let content = UNMutableNotificationContent()
        content.title = record.title
        content.body = record.message
        // Completely silent: user explicitly requested no alert sound effects
        content.sound = nil
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let req = UNNotificationRequest(
            identifier: "alert_\(record.category.rawValue)_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(req)
    }
    
    private func setupCloudKVSListener() {
        guard MycoKVS.isAvailable else { return }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkCloudAlerts()
            }
        }
        checkCloudAlerts()
    }
    
    func checkCloudAlerts() {
        let ts = MycoKVS.double(forKey: "MycoLabActiveAlertTimestamp")
        guard ts > 0 && (Date().timeIntervalSince1970 - ts) < 3600 else { return }
        let lastHandled = UserDefaults.standard.double(forKey: "mycolab_last_handled_cloud_alert")
        guard ts > lastHandled else { return }
        
        if let data = MycoKVS.data(forKey: "MycoLabActiveAlert"),
           let record = try? JSONDecoder().decode(LabAlertRecord.self, from: data) {
            UserDefaults.standard.set(ts, forKey: "mycolab_last_handled_cloud_alert")
            handleIncomingRemoteAlert(record, store: MycoStore.shared)
        }
    }
}
