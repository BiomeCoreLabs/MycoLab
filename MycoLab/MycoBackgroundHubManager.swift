import Foundation
import AVFoundation
import UIKit
import BackgroundTasks
import Combine

/// Manages 24/7 background execution, audio keep-alive, battery monitoring, and lab hub operation for MycoLab
@MainActor
final class MycoBackgroundHubManager: ObservableObject {
    static let shared = MycoBackgroundHubManager()
    
    static let bgTaskIdentifier = "com.mycolab.app.autopilot"
    
    @Published var isBackgroundHubActive: Bool = false
    @Published var isKeepScreenOnActive: Bool = false
    @Published var isStreamHubRoleActive: Bool = false
    @Published var isOledStandbyActive: Bool = false
    @Published var lastHubHeartbeat: Date = Date()
    @Published var lastHubActionDescription: String = ""
    @Published var completedAutopilotCyclesCount: Int = 0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal

    /// When true, uses silent audio loop to prevent iOS suspension (optimal for DIY 24/7 dedicated hub iPhones).
    /// When false, adheres strictly to Apple App Store Guideline 2.5.4 by using BGTaskScheduler and idle timer controls only.
    @Published var isAudioKeepAliveAllowed: Bool = false {
        didSet {
            UserDefaults.standard.set(isAudioKeepAliveAllowed, forKey: "mycolab_audio_keepalive_allowed")
            if !isAudioKeepAliveAllowed && isBackgroundHubActive && audioPlayer != nil {
                stopBackgroundHub()
            }
        }
    }
    
    // Battery Telemetry
    @Published var batteryLevel: Float = -1.0
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var isCharging: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var hubAutopilotTimer: AnyCancellable?
    private var batteryObserversSetup: Bool = false
    private var systemObserversSetup: Bool = false
    private var savedScreenBrightness: CGFloat? = nil
    
    private init() {
        if UserDefaults.standard.object(forKey: "mycolab_audio_keepalive_allowed") != nil {
            self.isAudioKeepAliveAllowed = UserDefaults.standard.bool(forKey: "mycolab_audio_keepalive_allowed")
        }
        self.thermalState = ProcessInfo.processInfo.thermalState
        startBatteryMonitoring()
        setupSystemResilienceObservers()
    }
    
    // MARK: - Thermal & Hardware Brightness Control (OLED Standby)
    
    var thermalStateLabelNL: String {
        switch thermalState {
        case .nominal: return "Koel & Stabiel"
        case .fair: return "Licht Warm"
        case .serious: return "Warm (Auto-Koeling)"
        case .critical: return "Heet (Spaarstand)"
        @unknown default: return "Normaal"
        }
    }
    
    var thermalStateLabelEN: String {
        switch thermalState {
        case .nominal: return "Cool & Stable"
        case .fair: return "Slightly Warm"
        case .serious: return "Warm (Auto-Cool)"
        case .critical: return "Hot (Power Save)"
        @unknown default: return "Normal"
        }
    }
    
    /// Engages or disengages hardware-level OLED Standby (dims physical screen backlight to 1% and keeps 24/7 hub + stream alive)
    func setOledStandbyMode(_ active: Bool) {
        isOledStandbyActive = active
        #if !targetEnvironment(macCatalyst)
        if active {
            if savedScreenBrightness == nil {
                savedScreenBrightness = max(0.25, UIScreen.main.brightness)
            }
            UIScreen.main.brightness = 0.01
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            if let restored = savedScreenBrightness {
                UIScreen.main.brightness = restored
                savedScreenBrightness = nil
            } else if UIScreen.main.brightness < 0.15 {
                UIScreen.main.brightness = 0.65
            }
        }
        #endif
    }
    
