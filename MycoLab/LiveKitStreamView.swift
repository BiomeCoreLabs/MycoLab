//
//  LiveKitStreamView.swift
//  MycoLab
//
//  Real-time WebRTC HD Live Streaming for MycoLab using LiveKit Cloud.
//  Works seamlessly over Wi-Fi, 4G, and 5G anywhere in the world.
//

import SwiftUI
import AVFoundation
import Photos
import Combine
import LiveKit
import Network

public enum LiveKitRole: String, CaseIterable, Identifiable {
    case broadcaster = "Kweekcamera"
    case viewer = "Live Kijker"

    public var id: String { rawValue }

    public func localizedName(isEnglish: Bool) -> String {
        switch self {
        case .broadcaster: return isEnglish ? "Grow Camera" : "Kweekcamera"
        case .viewer: return isEnglish ? "Live Monitor" : "Live Kijker"
        }
    }
}

public struct AvailableCamera: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let shortLabel: String
    public let position: AVCaptureDevice.Position
    public let deviceType: AVCaptureDevice.DeviceType
}

public struct RemoteCameraInfo: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let shortLabel: String

    public init(id: String, name: String, shortLabel: String) {
        self.id = id
        self.name = name
        self.shortLabel = shortLabel
    }
}

// MARK: - Stream Quality Preset (4K Ultra HD, 1080p Full HD, 720p HD)
public enum StreamQualityPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case ultra4K = "4k"
    case fullHD1080p = "1080p"
    case hd720p = "720p"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ultra4K: return "4K Ultra HD (3840×2160)"
        case .fullHD1080p: return "1080p Full HD (1920×1080)"
        case .hd720p: return "720p HD (1280×720)"
        }
    }

    public var shortTitle: String {
        switch self {
        case .ultra4K: return "4K UHD"
        case .fullHD1080p: return "1080p"
        case .hd720p: return "720p"
        }
    }

    public var icon: String {
        switch self {
        case .ultra4K: return "sparkles"
        case .fullHD1080p: return "tv"
        case .hd720p: return "gauge.medium"
        }
    }

    public func dimensions(aspectRatio: String) -> Dimensions {
        let is169 = aspectRatio == "16:9"
        switch self {
        case .ultra4K:
            return is169 ? .h2160_169 : .h1440_43
        case .fullHD1080p:
            return is169 ? .h1080_169 : .h1080_43
        case .hd720p:
            return is169 ? .h720_169 : .h720_43
        }
    }

    public var videoEncoding: VideoEncoding {
        switch self {
        case .ultra4K:
            return VideoEncoding(maxBitrate: 8_000_000, maxFps: 30)
        case .fullHD1080p:
            return VideoEncoding(maxBitrate: 4_500_000, maxFps: 30)
        case .hd720p:
            return VideoEncoding(maxBitrate: 1_800_000, maxFps: 30)
        }
    }

    public var publishOptions: VideoPublishOptions {
        VideoPublishOptions(
            encoding: videoEncoding,
            simulcast: true,
            degradationPreference: .maintainResolution
        )
    }
}

// MARK: - Dedicated Video Track Single Frame Grabber
final class VideoTrackFrameGrabber: NSObject, VideoRenderer, @unchecked Sendable {
    let isAdaptiveStreamEnabled: Bool = false
    let adaptiveStreamSize: CGSize = CGSize(width: 3840, height: 2160)

    private let lock = NSLock()
    private var continuation: CheckedContinuation<UIImage?, Never>?
    private weak var track: VideoTrack?
    private static let ciContext = CIContext(options: nil)

    init(track: VideoTrack, continuation: CheckedContinuation<UIImage?, Never>) {
        self.track = track
        self.continuation = continuation
        super.init()
    }

    func render(frame: VideoFrame) {
        lock.lock()
        guard let cont = self.continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        let targetTrack = self.track
        self.track = nil
        lock.unlock()

        // Detach renderer asynchronously on background queue so we NEVER block WebRTC's worker thread
        if let targetTrack = targetTrack {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                targetTrack.remove(videoRenderer: self)
            }
        }

        let orientation: UIImage.Orientation = {
            switch frame.rotation {
            case ._90: return .right
            case ._180: return .down
            case ._270: return .left
            default: return .up
            }
        }()

        // Use toCVPixelBuffer() to support both CVPixelVideoBuffer and I420VideoBuffer
        if let pixelBuffer = frame.toCVPixelBuffer() {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            if let cgImage = Self.ciContext.createCGImage(ciImage, from: ciImage.extent) {
                let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
                cont.resume(returning: image)
                return
            }
        }

        cont.resume(returning: nil)
    }

    func handleTimeout() {
        lock.lock()
        guard let cont = self.continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        let targetTrack = self.track
        self.track = nil
        lock.unlock()

        if let targetTrack = targetTrack {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                targetTrack.remove(videoRenderer: self)
            }
        }

        cont.resume(returning: nil)
    }
}

// MARK: - Continuous P2P Local Video Frame Broadcaster (0 Cloud Tokens)
final class P2PStreamBroadcaster: NSObject, VideoRenderer, @unchecked Sendable {
    static let shared = P2PStreamBroadcaster()
    let isAdaptiveStreamEnabled: Bool = false
    let adaptiveStreamSize: CGSize = .zero

    private static let ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
    private var lastSendTime: TimeInterval = 0

    func render(frame: VideoFrame) {
        let now = CACurrentMediaTime()
        // Broadcast at ~12-15 FPS (every 0.07s) for ultra-low latency & zero thermal heat
        guard now - lastSendTime >= 0.07 else { return }
        lastSendTime = now

        guard let pixelBuffer = frame.toCVPixelBuffer() else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        if let cgImage = Self.ciContext.createCGImage(ciImage, from: ciImage.extent) {
            let orientation: UIImage.Orientation = {
                switch frame.rotation {
                case ._90: return .right
                case ._180: return .down
                case ._270: return .left
                default: return .up
                }
            }()
            let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
            Task { @MainActor in
                MycoCamStreamManager.shared.broadcastCameraFrame(image)
            }
        }
    }
}

@MainActor
public final class LiveKitStreamManager: NSObject, ObservableObject {
    public static let shared = LiveKitStreamManager()

    // MARK: - Published UI State
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var isConnected: Bool = false
    @Published public var statusMessage: String = "Standby"
    @Published public var localVideoTrack: VideoTrack? = nil
    @Published public var remoteVideoTrack: VideoTrack? = nil
    @Published public var showFloatingPiP: Bool = false
    @Published public var isTorchOn: Bool = false
    @Published public var torchBrightness: Float = 0.8
    @Published public var isOledSaverActive: Bool = false
    @Published public var isRemoteScreenDimmed: Bool = false
    @Published public var remoteCameraHasScreen: Bool = true
    
    /// Dynamic hardware adaptation: returns true if the remote camera has a display/screen that can be put to sleep
    public var currentRemoteCameraHasScreen: Bool {
        if let store = MycoStore.shared {
            let src = store.db.environmentConfig.effectiveCameraSource
            if src == .rtsp || src == .httpSnapshot || src == .none {
                return false
            }
        }
        return remoteCameraHasScreen
    }
    
    public var connectedCameraDisplayName: String {
        if let store = MycoStore.shared {
            let src = store.db.environmentConfig.effectiveCameraSource
            switch src {
            case .rtsp: return "RTSP IP-Camera"
            case .httpSnapshot: return "ESP32-CAM / Pi Cam"
            case .none: return "Geen camera"
            case .liveKit:
                if let peer = MycoCamPairingManager.shared.pairedCameraName, !peer.isEmpty {
                    return peer
                }
                return "MycoCam Kweekcamera"
            }
        }
        return "Kweekcamera"
    }
    @Published public var participantCount: Int = 1
    @Published public var currentRoomName: String = ""
    @Published public var isViewerWaitingTooLong: Bool = false
    @Published public var isBroadcastingPaused: Bool = false
    @Published public var isReconnecting: Bool = false
    @Published public var isStartingStream: Bool = false
    private var isStartingLocalCameraTrack: Bool = false
    public var isUserInitiatedStop: Bool = false
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mycolab.livekit.networkmonitor")
    private var isPathMonitorActive = false
    private var lastObservedInterfaceType: NWInterface.InterfaceType? = nil
    private var reconnectTask: Task<Void, Never>? = nil
    @Published public var autoReconnectAttempts: Int = 0
    private let maxAutoReconnectAttempts: Int = 10
    @Published public var isQuotaExceeded: Bool = false
    
