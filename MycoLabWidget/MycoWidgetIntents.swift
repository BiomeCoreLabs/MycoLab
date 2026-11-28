//
//  MycoWidgetIntents.swift
//  MycoLabWidget
//
//  Created for MycoLab on 28/11/2026.
//

import AppIntents
import WidgetKit
import Foundation

// MARK: - Direct Hub Background Control Helper
private func sendHubSwitchCommand(deviceType: String, on: Bool) {
    let appGroupID = "group.com.mycolab.app"
    let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
    let host = defaults.string(forKey: "mycolab_pi_hub_ip") ?? "pi-lab.local"
    let port = defaults.integer(forKey: "mycolab_pi_hub_port") > 0 ? defaults.integer(forKey: "mycolab_pi_hub_port") : 8088
    
    guard let url = URL(string: "http://\(host):\(port)/switch") else { return }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.timeoutInterval = 1.8
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let payload: [String: Any] = [
        "device_id": "",
        "name": "",
        "on": on,
        "trigger": "widget_live_intent",
        "device_type": deviceType
    ]
    req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
    
    let session = URLSession(configuration: .ephemeral)
    let task = session.dataTask(with: req) { _, _, _ in }
    task.resume()
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct ToggleHumidifierIntent: AppIntent {
    public static var title: LocalizedStringResource = "Schakel Bevochtiger"
    public static var description = IntentDescription("Schakel de ultrasone bevochtiger van de kweekruimte in of uit.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        let appGroupID = "group.com.mycolab.app"
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        var newState = false
        if let data = defaults.data(forKey: "mycolab_widget_snapshot"),
           var snapshot = try? JSONDecoder().decode(MycoWidgetSnapshot.self, from: data) {
            snapshot.isHumidifierActive.toggle()
            newState = snapshot.isHumidifierActive
            snapshot.activeDeviceSummary = snapshot.isHumidifierActive ? "💧 Bevochtiger AAN" : "💤 Standby"
            if let encoded = try? JSONEncoder().encode(snapshot) {
                defaults.set(encoded, forKey: "mycolab_widget_snapshot")
            }
        }
        defaults.set("toggle_humidifier", forKey: "mycolab_pending_actuator_action")
        defaults.set(Date().timeIntervalSince1970, forKey: "mycolab_last_widget_command_timestamp")
        sendHubSwitchCommand(deviceType: "Humidifier", on: newState)
        WidgetCenter.shared.reloadTimelines(ofKind: "MycoLabWidget")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct ToggleExhaustFanIntent: AppIntent {
    public static var title: LocalizedStringResource = "Schakel Ventilatie (FAE)"
    public static var description = IntentDescription("Schakel de verse lucht afzuiger in of uit.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        let appGroupID = "group.com.mycolab.app"
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        var newState = false
        if let data = defaults.data(forKey: "mycolab_widget_snapshot"),
           var snapshot = try? JSONDecoder().decode(MycoWidgetSnapshot.self, from: data) {
            snapshot.isExhaustFanActive.toggle()
            newState = snapshot.isExhaustFanActive
            snapshot.activeDeviceSummary = snapshot.isExhaustFanActive ? "🌪️ Afzuiger AAN (FAE)" : "💤 Standby"
            if let encoded = try? JSONEncoder().encode(snapshot) {
                defaults.set(encoded, forKey: "mycolab_widget_snapshot")
            }
        }
        defaults.set("toggle_fan", forKey: "mycolab_pending_actuator_action")
        defaults.set(Date().timeIntervalSince1970, forKey: "mycolab_last_widget_command_timestamp")
        sendHubSwitchCommand(deviceType: "ExhaustFan", on: newState)
        WidgetCenter.shared.reloadTimelines(ofKind: "MycoLabWidget")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct ToggleGrowLightIntent: AppIntent {
    public static var title: LocalizedStringResource = "Schakel Kweeklamp"
    public static var description = IntentDescription("Schakel de 6500K LED kweekverlichting in of uit.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        let appGroupID = "group.com.mycolab.app"
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        var newState = false
        if let data = defaults.data(forKey: "mycolab_widget_snapshot"),
           var snapshot = try? JSONDecoder().decode(MycoWidgetSnapshot.self, from: data) {
            snapshot.isLightActive.toggle()
            newState = snapshot.isLightActive
            snapshot.activeDeviceSummary = snapshot.isLightActive ? "💡 Kweeklamp AAN" : "💤 Standby"
            if let encoded = try? JSONEncoder().encode(snapshot) {
                defaults.set(encoded, forKey: "mycolab_widget_snapshot")
            }
        }
        defaults.set("toggle_light", forKey: "mycolab_pending_actuator_action")
        defaults.set(Date().timeIntervalSince1970, forKey: "mycolab_last_widget_command_timestamp")
        sendHubSwitchCommand(deviceType: "GrowLight", on: newState)
        WidgetCenter.shared.reloadTimelines(ofKind: "MycoLabWidget")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct TriggerFaePulseIntent: AppIntent {
    public static var title: LocalizedStringResource = "Verse Lucht Pulse"
    public static var description = IntentDescription("Geef de kweekkamer direct 60 seconden verse lucht verversing.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        let appGroupID = "group.com.mycolab.app"
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        if let data = defaults.data(forKey: "mycolab_widget_snapshot"),
           var snapshot = try? JSONDecoder().decode(MycoWidgetSnapshot.self, from: data) {
            snapshot.isExhaustFanActive = true
            snapshot.activeDeviceSummary = "🌪️ FAE Pulse Actief (60s)"
            if let encoded = try? JSONEncoder().encode(snapshot) {
                defaults.set(encoded, forKey: "mycolab_widget_snapshot")
            }
        }
        defaults.set("trigger_fae_pulse", forKey: "mycolab_pending_actuator_action")
        defaults.set(Date().timeIntervalSince1970, forKey: "mycolab_last_widget_command_timestamp")
        sendHubSwitchCommand(deviceType: "ExhaustFan", on: true)
        WidgetCenter.shared.reloadTimelines(ofKind: "MycoLabWidget")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
