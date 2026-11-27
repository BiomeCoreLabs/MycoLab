//
//  MycoLiveActivityWidget.swift
//  MycoLabWidget
//
//  ActivityKit Live Activity widget supporting Dynamic Island and Lock Screen.
//

import ActivityKit
import WidgetKit
import SwiftUI

public struct MycoLiveActivityWidget: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: MycoLiveActivityAttributes.self) { context in
            // Lock Screen Live Activity Banner
            lockScreenBanner(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Leading
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("🍄")
                            Text(context.attributes.batchName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        Text(context.attributes.phaseName + (context.attributes.dayCount > 0 ? " • Day \(context.attributes.dayCount)" : ""))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                    .padding(.leading, 8)
                }
                
                // Expanded Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 3) {
                            Text("VPD")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f kPa", context.state.vpdKpa))
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundColor(context.state.vpdKpa >= 0.10 && context.state.vpdKpa <= 0.35 ? .green : .orange)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                    }
                    .padding(.trailing, 8)
                }
                
                // Expanded Center / Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        if let timerEnd = context.state.timerEndDate, let timerTitle = context.state.timerTitle {
                            HStack(spacing: 8) {
                                Image(systemName: "timer")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Text(timerTitle)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text(timerEnd, style: .timer)
                                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(8)
                        } else {
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Image(systemName: "thermometer.medium")
                                        .foregroundColor(.orange)
                                    Text(String(format: "%.1f°C", context.state.tempC))
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "humidity.fill")
                                        .foregroundColor(.cyan)
                                    Text(String(format: "%.0f%% RH", context.state.humidityPct))
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.cyan)
                                }
                                
                                Spacer()
                                
                                Text(context.state.activeDeviceSummary)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.1))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Text("🍄")
                    Text(String(format: "%.0f°", context.state.tempC))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
            } compactTrailing: {
                if let timerEnd = context.state.timerEndDate {
                    Text(timerEnd, style: .timer)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                        .frame(width: 44)
                } else {
                    Text(String(format: "%.0f%%", context.state.humidityPct))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                }
            } minimal: {
                if context.state.timerEndDate != nil {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                } else {
                    Text("🍄")
                }
            }
        }
    }
    
    // MARK: - Lock Screen Live Activity Banner
    @ViewBuilder
    private func lockScreenBanner(context: ActivityViewContext<MycoLiveActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row
            HStack(spacing: 6) {
                Text("🍄")
                Text(context.attributes.batchName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(context.attributes.phaseName)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.2))
                    .foregroundColor(.cyan)
                    .cornerRadius(4)
                
                if context.attributes.dayCount > 0 {
                    Text("Day \(context.attributes.dayCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // VPD Badge
                HStack(spacing: 3) {
                    Text("VPD")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f kPa", context.state.vpdKpa))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(context.state.vpdKpa >= 0.10 && context.state.vpdKpa <= 0.35 ? .green : .orange)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .cornerRadius(4)
            }
            
            // Timer or Climate Row
            if let timerEnd = context.state.timerEndDate, let timerTitle = context.state.timerTitle {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                        Text(timerTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(timerEnd, style: .timer)
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(.orange)
                }
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
            } else {
                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Image(systemName: "thermometer.medium")
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f°C", context.state.tempC))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "humidity.fill")
                            .foregroundColor(.cyan)
                        Text(String(format: "%.0f%%", context.state.humidityPct))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                    
                    Spacer()
                    
                    Text(context.state.activeDeviceSummary)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
            }
            
            // Footer status
            Text(context.state.statusSummary)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.7))
                .lineLimit(1)
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.10, blue: 0.15))
    }
}