    // Persistent Auto-Reconnect setting (User option to keep reconnecting forever after crashes or battery loss)
    @Published public var isPersistentAutoReconnectEnabled: Bool = UserDefaults.standard.object(forKey: "mycolab_persistent_autoreconnect") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isPersistentAutoReconnectEnabled, forKey: "mycolab_persistent_autoreconnect")
        }
    }

    // MARK: - Smart LiveKit Token / Standby Management
    public let monthlyLiveKitQuotaMinutes: Double = 5000.0
    @Published public var isEcoTokenSaverEnabled: Bool = {
        let key = "mycolab_livekit_eco_saver_v4"
        return UserDefaults.standard.object(forKey: key) as? Bool ?? false
    }() {
        didSet {
            UserDefaults.standard.set(isEcoTokenSaverEnabled, forKey: "mycolab_livekit_eco_saver_v4")
            if !isEcoTokenSaverEnabled && isInEcoStandby {
                Task { await wakeFromEcoStandby() }
            }
        }
    }
    @Published public var isInEcoStandby: Bool = false
    @Published public var usedLiveKitMinutesThisMonth: Double = 0.0
    @Published public var savedLiveKitMinutesThisMonth: Double = 0.0
    @Published public var noViewerIdleSeconds: Int = 0
    public let ecoIdleTimeoutSeconds: Int = 180
    private var screenAwakeWatchdogTimer: AnyCancellable? = nil

    public func startScreenAwakeWatchdog() {
        screenAwakeWatchdogTimer?.cancel()
        screenAwakeWatchdogTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let shouldKeepAwake = self.currentRole == .broadcaster
                    || self.isStreamHubModeActive
                    || self.isTimelapseRunning
                    || MycoBackgroundHubManager.shared.isStreamHubRoleActive
                    || MycoBackgroundHubManager.shared.isKeepScreenOnActive
                    || UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
                if shouldKeepAwake {
                    if !UIApplication.shared.isIdleTimerDisabled {
                        UIApplication.shared.isIdleTimerDisabled = true
                    }
                }
            }
    }
    private var ecoTokenMonitorTimer: AnyCancellable? = nil
    private var lastHandledWakeTimestamp: Double = 0.0
    private var lastHandledSleepTimestamp: Double = 0.0

    public var remainingLiveKitMinutesThisMonth: Double {
        max(0.0, monthlyLiveKitQuotaMinutes - usedLiveKitMinutesThisMonth)
    }

    public var remainingLiveKitPercentage: Double {
        min(100.0, max(0.0, (remainingLiveKitMinutesThisMonth / monthlyLiveKitQuotaMinutes) * 100.0))
    }

    private var currentMonthStorageSuffix: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy_MM"
        return df.string(from: Date())
    }

    public func loadMonthlyTokenUsage() {
        let suffix = currentMonthStorageSuffix
        usedLiveKitMinutesThisMonth = UserDefaults.standard.double(forKey: "mycolab_lk_used_mins_\(suffix)")
        savedLiveKitMinutesThisMonth = UserDefaults.standard.double(forKey: "mycolab_lk_saved_mins_\(suffix)")
    }

    private func saveMonthlyTokenUsage() {
        let suffix = currentMonthStorageSuffix
        UserDefaults.standard.set(usedLiveKitMinutesThisMonth, forKey: "mycolab_lk_used_mins_\(suffix)")
        UserDefaults.standard.set(savedLiveKitMinutesThisMonth, forKey: "mycolab_lk_saved_mins_\(suffix)")
    }

    public func startEcoTokenMonitorTimer() {
        ecoTokenMonitorTimer?.cancel()
        ecoTokenMonitorTimer = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.tickEcoTokenMonitor()
            }
    }

    private func tickEcoTokenMonitor() {
        // Enforce 24/7 screen wake on camera / broadcaster / hub devices first
        let shouldKeepAwake = currentRole == .broadcaster
            || isStreamHubModeActive
            || isTimelapseRunning
            || MycoBackgroundHubManager.shared.isStreamHubRoleActive
            || MycoBackgroundHubManager.shared.isKeepScreenOnActive
            || UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
        if shouldKeepAwake {
            if !UIApplication.shared.isIdleTimerDisabled {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }

        if currentRole == .viewer && isConnected {
            usedLiveKitMinutesThisMonth += (5.0 / 60.0)
            saveMonthlyTokenUsage()
            return
        }

        guard currentRole == .broadcaster, isStreamHubModeActive else { return }

        // Continuously check iCloud KVS in the background for new Smart Plugs / Lab Sync updates
        MycoKVS.synchronize()
        MycoStore.shared?.syncCloudData()

        if isInEcoStandby {
            // 0 LiveKit tokens consumed while in Eco-Standby!
            savedLiveKitMinutesThisMonth += (5.0 / 60.0)
            saveMonthlyTokenUsage()

            // Check if a Viewer requested a wake-up via iCloud KVS
            let wakeTs = MycoKVS.double(forKey: "MycoLabLiveKitWakeTimestamp")
            if wakeTs > lastHandledWakeTimestamp && (Date().timeIntervalSince1970 - wakeTs) < 300.0 {
                lastHandledWakeTimestamp = wakeTs
                Task { await self.wakeFromEcoStandby() }
            }
            return
        }

        if isConnected {
            let activeParticipants = max(1, (room?.remoteParticipants.count ?? 0) + 1)
            usedLiveKitMinutesThisMonth += (5.0 / 60.0) * Double(activeParticipants)
            saveMonthlyTokenUsage()

            // Check if Viewer sent a sleep command via iCloud KVS
            let sleepTs = MycoKVS.double(forKey: "MycoLabLiveKitSleepTimestamp")
            if sleepTs > lastHandledSleepTimestamp && (Date().timeIntervalSince1970 - sleepTs) < 120.0 {
                lastHandledSleepTimestamp = sleepTs
                Task { await self.enterEcoStandby() }
                return
            }

            let remoteCount = room?.remoteParticipants.count ?? 0
            if remoteCount == 0 && isEcoTokenSaverEnabled && !isTimelapseRunning && !isStreamHubModeActive && !MycoBackgroundHubManager.shared.isStreamHubRoleActive {
                noViewerIdleSeconds += 5
                if noViewerIdleSeconds >= ecoIdleTimeoutSeconds && !isCapturingSnapshot {
                    Task { await self.enterEcoStandby() }
                }
            } else {
                noViewerIdleSeconds = 0
            }
        }
    }

    public func enterEcoStandby() async {
        guard currentRole == .broadcaster, !isInEcoStandby else { return }
        print("[LiveKitStreamManager] Entering Eco-Standby — disconnecting from LiveKit to guarantee 0 tokens/minutes used.")
        isInEcoStandby = true
        noViewerIdleSeconds = 0
        lastHandledWakeTimestamp = Date().timeIntervalSince1970

        // Disconnect from LiveKit room so LiveKit Cloud completely stops metering participant minutes!
        if let existing = room {
            existing.remove(delegate: self)
            await existing.disconnect()
            self.room = nil
        }
        self.isConnected = false
        self.connectionState = .disconnected
        self.statusMessage = "Standby (Wachten op kijker...)"

        // Keep local camera track running for local preview, optical meter & 24/7 Timelapse captures
        if localVideoTrack == nil {
            await startLocalStandaloneCameraTrack()
        }
    }


    // MARK: - Network Resilience & Auto-Reconnect (Wi-Fi <-> 4G / 5G)
    public func startNetworkPathMonitoring() {
        guard !isPathMonitorActive else { return }
        isPathMonitorActive = true
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let currentInterface: NWInterface.InterfaceType = path.usesInterfaceType(.wifi) ? .wifi : (path.usesInterfaceType(.cellular) ? .cellular : .other)
            let isSatisfied = path.status == .satisfied
            
            Task { @MainActor in
                self.handleNetworkPathUpdate(isSatisfied: isSatisfied, interfaceType: currentInterface)
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func handleNetworkPathUpdate(isSatisfied: Bool, interfaceType: NWInterface.InterfaceType) {
        guard isSatisfied else {
            if isConnected {
                self.statusMessage = "Geen internetverbinding (wachten op signaal)..."
            }
            return
        }
        
        let previousInterface = lastObservedInterfaceType
        lastObservedInterfaceType = interfaceType
        
        if let prev = previousInterface, prev != interfaceType {
            let prevName = prev == .wifi ? "Wi-Fi" : "4G/5G"
            let newName = interfaceType == .wifi ? "Wi-Fi" : "4G/5G"
            print("[LiveKitStreamManager] Network interface switched from \(prevName) to \(newName)")
            
            if !isUserInitiatedStop && !isBroadcastingPaused && !isInEcoStandby && !currentRoomName.isEmpty {
                self.statusMessage = "Netwerk gewisseld naar \(newName). Verbinding herstellen..."
                // Immediate fresh reconnect on interface transition (Wi-Fi <-> 4G/5G) so WebRTC tracks reload seamlessly
                Task { @MainActor in
                    self.reconnectTask?.cancel()
                    self.reconnectTask = nil
                    self.autoReconnectAttempts = 0
                    await self.reconnectCurrentStream(forceFreshSession: true)
                }
            }
        }
    }

    public func scheduleAutoReconnect(immediate: Bool = false) {
        guard !isStartingStream, !isUserInitiatedStop, !isBroadcastingPaused, !isInEcoStandby, !currentRoomName.isEmpty else { return }
        
        // Prevent concurrent or stacking reconnect loops
        guard reconnectTask == nil else { return }
        
        if autoReconnectAttempts >= maxAutoReconnectAttempts {
            self.statusMessage = "Verbinding onderbroken. Tik op 'Opnieuw Proberen'."
            self.isReconnecting = false
            return
        }
        
        autoReconnectAttempts += 1
        self.isReconnecting = true
        
        let delay: Double = immediate ? 0.5 : min(Double(autoReconnectAttempts) * 1.5, 6.0)
        
        if autoReconnectAttempts > 4 {
            self.statusMessage = "Wachten op kweekcamera... (poging \(autoReconnectAttempts)/\(maxAutoReconnectAttempts))"
            if currentRole == .viewer {
                sendWakeSignalToBroadcaster(roomName: currentRoomName)
            }
        } else {
            self.statusMessage = "Verbinding herstellen over 4G/Wi-Fi (\(Int(delay))s, poging \(autoReconnectAttempts)/\(maxAutoReconnectAttempts))..."
        }
        
        reconnectTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            defer { self.reconnectTask = nil }
            guard !Task.isCancelled, !self.isUserInitiatedStop, !self.isBroadcastingPaused else {
                self.isReconnecting = false
                return
            }
            print("[LiveKitStreamManager] Executing auto-reconnect attempt \(self.autoReconnectAttempts)...")
            // After multiple dropped frames or network transition, force fresh session to cleanly rebind WebRTC
            let forceFresh = self.autoReconnectAttempts > 1
            await self.reconnectCurrentStream(forceFreshSession: forceFresh)
        }
    }

    public func reconnectCurrentStream(forceFreshSession: Bool = false) async {
        let role = currentRole
        guard !currentRoomName.isEmpty else {
            self.isReconnecting = false
            return
        }
        let targetRoom = currentRoomName
        
        self.isUserInitiatedStop = false
        self.isBroadcastingPaused = false
        self.isReconnecting = true
        
        if let existing = room {
            existing.remove(delegate: self)
            await existing.disconnect()
            self.room = nil
        }
        self.isConnected = false
        self.connectionState = .connecting
        if forceFreshSession {
            self.remoteVideoTrack = nil
            self.localVideoTrack = nil
        }
        
        if role == .viewer {
            sendWakeSignalToBroadcaster(roomName: targetRoom)
        }
        
        await startStream(role: role, roomName: targetRoom, forceFresh: forceFreshSession)
    }

    public func hardResetAndReconnect(cameraId: String? = nil) async {
        print("[LiveKitStreamManager] Executing HARD RESET & fresh reconnect...")
        reconnectTask?.cancel()
        reconnectTask = nil
        autoReconnectAttempts = 0
        isUserInitiatedStop = false
        isBroadcastingPaused = false
        isReconnecting = false
        statusMessage = "Volledige herverbinding initialiseren..."
        
        if let existing = room {
            existing.remove(delegate: self)
            await existing.disconnect()
            self.room = nil
        }
        self.isConnected = false
        self.remoteVideoTrack = nil
        self.localVideoTrack = nil
        self.connectionState = .connecting
        
        let targetRoom: String
        if currentRole == .viewer {
            targetRoom = resolveTargetCameraRoom(overrideId: cameraId)
            sendWakeSignalToBroadcaster(roomName: targetRoom)
        } else {
            let pairingManager = MycoCamPairingManager.shared
            if let paired = pairingManager.pairedCameraId?.trimmingCharacters(in: .whitespacesAndNewlines), !paired.isEmpty {
                targetRoom = "mycolab-cam-\(paired)"
            } else if let cid = cameraId?.trimmingCharacters(in: .whitespacesAndNewlines), !cid.isEmpty, cid != pairingManager.localCameraId {
                targetRoom = "mycolab-cam-\(cid)"
            } else {
                targetRoom = LiveKitTokenGenerator.currentRoom
            }
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        await startStream(role: currentRole, roomName: targetRoom, forceFresh: true)
    }

    public func pauseBroadcasting() async {
        guard currentRole == .broadcaster, !isBroadcastingPaused else { return }
        print("[LiveKitStreamManager] Pausing broadcast — switching to local camera preview mode.")
        isBroadcastingPaused = true
        isUserInitiatedStop = false
        reconnectTask?.cancel()
        
        if let existingRoom = room {
            existingRoom.remove(delegate: self)
            await existingRoom.disconnect()
            self.room = nil
        }
        self.isConnected = false
        self.connectionState = .disconnected
        self.statusMessage = "Uitzending gepauzeerd (Lokale camera preview actief)"
        
        await startLocalStandaloneCameraTrack()
    }
    
    public func resumeBroadcasting() async {
        guard currentRole == .broadcaster, isBroadcastingPaused else { return }
        print("[LiveKitStreamManager] Resuming broadcast — connecting to LiveKit Cloud...")
        isBroadcastingPaused = false
        let pairingManager = MycoCamPairingManager.shared
        let targetRoom: String
        if !currentRoomName.isEmpty {
            targetRoom = currentRoomName
        } else if let paired = pairingManager.pairedCameraId, !paired.isEmpty {
            targetRoom = "mycolab-cam-\(paired)"
        } else {
            targetRoom = LiveKitTokenGenerator.currentRoom
        }
        await startStream(role: .broadcaster, roomName: targetRoom)
    }

    public func wakeFromEcoStandby() async {
        guard currentRole == .broadcaster, isInEcoStandby else { return }
        print("[LiveKitStreamManager] Waking from Eco-Standby — Viewer requested LiveKit HD stream!")
        isInEcoStandby = false
        noViewerIdleSeconds = 0
        self.statusMessage = "Live HD Uitzending Actief (WebRTC)"
        if room == nil || !isConnected {
            let pairingManager = MycoCamPairingManager.shared
            let targetRoom: String
            if !currentRoomName.isEmpty {
                targetRoom = currentRoomName
            } else if let paired = pairingManager.pairedCameraId, !paired.isEmpty {
                targetRoom = "mycolab-cam-\(paired)"
            } else {
                targetRoom = LiveKitTokenGenerator.currentRoom
            }
            await startStream(role: .broadcaster, roomName: targetRoom)
        } else if self.localVideoTrack == nil {
            _ = await self.ensureCameraTrackAvailable()
        }
    }

    public func sendWakeSignalToBroadcaster(roomName: String? = nil) {
        let nowTs = Date().timeIntervalSince1970
        MycoKVS.set(nowTs, forKey: "MycoLabLiveKitWakeTimestamp")
        if let r = roomName {
            MycoKVS.set(r, forKey: "MycoLabLiveKitWakeRoom")
        }
        MycoKVS.synchronize()
        _ = MycoCamPairingManager.shared.sendDirectCommandToPeers("livekit:wake:\(Int(nowTs))")
    }

    public func sendSleepSignalToBroadcaster(roomName: String? = nil) {
        let nowTs = Date().timeIntervalSince1970
        MycoKVS.set(nowTs, forKey: "MycoLabLiveKitSleepTimestamp")
        if let r = roomName {
            MycoKVS.set(r, forKey: "MycoLabLiveKitSleepRoom")
        }
        MycoKVS.synchronize()
        _ = MycoCamPairingManager.shared.sendDirectCommandToPeers("livekit:sleep:\(Int(nowTs))")
    }

    public func startLocalStandaloneCameraTrack() async {
        if let existing = localVideoTrack {
            existing.add(videoRenderer: P2PStreamBroadcaster.shared)
            return
        }
        guard !isStartingLocalCameraTrack else { return }
        isStartingLocalCameraTrack = true
        defer { isStartingLocalCameraTrack = false }

        let targetDevice = AVCaptureDevice(uniqueID: selectedCameraID) ?? AVCaptureDevice.default(for: .video)
        let options = CameraCaptureOptions(
            device: targetDevice,
            position: targetDevice?.position ?? .unspecified,
            dimensions: streamQuality.dimensions(aspectRatio: captureAspectRatio),
            fps: 30
        )
        let standaloneTrack = await LocalVideoTrack.createCameraTrack(options: options)
        try? await standaloneTrack.start()
        standaloneTrack.add(videoRenderer: P2PStreamBroadcaster.shared)
        self.localVideoTrack = standaloneTrack
    }

    public func ensureCameraTrackAvailable(forceLocal: Bool = false) async -> VideoTrack? {
        if !forceLocal && currentRole == .viewer, let remoteTrack = remoteVideoTrack {
            return remoteTrack
        }
        if let track = localVideoTrack {
            return track
        }
        if !forceLocal, let track = remoteVideoTrack {
            return track
        }
        await startLocalStandaloneCameraTrack()
        try? await Task.sleep(nanoseconds: 350_000_000)
        return localVideoTrack ?? remoteVideoTrack
    }

    public func ensureLocalCameraTrackAvailable() async -> VideoTrack? {
        if let track = localVideoTrack {
            return track
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        await startLocalStandaloneCameraTrack()
        try? await Task.sleep(nanoseconds: 350_000_000)
        return localVideoTrack
    }

    // Multi-camera selection support (Local Broadcaster)
    @Published public var availableCameras: [AvailableCamera] = []
    @Published public var selectedCameraID: String = ""

    // Remote camera sync support (Remote Viewer)
    @Published public var remoteAvailableCameras: [RemoteCameraInfo] = []
    @Published public var remoteActiveCameraLabel: String = "1x Hoofd"
    @Published public var remoteActiveCameraID: String = ""

    // Snapshot feedback toast & remote photo sync
    @Published public var lastSavedSnapshotToast: String? = nil
    @Published public var isCapturingSnapshot: Bool = false
    @Published public var lastRemoteSnapshot: UIImage? = nil
    @Published public var lastLocalSnapshot: UIImage? = nil
    private var incomingPhotoChunks: [String: (total: Int, chunks: [Int: Data], receivedAt: Date)] = [:]

    public var onRemoteSnapshotRequested: (() -> Void)? = nil

    // Dedicated 24/7 Lab Hub state (Stream Telefoon)
    @Published public var isStreamHubModeActive: Bool = false
    @Published public var isRemoteHubOnline: Bool = false
    @Published public var lastRemoteHubHeartbeat: Date? = nil
    @Published public var lastRemoteHubLogMessage: String = ""
    @Published public var isRemoteHubAutopilotActive: Bool = false
    @Published public var remoteBatteryLevel: Float? = nil
    @Published public var remoteIsCharging: Bool? = nil
    @Published public var localBatteryLevel: Float = -1.0
    @Published public var localIsCharging: Bool = false
    private var hubHeartbeatTimer: AnyCancellable? = nil

    public var remoteBatteryPercent: Int? {
        guard let level = remoteBatteryLevel, level >= 0 else { return nil }
        return Int(round(level * 100))
    }

    public var remoteBatteryIcon: String {
        if remoteIsCharging == true {
            return "battery.100.bolt"
        }
        guard let pct = remoteBatteryPercent else {
            return "battery.100"
        }
        if pct >= 85 { return "battery.100" }
        if pct >= 60 { return "battery.75" }
        if pct >= 35 { return "battery.50" }
        if pct >= 15 { return "battery.25" }
        return "battery.0"
    }

    public var remoteBatteryColor: Color {
        if remoteIsCharging == true {
            return .green
        }
        guard let pct = remoteBatteryPercent else {
            return .white
        }
        if pct <= 15 { return .red }
        if pct <= 30 { return .orange }
        return .green
    }

    public func startHubHeartbeatTimer() {
        hubHeartbeatTimer?.cancel()
        hubHeartbeatTimer = Timer.publish(every: 15.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.broadcastHubHeartbeat()
            }
    }

    public func broadcastHubHeartbeat() {
        guard currentRole == .broadcaster else { return }
        NotificationCenter.default.post(name: NSNotification.Name("MycoLabBroadcastHubHeartbeat"), object: nil)
        guard isConnected else { return }
        let bat = MycoBackgroundHubManager.shared.batteryLevel
        let chg = MycoBackgroundHubManager.shared.isCharging
        broadcastLocalBattery(batteryLevel: bat, isCharging: chg)
        MycoSensorIntelligenceManager.shared.broadcastTelemetryToViewers()
    }

    public func sendHubHeartbeat(autopilotActive: Bool, batteryLevel: Float, isCharging: Bool, logMessage: String) {
        guard isConnected, currentRole == .broadcaster else { return }
        let batStr = String(format: "%.2f", batteryLevel)
        let chgStr = isCharging ? "1" : "0"
        let autoStr = autopilotActive ? "1" : "0"
        let safeLog = logMessage.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: ":", with: "-")
        let cmd = "hub:heartbeat:\(Int(Date().timeIntervalSince1970)):\(autoStr):\(batStr):\(chgStr):\(safeLog)"
        sendDataCommand(command: cmd)
    }

    public func broadcastLocalBattery(batteryLevel: Float, isCharging: Bool) {
        guard isConnected, currentRole == .broadcaster else { return }
        let batStr = String(format: "%.2f", batteryLevel)
        let chgStr = isCharging ? "1" : "0"
        sendDataCommand(command: "hub:battery:\(batStr):\(chgStr)")
    }

    @discardableResult
    public func sendHubPlugSetState(id: UUID, tuyaId: String = "", isOn: Bool, trigger: String = "Kijk-app (Afstandsbediening)", name: String = "") -> Bool {
        let cleanName = name.replacingOccurrences(of: ":", with: " ")
        let cleanTrigger = trigger.replacingOccurrences(of: ":", with: " ")
        let cmd = "plug:set:\(id.uuidString):\(tuyaId):\(isOn ? "1" : "0"):\(cleanTrigger):\(cleanName)"
        var delivered = false
        if isConnected && isRemoteHubOnline {
            sendDataCommand(command: cmd)
            delivered = true
        }
        if MycoCamPairingManager.shared.sendDirectCommandToPeers(cmd) {
            delivered = true
        }
        return delivered
    }

    public func sendHubPlugToggle(id: UUID, trigger: String = "Kijk-app (Afstandsbediening)") {
        let cmd = "plug:toggle:\(id.uuidString):\(trigger)"
        sendDataCommand(command: cmd)
        _ = MycoCamPairingManager.shared.sendDirectCommandToPeers(cmd)
    }

    public func sendHubPlugTest(id: UUID) {
        let cmd = "plug:test:\(id.uuidString)"
        sendDataCommand(command: cmd)
        _ = MycoCamPairingManager.shared.sendDirectCommandToPeers(cmd)
    }

    public func requestHubStatus() {
        sendDataCommand(command: "hub:status:request")
    }

    // MARK: - Dedicated Timelapse Engine (Local Broadcaster & Remote Viewer Control)
    @Published public var isTimelapseRunning: Bool = false
    @Published public var timelapseIntervalMinutes: Int = 2
    @Published public var timelapseCapturedFramesCount: Int = 0
    @Published public var timelapseStartTime: Date? = nil
    @Published public var timelapseAutoFlashIfLampOff: Bool = true
    @Published public var timelapseCameraID: String = ""
    
    // Multi-camera simultaneous timelapse support
    @Published public var activeTimelapseCameraIDs: Set<String> = [] // On Broadcaster (e.g. ["wide", "ultrawide"])
    @Published public var remoteActiveTimelapseCameraIDs: Set<String> = [] // On Viewer
    
    public func isTimelapseRunning(for cameraId: String) -> Bool {
        if currentRole == .viewer {
            guard isRemoteTimelapseRunning else { return false }
            if remoteActiveTimelapseCameraIDs.contains("all") { return true }
            if remoteActiveTimelapseCameraIDs.contains(cameraId) { return true }
            if cameraId == "wide" {
                if remoteActiveTimelapseCameraIDs.contains("wide") ||
                   remoteActiveTimelapseCameraIDs.contains("1.0") ||
                   remoteActiveTimelapseCameraIDs.contains("standard") {
                    return true
                }
            } else if cameraId == "ultrawide" {
                if remoteActiveTimelapseCameraIDs.contains("ultrawide") ||
                   remoteActiveTimelapseCameraIDs.contains("0.5") ||
                   remoteActiveTimelapseCameraIDs.contains("ultra") {
                    return true
                }
            } else if cameraId == "telephoto" {
                if remoteActiveTimelapseCameraIDs.contains("telephoto") ||
                   remoteActiveTimelapseCameraIDs.contains("3.0") ||
                   remoteActiveTimelapseCameraIDs.contains("tele") {
                    return true
                }
            }
            if remoteTimelapseCameraID == cameraId && remoteActiveTimelapseCameraIDs.isEmpty {
                return true
            }
            if cameraId == "all" && !remoteActiveTimelapseCameraIDs.isEmpty {
                return true
            }
            return false
        } else {
            guard isTimelapseRunning else { return false }
            if activeTimelapseCameraIDs.contains("all") { return true }
            if activeTimelapseCameraIDs.contains(cameraId) { return true }
            if cameraId == "wide" {
                if activeTimelapseCameraIDs.contains("wide") ||
                   activeTimelapseCameraIDs.contains("1.0") ||
                   activeTimelapseCameraIDs.contains("standard") {
                    return true
                }
            } else if cameraId == "ultrawide" {
                if activeTimelapseCameraIDs.contains("ultrawide") ||
                   activeTimelapseCameraIDs.contains("0.5") ||
                   activeTimelapseCameraIDs.contains("ultra") {
                    return true
                }
            } else if cameraId == "telephoto" {
                if activeTimelapseCameraIDs.contains("telephoto") ||
                   activeTimelapseCameraIDs.contains("3.0") ||
                   activeTimelapseCameraIDs.contains("tele") {
                    return true
                }
            }
            if timelapseCameraID == cameraId && activeTimelapseCameraIDs.isEmpty {
                return true
            }
            if cameraId == "all" && !activeTimelapseCameraIDs.isEmpty {
                return true
            }
            return false
        }
    }

    // Viewer perspective of broadcaster timelapse state
    @Published public var isRemoteTimelapseRunning: Bool = false
    @Published public var remoteTimelapseIntervalMinutes: Int = 2
    @Published public var remoteTimelapseFramesCount: Int = 0
    @Published public var remoteTimelapseStartTime: Date? = nil
    @Published public var remoteTimelapseAutoFlashIfLampOff: Bool = true
    @Published public var remoteTimelapseCameraID: String = ""
    
    // Stream Quality Preset: 4K Ultra HD (3840x2160), 1080p Full HD, or 720p HD
    @Published public var streamQuality: StreamQualityPreset = {
        let raw = UserDefaults.standard.string(forKey: "mycolab_stream_quality") ?? StreamQualityPreset.ultra4K.rawValue
        return StreamQualityPreset(rawValue: raw) ?? .ultra4K
    }() {
        didSet {
            UserDefaults.standard.set(streamQuality.rawValue, forKey: "mycolab_stream_quality")
            Task { @MainActor in
                await applyQualitySettings()
            }
        }
    }

    public func setStreamQuality(_ quality: StreamQualityPreset) {
        self.streamQuality = quality
    }

    public func applyQualitySettings() async {
        guard currentRole == .broadcaster || isStreamHubModeActive || MycoBackgroundHubManager.shared.isStreamHubRoleActive else { return }
        let targetDevice = AVCaptureDevice(uniqueID: selectedCameraID) ?? AVCaptureDevice.default(for: .video)
        let options = CameraCaptureOptions(
            device: targetDevice,
            position: targetDevice?.position ?? .unspecified,
            dimensions: streamQuality.dimensions(aspectRatio: captureAspectRatio),
            fps: 30
        )
        if let localTrack = localVideoTrack as? LocalVideoTrack,
           let cameraCapturer = localTrack.capturer as? CameraCapturer {
            do {
                try await cameraCapturer.set(options: options)
                print("🎥 [LiveKitStreamManager] Streamkwaliteit live bijgewerkt naar: \(streamQuality.title)")
            } catch {
                print("⚠️ [LiveKitStreamManager] Kon capturer opties niet bijwerken: \(error)")
            }
        } else if let room = room {
            _ = try? await room.localParticipant.setCamera(
                enabled: true,
                captureOptions: options,
                publishOptions: streamQuality.publishOptions
            )
            self.localVideoTrack = room.localParticipant.firstCameraVideoTrack ?? (room.localParticipant.videoTracks.first?.track as? VideoTrack)
        }
    }

    // Camera Aspect Ratio: "4:3" (Full Native Sensor, uncropped) vs "16:9" (Widescreen)
    @Published public var captureAspectRatio: String = "4:3"
    
    private var timelapseTimer: AnyCancellable? = nil
    
    public func setRemoteOrLocalTimelapseAutoFlash(_ enabled: Bool) {
        if currentRole == .viewer {
            self.remoteTimelapseAutoFlashIfLampOff = enabled
            sendDataCommand(command: "timelapse:autoflash:\(enabled ? "1" : "0")")
        } else {
            self.timelapseAutoFlashIfLampOff = enabled
            broadcastTimelapseStatus()
        }
    }
    
    public func startTimelapse(intervalMinutes: Int, cameraId: String? = nil) {
        if currentRole == .viewer {
            let chosenCam = cameraId ?? (self.remoteTimelapseCameraID.isEmpty ? self.remoteActiveCameraID : self.remoteTimelapseCameraID)
            sendRemoteTimelapseCommand(action: "start", intervalMinutes: intervalMinutes, cameraId: chosenCam)
            return
        }
        
        let cam = (cameraId == nil || cameraId?.isEmpty == true) ? (self.timelapseCameraID.isEmpty ? "all" : self.timelapseCameraID) : cameraId!
        self.activeTimelapseCameraIDs.insert(cam)
        self.timelapseCameraID = cam
        UserDefaults.standard.set(cam, forKey: "mycolab_stream_timelapse_camera_id")
        
        self.isTimelapseRunning = true
        self.timelapseIntervalMinutes = max(1, intervalMinutes)
        if self.timelapseStartTime == nil {
            self.timelapseStartTime = Date()
        }
        
        UserDefaults.standard.set(true, forKey: "mycolab_stream_timelapse_running")
        UserDefaults.standard.set(self.timelapseIntervalMinutes, forKey: "mycolab_stream_timelapse_interval")
        if let st = self.timelapseStartTime {
            UserDefaults.standard.set(st.timeIntervalSince1970, forKey: "mycolab_stream_timelapse_start_time")
        }
        
        // Ensure 24/7 background hub execution & keep screen awake so iOS does not throttle timelapse
        self.isStreamHubModeActive = true
        MycoBackgroundHubManager.shared.enableStreamHubMode()
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Switch to the designated timelapse camera if needed (only for specific single camera, never "all")
        if self.timelapseCameraID != "all" && !self.timelapseCameraID.isEmpty && self.selectedCameraID != self.timelapseCameraID {
            Task {
                await self.selectCamera(id: self.timelapseCameraID)
            }
        }
        
        broadcastTimelapseStatus()
        triggerTimelapseCapture(withFlash: shouldUseAutoFlashNow())
        
        timelapseTimer?.cancel()
        timelapseTimer = Timer.publish(every: Double(self.timelapseIntervalMinutes * 60), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.triggerTimelapseCapture(withFlash: self.shouldUseAutoFlashNow())
            }
    }
    
    private func shouldUseAutoFlashNow() -> Bool {
        guard timelapseAutoFlashIfLampOff else { return false }
        if let store = MycoStore.shared {
            let lightDevices = store.db.smartDevices.filter {
                let t = $0.deviceType.lowercased()
                return t.contains("lamp") || t.contains("light") || t.contains("licht")
            }
            if !lightDevices.isEmpty {
                return lightDevices.allSatisfy { !$0.isOn }
            }
        }
        return !isTorchOn
    }
    
    public func stopTimelapse(forCameraId: String? = nil) {
        if currentRole == .viewer {
            sendRemoteTimelapseCommand(action: "stop", intervalMinutes: 0, cameraId: forCameraId ?? "")
            return
        }
        
        let hasMultiple = self.activeTimelapseCameraIDs.count > 1
        if let cam = forCameraId, !cam.isEmpty, cam != "all", hasMultiple && !self.activeTimelapseCameraIDs.contains("all") {
            self.activeTimelapseCameraIDs = self.activeTimelapseCameraIDs.filter { existing in
                if cam == "wide" && (existing.contains("wide") || existing.contains("1.0")) { return false }
                if cam == "ultrawide" && (existing.contains("ultra") || existing.contains("0.5")) { return false }
                if cam == "telephoto" && (existing.contains("tele") || existing.contains("3.0")) { return false }
                return existing != cam
            }
            if self.activeTimelapseCameraIDs.isEmpty {
                self.isTimelapseRunning = false
                self.timelapseStartTime = nil
                UserDefaults.standard.set(false, forKey: "mycolab_stream_timelapse_running")
                self.timelapseTimer?.cancel()
                self.timelapseTimer = nil
            }
        } else {
            self.activeTimelapseCameraIDs.removeAll()
            self.isTimelapseRunning = false
            self.timelapseStartTime = nil
            UserDefaults.standard.set(false, forKey: "mycolab_stream_timelapse_running")
            self.timelapseTimer?.cancel()
            self.timelapseTimer = nil
        }
        broadcastTimelapseStatus()
    }
    
    public func broadcastTimelapseStatus() {
        guard currentRole == .broadcaster || isStreamHubModeActive || MycoBackgroundHubManager.shared.isStreamHubRoleActive else { return }
        let runningStr = isTimelapseRunning ? "1" : "0"
        let interval = timelapseIntervalMinutes
        let count = timelapseCapturedFramesCount
        let autoFlashStr = timelapseAutoFlashIfLampOff ? "1" : "0"
        let camIdsStr = isTimelapseRunning
            ? (activeTimelapseCameraIDs.isEmpty ? (timelapseCameraID.isEmpty ? "all" : timelapseCameraID) : activeTimelapseCameraIDs.joined(separator: ","))
            : ""
        sendDataCommand(command: "timelapse:status:\(runningStr):\(interval):\(count):\(autoFlashStr):\(camIdsStr)")
    }
    
    public func sendRemoteTimelapseCommand(action: String, intervalMinutes: Int = 2, cameraId: String = "") {
        if action == "start" {
            let chosenCam = cameraId.isEmpty ? (self.remoteTimelapseCameraID.isEmpty ? "all" : self.remoteTimelapseCameraID) : cameraId
            sendDataCommand(command: "timelapse:start:\(intervalMinutes):\(chosenCam)")
            self.remoteActiveTimelapseCameraIDs.insert(chosenCam)
            self.isRemoteTimelapseRunning = true
            self.remoteTimelapseIntervalMinutes = intervalMinutes
            self.remoteTimelapseCameraID = chosenCam
            UserDefaults.standard.set(chosenCam, forKey: "mycolab_viewer_remote_timelapse_camera_id")
            if self.remoteTimelapseStartTime == nil {
                self.remoteTimelapseStartTime = Date()
            }
            UserDefaults.standard.set(true, forKey: "mycolab_viewer_remote_timelapse_active")
            UserDefaults.standard.set(intervalMinutes, forKey: "mycolab_viewer_remote_timelapse_interval")
        } else {
            let chosenCam = cameraId
            let hasMultiple = self.remoteActiveTimelapseCameraIDs.count > 1
            if !chosenCam.isEmpty && chosenCam != "all" && hasMultiple && !self.remoteActiveTimelapseCameraIDs.contains("all") {
                sendDataCommand(command: "timelapse:stop:\(chosenCam)")
                self.remoteActiveTimelapseCameraIDs = self.remoteActiveTimelapseCameraIDs.filter { existing in
                    if chosenCam == "wide" && (existing.contains("wide") || existing.contains("1.0")) { return false }
                    if chosenCam == "ultrawide" && (existing.contains("ultra") || existing.contains("0.5")) { return false }
                    if chosenCam == "telephoto" && (existing.contains("tele") || existing.contains("3.0")) { return false }
                    return existing != chosenCam
                }
                self.isRemoteTimelapseRunning = !self.remoteActiveTimelapseCameraIDs.isEmpty
                if self.remoteActiveTimelapseCameraIDs.isEmpty {
                    self.remoteTimelapseStartTime = nil
                    UserDefaults.standard.set(false, forKey: "mycolab_viewer_remote_timelapse_active")
                }
            } else {
                sendDataCommand(command: "timelapse:stop:all")
                self.remoteActiveTimelapseCameraIDs.removeAll()
                self.isRemoteTimelapseRunning = false
                self.remoteTimelapseStartTime = nil
                UserDefaults.standard.set(false, forKey: "mycolab_viewer_remote_timelapse_active")
            }
        }
    }
    
    public func requestTimelapseStatus() {
        sendDataCommand(command: "timelapse:status:request")
    }
    
    public func triggerTimelapseCapture(withFlash: Bool = false) {
        guard currentRole == .broadcaster || isStreamHubModeActive || MycoBackgroundHubManager.shared.isStreamHubRoleActive else { return }
        self.timelapseCapturedFramesCount += 1
        let currentCount = self.timelapseCapturedFramesCount
        
        NotificationCenter.default.post(name: NSNotification.Name("MycoCamTimelapseFlashShutter"), object: nil)
        
        MycoBackgroundHubManager.shared.updateBatteryStatus()
        if let store = MycoStore.shared {
            store.db.environmentConfig.cameraBatteryLevel = MycoBackgroundHubManager.shared.batteryLevel
            store.db.environmentConfig.cameraIsCharging = MycoBackgroundHubManager.shared.isCharging
            store.db.environmentConfig.cameraBatteryLastUpdated = Date()
            store.save()
        }
        self.broadcastLocalBattery(
            batteryLevel: MycoBackgroundHubManager.shared.batteryLevel,
            isCharging: MycoBackgroundHubManager.shared.isCharging
        )
        
        let minutesElapsed = self.timelapseStartTime.map { Int(Date().timeIntervalSince($0) / 60.0) } ?? 0
        
        Task {
            _ = await self.ensureCameraTrackAvailable(forceLocal: true)

            let isMultiCam = self.activeTimelapseCameraIDs.contains("all") || self.timelapseCameraID == "all" || self.activeTimelapseCameraIDs.count > 1
            let backCameras = self.availableCameras.filter { $0.position == .back }
            
            let camerasToCapture: [AvailableCamera]
            if isMultiCam {
                if self.activeTimelapseCameraIDs.contains("all") || self.timelapseCameraID == "all" || self.activeTimelapseCameraIDs.isEmpty {
                    camerasToCapture = backCameras
                } else {
                    let matching = backCameras.filter { cam in
                        self.activeTimelapseCameraIDs.contains(cam.id) ||
                        (self.activeTimelapseCameraIDs.contains("wide") && cam.deviceType == .builtInWideAngleCamera) ||
                        (self.activeTimelapseCameraIDs.contains("ultrawide") && cam.deviceType == .builtInUltraWideCamera) ||
                        (self.activeTimelapseCameraIDs.contains("telephoto") && cam.deviceType == .builtInTelephotoCamera)
                    }
                    camerasToCapture = matching.isEmpty ? backCameras : matching
                }
            } else if let singleId = self.activeTimelapseCameraIDs.first ?? (!self.timelapseCameraID.isEmpty ? self.timelapseCameraID : nil) {
                let matching = backCameras.filter { cam in
                    cam.id == singleId ||
                    (singleId == "wide" && cam.deviceType == .builtInWideAngleCamera) ||
                    (singleId == "ultrawide" && cam.deviceType == .builtInUltraWideCamera) ||
                    (singleId == "telephoto" && cam.deviceType == .builtInTelephotoCamera)
                }
                camerasToCapture = matching.isEmpty ? backCameras : matching
            } else {
                camerasToCapture = backCameras
            }

            if camerasToCapture.count > 1 {
                let originalCameraID = (self.selectedCameraID != "all" && !self.selectedCameraID.isEmpty)
                    ? self.selectedCameraID
                    : (self.availableCameras.first(where: { $0.position == .back })?.id ?? "")

                // Sorteer: 1.0x Wide (Kweek), 0.5x Ultra-Wide (Tent), Telelens (Zoom AI Sensor)
                let sortedCams = camerasToCapture.sorted { a, b in
                    let rankA: Int = {
                        switch a.deviceType {
                        case .builtInWideAngleCamera: return 0
                        case .builtInUltraWideCamera: return 1
                        case .builtInTelephotoCamera: return 2
                        default: return 3
                        }
                    }()
                    let rankB: Int = {
                        switch b.deviceType {
                        case .builtInWideAngleCamera: return 0
                        case .builtInUltraWideCamera: return 1
                        case .builtInTelephotoCamera: return 2
                        default: return 3
                        }
                    }()
                    return rankA < rankB
                }

                for cam in sortedCams {
                    await self.selectCamera(id: cam.id)
                    try? await Task.sleep(nanoseconds: 400_000_000)

                    let (camType, camLabel): (String, String) = {
                        switch cam.deviceType {
                        case .builtInUltraWideCamera:
                            return ("ultraWide", "Tent (0.5x)")
                        case .builtInTelephotoCamera:
                            return ("telephoto", "Sensor AI (Zoom)")
                        default:
                            return ("wide", "Kweek (1.0x)")
                        }
                    }()

                    let frameCaption = "\(camLabel) • Frame #\(currentCount)"
                    let success = await self.captureAndSaveSnapshot(
                        withFlash: withFlash,
                        customCaption: frameCaption,
                        relativeMinutes: minutesElapsed,
                        cameraType: camType,
                        cameraName: camLabel
                    )

                    // Als de telelens opname is gemaakt, stuur direct door naar de optische hygrometer voor AI analyse & training
                    if success && camType == "telephoto", let lastImg = self.lastLocalSnapshot {
                        MycoOpticalHygrometerManager.shared.handleReceivedRemotePhoto(lastImg)
                    }
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }

                // Schakel direct terug naar de oorspronkelijke camera voor de live stream
                if !originalCameraID.isEmpty && originalCameraID != "all" && self.selectedCameraID != originalCameraID {
                    await self.selectCamera(id: originalCameraID)
                }
            } else if let singleCam = camerasToCapture.first {
                if singleCam.id != "all" && self.selectedCameraID != singleCam.id {
                    await self.selectCamera(id: singleCam.id)
                    try? await Task.sleep(nanoseconds: 350_000_000)
                }

                let (camType, camLabel): (String, String) = {
                    switch singleCam.deviceType {
                    case .builtInUltraWideCamera: return ("ultraWide", "Tent (0.5x)")
                    case .builtInTelephotoCamera: return ("telephoto", "Sensor AI (Zoom)")
                    default: return ("wide", "Kweek (1.0x)")
                    }
                }()
                let frameCaption = "\(camLabel) • Frame #\(currentCount)"
                _ = await self.captureAndSaveSnapshot(
                    withFlash: withFlash,
                    customCaption: frameCaption,
                    relativeMinutes: minutesElapsed,
                    cameraType: camType,
                    cameraName: camLabel
                )
            }

            self.broadcastTimelapseStatus()
            MycoSensorIntelligenceManager.shared.broadcastTelemetryToViewers()
        }
    }

    public private(set) var room: Room?
    @Published public var currentRole: LiveKitRole = .viewer
    private var trackPollingTask: Task<Void, Never>? = nil

    public override init() {
        super.init()
        loadAvailableCameras()
        loadMonthlyTokenUsage()
        startEcoTokenMonitorTimer()
        startNetworkPathMonitoring()
        startScreenAwakeWatchdog()
        
        self.timelapseCameraID = UserDefaults.standard.string(forKey: "mycolab_stream_timelapse_camera_id") ?? ""
        self.remoteTimelapseCameraID = UserDefaults.standard.string(forKey: "mycolab_viewer_remote_timelapse_camera_id") ?? ""
        
        let savedInterval = UserDefaults.standard.integer(forKey: "mycolab_stream_timelapse_interval")
        self.timelapseIntervalMinutes = savedInterval > 0 ? savedInterval : 2

        let savedRemoteInterval = UserDefaults.standard.integer(forKey: "mycolab_viewer_remote_timelapse_interval")
        self.remoteTimelapseIntervalMinutes = savedRemoteInterval > 0 ? savedRemoteInterval : 2

        // Ensure fresh start without phantom active timelapses on app launch
        self.isTimelapseRunning = false
        self.isRemoteTimelapseRunning = false
        self.activeTimelapseCameraIDs.removeAll()
        self.remoteActiveTimelapseCameraIDs.removeAll()
        UserDefaults.standard.set(false, forKey: "mycolab_viewer_remote_timelapse_active")
        UserDefaults.standard.set(false, forKey: "mycolab_stream_timelapse_running")
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoLabBroadcastBatteryUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let level = note.userInfo?["batteryLevel"] as? Float ?? -1.0
                let isChg = note.userInfo?["isCharging"] as? Bool ?? false
                self.localBatteryLevel = level
                self.localIsCharging = isChg
                if self.currentRole == .broadcaster && self.isConnected {
                    self.broadcastLocalBattery(batteryLevel: level, isCharging: isChg)
                }
            }
        }

        // Listen for direct local Wi-Fi P2P commands (Eco-Standby wake & deterministic Tuya plug relay)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoLabP2PDirectCommand"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self = self,
                      let cmd = note.userInfo?["cmd"] as? String else { return }
                self.handleDirectControlTextCommand(cmd)
            }
        }

        // Listen for iCloud Key-Value Store wake signal and smart plug updates when viewer is on 4G/5G
        if MycoKVS.isAvailable {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                
                // Immediately check for smart device updates from iCloud KVS
                if let rawSmart = MycoKVS.data(forKey: "MycoLabSmartDevicesPayload"),
                   let decoded = try? JSONDecoder().decode([SmartDeviceItem].self, from: rawSmart) {
                    let deletedIDs: [UUID] = {
                        guard let dData = MycoKVS.data(forKey: "MycoLabDeletedItemIDsPayload"),
                              let ids = try? JSONDecoder().decode([UUID].self, from: dData) else { return [] }
                        return ids
                    }()
                    let deletedTuyaIDs: [String] = {
                        guard let dtData = MycoKVS.data(forKey: "MycoLabDeletedTuyaIDsPayload"),
                              let ids = try? JSONDecoder().decode([String].self, from: dtData) else { return [] }
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
                        incomingDeletedTuyaIDs: deletedTuyaIDs,
                        tuyaApiKey: apiKey,
                        tuyaApiSecret: apiSec,
                        tuyaRegion: apiReg,
                        tuyaDeviceID: devId,
                        tuyaVerified: ver
                    )
                }
                
                guard self.currentRole == .broadcaster else { return }
                
                let sleepTs = MycoKVS.double(forKey: "MycoLabLiveKitSleepTimestamp")
                if sleepTs > self.lastHandledSleepTimestamp && (Date().timeIntervalSince1970 - sleepTs) < 120.0 {
                    self.lastHandledSleepTimestamp = sleepTs
                    if !self.isInEcoStandby {
                        Task { await self.enterEcoStandby() }
                    }
                    return
                }

                let wakeTs = MycoKVS.double(forKey: "MycoLabLiveKitWakeTimestamp")
                if wakeTs > self.lastHandledWakeTimestamp && (Date().timeIntervalSince1970 - wakeTs) < 300.0 {
                    self.lastHandledWakeTimestamp = wakeTs
                    if self.isInEcoStandby || self.room == nil || !self.isConnected {
                        Task { await self.wakeFromEcoStandby() }
                    }
                }
            }
        }
    }
        }

    public func handleDirectControlTextCommand(_ text: String) {
        if let data = text.data(using: .utf8) {
            MycoSyncManager.shared.handleIncomingP2PPacket(data, from: "4G/5G LiveKit")
        }

        if text.hasPrefix("livekit:wake") {
            if currentRole == .broadcaster && (isInEcoStandby || room == nil || !isConnected) {
                Task { await self.wakeFromEcoStandby() }
            }
        } else if text.hasPrefix("livekit:sleep") {
            if currentRole == .broadcaster && !isInEcoStandby {
                Task { await self.enterEcoStandby() }
            }
        } else if text.hasPrefix("plug:set:") {
            let remainder = String(text.dropFirst("plug:set:".count))
            let parts = remainder.split(separator: ":", omittingEmptySubsequences: false)
            if parts.count >= 3, let store = MycoStore.shared {
                let idStr = String(parts[0])
                let tuyaId = String(parts[1])
                let targetIsOn = (parts[2] == "1")
                let trigger = parts.count > 3 && !parts[3].isEmpty ? String(parts[3]) : "Kijk-app (Hub Aansturing)"
                let devUUID = UUID(uuidString: idStr)
                if let idx = store.db.smartDevices.firstIndex(where: { ($0.id == devUUID && devUUID != nil) || (!tuyaId.isEmpty && $0.tuyaDeviceID == tuyaId) }) {
                    let matchedId = store.db.smartDevices[idx].id
                    DispatchQueue.main.async {
                        store.setSmartDeviceState(id: matchedId, isOn: targetIsOn, trigger: trigger, relayToHub: false)
                    }
                }
            }
        } else if text.hasPrefix("plug:toggle:") {
            let remainder = String(text.dropFirst("plug:toggle:".count))
            let parts = remainder.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if let devIdStr = parts.first, let devId = UUID(uuidString: String(devIdStr)) {
                let trigger = parts.count > 1 && !parts[1].isEmpty ? String(parts[1]) : "Kijk-app (Hub Aansturing)"
                NotificationCenter.default.post(
                    name: NSNotification.Name("MycoLabRemotePlugToggle"),
                    object: nil,
                    userInfo: ["id": devId, "trigger": trigger]
                )
            }
        } else if text.hasPrefix("plug:test:") {
            let devIdStr = String(text.dropFirst("plug:test:".count))
            if let devId = UUID(uuidString: devIdStr) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("MycoLabRemotePlugTest"),
                    object: nil,
                    userInfo: ["id": devId]
                )
            }
        }
    }

    // MARK: - Camera Discovery & Switching
    public func loadAvailableCameras() {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera
        ]
        if #available(iOS 17.0, macCatalyst 17.0, *) {
            deviceTypes.append(.continuityCamera)
            deviceTypes.append(.external)
        }
        #if targetEnvironment(macCatalyst)
        let searchPos: AVCaptureDevice.Position = .unspecified
        #else
        let searchPos: AVCaptureDevice.Position = .back
        #endif
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: searchPos
        )

        var devices = discovery.devices
        #if !targetEnvironment(macCatalyst)
        devices.removeAll { $0.position == .front }
        #endif
        if devices.isEmpty, let defaultCam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            devices = [defaultCam]
        } else if devices.isEmpty, let defaultCam = AVCaptureDevice.default(for: .video) {
            devices = [defaultCam]
        }
        self.availableCameras = devices.map { device in
            AvailableCamera(
                id: device.uniqueID,
                name: Self.friendlyCameraName(for: device),
                shortLabel: Self.shortCameraLabel(for: device),
                position: device.position,
                deviceType: device.deviceType
            )
        }

        // Default to back wide-angle lens if nothing selected yet, or first available on Mac/iPad
        if selectedCameraID.isEmpty || !availableCameras.contains(where: { $0.id == selectedCameraID }) {
            if let backWide = availableCameras.first(where: { $0.position == .back && $0.deviceType == .builtInWideAngleCamera }) {
                selectedCameraID = backWide.id
            } else if let firstBack = availableCameras.first(where: { $0.position == .back }) {
                selectedCameraID = firstBack.id
            } else if let first = availableCameras.first {
                selectedCameraID = first.id
            }
        }
    }

    public static func friendlyCameraName(for device: AVCaptureDevice) -> String {
        if device.position == .unspecified {
            return device.localizedName
        }
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return "Ultra-Groothoek 0.5x"
        case .builtInTelephotoCamera:
            return "Telelens / Zoom"
        case .builtInWideAngleCamera:
            #if targetEnvironment(macCatalyst)
            return device.localizedName
            #else
            return "Hoofdcamera 1x"
            #endif
        default:
            return device.localizedName
        }
    }

    public static func shortCameraLabel(for device: AVCaptureDevice) -> String {
        if device.position == .unspecified {
            return "Mac / USB Cam"
        }
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return "0.5x Ultra"
        case .builtInTelephotoCamera:
            return "Tele Zoom"
        case .builtInWideAngleCamera:
            #if targetEnvironment(macCatalyst)
            return "Mac Cam"
            #else
            return "1x Hoofd"
            #endif
        default:
            return device.localizedName
        }
    }

    public var currentCameraShortLabel: String {
        availableCameras.first(where: { $0.id == selectedCameraID })?.shortLabel ?? "Camera"
    }

    public func selectCamera(id: String) async {
        guard id != "all" && !id.isEmpty else { return }

        // Resolve target AVCaptureDevice from id (uniqueID or symbolic type like wide/ultrawide/telephoto)
        let resolvedDevice: AVCaptureDevice? = {
            if let dev = AVCaptureDevice(uniqueID: id) {
                return dev
            }
            if let found = availableCameras.first(where: { $0.id == id }) {
                if let dev = AVCaptureDevice(uniqueID: found.id) { return dev }
            }
            let lower = id.lowercased()
            if lower.contains("ultra") || lower == "0.5x" || lower == "tent" {
                return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            } else if lower.contains("tele") || lower == "3.0x" || lower == "sensor" || lower == "zoom" {
                return AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
            } else if lower.contains("front") || lower == "selfie" {
                return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            } else {
                return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            }
        }()

        guard let targetDevice = resolvedDevice else {
            print("[LiveKitStreamManager] Could not resolve capture device for id: \(id)")
            return
        }

        let validDeviceId = targetDevice.uniqueID
        guard self.selectedCameraID != validDeviceId else { return }
        self.selectedCameraID = validDeviceId

        // If broadcaster is actively running, update camera capturer live
        if currentRole == .broadcaster {
            let previousTorchWasOn = self.isTorchOn
            let previousBrightness = self.torchBrightness

            if let localTrack = localVideoTrack as? LocalVideoTrack,
               let cameraCapturer = localTrack.capturer as? CameraCapturer {
                let options = CameraCaptureOptions(
                    device: targetDevice,
                    position: targetDevice.position,
                    dimensions: streamQuality.dimensions(aspectRatio: captureAspectRatio),
                    fps: 30
                )
                do {
                    try await cameraCapturer.set(options: options)
                    print("[LiveKitStreamManager] Switched active camera to: \(targetDevice.localizedName)")
                } catch {
                    print("[LiveKitStreamManager] Failed to switch camera options: \(error)")
                }
            } else if let room = room {
                let options = CameraCaptureOptions(
                    device: targetDevice,
                    position: targetDevice.position,
                    dimensions: streamQuality.dimensions(aspectRatio: captureAspectRatio),
                    fps: 30
                )
                _ = try? await room.localParticipant.setCamera(enabled: true, captureOptions: options, publishOptions: streamQuality.publishOptions)
                self.localVideoTrack = room.localParticipant.firstCameraVideoTrack ?? (room.localParticipant.videoTracks.first?.track as? VideoTrack)
            }

            // iOS AVFoundation inherently disables torch whenever an AVCaptureDevice switches or stops.
            // Seamlessly restore the hardware torch on the new lens if it was on!
            if previousTorchWasOn {
                if targetDevice.position != .front {
                    // Small delay to allow AVFoundation to stabilize the newly active video pipeline
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    self.setLocalTorch(on: true, level: previousBrightness)
                } else {
                    // Front camera physically lacks a rear torch: accurately update state & broadcast to viewers
                    self.isTorchOn = false
                    self.broadcastTorchStatus()
                }
            }

            broadcastCameraList()
        }
    }

    public func switchToNextCamera() async {
        guard availableCameras.count > 1 else { return }
        if let currentIndex = availableCameras.firstIndex(where: { $0.id == selectedCameraID }) {
            let nextIndex = (currentIndex + 1) % availableCameras.count
            await selectCamera(id: availableCameras[nextIndex].id)
        } else if let first = availableCameras.first {
            await selectCamera(id: first.id)
        }
    }

    // MARK: - Remote Camera Control & Sync
    public func switchRemoteCamera() {
        sendDataCommand(command: "camera:next")
    }

    public func selectRemoteCamera(id: String) {
        sendDataCommand(command: "camera:id:\(id)")
        self.remoteActiveCameraID = id
        if let cam = remoteAvailableCameras.first(where: { $0.id == id }) {
            self.remoteActiveCameraLabel = cam.shortLabel
        }
    }

    public func selectRemoteCameraByType(_ type: String) {
        sendDataCommand(command: "camera:type:\(type)")
        switch type.lowercased() {
        case "ultrawide", "tent", "0.5x":
            self.remoteActiveCameraLabel = "Tent (0.5x)"
        case "telephoto", "zoom", "sensor", "3.0x", "ai":
            self.remoteActiveCameraLabel = "Sensor (3.0x)"
        default:
            self.remoteActiveCameraLabel = "Kweek (1.0x)"
        }
    }

    public func selectCameraByType(_ type: String) async {
        guard currentRole == .broadcaster else { return }
        let targetType: AVCaptureDevice.DeviceType = {
            switch type.lowercased() {
            case "ultrawide", "tent", "0.5x":
                return .builtInUltraWideCamera
            case "telephoto", "zoom", "sensor", "3.0x", "ai":
                return .builtInTelephotoCamera
            default:
                return .builtInWideAngleCamera
            }
        }()
        
        if let dev = AVCaptureDevice.default(targetType, for: .video, position: .back),
           availableCameras.contains(where: { $0.id == dev.uniqueID }) {
            await selectCamera(id: dev.uniqueID)
            return
        }
        
        // Fallback: search by label
        if let found = availableCameras.first(where: {
            $0.shortLabel.localizedCaseInsensitiveContains(type) || $0.name.localizedCaseInsensitiveContains(type)
        }) {
            await selectCamera(id: found.id)
        }
    }

    public func requestRemoteCameras() {
        sendDataCommand(command: "get:cams")
    }

    public func broadcastCameraList() {
        guard currentRole == .broadcaster else { return }
        let cams = availableCameras.map { [
            "id": $0.id,
            "name": $0.name,
            "short": $0.shortLabel
        ] }
        let payload: [String: Any] = [
            "cmd": "cams_sync",
            "activeId": selectedCameraID,
            "activeLabel": currentCameraShortLabel,
            "cams": cams
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: data, encoding: .utf8) {
            sendDataCommand(command: jsonString)
        }
        sendDataCommand(command: "screen:sleep:status:\(isOledSaverActive ? "1" : "0")")
        broadcastTorchStatus()
    }

    public func broadcastTorchStatus() {
        guard currentRole == .broadcaster else { return }
        sendDataCommand(command: isTorchOn ? "torch:status:1:\(torchBrightness)" : "torch:status:0")
    }

    // MARK: - Snapshot & Gallery Saving
    public func captureCurrentFrame(from track: VideoTrack) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let grabber = VideoTrackFrameGrabber(track: track, continuation: continuation)
            track.add(videoRenderer: grabber)

            // Safety timeout after 2.5 seconds
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                grabber.handleTimeout()
            }
        }
    }

    public static func saveToPhotoLibrary(_ image: UIImage) async -> Bool {
        return await MycoPhotoLibraryHelper.saveImageToAlbum(image)
    }

    public func captureAndSaveSnapshot(
        withFlash: Bool = false,
        customCaption: String? = nil,
        relativeMinutes: Int? = nil,
        cameraType: String? = nil,
        cameraName: String? = nil,
        saveToLibrary: Bool = false
    ) async -> Bool {
        guard !isCapturingSnapshot else { return false }
        isCapturingSnapshot = true
        defer { isCapturingSnapshot = false }

        var targetTrack = remoteVideoTrack ?? localVideoTrack
        if targetTrack == nil && (currentRole == .broadcaster || isStreamHubModeActive || MycoBackgroundHubManager.shared.isStreamHubRoleActive) {
            targetTrack = await ensureCameraTrackAvailable(forceLocal: true)
        }
        guard let track = targetTrack else {
            print("[LiveKitStreamManager] No active video track for snapshot")
            return false
        }

        // Also notify the remote camera to trigger a snapshot in its timelapse log
        if currentRole == .viewer {
            requestSnapshot(withFlash: withFlash)
        }

        let image: UIImage?
        if withFlash, currentRole == .broadcaster {
            image = await captureFrameWithFlash(from: track)
        } else {
            image = await captureCurrentFrame(from: track)
        }

        guard let image = image else {
            print("[LiveKitStreamManager] Failed to capture frame from track")
            return false
        }

        // Storage safety: Pause capture if device flash memory is critical (< 1 GB free)
        if MycoStorageSafetyManager.shared.isCriticalStorage {
            self.lastSavedSnapshotToast = "⚠️ Opslag bijna vol (<1 GB vrij). Timelapse gepauzeerd!"
            return false
        }

        // Transmit captured snapshot photo to remote viewer immediately (no waiting for photo library)
        let isBroadcasterDevice = currentRole == .broadcaster
            || isStreamHubModeActive
            || MycoBackgroundHubManager.shared.isStreamHubRoleActive
            || localVideoTrack != nil

        // Alleen handmatige snapshots direct doorgeven, NOOIT periodieke timelapse frames (geen mesh belasting)
        if isBroadcasterDevice && (customCaption == nil || customCaption?.contains("Overzicht") == true || customCaption?.contains("Optische") == true) {
            transmitPhotoToViewers(image)
        }

        // Tussentijdse timelapse foto's worden NIET opgeslagen in de iPhone Foto's galerij (geen vervuiling tussen privéfoto's).
        // Alleen de voltooide timelapse video (.mp4) wordt automatisch opgeslagen in het speciale album 'MycoLab'.
        if saveToLibrary {
            Task {
                _ = await Self.saveToPhotoLibrary(image)
            }
        }

        self.lastLocalSnapshot = image

        // Optical Meter Reading Integration
        var photoTempC: Double? = nil
        var photoHumPct: Double? = nil
        var photoVpdKpa: Double? = nil

        if let opticalReading = MycoOpticalHygrometerManager.shared.lastReading {
            photoHumPct = opticalReading.humidityPct
            photoTempC = opticalReading.temperatureC
            if let temp = opticalReading.temperatureC {
                photoVpdKpa = MycoVPDCalculator.analyze(tempC: temp, humidityPct: opticalReading.humidityPct)?.vpdKPa
            }
        }

        if let store = MycoStore.shared {
            let finalCaption = customCaption ?? "\(currentRole == .viewer ? "Live Kijker Snapshot" : "Kweekcamera Snapshot") • \(withFlash ? "Flits" : "Regulier")"
            let item = TimelapsePhotoItem.createAndSave(
                image: image,
                caption: finalCaption,
                relativeMinutes: relativeMinutes ?? 0,
                cameraType: cameraType,
                cameraName: cameraName,
                temperatureC: photoTempC,
                humidityPct: photoHumPct,
                vpdKpa: photoVpdKpa
            )
            store.db.timelapsePhotos.insert(item, at: 0)
            while store.db.timelapsePhotos.count > 300 {
                let old = store.db.timelapsePhotos.removeLast()
                old.deleteFile()
            }
            store.save()
        }

        if saveToLibrary {
            self.lastSavedSnapshotToast = "📸 Foto bewaard in album 'MycoLabs'!"
        } else {
            self.lastSavedSnapshotToast = withFlash ? "📸 Flitsopname vastgelegd!" : "📸 Kweekopname vastgelegd!"
        }

        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if self.lastSavedSnapshotToast != nil {
                withAnimation {
                    self.lastSavedSnapshotToast = nil
                }
            }
        }
        return true
    }

    // MARK: - Photo Transmission & Chunking (WebRTC SCTP Safe)
    public static func prepareForDirectTransmission(image: UIImage, maxBytes: Int = 55_000) -> Data? {
        // Alleen in 1 enkel packet als het op 100% volledige kwaliteit past (<= 55KB).
        // Zo niet, dan verzenden we ALTIJD op 100% kwaliteit via chunked streaming.
        if let raw100 = image.jpegData(compressionQuality: 1.0), raw100.count <= maxBytes {
            return raw100
        }
        return nil
    }

    public func transmitPhotoToViewers(_ image: UIImage) {
        Task {
            // User policy: Geen losse foto's sturen over P2P mesh.
            guard let room = self.room else { return }

            // 1. Probeer eerst een geoptimaliseerde versie die direct in 1 WebRTC packet past (<= 55KB)
            if let compactData = Self.prepareForDirectTransmission(image: image, maxBytes: 55_000) {
                do {
                    try await room.localParticipant.publish(
                        data: compactData,
                        options: DataPublishOptions(topic: "optical_photo", reliable: true)
                    )
                    print("[LiveKitStreamManager] Snapshot transmitted to viewer in 1 packet (\(compactData.count) bytes)")
                    return
                } catch {
                    print("[LiveKitStreamManager] Single packet publish failed: \(error). Falling back to chunked transmission.")
                }
            }

            // 2. Chunks verzenden voor 100% native resolutie & 100% beeldkwaliteit (binary-safe met \n delimiter)
            if let fullData = image.jpegData(compressionQuality: 1.0) ?? MycoImageHelper.prepareForStorage(image: image, maxDimension: 4096, compressionQuality: 1.0) {
                let chunkSize = 28_000
                let totalChunks = Int(ceil(Double(fullData.count) / Double(chunkSize)))
                let transferId = String(UUID().uuidString.prefix(8))
                for idx in 0..<totalChunks {
                    let start = idx * chunkSize
                    let end = min(start + chunkSize, fullData.count)
                    let slice = fullData.subdata(in: start..<end)
                    var packet = Data("chunk:\(transferId):\(idx):\(totalChunks)\n".utf8)
                    packet.append(slice)
                    _ = try? await room.localParticipant.publish(
                        data: packet,
                        options: DataPublishOptions(topic: "optical_photo_chunk", reliable: true)
                    )
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }
                print("[LiveKitStreamManager] Snapshot transmitted via chunks (\(totalChunks) chunks, \(fullData.count) bytes)")
            }
        }
    }

    public func handleIncomingPhotoChunk(_ data: Data) {
        guard let newlineIdx = data.firstIndex(of: 0x0A) else { return }
        let headerData = data.subdata(in: 0..<newlineIdx)
        guard let headerString = String(data: headerData, encoding: .utf8) else { return }
        let comps = headerString.components(separatedBy: ":")
        guard comps.count >= 4, comps[0] == "chunk" else { return }
        let transferId = comps[1]
        guard let idx = Int(comps[2]), let total = Int(comps[3]) else { return }

        let slice = data.subdata(in: (newlineIdx + 1)..<data.count)

        let now = Date()
        incomingPhotoChunks = incomingPhotoChunks.filter { now.timeIntervalSince($0.value.receivedAt) < 30 }

        if incomingPhotoChunks[transferId] == nil {
            incomingPhotoChunks[transferId] = (total: total, chunks: [:], receivedAt: now)
        }
        incomingPhotoChunks[transferId]?.chunks[idx] = slice

        if let entry = incomingPhotoChunks[transferId], entry.chunks.count == entry.total {
            var fullData = Data()
            for i in 0..<entry.total {
                if let part = entry.chunks[i] {
                    fullData.append(part)
                }
            }
            incomingPhotoChunks.removeValue(forKey: transferId)
            if let image = UIImage(data: fullData) {
                print("[LiveKitStreamManager] Successfully reassembled chunked remote snapshot (\(fullData.count) bytes)")
                self.lastRemoteSnapshot = image
                self.lastSavedSnapshotToast = "📸 Foto ontvangen van kweekcamera!"
                MycoOpticalHygrometerManager.shared.handleReceivedRemotePhoto(image)
                if let store = MycoStore.shared {
                    let item = TimelapsePhotoItem.createAndSave(
                        image: image,
                        caption: "Kweekcamera Live Snapshot",
                        relativeMinutes: 0
                    )
                    store.db.timelapsePhotos.insert(item, at: 0)
                    while store.db.timelapsePhotos.count > 60 {
                        let old = store.db.timelapsePhotos.removeLast()
                        old.deleteFile()
                    }
                    store.save()
                }
            }
        }
    }

    // MARK: - Auto-Connect & Room Resolution
    public func resolveTargetCameraRoom(overrideId: String? = nil) -> String {
        let pairingManager = MycoCamPairingManager.shared
        // 0. Explicit override ID (if not our own local camera ID)
        if let ov = overrideId?.trimmingCharacters(in: .whitespacesAndNewlines), !ov.isEmpty {
            if ov != pairingManager.localCameraId {
                return "mycolab-cam-\(ov)"
            }
        }
        // 1. If currently connected and have active remote video track, preserve the current room
        if isConnected && !currentRoomName.isEmpty && remoteVideoTrack != nil {
            return currentRoomName
        }
        // 2. Paired camera ID (set via QR scan, Wi-Fi pairing, or manual pairing)
        if let pairedId = pairingManager.pairedCameraId?.trimmingCharacters(in: .whitespacesAndNewlines), !pairedId.isEmpty {
            return "mycolab-cam-\(pairedId)"
        }
        // 3. Shared iCloud registered camera ID from broadcaster iPhone
        let registeredCloudCamId = MycoKVS.string(forKey: "mycolab_registered_camera_id")?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cloudCam = registeredCloudCamId, !cloudCam.isEmpty, cloudCam != pairingManager.localCameraId {
            return "mycolab-cam-\(cloudCam)"
        }
        // 4. Any discovered camera nearby via Wi-Fi / Multipeer
        if let peerCam = pairingManager.discoveredCameras.first?.cameraId, !peerCam.isEmpty, peerCam != pairingManager.localCameraId {
            return "mycolab-cam-\(peerCam)"
        }
        // 5. Last paired camera ID saved in UserDefaults
        if let savedPaired = UserDefaults.standard.string(forKey: "mycolab_paired_camera_id")?.trimmingCharacters(in: .whitespacesAndNewlines), !savedPaired.isEmpty, savedPaired != pairingManager.localCameraId {
            return "mycolab-cam-\(savedPaired)"
        }
        // 6. Last used LiveKit room if not default and doesn't belong to local phone
        if let lastRoom = UserDefaults.standard.string(forKey: "mycolab_last_livekit_room")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lastRoom.isEmpty, lastRoom != LiveKitTokenGenerator.defaultRoom,
           !lastRoom.contains(pairingManager.localCameraId) {
            return lastRoom
        }
        // 7. If currently connected to any room
        if isConnected && !currentRoomName.isEmpty {
            return currentRoomName
        }
        // 8. Default shared lab room so both devices connect immediately without pairing!
        return LiveKitTokenGenerator.currentRoom
    }

    /// Connects to the active grow camera as viewer using the resolved room and wakes up the camera
    public func autoConnectToActiveCameraAsViewer(forceFresh: Bool = false) async {
        let targetRoom = resolveTargetCameraRoom()
        print("[LiveKitStreamManager] autoConnectToActiveCameraAsViewer targetRoom: \(targetRoom)")

        if !forceFresh && isConnected && currentRole == .viewer && currentRoomName == targetRoom && remoteVideoTrack != nil {
            return
        }

        self.isUserInitiatedStop = false
        self.isBroadcastingPaused = false
        self.autoReconnectAttempts = 0
        self.isReconnecting = false
        if forceFresh {
            self.remoteVideoTrack = nil
        }
        sendWakeSignalToBroadcaster(roomName: targetRoom)
        await startStream(role: .viewer, roomName: targetRoom, forceFresh: forceFresh)
    }

    // MARK: - Dedicated Broadcaster & Viewer Launchers
    public func startBroadcaster(cameraId: String? = nil, forceFresh: Bool = false) async {
        if isStartingStream {
            print("[LiveKitStreamManager] Broadcaster startup already in progress, skipping duplicate call.")
            return
        }
        self.isUserInitiatedStop = false
        self.isBroadcastingPaused = false
        self.autoReconnectAttempts = 0
        self.isReconnecting = false
        if forceFresh {
            self.localVideoTrack = nil
        }

        // 1. Immediately ensure local camera track is running on device
        if self.localVideoTrack == nil {
            await startLocalStandaloneCameraTrack()
        }

        let pairingManager = MycoCamPairingManager.shared
        let effectiveCamId: String
        if let camId = cameraId?.trimmingCharacters(in: .whitespacesAndNewlines), !camId.isEmpty {
            effectiveCamId = camId
        } else if !pairingManager.localCameraId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            effectiveCamId = pairingManager.localCameraId.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            effectiveCamId = ""
        }

        let targetRoom: String
        if !effectiveCamId.isEmpty {
            targetRoom = "mycolab-cam-\(effectiveCamId)"
            MycoKVS.set(effectiveCamId, forKey: "mycolab_registered_camera_id")
            MycoKVS.synchronize()
        } else {
            targetRoom = LiveKitTokenGenerator.currentRoom
        }
        await startStream(role: .broadcaster, roomName: targetRoom, forceFresh: forceFresh)
    }

    public func startViewer(cameraId: String? = nil, forceFresh: Bool = false) async {
        self.isUserInitiatedStop = false
        self.isBroadcastingPaused = false
        self.autoReconnectAttempts = 0
        self.isReconnecting = false
        if forceFresh {
            self.remoteVideoTrack = nil
        }
        let targetRoom = resolveTargetCameraRoom(overrideId: cameraId)
        sendWakeSignalToBroadcaster(roomName: targetRoom)
        await startStream(role: .viewer, roomName: targetRoom, forceFresh: forceFresh)
        if currentRole == .viewer {
            self.requestRemoteCameras()
            self.requestTimelapseStatus()
        }
    }

    // MARK: - Connect & Disconnect
    public func startStream(role: LiveKitRole, roomName: String = LiveKitTokenGenerator.defaultRoom, forceFresh: Bool = false) async {
        if !forceFresh && isConnected && currentRole == role && currentRoomName == roomName {
            if role == .viewer && remoteVideoTrack != nil { return }
            if role == .broadcaster && localVideoTrack != nil { return }
        }

        // Concurrency guard: avoid overlapping startStream runs for the same target
        if isStartingStream && currentRole == role && currentRoomName == roomName {
            print("[LiveKitStreamManager] startStream already in progress for room: \(roomName), skipping duplicate call.")
            return
        }
        self.isStartingStream = true
        defer { self.isStartingStream = false }

        self.isUserInitiatedStop = false
        self.isBroadcastingPaused = false
        self.currentRole = role
        self.currentRoomName = roomName
        self.isViewerWaitingTooLong = false
        self.isInEcoStandby = false
        self.noViewerIdleSeconds = 0
        self.statusMessage = "Verbinden met LiveKit Cloud..."

        // Cancel pending auto-reconnect timer since an explicit stream start is underway
        self.reconnectTask?.cancel()
        self.reconnectTask = nil

        // Keep screen awake while streaming or viewing
        UIApplication.shared.isIdleTimerDisabled = true
        startScreenAwakeWatchdog()

        // If broadcaster, activate 24/7 Lab Hub mode & persistent Wi-Fi P2P advertising
        if role == .broadcaster {
            self.isStreamHubModeActive = true
            MycoCamPairingManager.shared.startAdvertisingCamera()
            MycoBackgroundHubManager.shared.enableStreamHubMode()
            NotificationCenter.default.post(name: NSNotification.Name("MycoLabStartAutopilotEngine"), object: nil)
        }

        // Ensure camera authorization for broadcaster
        if role == .broadcaster {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            if status == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
            }
            loadAvailableCameras()
        }

        // Cancel previous polling task if any
        trackPollingTask?.cancel()
        trackPollingTask = nil

        // Disconnect any existing room cleanly without triggering delegate disconnect loops
        if let existing = room {
            existing.remove(delegate: self)
            await existing.disconnect()
            self.room = nil
        }

        let newRoom = Room(delegate: self)
        self.room = newRoom

        let identity = role == .broadcaster ? "lab-cam-\(UUID().uuidString.prefix(8))" : "viewer-\(UUID().uuidString.prefix(8))"
        let canPublish = true // Allow both broadcaster and viewer to publish data channel commands and sync payloads
        UserDefaults.standard.set(roomName, forKey: "mycolab_last_livekit_room")

        guard let token = await LiveKitTokenGenerator.fetchOrGenerateToken(
            identity: identity,
            room: roomName,
            name: role.rawValue,
            canPublish: canPublish,
            canSubscribe: true,
            durationInHours: 72
        ) else {
            self.statusMessage = "Fout bij genereren van authenticatie-token."
            if !self.isUserInitiatedStop && self.isPersistentAutoReconnectEnabled {
                self.scheduleAutoReconnect()
            }
            return
        }

        do {
            let connectOpts = ConnectOptions(
                autoSubscribe: true,
                reconnectAttempts: 25,
                reconnectAttemptDelay: 0.4,
                reconnectMaxDelay: 3.0,
                socketConnectTimeoutInterval: 8.0,
                primaryTransportConnectTimeout: 8.0,
                publisherTransportConnectTimeout: 8.0
            )

            let roomOpts = RoomOptions(
                adaptiveStream: true,
                dynacast: true,
                stopLocalTrackOnUnpublish: true,
                suspendLocalVideoTracksInBackground: false,
                singlePeerConnection: false
            )

            self.isUserInitiatedStop = false
            self.isBroadcastingPaused = false

            var connectSuccess = false
            var lastError: Error? = nil

            for startupAttempt in 1...3 {
                do {
                    try await newRoom.connect(
                        url: LiveKitTokenGenerator.currentServerUrl,
                        token: token,
                        connectOptions: connectOpts,
                        roomOptions: roomOpts
                    )
                    connectSuccess = true
                    break
                } catch {
                    lastError = error
                    print("[LiveKitStreamManager] Startup connect attempt \(startupAttempt) failed: \(error)")
                    if startupAttempt < 3 {
                        self.statusMessage = "Verbinding initialiseren (poging \(startupAttempt + 1)/3)..."
                        try? await Task.sleep(nanoseconds: 350_000_000)
                    }
                }
            }

            guard connectSuccess else {
                print("[LiveKitStreamManager] Connection error after retries: \(String(describing: lastError))")
                self.isQuotaExceeded = false
                self.isConnected = false
                self.isReconnecting = false
                if role == .broadcaster {
                    await startLocalStandaloneCameraTrack()
                    self.statusMessage = "Lokale Camera Actief (P2P Standby)"
                } else {
                    self.statusMessage = "Verbindingsfout: \(lastError?.localizedDescription ?? "Onbekende fout")"
                    if !self.isUserInitiatedStop && self.autoReconnectAttempts < self.maxAutoReconnectAttempts {
                        self.scheduleAutoReconnect()
                    }
                }
                return
            }

            self.isConnected = true
            self.connectionState = .connected
            self.autoReconnectAttempts = 0
            self.isReconnecting = false

            if role == .broadcaster {
                self.statusMessage = "Camera initialiseren..."

                if let existingLocalTrack = self.localVideoTrack as? LocalVideoTrack {
                    // Fast path: standalone camera track is already running on the device.
                    // Publish it directly to avoid AVCaptureSession contention!
                    do {
                        let pub = try await newRoom.localParticipant.publish(videoTrack: existingLocalTrack)
                        if let track = pub.track as? VideoTrack {
                            self.localVideoTrack = track
                            track.add(videoRenderer: P2PStreamBroadcaster.shared)
                        }
                    } catch {
                        print("[LiveKitStreamManager] Failed to publish existing camera track, falling back to setCamera: \(error)")
                        let targetDevice = AVCaptureDevice(uniqueID: selectedCameraID) ?? AVCaptureDevice.default(for: .video)
                        let options = CameraCaptureOptions(
                            device: targetDevice,
                            position: targetDevice?.position ?? .unspecified,
                            dimensions: streamQuality.dimensions(aspectRatio: captureAspectRatio),
                            fps: 30
                        )
                        let publication = try await newRoom.localParticipant.setCamera(enabled: true, captureOptions: options, publishOptions: streamQuality.publishOptions)
                        if let track = publication?.track as? VideoTrack {
                            self.localVideoTrack = track
                            track.add(videoRenderer: P2PStreamBroadcaster.shared)
                        }
                    }
                } else {
                    // Build camera options using user selected camera device if available, falling back to default video device on Mac/iPad
                    let targetDevice = AVCaptureDevice(uniqueID: selectedCameraID) ?? AVCaptureDevice.default(for: .video)
                    let options = CameraCaptureOptions(
                        device: targetDevice,
                        position: targetDevice?.position ?? .unspecified,
                        dimensions: streamQuality.dimensions(aspectRatio: captureAspectRatio),
                        fps: 30
                    )

                    let publication = try await newRoom.localParticipant.setCamera(enabled: true, captureOptions: options, publishOptions: streamQuality.publishOptions)

                    if let track = publication?.track as? VideoTrack {
                        self.localVideoTrack = track
                        track.add(videoRenderer: P2PStreamBroadcaster.shared)
                    } else if let track = newRoom.localParticipant.firstCameraVideoTrack {
                        self.localVideoTrack = track
                        track.add(videoRenderer: P2PStreamBroadcaster.shared)
                    } else if let track = newRoom.localParticipant.videoTracks.first?.track as? VideoTrack {
                        self.localVideoTrack = track
                        track.add(videoRenderer: P2PStreamBroadcaster.shared)
                    }
                }

                // If track not immediately available, retry over 2 seconds
                if self.localVideoTrack == nil {
                    for _ in 0..<10 {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        if let track = newRoom.localParticipant.firstCameraVideoTrack ?? (newRoom.localParticipant.videoTracks.first?.track as? VideoTrack) {
                            self.localVideoTrack = track
                            track.add(videoRenderer: P2PStreamBroadcaster.shared)
                            break
                        }
                    }
                }

                self.statusMessage = "Live HD Uitzending Actief (WebRTC)"
                broadcastCameraList()
                broadcastTimelapseStatus()
            } else {
                self.statusMessage = "Verbonden als kijker. Wachten op videobeeld..."
                // Force subscription to any remote participant video tracks immediately
                for p in newRoom.remoteParticipants.values {
                    for pub in p.videoTracks {
                        if let remotePub = pub as? RemoteTrackPublication, !remotePub.isSubscribed {
                            Task {
                                try? await remotePub.set(subscribed: true)
                            }
                        }
                    }
                }
                updateRemoteTrack()
                requestRemoteCameras()
                requestTimelapseStatus()

                // Background polling to catch remote video track as soon as it publishes (and wake camera if needed)
                trackPollingTask = Task { @MainActor [weak self] in
                    var pollCount = 0
                    while !Task.isCancelled {
                        let delayNs: UInt64 = pollCount < 10 ? 250_000_000 : 600_000_000
                        try? await Task.sleep(nanoseconds: delayNs)
                        pollCount += 1
                        guard let self = self, self.isConnected, self.currentRole == .viewer else { break }
                        if self.remoteVideoTrack == nil {
                            if let room = self.room {
                                for p in room.remoteParticipants.values {
                                    for pub in p.videoTracks {
                                        if let remotePub = pub as? RemoteTrackPublication, !remotePub.isSubscribed {
                                            Task {
                                                try? await remotePub.set(subscribed: true)
                                            }
                                        }
                                    }
                                }
                            }
                            self.updateRemoteTrack()
                            if pollCount == 1 || pollCount == 4 || pollCount == 8 {
                                self.sendWakeSignalToBroadcaster(roomName: self.currentRoomName)
                            }
                            if pollCount >= 16 {
                                self.isViewerWaitingTooLong = true
                                self.statusMessage = "Kweekcamera wordt gewekt of herstart..."
                            }
                        } else {
                            self.isViewerWaitingTooLong = false
                        }
                    }
                }
            }
        } catch {
            print("[LiveKitStreamManager] Connection error: \(error)")
            self.statusMessage = "Verbindingsfout: \(error.localizedDescription)"
            self.isConnected = false
        }
    }

    public func stopStream() async {
        if currentRole == .viewer {
            sendSleepSignalToBroadcaster(roomName: currentRoomName)
        }
        // Cancel polling
        trackPollingTask?.cancel()
        trackPollingTask = nil
        isViewerWaitingTooLong = false
        isInEcoStandby = false
        noViewerIdleSeconds = 0

        hubHeartbeatTimer?.cancel()
        hubHeartbeatTimer = nil
        if !isTimelapseRunning {
            isStreamHubModeActive = false
            timelapseTimer?.cancel()
            timelapseTimer = nil
        }

        // Re-enable screen timeout only if not broadcaster, not hub, not timelapse, and not dedicated camera
        let isDedicated = UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
        if currentRole != .broadcaster && !MycoBackgroundHubManager.shared.isKeepScreenOnActive && !MycoBackgroundHubManager.shared.isStreamHubRoleActive && !isDedicated && !isStreamHubModeActive && !isTimelapseRunning {
            UIApplication.shared.isIdleTimerDisabled = false
        }

        if isTorchOn {
            setLocalTorch(on: false)
        }
        self.isUserInitiatedStop = true
        self.isBroadcastingPaused = false
        self.reconnectTask?.cancel()
        self.reconnectTask = nil
        self.autoReconnectAttempts = 0
        self.isReconnecting = false

        if let room = room {
            room.remove(delegate: self)
            await room.disconnect()
        }
        self.room = nil
        self.isConnected = false
        self.localVideoTrack = nil
        self.remoteVideoTrack = nil
        self.statusMessage = "Gestopt"
    }

    // MARK: - Remote & Local Torch & Brightness Control (Non-Freezing)
    public func toggleTorch() {
        let newState = !isTorchOn
        isTorchOn = newState

        if currentRole == .broadcaster {
            setLocalTorch(on: newState, level: torchBrightness)
        } else {
            sendDataCommand(command: newState ? "torch:on:\(torchBrightness)" : "torch:off")
            MycoCamStreamManager.shared.sendTorchCommand(isOn: newState, brightness: torchBrightness)
        }
    }

    public func setTorch(on: Bool, level: Float? = nil) {
        let lvl = level ?? torchBrightness
        isTorchOn = on
        torchBrightness = lvl
        if currentRole == .broadcaster {
            setLocalTorch(on: on, level: lvl)
        } else {
            sendDataCommand(command: on ? "torch:on:\(lvl)" : "torch:off")
        }
    }

    public func setTorchBrightness(_ level: Float) {
        let clamped = max(0.01, min(1.0, level))
        self.torchBrightness = clamped
        if currentRole == .broadcaster {
            if isTorchOn {
                setLocalTorch(on: true, level: clamped)
            }
        } else {
            sendDataCommand(command: String(format: "torch:level:%.2f", clamped))
        }
    }

    public func getActiveCaptureDevice() -> AVCaptureDevice? {
        if !selectedCameraID.isEmpty, let dev = AVCaptureDevice(uniqueID: selectedCameraID) {
            return dev
        }
        if let localTrack = localVideoTrack as? LocalVideoTrack,
           let capturer = localTrack.capturer as? CameraCapturer,
           let dev = capturer.device {
            return dev
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    /// Returns the capture device responsible for torch illumination (handles iPhone models where Ultra-Wide lacks torch property).
    public func getTorchCapableDevice() -> AVCaptureDevice? {
        // 1. Check if the currently active capture device directly supports torch
        if let dev = getActiveCaptureDevice(), dev.hasTorch {
            return dev
        }
        // 2. If current camera is facing rear (or unspecified), fall back to primary back wide angle camera which controls the True Tone flash
        let currentPos = getActiveCaptureDevice()?.position ?? .back
        if currentPos != .front {
            if let backWide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), backWide.hasTorch {
                return backWide
            }
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInTripleCamera, .builtInDualWideCamera],
                mediaType: .video,
                position: .back
            )
            return discovery.devices.first(where: { $0.hasTorch })
        }
        return nil
    }

    private func applyDeviceTorch(device: AVCaptureDevice, on: Bool, level: Float = 1.0) async {
        guard device.hasTorch else { return }
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try device.lockForConfiguration()
                    if on {
                        if device.isTorchModeSupported(.on) {
                            try device.setTorchModeOn(level: max(0.01, min(1.0, level)))
                        }
                    } else {
                        if device.isTorchModeSupported(.off) {
                            device.torchMode = .off
                        }
                    }
                    device.unlockForConfiguration()
                } catch {
                    print("[LiveKitStreamManager] Torch configuration error: \(error)")
                }
                continuation.resume()
            }
        }
    }

    /// Captures a raw UIImage from the active local or remote video track without saving to Photos.
    public func captureRawCameraUIImage() async -> UIImage? {
        let track = (currentRole == .viewer) ? (remoteVideoTrack ?? localVideoTrack) : (localVideoTrack ?? remoteVideoTrack)
        if let track = track {
            return await captureCurrentFrame(from: track)
        }
        return nil
    }

    /// Captures a single video frame with hardware flash illumination if camera torch is available.
    public func captureFrameWithFlash(from track: VideoTrack) async -> UIImage? {
        guard let device = getTorchCapableDevice() else {
            return await captureCurrentFrame(from: track)
        }

        let previousTorchState = isTorchOn
        let previousBrightness = torchBrightness

        // Turn torch ON for flash
        await applyDeviceTorch(device: device, on: true, level: 1.0)

        // Wait ~350ms so sensor exposure and auto white balance adapt to the flash illumination
        var image: UIImage? = nil
        do {
            try await Task.sleep(nanoseconds: 350_000_000)
            image = await captureCurrentFrame(from: track)
            try await Task.sleep(nanoseconds: 50_000_000)
        } catch {
            print("[LiveKitStreamManager] Flash capture error: \(error)")
        }

        // Restore previous torch state
        if previousTorchState {
            await applyDeviceTorch(device: device, on: true, level: previousBrightness)
        } else {
            await applyDeviceTorch(device: device, on: false, level: 0)
        }

        return image
    }

    /// Sets camera torch safely with brightness level without interrupting video stream.
    private func setLocalTorch(on: Bool, level: Float = 0.8) {
        guard let device = getTorchCapableDevice() else {
            Task { @MainActor [weak self] in
                self?.isTorchOn = false
                self?.broadcastTorchStatus()
            }
            return
        }

        let clamped = max(0.01, min(1.0, level))
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var success = false
            do {
                try device.lockForConfiguration()
                if on {
                    if device.isTorchModeSupported(.on) {
                        try device.setTorchModeOn(level: clamped)
                        success = true
                    }
                } else {
                    if device.isTorchModeSupported(.off) {
                        device.torchMode = .off
                        success = true
                    }
                }
                device.unlockForConfiguration()
            } catch {
                print("[LiveKitStreamManager] Torch error: \(error)")
            }

            let initialSuccess = success
            if on && !initialSuccess {
                // If initial attempt failed (e.g. during camera pipeline transition), retry once after 250ms
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.25) {
                    var retrySuccess = false
                    do {
                        try device.lockForConfiguration()
                        if device.isTorchModeSupported(.on) {
                            try device.setTorchModeOn(level: clamped)
                            retrySuccess = true
                        }
                        device.unlockForConfiguration()
                    } catch {
                        print("[LiveKitStreamManager] Torch retry error: \(error)")
                    }
                    let didRetrySucceed = retrySuccess
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.isTorchOn = didRetrySucceed
                        self.torchBrightness = clamped
                        self.broadcastTorchStatus()
                    }
                }
            } else {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.isTorchOn = on && initialSuccess
                    self.torchBrightness = clamped
                    self.broadcastTorchStatus()
                }
            }
        }
    }

    // MARK: - Tap-To-Focus & Autofocus
    public func sendFocusCommand(x: CGFloat, y: CGFloat) {
        let clampedX = max(0.0, min(1.0, x))
        let clampedY = max(0.0, min(1.0, y))
        let isLocalBroadcaster = currentRole == .broadcaster
            || isStreamHubModeActive
            || MycoBackgroundHubManager.shared.isStreamHubRoleActive
            || localVideoTrack != nil
        if isLocalBroadcaster {
            setFocusPoint(normalizedPoint: CGPoint(x: clampedX, y: clampedY))
        } else {
            sendDataCommand(command: String(format: "focus:%.4f,%.4f", clampedX, clampedY))
            _ = MycoCamPairingManager.shared.sendDirectCommandToPeers(String(format: "focus:%.4f,%.4f", clampedX, clampedY))
        }
    }


    // MARK: - Tent-Lock: Autofocus & Belichting Vergrendeling voor Kweektenten
    @Published public var isTentLockActive: Bool = false

    public func toggleTentLock() {
        setTentLock(locked: !isTentLockActive)
    }

    public func setTentLock(locked: Bool, notifyPeer: Bool = true) {
        isTentLockActive = locked
        if currentRole == .broadcaster || isStreamHubModeActive || MycoBackgroundHubManager.shared.isStreamHubRoleActive {
            applyTentLockToActiveDevice(locked: locked)
        }
        if notifyPeer {
            sendDataCommand(command: locked ? "cmd:tentlock:on" : "cmd:tentlock:off")
        }
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        withAnimation {
            self.lastSavedSnapshotToast = locked ? "🔒 Tent-Lock AAN: Focus & Belichting vergrendeld!" : "🔓 Tent-Lock UIT: Automatische focus & belichting"
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.lastSavedSnapshotToast?.contains("Tent-Lock") == true {
                withAnimation { self.lastSavedSnapshotToast = nil }
            }
        }
    }

    private func applyTentLockToActiveDevice(locked: Bool) {
        guard let device = getActiveCaptureDevice() else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try device.lockForConfiguration()
                if locked {
                    if device.isFocusModeSupported(.locked) {
                        device.focusMode = .locked
                    }
                    if device.isExposureModeSupported(.locked) {
                        device.exposureMode = .locked
                    }
                    if device.isWhiteBalanceModeSupported(.locked) {
                        device.whiteBalanceMode = .locked
                    }
                    device.isSubjectAreaChangeMonitoringEnabled = false
                    print("[LiveKitStreamManager] Tent-Lock GEACTIVEERD op \(device.localizedName)")
                } else {
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        device.whiteBalanceMode = .continuousAutoWhiteBalance
                    }
                    device.isSubjectAreaChangeMonitoringEnabled = true
                    print("[LiveKitStreamManager] Tent-Lock gedeactiveerd op \(device.localizedName)")
                }
                device.unlockForConfiguration()
            } catch {
                print("[LiveKitStreamManager] Error Tent-Lock: \(error)")
            }
        }
    }

    // MARK: - Dynamische FPS & Thermische Bescherming voor Kweektent 24/7
    public func updateDynamicFrameRate() {
        guard currentRole == .broadcaster || isStreamHubModeActive || MycoBackgroundHubManager.shared.isStreamHubRoleActive else { return }
        guard let device = getActiveCaptureDevice() else { return }

        let hasActiveRemoteViewer = participantCount > 1
        let targetFps: Double = hasActiveRemoteViewer ? 30.0 : 5.0

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try device.lockForConfiguration()
                let frameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFps))
                if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= targetFps && targetFps <= $0.maxFrameRate }) {
                    device.activeVideoMinFrameDuration = frameDuration
                    device.activeVideoMaxFrameDuration = frameDuration
                    print("[LiveKitStreamManager] Dynamische framerate: \(targetFps) FPS (Kijker actief: \(hasActiveRemoteViewer))")
                }
                device.unlockForConfiguration()
            } catch {
                print("[LiveKitStreamManager] Dynamic FPS error: \(error)")
            }
        }
    }

    // MARK: - Gecombineerde Kweeklamp & Timelapse Multi-Lens + Optische Meter Routine
    public func triggerSynchronizedGrowLightCapture(source: String = "Kweeklamp Ingeschakeld") {
        let isBroadcaster = currentRole == .broadcaster
            || isStreamHubModeActive
            || MycoBackgroundHubManager.shared.isStreamHubRoleActive
            || localVideoTrack != nil

        if !isBroadcaster {
            sendDataCommand(command: "cmd:lamp:turned_on")
            return
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            print("[LiveKitStreamManager] Kweeklampen aan! Multi-lens kweekopname & optische meter scan starten...")

            try? await Task.sleep(nanoseconds: 400_000_000)

            let backCameras = self.availableCameras.filter { $0.position == .back }
            let originalCameraID = self.selectedCameraID

            let sortedCams = backCameras.sorted { a, b in
                let rankA: Int = {
                    switch a.deviceType {
                    case .builtInWideAngleCamera: return 0
                    case .builtInUltraWideCamera: return 1
                    case .builtInTelephotoCamera: return 2
                    default: return 3
                    }
                }()
                let rankB: Int = {
                    switch b.deviceType {
                    case .builtInWideAngleCamera: return 0
                    case .builtInUltraWideCamera: return 1
                    case .builtInTelephotoCamera: return 2
                    default: return 3
                    }
                }()
                return rankA < rankB
            }

            if sortedCams.count > 1 {
                for cam in sortedCams {
                    await self.selectCamera(id: cam.id)
                    try? await Task.sleep(nanoseconds: 350_000_000)

                    let (camType, camLabel): (String, String) = {
                        switch cam.deviceType {
                        case .builtInUltraWideCamera:
                            return ("ultraWide", "Tent (0.5x)")
                        case .builtInTelephotoCamera:
                            return ("telephoto", "Sensor AI (Zoom)")
                        default:
                            return ("wide", "Kweek (1.0x)")
                        }
                    }()

                    let caption = "\(camLabel) • \(source)"
                    _ = await self.captureAndSaveSnapshot(
                        withFlash: false,
                        customCaption: caption,
                        relativeMinutes: 0,
                        cameraType: camType,
                        cameraName: camLabel
                    )
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }

                if !originalCameraID.isEmpty && self.selectedCameraID != originalCameraID {
                    await self.selectCamera(id: originalCameraID)
                }
            } else {
                _ = await self.captureAndSaveSnapshot(
                    withFlash: false,
                    customCaption: "Kweek (1.0x) • \(source)",
                    relativeMinutes: 0,
                    cameraType: "wide",
                    cameraName: "Kweek (1.0x)"
                )
            }

            _ = await MycoOpticalHygrometerManager.shared.triggerScanAndReact()

            withAnimation {
                self.lastSavedSnapshotToast = "🌱 Kweeklamp cyclus: Foto's & Optische scan vastgelegd!"
            }
            Task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                if self.lastSavedSnapshotToast?.contains("Kweeklamp") == true {
                    withAnimation { self.lastSavedSnapshotToast = nil }
                }
            }
        }
    }

    public func setFocusPoint(normalizedPoint: CGPoint) {
        guard let device = getActiveCaptureDevice() else { return }
        
        let clampedX = max(0.0, min(1.0, normalizedPoint.x))
        let clampedY = max(0.0, min(1.0, normalizedPoint.y))
        
        // In AVFoundation portrait video, coordinates are transposed: (y, 1 - x)
        let devicePoint = CGPoint(x: clampedY, y: 1.0 - clampedX)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try device.lockForConfiguration()
                
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    if device.isFocusModeSupported(.autoFocus) {
                        if device.focusMode == .autoFocus, device.isFocusModeSupported(.continuousAutoFocus) {
                            device.focusMode = .continuousAutoFocus
                        }
                        device.focusMode = .autoFocus
                    } else if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                }
                
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    if device.isExposureModeSupported(.autoExpose) {
                        if device.exposureMode == .autoExpose, device.isExposureModeSupported(.continuousAutoExposure) {
                            device.exposureMode = .continuousAutoExposure
                        }
                        device.exposureMode = .autoExpose
                    } else if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
                print("[LiveKitStreamManager] Autofocus set to devicePoint: \(devicePoint)")
            } catch {
                print("[LiveKitStreamManager] Focus error: \(error)")
            }
        }
    }

    public func requestSnapshot(withFlash: Bool = false) {
        sendDataCommand(command: withFlash ? "cmd:snapshot:flash" : "cmd:snapshot")
    }

    public func requestWideFlashSnapshot() {
        sendDataCommand(command: "cmd:snapshot:wide:flash")
    }

    // MARK: - Unified OLED Saver (Local & Remote Screen Standby)
    public func setOledSaver(active: Bool, notifyPeer: Bool = true) {
        isOledSaverActive = active
        MycoBackgroundHubManager.shared.setOledStandbyMode(active)
        if notifyPeer {
            sendDataCommand(command: "screen:sleep:status:\(active ? "1" : "0")")
        }
    }

    public func toggleRemoteSleep() {
        sendDataCommand(command: "screen:sleep:toggle")
        isRemoteScreenDimmed.toggle()
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
    }

    public func setRemoteSleep(on: Bool) {
        isRemoteScreenDimmed = on
        sendDataCommand(command: on ? "screen:sleep:on" : "screen:sleep:off")
    }

    public func sendDataCommand(command: String) {
        _ = MycoCamPairingManager.shared.sendDirectCommandToPeers(command)
        MycoCamStreamManager.shared.sendPlaintextCommand(command)
        if command == "screen:sleep:on" {
            MycoCamStreamManager.shared.sendRemoteScreenSleep(dim: true)
        } else if command == "screen:sleep:off" {
            MycoCamStreamManager.shared.sendRemoteScreenSleep(dim: false)
        } else if command == "screen:sleep:toggle" {
            let nextState = !isRemoteScreenDimmed
            MycoCamStreamManager.shared.sendRemoteScreenSleep(dim: nextState)
        }
        guard let room = room, let data = command.data(using: .utf8) else { return }
        Task {
            _ = try? await room.localParticipant.publish(data: data, options: DataPublishOptions(topic: "mycolab_control", reliable: true))
            _ = try? await room.localParticipant.publish(data: data, options: DataPublishOptions(reliable: true))
        }
    }

    public func publishSyncData(_ data: Data) {
        guard let room = room else { return }
        Task {
            _ = try? await room.localParticipant.publish(data: data, options: DataPublishOptions(topic: "mycolab_sync", reliable: true))
            let base64 = data.base64EncodedString()
            if let cmdData = "sync:smart_devices:\(base64)".data(using: .utf8) {
                _ = try? await room.localParticipant.publish(data: cmdData, options: DataPublishOptions(reliable: true))
            }
        }
    }

    /// Delivers a sync payload over LiveKit only if already connected; NEVER opens a background LiveKit room.
    public func deliverBackgroundSyncPayload(_ data: Data) {
        if isConnected, let room = room {
            Task {
                _ = try? await room.localParticipant.publish(data: data, options: DataPublishOptions(topic: "mycolab_sync", reliable: true))
                let base64 = data.base64EncodedString()
                if let cmdData = "sync:smart_devices:\(base64)".data(using: .utf8) {
                    _ = try? await room.localParticipant.publish(data: cmdData, options: DataPublishOptions(reliable: true))
                }
            }
        }
        // Background sync is handled 100% by Apple iCloud KVS and Multipeer P2P without consuming LiveKit minutes.
    }

    public func updateRemoteTrack() {
        guard let room = room else {
            self.remoteVideoTrack = nil
            return
        }

        // Search for any published and subscribed remote video track
        for p in room.remoteParticipants.values {
            if let track = p.firstCameraVideoTrack {
                self.remoteVideoTrack = track
                self.isViewerWaitingTooLong = false
                self.statusMessage = "Live HD Beeld (WebRTC)"
                return
            }
            for pub in p.videoTracks {
                if let remotePub = pub as? RemoteTrackPublication, !remotePub.isSubscribed {
                    Task {
                        try? await remotePub.set(subscribed: true)
                    }
                }
                if let track = pub.track as? VideoTrack {
                    self.remoteVideoTrack = track
                    self.isViewerWaitingTooLong = false
                    self.statusMessage = "Live HD Beeld (WebRTC)"
                    return
                }
            }
        }
        
        // No active video track found on any connected remote participant
        self.remoteVideoTrack = nil
        if room.remoteParticipants.isEmpty {
            if currentRole == .viewer {
                self.statusMessage = "Kweekcamera offline of herstart..."
            }
        }
    }
}

