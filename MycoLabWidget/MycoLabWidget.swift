//
//  MycoLabWidget.swift
//  MycoLabWidget
//
//  Created for MycoLab on 03/11/2026.
//

import WidgetKit
import SwiftUI
import AppIntents

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
        statusSummary: String = "Optimal Climate",
        isHumidifierActive: Bool = false,
        isExhaustFanActive: Bool = false,
        isLightActive: Bool = false,
        activeDeviceSummary: String = "Standby",
        vpdKpa: Double = 0.25,
        vpdZoneTitle: String = "Ideal",
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
        self.topBatchStrain = try c.decodeIfPresent(String.self, forKey: .topBatchStrain) ?? "MycoLab"
        self.topBatchPhase = try c.decodeIfPresent(String.self, forKey: .topBatchPhase) ?? "Fruiting"
        self.topBatchColonization = try c.decodeIfPresent(Double.self, forKey: .topBatchColonization) ?? 90.0
        self.topBatchDaysInPhase = try c.decodeIfPresent(Int.self, forKey: .topBatchDaysInPhase) ?? 5
        self.topBatchNeedsBS = try c.decodeIfPresent(Bool.self, forKey: .topBatchNeedsBS) ?? false
        self.topBatchHasPins = try c.decodeIfPresent(Bool.self, forKey: .topBatchHasPins) ?? true
        self.lastUpdated = try c.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
        self.statusSummary = try c.decodeIfPresent(String.self, forKey: .statusSummary) ?? "Optimal Climate"
        self.isHumidifierActive = try c.decodeIfPresent(Bool.self, forKey: .isHumidifierActive) ?? false
        self.isExhaustFanActive = try c.decodeIfPresent(Bool.self, forKey: .isExhaustFanActive) ?? false
        self.isLightActive = try c.decodeIfPresent(Bool.self, forKey: .isLightActive) ?? false
        self.activeDeviceSummary = try c.decodeIfPresent(String.self, forKey: .activeDeviceSummary) ?? "Standby"
        self.vpdKpa = try c.decodeIfPresent(Double.self, forKey: .vpdKpa) ?? 0.25
        self.vpdZoneTitle = try c.decodeIfPresent(String.self, forKey: .vpdZoneTitle) ?? "Ideal"
        self.isDemoMode = try c.decodeIfPresent(Bool.self, forKey: .isDemoMode) ?? false
        self.hasConfiguredCamera = try c.decodeIfPresent(Bool.self, forKey: .hasConfiguredCamera) ?? false
        self.isCameraConnected = try c.decodeIfPresent(Bool.self, forKey: .isCameraConnected) ?? false
        self.cameraSnapshotDate = try c.decodeIfPresent(Date.self, forKey: .cameraSnapshotDate)
    }

    public static var placeholder: MycoWidgetSnapshot {
        MycoWidgetSnapshot()
    }
}

// MARK: - Timeline Provider

public struct MycoWidgetEntry: TimelineEntry {
    public let date: Date
    public let snapshot: MycoWidgetSnapshot
}

public struct MycoWidgetProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> MycoWidgetEntry {
        MycoWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    public func getSnapshot(in context: Context, completion: @escaping (MycoWidgetEntry) -> Void) {
        let snap = loadSnapshot() ?? .placeholder
        completion(MycoWidgetEntry(date: Date(), snapshot: snap))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<MycoWidgetEntry>) -> Void) {
        let snap = loadSnapshot() ?? .placeholder
        let currentEntry = MycoWidgetEntry(date: Date(), snapshot: snap)

        // Schedule next automatic reload after 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadSnapshot() -> MycoWidgetSnapshot? {
        let appGroupID = "group.com.mycolab.app"
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        guard let data = defaults.data(forKey: "mycolab_widget_snapshot") else {
            return nil
        }
        return try? JSONDecoder().decode(MycoWidgetSnapshot.self, from: data)
    }
}

// MARK: - Shared Background Backdrop

