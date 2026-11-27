//
//  MycoOpticalHygrometerManager.swift
//  MycoLab
//
//  Autonome Optische Telelens Thermo- & Hygrometer Scanner
//  Leest met de ingestelde camera van de livestream telefoon en flits/lampen een fysieke niet-smart meter af via Vision AI.
//  Berekent vooraf de benodigde looptijd voor de luchtbevochtiger om het gewenste
//  percentage te bereiken, omdat het display door optrekkende nevel/condens onleesbaar
//  wordt zodra de bevochtiger inschakelt.
//

import Foundation
import SwiftUI
import AVFoundation
@preconcurrency import Vision
import Combine
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
@preconcurrency import UserNotifications

// MARK: - 1. GEGEVENSMODELLEN

public struct NormalizedROI: Codable, Equatable, Sendable {
    public var x: Double      // 0.0 ... 1.0 (left)
    public var y: Double      // 0.0 ... 1.0 (top)
    public var width: Double  // 0.05 ... 1.0
    public var height: Double // 0.05 ... 1.0

    nonisolated public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = max(0.0, min(0.95, x))
        self.y = max(0.0, min(0.95, y))
        self.width = max(0.05, min(1.0 - self.x, width))
        self.height = max(0.05, min(1.0 - self.y, height))
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    public static let defaultMeter = NormalizedROI(x: 0.15, y: 0.18, width: 0.70, height: 0.64)
    public static let defaultTemperature = NormalizedROI(x: 0.20, y: 0.22, width: 0.60, height: 0.26)
    public static let defaultHumidity = NormalizedROI(x: 0.20, y: 0.52, width: 0.60, height: 0.26)
}

public struct OpticalMeterReading: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var humidityPct: Double
    public var temperatureC: Double?
    public var confidence: Double
    public var recognizedRawText: String
    public var sourceLens: String
    public var calculatedHumidifierDurationSec: Int
    public var calculatedWaterMl: Double
    public var chamberVolumeM3: Double
    public var wasHumidifierTriggered: Bool
    public var isFlashUsed: Bool
    public var sampleCount: Int = 1
    public var verificationSummary: String? = nil

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        humidityPct: Double,
        temperatureC: Double? = nil,
        confidence: Double = 0.9,
        recognizedRawText: String = "",
        sourceLens: String = "Livestream Camera",
        calculatedHumidifierDurationSec: Int = 0,
        calculatedWaterMl: Double = 0.0,
        chamberVolumeM3: Double = 0.5,
        wasHumidifierTriggered: Bool = false,
        isFlashUsed: Bool = true,
        sampleCount: Int = 1,
        verificationSummary: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.humidityPct = humidityPct
        self.temperatureC = temperatureC
        self.confidence = confidence
        self.recognizedRawText = recognizedRawText
        self.sourceLens = sourceLens
        self.calculatedHumidifierDurationSec = calculatedHumidifierDurationSec
        self.calculatedWaterMl = calculatedWaterMl
        self.chamberVolumeM3 = chamberVolumeM3
        self.wasHumidifierTriggered = wasHumidifierTriggered
        self.isFlashUsed = isFlashUsed
        self.sampleCount = sampleCount
        self.verificationSummary = verificationSummary
    }

    enum CodingKeys: CodingKey {
        case id, timestamp, humidityPct, temperatureC, confidence
        case recognizedRawText, sourceLens, calculatedHumidifierDurationSec
        case calculatedWaterMl, chamberVolumeM3, wasHumidifierTriggered, isFlashUsed
        case sampleCount, verificationSummary
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try c.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        humidityPct = try c.decode(Double.self, forKey: .humidityPct)
        temperatureC = try c.decodeIfPresent(Double.self, forKey: .temperatureC)
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.9
        recognizedRawText = try c.decodeIfPresent(String.self, forKey: .recognizedRawText) ?? ""
        sourceLens = try c.decodeIfPresent(String.self, forKey: .sourceLens) ?? "Livestream Camera"
        calculatedHumidifierDurationSec = try c.decodeIfPresent(Int.self, forKey: .calculatedHumidifierDurationSec) ?? 0
        calculatedWaterMl = try c.decodeIfPresent(Double.self, forKey: .calculatedWaterMl) ?? 0.0
        chamberVolumeM3 = try c.decodeIfPresent(Double.self, forKey: .chamberVolumeM3) ?? 0.5
        wasHumidifierTriggered = try c.decodeIfPresent(Bool.self, forKey: .wasHumidifierTriggered) ?? false
        isFlashUsed = try c.decodeIfPresent(Bool.self, forKey: .isFlashUsed) ?? false
        sampleCount = try c.decodeIfPresent(Int.self, forKey: .sampleCount) ?? 1
        verificationSummary = try c.decodeIfPresent(String.self, forKey: .verificationSummary)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(humidityPct, forKey: .humidityPct)
        try c.encodeIfPresent(temperatureC, forKey: .temperatureC)
        try c.encode(confidence, forKey: .confidence)
        try c.encode(recognizedRawText, forKey: .recognizedRawText)
        try c.encode(sourceLens, forKey: .sourceLens)
        try c.encode(calculatedHumidifierDurationSec, forKey: .calculatedHumidifierDurationSec)
        try c.encode(calculatedWaterMl, forKey: .calculatedWaterMl)
        try c.encode(chamberVolumeM3, forKey: .chamberVolumeM3)
        try c.encode(wasHumidifierTriggered, forKey: .wasHumidifierTriggered)
        try c.encode(isFlashUsed, forKey: .isFlashUsed)
        try c.encode(sampleCount, forKey: .sampleCount)
        try c.encodeIfPresent(verificationSummary, forKey: .verificationSummary)
    }
}

public struct RecognizedCandidate: Sendable {
    public let text: String
    public let confidence: Float
    public let boundingBox: CGRect // Normalized (0...1) in UIKit coordinates (top-left 0,0)

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

public struct OpticalRecognitionDetails: Sendable {
    public var humidity: Double?
    public var temperature: Double?
    public var confidence: Double
    public var rawText: String
    public var tempCropImage: UIImage?
    public var humCropImage: UIImage?
    public var meterCropImage: UIImage?
    public var tempCandidatesText: String
    public var humCandidatesText: String
    public var fullDisplayCandidatesText: String
    public var sharpnessScore: Double
    public var verificationNote: String?
    public var isSuccess: Bool {
        humidity != nil && temperature != nil
    }

    public init(
        humidity: Double? = nil,
        temperature: Double? = nil,
        confidence: Double = 0.85,
        rawText: String = "",
        tempCropImage: UIImage? = nil,
        humCropImage: UIImage? = nil,
        meterCropImage: UIImage? = nil,
        tempCandidatesText: String = "",
        humCandidatesText: String = "",
        fullDisplayCandidatesText: String = "",
        sharpnessScore: Double = 0.0,
        verificationNote: String? = nil
    ) {
        self.humidity = humidity
        self.temperature = temperature
        self.confidence = confidence
        self.rawText = rawText
        self.tempCropImage = tempCropImage
        self.humCropImage = humCropImage
        self.meterCropImage = meterCropImage
        self.tempCandidatesText = tempCandidatesText
        self.humCandidatesText = humCandidatesText
        self.fullDisplayCandidatesText = fullDisplayCandidatesText
        self.sharpnessScore = sharpnessScore
        self.verificationNote = verificationNote
    }
}

/// Vertegenwoordigt een individuele opname uit een multi-shot burst met zijn berekende optische kwaliteit en herkenning
public struct OpticalCandidateSample: Sendable {
    public let index: Int
    public let image: UIImage
    public let sharpness: Double
    public let details: OpticalRecognitionDetails

    public var humidity: Double? { details.humidity }
    public var temperature: Double? { details.temperature }
    public var confidence: Double { details.confidence }
    public var hasReading: Bool { details.humidity != nil }
    public var isComplete: Bool { details.humidity != nil && details.temperature != nil }

    public var compositeScore: Double {
        let normalizedSharpness = min(1.0, sharpness * 4.0)
        let completeBonus = isComplete ? 0.30 : (hasReading ? 0.10 : 0.0)
        return (normalizedSharpness * 0.45) + (confidence * 0.45) + completeBonus
    }

    public init(index: Int, image: UIImage, sharpness: Double, details: OpticalRecognitionDetails) {
        self.index = index
        self.image = image
        self.sharpness = sharpness
        self.details = details
    }
}

public struct OpticalHygrometerConfig: Codable, Equatable, Sendable {
    public enum CameraSource: String, Codable, CaseIterable, Sendable {
        case remoteStream = "remote_stream"   // Kweekcamera (Livestream / Op afstand)
        case localDevice = "local_device"     // Lokale Camera (Dit toestel)
    }

    public var isEnabled: Bool = false
    public var scanIntervalMinutes: Int = 15
    public var useFlash: Bool = false
    public var useGrowLights: Bool = true
    public var preferredZoomRatio: Double = 2.5
    public var targetHumidityPct: Double = 90.0
    public var humidifierOutputMlH: Double = 300.0
    public var chamberVolumeM3: Double = 0.50
    public var useGrowSpaceSync: Bool = true
    public var absorptionEfficiency: Double = 1.35
    public var minRunDurationSeconds: Int = 20
    public var maxRunDurationSeconds: Int = 480
    public var fogSettlingDurationMinutes: Int = 15
    public var selectedHumidifierDeviceId: UUID? = nil
    public var autoScanAfterFAE: Bool = true

    // Kritieke Alarm Notificaties
    public var alertsEnabled: Bool = true
    public var minCriticalHumidityThreshold: Double = 80.0
    public var maxCriticalTempThreshold: Double = 27.5
    public var minCriticalTempThreshold: Double = 18.0

    // Camera Bron & Lens Keuze
    public var cameraSource: CameraSource = .remoteStream
    public var preferredCameraId: String = ""

    // Interactive Meter & Zone Calibration ROIs
    public var isConfigured: Bool = false
    public var meterROI: NormalizedROI? = NormalizedROI.defaultMeter
    public var temperatureROI: NormalizedROI? = NormalizedROI.defaultTemperature
    public var humidityROI: NormalizedROI? = NormalizedROI.defaultHumidity

    // Custom Saved Tap-to-Focus Point (exact spot on physical meter)
    public var customFocusPoint: CGPoint? = nil

    public init() {}