// MARK: - RoomDelegate Callbacks
extension LiveKitStreamManager: RoomDelegate {
    nonisolated public func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from fromState: ConnectionState) {
        Task { @MainActor in
            guard room === self.room else {
                print("[LiveKitStreamManager] Ignoring connectionState update from orphaned/previous room.")
                return
            }
            self.connectionState = connectionState
            switch connectionState {
            case .connected:
                self.isConnected = true
                self.isReconnecting = false
                self.autoReconnectAttempts = 0
                if self.currentRole == .viewer {
                    self.statusMessage = "Verbonden (LiveKit HD)"
                    self.updateRemoteTrack()
                    self.requestRemoteCameras()
                    self.requestTimelapseStatus()
                    MycoSensorIntelligenceManager.shared.requestRemoteSensorStatus()
                    self.isRemoteHubOnline = true
                    self.lastRemoteHubHeartbeat = Date()
                    self.requestHubStatus()
                } else {
                    self.statusMessage = "Live HD Uitzending Actief (WebRTC)"
                    self.broadcastCameraList()
                    self.broadcastTimelapseStatus()
                    MycoSensorIntelligenceManager.shared.broadcastTelemetryToViewers()
                    self.startHubHeartbeatTimer()
                    self.broadcastHubHeartbeat()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    MycoSyncManager.shared.onLiveKitConnected()
                }
            case .reconnecting:
                self.isReconnecting = true
                self.statusMessage = "Opnieuw verbinden met LiveKit (WebRTC ICE restart)..."
                // Watchdog: If LiveKit's internal ICE restart hangs for more than 3.5 seconds after a network switch, force fresh reconnect
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    if self.connectionState == .reconnecting && !self.isUserInitiatedStop && !self.isBroadcastingPaused && !self.isInEcoStandby {
                        print("[LiveKitStreamManager] ICE restart stalled after network switch, forcing fresh reconnect...")
                        await self.reconnectCurrentStream(forceFreshSession: true)
                    }
                }
            case .disconnected:
                self.isConnected = false
                if !self.isStartingStream && !self.isUserInitiatedStop && !self.isBroadcastingPaused && !self.isInEcoStandby && !self.isReconnecting && !self.currentRoomName.isEmpty {
                    self.scheduleAutoReconnect()
                } else if !self.isReconnecting {
                    self.statusMessage = "Verbinding verbroken"
                }
            default:
                break
            }
        }
    }

    nonisolated public func room(_ room: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            guard room === self.room else { return }
            if !publication.isSubscribed {
                try? await publication.set(subscribed: true)
            }
            self.updateRemoteTrack()
        }
    }

    nonisolated public func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            guard room === self.room else { return }
            if let videoTrack = publication.track as? VideoTrack {
                self.remoteVideoTrack = videoTrack
                self.isViewerWaitingTooLong = false
                self.autoReconnectAttempts = 0
                self.isReconnecting = false
                self.statusMessage = "Live HD Beeld (WebRTC)"
            } else {
                self.updateRemoteTrack()
            }
            if self.currentRole == .viewer {
                self.requestRemoteCameras()
            }
        }
    }

    nonisolated public func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            guard room === self.room else { return }
            if publication.track == self.remoteVideoTrack {
                self.remoteVideoTrack = nil
            }
            self.updateRemoteTrack()
        }
    }

    nonisolated public func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor in
            guard room === self.room else { return }
            self.participantCount = room.remoteParticipants.count + 1
            if self.currentRole == .broadcaster {
                self.updateDynamicFrameRate()
                print("[LiveKitStreamManager] Remote viewer connected: \(String(describing: participant.identity)) — Ensuring camera is active!")
                if self.isInEcoStandby {
                    await self.wakeFromEcoStandby()
                }
                if self.localVideoTrack == nil {
                    _ = await self.ensureCameraTrackAvailable()
                }
                self.broadcastCameraList()
                self.broadcastTorchStatus()
                self.broadcastTimelapseStatus()
            } else {
                self.statusMessage = "Kweekcamera verbonden. Beeld laden..."
                self.updateRemoteTrack()
                self.requestRemoteCameras()
                self.requestTimelapseStatus()
            }
        }
    }

    nonisolated public func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            guard room === self.room else { return }
            self.participantCount = room.remoteParticipants.count + 1
            self.updateRemoteTrack()
            if self.currentRole == .broadcaster {
                self.updateDynamicFrameRate()
            }
            if self.currentRole == .viewer && room.remoteParticipants.isEmpty {
                print("[LiveKitStreamManager] Broadcaster disconnected or entered standby — staying in room waiting for camera.")
                self.statusMessage = "Wachten op kweekcamera..."
                self.remoteVideoTrack = nil
                self.sendWakeSignalToBroadcaster(roomName: self.currentRoomName)
                
                // Proactive 5s watchdog: ping broadcaster again and refresh session if camera took a long network pause
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if self.currentRole == .viewer && self.room?.remoteParticipants.isEmpty == true && !self.isUserInitiatedStop && !self.isBroadcastingPaused {
                        print("[LiveKitStreamManager] Broadcaster still empty after 5s watchdog — pinging wake and resetting session...")
                        self.sendWakeSignalToBroadcaster(roomName: self.currentRoomName)
                        await self.reconnectCurrentStream(forceFreshSession: true)
                    }
                }
            } else if self.currentRole == .broadcaster && room.remoteParticipants.isEmpty && self.isEcoTokenSaverEnabled {
                print("[LiveKitStreamManager] All viewers disconnected — staying connected for fast viewer reconnect.")
            }
        }
    }

    nonisolated public func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
        Task { @MainActor in
            guard room === self.room else { return }
            if topic == "optical_photo" || topic == "remote_snapshot" {
                if let image = UIImage(data: data) {
                    print("[LiveKitStreamManager] Received remote snapshot photo (\(data.count) bytes)")
                    self.lastRemoteSnapshot = image
                    self.lastSavedSnapshotToast = "📸 Foto ontvangen van kweekcamera!"
                    MycoOpticalHygrometerManager.shared.handleReceivedRemotePhoto(image)
                    if let store = MycoStore.shared {
                        let item = TimelapsePhotoItem.createAndSave(
                            image: image,
                            caption: "Kweekcamera Live Snapshot",
                            relativeMinutes: 0
                        )
                        store.db.timelapsePhotos.insert(item, at: 0)
                        while store.db.timelapsePhotos.count > 60 {
                            let old = store.db.timelapsePhotos.removeLast()
                            old.deleteFile()
                        }
                        store.save()
                    }
                }
                return
            }
            if topic == "optical_photo_chunk" {
                self.handleIncomingPhotoChunk(data)
                return
            }
            if topic == "mycolab_sync" {
                MycoSyncManager.shared.handleIncomingData(data, transport: "4G/5G LiveKit Cloud")
                return
            }
            if topic == "mycolab_alert" {
                if let record = try? JSONDecoder().decode(LabAlertRecord.self, from: data) {
                    MycoLabAlertManager.shared.handleIncomingRemoteAlert(record, store: MycoStore.shared)
                } else if let text = String(data: data, encoding: .utf8), text.hasPrefix("alert:") {
                    let parts = text.components(separatedBy: ":")
                    if parts.count >= 5 {
                        let cat = LabAlertCategory(rawValue: parts[1]) ?? .lowHumidity
                        let sev = LabAlertSeverity(rawValue: parts[2]) ?? .warning
                        let record = LabAlertRecord(severity: sev, category: cat, title: parts[3], message: parts[4])
                        MycoLabAlertManager.shared.handleIncomingRemoteAlert(record, store: MycoStore.shared)
                    }
                }
                return
            }

            guard let text = String(data: data, encoding: .utf8) else { return }
            if text.hasPrefix("sync:smart_devices:") {
                let remainder = String(text.dropFirst("sync:smart_devices:".count))
                if let payloadData = Data(base64Encoded: remainder) {
                    MycoSyncManager.shared.handleIncomingData(payloadData, transport: "LiveKit Direct")
                } else if let rawData = remainder.data(using: .utf8) {
                    MycoSyncManager.shared.handleIncomingData(rawData, transport: "LiveKit Direct")
                }
                return
            }
            if MycoSyncManager.shared.isSyncPayload(data) {
                MycoSyncManager.shared.handleIncomingData(data, transport: "LiveKit Cloud")
                return
            }
            self.handleIncomingControlMessage(text)
        }
    }
}