struct WidgetBackdropView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.15),
                Color(red: 0.02, green: 0.04, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Lock Screen Views

struct InlineLockScreenWidgetView: View {
    let snapshot: MycoWidgetSnapshot

    var body: some View {
        Text("🍄 \(Int(round(snapshot.temperatureC)))°C • \(Int(round(snapshot.humidityPct)))% • VPD \(String(format: "%.2f", snapshot.vpdKpa)) • Day \(snapshot.topBatchDaysInPhase)")
    }
}

struct CircularLockScreenWidgetView: View {
    let snapshot: MycoWidgetSnapshot

    var body: some View {
        Gauge(value: min(max(snapshot.topBatchColonization, 0), 100), in: 0...100) {
            Image(systemName: "circle.hexagongrid.fill")
        } currentValueLabel: {
            VStack(spacing: 0) {
                Text("\(Int(round(snapshot.topBatchColonization)))%")
                    .font(.system(size: 10, weight: .bold))
                Text("D\(snapshot.topBatchDaysInPhase)")
                    .font(.system(size: 7, weight: .semibold))
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

struct RectangularLockScreenWidgetView: View {
    let snapshot: MycoWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "cross.vial.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(snapshot.topBatchStrain.isEmpty ? "MycoLab Batch" : snapshot.topBatchStrain)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Spacer()
                Text("Day \(snapshot.topBatchDaysInPhase) (\(Int(round(snapshot.topBatchColonization)))%)")
                    .font(.system(size: 10, weight: .heavy))
            }

            HStack(spacing: 6) {
                Text(String(format: "%.1f°C", snapshot.temperatureC))
                    .font(.system(size: 12, weight: .heavy))
                Text("•")
                    .foregroundColor(.secondary)
                Text("\(Int(round(snapshot.humidityPct)))% RH")
                    .font(.system(size: 12, weight: .heavy))
                Text("•")
                    .foregroundColor(.secondary)
                Text("VPD \(String(format: "%.2f", snapshot.vpdKpa))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(snapshot.vpdKpa >= 0.10 && snapshot.vpdKpa <= 0.35 ? .primary : .orange)
            }

            HStack(spacing: 4) {
                Text(snapshot.topBatchPhase)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text(snapshot.activeDeviceSummary)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(snapshot.isHumidifierActive ? .cyan : (snapshot.isExhaustFanActive ? .orange : .secondary))
            }
            .lineLimit(1)
        }
    }
}

// MARK: - Home Screen Views (Small)

struct SmallHomeScreenWidgetView: View {
    let snapshot: MycoWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Text("🍄")
                        .font(.system(size: 12))
                    Text("MYCOLAB")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(Color.cyan)
                }
                Spacer()
                HStack(spacing: 3) {
                    Circle()
                        .fill(snapshot.hubActive ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(snapshot.hubActive ? "HUB" : "OFF")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(snapshot.hubActive ? .green : .secondary)
                }
            }

            // Big Climate Metrics
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 2) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text("TEMP")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text(String(format: "%.1f°", snapshot.temperatureC))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 2) {
                        Image(systemName: "humidity.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.cyan)
                        Text("RV")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text(String(format: "%.0f%%", snapshot.humidityPct))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(.cyan)
                }
            }
            .padding(.vertical, 1)

            // Smart Hardware & VPD Status Chip
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    Text("VPD")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", snapshot.vpdKpa))
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundColor(snapshot.vpdKpa >= 0.10 && snapshot.vpdKpa <= 0.35 ? .green : .orange)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.08))
                .cornerRadius(3)

                Spacer()

                if snapshot.topBatchDaysInPhase > 0 {
                    Text("Dag \(snapshot.topBatchDaysInPhase)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.cyan)
                }
            }
            .lineLimit(1)

            // Smart Hardware Status Chip
            HStack(spacing: 4) {
                if snapshot.isHumidifierActive {
                    HStack(spacing: 3) {
                        Circle().fill(Color.cyan).frame(width: 4, height: 4)
                        Text(snapshot.activeDeviceSummary)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                } else if snapshot.isExhaustFanActive {
                    HStack(spacing: 3) {
                        Circle().fill(Color.orange).frame(width: 4, height: 4)
                        Text(snapshot.activeDeviceSummary)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                    }
                } else if snapshot.isLightActive {
                    HStack(spacing: 3) {
                        Circle().fill(Color.yellow).frame(width: 4, height: 4)
                        Text("💡 Lamp AAN")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                } else {
                    HStack(spacing: 3) {
                        Circle().fill(Color.secondary.opacity(0.7)).frame(width: 4, height: 4)
                        Text("💤 Standby")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .lineLimit(1)

            Spacer(minLength: 0)

            // Active Batch & Colonization Progress
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(snapshot.topBatchStrain.isEmpty ? "Geen actieve batch" : snapshot.topBatchStrain)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(round(snapshot.topBatchColonization)))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 4)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(geo.size.width * CGFloat(snapshot.topBatchColonization / 100.0), 4), height: 4)
                    }
                }
                .frame(height: 4)

                // Subtitle / alert
                HStack(spacing: 4) {
                    if snapshot.topBatchNeedsBS {
                        Text("🫨 B&S Nodig!")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.orange)
                    } else if snapshot.topBatchHasPins {
                        Text("🌱 Pins actief")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text(snapshot.topBatchPhase)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(snapshot.roomName)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Home Screen Views (Medium)

struct MediumHomeScreenWidgetView: View {
    let snapshot: MycoWidgetSnapshot

    var body: some View {
        HStack(spacing: 12) {
            // Left Column: Climate & Hub Status
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 4) {
                    Text("🍄")
                        .font(.system(size: 12))
                    Text("MYCOLAB")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                    Spacer()
                    HStack(spacing: 3) {
                        Circle()
                            .fill(snapshot.hubActive ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(snapshot.hubActive ? "HUB LIVE" : "STANDBY")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(snapshot.hubActive ? .green : .secondary)
                    }
                }

                Spacer(minLength: 0)

                // Climate Big Metrics
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Label("TEMP", systemImage: "thermometer.medium")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f°C", snapshot.temperatureC))
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Label("RH", systemImage: "humidity.fill")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                        Text(String(format: "%.0f%%", snapshot.humidityPct))
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundColor(.cyan)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Label("VPD", systemImage: "gauge.with.dots.needle.bottom.50percent")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(snapshot.vpdKpa >= 0.10 && snapshot.vpdKpa <= 0.35 ? .green : .orange)
                        Text(String(format: "%.2f", snapshot.vpdKpa))
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundColor(snapshot.vpdKpa >= 0.10 && snapshot.vpdKpa <= 0.35 ? .green : .orange)
                    }
                }

                Spacer(minLength: 0)

                // Smart Hardware Status Bar
                HStack(spacing: 4) {
                    if snapshot.isHumidifierActive {
                        HStack(spacing: 3) {
                            Circle().fill(Color.cyan).frame(width: 5, height: 5)
                            Text(snapshot.activeDeviceSummary)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.18))
                        .cornerRadius(4)
                    } else if snapshot.isExhaustFanActive {
                        HStack(spacing: 3) {
                            Circle().fill(Color.orange).frame(width: 5, height: 5)
                            Text(snapshot.activeDeviceSummary)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18))
                        .cornerRadius(4)
                    } else if snapshot.isLightActive {
                        HStack(spacing: 3) {
                            Circle().fill(Color.yellow).frame(width: 5, height: 5)
                            Text("💡 Lamp AAN")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.18))
                        .cornerRadius(4)
                    } else {
                        HStack(spacing: 3) {
                            Circle().fill(Color.secondary).frame(width: 4, height: 4)
                            Text("💤 Apparaten in rust")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .lineLimit(1)

                // Atmospheric & Room Footnote
                HStack(spacing: 6) {
                    if snapshot.pressureHpa > 900 {
                        Text("\(Int(round(snapshot.pressureHpa))) hPa")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(snapshot.roomName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 4)

            // Right Column: Active Batches & Status
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("ACTIEVE KWEEK")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(snapshot.activeBatchCount) batch\(snapshot.activeBatchCount == 1 ? "" : "es")")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.cyan)
                }

                Spacer(minLength: 0)

                // Top Batch Card
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(snapshot.topBatchStrain.isEmpty ? "Geen actieve batch" : snapshot.topBatchStrain)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(round(snapshot.topBatchColonization)))%")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(.green)
                    }

                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 5)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan, Color.green],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(geo.size.width * CGFloat(snapshot.topBatchColonization / 100.0), 5), height: 5)
                        }
                    }
                    .frame(height: 5)

                    // Phase & Tag pill
                    HStack(spacing: 4) {
                        Text(snapshot.topBatchPhase)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.2))
                            .foregroundColor(.cyan)
                            .cornerRadius(4)

                        if snapshot.topBatchDaysInPhase > 0 {
                            Text("Dag \(snapshot.topBatchDaysInPhase)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }

                        if snapshot.topBatchNeedsBS {
                            Text("🫨 Shake")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.25))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        } else if snapshot.topBatchHasPins {
                            Text("🌱 Pins")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.25))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                }

                Spacer(minLength: 0)

                // Status summary footnote
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                    Text(snapshot.statusSummary)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }
}



