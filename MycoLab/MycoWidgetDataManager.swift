//
//  MycoWidgetDataManager.swift
//  MycoLab
//
//  Created for MycoLab on 03/11/2026.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shared Data Snapshot Model

public struct MycoWidgetSnapshot: Codable {
    public var roomName: String
    public var temperatureC: Double
    public var humidityPct: Double
    public var pressureHpa: Double
    public var co2Ppm: Int
    public var hubActive: Bool
    public var activeBatchCount: Int
    public var topBatchName: String
    public var topBatchStrain: String
    public var topBatchPhase: String
    public var topBatchColonization: Double
    public var topBatchDaysInPhase: Int
    public var topBatchNeedsBS: Bool
    public var topBatchHasPins: Bool
    public var lastUpdated: Date
    public var statusSummary: String
    public var isHumidifierActive: Bool
    public var isExhaustFanActive: Bool
    public var isLightActive: Bool
    public var activeDeviceSummary: String
    public var vpdKpa: Double
    public var vpdZoneTitle: String
    public var isDemoMode: Bool
    public var hasConfiguredCamera: Bool
    public var isCameraConnected: Bool
    public var cameraSnapshotDate: Date?

    public init(
        roomName: String = "Lab Alpha",
        temperatureC: Double = 23.5,
        humidityPct: Double = 91.0,
        pressureHpa: Double = 1013.2,
        co2Ppm: Int = 780,
        hubActive: Bool = true,
        activeBatchCount: Int = 2,
        topBatchName: String = "Batch #04",
        topBatchStrain: String = "Lion's Mane",
        topBatchPhase: String = "Fruiting",
        topBatchColonization: Double = 95.0,
        topBatchDaysInPhase: Int = 5,
        topBatchNeedsBS: Bool = false,
        topBatchHasPins: Bool = true,
        lastUpdated: Date = Date(),
        statusSummary: String = "Klimaat Optimaal",
        isHumidifierActive: Bool = false,
        isExhaustFanActive: Bool = false,
        isLightActive: Bool = false,
        activeDeviceSummary: String = "Ruststand",
        vpdKpa: Double = 0.25,
        vpdZoneTitle: String = "Ideaal",
        isDemoMode: Bool = false,
        hasConfiguredCamera: Bool = false,
        isCameraConnected: Bool = false,
        cameraSnapshotDate: Date? = nil
    ) {
        self.roomName = roomName
        self.temperatureC = temperatureC
        self.humidityPct = humidityPct
        self.pressureHpa = pressureHpa
        self.co2Ppm = co2Ppm
        self.hubActive = hubActive
        self.activeBatchCount = activeBatchCount
        self.topBatchName = topBatchName
        self.topBatchStrain = topBatchStrain
        self.topBatchPhase = topBatchPhase
        self.topBatchColonization = topBatchColonization
        self.topBatchDaysInPhase = topBatchDaysInPhase
        self.topBatchNeedsBS = topBatchNeedsBS
        self.topBatchHasPins = topBatchHasPins
        self.lastUpdated = lastUpdated
        self.statusSummary = statusSummary
        self.isHumidifierActive = isHumidifierActive
        self.isExhaustFanActive = isExhaustFanActive
        self.isLightActive = isLightActive
        self.activeDeviceSummary = activeDeviceSummary
        self.vpdKpa = vpdKpa
        self.vpdZoneTitle = vpdZoneTitle
        self.isDemoMode = isDemoMode
        self.hasConfiguredCamera = hasConfiguredCamera
        self.isCameraConnected = isCameraConnected
        self.cameraSnapshotDate = cameraSnapshotDate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.roomName = try c.decodeIfPresent(String.self, forKey: .roomName) ?? "Lab Alpha"
        self.temperatureC = try c.decodeIfPresent(Double.self, forKey: .temperatureC) ?? 23.5
        self.humidityPct = try c.decodeIfPresent(Double.self, forKey: .humidityPct) ?? 91.0
        self.pressureHpa = try c.decodeIfPresent(Double.self, forKey: .pressureHpa) ?? 1013.2
        self.co2Ppm = try c.decodeIfPresent(Int.self, forKey: .co2Ppm) ?? 780
        self.hubActive = try c.decodeIfPresent(Bool.self, forKey: .hubActive) ?? true
        self.activeBatchCount = try c.decodeIfPresent(Int.self, forKey: .activeBatchCount) ?? 1
        self.topBatchName = try c.decodeIfPresent(String.self, forKey: .topBatchName) ?? "Batch #01"
        self.topBatchStrain = try c.decodeIfPresent(String.self, forKey: .topBatchStrain) ?? "MycoLabs"
        self.topBatchPhase = try c.decodeIfPresent(String.self, forKey: .topBatchPhase) ?? "Fruiting"
        self.topBatchColonization = try c.decodeIfPresent(Double.self, forKey: .topBatchColonization) ?? 90.0
        self.topBatchDaysInPhase = try c.decodeIfPresent(Int.self, forKey: .topBatchDaysInPhase) ?? 5
        self.topBatchNeedsBS = try c.decodeIfPresent(Bool.self, forKey: .topBatchNeedsBS) ?? false
        self.topBatchHasPins = try c.decodeIfPresent(Bool.self, forKey: .topBatchHasPins) ?? true
        self.lastUpdated = try c.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
        self.statusSummary = try c.decodeIfPresent(String.self, forKey: .statusSummary) ?? "Klimaat Optimaal"
        self.isHumidifierActive = try c.decodeIfPresent(Bool.self, forKey: .isHumidifierActive) ?? false
        self.isExhaustFanActive = try c.decodeIfPresent(Bool.self, forKey: .isExhaustFanActive) ?? false
        self.isLightActive = try c.decodeIfPresent(Bool.self, forKey: .isLightActive) ?? false
        self.activeDeviceSummary = try c.decodeIfPresent(String.self, forKey: .activeDeviceSummary) ?? "Ruststand"
        self.vpdKpa = try c.decodeIfPresent(Double.self, forKey: .vpdKpa) ?? 0.25
        self.vpdZoneTitle = try c.decodeIfPresent(String.self, forKey: .vpdZoneTitle) ?? "Ideaal"
        self.isDemoMode = try c.decodeIfPresent(Bool.self, forKey: .isDemoMode) ?? false
        self.hasConfiguredCamera = try c.decodeIfPresent(Bool.self, forKey: .hasConfiguredCamera) ?? false
        self.isCameraConnected = try c.decodeIfPresent(Bool.self, forKey: .isCameraConnected) ?? false
        self.cameraSnapshotDate = try c.decodeIfPresent(Date.self, forKey: .cameraSnapshotDate)
    }