// MARK: - Central Control Message Handler (P2P + LiveKit Cloud 0-Token Parity)
extension LiveKitStreamManager {
    public func handleIncomingControlMessage(_ text: String) {
        if text.hasPrefix("torch:on:") {
            let lvlStr = String(text.dropFirst("torch:on:".count))
            let lvl = Float(lvlStr) ?? 0.8
            self.torchBrightness = lvl
            self.setLocalTorch(on: true, level: lvl)
        } else if text == "torch:on" {
            self.setLocalTorch(on: true, level: self.torchBrightness)
        } else if text == "torch:off" {
            self.setLocalTorch(on: false)
        } else if text.hasPrefix("torch:level:") {
            let lvlStr = String(text.dropFirst("torch:level:".count))
            if let lvl = Float(lvlStr) {
                self.torchBrightness = lvl
                if self.isTorchOn {
                    self.setLocalTorch(on: true, level: lvl)
                }
            }
        } else if text.hasPrefix("torch:status:1:") {
            let lvlStr = String(text.dropFirst("torch:status:1:".count))
            let lvl = Float(lvlStr) ?? 0.8
            self.isTorchOn = true
            self.torchBrightness = lvl
        } else if text == "torch:status:1" {
            self.isTorchOn = true
        } else if text == "torch:status:0" {
            self.isTorchOn = false
        } else if text.hasPrefix("focus:") {
            let coords = String(text.dropFirst("focus:".count)).split(separator: ",")
            if coords.count == 2,
               let fx = Double(coords[0]),
               let fy = Double(coords[1]) {
                self.setFocusPoint(normalizedPoint: CGPoint(x: fx, y: fy))
            }
        } else if text == "cmd:snapshot" || text == "cmd:snapshot:flash" || text == "cmd:snapshot:wide:flash" || text.hasPrefix("request:snapshot") {
            let withFlash = (text == "cmd:snapshot:flash" || text == "cmd:snapshot:wide:flash")
            let isWide = (text == "cmd:snapshot:wide:flash")
            self.onRemoteSnapshotRequested?()
            let canCapture = self.currentRole == .broadcaster
                || self.isStreamHubModeActive
                || MycoBackgroundHubManager.shared.isStreamHubRoleActive
                || self.localVideoTrack != nil
            if canCapture {
                Task {
                    if isWide {
                        await self.selectCameraByType("wide")
                        try? await Task.sleep(nanoseconds: 350_000_000)
                    }
                    _ = await self.captureAndSaveSnapshot(
                        withFlash: withFlash,
                        customCaption: isWide ? "Kweekruimte Overzicht (Optische Scan Flits)" : nil,
                        cameraType: isWide ? "wide" : nil,
                        cameraName: isWide ? "Kweek (1.0x Groothoek)" : nil
                    )
                }
            }
        } else if text == "screen:sleep:toggle" {
            self.setOledSaver(active: !self.isOledSaverActive, notifyPeer: true)
        } else if text == "screen:sleep:on" {
            self.setOledSaver(active: true, notifyPeer: true)
        } else if text == "screen:sleep:off" {
            self.setOledSaver(active: false, notifyPeer: true)
        } else if text.hasPrefix("screen:sleep:status:") {
            let status = text.dropFirst("screen:sleep:status:".count)
            self.isRemoteScreenDimmed = (status == "1")
        } else if text == "cmd:tentlock:on" {
            self.setTentLock(locked: true, notifyPeer: false)
        } else if text == "cmd:tentlock:off" {
            self.setTentLock(locked: false, notifyPeer: false)
        } else if text == "cmd:lamp:turned_on" {
            self.triggerSynchronizedGrowLightCapture(source: "Kweeklamp Ingeschakeld (Afstand)")
        } else if text == "camera:next" {
            Task {
                await self.switchToNextCamera()
            }
        } else if text.hasPrefix("camera:id:") {
            let id = String(text.dropFirst("camera:id:".count))
            Task {
                await self.selectCamera(id: id)
            }
        } else if text.hasPrefix("camera:type:") {
            let type = String(text.dropFirst("camera:type:".count))
            Task {
                await self.selectCameraByType(type)
            }
        } else if text == "get:cams" {
            self.broadcastCameraList()
        } else if text.hasPrefix("plug:set:") || text.hasPrefix("plug:toggle:") || text.hasPrefix("plug:delete:") || text.hasPrefix("plug:test:") || text.hasPrefix("livekit:wake") {
            self.handleDirectControlTextCommand(text)
        } else if text.hasPrefix("hub:battery:") {
            let payload = String(text.dropFirst("hub:battery:".count))
            let parts = payload.components(separatedBy: ":")
            if let batFloat = Float(parts[0]) {
                self.remoteBatteryLevel = batFloat
                MycoStore.shared?.db.environmentConfig.cameraBatteryLevel = batFloat
                MycoStore.shared?.db.environmentConfig.cameraBatteryLastUpdated = Date()
            }
            if parts.count > 1 {
                let isChg = (parts[1] == "1")
                self.remoteIsCharging = isChg
                MycoStore.shared?.db.environmentConfig.cameraIsCharging = isChg
            }
            self.isRemoteHubOnline = true
            self.lastRemoteHubHeartbeat = Date()
        } else if text.hasPrefix("hub:heartbeat:") {
            let payload = String(text.dropFirst("hub:heartbeat:".count))
            let comps = payload.components(separatedBy: ":")
            self.isRemoteHubOnline = true
            self.lastRemoteHubHeartbeat = Date()
            if comps.count > 1 {
                self.isRemoteHubAutopilotActive = (comps[1] == "1")
            }
            if comps.count >= 4, let batFloat = Float(comps[2]) {
                self.remoteBatteryLevel = batFloat
                let isChg = (comps[3] == "1")
                self.remoteIsCharging = isChg
                MycoStore.shared?.db.environmentConfig.cameraBatteryLevel = batFloat
                MycoStore.shared?.db.environmentConfig.cameraIsCharging = isChg
                MycoStore.shared?.db.environmentConfig.cameraBatteryLastUpdated = Date()
                if comps.count > 4 {
                    self.lastRemoteHubLogMessage = comps[4...].joined(separator: ":")
                }
            } else if comps.count > 2 {
                self.lastRemoteHubLogMessage = comps[2...].joined(separator: ":")
            }
        } else if text == "hub:status:request" {
            self.broadcastHubHeartbeat()
        } else if text.hasPrefix("timelapse:start:") {
            let remainder = String(text.dropFirst("timelapse:start:".count))
            let comps = remainder.components(separatedBy: ":")
            let interval = Int(comps[0]) ?? 2
            let camId = comps.count > 1 ? comps[1] : ""
            self.startTimelapse(intervalMinutes: interval, cameraId: camId.isEmpty ? nil : camId)
        } else if text.hasPrefix("timelapse:stop") {
            let remainder = String(text.dropFirst("timelapse:stop".count))
            if remainder.hasPrefix(":") {
                let camId = String(remainder.dropFirst())
                self.stopTimelapse(forCameraId: camId)
            } else {
                self.stopTimelapse()
            }
        } else if text.hasPrefix("timelapse:autoflash:") {
            let val = String(text.dropFirst("timelapse:autoflash:".count))
            self.timelapseAutoFlashIfLampOff = (val == "1")
            self.broadcastTimelapseStatus()
        } else if text.hasPrefix("timelapse:status:") {
            let remainder = String(text.dropFirst("timelapse:status:".count))
            let parts = remainder.components(separatedBy: ":")
            if parts.count >= 3 {
                let isRunning = (parts[0] == "1")
                let interval = Int(parts[1]) ?? 2
                let count = Int(parts[2]) ?? 0
                self.isRemoteTimelapseRunning = isRunning
                self.remoteTimelapseIntervalMinutes = interval
                self.remoteTimelapseFramesCount = count
                UserDefaults.standard.set(isRunning, forKey: "mycolab_viewer_remote_timelapse_active")
                UserDefaults.standard.set(interval, forKey: "mycolab_viewer_remote_timelapse_interval")
                if parts.count >= 4 {
                    self.remoteTimelapseAutoFlashIfLampOff = (parts[3] == "1")
                }
                if isRunning && parts.count >= 5 && !parts[4].isEmpty {
                    let camIds = parts[4].components(separatedBy: ",").filter { !$0.isEmpty }
                    self.remoteActiveTimelapseCameraIDs = Set(camIds)
                    if let first = camIds.first, self.remoteTimelapseCameraID.isEmpty {
                        self.remoteTimelapseCameraID = first
                    }
                } else if !isRunning {
                    self.remoteActiveTimelapseCameraIDs.removeAll()
                }
                if isRunning && self.remoteTimelapseStartTime == nil {
                    self.remoteTimelapseStartTime = Date()
                } else if !isRunning {
                    self.remoteTimelapseStartTime = nil
                }
            }
        } else if text == "timelapse:status:request" {
            self.broadcastTimelapseStatus()
        } else if text == "optical:scan" || text == "cmd:optical:scan" {
            if self.currentRole == .broadcaster || self.localVideoTrack != nil {
                Task {
                    _ = await MycoOpticalHygrometerManager.shared.triggerScanAndReact()
                }
            }
        } else if text.hasPrefix("optical:reading:") {
            let payload = String(text.dropFirst("optical:reading:".count))
            let comps = payload.components(separatedBy: ":")
            if comps.count >= 2, let hum = Double(comps[0]) {
                let temp = Double(comps[1])
                let reading = OpticalMeterReading(
                    humidityPct: hum,
                    temperatureC: temp,
                    confidence: 0.95,
                    recognizedRawText: "Kweekcamera Onboard AI",
                    sourceLens: "Kweekcamera AI",
                    wasHumidifierTriggered: false
                )
                MycoOpticalHygrometerManager.shared.handleReceivedRemoteReading(reading)
            }
        } else if text == "sensor:status:request" || text == "sensor:request" {
            if self.currentRole == .broadcaster {
                MycoSensorIntelligenceManager.shared.broadcastTelemetryToViewers()
            }
        } else if text.hasPrefix("sensor:telemetry:") {
            let jsonStr = String(text.dropFirst("sensor:telemetry:".count))
            MycoSensorIntelligenceManager.shared.handleIncomingRemoteTelemetry(jsonString: jsonStr)
        } else if text.contains("\"cams_sync\"") {
            if let jsonData = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                if let activeId = json["activeId"] as? String {
                    self.remoteActiveCameraID = activeId
                }
                if let activeLabel = json["activeLabel"] as? String {
                    self.remoteActiveCameraLabel = activeLabel
                }
                if let camsList = json["cams"] as? [[String: String]] {
                    self.remoteAvailableCameras = camsList.compactMap { dict in
                        guard let id = dict["id"], let name = dict["name"], let shortLabel = dict["short"] else { return nil }
                        return RemoteCameraInfo(id: id, name: name, shortLabel: shortLabel)
                    }
                }
            }
        }
    }
}