// MARK: - Viewfinder HUD Brackets

struct ViewfinderBrackets: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let b: CGFloat = 8
            Path { p in
                // Top-Left
                p.move(to: CGPoint(x: 4, y: 4 + b))
                p.addLine(to: CGPoint(x: 4, y: 4))
                p.addLine(to: CGPoint(x: 4 + b, y: 4))
                // Top-Right
                p.move(to: CGPoint(x: w - 4 - b, y: 4))
                p.addLine(to: CGPoint(x: w - 4, y: 4))
                p.addLine(to: CGPoint(x: w - 4, y: 4 + b))
                // Bottom-Left
                p.move(to: CGPoint(x: 4, y: h - 4 - b))
                p.addLine(to: CGPoint(x: 4, y: h - 4))
                p.addLine(to: CGPoint(x: 4 + b, y: h - 4))
                // Bottom-Right
                p.move(to: CGPoint(x: w - 4 - b, y: h - 4))
                p.addLine(to: CGPoint(x: w - 4, y: h - 4))
                p.addLine(to: CGPoint(x: w - 4, y: h - 4 - b))
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 1.2)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Chamber Optical View & Interactive Room Controls (Large & ExtraLarge)

struct ChamberOpticalView: View {
    let snapshot: MycoWidgetSnapshot
    let isCompact: Bool

