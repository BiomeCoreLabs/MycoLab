//
//  MycoLabWidget.swift
//  MycoLabWidget
//
//  Created for MycoLab on 03/11/2026.
//

import WidgetKit
import SwiftUI

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
        vpdZoneTitle: String = "Ideal"
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
            case .systemMedium:
                MediumHomeScreenWidgetView(snapshot: entry.snapshot)
            default:
                SmallHomeScreenWidgetView(snapshot: entry.snapshot)
            }
        }
        .widgetURL(URL(string: "mycolab://dashboard"))
    }
}

public struct MycoLabClimateWidget: Widget {
    public let kind: String = "MycoLabClimateWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MycoWidgetProvider()) { entry in
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
        .description("Live climate metrics, colonization progress, and grow alerts on your home and lock screen.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}