// MARK: - SwiftUI View
public struct LiveKitStreamView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var store: MycoStore
    @StateObject private var manager = LiveKitStreamManager.shared
    @ObservedObject private var pairingManager = MycoCamPairingManager.shared
    @ObservedObject private var sensorManager = MycoSensorIntelligenceManager.shared
    @ObservedObject private var opticalManager = MycoOpticalHygrometerManager.shared
    @State private var selectedRole: LiveKitRole = .viewer
    @State private var showSettings = false
    @State private var showLiveKitKeySheet: Bool = false
    @State private var isControlsVisible: Bool = true
    @State private var videoLayoutMode: VideoView.LayoutMode = .fit
    @State private var framingToast: String? = nil
    @State private var zoomScale: CGFloat = 1.0
    @State private var gestureZoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var gesturePan: CGSize = .zero
    @State private var isRotated90: Bool = false
    @State private var showTimelapseSheet: Bool = false
    @State private var showGallerySheet: Bool = false
    @State private var showSensorSheet: Bool = false
    @State private var showOpticalHygrometerSheet: Bool = false
    @State private var showConfirmCloseCamera: Bool = false
    @State private var showPairingQR: Bool = false

    // Tap-To-Focus State & Reticle
    @State private var tapFocusPoint: CGPoint? = nil
    @State private var showFocusReticle: Bool = false
    @State private var focusTimer: AnyCancellable? = nil

    public init() {}

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    private var hasActiveVideoTrack: Bool {
        if selectedRole == .broadcaster {
            return manager.localVideoTrack != nil
        } else {
            return manager.remoteVideoTrack != nil
        }
    }

    private func t(nl: String, en: String) -> String {
        store.isEnglish ? en : nl
    }

    private func localizedStatusMessage(_ msg: String) -> String {
        guard store.isEnglish else { return msg }
        switch msg {
        case "Standby": return "Standby"
        case "Standby (Wachten op kijker...)": return "Standby (Waiting for viewer...)"
        case "Verbinden met LiveKit Cloud...": return "Connecting to LiveKit Cloud..."
        case "Fout bij genereren van authenticatie-token.": return "Error generating authentication token."
        case "Camera initialiseren...": return "Initializing camera..."
        case "Live HD Uitzending Actief (WebRTC)": return "Live HD Broadcast Active (WebRTC)"
        case "Verbonden als kijker. Wachten op videobeeld...": return "Connected as viewer. Waiting for video feed..."
        case "Gestopt": return "Stopped"
        case "Live HD Beeld (WebRTC)": return "Live HD Feed (WebRTC)"
        case "Verbonden (LiveKit HD)": return "Connected (LiveKit HD)"
        case "Opnieuw verbinden met LiveKit...": return "Reconnecting to LiveKit..."
        case "Verbinding verbroken": return "Connection lost"
        default:
            if msg.hasPrefix("Verbindingsfout: ") {
                return msg.replacingOccurrences(of: "Verbindingsfout: ", with: "Connection error: ")
            }
            return msg
        }
    }

    private func localizedToast(_ toast: String) -> String {
        guard store.isEnglish else { return toast }
        if toast.contains("Foto opgeslagen") {
            return "Photo saved to your iPhone Photos library!"
        } else if toast.contains("spaarstand") {
            return "Grow camera screen set to sleep mode 🌙"
        } else if toast.contains("gewekt") {
            return "Grow camera screen woken ☀️"
        }
        return toast
    }

    private func handleTapToFocus(at location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        // If controls were hidden, tap also brings them back
        if !isControlsVisible {
            withAnimation(.easeInOut(duration: 0.22)) {
                isControlsVisible = true
            }
        }

        // Calculate normalized coordinates taking current zoomScale, panOffset and rotation into account
        let effectiveZoom = max(1.0, zoomScale * gestureZoom)
        let totalPanX = panOffset.width + gesturePan.width
        let totalPanY = panOffset.height + gesturePan.height

        let relX = (location.x - (size.width / 2.0 + totalPanX)) / effectiveZoom + (size.width / 2.0)
        let relY = (location.y - (size.height / 2.0 + totalPanY)) / effectiveZoom + (size.height / 2.0)

        var targetX = relX
        var targetY = relY
        if isRotated90 {
            let cx = size.width / 2.0
            let cy = size.height / 2.0
            let dx = relX - cx
            let dy = relY - cy
            targetX = cx + dy
            targetY = cy - dx
        }

        let normX = max(0.0, min(1.0, targetX / size.width))
        let normY = max(0.0, min(1.0, targetY / size.height))

        tapFocusPoint = location
        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
            showFocusReticle = true
        }

        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()

        manager.sendFocusCommand(x: normX, y: normY)

        // Sla het precieze focuspunt direct op voor automatische optische hygrometer metingen
        Task { @MainActor in
            MycoOpticalHygrometerManager.shared.config.customFocusPoint = CGPoint(x: normX, y: normY)
            MycoOpticalHygrometerManager.shared.saveConfig()
        }

        focusTimer?.cancel()
        focusTimer = Timer.publish(every: 1.6, on: .main, in: .common)
            .autoconnect()
            .sink { [self] _ in
                withAnimation(.easeOut(duration: 0.35)) {
                    self.showFocusReticle = false
                }
                self.focusTimer?.cancel()
                self.focusTimer = nil
            }
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 1. Video Feed Display (with Interactive Pinch-to-Zoom, Pan & 90° Rotated Fullscreen)
            Group {
                if selectedRole == .broadcaster {
                    if let track = manager.localVideoTrack {
                        SwiftUIVideoView(track, layoutMode: videoLayoutMode)
                            .scaleEffect(max(1.0, min(5.0, zoomScale * gestureZoom)))
                            .offset(
                                x: panOffset.width + gesturePan.width,
                                y: panOffset.height + gesturePan.height
                            )
                            .rotationEffect(.degrees(isRotated90 ? 90 : 0))
                            .ignoresSafeArea()
                    } else {
                        cameraStandbyPlaceholder
                    }
                } else {
                    if let p2pFrame = MycoCamStreamManager.shared.receivedFrame {
                        Image(uiImage: p2pFrame)
                            .resizable()
                            .aspectRatio(contentMode: videoLayoutMode == .fit ? .fit : .fill)
                            .scaleEffect(max(1.0, min(5.0, zoomScale * gestureZoom)))
                            .offset(
                                x: panOffset.width + gesturePan.width,
                                y: panOffset.height + gesturePan.height
                            )
                            .rotationEffect(.degrees(isRotated90 ? 90 : 0))
                            .ignoresSafeArea()
                    } else if let track = manager.remoteVideoTrack {
                        SwiftUIVideoView(track, layoutMode: videoLayoutMode)
                            .scaleEffect(max(1.0, min(5.0, zoomScale * gestureZoom)))
                            .offset(
                                x: panOffset.width + gesturePan.width,
                                y: panOffset.height + gesturePan.height
                            )
                            .rotationEffect(.degrees(isRotated90 ? 90 : 0))
                            .ignoresSafeArea()
                    } else {
                        viewerWaitingPlaceholder
                    }
                }
            }

            // 2. Fullscreen Interactive Layer (Tap-to-Focus, Pinch-to-Zoom, Pan & Layout Mode)
            if hasActiveVideoTrack {
                GeometryReader { videoGeo in
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { val in
                                        gestureZoom = val
                                    }
                                    .onEnded { val in
                                        zoomScale = max(1.0, min(5.0, zoomScale * val))
                                        gestureZoom = 1.0
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { val in
                                        if zoomScale > 1.05 {
                                            gesturePan = val.translation
                                        }
                                    }
                                    .onEnded { val in
                                        if zoomScale > 1.05 {
                                            panOffset.width += val.translation.width
                                            panOffset.height += val.translation.height
                                            gesturePan = .zero
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        if zoomScale > 1.05 || panOffset != .zero || isRotated90 {
                                            zoomScale = 1.0
                                            panOffset = .zero
                                            isRotated90 = false
                                            framingToast = t(nl: "Hersteld naar 1.0x", en: "Reset to 1.0x")
                                        } else {
                                            videoLayoutMode = (videoLayoutMode == .fill) ? .fit : .fill
                                            framingToast = (videoLayoutMode == .fit) ? t(nl: "Volledig camerabeeld (Passend)", en: "Full camera sensor (Fit)") : t(nl: "Schermvullend beeld (Vullend)", en: "Screen fill view (Fill)")
                                        }
                                    }
                                    let gen = UIImpactFeedbackGenerator(style: .medium)
                                    gen.impactOccurred()
                                    Task {
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        withAnimation { self.framingToast = nil }
                                    }
                                }
                            )
                            .onTapGesture { location in
                                handleTapToFocus(at: location, in: videoGeo.size)
                            }

                        // Animated Yellow Camera Autofocus Reticle (only when video is active)
                        if showFocusReticle, let pt = tapFocusPoint {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.yellow, lineWidth: 2.0)
                                    .frame(width: 60, height: 60)
                                    .shadow(color: Color.yellow.opacity(0.85), radius: 5)
                                Circle()
                                    .fill(Color.yellow)
                                    .frame(width: 5, height: 5)
                            }
                            .position(pt)
                            .transition(.scale(scale: 1.25).combined(with: .opacity))
                            .allowsHitTesting(false)
                        }
                    }
                }
                .ignoresSafeArea()
            }

            // 3. OLED Screen Saver (only dim locally if in broadcaster mode)
            if manager.isOledSaverActive && (selectedRole == .broadcaster || manager.currentRole == .broadcaster) {
                oledSaverOverlay
            }

            // 4. Toast notifications (Snapshots & Framing feedback)
            VStack {
                Spacer()
                if let toast = manager.lastSavedSnapshotToast {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundColor(.green)
                        Text(localizedToast(toast))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.green.opacity(0.5), lineWidth: 1))
                    .shadow(radius: 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, isControlsVisible ? 85 : 30)
                } else if let toast = framingToast {
                    HStack(spacing: 8) {
                        Image(systemName: videoLayoutMode == .fit ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                            .foregroundColor(.cyan)
                        Text(toast)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                    .shadow(radius: 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, isControlsVisible ? 85 : 30)
                }
            }
            .zIndex(10)

            // 5. Standard HUD Overlays (Top HUD, Sensor Telemetry Mini HUD, and Bottom Controls)
            if !(manager.isOledSaverActive && selectedRole == .broadcaster) {
                VStack(spacing: 8) {
                    topHUD
                    sensorTelemetryMiniHUD
                    Spacer()
                    lensQuickSelectorBar
                    bottomControlBar
                }
                .padding(.horizontal, MycoDevicePlatform.isCompactWidth ? 8 : 14)
                .padding(.top, MycoDevicePlatform.safeTopPadding)
                .padding(.bottom, MycoDevicePlatform.safeBottomPadding)
                .opacity(isControlsVisible ? 1 : 0)
                .allowsHitTesting(isControlsVisible)
                .animation(.easeInOut(duration: 0.22), value: isControlsVisible)
            }
        }
        .onAppear {
            selectedRole = .viewer
            let targetId = pairingManager.pairedCameraId
            Task {
                await manager.startViewer(cameraId: targetId)
                sensorManager.requestRemoteSensorStatus()
            }
        }
        .onDisappear {
            focusTimer?.cancel()
            focusTimer = nil
            showFocusReticle = false
            tapFocusPoint = nil
        }
        .sheet(isPresented: $showSettings) {
            streamSettingsSheet
        }
        .sheet(isPresented: $showTimelapseSheet) {
            RemoteTimelapseSheet(manager: manager, role: selectedRole, showGallery: $showGallerySheet)
        }
        .sheet(isPresented: $showGallerySheet) {
            TimelapseGallerySheet()
        }
        .sheet(isPresented: $showSensorSheet) {
            MycoSensorInspectionSheet()
        }
        .sheet(isPresented: $showOpticalHygrometerSheet) {
            MycoOpticalHygrometerView()
        }
        .sheet(isPresented: $showPairingQR) {
            CameraPairingQRSheet()
        }
        .alert(store.t(nl: "Kweekcamera Stoppen?", en: "Stop Grow Camera?"), isPresented: $showConfirmCloseCamera) {
            Button(store.t(nl: "Camera Stoppen & Sluiten", en: "Stop Camera & Close"), role: .destructive) {
                dismiss()
            }
            Button(store.t(nl: "Blijf Streamen", en: "Stay Streaming"), role: .cancel) {}
        } message: {
            Text(store.t(
                nl: "Deze iPhone fungeert als actieve kweekcamera in de tent. Weet je zeker dat je de stream wilt beëindigen?",
                en: "This device is acting as the active grow camera in the tent. Are you sure you want to stop the stream?"
            ))
        }
        .interactiveDismissDisabled(selectedRole == .broadcaster)
    }

    // MARK: - Live Sensor & Barometer + Eco-Token Mini-HUD (Viewer & Broadcaster)
    private var sensorTelemetryMiniHUD: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Optical Meter Chip (Replaces 3D Foto)
                Button {
                    showOpticalHygrometerSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "binoculars.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.cyan)
                        if let r = opticalManager.lastReading {
                            Text("\(Int(r.humidityPct))% RV")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            if let temp = r.temperatureC {
                                Text("• \(String(format: "%.1f", temp))°")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        } else {
                            Text(t(nl: "Optische Meter", en: "Optical Meter"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }

                // Barometer chip (only shown if real hardware reading > 0)
                if sensorManager.currentPressureHpa > 0 {
                    Button { showSensorSheet = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: sensorManager.pressureTrend.icon)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(sensorManager.pressureTrend == .stormFront ? .red : .cyan)
                            Text("\(String(format: "%.0f", sensorManager.currentPressureHpa)) hPa")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Placeholders
    private var cameraStandbyPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.3)
            Text(t(nl: "Camera opstarten...", en: "Starting camera..."))
                .font(.headline)
                .foregroundColor(.white)
            Text(localizedStatusMessage(manager.statusMessage))
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    private var viewerWaitingPlaceholder: some View {
        VStack(spacing: 16) {
            if manager.isConnected {
                if manager.isViewerWaitingTooLong {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                    Text(t(nl: "Kweekcamera reageert niet of staat standby", en: "Grow camera not responding or in standby"))
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text(t(
                        nl: "Controleer of de lab-telefoon aan de lader hangt, verbonden is met Wi-Fi en MycoLabs geopend heeft.",
                        en: "Check if the lab phone is plugged in, connected to Wi-Fi, and has MycoLabs open."
                    ))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                    Button {
                        let targetId = pairingManager.pairedCameraId
                            ?? MycoKVS.string(forKey: "mycolab_registered_camera_id")
                        Task {
                            await manager.hardResetAndReconnect(cameraId: targetId)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text(t(nl: "Opnieuw Proberen", en: "Try Again"))
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                } else {
                    ProgressView()
                        .tint(.blue)
                        .scaleEffect(1.4)
                    Text(t(nl: "Wachten op videobeeld...", en: "Waiting for video feed..."))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(t(nl: "De kweekcamera is nog aan het laden of offline.", en: "The grow camera is loading or offline."))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 44))
                    .foregroundColor(.orange)
                Text(t(nl: "Nog niet verbonden", en: "Not connected yet"))
                    .font(.headline)
                    .foregroundColor(.white)
                Text(localizedStatusMessage(manager.statusMessage))
                    .font(.caption)
                    .foregroundColor(.gray)

                Button {
                    let targetId = pairingManager.pairedCameraId
                        ?? MycoKVS.string(forKey: "mycolab_registered_camera_id")
                    Task {
                        await manager.hardResetAndReconnect(cameraId: targetId)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text(t(nl: "Verbinding Maken", en: "Connect"))
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Overlays & HUD
    private var oledSaverOverlay: some View {
        MycoOledStandbyOverlayView(
            isTimelapseRunning: manager.isTimelapseRunning,
            capturedFramesCount: manager.timelapseCapturedFramesCount,
            timelapseIntervalMinutes: manager.timelapseIntervalMinutes,
            autoFlashIfLampOff: manager.timelapseAutoFlashIfLampOff,
            isLampActive: manager.isTorchOn
        ) {
            withAnimation {
                manager.setOledSaver(active: false, notifyPeer: true)
            }
        }
    }

    private var topHUD: some View {
        VStack(spacing: 4) {
            // Main Top Bar: Close Button + Role Badge | [Spacer] | REC Badge | [Spacer] | Tent-Lock + Settings
            HStack(alignment: .center, spacing: 6) {
                // Left: Close Button + Role Badge
                HStack(spacing: 6) {
                    Button {
                        if selectedRole == .broadcaster {
                            showConfirmCloseCamera = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(manager.isConnected ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(selectedRole.localizedName(isEnglish: store.isEnglish))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if manager.isConnected && (manager.remoteVideoTrack != nil || manager.localVideoTrack != nil) {
                            Text(manager.streamQuality.shortTitle)
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(.black)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 0.5)
                                .background(Color.green)
                                .cornerRadius(3)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                }

                Spacer(minLength: 4)

                // Center: Live Timelapse REC Badge (if running)
                if (selectedRole == .viewer && manager.isRemoteTimelapseRunning) || (selectedRole == .broadcaster && manager.isTimelapseRunning) {
                    Button {
                        showTimelapseSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 7, height: 7)
                            Text("REC #\(selectedRole == .viewer ? manager.remoteTimelapseFramesCount : manager.timelapseCapturedFramesCount)")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.35))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.6), lineWidth: 0.8))
                    }
                }

                Spacer(minLength: 4)

                // Right: Tent-Lock + Settings (Guaranteed visible on every device width)
                HStack(spacing: 6) {
                    Button {
                        manager.toggleTentLock()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: manager.isTentLockActive ? "lock.fill" : "lock.open")
                                .font(.system(size: 9, weight: .bold))
                            Text(manager.isTentLockActive ? "Lock" : "Auto")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(manager.isTentLockActive ? .black : .white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 6)
                        .background(manager.isTentLockActive ? MycoTheme.green : Color.white.opacity(0.18))
                        .cornerRadius(14)
                    }

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }

            // Secondary Info Bar: Status message on Left + Battery/Network Capsule on Right
            HStack(spacing: 6) {
                Text(localizedStatusMessage(manager.statusMessage))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)

                if selectedRole == .broadcaster {
                    Button {
                        Task {
                            _ = await opticalManager.triggerScanAndReact()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "binoculars.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.cyan)
                            if let r = opticalManager.lastReading {
                                let tempStr = r.temperatureC != nil ? " • \(String(format: "%.1f", r.temperatureC!))°" : ""
                                Text("\(Int(r.humidityPct))% RV\(tempStr)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            } else {
                                Text("AI Meter")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.cyan.opacity(0.2))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.4), lineWidth: 0.8))
                    }
                }

                Spacer(minLength: 4)

                // Hub Status + Battery + Network Pill
                HStack(spacing: 6) {
                    if selectedRole == .broadcaster {
                        HStack(spacing: 2) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 8))
                                .foregroundColor(.green)
                            Text("Hub")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.green)
                        }
                        if MycoBackgroundHubManager.shared.batteryPercentageInt > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: MycoBackgroundHubManager.shared.batteryIconName)
                                    .font(.system(size: 8))
                                    .foregroundColor(MycoBackgroundHubManager.shared.isCharging ? .green : .white)
                                Text("\(MycoBackgroundHubManager.shared.batteryPercentageInt)%")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        }
                    } else {
                        if manager.isRemoteHubOnline {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                        }
                        if let bat = manager.remoteBatteryPercent {
                            HStack(spacing: 2) {
                                Image(systemName: manager.remoteBatteryIcon)
                                    .font(.system(size: 8))
                                    .foregroundColor(manager.remoteBatteryColor)
                                Text("\(bat)%")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                if manager.remoteIsCharging == true {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }

                    HStack(spacing: 2) {
                        Image(systemName: pairingManager.isCellular ? "antenna.radiowaves.left.and.right" : "wifi")
                            .font(.system(size: 8, weight: .semibold))
                        Text(pairingManager.isCellular ? "4G/5G" : "Wi-Fi")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(pairingManager.isCellular ? .cyan : .green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    @ViewBuilder
    private var lensQuickSelectorBar: some View {
        if selectedRole == .viewer && manager.remoteAvailableCameras.count > 1 {
            HStack(spacing: 8) {
                ForEach(manager.remoteAvailableCameras) { cam in
                    Button {
                        manager.selectRemoteCamera(id: cam.id)
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                    } label: {
                        Text(cam.shortLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor((manager.remoteActiveCameraID == cam.id || manager.remoteActiveCameraLabel == cam.shortLabel) ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background((manager.remoteActiveCameraID == cam.id || manager.remoteActiveCameraLabel == cam.shortLabel) ? Color.yellow : Color.black.opacity(0.65))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                    }
                }
            }
            .padding(.bottom, 2)
        }
    }

    // MARK: - Bottom Control Dock (Native Camera Ergonomics for Portrait & Landscape)
    private var bottomControlBar: some View {
        let isCompact = MycoDevicePlatform.isCompactWidth || isCompactHeight
        let dockBtnSize: CGFloat = isCompact ? 40 : 46
        let dockIconSize: CGFloat = isCompact ? 14 : 17
        let heroRingSize: CGFloat = isCompact ? 52 : 62
        let heroCoreSize: CGFloat = isCompact ? 40 : 50
        let spacing: CGFloat = isCompact ? 10 : 18

        return HStack(spacing: spacing) {
            // 1. Torch / Zaklamp
            Button {
                Task {
                    manager.toggleTorch()
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: manager.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: dockIconSize, weight: .semibold))
                        .foregroundColor(manager.isTorchOn ? .yellow : .white)
                    if !isCompactHeight {
                        Text(t(nl: "Lamp", en: "Light"))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .frame(width: dockBtnSize, height: dockBtnSize)
                .background(manager.isTorchOn ? Color.yellow.opacity(0.25) : Color.white.opacity(0.14))
                .clipShape(Circle())
            }

            // 2. Standby / OLED Nachtstand (Moon) - Automatically hidden if connected camera has no screen (headless/RTSP)
            if selectedRole == .broadcaster || manager.currentRemoteCameraHasScreen {
                Button {
                    if selectedRole == .broadcaster {
                        withAnimation {
                            manager.setOledSaver(active: !manager.isOledSaverActive, notifyPeer: true)
                        }
                    } else {
                        manager.toggleRemoteSleep()
                    }
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                } label: {
                    let isDimmed = (selectedRole == .broadcaster ? manager.isOledSaverActive : manager.isRemoteScreenDimmed)
                    VStack(spacing: 2) {
                        Image(systemName: isDimmed ? "moon.stars.fill" : "moon.stars")
                            .font(.system(size: dockIconSize, weight: .semibold))
                            .foregroundColor(isDimmed ? .yellow : .white)
                        if !isCompactHeight {
                            Text(t(nl: "Standby", en: "Standby"))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                    .frame(width: dockBtnSize, height: dockBtnSize)
                    .background(isDimmed ? Color.yellow.opacity(0.25) : Color.white.opacity(0.14))
                    .clipShape(Circle())
                }
            }

            Spacer(minLength: 4)

            // 3. Shutter / Foto Snapshot Button (Center Hero)
            Button {
                Task {
                    _ = await manager.captureAndSaveSnapshot()
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: isCompact ? 2.5 : 3.5)
                        .frame(width: heroRingSize, height: heroRingSize)
                    if manager.isCapturingSnapshot {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: heroCoreSize, height: heroCoreSize)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: isCompact ? 16 : 19, weight: .bold))
                                    .foregroundColor(.black)
                            )
                    }
                }
            }
            .disabled(manager.isCapturingSnapshot)

            Spacer(minLength: 4)

            // 4. Remote Timelapse Controller (Viewer) vs Koppel QR (Broadcaster)
            if selectedRole == .viewer {
                Button {
                    showTimelapseSheet = true
                } label: {
                    let isRunning = manager.isRemoteTimelapseRunning
                    let count = manager.remoteTimelapseFramesCount
                    VStack(spacing: 2) {
                        Image(systemName: isRunning ? "record.circle.fill" : "timer")
                            .font(.system(size: dockIconSize, weight: .semibold))
                            .foregroundColor(isRunning ? .red : .white)
                        if !isCompactHeight {
                            Text(isRunning ? "\(count)" : t(nl: "Timelapse", en: "Timelapse"))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(isRunning ? .red : .white.opacity(0.75))
                        }
                    }
                    .frame(width: dockBtnSize, height: dockBtnSize)
                    .background(isRunning ? Color.red.opacity(0.3) : Color.white.opacity(0.14))
                    .clipShape(Circle())
                }
            } else {
                Button {
                    showPairingQR = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "qrcode")
                            .font(.system(size: dockIconSize, weight: .semibold))
                            .foregroundColor(.white)
                        if !isCompactHeight {
                            Text(t(nl: "Koppel QR", en: "Pair QR"))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                    .frame(width: dockBtnSize, height: dockBtnSize)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Circle())
                }
            }

            // 5. Video Framing & 90° Rotation
            Menu {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        videoLayoutMode = .fit
                        isRotated90 = false
                        zoomScale = 1.0
                        panOffset = .zero
                    }
                    framingToast = t(nl: "Volledig camerabeeld (Passend)", en: "Full camera sensor (Fit)")
                } label: {
                    Label(t(nl: "Passend (100% Sensor)", en: "Fit (100% Sensor)"), systemImage: "arrow.down.right.and.arrow.up.left")
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        videoLayoutMode = .fill
                        isRotated90 = false
                    }
                    framingToast = t(nl: "Schermvullend beeld (Vullend)", en: "Screen fill view (Fill)")
                } label: {
                    Label(t(nl: "Schermvullend (Fill)", en: "Screen Fill"), systemImage: "arrow.up.left.and.arrow.down.right")
                }

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isRotated90.toggle()
                        zoomScale = 1.0
                        panOffset = .zero
                    }
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    framingToast = isRotated90 ? t(nl: "90° Gekanteld (Volledig scherm)", en: "90° Rotated (Fullscreen)") : t(nl: "Standaard oriëntatie", en: "Default orientation")
                } label: {
                    Label(t(nl: isRotated90 ? "Herstel Oriëntatie" : "Kantel 90° (Volledig scherm)", en: isRotated90 ? "Reset Orientation" : "Rotate 90° (Fullscreen)"), systemImage: "rectangle.landscape.rotate")
                }

                if zoomScale > 1.05 || panOffset != .zero {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            zoomScale = 1.0
                            panOffset = .zero
                        }
                    } label: {
                        Label(t(nl: "Zoom Herstellen (1.0x)", en: "Reset Zoom (1.0x)"), systemImage: "arrow.counterclockwise")
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: isRotated90 ? "rectangle.landscape.rotate" : (videoLayoutMode == .fit ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left"))
                        .font(.system(size: dockIconSize, weight: .semibold))
                        .foregroundColor((isRotated90 || videoLayoutMode == .fill || zoomScale > 1.05) ? .cyan : .white)
                    if !isCompactHeight {
                        Text(isRotated90 ? "90°" : (videoLayoutMode == .fit ? t(nl: "Passend", en: "Fit") : t(nl: "Vullend", en: "Fill")))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .frame(width: dockBtnSize, height: dockBtnSize)
                .background(Color.white.opacity(0.14))
                .clipShape(Circle())
            } primaryAction: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    if isRotated90 {
                        isRotated90 = false
                        videoLayoutMode = .fit
                        framingToast = t(nl: "Passend (Originele verhouding)", en: "Fit (Original aspect)")
                    } else if videoLayoutMode == .fit {
                        videoLayoutMode = .fill
                        framingToast = t(nl: "Schermvullend (Vullend)", en: "Screen fill view (Fill)")
                    } else {
                        isRotated90 = true
                        videoLayoutMode = .fit
                        framingToast = t(nl: "90° Gekanteld (Volledig scherm)", en: "90° Rotated (Fullscreen)")
                    }
                }
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation { self.framingToast = nil }
                }
            }

            // 6. Direct Smart Hardware Controls (Tuya Plugs / Pi Relay)
            let controllableDevices = store.db.smartDevices.filter { $0.deviceType != "Sensor" }
            if !controllableDevices.isEmpty {
                Menu {
                    Text(t(nl: "Lab Hardware Schakelaars", en: "Lab Hardware Controls"))
                    Divider()
                    ForEach(controllableDevices) { dev in
                        Button {
                            store.toggleSmartDevice(id: dev.id, trigger: "LiveKit Direct Stream Control", relayToHub: true)
                        } label: {
                            Label(
                                "\(dev.name): \(dev.isOn ? t(nl: "AAN (Tik voor UIT)", en: "ON (Tap for OFF)") : t(nl: "UIT (Tik voor AAN)", en: "OFF (Tap for ON)"))",
                                systemImage: dev.isOn ? "powerplug.fill" : "powerplug"
                            )
                        }
                    }
                } label: {
                    let anyOn = controllableDevices.contains { $0.isOn }
                    VStack(spacing: 2) {
                        Image(systemName: anyOn ? "powerplug.fill" : "powerplug")
                            .font(.system(size: dockIconSize, weight: .semibold))
                            .foregroundColor(anyOn ? MycoTheme.green : .white)
                        if !isCompactHeight {
                            Text(t(nl: "Hardware", en: "Hardware"))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }
                    .frame(width: dockBtnSize, height: dockBtnSize)
                    .background(anyOn ? MycoTheme.green.opacity(0.25) : Color.white.opacity(0.14))
                    .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, isCompactHeight ? 16 : 22)
        .padding(.vertical, isCompactHeight ? 8 : 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 4)
    }

    private var streamSettingsSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text(t(nl: "Apparaat Rol", en: "Device Role"))) {
                    HStack(spacing: 12) {
                        Image(systemName: MycoDevicePlatform.isMac ? "laptopcomputer.and.iphone" : "eye.circle.fill")
                            .font(.title3)
                            .foregroundColor(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t(nl: "Live Monitor (Meekijken & Bedienen)", en: "Live Monitor (Viewer & Remote Control)"))
                                .font(.subheadline.bold())
                            Text(t(
                                nl: "Kijk live mee en bedien de verlichting, het scherm (OLED Spaarstand), de timelapse en slimme stekkers van je kweekcamera op afstand.",
                                en: "Watch the live feed and remotely control the light, OLED standby screen, timelapse, and smart plugs of your grow camera."
                            ))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text(t(nl: "Beeldweergave", en: "Video Framing"))) {
                    Picker(t(nl: "Modus", en: "Mode"), selection: $videoLayoutMode) {
                        Text(t(nl: "Passend (100% camerasensor)", en: "Fit (100% camera sensor)")).tag(VideoView.LayoutMode.fit)
                        Text(t(nl: "Schermvullend (Zoom)", en: "Fill (Screen zoom)")).tag(VideoView.LayoutMode.fill)
                    }
                    .pickerStyle(.segmented)
                }

                if selectedRole == .viewer && !manager.remoteAvailableCameras.isEmpty {
                    Section(header: Text(t(nl: "Kweekcamera Lens Selecteren", en: "Select Grow Camera Lens"))) {
                        ForEach(manager.remoteAvailableCameras) { cam in
                            Button {
                                manager.selectRemoteCamera(id: cam.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cam.name)
                                            .foregroundColor(.primary)
                                        Text(cam.shortLabel)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    if manager.remoteActiveCameraID == cam.id || manager.remoteActiveCameraLabel == cam.shortLabel {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section(header: Text(t(nl: "Kweekcamera & Timelapse Batterij", en: "Grow Camera & Timelapse Battery"))) {
                    if selectedRole == .viewer {
                        if let bat = manager.remoteBatteryPercent {
                            HStack {
                                Label(t(nl: "Batterijniveau Camera", en: "Camera Battery Level"), systemImage: manager.remoteBatteryIcon)
                                    .foregroundColor(manager.remoteBatteryColor)
                                Spacer()
                                Text("\(bat)%")
                                    .font(.system(.body, design: .monospaced).bold())
                            }
                            HStack {
                                Text(t(nl: "Oplaadstatus", en: "Charging Status"))
                                Spacer()
                                HStack(spacing: 5) {
                                    if manager.remoteIsCharging == true {
                                        Image(systemName: "bolt.fill").foregroundColor(.green)
                                        Text(t(nl: "Aan de lader (Opladen) ⚡", en: "Charging (Plugged in) ⚡"))
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "battery.25").foregroundColor(.orange)
                                        Text(t(nl: "Op batterij (Loopt leeg)", en: "On Battery (Draining)"))
                                            .foregroundColor(.orange)
                                    }
                                }
                                .font(.caption.bold())
                            }
                        } else {
                            Text(t(nl: "Batterijstatus wordt opgehaald...", en: "Fetching battery status..."))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else {
                        HStack {
                            Label(t(nl: "Lokale Batterij", en: "Local Battery"), systemImage: MycoBackgroundHubManager.shared.batteryIconName)
                                .foregroundColor(MycoBackgroundHubManager.shared.isCharging ? .green : .primary)
                            Spacer()
                            Text("\(MycoBackgroundHubManager.shared.batteryPercentageInt)%")
                                .font(.system(.body, design: .monospaced).bold())
                        }
                        HStack {
                            Text(t(nl: "Oplaadstatus", en: "Charging Status"))
                            Spacer()
                            Text(MycoBackgroundHubManager.shared.isCharging ? t(nl: "Aan de lader (Opladen) ⚡", en: "Charging ⚡") : t(nl: "Op batterij (Niet aangesloten)", en: "On Battery"))
                                .foregroundColor(MycoBackgroundHubManager.shared.isCharging ? .green : .orange)
                                .font(.caption.bold())
                        }
                    }
                }

                Section(header: Text(t(nl: "LiveKit Cloud Server & Sleutels", en: "LiveKit Cloud Server & Keys"))) {
                    Button {
                        showLiveKitKeySheet = true
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t(nl: "LiveKit Sleutels Wijzigen", en: "Change LiveKit Keys"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                Text(LiveKitTokenGenerator.currentServerUrl)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section(header: Text(t(nl: "Kwaliteit & Resolutie", en: "Quality & Resolution"))) {
                    Picker(t(nl: "Stream Kwaliteit", en: "Stream Quality"), selection: $manager.streamQuality) {
                        ForEach(StreamQualityPreset.allCases) { preset in
                            HStack {
                                Image(systemName: preset.icon)
                                Text(preset.title)
                            }.tag(preset)
                        }
                    }

                    HStack {
                        Text(t(nl: "Resolutiebehoud", en: "Resolution Priority"))
                        Spacer()
                        Text(t(nl: "Actief (Geen kwaliteitsverlies)", en: "Active (No resolution loss)"))
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }

                    HStack {
                        Text(t(nl: "Foto & Snapshot Kwaliteit", en: "Photo & Snapshot Quality"))
                        Spacer()
                        Text(t(nl: "100% Origineel Sensor / Lossless", en: "100% Original Sensor / Lossless"))
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                }

                Section(header: Text(t(nl: "Koppeling & Status", en: "Pairing & Status"))) {
                    HStack {
                        Text(t(nl: "Kamer ID", en: "Room ID"))
                        Spacer()
                        Text(manager.currentRoomName)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text(t(nl: "Gekoppelde Camera", en: "Paired Camera"))
                        Spacer()
                        Text(pairingManager.pairedCameraName ?? t(nl: "Geen", en: "None"))
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle(t(nl: "LiveKit Stream Info", en: "LiveKit Stream Info"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t(nl: "Sluit", en: "Close")) {
                        showSettings = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}


// MARK: - Remote Timelapse Control Sheet (Viewer & Broadcaster)
public struct RemoteTimelapseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MycoStore
    @ObservedObject var manager: LiveKitStreamManager
    let role: LiveKitRole
    @Binding var showGallery: Bool

    @State private var selectedInterval: Int = 2
    let intervalOptions: [Int] = [1, 2, 5, 10, 15, 30, 60]

    private var isRunning: Bool {
        role == .viewer ? manager.isRemoteTimelapseRunning : manager.isTimelapseRunning
    }

    private var frameCount: Int {
        role == .viewer ? manager.remoteTimelapseFramesCount : manager.timelapseCapturedFramesCount
    }

    private var activeInterval: Int {
        role == .viewer ? manager.remoteTimelapseIntervalMinutes : manager.timelapseIntervalMinutes
    }

    private func t(nl: String, en: String) -> String {
        store.isEnglish ? en : nl
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Status Header Card
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isRunning ? Color.red : Color.gray.opacity(0.5))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(isRunning ? Color.red.opacity(0.5) : Color.clear, lineWidth: 6)
                                    .scaleEffect(isRunning ? 1.4 : 1.0)
                            )
                        Text(isRunning ? t(nl: "OPNAME ACTIEF OP KWEEKCAMERA", en: "RECORDING ACTIVE ON GROW CAMERA") : t(nl: "TIMELAPSE STANDBY", en: "TIMELAPSE STANDBY"))
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(isRunning ? .red : .gray)
                    }

                    if isRunning {
                        Text("\(frameCount)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(t(nl: "foto's vastgelegd (elke \(activeInterval) minuten)", en: "photos captured (every \(activeInterval) minutes)"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 40))
                            .foregroundColor(MycoTheme.green.opacity(0.8))
                        Text(t(nl: "Start een automatische timelapse fotoserie op de kweekcamera om paddenstoelengroei vast te leggen.", en: "Start an automatic timelapse photo series on the grow camera to record mushroom flushes."))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(isRunning ? Color.red.opacity(0.12) : Color.white.opacity(0.06))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isRunning ? Color.red.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1))

                // Interval Selection (Disabled while running)
                VStack(alignment: .leading, spacing: 10) {
                    Text(t(nl: "Opname Interval", en: "Capture Interval"))
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .textCase(.uppercase)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(intervalOptions, id: \.self) { min in
                                Button {
                                    selectedInterval = min
                                } label: {
                                    HStack(spacing: 2) {
                                        Text("\(min)")
                                            .font(.system(size: 15, weight: .bold))
                                        Text("m")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundColor(selectedInterval == min ? .black : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(selectedInterval == min ? MycoTheme.green : Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedInterval == min ? MycoTheme.green : Color.white.opacity(0.15), lineWidth: 1)
                                    )
                                }
                                .disabled(isRunning)
                            }
                        }
                    }
                }

                // Camera Selection for Timelapse
                if (role == .viewer ? manager.remoteAvailableCameras.count : manager.availableCameras.count) > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t(nl: "Timelapse Camera", en: "Timelapse Camera"))
                            .font(.caption.bold())
                            .foregroundColor(.gray)
                            .textCase(.uppercase)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // Multi-Cam Optie: Alle Camera's (Kweek, Tent en AI Sensor)
                                let isAllSelected = (role == .viewer ? (manager.remoteTimelapseCameraID.isEmpty || manager.remoteTimelapseCameraID == "all") : (manager.timelapseCameraID.isEmpty || manager.timelapseCameraID == "all"))
                                Button {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    if role == .viewer {
                                        manager.remoteTimelapseCameraID = "all"
                                        UserDefaults.standard.set("all", forKey: "mycolab_viewer_remote_timelapse_camera_id")
                                    } else {
                                        manager.timelapseCameraID = "all"
                                        UserDefaults.standard.set("all", forKey: "mycolab_stream_timelapse_camera_id")
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        if manager.isTimelapseRunning(for: "all") {
                                            Circle().fill(Color.red).frame(width: 7, height: 7)
                                        } else {
                                            Image(systemName: "camera.on.rectangle.fill")
                                                .font(.system(size: 11))
                                        }
                                        Text(t(nl: "Alle Camera's", en: "All Cameras"))
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(isAllSelected ? .black : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(isAllSelected ? MycoTheme.green : (manager.isTimelapseRunning(for: "all") ? Color.red.opacity(0.25) : Color.white.opacity(0.1)))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isAllSelected ? MycoTheme.green : Color.white.opacity(0.15), lineWidth: 1)
                                    )
                                }

                                if role == .viewer {
                                    let currentCamId = manager.remoteTimelapseCameraID.isEmpty ? manager.remoteActiveCameraID : manager.remoteTimelapseCameraID
                                    ForEach(manager.remoteAvailableCameras) { cam in
                                        let isSelected = currentCamId == cam.id
                                        Button {
                                            let gen = UIImpactFeedbackGenerator(style: .light)
                                            gen.impactOccurred()
                                            manager.remoteTimelapseCameraID = cam.id
                                            UserDefaults.standard.set(cam.id, forKey: "mycolab_viewer_remote_timelapse_camera_id")
                                            manager.selectRemoteCamera(id: cam.id)
                                        } label: {
                                            let isCamRec = manager.isTimelapseRunning(for: cam.id)
                                            HStack(spacing: 4) {
                                                if isCamRec {
                                                    Circle().fill(Color.red).frame(width: 7, height: 7)
                                                } else {
                                                    Image(systemName: "camera.fill")
                                                        .font(.system(size: 11))
                                                }
                                                Text(cam.shortLabel)
                                                    .font(.system(size: 13, weight: .bold))
                                                if isCamRec {
                                                    Text("REC")
                                                        .font(.system(size: 8, weight: .black))
                                                        .foregroundColor(.red)
                                                }
                                            }
                                            .foregroundColor(isSelected ? .black : (isCamRec ? .red : .white))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(isSelected ? MycoTheme.green : (isCamRec ? Color.red.opacity(0.2) : Color.white.opacity(0.1)))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(isSelected ? MycoTheme.green : Color.white.opacity(0.15), lineWidth: 1)
                                            )
                                        }
                                    }
                                } else {
                                    let currentCamId = manager.timelapseCameraID.isEmpty ? manager.selectedCameraID : manager.timelapseCameraID
                                    ForEach(manager.availableCameras) { cam in
                                        let isSelected = currentCamId == cam.id
                                        Button {
                                            let gen = UIImpactFeedbackGenerator(style: .light)
                                            gen.impactOccurred()
                                            manager.timelapseCameraID = cam.id
                                            UserDefaults.standard.set(cam.id, forKey: "mycolab_stream_timelapse_camera_id")
                                            Task {
                                                await manager.selectCamera(id: cam.id)
                                            }
                                        } label: {
                                            let isCamRec = manager.isTimelapseRunning(for: cam.id)
                                            HStack(spacing: 4) {
                                                if isCamRec {
                                                    Circle().fill(Color.red).frame(width: 7, height: 7)
                                                } else {
                                                    Image(systemName: "camera.fill")
                                                        .font(.system(size: 11))
                                                }
                                                Text(cam.shortLabel)
                                                    .font(.system(size: 13, weight: .bold))
                                                if isCamRec {
                                                    Text("REC")
                                                        .font(.system(size: 8, weight: .black))
                                                        .foregroundColor(.red)
                                                }
                                            }
                                            .foregroundColor(isSelected ? .black : (isCamRec ? .red : .white))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(isSelected ? MycoTheme.green : (isCamRec ? Color.red.opacity(0.2) : Color.white.opacity(0.1)))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(isSelected ? MycoTheme.green : Color.white.opacity(0.15), lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Auto-Flash & AI Vision Scan Toggles for Remote/Local Timelapse
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "bolt.badge.automatic.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t(nl: "Flits automatisch in het donker", en: "Auto-flash in the dark"))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Text(t(nl: "Gebruikt zaklamp/flits op de kweekcamera als de lamp uitstaat", en: "Uses flash on the grow camera when grow light is off"))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { role == .viewer ? manager.remoteTimelapseAutoFlashIfLampOff : manager.timelapseAutoFlashIfLampOff },
                            set: { newVal in manager.setRemoteOrLocalTimelapseAutoFlash(newVal) }
                        ))
                        .labelsHidden()
                        .tint(.yellow)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t(nl: "Draait 24/7 door op de achtergrond", en: "Keeps running 24/7 in the background"))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Text(t(nl: "Timelapse-opname gaat 24/7 continu door", en: "Timelapse recording continues 24/7 continuously"))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                }

                // Instant Remote Snapshot Buttons (Normal + Flash)
                HStack(spacing: 10) {
                    Button {
                        Task {
                            _ = await manager.captureAndSaveSnapshot(withFlash: false)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                            Text(t(nl: "Losse Foto", en: "Single Photo"))
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(12)
                    }

                    Button {
                        Task {
                            _ = await manager.captureAndSaveSnapshot(withFlash: true)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                            Text(t(nl: "Foto met Flits", en: "Flash Photo"))
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.yellow.opacity(0.18))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.35), lineWidth: 1))
                    }
                }

                // Main Start / Stop Action Button per selected camera
                let chosenCamId: String = {
                    if role == .viewer {
                        return manager.remoteTimelapseCameraID.isEmpty ? "wide" : manager.remoteTimelapseCameraID
                    } else {
                        return manager.timelapseCameraID.isEmpty ? "wide" : manager.timelapseCameraID
                    }
                }()
                let isCurrentCamRunning = isRunning && manager.isTimelapseRunning(for: chosenCamId)
                let activeCamLabel: String = {
                    if chosenCamId == "all" { return t(nl: "Alle Camera's", en: "All Cameras") }
                    if role == .viewer {
                        return manager.remoteAvailableCameras.first(where: { $0.id == chosenCamId })?.shortLabel ?? (chosenCamId == "wide" ? "1.0x" : (chosenCamId == "ultrawide" ? "0.5x" : (chosenCamId == "telephoto" ? "3.0x" : chosenCamId)))
                    } else {
                        return manager.availableCameras.first(where: { $0.id == chosenCamId })?.shortLabel ?? chosenCamId
                    }
                }()

                VStack(spacing: 10) {
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                        if isCurrentCamRunning || isRunning {
                            manager.stopTimelapse(forCameraId: chosenCamId)
                        } else {
                            manager.startTimelapse(intervalMinutes: selectedInterval, cameraId: chosenCamId)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: (isCurrentCamRunning || isRunning) ? "stop.fill" : "play.fill")
                            Text((isCurrentCamRunning || isRunning)
                                ? t(nl: "Stop Timelapse (\(activeCamLabel))", en: "Stop Timelapse (\(activeCamLabel))")
                                : t(nl: "Start Timelapse voor \(activeCamLabel)", en: "Start Timelapse on \(activeCamLabel)"))
                                .fontWeight(.bold)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background((isCurrentCamRunning || isRunning) ? Color.red : MycoTheme.green)
                        .cornerRadius(16)
                        .shadow(color: ((isCurrentCamRunning || isRunning) ? Color.red : MycoTheme.green).opacity(0.4), radius: 8, y: 3)
                    }

                    if isRunning && (role == .viewer ? manager.remoteActiveTimelapseCameraIDs.count > 1 : manager.activeTimelapseCameraIDs.count > 1) {
                        Button {
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                            manager.stopTimelapse()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.circle.fill")
                                Text(t(nl: "Stop Alle Timelapses tegelijk", en: "Stop All Timelapses at once"))
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }
                }

                // Open Gallery Button
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showGallery = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.stack")
                        Text(t(nl: "Bekijk Timelapse Galerij (\(store.db.timelapsePhotos.count) foto's)", en: "View Timelapse Gallery (\(store.db.timelapsePhotos.count) photos)"))
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(MycoTheme.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MycoTheme.blue.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.blue.opacity(0.25), lineWidth: 1))
                }

                Spacer()
            }
            .padding(20)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(t(nl: "Timelapse Kweekcamera", en: "Grow Camera Timelapse"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t(nl: "Klaar", en: "Done")) {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .presentationDetents([.fraction(0.55), .medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            if isRunning {
                selectedInterval = activeInterval
            }
        }
    }
}

// MARK: - UNIFIED OLED STANDBY OVERLAY VIEW (Camera & Viewer Sleep Mode)
public struct MycoOledStandbyOverlayView: View {
    @EnvironmentObject private var store: MycoStore
    @ObservedObject private var hubManager = MycoBackgroundHubManager.shared
    @ObservedObject private var sensorManager = MycoSensorIntelligenceManager.shared
    
    let isTimelapseRunning: Bool
    let capturedFramesCount: Int
    let timelapseIntervalMinutes: Int
    let autoFlashIfLampOff: Bool
    let isLampActive: Bool
    let onWake: () -> Void
    
    public init(
        isTimelapseRunning: Bool = false,
        capturedFramesCount: Int = 0,
        timelapseIntervalMinutes: Int = 2,
        autoFlashIfLampOff: Bool = true,
        isLampActive: Bool = false,
        onWake: @escaping () -> Void
    ) {
        self.isTimelapseRunning = isTimelapseRunning
        self.capturedFramesCount = capturedFramesCount
        self.timelapseIntervalMinutes = timelapseIntervalMinutes
        self.autoFlashIfLampOff = autoFlashIfLampOff
        self.isLampActive = isLampActive
        self.onWake = onWake
    }
    
    private func formattedTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: store.isEnglish ? "en_US" : "nl_NL")
        df.dateFormat = "EEEE d MMMM"
        return df.string(from: date).capitalized
    }
    
    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 14) {
                    // 1. Big OLED Clock & Date
                    VStack(spacing: 2) {
                        Text(formattedTime(context.date))
                            .font(.system(size: 56, weight: .thin, design: .rounded))
                            .foregroundColor(.white.opacity(0.48))
                            .monospacedDigit()
                        
                        Text(formattedDate(context.date))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.bottom, 4)
                    
                    // 2. Unified Status Header
                    VStack(spacing: 5) {
                        HStack(spacing: 6) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 14))
                                .foregroundColor(MycoTheme.blue.opacity(0.75))
                            Text(store.t(nl: "MycoCam Draait (OLED Spaarstand)", en: "MycoCam Running (OLED Saver)"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        
                        Text(store.t(
                            nl: "24/7 Stream, Autopilot & Sensoren draaien door op minimale schermstroom",
                            en: "24/7 Stream, Autopilot & Sensors keep running on minimal screen power"
                        ))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.38))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    }
                    
                    // 3. Live Telemetry Chips (Dimmed OLED-safe colors)
                    HStack(spacing: 8) {
                        if let temp = store.db.environmentConfig.latestSensorTempC {
                            HStack(spacing: 3) {
                                Image(systemName: "thermometer.medium")
                                    .font(.system(size: 9))
                                Text(String(format: "%.1f°C", temp))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }
                        
                        if let rh = store.db.environmentConfig.latestSensorHumidityPct {
                            HStack(spacing: 3) {
                                Image(systemName: "humidity.fill")
                                    .font(.system(size: 9))
                                Text("\(Int(rh))% RV")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(MycoTheme.blue.opacity(0.65))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                        }
                        
                        HStack(spacing: 3) {
                            Image(systemName: "gauge.with.needle.fill")
                                .font(.system(size: 9))
                            Text("\(Int(sensorManager.currentPressureHpa)) hPa")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                        

                    }
                    
                    // 4. Timelapse Progress (if active)
                    if isTimelapseRunning {
                        VStack(spacing: 4) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(MycoTheme.green.opacity(0.75))
                                    .frame(width: 6, height: 6)
                                Text("\(capturedFramesCount) " + store.t(nl: "foto's vastgelegd • elke \(timelapseIntervalMinutes)m", en: "photos captured • every \(timelapseIntervalMinutes)m"))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(MycoTheme.green.opacity(0.75))
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: autoFlashIfLampOff ? "bolt.badge.automatic.fill" : "bolt.slash.fill")
                                    .font(.system(size: 9))
                                Text(store.t(
                                    nl: isLampActive ? "Flits standby (lamp AAN)" : "Flits actief bij donker",
                                    en: isLampActive ? "Flash standby (light ON)" : "Flash active in dark"
                                ))
                                .font(.system(size: 9))
                            }
                            .foregroundColor(autoFlashIfLampOff ? MycoTheme.amber.opacity(0.65) : .gray.opacity(0.6))
                        }
                        .padding(.top, 2)
                    }
                    
                    // 5. Battery, Charging & Thermal Status
                    HStack(spacing: 10) {
                        HStack(spacing: 5) {
                            Image(systemName: hubManager.batteryIconName)
                                .foregroundColor(hubManager.isCharging ? .green.opacity(0.75) : .white.opacity(0.6))
                            Text("\(hubManager.batteryPercentageInt)%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                            if hubManager.isCharging {
                                Text(store.t(nl: "Aan lader (Opladen ⚡)", en: "Charging ⚡"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.green.opacity(0.75))
                            } else {
                                Text(store.t(nl: "Op batterij", en: "On battery"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                        
                        Text("•")
                            .foregroundColor(.white.opacity(0.25))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.system(size: 9))
                            Text(store.isEnglish ? hubManager.thermalStateLabelEN : hubManager.thermalStateLabelNL)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.45))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 2)
                    
                    // 6. Wake instruction
                    Text(store.t(nl: "Tik ergens op het scherm om te wekken", en: "Tap anywhere on screen to wake"))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.28))
                        .padding(.top, 8)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onWake()
            }
        }
        .onAppear {
            hubManager.setOledStandbyMode(true)
        }
        .onDisappear {
            hubManager.setOledStandbyMode(false)
        }
    }
}