    // 1. Laad echte snapshot uit de gedeelde App Group container
    private var realSnapshotImage: UIImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mycolab.app") else {
            return nil
        }
        let targetURL = containerURL.appendingPathComponent("latest_chamber_snapshot.jpg")
        guard let data = try? Data(contentsOf: targetURL),
              let uiImage = UIImage(data: data) else {
            return nil
        }
        return uiImage
    }

    private var demoImageName: String {
        if snapshot.isHumidifierActive {
            return "chamber_mist"
        } else if !snapshot.isLightActive {
            return "chamber_night"
        } else {
            return "chamber_base"
        }
    }

    var body: some View {
        Link(destination: URL(string: "mycolab://camera")!) {
            content
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if snapshot.isDemoMode {
            // MARK: - STATE 1: DEMO MODUS (Gesimuleerde beelden)
            demoChamberView
        } else if !snapshot.hasConfiguredCamera {
            // MARK: - STATE 2: GEEN CAMERA VERBONDEN (Geen foto)
            noCameraView
        } else if snapshot.isCameraConnected {
            // MARK: - STATE 3: CAMERA LIVE VERBONDEN (Geen foto)
            liveStreamActiveView
        } else {
            // MARK: - STATE 4: CAMERA OFFLINE / STANDBY (Echte livestream foto)
            offlineSnapshotView
        }
    }

    // MARK: - 1. Demo Mode View
    private var demoChamberView: some View {
        ZStack {
            Image(demoImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            if snapshot.isHumidifierActive {
                Color.cyan.opacity(0.12)
            } else if !snapshot.isLightActive {
                Color.blue.opacity(0.18)
            }

            ViewfinderBrackets()

            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.75),
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.20),
                    Color.black.opacity(0.85)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("DEMO MODUS")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())

                    Spacer()

                    Text("VIRTUEEL LAB • SIMULATIE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)

                Spacer(minLength: 2)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                        Text("🍄 \(snapshot.topBatchStrain) (\(Int(round(snapshot.topBatchColonization)))%)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.75))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.green.opacity(0.6), lineWidth: 1))
                    .cornerRadius(6)

                    Spacer()

                    if snapshot.isHumidifierActive {
                        HStack(spacing: 3) {
                            Circle().fill(Color.cyan).frame(width: 5, height: 5)
                            Text("MIST")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.2))
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

                telemetryStrip
            }
        }
    }

    // MARK: - 2. Geen Camera Verbonden View (Geen foto)
    private var noCameraView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.12),
                    Color(red: 0.02, green: 0.04, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ViewfinderBrackets()

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.gray.opacity(0.8))
                            .frame(width: 6, height: 6)
                        Text("GEEN CAMERA")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())

                    Spacer()

                    Text("KWEEKBEWAKING STANDBY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)

                Spacer(minLength: 2)

                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 34, height: 34)
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Geen camera verbonden")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Koppel een camera om live mee te kijken")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 3) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 9, weight: .bold))
                        Text("Koppel")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(6)
                }
                .padding(.horizontal, 10)

                Spacer(minLength: 2)

                telemetryStrip
            }
        }
    }

    // MARK: - 3. Live Stream Actief View (Geen foto)
    private var liveStreamActiveView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.13, blue: 0.15),
                    Color(red: 0.01, green: 0.04, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ViewfinderBrackets()

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("LIVE VERBONDEN")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.35))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.red.opacity(0.6), lineWidth: 1))

                    Spacer()

                    Text("WEBRTC • LIVE FEED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)

                Spacer(minLength: 2)

                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: "video.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live meekijken beschikbaar")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("Ultra-lage latentie kweekbeeld")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Kijk Live")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.35))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.green.opacity(0.6), lineWidth: 1))
                }
                .padding(.horizontal, 10)

                Spacer(minLength: 2)

                telemetryStrip
            }
        }
    }

    // MARK: - 4. Offline / Standby View (Toont laatste foto van de echte livestream)
    private var offlineSnapshotView: some View {
        ZStack {
            if let realImg = realSnapshotImage {
                Image(uiImage: realImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                ViewfinderBrackets()

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.75),
                        Color.black.opacity(0.08),
                        Color.black.opacity(0.20),
                        Color.black.opacity(0.85)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack {
                    HStack(alignment: .center) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text("OFFLINE • LAATSTE FOTO")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())

                        Spacer()

                        Text("LAATSTE LIVESTREAM OPNAME")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)

                    Spacer(minLength: 2)

                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.cyan)
                            Text("Tik voor live monitor")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(6)

                        Spacer()
                    }
                    .padding(.horizontal, 8)

                    telemetryStrip
                }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.06, blue: 0.10),
                            Color(red: 0.02, green: 0.03, blue: 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    ViewfinderBrackets()

                    VStack(spacing: 0) {
                        HStack {
                            HStack(spacing: 5) {
                                Circle().fill(Color.orange).frame(width: 6, height: 6)
                                Text("CAMERA STANDBY")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())

                            Spacer()

                            Text("OFFLINE")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 6)

                        Spacer(minLength: 2)

                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.orange)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Camera offline")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Wachten op eerste livestream snapshot")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)

                        Spacer(minLength: 2)

                        telemetryStrip
                    }
                }
            }
        }
    }

    // MARK: - Telemetry Strip
    private var telemetryStrip: some View {
        HStack(spacing: 8) {
            Label(String(format: "%.1f°C", snapshot.temperatureC), systemImage: "thermometer.medium")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)

            Divider().frame(height: 10).background(Color.white.opacity(0.2))

            Label("\(Int(round(snapshot.humidityPct)))%", systemImage: "drop.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.cyan)

            Divider().frame(height: 10).background(Color.white.opacity(0.2))

            Label("VPD \(String(format: "%.2f", snapshot.vpdKpa))", systemImage: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.green)

            Spacer(minLength: 0)

            Text("\(snapshot.co2Ppm) ppm")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color.gray)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.85))
    }
}

