//
//  MycoWidgetIntents.swift
//  MycoLabWidget
//
//  Created for MycoLab on 28/11/2026.
//

import AppIntents
import WidgetKit
import Foundation

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct ToggleHumidifierIntent: AppIntent {
    public static var title: LocalizedStringResource = "Schakel Bevochtiger"
    public static var description = IntentDescription("Schakel de ultrasone bevochtiger van de kweekruimte in of uit.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        let appGroupID = "group.com.mycolab.app"
        let defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
        if let data = defaults.data(forKey: "mycolab_widget_snapshot"),
           var snapshot = try? JSONDecoder().decode(MycoWidgetSnapshot.self, from: data) {
            snapshot.isHumidifierActive.toggle()
            snapshot.activeDeviceSummary = snapshot.isHumidifierActive ? "💧 Bevochtiger AAN" : "💤 Standby"
            if let encoded = try? JSONEncoder().encode(snapshot) {
                defaults.set(encoded, forKey: "mycolab_widget_snapshot")
            }
        }
        defaults.set("toggle_humidifier", forKey: "mycolab_pending_actuator_action")
        defaults.set(Date().timeIntervalSince1970, forKey: "mycolab_last_widget_command_timestamp")
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
        if let data = defaults.data(forKey: "mycolab_widget_snapshot"),
           var snapshot = try? JSONDecoder().decode(MycoWidgetSnapshot.self, from: data) {
            snapshot.isExhaustFanActive.toggle()
            snapshot.activeDeviceSummary = snapshot.isExhaustFanActive ? "🌪️ Afzuiger AAN (FAE)" : "💤 Standby"
            if let encoded = try? JSONEncoder().encode(snapshot) {
                defaults.set(encoded, forKey: "mycolab_widget_snapshot")
            }
        }
        defaults.set("toggle_fan", forKey: "mycolab_pending_actuator_action")
        defaults.set(Date().timeIntervalSince1970, forKey: "mycolab_last_widget_command_timestamp")
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
        if let data = defaults.data(forKey: "mycolab_widget_snapshot"),
           var snapshot = try? JSONDecoder().decode(MycoWidgetSnapshot.self, from: data) {
            snapshot.isLightActive.toggle()
            snapshot.activeDeviceSummary = snapshot.isLightActive ? "💡 Kweeklamp AAN" : "💤 Standby"
            if let encoded = try? JSONEncoder().encode(snapshot) {
                defaults.set(encoded, forKey: "mycolab_widget_snapshot")
            }
        }
        defaults.set("toggle_light", forKey: "mycolab_pending_actuator_action")
        defaults.set(Date().timeIntervalSince1970, forKey: "mycolab_last_widget_command_timestamp")
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
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
