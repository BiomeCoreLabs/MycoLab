import Foundation
import SwiftUI
import Combine
import UIKit
#if canImport(CoreMotion)
import CoreMotion
#endif

// MARK: - 1. DATA MODELS FOR BAROMETER & LUCHTDRUK

public struct BarometerSample: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var timestamp: Date
    public var pressureHpa: Double
    public var relativeAltitudeMeters: Double
}

public enum PressureTrend: String, Codable, Sendable {
    case rising = "Rising"
    case stable = "Stable"
    case falling = "Falling (Pin-Trigger)"
    case stormFront = "Sharp Drop (Storm Front)"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "Rising", "Stijgend": self = .rising
        case "Stable", "Stabiel": self = .stable
        case "Falling (Pin-Trigger)", "Dalend (Pin-Trigger)": self = .falling
        case "Sharp Drop (Storm Front)", "Sterke Daling (Stormfront)": self = .stormFront
        default: self = .stable
        }
    }

    public var icon: String {
        switch self {
        case .rising: return "arrow.up.right.circle.fill"
        case .stable: return "equal.circle.fill"
        case .falling: return "arrow.down.right.circle.fill"
        case .stormFront: return "cloud.bolt.rain.fill"
        }
    }
}

public struct RemoteSensorPayload: Codable, Sendable {
    public var pressureHpa: Double
    public var relativeAltitudeM: Double
    public var pressureDelta6h: Double
    public var pressureTrend: PressureTrend
    public var pinningAdvice: String

    enum CodingKeys: CodingKey {
        case pressureHpa
        case relativeAltitudeM
        case pressureDelta6h
        case pressureTrend
        case pinningAdvice
    }

    public init(
        pressureHpa: Double,
        relativeAltitudeM: Double,
        pressureDelta6h: Double,
        pressureTrend: PressureTrend,
        pinningAdvice: String
    ) {
        self.pressureHpa = pressureHpa
        self.relativeAltitudeM = relativeAltitudeM
        self.pressureDelta6h = pressureDelta6h
        self.pressureTrend = pressureTrend
        self.pinningAdvice = pinningAdvice
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pressureHpa, forKey: .pressureHpa)
        try container.encode(relativeAltitudeM, forKey: .relativeAltitudeM)
        try container.encode(pressureDelta6h, forKey: .pressureDelta6h)
        try container.encode(pressureTrend, forKey: .pressureTrend)
        try container.encode(pinningAdvice, forKey: .pinningAdvice)
    }
}

// MARK: - 2. SENSOR INTELLIGENCE MANAGER (REAL BAROMETER & TELEMETRY)

@MainActor
public final class MycoSensorIntelligenceManager: NSObject, ObservableObject {
    public static let shared = MycoSensorIntelligenceManager()

    // --- Barometer (CMAltimeter) ---
    @Published public var isBarometerAvailable: Bool = false
    /// Standard atmospheric pressure (1013.25 hPa) until updated by real barometer
    @Published public var currentPressureHpa: Double = 1013.25
    @Published public var relativeAltitudeM: Double = 0.0
    @Published public var pressureDelta6h: Double = 0.0
    @Published public var pressureTrend: PressureTrend = .stable
    @Published public var barometerHistory: [BarometerSample] = []
    @Published public var pinningTriggerAdvice: String = "Waiting for barometer telemetry..."

    // --- Remote Sync (Camera Phone -> Viewer Phone / iPad / Mac) ---
    @Published public var isReceivingRemoteSensorStream: Bool = false
    @Published public var lastRemoteSyncTime: Date? = nil

    private let baroHistoryKey = "mycolab_real_baro_history_v1"

    #if canImport(CoreMotion) && !targetEnvironment(macCatalyst)
    private let altimeter = CMAltimeter()
    #endif

    override private init() {
        super.init()
        loadPersistedHistory()
        detectHardwareCapabilities()
        startBarometerMonitoring()
    }