// MARK: - Dedicated Climate Metric Tile

struct ClimateMetricTile: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let tint: Color
    var subtext: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(tint)
                Text(label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color.gray)
            }
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(tint)
                }
            }
            if let sub = subtext {
                Text(sub)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(tint.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

struct ActuatorButtonTile: View {
    let title: String
    let icon: String
    let isActive: Bool
    let activeColor: Color
    var subtitle: String? = nil

    var body: some View {
        ZStack {
            // Tactile background
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? activeColor.opacity(0.20) : Color.white.opacity(0.06))

            // Glowing border
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isActive ? activeColor.opacity(0.85) : Color.white.opacity(0.12),
                    lineWidth: isActive ? 1.5 : 1.0
                )

            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(isActive ? activeColor.opacity(0.32) : Color.white.opacity(0.06))
                        .frame(width: 22, height: 22)

                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isActive ? activeColor : Color.white.opacity(0.45))
                }

                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(isActive ? .white : Color.white.opacity(0.65))
                    .lineLimit(1)

                // Mini status pill
                Text(subtitle ?? (isActive ? "AAN" : "UIT"))
                    .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                    .foregroundColor(isActive ? activeColor : Color.white.opacity(0.35))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(isActive ? activeColor.opacity(0.18) : Color.white.opacity(0.04))
                    .clipShape(Capsule())
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
    }
}