    enum CodingKeys: CodingKey {
        case isEnabled, scanIntervalMinutes, useFlash, useGrowLights, preferredZoomRatio
        case targetHumidityPct, humidifierOutputMlH, chamberVolumeM3, useGrowSpaceSync, absorptionEfficiency
        case minRunDurationSeconds, maxRunDurationSeconds, fogSettlingDurationMinutes
        case selectedHumidifierDeviceId, autoScanAfterFAE, isConfigured, meterROI, temperatureROI, humidityROI
        case cameraSource, preferredCameraId
        case alertsEnabled, minCriticalHumidityThreshold, maxCriticalTempThreshold, minCriticalTempThreshold
        case customFocusPoint
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        let decodedInterval = try container.decodeIfPresent(Int.self, forKey: .scanIntervalMinutes) ?? 15
        scanIntervalMinutes = decodedInterval >= 5 ? decodedInterval : 15
        useFlash = try container.decodeIfPresent(Bool.self, forKey: .useFlash) ?? false
        useGrowLights = try container.decodeIfPresent(Bool.self, forKey: .useGrowLights) ?? true
        preferredZoomRatio = try container.decodeIfPresent(Double.self, forKey: .preferredZoomRatio) ?? 2.5
        targetHumidityPct = try container.decodeIfPresent(Double.self, forKey: .targetHumidityPct) ?? 90.0
        humidifierOutputMlH = try container.decodeIfPresent(Double.self, forKey: .humidifierOutputMlH) ?? 300.0
        chamberVolumeM3 = try container.decodeIfPresent(Double.self, forKey: .chamberVolumeM3) ?? 0.50
        useGrowSpaceSync = try container.decodeIfPresent(Bool.self, forKey: .useGrowSpaceSync) ?? true
        absorptionEfficiency = try container.decodeIfPresent(Double.self, forKey: .absorptionEfficiency) ?? 1.35
        minRunDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .minRunDurationSeconds) ?? 20
        maxRunDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .maxRunDurationSeconds) ?? 480
        fogSettlingDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .fogSettlingDurationMinutes) ?? 15
        selectedHumidifierDeviceId = try container.decodeIfPresent(UUID.self, forKey: .selectedHumidifierDeviceId)
        autoScanAfterFAE = try container.decodeIfPresent(Bool.self, forKey: .autoScanAfterFAE) ?? true
        cameraSource = try container.decodeIfPresent(CameraSource.self, forKey: .cameraSource) ?? .remoteStream
        preferredCameraId = try container.decodeIfPresent(String.self, forKey: .preferredCameraId) ?? ""
        isConfigured = try container.decodeIfPresent(Bool.self, forKey: .isConfigured) ?? false
        alertsEnabled = try container.decodeIfPresent(Bool.self, forKey: .alertsEnabled) ?? true
        minCriticalHumidityThreshold = try container.decodeIfPresent(Double.self, forKey: .minCriticalHumidityThreshold) ?? 80.0
        maxCriticalTempThreshold = try container.decodeIfPresent(Double.self, forKey: .maxCriticalTempThreshold) ?? 27.5
        minCriticalTempThreshold = try container.decodeIfPresent(Double.self, forKey: .minCriticalTempThreshold) ?? 18.0
        meterROI = try container.decodeIfPresent(NormalizedROI.self, forKey: .meterROI) ?? NormalizedROI.defaultMeter
        temperatureROI = try container.decodeIfPresent(NormalizedROI.self, forKey: .temperatureROI) ?? NormalizedROI.defaultTemperature
        humidityROI = try container.decodeIfPresent(NormalizedROI.self, forKey: .humidityROI) ?? NormalizedROI.defaultHumidity
        customFocusPoint = try container.decodeIfPresent(CGPoint.self, forKey: .customFocusPoint)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(scanIntervalMinutes, forKey: .scanIntervalMinutes)
        try container.encode(useFlash, forKey: .useFlash)
        try container.encode(useGrowLights, forKey: .useGrowLights)
        try container.encode(preferredZoomRatio, forKey: .preferredZoomRatio)
        try container.encode(targetHumidityPct, forKey: .targetHumidityPct)
        try container.encode(humidifierOutputMlH, forKey: .humidifierOutputMlH)
        try container.encode(chamberVolumeM3, forKey: .chamberVolumeM3)
        try container.encode(useGrowSpaceSync, forKey: .useGrowSpaceSync)
        try container.encode(absorptionEfficiency, forKey: .absorptionEfficiency)
        try container.encode(minRunDurationSeconds, forKey: .minRunDurationSeconds)
        try container.encode(maxRunDurationSeconds, forKey: .maxRunDurationSeconds)
        try container.encode(fogSettlingDurationMinutes, forKey: .fogSettlingDurationMinutes)
        try container.encodeIfPresent(selectedHumidifierDeviceId, forKey: .selectedHumidifierDeviceId)
        try container.encode(autoScanAfterFAE, forKey: .autoScanAfterFAE)
        try container.encode(cameraSource, forKey: .cameraSource)
        try container.encode(preferredCameraId, forKey: .preferredCameraId)
        try container.encode(isConfigured, forKey: .isConfigured)
        try container.encode(alertsEnabled, forKey: .alertsEnabled)
        try container.encode(minCriticalHumidityThreshold, forKey: .minCriticalHumidityThreshold)
        try container.encode(maxCriticalTempThreshold, forKey: .maxCriticalTempThreshold)
        try container.encode(minCriticalTempThreshold, forKey: .minCriticalTempThreshold)
        try container.encodeIfPresent(meterROI, forKey: .meterROI)
        try container.encodeIfPresent(temperatureROI, forKey: .temperatureROI)
        try container.encodeIfPresent(humidityROI, forKey: .humidityROI)
        try container.encodeIfPresent(customFocusPoint, forKey: .customFocusPoint)
    }
}

// MARK: - 2. OPTICAL HYGROMETER MANAGER

@MainActor
public final class MycoOpticalHygrometerManager: NSObject, ObservableObject {
    public static let shared = MycoOpticalHygrometerManager()

    // MARK: - Published Properties
    @Published public var config: OpticalHygrometerConfig = OpticalHygrometerConfig() {
        didSet { saveConfig() }
    }
    @Published public var lastReading: OpticalMeterReading? = nil
    @Published public var readingHistory: [OpticalMeterReading] = []
    @Published public var isScanning: Bool = false
    @Published public var scanStatus: String = "Standby"
    @Published public var lastCapturedPreview: UIImage? = nil
    @Published public var lastScanError: String? = nil

    public func handleReceivedRemotePhoto(_ image: UIImage) {
        self.lastCapturedPreview = image
        self.scanStatus = "Nieuwe foto ontvangen van kweekcamera!"
        self.lastScanError = nil
    }
    @Published public var lastRawRecognizedText: String? = nil
    @Published public var lastMultiSampleSummary: String? = nil
    @Published public var isHumidifierRunning: Bool = false
    @Published public var humidifierRemainingSeconds: Int = 0
    @Published public var isFogSettling: Bool = false
    @Published public var fogSettlingRemainingSeconds: Int = 0
    @Published public var nextScanDate: Date? = nil

    // Hardware Lens & Detection Info
    @Published public var hasPhysicalTelephotoLens: Bool = false
    @Published public var activeTelephotoDescription: String = "Livestream Telefoon Camera"

    /// Bepaalt of er een camera gekoppeld is (optioneel voor de gebruiker)
    public var isCameraLinked: Bool {
        guard config.isEnabled else { return false }
        if MycoCamPairingManager.shared.isPaired || MycoCamPairingManager.shared.pairedCameraId != nil {
            return true
        }
        if let storedId = UserDefaults.standard.string(forKey: "mycolab_paired_camera_id"), !storedId.isEmpty {
            return true
        }
        let streamMgr = LiveKitStreamManager.shared
        if streamMgr.isConnected && streamMgr.remoteVideoTrack != nil {
            return true
        }
        if let url = MycoStore.shared?.db.environmentConfig.remoteCameraStreamURL, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
    }

    // Internals
    private var periodicScanTimer: AnyCancellable? = nil
    private var humidifierCountdownTimer: AnyCancellable? = nil
    private var fogSettlingTimer: AnyCancellable? = nil
    private let configStorageKey = "mycolab_optical_hygrometer_config_v1"
    private let historyStorageKey = "mycolab_optical_hygrometer_history_v1"

    override private init() {
        super.init()
        loadPersistedData()
        if !UserDefaults.standard.bool(forKey: "mycolab_optical_lights_configured") {
            config.useGrowLights = true
            UserDefaults.standard.set(true, forKey: "mycolab_optical_lights_configured")
            saveConfig()
        }
        if config.scanIntervalMinutes < 5 {
            config.scanIntervalMinutes = 15
        }
        detectTelephotoHardware()
        syncWithEnvironmentConfig()
        
        // Safety: Do NOT auto-start periodic background scanning on app launch.
        // This immediately stops any previously stuck background loop or rogue fast timer.
        config.isEnabled = false
        stopPeriodicMonitoring()
        saveConfig()
    }

    public func syncWithEnvironmentConfig() {
        guard let store = MycoStore.shared else { return }
        let env = store.db.environmentConfig
        if config.useGrowSpaceSync {
            if env.roomVolumeM3 > 0.01 {
                config.chamberVolumeM3 = (env.roomVolumeM3 * 100).rounded() / 100
            }
            if env.humidifierOutputMlH > 0 {
                config.humidifierOutputMlH = env.humidifierOutputMlH
            }
            if env.targetHumidityPct > 0 {
                config.targetHumidityPct = env.targetHumidityPct
            }
            saveConfig()
        }
    }

    // MARK: - Hardware Lens & Stream Source Detection
    public func resolveTelephotoCameraID() -> String? {
        let streamMgr = LiveKitStreamManager.shared
        // 1. Explicit user selection if set and valid
        if !config.preferredCameraId.isEmpty,
           streamMgr.availableCameras.contains(where: { $0.id == config.preferredCameraId }) {
            return config.preferredCameraId
        }
        // 2. Hardware telephoto camera among local available cameras
        if let tele = streamMgr.availableCameras.first(where: {
            $0.deviceType == .builtInTelephotoCamera ||
            $0.shortLabel.localizedCaseInsensitiveContains("tele") ||
            $0.name.localizedCaseInsensitiveContains("tele") ||
            $0.name.localizedCaseInsensitiveContains("zoom")
        }) {
            return tele.id
        }
        // 3. Fallback AVCaptureDevice discovery session
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        return discovery.devices.first?.uniqueID
    }

    public func resolveRemoteTelephotoCameraID() -> String? {
        let streamMgr = LiveKitStreamManager.shared
        if !config.preferredCameraId.isEmpty,
           streamMgr.remoteAvailableCameras.contains(where: { $0.id == config.preferredCameraId }) {
            return config.preferredCameraId
        }
        if let tele = streamMgr.remoteAvailableCameras.first(where: {
            $0.shortLabel.localizedCaseInsensitiveContains("tele") ||
            $0.name.localizedCaseInsensitiveContains("tele") ||
            $0.name.localizedCaseInsensitiveContains("zoom")
        }) {
            return tele.id
        }
        return nil
    }