    public func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: baroHistoryKey)
        self.currentPressureHpa = 1013.25
        self.relativeAltitudeM = 0.0
        self.pressureTrend = .stable
        self.pressureDelta6h = 0.0
        self.barometerHistory = []
    }

    // MARK: - Hardware Detection
    public func detectHardwareCapabilities() {
        #if canImport(CoreMotion) && !targetEnvironment(macCatalyst)
        self.isBarometerAvailable = CMAltimeter.isRelativeAltitudeAvailable()
        #else
        self.isBarometerAvailable = false
        #endif
    }

    // MARK: - 1. Barometer Monitoring
    public func startBarometerMonitoring() {
        #if canImport(CoreMotion) && !targetEnvironment(macCatalyst)
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            isBarometerAvailable = false
            pinningTriggerAdvice = "This device does not have a built-in barometer. Connect an iPhone as grow camera for live air pressure."
            return
        }
        isBarometerAvailable = true
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            let hpa = data.pressure.doubleValue * 10.0
            let alt = data.relativeAltitude.doubleValue
            self.recordBarometerReading(hpa: hpa, altitudeM: alt)
        }
        #else
        isBarometerAvailable = false
        pinningTriggerAdvice = "Waiting for live barometer telemetry from the connected grow camera..."
        #endif
    }

    public func stopBarometerMonitoring() {
        #if canImport(CoreMotion) && !targetEnvironment(macCatalyst)
        altimeter.stopRelativeAltitudeUpdates()
        #endif
    }

    public func recordBarometerReading(hpa: Double, altitudeM: Double) {
        guard hpa > 500 && hpa < 1300 else { return }
        currentPressureHpa = hpa
        relativeAltitudeM = altitudeM
        isBarometerAvailable = true
        let now = Date()
        if let last = barometerHistory.last, now.timeIntervalSince(last.timestamp) < 300 {
            // Keep 5-minute spacing
        } else {
            barometerHistory.append(BarometerSample(timestamp: now, pressureHpa: hpa, relativeAltitudeMeters: altitudeM))
            if barometerHistory.count > 144 {
                barometerHistory.removeFirst(barometerHistory.count - 144)
            }
            savePersistedHistory()
        }
        evaluateBarometerTrend()
    }

    public func evaluateBarometerTrend() {
        guard let oldest = barometerHistory.first, currentPressureHpa > 0 else { return }
        let delta = currentPressureHpa - oldest.pressureHpa
        pressureDelta6h = delta

        if delta <= -4.0 {
            pressureTrend = .stormFront
            pinningTriggerAdvice = "⚡️ Sharp pressure drop (\(String(format: "%.1f", delta)) hPa) detected."
        } else if delta <= -1.5 {
            pressureTrend = .falling
            pinningTriggerAdvice = "🌧️ Falling air pressure (\(String(format: "%.1f", delta)) hPa) detected."
        } else if delta >= 2.0 {
            pressureTrend = .rising
            pinningTriggerAdvice = "☀️ Rising air pressure (+\(String(format: "%.1f", delta)) hPa) detected."
        } else {
            pressureTrend = .stable
            pinningTriggerAdvice = "⚖️ Stable air pressure (\(String(format: "%.1f", currentPressureHpa)) hPa)."
        }
    }

    public func deleteMeasurement(id: UUID) {
        // Legacy stub for backward compatibility
    }

    // MARK: - Remote Telemetry Sync (Camera Hub <-> Viewer)
    public func broadcastTelemetryToViewers() {
        let payload = RemoteSensorPayload(
            pressureHpa: currentPressureHpa,
            relativeAltitudeM: relativeAltitudeM,
            pressureDelta6h: pressureDelta6h,
            pressureTrend: pressureTrend,
            pinningAdvice: pinningTriggerAdvice
        )
        Task.detached(priority: .userInitiated) {
            guard let data = try? JSONEncoder().encode(payload),
                  let jsonStr = String(data: data, encoding: .utf8) else { return }
            await MainActor.run {
                LiveKitStreamManager.shared.sendDataCommand(command: "sensor:telemetry:\(jsonStr)")
            }
        }
    }

    public func handleIncomingRemoteTelemetry(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(RemoteSensorPayload.self, from: data) else { return }
        self.isReceivingRemoteSensorStream = true
        self.lastRemoteSyncTime = Date()
        if payload.pressureHpa > 0 {
            self.currentPressureHpa = payload.pressureHpa
            self.relativeAltitudeM = payload.relativeAltitudeM
            self.pressureDelta6h = payload.pressureDelta6h
            self.pressureTrend = payload.pressureTrend
            self.pinningTriggerAdvice = payload.pinningAdvice
            self.isBarometerAvailable = true
        }
    }

    public func requestRemoteSensorStatus() {
        LiveKitStreamManager.shared.sendDataCommand(command: "sensor:request")
    }

    // MARK: - Persistence
    private func savePersistedHistory() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil {
            return
        }
        let baro = barometerHistory
        let bKey = baroHistoryKey
        Task.detached(priority: .userInitiated) {
            if let bData = try? JSONEncoder().encode(baro) {
                UserDefaults.standard.set(bData, forKey: bKey)
            }
        }
    }

    private func loadPersistedHistory() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil {
            return
        }
        let bKey = baroHistoryKey
        Task.detached(priority: .userInitiated) { [weak self] in
            let rawBData = UserDefaults.standard.data(forKey: bKey)
            let decodedBaro = rawBData.flatMap { try? JSONDecoder().decode([BarometerSample].self, from: $0) }
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                if let bDecoded = decodedBaro, !bDecoded.isEmpty {
                    self.barometerHistory = bDecoded
                    if let last = bDecoded.last {
                        self.currentPressureHpa = last.pressureHpa
                        self.relativeAltitudeM = last.relativeAltitudeMeters
                        self.evaluateBarometerTrend()
                    }
                }
            }
        }
    }
}

// MARK: - 3. FULL SENSOR INSPECTION SHEET (BAROMETER & LUCHTDRUK)

public struct MycoSensorInspectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sensorManager = MycoSensorIntelligenceManager.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "gauge.with.needle.fill")
                                .foregroundColor(.cyan)
                            Text("Barometer & Air Pressure")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Spacer()
                            if sensorManager.currentPressureHpa > 0 {
                                Text("\(String(format: "%.1f", sensorManager.currentPressureHpa)) hPa")
                                    .font(.subheadline.bold().monospaced())
                                    .foregroundColor(.cyan)
                            } else {
                                Text("No measurement")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text(sensorManager.pinningTriggerAdvice)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color(red: 0.08, green: 0.09, blue: 0.12))
                    .cornerRadius(16)
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Barometer & Air Pressure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
    }
}