    private func setupSystemResilienceObservers() {
        guard !systemObserversSetup else { return }
        systemObserversSetup = true
        
        // Monitor thermal state to auto-protect 24/7 camera/hub phones
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.thermalState = ProcessInfo.processInfo.thermalState
                if (self.thermalState == .serious || self.thermalState == .critical) && self.isStreamHubRoleActive {
                    LiveKitStreamManager.shared.setOledSaver(active: true, notifyPeer: true)
                }
            }
        }
        
        // Auto-resume silent audio keep-alive after phone calls, alarms, or Siri interruptions
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isBackgroundHubActive else { return }
                self.ensureAudioKeepAliveRunning()
            }
        }
        
        // Ensure background task & audio keep-alive stay active when app enters background or screen locks
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, (self.isBackgroundHubActive || self.isStreamHubRoleActive || LiveKitStreamManager.shared.currentRole == .broadcaster || UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")) else { return }
                self.beginBackgroundTask(name: "MycoLabs-24-7-Hub")
                self.scheduleBackgroundRefresh()
                self.ensureAudioKeepAliveRunning()
                self.tickHubAutopilot()
            }
        }
        
        // Ensure idle timer and audio keep-alive stay active when app returns to foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let isDedicated = UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
                if self.isStreamHubRoleActive || self.isKeepScreenOnActive || isDedicated || LiveKitStreamManager.shared.currentRole == .broadcaster || LiveKitStreamManager.shared.isStreamHubModeActive {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                self.ensureAudioKeepAliveRunning()
            }
        }
    }
    
    private func ensureAudioKeepAliveRunning() {
        guard isBackgroundHubActive && isAudioKeepAliveAllowed else { return }
        if let player = audioPlayer {
            if !player.isPlaying {
                Task.detached(priority: .userInitiated) {
                    try? AVAudioSession.sharedInstance().setActive(true)
                    await MainActor.run {
                        _ = player.play()
                    }
                }
            }
        } else {
            isBackgroundHubActive = false
            startBackgroundHub()
        }
    }
    
    // MARK: - Battery Monitoring
    
    /// Enables battery monitoring on the device and begins tracking level and charging state
    func startBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBatteryStatus()
        
        guard !batteryObserversSetup else { return }
        batteryObserversSetup = true
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateBatteryStatus()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateBatteryStatus()
            }
        }
    }
    
    func updateBatteryStatus() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        isCharging = (batteryState == .charging || batteryState == .full)
        
        // Broadcast local battery update over stream if active
        if isStreamHubRoleActive {
            NotificationCenter.default.post(
                name: NSNotification.Name("MycoLabBroadcastBatteryUpdate"),
                object: nil,
                userInfo: ["batteryLevel": batteryLevel, "isCharging": isCharging]
            )
        }
    }
    
    var batteryPercentageInt: Int {
        if batteryLevel < 0 { return 100 }
        return Int(round(batteryLevel * 100))
    }
    
    var batteryIconName: String {
        if isCharging {
            return "battery.100.bolt"
        }
        let pct = batteryPercentageInt
        if pct >= 85 { return "battery.100" }
        if pct >= 60 { return "battery.75" }
        if pct >= 35 { return "battery.50" }
        if pct >= 15 { return "battery.25" }
        return "battery.0"
    }
    
    // MARK: - Dedicated 24/7 Stream Hub Operation
    
    /// Activates dedicated Stream Hub mode: 24/7 background audio, idle timer prevention, active autopilot loop, and battery monitoring
    func enableStreamHubMode() {
        isStreamHubRoleActive = true
        startBackgroundHub()
        startBatteryMonitoring()
        setKeepScreenOn(true)
        UIApplication.shared.isIdleTimerDisabled = true
        scheduleBackgroundRefresh()
        startHubAutopilotTimer()
        lastHubHeartbeat = Date()
        lastHubActionDescription = "24/7 Lab Hub Actief (Wi-Fi Stekkers & Autopilot gereed)"
        print("🌿 MycoLabs: Stream Telefoon als 24/7 Lab Hub geactiveerd.")
    }
    
    /// Deactivates stream hub mode
    func disableStreamHubMode() {
        isStreamHubRoleActive = false
        stopHubAutopilotTimer()
        print("⚪️ MycoLabs: Stream Telefoon Lab Hub gedeactiveerd.")
    }
    
    /// Dedicated timer running in .common runloop mode to guarantee autopilot cycles on local Wi-Fi 24/7
    func startHubAutopilotTimer() {
        hubAutopilotTimer?.cancel()
        // Fast 15-second tick loop to evaluate triggers, sensor reads and smart plug schedules
        hubAutopilotTimer = Timer.publish(every: 15.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.tickHubAutopilot()
                }
            }
        
        // Trigger initial tick immediately
        tickHubAutopilot()
    }
    
    func stopHubAutopilotTimer() {
        hubAutopilotTimer?.cancel()
        hubAutopilotTimer = nil
    }
    
    private func tickHubAutopilot() {
        guard isStreamHubRoleActive || isBackgroundHubActive else { return }
        lastHubHeartbeat = Date()
        completedAutopilotCyclesCount += 1
        thermalState = ProcessInfo.processInfo.thermalState
        updateBatteryStatus()
        ensureAudioKeepAliveRunning()
        
        // Evaluate tent environment conditions & camera battery for real-time remote push alerting
        let curHum = MycoStore.shared?.db.environmentConfig.currentHumidityPct
        let curTemp = MycoStore.shared?.db.environmentConfig.currentTempC
        
        let isCamDevice = isStreamHubRoleActive || LiveKitStreamManager.shared.currentRole == .broadcaster || UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
        let cameraBat: Float?
        let cameraIsChg: Bool
        if isCamDevice {
            cameraBat = batteryLevel
            cameraIsChg = (batteryState == .charging || batteryState == .full)
        } else {
            cameraBat = MycoStore.shared?.db.environmentConfig.cameraBatteryLevel ?? LiveKitStreamManager.shared.remoteBatteryLevel
            cameraIsChg = (MycoStore.shared?.db.environmentConfig.cameraIsCharging ?? LiveKitStreamManager.shared.remoteIsCharging) == true
        }
        
        MycoLabAlertManager.shared.evaluateConditions(
            humidity: curHum,
            temperature: curTemp,
            batteryPct: cameraBat,
            isCharging: cameraIsChg,
            store: MycoStore.shared
        )
        
        // Strictly prevent sleep/auto-lock while stream hub, keep-screen-on, or dedicated camera is active
        let isDedicated = UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
        if isStreamHubRoleActive || isKeepScreenOnActive || isDedicated || LiveKitStreamManager.shared.currentRole == .broadcaster || LiveKitStreamManager.shared.isStreamHubModeActive {
            if !UIApplication.shared.isIdleTimerDisabled {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
        
        // Trigger Store autopilot and sensor polling (Tuya Smart Plugs + Bluetooth/Wi-Fi Sensors)
        NotificationCenter.default.post(name: NSNotification.Name("MycoLabExecuteHubAutopilotTick"), object: nil)
        
        // Check for smart plug updates from iCloud KVS if newer than local timestamp
        if let rawSmart = MycoKVS.data(forKey: "MycoLabSmartDevicesPayload") {
            let remoteTs = MycoKVS.double(forKey: "MycoLabSmartDevicesTimestamp")
            let lastLocalSync = UserDefaults.standard.double(forKey: "mycolab_last_smart_devices_sync_timestamp")
            if remoteTs > lastLocalSync {
                if let decoded = try? JSONDecoder().decode([SmartDeviceItem].self, from: rawSmart) {
                    let deletedIDs: [UUID] = {
                        guard let dData = MycoKVS.data(forKey: "MycoLabDeletedItemIDsPayload"),
                              let ids = try? JSONDecoder().decode([UUID].self, from: dData) else { return [] }
                        return ids
                    }()
                    
                    var apiKey: String? = nil
                    var apiSec: String? = nil
                    var apiReg: String? = nil
                    var devId: String? = nil
                    var ver: Bool? = nil
                    if let tData = MycoKVS.data(forKey: "MycoLabTuyaCredentials"),
                       let json = try? JSONSerialization.jsonObject(with: tData) as? [String: Any] {
                        apiKey = json["tuyaApiKey"] as? String
                        apiSec = json["tuyaApiSecret"] as? String
                        apiReg = json["tuyaRegion"] as? String
                        devId = json["tuyaDeviceID"] as? String
                        ver = json["tuyaVerified"] as? Bool
                    }
                    
                    MycoSyncManager.shared.mergeIncomingSmartDevices(
                        decoded,
                        incomingDeletedIDs: deletedIDs,
                        tuyaApiKey: apiKey,
                        tuyaApiSecret: apiSec,
                        tuyaRegion: apiReg,
                        tuyaDeviceID: devId,
                        tuyaVerified: ver
                    )
                    UserDefaults.standard.set(remoteTs, forKey: "mycolab_last_smart_devices_sync_timestamp")
                }
            }
        }
        
        // Broadcast heartbeat + live sensor telemetry to any connected viewers
        NotificationCenter.default.post(name: NSNotification.Name("MycoLabBroadcastHubHeartbeat"), object: nil)
        if isStreamHubRoleActive {
            MycoSensorIntelligenceManager.shared.broadcastTelemetryToViewers()
        }
    }
    
    // MARK: - Background Audio Keep-Alive
    
    /// Starts 24/7 background audio keep-alive and 15s autopilot/sensor timer so iOS does not suspend the app when locked or in the background
    func startBackgroundHub() {
        startBatteryMonitoring()
        scheduleBackgroundRefresh()
        startHubAutopilotTimer()
        
        guard isAudioKeepAliveAllowed else {
            // Respect Apple Guideline 2.5.4 & battery efficiency:
            // Do not start continuous audio loop unless the user explicitly enabled it for a dedicated DIY hub device.
            return
        }
        
        guard !isBackgroundHubActive else {
            ensureAudioKeepAliveRunning()
            return
        }
        isBackgroundHubActive = true
        let silentWav = Self.generateSilentAudioData()
        
        Task.detached(priority: .userInitiated) {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                
                let player = try AVAudioPlayer(data: silentWav)
                player.numberOfLoops = -1 // Infinite loop
                player.volume = 0.0 // Completely silent
                player.prepareToPlay()
                player.play()
                
                await MycoBackgroundHubManager.shared.didStartAudioPlayer(player)
            } catch {
                await MycoBackgroundHubManager.shared.didFailStartingAudioPlayer(error)
            }
        }
    }
    
    private func didStartAudioPlayer(_ player: AVAudioPlayer) {
        guard isBackgroundHubActive else {
            player.stop()
            Task.detached(priority: .userInitiated) {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
            return
        }
        self.audioPlayer = player
        print("🟢 MycoLabs: 24/7 Background Hub audio keep-alive gestart.")
    }
    
    private func didFailStartingAudioPlayer(_ error: Error) {
        isBackgroundHubActive = false
        print("⚠️ MycoLabs: Kon background audio session niet starten: \(error.localizedDescription)")
    }
    
    /// Stops background audio keep-alive
    func stopBackgroundHub() {
        audioPlayer?.stop()
        audioPlayer = nil
        isBackgroundHubActive = false
        
        Task.detached(priority: .userInitiated) {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("⚠️ MycoLabs: Kon background audio session niet deactiveren: \(error.localizedDescription)")
            }
        }
        print("⚪️ MycoLabs: 24/7 Background Hub gestopt.")
    }
    
    /// Toggles Keep Screen On (Lab Docking Station mode)
    func setKeepScreenOn(_ enabled: Bool) {
        isKeepScreenOnActive = enabled
        UIApplication.shared.isIdleTimerDisabled = enabled
    }
    
    /// Begins a finite background task for executing in-flight cycles or network calls
    func beginBackgroundTask(name: String = "MycoLabs-Autopilot", expiration: (() -> Void)? = nil) {
        endBackgroundTask()
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            expiration?()
            self?.endBackgroundTask()
        }
    }
    
    func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    
    /// Schedules a BGAppRefreshTask with BGTaskScheduler as secondary wake-up mechanism
    func scheduleBackgroundRefresh() {
        #if !targetEnvironment(macCatalyst)
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min minimum
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("⚠️ BGTaskScheduler submission error: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Generates a 1-second silent 16-bit PCM WAV data in memory
    nonisolated private static func generateSilentAudioData() -> Data {
        let sampleRate: Int32 = 8000
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let blockAlign = Int16(numChannels * (bitsPerSample / 8))
        let byteRate = sampleRate * Int32(blockAlign)
        let numSamples: Int32 = sampleRate * 1
        let dataSize = numSamples * Int32(blockAlign)
        let chunkSize = 36 + dataSize
        
        var data = Data()
        data.append(Data("RIFF".utf8))
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(Data("WAVE".utf8))
        data.append(Data("fmt ".utf8))
        let subchunk1Size: Int32 = 16
        data.append(contentsOf: withUnsafeBytes(of: subchunk1Size.littleEndian) { Array($0) })
        let audioFormat: Int16 = 1 // PCM
        data.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        data.append(Data("data".utf8))
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        data.append(contentsOf: [UInt8](repeating: 0, count: Int(dataSize)))
        return data
    }
}