// MARK: - LIVEKIT CLOUD CREDENTIALS & KEY MANAGEMENT SHEET
public struct LiveKitCredentialsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MycoStore
    @ObservedObject var manager: LiveKitStreamManager
    
    @State private var serverUrl: String = LiveKitTokenGenerator.currentServerUrl
    @State private var apiKey: String = LiveKitTokenGenerator.currentApiKey
    @State private var apiSecret: String = LiveKitTokenGenerator.currentApiSecret
    @State private var showResetConfirm: Bool = false
    
    public init(manager: LiveKitStreamManager) {
        self.manager = manager
    }
    
    private func t(nl: String, en: String) -> String {
        store.isEnglish ? en : nl
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(t(nl: "LiveKit Cloud Project Sleutels", en: "LiveKit Cloud Project Keys"))) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t(nl: "WebSocket Server URL", en: "WebSocket Server URL"))
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        TextField("wss://jouw-project.livekit.cloud", text: $serverUrl)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        TextField("API...", text: $apiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Secret")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        SecureField("Secret...", text: $apiSecret)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                Section(header: Text(t(nl: "Lokale Hub Verbinding", en: "Local Hub Connection"))) {
                    Button {
                        serverUrl = LiveKitTokenGenerator.defaultServerUrl
                        apiKey = LiveKitTokenGenerator.defaultApiKey
                        apiSecret = LiveKitTokenGenerator.defaultApiSecret
                        LiveKitTokenGenerator.switchToPiLabHub()
                        manager.isQuotaExceeded = false
                        dismiss()
                        Task {
                            await manager.hardResetAndReconnect()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "server.rack")
                            Text(t(nl: "Herstel naar Standaard Hub URL", en: "Reset to Default Hub URL"))
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .tint(.green)
                }
                
                Section {
                    Button {
                        let cleanUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleanSecret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        LiveKitTokenGenerator.saveConfiguration(
                            serverUrl: cleanUrl.isEmpty ? nil : cleanUrl,
                            apiKey: cleanKey.isEmpty ? nil : cleanKey,
                            apiSecret: cleanSecret.isEmpty ? nil : cleanSecret
                        )
                        manager.isQuotaExceeded = false
                        dismiss()
                        Task {
                            await manager.hardResetAndReconnect()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                            Text(t(nl: "Opslaan & Opnieuw Verbinden", en: "Save & Reconnect"))
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .tint(.blue)
                    
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(t(nl: "Herstel naar Fabrieksinstellingen", en: "Reset to Default Keys"))
                            Spacer()
                        }
                    }
                }
                
                Section(header: Text(t(nl: "Gratis Nieuw LiveKit Project Aanmaken", en: "Create Free LiveKit Project"))) {
                                        Text(t(
                        nl: "1. Ga naar cloud.livekit.io en meld je gratis aan.\n2. Klik op Create Project.\n3. Kopieer de WebSocket URL, API Key en Secret.",
                        en: "1. Go to cloud.livekit.io and sign up for free.\n2. Click Create Project.\n3. Copy the WebSocket URL, API Key and Secret."
                    ))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Link(destination: URL(string: "https://cloud.livekit.io")!) {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text(t(nl: "Open cloud.livekit.io", en: "Open cloud.livekit.io"))
                        }
                    }
                }
            }
            .navigationTitle(t(nl: "LiveKit Cloud Sleutels", en: "LiveKit Cloud Keys"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t(nl: "Sluit", en: "Close")) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                t(nl: "Standaard sleutels herstellen?", en: "Reset to default keys?"),
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button(t(nl: "Herstel naar Standaard", en: "Reset to Default"), role: .destructive) {
                    LiveKitTokenGenerator.resetToDefault()
                    serverUrl = LiveKitTokenGenerator.defaultServerUrl
                    apiKey = LiveKitTokenGenerator.defaultApiKey
                    apiSecret = LiveKitTokenGenerator.defaultApiSecret
                    manager.isQuotaExceeded = false
                    dismiss()
                    Task {
                        await manager.hardResetAndReconnect()
                    }
                }
                Button(t(nl: "Annuleer", en: "Cancel"), role: .cancel) {}
            }
        }
    }
}