struct RoomControlQuickDock: View {
    let snapshot: MycoWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("RUIMTE BEDIENING")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color.gray)
                Spacer()
                Text(snapshot.activeDeviceSummary)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color.cyan)
                    .lineLimit(1)
            }

            HStack(spacing: 5) {
                // Button 1: Bevochtiger (Mist)
                if #available(iOS 17.0, macOS 14.0, *) {
                    Button(intent: ToggleHumidifierIntent()) {
                        ActuatorButtonTile(
                            title: "Mist",
                            icon: "drop.fill",
                            isActive: snapshot.isHumidifierActive,
                            activeColor: .cyan
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "mycolab://control?device=humidifier&action=toggle")!) {
                        ActuatorButtonTile(
                            title: "Mist",
                            icon: "drop.fill",
                            isActive: snapshot.isHumidifierActive,
                            activeColor: .cyan
                        )
                    }
                }

                // Button 2: Ventilatie (Afzuiger / FAE)
                if #available(iOS 17.0, macOS 14.0, *) {
                    Button(intent: ToggleExhaustFanIntent()) {
                        ActuatorButtonTile(
                            title: "Afzuig",
                            icon: "wind",
                            isActive: snapshot.isExhaustFanActive,
                            activeColor: Color(red: 0.2, green: 0.6, blue: 1.0)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "mycolab://control?device=fan&action=toggle")!) {
                        ActuatorButtonTile(
                            title: "Afzuig",
                            icon: "wind",
                            isActive: snapshot.isExhaustFanActive,
                            activeColor: Color(red: 0.2, green: 0.6, blue: 1.0)
                        )
                    }
                }

                // Button 3: Kweeklamp
                if #available(iOS 17.0, macOS 14.0, *) {
                    Button(intent: ToggleGrowLightIntent()) {
                        ActuatorButtonTile(
                            title: "Lamp",
                            icon: "lightbulb.fill",
                            isActive: snapshot.isLightActive,
                            activeColor: Color.yellow
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "mycolab://control?device=light&action=toggle")!) {
                        ActuatorButtonTile(
                            title: "Lamp",
                            icon: "lightbulb.fill",
                            isActive: snapshot.isLightActive,
                            activeColor: Color.yellow
                        )
                    }
                }

                // Button 4: Verse Lucht Pulse
                if #available(iOS 17.0, macOS 14.0, *) {
                    Button(intent: TriggerFaePulseIntent()) {
                        ActuatorButtonTile(
                            title: "Pulse",
                            icon: "fanblades.fill",
                            isActive: false,
                            activeColor: Color.green,
                            subtitle: "60s"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "mycolab://control?device=fan_pulse&action=trigger")!) {
                        ActuatorButtonTile(
                            title: "Pulse",
                            icon: "fanblades.fill",
                            isActive: false,
                            activeColor: Color.green,
                            subtitle: "60s"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Large Home Screen Widget (iPhone, iPad & Mac)

struct LargeHomeScreenWidgetView: View {
    let snapshot: MycoWidgetSnapshot

    var body: some View {
        VStack(spacing: 6) {
            // 1. Top Header Row (deep link to dashboard)
            Link(destination: URL(string: "mycolab://dashboard")!) {
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Text("🍄 MYCOLAB")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(.cyan)
                        Text("•")
                            .foregroundColor(.gray)
                        Text(snapshot.roomName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        Circle()
                            .fill(snapshot.hubActive ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(snapshot.hubActive ? "24/7 HUB ONLINE" : "STANDBY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(snapshot.hubActive ? .green : .gray)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)

            // 2. Kweekkamer Optical Feed Viewport (Optimized height for breathing room)
            ChamberOpticalView(snapshot: snapshot, isCompact: false)
                .frame(height: 116)

            // 3. Dedicated 4-Metric Climate Telemetry Grid (Zero wasted space!)
            HStack(spacing: 5) {
                ClimateMetricTile(
                    icon: "thermometer.medium",
                    label: "TEMP",
                    value: String(format: "%.1f", snapshot.temperatureC),
                    unit: "°C",
                    tint: .orange,
                    subtext: "Doel 23°"
                )

                ClimateMetricTile(
                    icon: "drop.fill",
                    label: "VOCHT",
                    value: "\(Int(round(snapshot.humidityPct)))",
                    unit: "%",
                    tint: .cyan,
                    subtext: "Optimaal"
                )

                ClimateMetricTile(
                    icon: "gauge.with.dots.needle.bottom.50percent",
                    label: "VPD",
                    value: String(format: "%.2f", snapshot.vpdKpa),
                    unit: "kPa",
                    tint: .green,
                    subtext: "Goud Zone"
                )

                ClimateMetricTile(
                    icon: "wind",
                    label: "CO2",
                    value: "\(snapshot.co2Ppm)",
                    unit: "ppm",
                    tint: Color(red: 0.6, green: 0.7, blue: 0.9),
                    subtext: "Fris / FAE"
                )
            }

            // 4. Actuator Quick Dock
            RoomControlQuickDock(snapshot: snapshot)

            // 5. Active Batch & Cultivation Status Card (Bottom Ribbon)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(snapshot.topBatchName.isEmpty ? "Geen actieve batch" : snapshot.topBatchName)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if !snapshot.topBatchStrain.isEmpty {
                            Text("•")
                                .foregroundColor(.gray)
                            Text(snapshot.topBatchStrain)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.cyan)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("\(Int(round(snapshot.topBatchColonization)))% Kolonisatie")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .green],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(4, geo.size.width * CGFloat(snapshot.topBatchColonization / 100.0)))
                        }
                    }
                    .frame(height: 4)

                    HStack(spacing: 4) {
                        Text(snapshot.topBatchPhase)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.secondary)
                        if snapshot.topBatchDaysInPhase > 0 {
                            Text("Dag \(snapshot.topBatchDaysInPhase)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Text(snapshot.statusSummary)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                if snapshot.topBatchNeedsBS {
                    Text("🌾 B&S")
                        .font(.system(size: 8, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                } else if snapshot.topBatchHasPins {
                    Text("🌱 Pins")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Extra Large Home Screen Widget (iPad & Mac Desktop)

struct ExtraLargeHomeScreenWidgetView: View {
    let snapshot: MycoWidgetSnapshot

    var body: some View {
        HStack(spacing: 14) {
            // Left: Large Widescreen Chamber Viewport
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 5) {
                        Text("🍄 MYCOLAB")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundColor(.cyan)
                        Text("•")
                            .foregroundColor(.gray)
                        Text(snapshot.roomName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("LIVE 60FPS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }

                ChamberOpticalView(snapshot: snapshot, isCompact: false)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)

            // Right: Actuator Control Station & Batch Deep Telemetry
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("KAMER BEDIENING")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("HUB ACTIEF")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }

                // Actuator Grid (2x2)
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        if #available(iOS 17.0, macOS 14.0, *) {
                            Button(intent: ToggleHumidifierIntent()) {
                                ActuatorButtonTile(
                                    title: "Mist",
                                    icon: "drop.fill",
                                    isActive: snapshot.isHumidifierActive,
                                    activeColor: .cyan
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            ActuatorButtonTile(
                                title: "Mist",
                                icon: "drop.fill",
                                isActive: snapshot.isHumidifierActive,
                                activeColor: .cyan
                            )
                        }

                        if #available(iOS 17.0, macOS 14.0, *) {
                            Button(intent: ToggleExhaustFanIntent()) {
                                ActuatorButtonTile(
                                    title: "Ventilatie",
                                    icon: "wind",
                                    isActive: snapshot.isExhaustFanActive,
                                    activeColor: Color(red: 0.2, green: 0.6, blue: 1.0)
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            ActuatorButtonTile(
                                title: "Ventilatie",
                                icon: "wind",
                                isActive: snapshot.isExhaustFanActive,
                                activeColor: Color(red: 0.2, green: 0.6, blue: 1.0)
                            )
                        }
                    }

                    HStack(spacing: 6) {
                        if #available(iOS 17.0, macOS 14.0, *) {
                            Button(intent: ToggleGrowLightIntent()) {
                                ActuatorButtonTile(
                                    title: "Kweeklamp",
                                    icon: "lightbulb.fill",
                                    isActive: snapshot.isLightActive,
                                    activeColor: Color.yellow
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            ActuatorButtonTile(
                                title: "Kweeklamp",
                                icon: "lightbulb.fill",
                                isActive: snapshot.isLightActive,
                                activeColor: Color.yellow
                            )
                        }

                        if #available(iOS 17.0, macOS 14.0, *) {
                            Button(intent: TriggerFaePulseIntent()) {
                                ActuatorButtonTile(
                                    title: "Verse Lucht",
                                    icon: "fanblades.fill",
                                    isActive: false,
                                    activeColor: Color.green,
                                    subtitle: "60s"
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            ActuatorButtonTile(
                                title: "Verse Lucht",
                                icon: "fanblades.fill",
                                isActive: false,
                                activeColor: Color.green,
                                subtitle: "60s"
                            )
                        }
                    }
                }

                // 4-tile Telemetry Ribbon
                HStack(spacing: 5) {
                    ClimateMetricTile(icon: "thermometer.medium", label: "TEMP", value: String(format: "%.1f", snapshot.temperatureC), unit: "°", tint: .orange)
                    ClimateMetricTile(icon: "drop.fill", label: "VOCHT", value: "\(Int(round(snapshot.humidityPct)))", unit: "%", tint: .cyan)
                    ClimateMetricTile(icon: "gauge.with.dots.needle.bottom.50percent", label: "VPD", value: String(format: "%.2f", snapshot.vpdKpa), unit: "", tint: .green)
                    ClimateMetricTile(icon: "wind", label: "CO2", value: "\(snapshot.co2Ppm)", unit: "", tint: .gray)
                }

                // Cultivation & Telemetry Detail Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(snapshot.topBatchName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text(snapshot.topBatchStrain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan)
                    }

                    HStack {
                        Text(snapshot.topBatchPhase)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                        if snapshot.topBatchDaysInPhase > 0 {
                            Text("• Dag \(snapshot.topBatchDaysInPhase)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text("\(Int(round(snapshot.topBatchColonization)))% Kolonisatie")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(LinearGradient(colors: [.cyan, .green], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(4, geo.size.width * CGFloat(snapshot.topBatchColonization / 100.0)))
                        }
                    }
                    .frame(height: 5)
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
            }
            .frame(width: 270)
        }
        .padding(12)
    }
}

// MARK: - Entry Views & Configurations

struct MycoLabClimateWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MycoWidgetProvider.Entry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                InlineLockScreenWidgetView(snapshot: entry.snapshot)
            case .accessoryCircular:
                CircularLockScreenWidgetView(snapshot: entry.snapshot)
            case .accessoryRectangular:
                RectangularLockScreenWidgetView(snapshot: entry.snapshot)
            case .accessoryCorner:
                CircularLockScreenWidgetView(snapshot: entry.snapshot)
            case .systemSmall:
                SmallHomeScreenWidgetView(snapshot: entry.snapshot)
                    .widgetURL(URL(string: "mycolab://dashboard"))
            case .systemMedium:
                MediumHomeScreenWidgetView(snapshot: entry.snapshot)
                    .widgetURL(URL(string: "mycolab://dashboard"))
            case .systemLarge:
                LargeHomeScreenWidgetView(snapshot: entry.snapshot)
            case .systemExtraLarge:
                ExtraLargeHomeScreenWidgetView(snapshot: entry.snapshot)
            case .systemExtraLargePortrait:
                ExtraLargeHomeScreenWidgetView(snapshot: entry.snapshot)
            default:
                LargeHomeScreenWidgetView(snapshot: entry.snapshot)
            }
        }
    }
}

public struct MycoLabClimateWidget: Widget {
    public let kind: String = "MycoLabClimateWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: MycoWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                MycoLabClimateWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        WidgetBackdropView()
                    }
            } else {
                MycoLabClimateWidgetEntryView(entry: entry)
                    .padding()
                    .background(WidgetBackdropView())
            }
        }
        .configurationDisplayName("MycoLab Grow Monitor")
        .description("Live climate metrics, colonization progress, grow chamber view, and handy room controls on your iPhone, iPad, and Mac home screens.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])

        #if os(iOS)
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
        #elseif os(macOS)
        if #available(macOS 14.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
        #else
        return config
        #endif
    }
}