    public static var placeholder: MycoWidgetSnapshot {
        MycoWidgetSnapshot()
    }
}

// MARK: - Widget Data Manager for Host App

final class MycoWidgetDataManager {
    static let shared = MycoWidgetDataManager()
    static let appGroupID = "group.com.mycolab.app"
    static let snapshotKey = "mycolab_widget_snapshot"

    private init() {}

    public func loadSnapshot() -> MycoWidgetSnapshot {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        if let data = defaults.data(forKey: Self.snapshotKey),
           let snapshot = try? JSONDecoder().decode(MycoWidgetSnapshot.self, from: data) {
            return snapshot
        }
        return MycoWidgetSnapshot()
    }

#if canImport(UIKit)
    public static func saveCameraSnapshot(image: UIImage) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }
        let targetURL = containerURL.appendingPathComponent("latest_chamber_snapshot.jpg")
        if let jpegData = image.jpegData(compressionQuality: 0.82) {
            try? jpegData.write(to: targetURL, options: .atomic)
        }
    }
#endif

    func updateSnapshot(
        from db: AppDatabase,
        currentTemp: Double? = nil,
        currentHumidity: Double? = nil,
        currentPressure: Double? = nil,
        isHubActive: Bool? = nil
    ) {
        let activeProjects = db.projects.filter { !$0.isArchived && $0.phase != .archived && $0.phase != .contaminated }
        let topProject = activeProjects.first

        // Determine temperature
        let temp = currentTemp
            ?? db.environmentConfig.latestSensorTempC
            ?? topProject?.latestTempC
            ?? db.environmentConfig.targetDayTempC

        // Determine humidity
        let humidity = currentHumidity
            ?? db.environmentConfig.latestSensorHumidityPct
            ?? topProject?.latestHumidityPct
            ?? db.environmentConfig.targetHumidityPct

        // Determine atmospheric pressure
        let baroPressure = MycoSensorIntelligenceManager.shared.currentPressureHpa
        let pressure = currentPressure ?? (baroPressure > 800 ? baroPressure : 1013.2)

        // CO2
        let co2 = db.environmentConfig.latestSensorCo2Ppm ?? 780

        // Hub state
        let hubActive = isHubActive ?? (MycoBackgroundHubManager.shared.isBackgroundHubActive || db.environmentConfig.is24_7HubBackgroundModeEnabled)

        var needsBS = false
        var hasPins = false
        if let p = topProject {
            needsBS = (p.colonizationPercent >= 25 && p.colonizationPercent <= 35 && p.lastBreakAndShakeDate == nil && p.phase == .spawn)
            hasPins = p.tags.contains(where: { $0.localizedCaseInsensitiveContains("pin") }) || p.phase == .fruiting || p.phase == .flushing
        }

        let daysInPhase: Int
        if let p = topProject {
            daysInPhase = max(Calendar.current.dateComponents([.day], from: p.startDate, to: Date()).day ?? 1, 1)
        } else {
            daysInPhase = 0
        }

        let statusText: String
        if temp >= 21.0 && temp <= 26.0 && humidity >= 80.0 {
            statusText = "Klimaat Optimaal"
        } else if temp < 20.0 {
            statusText = "Te Koud (\(String(format: "%.1f", temp))°C)"
        } else if temp > 27.0 {
            statusText = "Te Warm (\(String(format: "%.1f", temp))°C)"
        } else if humidity < 75.0 {
            statusText = "Vochtigheid Laag"
        } else {
            statusText = "Actief Bewaakt"
        }

        let topStrain = (topProject?.strainName.isEmpty == false) ? (topProject?.strainName ?? "MycoLabs Kweek") : "MycoLabs Kweek"
        let topPhaseName = topProject?.phase.rawValue ?? "Standby"
        let topColPct = topProject?.colonizationPercent ?? 0.0
        let topBatchTitle = topProject.map { "Batch #\($0.batchNumber)" } ?? "Geen batch"

        let isHumOn = db.smartDevices.contains { $0.deviceType == "Humidifier" && $0.isOn } || MycoOpticalHygrometerManager.shared.isHumidifierRunning
        let isFanOn = db.smartDevices.contains { $0.deviceType == "ExhaustFan" && $0.isOn }
        let isLightOn = db.smartDevices.contains { $0.deviceType == "Light" && $0.isOn }

        let deviceSummary: String
        if isHumOn {
            let secs = MycoOpticalHygrometerManager.shared.humidifierRemainingSeconds
            if secs > 0 {
                deviceSummary = "💨 Bevochtiger AAN (\(secs)s)"
            } else {
                deviceSummary = "💨 Bevochtiger AAN"
            }
        } else if isFanOn {
            deviceSummary = "🌪️ Afzuiger AAN (FAE)"
        } else if isLightOn {
            deviceSummary = "💡 Kweeklamp AAN"
        } else {
            deviceSummary = "💤 Apparaten in rust"
        }

        let vpdRes = MycoVPDCalculator.analyze(tempC: temp, humidityPct: humidity)
        let computedVpd = vpdRes?.vpdKPa ?? 0.25
        let computedVpdTitle = vpdRes?.titleNL ?? "Ideaal (0.25 kPa)"

        // Camera status computation
        let isDemo = db.isDemoMode
        let isCamLive = MycoCamStreamManager.shared.connectionState == .connected ||
                        (MycoCamStreamManager.shared.role == .host) ||
                        LiveKitStreamManager.shared.isConnected

        let pairedCam = UserDefaults.standard.string(forKey: "mycolab_paired_camera_id") ?? ""
        let hasCamera = !pairedCam.isEmpty ||
                        !db.environmentConfig.effectiveRtspURL.isEmpty ||
                        !db.environmentConfig.effectiveSnapshotURL.isEmpty ||
                        db.timelapsePhotos.contains(where: { $0.hasPhotoData }) ||
                        isCamLive

        var snapshotDate: Date? = nil
        #if canImport(UIKit)
        if let liveFrame = MycoCamStreamManager.shared.receivedFrame ?? MycoCamStreamManager.shared.cloudFrame ?? LiveKitStreamManager.shared.lastRemoteSnapshot {
            Self.saveCameraSnapshot(image: liveFrame)
            snapshotDate = Date()
        } else if let photoItem = db.timelapsePhotos.first(where: { $0.hasPhotoData }),
                  let img = photoItem.loadImage() {
            Self.saveCameraSnapshot(image: img)
            snapshotDate = photoItem.timestamp
        }
        #endif

        if snapshotDate == nil,
           let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            let targetURL = containerURL.appendingPathComponent("latest_chamber_snapshot.jpg")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: targetURL.path),
               let modDate = attrs[.modificationDate] as? Date {
                snapshotDate = modDate
            }
        }

        let snapshot = MycoWidgetSnapshot(
            roomName: db.environmentConfig.environmentName.isEmpty ? "Lab Alpha" : db.environmentConfig.environmentName,
            temperatureC: temp,
            humidityPct: humidity,
            pressureHpa: pressure,
            co2Ppm: co2,
            hubActive: hubActive,
            activeBatchCount: activeProjects.count,
            topBatchName: topBatchTitle,
            topBatchStrain: topStrain,
            topBatchPhase: topPhaseName,
            topBatchColonization: topColPct,
            topBatchDaysInPhase: daysInPhase,
            topBatchNeedsBS: needsBS,
            topBatchHasPins: hasPins,
            lastUpdated: Date(),
            statusSummary: statusText,
            isHumidifierActive: isHumOn,
            isExhaustFanActive: isFanOn,
            isLightActive: isLightOn,
            activeDeviceSummary: deviceSummary,
            vpdKpa: computedVpd,
            vpdZoneTitle: computedVpdTitle,
            isDemoMode: isDemo,
            hasConfiguredCamera: hasCamera,
            isCameraConnected: isCamLive,
            cameraSnapshotDate: snapshotDate
        )

        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? UserDefaults.standard
        defaults.set(db.environmentConfig.effectivePiHubIP, forKey: "mycolab_pi_hub_ip")
        defaults.set(db.environmentConfig.effectivePiHubPort, forKey: "mycolab_pi_hub_port")
        if let encoded = try? JSONEncoder().encode(snapshot) {
            defaults.set(encoded, forKey: Self.snapshotKey)
        }

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
