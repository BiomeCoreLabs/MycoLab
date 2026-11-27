//
//  LivingSmartDeviceQuickDock.swift
//  MycoLab
//
//  Dashboard Quick-Dock for Connected Smart Lab Devices (Tuya & Mesh Relays):
//  - Displays ONLY real, user-added devices from store.db.smartDevices (NO phantom/dummy devices)
//  - 1-tap toggling for real devices
//  - Living glow pulses reflecting real hardware relay states
//  - Fixed dimensions to prevent tiles from resizing/jumping when toggled
//  - InfoTipButton contextual popovers explaining autopilot rules without screen clutter
//

import SwiftUI

public struct LivingSmartDeviceQuickDock: View {
    @EnvironmentObject var store: MycoStore
    let onOpenSmartHub: () -> Void
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text(store.t(nl: "Smart Hardware", en: "Smart Hardware"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if !store.db.smartDevices.isEmpty {
                        Text("\(store.db.smartDevices.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MycoTheme.green.opacity(0.2))
                            .foregroundColor(MycoTheme.green)
                            .clipShape(Capsule())
                    }
                    
                    InfoTipButton(
                        title: store.t(nl: "Smart Hardware Bediening", en: "Smart Hardware Control"),
                        message: store.t(
                            nl: "Schakel gekoppelde slimme stekkers direct in of uit met één tik. Alleen apparaten die je zelf hebt toegevoegd in de Smart Hub worden hier getoond.",
                            en: "Toggle paired smart plugs with a single tap. Only devices you explicitly added in Smart Hub appear here."
                        )
                    )
                }
                
                Spacer()
                
                Button {
                    onOpenSmartHub()
                } label: {
                    HStack(spacing: 4) {
                        Text(store.t(nl: "Smart Hub", en: "Smart Hub"))
                            .font(.system(size: 11, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(MycoTheme.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MycoTheme.blue.opacity(0.12))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 2)
            
            // Devices Grid or Empty State
            if store.db.smartDevices.isEmpty {
                // Honest, clean empty state when no devices have been added
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 32, height: 32)
                        Image(systemName: "powerplug")
                            .font(.system(size: 13))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Geen apparaten gekoppeld", en: "No devices paired"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text(store.t(nl: "Voeg een Tuya of Wi-Fi stekker toe via de Smart Hub", en: "Add a Tuya or Wi-Fi plug via Smart Hub"))
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        onOpenSmartHub()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text(store.t(nl: "Toevoegen", en: "Add"))
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(MycoTheme.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MycoTheme.blue.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
                .padding(10)
                .background(MycoTheme.card)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
            } else {
                // Render ONLY actual devices added by the user in a stable grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(store.db.smartDevices) { device in
                        realDeviceCard(device: device)
                    }
                }
            }
        }
    }
    
    private func iconForDevice(_ dev: SmartDeviceItem) -> (name: String, color: Color) {
        let type = dev.deviceType.lowercased()
        let name = dev.name.lowercased()
        
        if type.contains("humidifier") || name.contains("bevochtiger") || name.contains("mist") {
            return ("drop.fill", Color.cyan)
        } else if type.contains("fan") || type.contains("exhaust") || name.contains("afzuig") || name.contains("fan") || name.contains("fae") {
            return ("wind", MycoTheme.blue)
        } else if type.contains("light") || name.contains("lamp") || name.contains("licht") {
            return ("lightbulb.fill", MycoTheme.amber)
        } else {
            return ("powerplug.fill", MycoTheme.green)
        }
    }
    
    private func realDeviceCard(device: SmartDeviceItem) -> some View {
        let iconInfo = iconForDevice(device)
        let isOn = device.isOn
        let isAuto = device.autoControlEnabled
        
        let triggerMsg: String = {
            let details = isAuto
                ? (store.isEnglish ? "Autopilot rule active: automatically manages tent climate." : "Autopilot actief: stuurt tentklimaat automatisch aan.")
                : (store.isEnglish ? "Manual control active." : "Handmatige bediening actief.")
            return store.t(
                nl: "Apparaat: \(device.name)\nStatus: \(isOn ? "AAN" : "UIT") (\(isAuto ? "Autopilot" : "Handmatig"))\n\n\(details)",
                en: "Device: \(device.name)\nState: \(isOn ? "ON" : "OFF") (\(isAuto ? "Autopilot" : "Manual"))\n\n\(details)"
            )
        }()
        
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(MycoTheme.card)
            
            if isOn {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(iconInfo.color.opacity(0.6), lineWidth: 1.5)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(MycoTheme.border, lineWidth: 1)
            }
            
            HStack(spacing: 8) {
                // Tap button for power toggle
                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    store.toggleSmartDevice(id: device.id)
                } label: {
                    HStack(spacing: 8) {
                        // Icon with live glow - fixed size
                        ZStack {
                            Circle()
                                .fill(isOn ? iconInfo.color.opacity(0.2) : Color.white.opacity(0.04))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: iconInfo.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isOn ? iconInfo.color : MycoTheme.textSecondary)
                        }
                        .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(isOn ? iconInfo.color : MycoTheme.textSecondary.opacity(0.5))
                                    .frame(width: 5, height: 5)
                                
                                Text(isOn ? store.t(nl: "AAN", en: "ON") : store.t(nl: "UIT", en: "OFF"))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(isOn ? iconInfo.color : MycoTheme.textSecondary)
                                    .lineLimit(1)
                                
                                if device.isManualOverrideActive {
                                    Text(store.t(nl: "• Hand", en: "• Manual"))
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.orange.opacity(0.9))
                                        .lineLimit(1)
                                } else if isAuto {
                                    Text("• Auto")
                                        .font(.system(size: 9))
                                        .foregroundColor(MycoTheme.textSecondary.opacity(0.8))
                                        .lineLimit(1)
                                }
                            }
                            .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer(minLength: 0)
                
                // Embedded InfoTipButton
                InfoTipButton(
                    title: device.name,
                    message: triggerMsg
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(height: 56)
    }
}
