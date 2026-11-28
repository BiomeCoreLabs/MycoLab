import SwiftUI
import UserNotifications
import BackgroundTasks

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even while app is in the foreground
        completionHandler([.banner, .sound, .badge, .list])
    }
}

@main struct MyApp: App {
    @StateObject private var store = MycoStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Register Background Task for periodic autopilot execution
        #if !targetEnvironment(macCatalyst)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: MycoBackgroundHubManager.bgTaskIdentifier,
            using: nil
        ) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                MycoStore.shared?.runAutopilotCycle()
                MycoStore.shared?.pollAllConnectedSensors()
                MycoBackgroundHubManager.shared.scheduleBackgroundRefresh()
                appRefreshTask.setTaskCompleted(success: true)
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    store.triggerStartupBiometrics()
                    let isDedicated = UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
                    if store.db.environmentConfig.is24_7HubBackgroundModeEnabled || isDedicated {
                        MycoBackgroundHubManager.shared.startBackgroundHub()
                    }
                    if store.db.environmentConfig.isScreenAlwaysOnEnabled || isDedicated {
                        MycoBackgroundHubManager.shared.setKeepScreenOn(true)
                        UIApplication.shared.isIdleTimerDisabled = true
                    }
                    LiveKitStreamManager.shared.startScreenAwakeWatchdog()
                }
            .onChange(of: scenePhase) { _, newPhase in
                let isDedicated = UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
                if newPhase == .active {
                    store.handleAppBecameActive()
                    if store.db.environmentConfig.is24_7HubBackgroundModeEnabled || isDedicated {
                        MycoBackgroundHubManager.shared.startBackgroundHub()
                    }
                    if store.db.environmentConfig.isScreenAlwaysOnEnabled || isDedicated {
                        MycoBackgroundHubManager.shared.setKeepScreenOn(true)
                        UIApplication.shared.isIdleTimerDisabled = true
                    }
                    LiveKitStreamManager.shared.startScreenAwakeWatchdog()
                } else if newPhase == .background {
                    store.saveImmediately()
                    if store.db.environmentConfig.is24_7HubBackgroundModeEnabled || isDedicated {
                        MycoBackgroundHubManager.shared.startBackgroundHub()
                    }
                    MycoBackgroundHubManager.shared.scheduleBackgroundRefresh()
                } else if newPhase == .inactive {
                    store.saveImmediately()
                }
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
        .defaultSize(width: 1240, height: 840)
#if !STREAM_PHONE_ONLY
        .commands {
            CommandMenu("Laboratorium") {
                Button("Dashboard") {
                    NotificationCenter.default.post(name: NSNotification.Name("MycoLabSwitchTab"), object: 0)
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Culturen & Genetica") {
                    NotificationCenter.default.post(name: NSNotification.Name("MycoLabSwitchTab"), object: 1)
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("Stash & Voorraad") {
                    NotificationCenter.default.post(name: NSNotification.Name("MycoLabSwitchTab"), object: 2)
                }
                .keyboardShortcut("3", modifiers: .command)
                
                Button("Tools & Presets") {
                    NotificationCenter.default.post(name: NSNotification.Name("MycoLabSwitchTab"), object: 3)
                }
                .keyboardShortcut("4", modifiers: .command)
                
                Divider()
                
                Button("AI & QR Scanner Openen") {
                    NotificationCenter.default.post(name: NSNotification.Name("MycoLabOpenQRScanner"), object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button("Nieuwe Batch Starten") {
                    NotificationCenter.default.post(name: NSNotification.Name("MycoLabSwitchTab"), object: 0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: NSNotification.Name("MycoLabNewBatchShortcut"), object: nil)
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
#endif
    }

    private func handleIncomingURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "mycolab" else { return }
        if url.host?.lowercased() == "sensor" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let items = components.queryItems else { return }
            
            let tempStr = items.first(where: { $0.name == "temp" || $0.name == "t" })?.value
            let humStr = items.first(where: { $0.name == "humidity" || $0.name == "hum" || $0.name == "rv" })?.value
            let co2Str = items.first(where: { $0.name == "co2" })?.value
            
            let temp = tempStr.flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
            let hum = humStr.flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
            let co2 = co2Str.flatMap { Int($0) }
            
            store.recordSensorReading(tempC: temp, humidityPct: hum, co2Ppm: co2, source: "Webhook API")
            store.runAutopilotCycle()
        } else if url.host?.lowercased() == "control" || url.host?.lowercased() == "device" {
            store.checkPendingWidgetCommands()
        } else if url.host?.lowercased() == "hub" || url.host?.lowercased() == "pair-hub" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let items = components.queryItems else { return }
            if let host = items.first(where: { $0.name == "host" || $0.name == "ip" })?.value, !host.isEmpty {
                store.db.environmentConfig.piHubIP = host
                if let portStr = items.first(where: { $0.name == "port" })?.value, let p = Int(portStr) {
                    store.db.environmentConfig.piHubPort = p
                }
                store.saveImmediately()
                MycoSyncManager.shared.triggerToast(message: "🍓 MycoLab Hub: \(host)")
                NotificationCenter.default.post(name: NSNotification.Name("MycoLabSwitchTab"), object: 3)
            }
        } else if url.host?.lowercased() == "camera" || url.host?.lowercased() == "live" {
            NotificationCenter.default.post(name: NSNotification.Name("MycoLabSwitchTab"), object: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: NSNotification.Name("MycoLabOpenLiveMonitor"), object: nil)
            }
        }
    }
}