    public func detectTelephotoHardware() {
        let streamMgr = LiveKitStreamManager.shared
        let camStreamMgr = MycoCamStreamManager.shared
        let isBroadcaster = streamMgr.currentRole == .broadcaster
            || streamMgr.isStreamHubModeActive
            || MycoBackgroundHubManager.shared.isStreamHubRoleActive
            || camStreamMgr.role == .host

        if config.cameraSource == .remoteStream && !isBroadcaster {
            if let remoteTeleId = resolveRemoteTelephotoCameraID(),
               let remoteTele = streamMgr.remoteAvailableCameras.first(where: { $0.id == remoteTeleId }) {
                self.hasPhysicalTelephotoLens = true
                self.activeTelephotoDescription = "Kweekcamera Telelens (\(remoteTele.shortLabel))"
                if config.preferredCameraId.isEmpty {
                    config.preferredCameraId = remoteTele.id
                }
            } else {
                let remoteLabel = streamMgr.remoteActiveCameraLabel.isEmpty ? "Kweekcamera (Livestream)" : "Kweekcamera (\(streamMgr.remoteActiveCameraLabel))"
                self.hasPhysicalTelephotoLens = false
                self.activeTelephotoDescription = remoteLabel
            }
            return
        }

        if let localTeleId = resolveTelephotoCameraID(),
           let localTele = streamMgr.availableCameras.first(where: { $0.id == localTeleId }) {
            self.hasPhysicalTelephotoLens = true
            self.activeTelephotoDescription = "Lokale Telelens (\(localTele.name))"
            if config.preferredCameraId.isEmpty {
                config.preferredCameraId = localTele.id
            }
        } else {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInTelephotoCamera],
                mediaType: .video,
                position: .back
            )
            if let teleDevice = discovery.devices.first {
                self.hasPhysicalTelephotoLens = true
                self.activeTelephotoDescription = "Lokale Telelens (\(teleDevice.localizedName))"
                if config.preferredCameraId.isEmpty {
                    config.preferredCameraId = teleDevice.uniqueID
                }
            } else {
                self.hasPhysicalTelephotoLens = false
                self.activeTelephotoDescription = "Lokale Camera (\(String(format: "%.1f", config.preferredZoomRatio))x)"
            }
        }
    }

    // MARK: - Periodic Scanning Control
    public func togglePeriodicMonitoring(enabled: Bool) {
        config.isEnabled = enabled
        if enabled {
            startPeriodicMonitoring()
        } else {
            stopPeriodicMonitoring()
        }
    }

    public func startPeriodicMonitoring() {
        periodicScanTimer?.cancel()
        
        // Safety: Enforce strict minimum interval of 5 minutes (300 seconds) to prevent repeating loops
        if config.scanIntervalMinutes < 5 {
            config.scanIntervalMinutes = 15
        }
        let intervalSec = TimeInterval(max(300, config.scanIntervalMinutes * 60))
        scanStatus = "Periodieke meter scanner actief (\(config.scanIntervalMinutes) min)"
        scheduleNextScanDate()

        periodicScanTimer = Timer.publish(every: intervalSec, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.performScheduledScan()
                }
            }
    }

    public func stopPeriodicMonitoring() {
        periodicScanTimer?.cancel()
        periodicScanTimer = nil
        nextScanDate = nil
        config.isEnabled = false
        saveConfig()
        scanStatus = "Periodieke scanner gepauzeerd"
    }

    private var postFAETimer: AnyCancellable? = nil

    /// Voert direct een optische meting uit wanneer een gekoppelde camera aanwezig is na het draaien van de ventilator
    @discardableResult
    public func triggerPostFaeScan(fanDurationMinutes: Double) async -> OpticalMeterReading? {
        postFAETimer?.cancel()
        postFAETimer = nil
        print("📸 [OpticalHygrometer] Start directe post-FAE optische scan na \(fanDurationMinutes)m ventilatie.")
        scanStatus = "📸 Display direct scannen na \(String(format: "%.1f", fanDurationMinutes))m ventilatie..."
        try? await Task.sleep(nanoseconds: 800_000_000)
        return await triggerScanAndReact(fanDurationMinutes: fanDurationMinutes)
    }

    public func scheduleScanAfterFAE(fanDurationMinutes: Double? = nil) {
        guard config.isEnabled && config.autoScanAfterFAE else { return }
        postFAETimer?.cancel()
        scanStatus = "🍃 Verse lucht voltooid. Directe optische scan start..."
        print("🍃 [OpticalHygrometer] FAE ventilatie afgerond. Start directe optische scan...")
        
        Task { @MainActor in
            _ = await self.triggerPostFaeScan(fanDurationMinutes: fanDurationMinutes ?? 5.0)
        }
    }

    private func scheduleNextScanDate() {
        nextScanDate = Date().addingTimeInterval(TimeInterval(config.scanIntervalMinutes * 60))
    }

    private func performScheduledScan() async {
        guard config.isEnabled else { return }

        // Fog Settling Safety Check:
        // Do NOT scan if humidifier has just run and mist is still floating in the chamber!
        if isFogSettling {
            scanStatus = "Wachten tot nevel is opgetrokken (\(fogSettlingRemainingSeconds)s)..."
            return
        }

        _ = await triggerScanAndReact()
        scheduleNextScanDate()
    }

    // MARK: - Core Scan & Automation Pipeline
    /// Voert de volledige cyclus uit via de camera van de livestream telefoon:
    /// 1. Verlichting aan (lampen + flits op livestream telefoon)
    /// 2. Hoge-resolutie frame ophalen van de livestream camera (geen lokale kijker camera!)
    /// 3. Flits/verlichting herstellen
    /// 4. Vision OCR tekstherkenning op display
    /// 5. Berekent vooraf de bevochtigerduur (voordat de kamer dichtslaat met nevel)
    /// 6. Schakelt bevochtiger in en bewaakt de looptijd
    @discardableResult
    public func triggerScanAndReact(overrideImage: UIImage? = nil, simulateRH: Double? = nil, fanDurationMinutes: Double? = nil) async -> OpticalMeterReading? {
        guard !isScanning else { return nil }

        // FAE Fan Safety Check: Scannen heeft geen zin als de ventilator stormachtige wind blaast
        if let store = MycoStore.shared,
           store.db.smartDevices.contains(where: {
               ($0.deviceType == "ExhaustFan" || $0.name.localizedCaseInsensitiveContains("ventil") || $0.name.localizedCaseInsensitiveContains("afzuig")) && $0.isOn
           }) {
            scanStatus = "Ventilator draait momenteel (FAE). Scan uitgesteld tot lucht stilstaat..."
            print("[OpticalHygrometer] Scan overgeslagen: ventilator is actief.")
            return nil
        }

        isScanning = true
        scanStatus = "Camera stelt eerst scherp op de meter..."

        var capturedImages: [UIImage] = []
        var usedFlash = false

        if let singleOverride = overrideImage {
            capturedImages = [singleOverride]
        } else {
            let captureResult = await acquireTelephotoFramesWithFocusAndLighting(sampleCount: 3)
            capturedImages = captureResult.images
            usedFlash = captureResult.usedFlash
        }

        guard !capturedImages.isEmpty else {
            isScanning = false
            let hasLiveKitBroadcaster = LiveKitStreamManager.shared.remoteVideoTrack != nil
            if hasLiveKitBroadcaster {
                self.lastScanError = "Geen camerabeeld van de livestream telefoon ontvangen. Zorg dat de camera actief is en niet geblokkeerd wordt."
                scanStatus = "Wachten op beeld van kweekcamera..."
            } else {
                self.lastScanError = "Geen camerabeeld ontvangen. Geef MycoLabs toegang tot de camera in Instellingen, of activeer de kweekcamera livestream."
                scanStatus = "Cameratoegang of livestream vereist"
            }
            return nil
        }

        // 2. Vision OCR & Scherpte Evaluatie over alle gemaakte opnames
        scanStatus = "✨ Kwaliteit en scherpte analyseren over \(capturedImages.count) opnames..."

        var evaluatedSamples: [OpticalCandidateSample] = []

        if let simRH = simulateRH {
            let simDetails = OpticalRecognitionDetails(
                humidity: simRH,
                temperature: 22.8,
                confidence: 0.98,
                rawText: "SIMULATIE: \(Int(simRH))% 22.8C",
                sharpnessScore: 0.85,
                verificationNote: "Handmatige simulatie"
            )
            evaluatedSamples.append(
                OpticalCandidateSample(index: 0, image: capturedImages[0], sharpness: 0.85, details: simDetails)
            )
        } else {
            for (idx, img) in capturedImages.enumerated() {
                scanStatus = "✨ Opname \(idx + 1)/\(capturedImages.count) analyseren..."
                let sharpness = Self.calculateSharpnessScore(image: img, roi: self.config.meterROI)
                var details = await recognizeMeterTextDetailed(image: img, config: self.config)
                details.sharpnessScore = sharpness
                evaluatedSamples.append(
                    OpticalCandidateSample(index: idx, image: img, sharpness: sharpness, details: details)
                )
            }
        }

        // 3. Kies de beste opname (hoogste scherpte + geldige cijferherkenning)
        let samplesWithReading = evaluatedSamples.filter { $0.hasReading }

        guard let bestCandidate = samplesWithReading.sorted(by: { $0.compositeScore > $1.compositeScore }).first else {
            isScanning = false
            // Bewaar de scherpste foto als preview zodat gebruiker de uitsnede kan zien/corrigeren
            if let sharpest = evaluatedSamples.sorted(by: { $0.sharpness > $1.sharpness }).first {
                self.lastCapturedPreview = sharpest.image
                self.lastRawRecognizedText = sharpest.details.rawText
            }
            self.lastScanError = evaluatedSamples.first?.details.rawText.isEmpty == true
                ? "Geen cijfers herkend in de \(capturedImages.count) opnames. Gebruik 'Zones Instellen' om de AI te richten."
                : "Geen duidelijke vochtmeting herkend in de \(capturedImages.count) opnames. Pas de selectievakken aan in de set-up."
            scanStatus = "Geen cijfers herkend over \(capturedImages.count) opnames. Stel zones in."
            return nil
        }

        // 4. Kruisvalidatie & Consensus over de andere foto's
        let primaryH = bestCandidate.humidity!
        let primaryT = bestCandidate.temperature

        var agreeingSamples: [OpticalCandidateSample] = []
        var differingSamples: [OpticalCandidateSample] = []

        for sample in samplesWithReading {
            let humDiff = abs(sample.humidity! - primaryH)
            let tempDiff: Double = {
                guard let t1 = primaryT, let t2 = sample.temperature else { return 0.0 }
                return abs(t1 - t2)
            }()

            if humDiff <= 2.0 && tempDiff <= 0.8 {
                agreeingSamples.append(sample)
            } else {
                differingSamples.append(sample)
            }
        }

        // Als er meerdere andere foto's zijn die gezamenlijk overeenkomen en afwijken van de scherpste (bijv. reflectie), neem de consensus
        let chosenCandidate: OpticalCandidateSample
        if differingSamples.count > agreeingSamples.count, differingSamples.count >= 2 {
            chosenCandidate = differingSamples.sorted(by: { $0.compositeScore > $1.compositeScore }).first ?? bestCandidate
        } else {
            chosenCandidate = bestCandidate
        }

        let detectedHumidity = chosenCandidate.humidity!
        let detectedTemp = chosenCandidate.temperature
        let finalConfidence = chosenCandidate.confidence
        self.lastCapturedPreview = chosenCandidate.image
        self.lastRawRecognizedText = chosenCandidate.details.rawText
        self.lastScanError = nil

        let totalPhotos = capturedImages.count
        let matchedCount = max(1, agreeingSamples.count)
        let tempText = detectedTemp != nil ? String(format: "%.1f°C", detectedTemp!) : "-"
        let verificationSummary: String
        if totalPhotos > 1 {
            if matchedCount == totalPhotos {
                verificationSummary = "✅ 100% consistent: alle \(totalPhotos) opnames bevestigen \(Int(detectedHumidity))% RV & \(tempText) (Foto #\(chosenCandidate.index + 1) scherpst)."
            } else if matchedCount >= 2 {
                verificationSummary = "✅ Geverifieerd: \(matchedCount) van de \(totalPhotos) opnames bevestigen \(Int(detectedHumidity))% RV & \(tempText)."
            } else {
                verificationSummary = "ℹ️ Afgelezen van beste opname #\(chosenCandidate.index + 1) (\(Int(detectedHumidity))% RV, \(tempText))."
            }
        } else {
            verificationSummary = "Enkele opname geanalyseerd (\(Int(detectedHumidity))% RV)."
        }
        self.lastMultiSampleSummary = verificationSummary

        // 5. Meetwaarden opslaan & synchroniseren in MycoLab
        if let store = MycoStore.shared {
            store.recordSensorReading(
                tempC: detectedTemp,
                humidityPct: detectedHumidity,
                source: "Optische Tele-Sensor"
            )
        }

        // 6. BEREKENING VOORAF (Voorkomt nevel-blindering!)
        let effectiveTargetRH = (MycoStore.shared?.db.environmentConfig.targetHumidityPct ?? config.targetHumidityPct)
        let calc = calculateHumidifierDuration(
            currentRH: detectedHumidity,
            targetRH: effectiveTargetRH,
            fanDurationMinutes: fanDurationMinutes
        )

        let isBroadcaster = LiveKitStreamManager.shared.currentRole == .broadcaster
            || LiveKitStreamManager.shared.isStreamHubModeActive
            || MycoBackgroundHubManager.shared.isStreamHubRoleActive
            || MycoCamStreamManager.shared.role == .host

        let lensDescription: String
        if !isBroadcaster {
            let remoteLabel = LiveKitStreamManager.shared.remoteActiveCameraLabel.isEmpty ? "Livestream Telefoon" : "Livestream Telefoon (\(LiveKitStreamManager.shared.remoteActiveCameraLabel))"
            lensDescription = remoteLabel
        } else {
            lensDescription = hasPhysicalTelephotoLens ? "Optische Telelens" : "Kweekcamera (Ingesteld)"
        }

        var reading = OpticalMeterReading(
            humidityPct: detectedHumidity,
            temperatureC: detectedTemp,
            confidence: finalConfidence,
            recognizedRawText: chosenCandidate.details.rawText,
            sourceLens: lensDescription,
            calculatedHumidifierDurationSec: calc.seconds,
            calculatedWaterMl: calc.waterMl,
            chamberVolumeM3: config.chamberVolumeM3,
            wasHumidifierTriggered: false,
            isFlashUsed: usedFlash,
            sampleCount: totalPhotos,
            verificationSummary: verificationSummary
        )

        // 7. Automatisch reageren met de bevochtiger
        if calc.seconds > 0 {
            reading.wasHumidifierTriggered = true
            executeHumidifierReaction(durationSeconds: calc.seconds, reading: reading)
            scanStatus = "Gelezen: \(Int(detectedHumidity))% RV (\(matchedCount)/\(totalPhotos) opnames). Bevochtiger gestart voor \(calc.seconds)s (\(calc.explanation))"
        } else {
            scanStatus = "Gelezen: \(Int(detectedHumidity))% RV (\(matchedCount)/\(totalPhotos) opnames). Luchtvochtigheid optimaal (\(Int(effectiveTargetRH))% doel)."
        }

        self.lastReading = reading
        self.readingHistory.insert(reading, at: 0)
        self.checkAndDispatchClimateAlerts(reading: reading)
        if self.readingHistory.count > 30 {
            self.readingHistory = Array(self.readingHistory.prefix(30))
        }
        self.isScanning = false
        saveHistory()

        // Telemetrie direct versturen naar kijk-telefoon via LiveKit datakanaal
        let streamMgr = LiveKitStreamManager.shared
        if streamMgr.isConnected {
            let tempStr = reading.temperatureC != nil ? String(format: "%.1f", reading.temperatureC!) : "nil"
            streamMgr.sendDataCommand(command: "optical:reading:\(reading.humidityPct):\(tempStr)")
        }

        // Maak aansluitend ook een groothoek overzichtsfoto met flits voor het dashboard kweekcamera-blokje in standby
        Task {
            await self.captureWideOverviewWithFlashForStandby()
        }

        return reading
    }

    // MARK: - Wide Angle Standby Snapshot with Flash
    /// Maakt aansluitend op een optische meting een groothoekfoto met flits van de hele kweekruimte voor weergave op het dashboard
    public func captureWideOverviewWithFlashForStandby() async {
        let streamMgr = LiveKitStreamManager.shared
        let camStreamMgr = MycoCamStreamManager.shared

        let isBroadcaster = streamMgr.currentRole == .broadcaster
            || streamMgr.isStreamHubModeActive
            || MycoBackgroundHubManager.shared.isStreamHubRoleActive
            || camStreamMgr.role == .host

        print("[OpticalHygrometer] Triggering wide overview flash snapshot for standby dashboard (isBroadcaster: \(isBroadcaster))")

        if isBroadcaster {
            await streamMgr.selectCameraByType("wide")
            try? await Task.sleep(nanoseconds: 350_000_000)
            _ = await streamMgr.captureAndSaveSnapshot(
                withFlash: true,
                customCaption: "Kweekruimte Overzicht (Optische Scan Flits)",
                cameraType: "wide",
                cameraName: "Kweek (1.0x Groothoek)"
            )
        } else {
            streamMgr.requestWideFlashSnapshot()
            _ = MycoCamPairingManager.shared.sendDirectCommandToPeers("cmd:snapshot:wide:flash")
        }
    }

    // MARK: - Autofocus on Meter / Sensor Display
    /// Richt de camera-autofocus en belichting specifiek op het display van de hygrometer/thermo-sensor
    public func triggerAutofocusOnMeter(at point: CGPoint? = nil) async {
        let streamMgr = LiveKitStreamManager.shared
        let camStreamMgr = MycoCamStreamManager.shared

        let targetPoint: CGPoint = {
            if let p = point { return p }
            if let custom = config.customFocusPoint { return custom }
            let meterROI = config.meterROI ?? NormalizedROI.defaultMeter
            return CGPoint(
                x: meterROI.x + (meterROI.width / 2.0),
                y: meterROI.y + (meterROI.height / 2.0)
            )
        }()

        let clampedX = max(0.05, min(0.95, targetPoint.x))
        let clampedY = max(0.05, min(0.95, targetPoint.y))

        let isBroadcaster = streamMgr.currentRole == .broadcaster
            || streamMgr.isStreamHubModeActive
            || MycoBackgroundHubManager.shared.isStreamHubRoleActive
            || camStreamMgr.role == .host
        let shouldUseLocalCamera = (config.cameraSource == .localDevice) || isBroadcaster

        // Multi-puls autofocus: stuur 3 opeenvolgende focuspulsen (zoals een gebruiker meerdere keren tikt)
        for pulse in 1...3 {
            if shouldUseLocalCamera {
                streamMgr.setFocusPoint(normalizedPoint: CGPoint(x: clampedX, y: clampedY))
            } else {
                streamMgr.sendFocusCommand(x: clampedX, y: clampedY)
                _ = MycoCamPairingManager.shared.sendDirectCommandToPeers(String(format: "focus:%.4f,%.4f", clampedX, clampedY))
            }
            if pulse < 3 {
                try? await Task.sleep(nanoseconds: 180_000_000)
            }
        }

        // Geef het fysieke lensmechanisme 1.0s om scherp te stellen en belichting in te regelen
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    // MARK: - Frame Acquisition met Autofocus, Flits & Kweeklampen
    public func acquireTelephotoFramesWithFocusAndLighting(sampleCount: Int = 3) async -> (images: [UIImage], usedFlash: Bool) {
        detectTelephotoHardware()
        let streamMgr = LiveKitStreamManager.shared
        let camStreamMgr = MycoCamStreamManager.shared

        let isStreamBroadcaster = streamMgr.currentRole == .broadcaster
            || streamMgr.isStreamHubModeActive
            || MycoBackgroundHubManager.shared.isStreamHubRoleActive
            || camStreamMgr.role == .host

        var flashUsed = false
        var previousTorch = false
        var previousLampSwitchedOn: [UUID] = []

        // A. Kweeklampen inschakelen voor heldere belichting tijdens de optische meting
        if config.useGrowLights, let store = MycoStore.shared {
            let lamps = store.db.smartDevices.filter { dev in
                let type = dev.deviceType.lowercased()
                let name = dev.name.lowercased()
                return type == "light" || type == "lamp" || type == "growlight"
                    || name.contains("lamp") || name.contains("licht") || name.contains("light")
                    || name.contains("kweeklamp") || name.contains("groeilamp") || name.contains("led")
            }
            for lamp in lamps {
                if !lamp.isOn {
                    store.setSmartDeviceState(id: lamp.id, isOn: true, trigger: "Optische Meting Belichting (Tijdelijk)")
                    previousLampSwitchedOn.append(lamp.id)
                }
            }
            if !previousLampSwitchedOn.isEmpty {
                scanStatus = "💡 Kweeklampen ingeschakeld voor meting..."
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
        }

        // B. Flitser / Torch inschakelen voor maximaal contrast
        if config.useFlash {
            flashUsed = true
            if isStreamBroadcaster {
                previousTorch = streamMgr.isTorchOn
                streamMgr.setTorch(on: true, level: 1.0)
            } else {
                streamMgr.setTorch(on: true, level: 1.0)
                camStreamMgr.sendTorchCommand(isOn: true, brightness: 1.0)
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        // C. Camera autofocus specifiek richten op de fysieke meter/sensor!
        scanStatus = "🔍 Camera stelt scherp op de meter..."
        await triggerAutofocusOnMeter()

        // D. Hoge resolutie frames vastleggen van de geselecteerde camera
        var capturedImages: [UIImage] = []
        let shouldUseLocalCamera = (config.cameraSource == .localDevice) || isStreamBroadcaster

        if shouldUseLocalCamera {
            scanStatus = "Lokale camera frames vastleggen..."
            let targetTeleId = resolveTelephotoCameraID()
            var didSwitchLocalLens = false

            if let teleId = targetTeleId, streamMgr.selectedCameraID != teleId {
                didSwitchLocalLens = true
                await streamMgr.selectCamera(id: teleId)
                try? await Task.sleep(nanoseconds: 350_000_000)
                await triggerAutofocusOnMeter()
            }

            var trackToUse = streamMgr.localVideoTrack
            if trackToUse == nil {
                trackToUse = await streamMgr.ensureLocalCameraTrackAvailable()
                if let teleId = targetTeleId, streamMgr.selectedCameraID != teleId {
                    await streamMgr.selectCamera(id: teleId)
                    await triggerAutofocusOnMeter()
                }
            }

            if let track = trackToUse {
                for i in 1...sampleCount {
                    scanStatus = "📸 Foto \(i)/\(sampleCount) vastleggen..."
                    let frame: UIImage?
                    if config.useFlash {
                        frame = await streamMgr.captureFrameWithFlash(from: track)
                    } else {
                        frame = await streamMgr.captureCurrentFrame(from: track)
                    }
                    if let f = frame {
                        capturedImages.append(f)
                    }
                    if i < sampleCount {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                }
            }

            if capturedImages.isEmpty, let hostFrame = camStreamMgr.latestHostFrame {
                capturedImages.append(hostFrame)
            }

            if didSwitchLocalLens {
                if let teleId = targetTeleId {
                    config.preferredCameraId = teleId
                    saveConfig()
                }
            }
        } else {
            // "De Kijk" (kijker-telefoon via livestream)
            let targetRoom = streamMgr.resolveTargetCameraRoom()
            if !streamMgr.isConnected || streamMgr.currentRoomName != targetRoom {
                scanStatus = "Verbinden met kweekcamera livestream..."
                await streamMgr.autoConnectToActiveCameraAsViewer()
                for _ in 0..<12 {
                    if streamMgr.isConnected && (streamMgr.remoteVideoTrack != nil || streamMgr.currentRoomName == targetRoom) { break }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }

            // Telelens vergrendelen: Als er een telelens is of geconfigureerd, selecteer die en BLIJF erop!
            if let teleId = resolveRemoteTelephotoCameraID(), streamMgr.remoteActiveCameraID != teleId {
                streamMgr.selectRemoteCamera(id: teleId)
                config.preferredCameraId = teleId
                saveConfig()
                try? await Task.sleep(nanoseconds: 600_000_000)
                await triggerAutofocusOnMeter()
            }

            // PRIORITY 1: Maximale Kwaliteit Native Snapshot van Kweekcamera (100% sensorkwaliteit via chunked transfer)
            scanStatus = config.useFlash ? "📸 Haarscherpe foto met flits ophalen van kweekcamera..." : "📸 Haarscherpe foto ophalen van kweekcamera..."
            streamMgr.lastRemoteSnapshot = nil
            self.lastCapturedPreview = nil
            streamMgr.requestSnapshot(withFlash: config.useFlash)
            camStreamMgr.requestHighResSnapshot()
            _ = MycoCamPairingManager.shared.sendDirectCommandToPeers(config.useFlash ? "cmd:snapshot:flash" : "cmd:snapshot")

            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 150_000_000)
                if let snap = streamMgr.lastRemoteSnapshot {
                    capturedImages.append(snap)
                    scanStatus = "Native resolutie foto ontvangen!"
                    break
                }
                if let snap = self.lastCapturedPreview {
                    capturedImages.append(snap)
                    scanStatus = "Native resolutie foto ontvangen!"
                    break
                }
            }

            // PRIORITY 2 (Fallback): Als snapshot transfer vertraagd is, pak frames uit de 4K/FullHD remote video track
            if capturedImages.isEmpty, let remoteTrack = streamMgr.remoteVideoTrack {
                for i in 1...sampleCount {
                    scanStatus = "📸 Kweekcamera videoframes \(i)/\(sampleCount) vastleggen..."
                    if let frame = await streamMgr.captureCurrentFrame(from: remoteTrack) {
                        capturedImages.append(frame)
                    }
                    if i < sampleCount {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                }
            }

            // Fallback naar reeds gecachete P2P of cloud frame als timeout
            if capturedImages.isEmpty, let p2pFrame = camStreamMgr.receivedFrame {
                capturedImages.append(p2pFrame)
            }
            if capturedImages.isEmpty, let cloudFrame = camStreamMgr.cloudFrame {
                capturedImages.append(cloudFrame)
            }

            // Behoud de telelens (geen terugschakeling naar breedhoek!)
        }

        // E. Flitser / Torch weer herstellen
        if config.useFlash {
            if isStreamBroadcaster {
                streamMgr.setTorch(on: previousTorch, level: 0.8)
            } else {
                streamMgr.setTorch(on: false)
                camStreamMgr.sendTorchCommand(isOn: false)
            }
        }

        // F. Kweeklampen weer herstellen naar hun oorspronkelijke status
        if !previousLampSwitchedOn.isEmpty, let store = MycoStore.shared {
            for lampId in previousLampSwitchedOn {
                if let dev = store.db.smartDevices.first(where: { $0.id == lampId }) {
                    let shouldStayOnInDayCycle = dev.isWithinLightSchedule && !dev.isManualOverrideActive
                    if !shouldStayOnInDayCycle {
                        store.setSmartDeviceState(id: lampId, isOn: false, trigger: "Optische Meting Voltooid (Status Hersteld)")
                    }
                }
            }
        }

        if let first = capturedImages.first, self.lastCapturedPreview == nil {
            self.lastCapturedPreview = first
        }

        return (capturedImages, flashUsed)
    }

    public func acquireTelephotoFrameWithLighting() async -> (image: UIImage?, usedFlash: Bool) {
        let multi = await acquireTelephotoFramesWithFocusAndLighting(sampleCount: 1)
        return (multi.images.first, multi.usedFlash)
    }

    public func captureCalibrationSnapshot() async -> UIImage? {
        await triggerAutofocusOnMeter()
        let (images, _) = await acquireTelephotoFramesWithFocusAndLighting(sampleCount: 3)
        let sharpest = images.max(by: {
            Self.calculateSharpnessScore(image: $0, roi: self.config.meterROI) < Self.calculateSharpnessScore(image: $1, roi: self.config.meterROI)
        }) ?? images.first
        if let sharpest = sharpest {
            self.lastCapturedPreview = sharpest
        }
        return sharpest
    }

    // MARK: - Vision OCR Tekstherkenning & ROI Processing
    /// Herkent cijfers en symbolen van het fysieke thermo/hygrometer LCD display,
    /// met optionele gerichte ROI uitsnedes voor temperatuur en luchtvochtigheid.
    public func recognizeMeterText(image: UIImage, config: OpticalHygrometerConfig? = nil) async -> (humidity: Double?, temperature: Double?, confidence: Double, rawText: String) {
        let details = await recognizeMeterTextDetailed(image: image, config: config)
        return (details.humidity, details.temperature, details.confidence, details.rawText)
    }

    /// Uitgebreide herkenning die ook uitsnedes en debug-kandidaten teruggeeft voor de UI
    public func recognizeMeterTextDetailed(image: UIImage, config: OpticalHygrometerConfig? = nil) async -> OpticalRecognitionDetails {
        let normalizedImage = Self.normalizeImageOrientation(image)
        guard let _ = normalizedImage.cgImage else {
            return OpticalRecognitionDetails(rawText: "Geen geldige beeldata gevonden.")
        }

        let cfg = config ?? self.config
        var detectedTemp: Double? = nil
        var detectedHumidity: Double? = nil
        var rawPieces: [String] = []
        var maxConfidence: Double = 0.85

        var tempCropImg: UIImage? = nil
        var humCropImg: UIImage? = nil
        var meterCropImg: UIImage? = nil
        var tempCandStr = ""
        var humCandStr = ""
        var fullCandStr = ""

        // 0. AI Focus / Display Crop: Als een meterROI is ingesteld, zoomt de AI in en vergroot het scherm
        if let mROI = cfg.meterROI {
            meterCropImg = Self.cropAndEnlargeDisplay(image: normalizedImage, to: mROI)
        }

        // 1. Check gerichte uitsnede voor Temperatuur (Oranje zone) - probeert automatisch alle 4 draaihoeken
        if let tempROI = cfg.temperatureROI, let tempCrop = Self.cropImage(image: normalizedImage, to: tempROI) {
            tempCropImg = tempCrop
            let variants = Self.generateLCDVariants(image: tempCrop)
            var allTempCandidates: [RecognizedCandidate] = []
            let orientations: [CGImagePropertyOrientation] = [.up, .down, .right, .left]
            for orient in orientations {
                var candsForOrient: [RecognizedCandidate] = []
                for cg in variants {
                    let cands = await Self.performVisionOCR(cgImage: cg, orientation: orient)
                    candsForOrient.append(contentsOf: cands)
                }
                allTempCandidates.append(contentsOf: candsForOrient)
                if let t = Self.parseTemperatureFromROICandidates(candsForOrient) {
                    detectedTemp = t
                    maxConfidence = max(maxConfidence, Double(candsForOrient.first?.confidence ?? 0.90))
                    break // Gevonden! Vroegtijdig stoppen voor maximale performance
                }
            }
            if !allTempCandidates.isEmpty {
                let distinctTexts = Array(Set(allTempCandidates.map { $0.text }))
                tempCandStr = distinctTexts.joined(separator: ", ")
                rawPieces.append("Temp: [\(tempCandStr)]")
            }
        }

        // 2. Check gerichte uitsnede voor Luchtvochtigheid (Blauwe zone) - probeert automatisch alle 4 draaihoeken
        if let humROI = cfg.humidityROI, let humCrop = Self.cropImage(image: normalizedImage, to: humROI) {
            humCropImg = humCrop
            let variants = Self.generateLCDVariants(image: humCrop)
            var allHumCandidates: [RecognizedCandidate] = []
            let orientations: [CGImagePropertyOrientation] = [.up, .down, .right, .left]
            for orient in orientations {
                var candsForOrient: [RecognizedCandidate] = []
                for cg in variants {
                    let cands = await Self.performVisionOCR(cgImage: cg, orientation: orient)
                    candsForOrient.append(contentsOf: cands)
                }
                allHumCandidates.append(contentsOf: candsForOrient)
                if let h = Self.parseHumidityFromROICandidates(candsForOrient) {
                    detectedHumidity = h
                    maxConfidence = max(maxConfidence, Double(candsForOrient.first?.confidence ?? 0.90))
                    break // Gevonden! Vroegtijdig stoppen voor snelheid
                }
            }
            if !allHumCandidates.isEmpty {
                let distinctTexts = Array(Set(allHumCandidates.map { $0.text }))
                humCandStr = distinctTexts.joined(separator: ", ")
                rawPieces.append("RV: [\(humCandStr)]")
            }
        }

        // 3. Fallback: Als temperatuur of luchtvochtigheid nog niet gevonden is,
        // scan dan het algemene vergrote display kader (meterROI) of het hele beeld
        if detectedHumidity == nil || detectedTemp == nil {
            let fallbackImage: UIImage
            if let mCrop = meterCropImg {
                fallbackImage = mCrop
            } else if let mROI = cfg.meterROI, let croppedMeter = Self.cropImage(image: normalizedImage, to: mROI) {
                fallbackImage = croppedMeter
            } else {
                fallbackImage = normalizedImage
            }

            let fbVariants = Self.generateLCDVariants(image: fallbackImage)
            var allFallbackCandidates: [RecognizedCandidate] = []
            let orientations: [CGImagePropertyOrientation] = [.up, .down, .right, .left]
            for orient in orientations {
                var candsForOrient: [RecognizedCandidate] = []
                for cg in fbVariants {
                    let cands = await Self.performVisionOCR(cgImage: cg, orientation: orient)
                    candsForOrient.append(contentsOf: cands)
                }
                allFallbackCandidates.append(contentsOf: candsForOrient)
                let parsed = Self.parseMeterReadings(from: candsForOrient)
                if detectedHumidity == nil, let h = parsed.humidity {
                    detectedHumidity = h
                }
                if detectedTemp == nil, let t = parsed.temperature {
                    detectedTemp = t
                }
                if detectedHumidity != nil && detectedTemp != nil {
                    maxConfidence = max(maxConfidence, parsed.confidence)
                    break
                }
            }

            if !allFallbackCandidates.isEmpty {
                let distinctTexts = Array(Set(allFallbackCandidates.map { $0.text }))
                fullCandStr = distinctTexts.joined(separator: ", ")
                let parsed = Self.parseMeterReadings(from: allFallbackCandidates)

                if detectedHumidity == nil {
                    detectedHumidity = parsed.humidity
                }
                if detectedTemp == nil {
                    detectedTemp = parsed.temperature
                }
                if !parsed.rawText.isEmpty {
                    rawPieces.append("Meter: [\(parsed.rawText)]")
                }
                maxConfidence = max(maxConfidence, parsed.confidence)
            }
        }

        let combinedRaw = rawPieces.joined(separator: " | ")
        return OpticalRecognitionDetails(
            humidity: detectedHumidity,
            temperature: detectedTemp,
            confidence: maxConfidence,
            rawText: combinedRaw,
            tempCropImage: tempCropImg,
            humCropImage: humCropImg,
            meterCropImage: meterCropImg,
            tempCandidatesText: tempCandStr,
            humCandidatesText: humCandStr,
            fullDisplayCandidatesText: fullCandStr
        )
    }

    // Reusable thread-safe CoreImage context voor razendsnelle randdetectie en beeldanalyse
    nonisolated private static let sharedAnalysisCIContext = CIContext(options: [CIContextOption.useSoftwareRenderer: false])

    /// Berekent de optische scherptescore (randcontrast via CoreImage CIEdges + CIAreaAverage)
    /// op het geselecteerde displaygebied (of het centrum van het beeld). Hogere score = scherpere focus.
    nonisolated public static func calculateSharpnessScore(image: UIImage, roi: NormalizedROI? = nil) -> Double {
        let normalized = normalizeImageOrientation(image)
        guard let cg = normalized.cgImage else { return 0.0 }

        let width = Double(cg.width)
        let height = Double(cg.height)
        guard width > 10, height > 10 else { return 0.0 }

        let targetRect: CGRect
        if let r = roi {
            targetRect = CGRect(
                x: r.x * width,
                y: r.y * height,
                width: r.width * width,
                height: r.height * height
            ).integral
        } else {
            targetRect = CGRect(
                x: 0.15 * width,
                y: 0.15 * height,
                width: 0.70 * width,
                height: 0.70 * height
            ).integral
        }

        guard let cropped = cg.cropping(to: targetRect) else { return 0.0 }
        let ciImg = CIImage(cgImage: cropped)

        guard let edgeFilter = CIFilter(name: "CIEdges") else { return 0.0 }
        edgeFilter.setValue(ciImg, forKey: kCIInputImageKey)
        edgeFilter.setValue(2.0, forKey: kCIInputIntensityKey)

        guard let edgeOut = edgeFilter.outputImage else { return 0.0 }

        guard let avgFilter = CIFilter(name: "CIAreaAverage") else { return 0.0 }
        avgFilter.setValue(edgeOut, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: edgeOut.extent), forKey: kCIInputExtentKey)

        guard let avgOut = avgFilter.outputImage else { return 0.0 }

        var pixel = [UInt8](repeating: 0, count: 4)
        sharedAnalysisCIContext.render(
            avgOut,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        return (0.299 * r) + (0.587 * g) + (0.114 * b)
    }

    /// Roteert een afbeelding met 90 graden met de klok mee (handig als sensor gekanteld staat)
    nonisolated public static func rotateImage90Degrees(_ image: UIImage) -> UIImage {
        let targetSize = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            cgCtx.translateBy(x: targetSize.width / 2.0, y: targetSize.height / 2.0)
            cgCtx.rotate(by: .pi / 2.0)
            image.draw(in: CGRect(x: -image.size.width / 2.0, y: -image.size.height / 2.0, width: image.size.width, height: image.size.height))
        }
    }

    /// Garandeert dat een UIImage altijd de fysieke .up orientatie heeft
    /// zodat SwiftUI coördinaten 1:1 overeenkomen met CoreGraphics pixelcoördinaten.
    nonisolated public static func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Snijdt een sub-afbeelding uit met veilige padding zodat buitenranden van cijfers niet afgekapt worden
    nonisolated public static func cropImage(image: UIImage, to roi: NormalizedROI, paddingFraction: Double = 0.03) -> UIImage? {
        let normalized = normalizeImageOrientation(image)
        guard let cg = normalized.cgImage else { return nil }
        let imgW = CGFloat(cg.width)
        let imgH = CGFloat(cg.height)

        let padX = CGFloat(roi.width * paddingFraction) * imgW
        let padY = CGFloat(roi.height * paddingFraction) * imgH

        let rawX = (CGFloat(roi.x) * imgW) - padX
        let rawY = (CGFloat(roi.y) * imgH) - padY
        let rawW = (CGFloat(roi.width) * imgW) + (padX * 2)
        let rawH = (CGFloat(roi.height) * imgH) + (padY * 2)

        let cropX = max(0.0, min(imgW - 10.0, rawX))
        let cropY = max(0.0, min(imgH - 10.0, rawY))
        let cropW = max(10.0, min(imgW - cropX, rawW))
        let cropH = max(10.0, min(imgH - cropY, rawH))

        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
        guard let croppedCg = cg.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: croppedCg, scale: 1.0, orientation: .up)
    }

    /// Zooms in on the user's selected LCD display region, upscales it with high-definition bicubic interpolation,
    /// and enhances contrast/sharpness so the AI can inspect the numbers up close.
    nonisolated public static func cropAndEnlargeDisplay(image: UIImage, to roi: NormalizedROI, upscaleFactor: CGFloat = 2.5) -> UIImage? {
        guard let baseCrop = cropImage(image: image, to: roi, paddingFraction: 0.04) else { return nil }
        guard let cg = baseCrop.cgImage else { return baseCrop }

        let targetWidth = CGFloat(cg.width) * upscaleFactor
        let targetHeight = CGFloat(cg.height) * upscaleFactor
        let newSize = CGSize(width: max(320.0, targetWidth), height: max(220.0, targetHeight))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let enlarged = renderer.image { ctx in
            ctx.cgContext.interpolationQuality = .high
            baseCrop.draw(in: CGRect(origin: .zero, size: newSize))
        }

        if let ci = CIImage(image: enlarged) {
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(ci, forKey: kCIInputImageKey)
            filter?.setValue(1.30, forKey: kCIInputContrastKey)
            filter?.setValue(0.04, forKey: kCIInputBrightnessKey)

            let sharpen = CIFilter(name: "CIUnsharpMask")
            sharpen?.setValue(filter?.outputImage ?? ci, forKey: kCIInputImageKey)
            sharpen?.setValue(0.8, forKey: kCIInputIntensityKey)
            sharpen?.setValue(2.0, forKey: kCIInputRadiusKey)

            let context = CIContext(options: nil)
            if let output = sharpen?.outputImage ?? filter?.outputImage,
               let filteredCg = context.createCGImage(output, from: output.extent) {
                return UIImage(cgImage: filteredCg, scale: 1.0, orientation: .up)
            }
        }

        return enlarged
    }

    /// Detects the hygrometer LCD display in the image using Vision digit/symbol cluster recognition
    nonisolated public static func autoDetectDisplayROI(in image: UIImage) async -> NormalizedROI? {
        let normalized = normalizeImageOrientation(image)
        guard let cg = normalized.cgImage else { return nil }

        // Methode 1: Geometric Rectangle Detection (vindt de rechthoekige LCD display rand)
        let rectRequest = VNDetectRectanglesRequest()
        rectRequest.minimumAspectRatio = 0.35
        rectRequest.maximumAspectRatio = 2.8
        rectRequest.minimumSize = 0.06
        rectRequest.maximumObservations = 6

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([rectRequest])

        if let observations = rectRequest.results, !observations.isEmpty {
            // Sorteer op relevantie: oppervlakte tussen 1.5% en 75% van het beeld
            let valid = observations.filter { obs in
                let w = obs.boundingBox.width
                let h = obs.boundingBox.height
                let area = w * h
                return area > 0.015 && area < 0.75
            }
            var bestObservation: VNRectangleObservation? = nil
            var maxScore: Double = -1.0
            for obs in valid {
                let area = Double(obs.boundingBox.width * obs.boundingBox.height)
                let score = Double(obs.confidence) * area
                if score > maxScore {
                    maxScore = score
                    bestObservation = obs
                }
            }
            if let best = bestObservation {
                // Vision boundingBox has origin at bottom-left; convert naar top-left SwiftUI:
                let b = best.boundingBox
                let normX = Double(b.minX)
                let normY = Double(1.0 - b.maxY)
                let normW = Double(b.width)
                let normH = Double(b.height)

                let padX = normW * 0.03
                let padY = normH * 0.03
                return NormalizedROI(
                    x: min(1.0, max(0.0, normX + padX)),
                    y: min(1.0, max(0.0, normY + padY)),
                    width: max(0.05, normW - (padX * 2)),
                    height: max(0.05, normH - (padY * 2))
                )
            }
        }

        // Methode 2 (Fallback): OCR Text/Digits Clustering
        let candidates = await performVisionOCR(cgImage: cg)
        let relevant = candidates.filter { cand in
            cand.text.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
                || cand.text.contains("%")
                || cand.text.contains("°")
                || cand.text.contains("C")
        }

        guard !relevant.isEmpty else { return nil }

        var minX: Double = 1.0
        var minY: Double = 1.0
        var maxX: Double = 0.0
        var maxY: Double = 0.0

        for cand in relevant {
            let b = cand.boundingBox
            minX = min(minX, Double(b.origin.x))
            minY = min(minY, Double(b.origin.y))
            maxX = max(maxX, Double(b.origin.x + b.size.width))
            maxY = max(maxY, Double(b.origin.y + b.size.height))
        }

        guard maxX > minX, maxY > minY else { return nil }

        // Add comfortable display bezel padding around the detected digits
        let padX = max(0.03, (maxX - minX) * 0.22)
        let padY = max(0.03, (maxY - minY) * 0.25)

        let finalX = max(0.0, minX - padX)
        let finalY = max(0.0, minY - padY)
        let finalW = min(1.0 - finalX, (maxX - minX) + (padX * 2))
        let finalH = min(1.0 - finalY, (maxY - minY) + (padY * 2))

        return NormalizedROI(x: finalX, y: finalY, width: finalW, height: finalH)
    }

    /// Genereert geoptimaliseerde varianten van een LCD uitsnede voor robuuste 7-segment cijferherkenning
    nonisolated public static func generateLCDVariants(image: UIImage) -> [CGImage] {
        var variants: [CGImage] = []
        guard let baseCg = image.cgImage else { return variants }
        variants.append(baseCg)

        // 1. Zorg voor voldoende resolutie (upscalen als uitsnede klein is voor Apple Vision neuraal netwerk)
        let targetMinHeight: CGFloat = 260.0
        let currentH = CGFloat(baseCg.height)
        let scaleFactor: CGFloat = currentH < targetMinHeight ? (targetMinHeight / currentH) : 1.0

        let upscaledImage: UIImage
        if scaleFactor > 1.05 {
            let newSize = CGSize(width: CGFloat(baseCg.width) * scaleFactor, height: currentH * scaleFactor)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            upscaledImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            if let upCg = upscaledImage.cgImage {
                variants.append(upCg)
            }
        } else {
            upscaledImage = image
        }

        guard let ciInput = CIImage(image: upscaledImage) else { return variants }
        let ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer: false])

        // Variant 1: Verscherpen (benadrukt dunne LCD segment-randen)
        if let sharpen = CIFilter(name: "CISharpenLuminance") {
            sharpen.setValue(ciInput, forKey: kCIInputImageKey)
            sharpen.setValue(1.6, forKey: kCIInputSharpnessKey)
            if let outSharp = sharpen.outputImage,
               let cgSharp = ciContext.createCGImage(outSharp, from: outSharp.extent) {
                variants.append(cgSharp)
            }
        }

        // Variant 2: Monochroom + Hoog Contrast (versterkt donkere LCD segmenten tegen lichte achtergrond)
        if let mono = CIFilter(name: "CIColorMonochrome") {
            mono.setValue(ciInput, forKey: kCIInputImageKey)
            mono.setValue(CIColor(red: 0.5, green: 0.5, blue: 0.5), forKey: kCIInputColorKey)
            mono.setValue(1.0, forKey: kCIInputIntensityKey)
            if let monoOut = mono.outputImage,
               let controls = CIFilter(name: "CIColorControls") {
                controls.setValue(monoOut, forKey: kCIInputImageKey)
                controls.setValue(2.6, forKey: kCIInputContrastKey)
                controls.setValue(-0.10, forKey: kCIInputBrightnessKey)
                if let outImg = controls.outputImage,
                   let cgOut = ciContext.createCGImage(outImg, from: outImg.extent) {
                    variants.append(cgOut)
                }
            }
        }

        // Variant 3: Lichte Gaussian blur om segment-onderbrekingen van 7-segment cijfers te overbruggen
        if let lastCg = variants.last,
           let ciLast = CIImage(image: UIImage(cgImage: lastCg)),
           let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(ciLast, forKey: kCIInputImageKey)
            blur.setValue(0.6, forKey: kCIInputRadiusKey)
            if let outBlur = blur.outputImage,
               let cgBlur = ciContext.createCGImage(outBlur, from: ciLast.extent) {
                variants.append(cgBlur)
            }
        }

        // Variant 4: Geïnverteerd met versterkt contrast (voor witte/lichte cijfers op donker LCD display)
        if let invert = CIFilter(name: "CIColorInvert") {
            invert.setValue(ciInput, forKey: kCIInputImageKey)
            if let invOut = invert.outputImage,
               let invControls = CIFilter(name: "CIColorControls") {
                invControls.setValue(invOut, forKey: kCIInputImageKey)
                invControls.setValue(2.4, forKey: kCIInputContrastKey)
                invControls.setValue(-0.05, forKey: kCIInputBrightnessKey)
                if let outInv = invControls.outputImage,
                   let cgInv = ciContext.createCGImage(outInv, from: outInv.extent) {
                    variants.append(cgInv)
                }
            }
        }

        return variants
    }

    /// Voert Apple Vision OCR uit en extraheert top 5 kandidaten per tekstregel (ondersteunt alle 4 oriëntaties: 0°, 90°, 180°, 270°)
    nonisolated public static func performVisionOCR(cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) async -> [RecognizedCandidate] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { req, err in
                    guard err == nil, let observations = req.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: [])
                        return
                    }
                    var results: [RecognizedCandidate] = []
                    for obs in observations {
                        let vBox = obs.boundingBox
                        let uiBox = CGRect(x: vBox.origin.x, y: 1.0 - (vBox.origin.y + vBox.height), width: vBox.width, height: vBox.height)
                        for candidate in obs.topCandidates(5) {
                            let str = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !str.isEmpty {
                                results.append(RecognizedCandidate(text: str, confidence: candidate.confidence, boundingBox: uiBox))
                            }
                        }
                    }
                    continuation.resume(returning: results)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.automaticallyDetectsLanguage = false
                request.recognitionLanguages = ["en-US"]
                if #available(iOS 16.0, *) {
                    request.customWords = ["%", "°C", "°F", "C", "RH", "%RH", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "."]
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Herstelt veelvoorkomende OCR verwarringen bij 7-segment LCD cijfers
    nonisolated public static func repairSevenSegmentCandidates(_ raw: String) -> [String] {
        var variants: [String] = [raw]

        var s1 = raw
        // Letters die vaak worden verward met cijfers
        s1 = s1.replacingOccurrences(of: "[Ss$]", with: "5", options: .regularExpression)
        s1 = s1.replacingOccurrences(of: "[Zz]", with: "2", options: .regularExpression)
        s1 = s1.replacingOccurrences(of: "[OoDQU]", with: "0", options: .regularExpression)
        s1 = s1.replacingOccurrences(of: "[Il|!/\\\\]", with: "1", options: .regularExpression)
        s1 = s1.replacingOccurrences(of: "[Bb&]", with: "8", options: .regularExpression)
        s1 = s1.replacingOccurrences(of: "[gq]", with: "9", options: .regularExpression)
        s1 = s1.replacingOccurrences(of: "[Aah]", with: "4", options: .regularExpression)
        s1 = s1.replacingOccurrences(of: "[+rTt]", with: "7", options: .regularExpression)
        // Decimale leestekens
        s1 = s1.replacingOccurrences(of: "[:,;'`·]", with: ".", options: .regularExpression)
        s1 = s1.replacingOccurrences(of: ",", with: ".")
        // Spaties tussen 2 cijfers en 1 decimaal cijfer (bv. "23 4" -> "23.4", "23 . 4" -> "23.4")
        s1 = s1.replacingOccurrences(of: #"(\d{2})\s*\.\s*(\d{1})\b"#, with: "$1.$2", options: .regularExpression)
        s1 = s1.replacingOccurrences(of: #"(\d{2})\s+(\d{1})\b"#, with: "$1.$2", options: .regularExpression)
        // % symbool herstel
        s1 = s1.replacingOccurrences(of: #"[0oO°]/[0oO]"#, with: "%", options: .regularExpression)

        if s1 != raw {
            variants.append(s1)
        }

        let digitsAndDots = s1.replacingOccurrences(of: #"[^0-9.]"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if !digitsAndDots.isEmpty && digitsAndDots != s1 {
            variants.append(digitsAndDots)
        }

        return variants
    }

    nonisolated public static func parseTemperatureFromROICandidates(_ candidates: [RecognizedCandidate]) -> Double? {
        // 1. Directe check op originele kandidaatteksten (zonder letters te verminken)
        let rawCandidates = candidates.map { $0.text }
        let primaryPatterns = [
            #"([0-4]?[0-9][.,][0-9])\s*(?:°|º|o|O|\*|\^)?\s*[Cc]?"#, // bv. 21.4, 21.4°C, 21.4 C, 21.4°
            #"([0-4]?[0-9])\s*(?:°|º)\s*[Cc]?"#,                     // bv. 23°, 23°C
            #"([0-4]?[0-9])\s*[Cc]\b"#,                              // bv. 23C
            #"([5-9][0-9](?:[.,][0-9])?)\s*°?\s*F"#                 // Fahrenheit
        ]

        for str in rawCandidates {
            for pattern in primaryPatterns {
                if let val = extractFirstMatch(pattern: pattern, in: str) {
                    if pattern.contains("F") {
                        let cVal = (val - 32.0) * (5.0 / 9.0)
                        if cVal >= 10.0 && cVal <= 45.0 {
                            return (cVal * 10.0).rounded() / 10.0
                        }
                    } else if val >= 10.0 && val <= 45.0 {
                        return (val * 10.0).rounded() / 10.0
                    }
                }
            }
        }

        // 2. Herstelde 7-segment kandidaten
        var repairedStrings: [String] = []
        for c in candidates {
            repairedStrings.append(contentsOf: repairSevenSegmentCandidates(c.text))
        }

        for str in repairedStrings {
            for pattern in primaryPatterns {
                if let val = extractFirstMatch(pattern: pattern, in: str) {
                    if pattern.contains("F") {
                        let cVal = (val - 32.0) * (5.0 / 9.0)
                        if cVal >= 10.0 && cVal <= 45.0 {
                            return (cVal * 10.0).rounded() / 10.0
                        }
                    } else if val >= 10.0 && val <= 45.0 {
                        return (val * 10.0).rounded() / 10.0
                    }
                }
            }
        }

        // 3. Token-niveau analyse binnen het temperatuur-uitsnedevak (tempROI)
        for str in (rawCandidates + repairedStrings) {
            let tokens = str.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "°º*CcFf ")))
            for tok in tokens {
                let cleaned = tok.replacingOccurrences(of: ",", with: ".")
                // Direct decimaal getal (bv. "22.4")
                if let val = Double(cleaned), val >= 10.0 && val <= 45.0 {
                    return (val * 10.0).rounded() / 10.0
                }
                // 3 cijfers zonder punt op LCD (bv. "224" -> 22.4, "238" -> 23.8)
                if cleaned.count == 3, let intVal = Int(cleaned), intVal >= 120 && intVal <= 420 {
                    return Double(intVal) / 10.0
                }
                // 2 cijfers geheel getal binnen temperatuurbereik (bv. "23")
                if cleaned.count == 2, let intVal = Int(cleaned), intVal >= 15 && intVal <= 35 {
                    return Double(intVal)
                }
            }
        }

        return nil
    }

    nonisolated public static func parseHumidityFromROICandidates(_ candidates: [RecognizedCandidate]) -> Double? {
        var allStrings: [String] = []
        for c in candidates {
            allStrings.append(contentsOf: repairSevenSegmentCandidates(c.text))
        }

        let explicitPatterns = [
            #"(?:RH\s*)?([1-9][0-9](?:[.,][0-9])?)\s*%"#,
            #"([1-9][0-9](?:[.,][0-9])?)\s*%\s*RH"#,
            #"([1-9][0-9])\s*RH"#,
            #"\b([1-9][0-9](?:[.,][0-9])?)\b"#,
            #"^100(?:\.0)?%?$"#
        ]

        // 1. Expliciet patroon
        for str in allStrings {
            for pattern in explicitPatterns {
                if let val = extractFirstMatch(pattern: pattern, in: str) {
                    if val >= 15.0 && val <= 100.0 {
                        return (val * 10.0).rounded() / 10.0
                    }
                }
            }
        }

        // 2. Token fallback binnen luchtvochtigheid bereik (15 ... 100)
        for str in allStrings {
            let tokens = str.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "%RHrh ")))
            for tok in tokens {
                let cleaned = tok.replacingOccurrences(of: ",", with: ".")
                if let val = Double(cleaned), val >= 15.0 && val <= 100.0 {
                    return (val * 10.0).rounded() / 10.0
                }
                // Drie aaneengesloten cijfers met weggelaten punt (bv. "885" -> 88.5)
                if cleaned.count == 3, let intVal = Int(cleaned), intVal >= 150 && intVal <= 999 {
                    return Double(intVal) / 10.0
                }
            }
        }

        return nil
    }

    /// Slimme parser voor fysieke thermo- & hygrometer displays
    nonisolated public static func parseMeterReadings(from candidates: [RecognizedCandidate]) -> (humidity: Double?, temperature: Double?, confidence: Double, rawText: String) {
        let combined = candidates.map { $0.text }.joined(separator: " \n ")
        var foundHumidity: Double? = nil
        var foundTemperature: Double? = nil
        var highestConf: Double = 0.85

        for item in candidates {
            let line = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            highestConf = max(highestConf, Double(item.confidence))
            let repairedList = repairSevenSegmentCandidates(line)

            // 1. Luchtvochtigheid (% of RH)
            if foundHumidity == nil {
                let rhPatterns = [
                    #"(?:RH\s*)?([2-9][0-9](?:\.[0-9])?)\s*%\s*(?:RH)?"#,
                    #"([2-9][0-9])\s*%\s*RH"#,
                    #"\b([3-9][0-9])\s*%"#,
                    #"HUMIDITY\s*([2-9][0-9])"#
                ]
                for rep in repairedList {
                    for pattern in rhPatterns {
                        if let val = extractFirstMatch(pattern: pattern, in: rep) {
                            if val >= 15.0 && val <= 99.9 {
                                foundHumidity = val
                                break
                            }
                        }
                    }
                    if foundHumidity != nil { break }
                }
            }

            // 2. Temperatuur (°C of °F)
            if foundTemperature == nil {
                let tempPatterns = [
                    #"([1-3][0-9](?:\.[0-9])?)\s*°\s*C"#,
                    #"([1-3][0-9](?:\.[0-9])?)\s*C\b"#,
                    #"([1-3][0-9]\.[0-9])\s*°"#,
                    #"([5-9][0-9](?:\.[0-9])?)\s*°\s*F"#
                ]
                for rep in repairedList {
                    for pattern in tempPatterns {
                        if let val = extractFirstMatch(pattern: pattern, in: rep) {
                            if pattern.contains("F") {
                                let cVal = (val - 32.0) * (5.0 / 9.0)
                                if cVal >= 10.0 && cVal <= 45.0 {
                                    foundTemperature = (cVal * 10.0).rounded() / 10.0
                                    break
                                }
                            } else if val >= 10.0 && val <= 45.0 {
                                foundTemperature = val
                                break
                            }
                        }
                    }
                    if foundTemperature != nil { break }
                }
            }
        }

        // Fallback: cijfers op basis van bereik
        if foundHumidity == nil {
            for item in candidates {
                for rep in repairSevenSegmentCandidates(item.text) {
                    let cleaned = rep.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                    if let intVal = Double(cleaned), intVal >= 25.0 && intVal <= 99.0 {
                        foundHumidity = intVal
                        break
                    }
                }
                if foundHumidity != nil { break }
            }
        }

        if foundTemperature == nil {
            for item in candidates {
                for rep in repairSevenSegmentCandidates(item.text) {
                    let cleaned = rep.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                    if let val = Double(cleaned), val >= 12.0 && val <= 38.0 {
                        foundTemperature = val
                        break
                    }
                }
                if foundTemperature != nil { break }
            }
        }

        return (foundHumidity, foundTemperature, highestConf, combined)
    }

    nonisolated private static func extractFirstMatch(pattern: String, in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else { return nil }
        let matchRange = match.range(at: 1)
        if let swiftRange = Range(matchRange, in: text) {
            let numberString = String(text[swiftRange]).replacingOccurrences(of: ",", with: ".")
            return Double(numberString)
        }
        return nil
    }

    // MARK: - 3. VOORUITBEREKENING BEVOCHTIGERDUUR (CRUCIAAL)
    /// Berekent exact hoeveel seconden de bevochtiger moet draaien om het tekort op te vangen.
    /// Waarom vooraf? Zodra de nevel aangaat, beslaan de display en lens, waardoor realtime
    /// aflezen onmogelijk is tot de mist is opgetrokken.
    public func calculateHumidifierDuration(
        currentRH: Double,
        targetRH: Double,
        fanDurationMinutes: Double? = nil
    ) -> (seconds: Int, waterMl: Double, explanation: String) {
        let deltaRH = targetRH - currentRH

        // Dode zone van 1.5%: als we al binnen 1.5% van het doel zijn én ventilator niet lang heeft gedraaid, hoeft bevochtiger niet aan
        guard deltaRH > 1.5 || (fanDurationMinutes != nil && fanDurationMinutes! >= 1.0) else {
            return (0, 0.0, "Reeds op peil (afwijking < 1.5%)")
        }

        let effectiveDelta = max(2.0, deltaRH)

        // Fysische constante:
        // Bij 20-24°C bevat 100% verzadigde lucht ~19.4 g (ml) water per m³.
        // Dus 1% RV stijging per m³ vereist ~0.194 ml waterdamp.
        let baseWaterMlPerM3PerPct = 0.195

        // Volume van de kweekruimte in m³ (automatisch gekoppeld aan Kweekruimte AI)
        let volumeM3: Double = {
            if config.useGrowSpaceSync, let env = MycoStore.shared?.db.environmentConfig, env.roomVolumeM3 > 0.01 {
                return env.roomVolumeM3
            }
            return max(0.02, config.chamberVolumeM3)
        }()

        // Absorptiefactor: tentwanden, substraat en lichte luchtverversing nemen een deel op
        let absorption = max(1.0, config.absorptionEfficiency)

        // Ventilatie-compensatie: hoe langer de ventilator heeft gedraaid, hoe meer vocht er uit de tent en oppervlaktes is onttrokken
        let fanComp: Double = {
            guard let mins = fanDurationMinutes, mins > 0 else { return 1.0 }
            return min(1.65, 1.0 + (mins * 0.065))
        }()

        // Totaal benodigde waterdamp in ml
        let netWaterNeededMl = volumeM3 * effectiveDelta * baseWaterMlPerM3PerPct * absorption * fanComp

        // Bevochtiger vermogen in ml per seconde (automatisch gekoppeld aan Kweekruimte AI)
        let effectiveOutputMlH: Double = {
            if config.useGrowSpaceSync, let env = MycoStore.shared?.db.environmentConfig, env.humidifierOutputMlH > 0 {
                return env.humidifierOutputMlH
            }
            return max(50.0, config.humidifierOutputMlH)
        }()
        let mlPerSecond = effectiveOutputMlH / 3600.0

        // Berekende duur in seconden
        let rawDurationSeconds = netWaterNeededMl / mlPerSecond

        // Veiligheidsklemmen: minimaal minRunDurationSeconds en maximaal maxRunDurationSeconds
        let clampedDuration = max(
            config.minRunDurationSeconds,
            min(config.maxRunDurationSeconds, Int(rawDurationSeconds.rounded()))
        )

        let fanText = fanDurationMinutes != nil ? String(format: " + %.1fm ventilatie", fanDurationMinutes!) : ""
        let expNl = "Δ\(Int(effectiveDelta))% RV\(fanText) in \(String(format: "%.2f", volumeM3)) m³ vereist \(String(format: "%.1f", netWaterNeededMl)) ml nevel (@ \(Int(effectiveOutputMlH)) ml/u) = \(clampedDuration)s (AI Kweekruimte Model)"

        return (clampedDuration, (netWaterNeededMl * 10).rounded() / 10, expNl)
    }

    /// Directe vochtherstel berekening specifiek voor na ventilatie (werkt zowel met als zonder gekoppelde camera)
    public func calculateHumidifierDurationForFan(
        fanDurationMinutes: Double,
        targetRH: Double,
        currentRH: Double? = nil
    ) -> (seconds: Int, waterMl: Double, explanation: String) {
        let volumeM3: Double = {
            if let env = MycoStore.shared?.db.environmentConfig, env.roomVolumeM3 > 0.01 {
                return env.roomVolumeM3
            }
            return max(0.02, config.chamberVolumeM3)
        }()
        let effectiveOutputMlH: Double = {
            if let env = MycoStore.shared?.db.environmentConfig, env.humidifierOutputMlH > 0 {
                return env.humidifierOutputMlH
            }
            return max(50.0, config.humidifierOutputMlH)
        }()
        let absorption = max(1.0, config.absorptionEfficiency)
        let baseWaterMlPerM3PerPct = 0.195

        let deltaRH: Double
        let isEstimated: Bool
        if let liveRH = currentRH {
            deltaRH = max(2.5, targetRH - liveRH)
            isEstimated = false
        } else {
            // Ventilatie vervangt tentlucht met drogere kamerlucht (~50% RV)
            let maxDrop = max(10.0, targetRH - 50.0)
            let drop = min(maxDrop, max(8.0, fanDurationMinutes * 4.5))
            deltaRH = drop
            isEstimated = true
        }

        let fanComp = min(1.65, 1.0 + (fanDurationMinutes * 0.065))
        let netWaterNeededMl = volumeM3 * deltaRH * baseWaterMlPerM3PerPct * absorption * fanComp
        let mlPerSecond = effectiveOutputMlH / 3600.0
        let rawDurationSeconds = netWaterNeededMl / mlPerSecond

        let clampedDuration = max(
            config.minRunDurationSeconds,
            min(config.maxRunDurationSeconds, Int(rawDurationSeconds.rounded()))
        )

        let isEnglish = Locale.current.language.languageCode?.identifier == "en"
        let explanation: String
        if isEstimated {
            explanation = isEnglish
                ? "\(String(format: "%.1f", fanDurationMinutes))m ventilation estimated drop Δ\(Int(deltaRH))% RH → \(clampedDuration)s mist (\(String(format: "%.1f", netWaterNeededMl))ml) to reach \(Int(targetRH))%"
                : "\(String(format: "%.1f", fanDurationMinutes))m ventilatie schatting Δ\(Int(deltaRH))% RV → \(clampedDuration)s nevel (\(String(format: "%.1f", netWaterNeededMl))ml) om \(Int(targetRH))% te herstellen"
        } else {
            explanation = isEnglish
                ? "Measured RH after \(String(format: "%.1f", fanDurationMinutes))m fan: Δ\(Int(deltaRH))% RH → \(clampedDuration)s mist (\(String(format: "%.1f", netWaterNeededMl))ml) to reach \(Int(targetRH))%"
                : "Gemeten RV na \(String(format: "%.1f", fanDurationMinutes))m fan: Δ\(Int(deltaRH))% RV → \(clampedDuration)s nevel (\(String(format: "%.1f", netWaterNeededMl))ml) om \(Int(targetRH))% te herstellen"
        }

        return (clampedDuration, (netWaterNeededMl * 10).rounded() / 10, explanation)
    }

    // MARK: - 4. Bevochtiger Actuator & Nevel-Herstelperiode
    private func executeHumidifierReaction(durationSeconds: Int, reading: OpticalMeterReading) {
        guard let store = MycoStore.shared else { return }

        // Zoek de bevochtiger stekker met slimme fallbacks
        let targetDeviceId: UUID?
        if let selectedId = config.selectedHumidifierDeviceId,
           store.db.smartDevices.contains(where: { $0.id == selectedId }) {
            targetDeviceId = selectedId
        } else if let hum = store.db.smartDevices.first(where: { $0.deviceType == "Humidifier" && $0.autoControlEnabled }) {
            targetDeviceId = hum.id
        } else if let hum = store.db.smartDevices.first(where: { $0.deviceType == "Humidifier" }) {
            targetDeviceId = hum.id
        } else if let namedHum = store.db.smartDevices.first(where: {
            $0.deviceType != "Sensor" && $0.deviceType != "Light" && (
                $0.name.localizedCaseInsensitiveContains("bevocht") ||
                $0.name.localizedCaseInsensitiveContains("humid") ||
                $0.name.localizedCaseInsensitiveContains("mist") ||
                $0.name.localizedCaseInsensitiveContains("nevel") ||
                $0.name.localizedCaseInsensitiveContains("rv")
            )
        }) {
            targetDeviceId = namedHum.id
        } else {
            targetDeviceId = nil
        }

        // SMART INTERLOCK: Schakel eventuele actieve afzuigers/ventilators direct uit voor nevel start
        for fan in store.db.smartDevices.filter({ $0.deviceType == "ExhaustFan" && $0.isOn }) {
            store.setSmartDeviceState(id: fan.id, isOn: false, trigger: "Slimme Vergrendeling (Nevel Actief)", relayToHub: true)
        }

        // Synchroniseer de meting naar de 24/7 Pi Hub zodat ook de Pi op de hoogte is van de actuele RV
        let effectiveTargetRH = (MycoStore.shared?.db.environmentConfig.targetHumidityPct ?? config.targetHumidityPct)
        store.sendClimateReadingToPiHub(
            humidity: reading.humidityPct,
            temperature: reading.temperatureC,
            targetHumidity: effectiveTargetRH
        )

        guard let humId = targetDeviceId,
              store.db.smartDevices.contains(where: { $0.id == humId }) else {
            scanStatus = "Gelezen: \(Int(reading.humidityPct))% RV. Looptijd \(durationSeconds)s (Geen bevochtiger gekoppeld)"
            return
        }

        // Schakel bevochtiger AAN
        let triggerMsg = "Tele-Sensor OCR Autopilot (\(durationSeconds)s)"
        store.setSmartDeviceState(id: humId, isOn: true, trigger: triggerMsg)
        self.isHumidifierRunning = true
        self.humidifierRemainingSeconds = durationSeconds

        // Start afteller voor uitschakeling
        humidifierCountdownTimer?.cancel()
        humidifierCountdownTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.humidifierRemainingSeconds > 1 {
                    self.humidifierRemainingSeconds -= 1
                } else {
                    self.humidifierCountdownTimer?.cancel()
                    self.humidifierCountdownTimer = nil
                    self.humidifierRemainingSeconds = 0
                    self.isHumidifierRunning = false

                    // Schakel bevochtiger UIT
                    store.setSmartDeviceState(id: humId, isOn: false, trigger: "Tele-Sensor OCR Voltooid")

                    // Start Nevel-Herstelperiode (Fog Settling Window)
                    self.startFogSettlingWindow()
                }
            }
    }

    private func startFogSettlingWindow() {
        self.isFogSettling = true
        self.fogSettlingRemainingSeconds = max(60, config.fogSettlingDurationMinutes * 60)
        self.scanStatus = "Nevel trekt op... Meterdisplay is tijdelijk beslagen. Volgende scan over \(config.fogSettlingDurationMinutes) min."

        fogSettlingTimer?.cancel()
        fogSettlingTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.fogSettlingRemainingSeconds > 1 {
                    self.fogSettlingRemainingSeconds -= 1
                } else {
                    self.fogSettlingTimer?.cancel()
                    self.fogSettlingTimer = nil
                    self.fogSettlingRemainingSeconds = 0
                    self.isFogSettling = false
                    self.scanStatus = "Nevel opgetrokken. Display is weer helder voor de volgende optische meting."
                }
            }
    }

    // MARK: - Persistentie
    public func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configStorageKey)
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(readingHistory) {
            UserDefaults.standard.set(data, forKey: historyStorageKey)
        }
    }

    private func loadPersistedData() {
        if let data = UserDefaults.standard.data(forKey: configStorageKey),
           let decoded = try? JSONDecoder().decode(OpticalHygrometerConfig.self, from: data) {
            var cfg = decoded
            if cfg.scanIntervalMinutes < 5 {
                cfg.scanIntervalMinutes = 15
            }
            self.config = cfg
        }
        if let hData = UserDefaults.standard.data(forKey: historyStorageKey),
           let hDecoded = try? JSONDecoder().decode([OpticalMeterReading].self, from: hData) {
            self.readingHistory = hDecoded
            self.lastReading = hDecoded.first
        }
    }

    // MARK: - Kritieke Klimaat Alarmen & Notificaties
    private func checkAndDispatchClimateAlerts(reading: OpticalMeterReading) {
        guard config.alertsEnabled else { return }
        
        // Broadcasts to viewer phone via LiveKit Data Channel & iCloud KVS, and schedules local push notification
        let isCamDevice = MycoBackgroundHubManager.shared.isStreamHubRoleActive || LiveKitStreamManager.shared.currentRole == .broadcaster || UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
        let cameraBat: Float?
        let isChg: Bool
        if isCamDevice {
            UIDevice.current.isBatteryMonitoringEnabled = true
            let batLevel = UIDevice.current.batteryLevel
            cameraBat = batLevel >= 0 ? batLevel : nil
            isChg = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        } else {
            cameraBat = MycoStore.shared?.db.environmentConfig.cameraBatteryLevel ?? LiveKitStreamManager.shared.remoteBatteryLevel
            isChg = (MycoStore.shared?.db.environmentConfig.cameraIsCharging ?? LiveKitStreamManager.shared.remoteIsCharging) == true
        }
        MycoLabAlertManager.shared.evaluateConditions(
            humidity: reading.humidityPct,
            temperature: reading.temperatureC,
            batteryPct: cameraBat,
            isCharging: isChg,
            store: MycoStore.shared
        )
    }


    // MARK: - Handmatige Invoer & Reactie
    public func reactToManualOrExternalReading(humidityPct: Double, tempC: Double? = nil) {
        let effectiveTargetRH = (MycoStore.shared?.db.environmentConfig.targetHumidityPct ?? config.targetHumidityPct)
        let calc = calculateHumidifierDuration(
            currentRH: humidityPct,
            targetRH: effectiveTargetRH
        )

        let reading = OpticalMeterReading(
            humidityPct: humidityPct,
            temperatureC: tempC,
            confidence: 1.0,
            recognizedRawText: "Handmatige invoer: \(Int(humidityPct))% RV",
            sourceLens: "Handmatige correctie",
            calculatedHumidifierDurationSec: calc.seconds,
            calculatedWaterMl: calc.waterMl,
            chamberVolumeM3: config.chamberVolumeM3,
            wasHumidifierTriggered: calc.seconds > 0,
            isFlashUsed: false
        )

        self.lastReading = reading
        self.readingHistory.insert(reading, at: 0)

        if calc.seconds > 0 {
            executeHumidifierReaction(durationSeconds: calc.seconds, reading: reading)
            if let store = MycoStore.shared {
                MycoSyncManager.shared.triggerToast(message: store.t(
                    nl: "💨 Bevochtiger ingeschakeld voor \(calc.seconds)s om RV te corrigeren naar \(Int(effectiveTargetRH))%",
                    en: "💨 Humidifier activated for \(calc.seconds)s to correct RH to \(Int(effectiveTargetRH))%"
                ))
            }
        }
    }

    // MARK: - Ontvangst Telemetrie van Remote Kweekcamera
    public func handleReceivedRemoteReading(_ reading: OpticalMeterReading) {
        self.lastReading = reading
        self.readingHistory.insert(reading, at: 0)
        if self.readingHistory.count > 30 {
            self.readingHistory = Array(self.readingHistory.prefix(30))
        }
        self.scanStatus = "Kweekcamera AI: \(Int(reading.humidityPct))% RV\(reading.temperatureC != nil ? " • \(String(format: "%.1f", reading.temperatureC!))°C" : "")"
        saveHistory()
        checkAndDispatchClimateAlerts(reading: reading)
    }

    public func cancelHumidifierRun(reason: String) {
        humidifierCountdownTimer?.cancel()
        humidifierCountdownTimer = nil
        humidifierRemainingSeconds = 0
        isHumidifierRunning = false
        if let store = MycoStore.shared {
            if let hum = store.db.smartDevices.first(where: { $0.deviceType == "Humidifier" && $0.isOn }) {
                store.setSmartDeviceState(id: hum.id, isOn: false, trigger: "Onderbroken: \(reason)")
            }
        }
        scanStatus = "Bevochtiging onderbroken: \(reason)"
    }

    private func sendLocalNotification(title: String, body: String, identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let req = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(req)
        }
    }

}
