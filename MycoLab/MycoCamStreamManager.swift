//
//  MycoCamStreamManager.swift
//  MycoLab
//
//  Apple Multipeer Connectivity (P2P Wi-Fi & Bluetooth) + 4G/5G Cloud Live Streaming
//  Enables ultra low-latency live camera streaming between an old iPhone (Grow Lab Camera)
//  and viewer iPhone over direct Wi-Fi, Bluetooth, or cellular 4G/5G.
//

import Foundation
import SwiftUI
public import Combine
@preconcurrency import MultipeerConnectivity
import AVFoundation

public enum MycoCamRole: String, Codable, Sendable {
    case idle
    case host      // Camera broadcast (old iPhone in lab)
    case viewer    // Remote viewer (daily iPhone)
}

public enum MycoCamConnectionState: String, Sendable {
    case disconnected
    case advertising
    case browsing
    case connecting
    case connected
}

public enum StreamTransportMode: String, CaseIterable, Identifiable, Sendable {
    case p2p = "P2P (Wi-Fi & Bluetooth)"
    case cloud = "4G / 5G Mobiel Cloud"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .p2p: return "personalhotspot"
        case .cloud: return "antenna.radiowaves.left.and.right"
        }
    }
}

nonisolated public struct RemoteCamCommand: Codable, Sendable {
    public let type: String            // "torch", "request_snapshot", "ping", "plug_toggle", "plug_test", "battery_status", "timelapse_start", "timelapse_stop", "timelapse_status"
    public let torchOn: Bool?
    public let torchBrightness: Float?
    public let timestamp: Double?
    public let plugDeviceId: String?
    public let plugTrigger: String?
    public let batteryLevel: Float?
    public let isCharging: Bool?
    public let timelapseInterval: Int?
    public let timelapseFrameCount: Int?
    public let isTimelapseRunning: Bool?
    
    public init(
        type: String,
        torchOn: Bool? = nil,
        torchBrightness: Float? = nil,
        timestamp: Double? = Date().timeIntervalSince1970,
        plugDeviceId: String? = nil,
        plugTrigger: String? = nil,
        batteryLevel: Float? = nil,
        isCharging: Bool? = nil,
        timelapseInterval: Int? = nil,
        timelapseFrameCount: Int? = nil,
        isTimelapseRunning: Bool? = nil
    ) {
        self.type = type
        self.torchOn = torchOn
        self.torchBrightness = torchBrightness
        self.timestamp = timestamp
        self.plugDeviceId = plugDeviceId
        self.plugTrigger = plugTrigger
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.timelapseInterval = timelapseInterval
        self.timelapseFrameCount = timelapseFrameCount
        self.isTimelapseRunning = isTimelapseRunning
    }
}

// Main thread dispatcher for asynchronous delegate and background network callbacks
nonisolated private func runOnMain(_ block: @escaping @MainActor () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated {
            block()
        }
    } else {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                block()
            }
        }
    }
}

@MainActor
public final class MycoCamStreamManager: NSObject, ObservableObject {
    public static let shared = MycoCamStreamManager()
    
    private let serviceType = "mycolab-cam" // Max 15 chars, alphanumeric and hyphens
    
    // MARK: - State Properties
    @Published public var role: MycoCamRole = .idle
    @Published public var connectionState: MycoCamConnectionState = .disconnected
    @Published public var connectedPeerName: String? = nil
    @Published public var discoveredPeers: [MCPeerID] = []
    
    // Legacy pin code (compatibility, not required for auto connect)
    @Published public var pinCode: String = ""
    
    // Video Feed Data (P2P)
    @Published public var receivedFrame: UIImage? = nil
    @Published public var lastFrameDate: Date? = nil
    @Published public var fps: Double = 0.0
    @Published public var latencyMs: Int = 0
    @Published public var statusMessage: String = "Standby"
    
    // Controls & Host status
    @Published public var isTorchOn: Bool = false
    @Published public var torchBrightness: Float = 0.6
    @Published public var remoteFlashActiveOnHost: Bool = false
    
    // Internal cache of the latest host frame (not published to avoid triggering UI updates on background video thread)
    private let hostFrameLock = NSLock()
    private var _latestHostFrame: UIImage? = nil
    public var latestHostFrame: UIImage? {
        get {
            hostFrameLock.lock()
            defer { hostFrameLock.unlock() }
            return _latestHostFrame
        }
        set {
            hostFrameLock.lock()
            defer { hostFrameLock.unlock() }
            _latestHostFrame = newValue
        }
    }
    
    // MARK: - 4G / 5G Cloud Streaming Properties
    @Published public var cloudChannel: String = "mycolab_lab_stream"
    @Published public var isCloudBroadcasting: Bool = false
    @Published public var isCloudViewerActive: Bool = false
    @Published public var cloudFrame: UIImage? = nil
    @Published public var cloudLastReceivedDate: Date? = nil
    @Published public var cloudLatencyMs: Int = 0
    @Published public var cloudStatusMessage: String = "4G/5G Standby"
    
    // Internal Multipeer objects
    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    // Cloud networking objects
    private var cloudUploadCancellable: AnyCancellable?
    private var cloudViewerPollCancellable: AnyCancellable?
    private var cloudCmdWebSocketTask: URLSessionWebSocketTask?
    private var isUploadingCloudFrame = false
    
    // FPS tracking
    private var frameCount: Int = 0
    private var lastFPSUpdateTime: Date = Date()
    private var lastSendTime: Date = Date()
    private let sendInterval: TimeInterval = 0.10 // ~10 FPS for optimal battery & latency
    
    // Remote command callback for host
    public var onRemoteCommandReceived: (@MainActor (RemoteCamCommand) -> Void)?
    
    override init() {
        super.init()
        let savedChannel = UserDefaults.standard.string(forKey: "mycolab_cloud_channel")
        if let saved = savedChannel, !saved.isEmpty, saved != "mycolab_lab_stream" {
            self.cloudChannel = saved
        } else {
            let clusterChannel = MycoSecurityManager.shared.clusterChannelId
            self.cloudChannel = clusterChannel.isEmpty ? "mycolab_lab_stream" : "mycolab_lab_\(clusterChannel)"
        }
    }
    
    public func setCloudChannel(_ newChannel: String) {
        let cleaned = newChannel
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9_-]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let clusterChannel = MycoSecurityManager.shared.clusterChannelId
        let fallback = clusterChannel.isEmpty ? "mycolab_lab_stream" : "mycolab_lab_\(clusterChannel)"
        self.cloudChannel = cleaned.isEmpty ? fallback : cleaned
        UserDefaults.standard.set(self.cloudChannel, forKey: "mycolab_cloud_channel")
    }
    
    private func setupPeerID(prefix: String) {
        let rawName = UIDevice.current.name.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
        let trimmed = String(rawName.prefix(10)).trimmingCharacters(in: .whitespaces)
        let displayName = "\(prefix)-\(trimmed.isEmpty ? "iPhone" : trimmed)"
        let key = "mycolab_persistent_mppeer_\(prefix)"
        if let data = UserDefaults.standard.data(forKey: key),
           let peer = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data) {
            self.myPeerID = peer
        } else {
            let peer = MCPeerID(displayName: displayName)
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: peer, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: key)
            }
            self.myPeerID = peer
        }
    }
    
    // MARK: - HOST (CAMERA BROADCASTER - P2P)
    public func startHost(pin: String? = nil) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.stopAll()
            
            self.role = .host
            self.statusMessage = "Kweekcamera uitzending gestart. Wachten op kijker..."
            
            // Activate 24/7 Lab Hub on Stream Phone so smart plugs & autopilot operate autonomously on Wi-Fi
            MycoBackgroundHubManager.shared.enableStreamHubMode()
            NotificationCenter.default.post(name: NSNotification.Name("MycoLabStartAutopilotEngine"), object: nil)
            
            self.setupPeerID(prefix: "Cam")
            guard let peerID = self.myPeerID else { return }
            
            let sess = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .optional)
            sess.delegate = self
            self.session = sess
            
            let info = ["name": UIDevice.current.name, "role": "host"]
            let adv = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: self.serviceType)
            adv.delegate = self
            adv.startAdvertisingPeer()
            self.advertiser = adv
            
            self.connectionState = .advertising
        }
    }
    
    public func stopHost() {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.advertiser?.stopAdvertisingPeer()
            self.advertiser = nil
            self.disconnectSession()
            self.role = .idle
            self.connectionState = .disconnected
            self.statusMessage = "Camera uitzending gestopt."
        }
    }
    
    // MARK: - UNIFIED & P2P VIEWER
    public func startUnifiedViewer() {
        startViewer(cleanCloud: false)
        startCloudViewer()
    }
    
    public func stopUnifiedViewer() {
        stopViewer()
        stopCloudViewer()
    }
    
    public func startUnifiedHost() {
        startHost()
        startCloudBroadcasting()
    }
    
    public func stopUnifiedHost() {
        stopHost()
        stopCloudBroadcasting()
    }
    
    public func startViewer(cleanCloud: Bool = false) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            if cleanCloud {
                self.stopAll()
            } else {
                self.advertiser?.stopAdvertisingPeer()
                self.advertiser = nil
                self.browser?.stopBrowsingForPeers()
                self.browser = nil
                self.disconnectSession()
                self.discoveredPeers.removeAll()
                self.role = .idle
                self.connectionState = .disconnected
            }
            
            self.role = .viewer
            self.statusMessage = "Zoeken naar actieve kweekcamera's via Wi-Fi & BT..."
            
            self.setupPeerID(prefix: "Kijker")
            guard let peerID = self.myPeerID else { return }
            
            let sess = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .optional)
            sess.delegate = self
            self.session = sess
            
            let brow = MCNearbyServiceBrowser(peer: peerID, serviceType: self.serviceType)
            brow.delegate = self
            brow.startBrowsingForPeers()
            self.browser = brow
            
            self.connectionState = .browsing
        }
    }
    
    public func stopViewer() {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.browser?.stopBrowsingForPeers()
            self.browser = nil
            self.disconnectSession()
            self.discoveredPeers.removeAll()
            self.role = .idle
            self.connectionState = .disconnected
            self.statusMessage = "Kijker gestopt."
        }
    }
    
    public func connectToCamera(peer: MCPeerID, pin: String = "") {
        runOnMain { [weak self] in
            guard let self = self, let browser = self.browser, let session = self.session else { return }
            self.connectionState = .connecting
            self.statusMessage = "Verbinden met \(peer.displayName)..."
            browser.invitePeer(peer, to: session, withContext: nil, timeout: 15.0)
        }
    }
    
    public func stopAll() {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.advertiser?.stopAdvertisingPeer()
            self.advertiser = nil
            self.browser?.stopBrowsingForPeers()
            self.browser = nil
            self.disconnectSession()
            self.discoveredPeers.removeAll()
            self.role = .idle
            self.connectionState = .disconnected
            self.stopCloudBroadcasting()
            self.stopCloudViewer()
        }
    }
    
    private func disconnectSession() {
        session?.disconnect()
        session = nil
        connectedPeerName = nil
        receivedFrame = nil
    }
    
    // MARK: - SEND VIDEO FRAMES (P2P DIRECT)
    public func broadcastCameraFrame(_ image: UIImage) {
        self.latestHostFrame = image
        guard role == .host, let session = session, !session.connectedPeers.isEmpty else {
            return
        }
        
        let now = Date()
        guard now.timeIntervalSince(lastSendTime) >= sendInterval else { return }
        lastSendTime = now
        
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard self != nil else { return }
            
            // Downscale to max 480 wide for low-latency transmission
            let targetSize: CGSize
            let aspect = image.size.height / max(1, image.size.width)
            if image.size.width > 480 {
                targetSize = CGSize(width: 480, height: 480 * aspect)
            } else {
                targetSize = image.size
            }
            
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: targetSize))
            let resized = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            guard let resizedImage = resized,
                  let jpegData = resizedImage.jpegData(compressionQuality: 0.40) else { return }
            
            // Prefix packet with timestamp for latency calculation
            var packet = Data()
            var ts = now.timeIntervalSince1970
            packet.append(Data(bytes: &ts, count: MemoryLayout<Double>.size))
            packet.append(jpegData)
            
            do {
                try session.send(packet, toPeers: session.connectedPeers, with: .unreliable)
            } catch {
                // dropped frame or network buffer full
            }
        }
    }

    public func sendHighResSnapshotToPeers(_ image: UIImage) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let jpegData = MycoImageHelper.prepareForStorage(image: image, maxDimension: 1024, compressionQuality: 0.6) else { return }
            var packet = Data("p2p_photo\n".utf8)
            packet.append(jpegData)
            try? session.send(packet, toPeers: session.connectedPeers, with: .reliable)
        }
    }
    
    // MARK: - SEND REMOTE COMMANDS (FROM VIEWER TO CAMERA HUB)
    public func sendTorchCommand(isOn: Bool, brightness: Float = 0.8) {
        self.remoteFlashActiveOnHost = isOn
        self.isTorchOn = isOn
        self.torchBrightness = brightness
        let cmd = RemoteCamCommand(type: "torch", torchOn: isOn, torchBrightness: brightness)
        if connectionState == .connected {
            sendCommand(cmd)
        }
        sendCloudCommand(cmd)
    }
    
    public func requestHighResSnapshot() {
        let cmd = RemoteCamCommand(type: "request_snapshot")
        if connectionState == .connected {
            sendCommand(cmd)
        } else if isCloudViewerActive {
            sendCloudCommand(cmd)
        }
    }
    
    public func sendCloudPlugToggle(id: UUID, trigger: String = "Kijk-app (Afstandsbediening)") {
        let cmd = RemoteCamCommand(type: "plug_toggle", plugDeviceId: id.uuidString, plugTrigger: trigger)
        if connectionState == .connected {
            sendCommand(cmd)
        }
        sendCloudCommand(cmd)
    }
    
    public func sendCloudPlugTest(id: UUID) {
        let cmd = RemoteCamCommand(type: "plug_test", plugDeviceId: id.uuidString)
        if connectionState == .connected {
            sendCommand(cmd)
        }
        sendCloudCommand(cmd)
    }
    
    private func sendCommand(_ command: RemoteCamCommand) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(command) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
    
    /// Sends a plaintext command string across the active P2P session
    public func sendPlaintextCommand(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
    
    /// Sends screen sleep/wake command across P2P and cloud transports
    public func sendRemoteScreenSleep(dim: Bool) {
        let cmd = RemoteCamCommand(type: dim ? "screen_sleep" : "screen_wake")
        if connectionState == .connected {
            sendCommand(cmd)
        }
        sendCloudCommand(cmd)
        sendPlaintextCommand(dim ? "screen:sleep:on" : "screen:sleep:off")
    }
    
    // MARK: - 4G / 5G CLOUD STREAMING (CELLULAR & ANY NETWORK)
    public func startCloudBroadcasting() {
        guard !isCloudBroadcasting else { return }
        isCloudBroadcasting = true
        cloudStatusMessage = "4G/5G Uitzending actief"
        
        // Start background upload loop every 2.5 seconds
        cloudUploadCancellable = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.uploadLatestCloudFrame()
            }
        
        // Connect to command WebSocket to receive remote commands on 4G/5G
        startHostCloudCommandListener()
    }
    
    public func stopCloudBroadcasting() {
        isCloudBroadcasting = false
        cloudUploadCancellable?.cancel()
        cloudUploadCancellable = nil
        cloudCmdWebSocketTask?.cancel(with: .normalClosure, reason: nil)
        cloudCmdWebSocketTask = nil
        cloudStatusMessage = "4G/5G Uitzending gestopt"
    }
    
    private func uploadLatestCloudFrame() {
        guard isCloudBroadcasting, !isUploadingCloudFrame, let frame = latestHostFrame else { return }
        isUploadingCloudFrame = true
        let channel = self.cloudChannel
        
        // Safety timeout watchdog: ensure upload flag resets after 4s in case of connection drop
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if self?.isUploadingCloudFrame == true {
                self?.isUploadingCloudFrame = false
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let targetSize = CGSize(width: 440, height: 330)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let scaled = renderer.image { _ in
                frame.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            guard let jpegData = scaled.jpegData(compressionQuality: 0.35) else {
                runOnMain { [weak self] in self?.isUploadingCloudFrame = false }
                return
            }
            
            guard let url = URL(string: "https://ntfy.sh/\(channel)") else {
                runOnMain { [weak self] in self?.isUploadingCloudFrame = false }
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("frame.jpg", forHTTPHeaderField: "Filename")
            request.setValue("MycoCamFrame", forHTTPHeaderField: "Title")
            request.setValue("low", forHTTPHeaderField: "Priority")
            request.setValue("\(Date().timeIntervalSince1970)", forHTTPHeaderField: "X-Timestamp")
            request.timeoutInterval = 3.5
            request.httpBody = jpegData
            
            let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
                runOnMain { [weak self] in
                    self?.isUploadingCloudFrame = false
                    if error == nil, let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                        self?.cloudStatusMessage = "4G/5G Uitzending live (laatste frame verzonden)"
                    }
                }
            }
            task.resume()
        }
    }
    
    private func startHostCloudCommandListener() {
        guard let url = URL(string: "wss://ntfy.sh/\(cloudChannel)_cmd/ws") else { return }
        let wsTask = URLSession.shared.webSocketTask(with: url)
        self.cloudCmdWebSocketTask = wsTask
        wsTask.resume()
        listenForHostCloudCommands()
    }
    
    private func listenForHostCloudCommands() {
        cloudCmdWebSocketTask?.receive { [weak self] result in
            runOnMain { [weak self] in
                guard let self = self, self.isCloudBroadcasting else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleIncomingCloudCommandText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleIncomingCloudCommandText(text)
                        }
                    @unknown default:
                        break
                    }
                    self.listenForHostCloudCommands()
                case .failure:
                    // Reconnect after brief pause
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        if self?.isCloudBroadcasting == true {
                            self?.startHostCloudCommandListener()
                        }
                    }
                }
            }
        }
    }
    
    private func handleIncomingCloudCommandText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageBody = json["message"] as? String,
              let cmdData = messageBody.data(using: .utf8),
              let cmd = try? JSONDecoder().decode(RemoteCamCommand.self, from: cmdData) else {
            return
        }
        
        runOnMain { [weak self] in
            guard let self = self else { return }
            if cmd.type == "torch", let on = cmd.torchOn {
                self.remoteFlashActiveOnHost = on
                self.isTorchOn = on
                if let b = cmd.torchBrightness {
                    self.torchBrightness = b
                }
            } else if cmd.type == "plug_toggle", let idStr = cmd.plugDeviceId, let id = UUID(uuidString: idStr) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("MycoLabRemotePlugToggle"),
                    object: nil,
                    userInfo: ["id": id, "trigger": cmd.plugTrigger ?? "Kijk-app (Stream Hub Relay)"]
                )
            } else if cmd.type == "plug_test", let idStr = cmd.plugDeviceId, let id = UUID(uuidString: idStr) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("MycoLabRemotePlugTest"),
                    object: nil,
                    userInfo: ["id": id]
                )
            }
            if let bat = cmd.batteryLevel {
                LiveKitStreamManager.shared.remoteBatteryLevel = bat
                MycoStore.shared?.db.environmentConfig.cameraBatteryLevel = bat
                MycoStore.shared?.db.environmentConfig.cameraBatteryLastUpdated = Date()
            }
            if let chg = cmd.isCharging {
                LiveKitStreamManager.shared.remoteIsCharging = chg
                MycoStore.shared?.db.environmentConfig.cameraIsCharging = chg
            }
            self.onRemoteCommandReceived?(cmd)
        }
    }
    
    // MARK: - 4G / 5G CLOUD VIEWER (MONITOR OVER CELLULAR)
    private var cloudViewerWsTask: URLSessionWebSocketTask? = nil
    
    public func startCloudViewer() {
        guard !isCloudViewerActive else { return }
        isCloudViewerActive = true
        cloudStatusMessage = "Verbinden met 4G/5G Cloud..."
        
        // Initial fetch
        fetchLatestCloudSnapshot()
        
        // Start live WebSocket stream for instant sub-second push
        startCloudViewerWebSocket()
        
        // Polling loop every 1.5 seconds as guaranteed fallback
        cloudViewerPollCancellable = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchLatestCloudSnapshot()
            }
    }
    
    public func stopCloudViewer() {
        isCloudViewerActive = false
        cloudViewerPollCancellable?.cancel()
        cloudViewerPollCancellable = nil
        cloudViewerWsTask?.cancel(with: .normalClosure, reason: nil)
        cloudViewerWsTask = nil
        cloudStatusMessage = "4G/5G Kijker gestopt"
    }
    
    private func startCloudViewerWebSocket() {
        guard let url = URL(string: "wss://ntfy.sh/\(cloudChannel)/ws") else { return }
        let wsTask = URLSession.shared.webSocketTask(with: url)
        self.cloudViewerWsTask = wsTask
        wsTask.resume()
        listenForCloudViewerWebSocket()
    }
    
    private func listenForCloudViewerWebSocket() {
        cloudViewerWsTask?.receive { [weak self] result in
            runOnMain { [weak self] in
                guard let self = self, self.isCloudViewerActive else { return }
                switch result {
                case .success(let message):
                    var text = ""
                    switch message {
                    case .string(let t): text = t
                    case .data(let d): text = String(data: d, encoding: .utf8) ?? ""
                    @unknown default: break
                    }
                    
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let attachment = json["attachment"] as? [String: Any],
                       let fileUrlString = attachment["url"] as? String,
                       let fileUrl = URL(string: fileUrlString) {
                        let attachType = attachment["type"] as? String ?? ""
                        let attachName = attachment["name"] as? String ?? ""
                        guard attachType.hasPrefix("image/") || attachName.hasSuffix(".jpg") || attachName.hasSuffix(".png") else {
                            self.listenForCloudViewerWebSocket()
                            return
                        }
                        let sendTimestamp = json["time"] as? Double ?? Date().timeIntervalSince1970
                        var imgReq = URLRequest(url: fileUrl)
                        imgReq.timeoutInterval = 3.0
                        URLSession.shared.dataTask(with: imgReq) { [weak self] imgData, _, _ in
                            guard let imgData = imgData, let img = UIImage(data: imgData) else { return }
                            let now = Date()
                            let latency = max(10, Int((now.timeIntervalSince1970 - sendTimestamp) * 1000.0))
                            runOnMain { [weak self] in
                                self?.cloudFrame = img
                                self?.cloudLastReceivedDate = now
                                self?.cloudLatencyMs = min(9999, latency)
                                self?.cloudStatusMessage = "Live via 4G/5G Mobiel (Live Push)"
                            }
                        }.resume()
                    }
                    self.listenForCloudViewerWebSocket()
                case .failure:
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        if self?.isCloudViewerActive == true {
                            self?.startCloudViewerWebSocket()
                        }
                    }
                }
            }
        }
    }
    
    public func fetchLatestCloudSnapshot() {
        guard isCloudViewerActive else { return }
        guard let url = URL(string: "https://ntfy.sh/\(cloudChannel)/json?poll=1") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            
            guard let str = String(data: data, encoding: .utf8) else { return }
            let lines = str.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            // Find NEWEST message with valid IMAGE attachment and download ONLY that one
            for line in lines.reversed() {
                guard let lineData = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let attachment = json["attachment"] as? [String: Any],
                      let fileUrlString = attachment["url"] as? String,
                      let fileUrl = URL(string: fileUrlString) else {
                    continue
                }
                
                let attachType = attachment["type"] as? String ?? ""
                let attachName = attachment["name"] as? String ?? ""
                guard attachType.hasPrefix("image/") || attachName.hasSuffix(".jpg") || attachName.hasSuffix(".png") else {
                    continue
                }
                
                let sendTimestamp = json["time"] as? Double ?? Date().timeIntervalSince1970
                
                var imgRequest = URLRequest(url: fileUrl)
                imgRequest.timeoutInterval = 3.0
                URLSession.shared.dataTask(with: imgRequest) { [weak self] imgData, _, _ in
                    guard let imgData = imgData, let img = UIImage(data: imgData) else { return }
                    let now = Date()
                    let latency = max(10, Int((now.timeIntervalSince1970 - sendTimestamp) * 1000.0))
                    
                    runOnMain { [weak self] in
                        self?.cloudFrame = img
                        self?.cloudLastReceivedDate = now
                        self?.cloudLatencyMs = min(9999, latency)
                        self?.cloudStatusMessage = "Live via 4G/5G Mobiel"
                    }
                }.resume()
                
                // Break immediately so only the single newest frame is retrieved
                break
            }
        }.resume()
    }
    
    public func sendCloudCommand(_ command: RemoteCamCommand) {
        guard let url = URL(string: "https://ntfy.sh/\(cloudChannel)_cmd") else { return }
        guard let cmdData = try? JSONEncoder().encode(command),
              let jsonString = String(data: cmdData, encoding: .utf8) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonString.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request).resume()
    }
}

// MARK: - MCSESSION DELEGATE
extension MycoCamStreamManager: MCSessionDelegate {
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            switch state {
            case .connected:
                self.connectionState = .connected
                self.connectedPeerName = peerID.displayName
                self.statusMessage = "Verbonden met \(peerID.displayName)!"
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)
                if self.role == .host {
                    LiveKitStreamManager.shared.broadcastCameraList()
                } else if self.role == .viewer {
                    LiveKitStreamManager.shared.requestRemoteCameras()
                }
            case .connecting:
                self.connectionState = .connecting
                self.statusMessage = "Verbinding maken met \(peerID.displayName)..."
            case .notConnected:
                if self.connectionState == .connected {
                    self.statusMessage = "Verbinding met \(peerID.displayName) verbroken."
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.warning)
                }
                self.connectedPeerName = nil
                self.receivedFrame = nil
                if self.role == .host {
                    self.connectionState = .advertising
                } else if self.role == .viewer {
                    self.connectionState = .browsing
                    if let brow = self.browser, let sess = self.session, self.discoveredPeers.contains(peerID) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                            guard let self = self else { return }
                            if self.role == .viewer && self.connectionState == .browsing && !sess.connectedPeers.contains(peerID) {
                                self.connectionState = .connecting
                                brow.invitePeer(peerID, to: sess, withContext: nil, timeout: 10.0)
                            }
                        }
                    }
                } else {
                    self.connectionState = .disconnected
                }
            @unknown default:
                break
            }
        }
    }
    
    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let tsSize = MemoryLayout<Double>.size
        
        // 1. Check if packet is a video frame with timestamp prefix
        if data.count > tsSize + 100 {
            let timestamp: Double = data.withUnsafeBytes { ptr in
                ptr.load(as: Double.self)
            }
            let imageData = data.subdata(in: tsSize..<data.count)
            if let image = UIImage(data: imageData) {
                let now = Date()
                let latency = Int((now.timeIntervalSince1970 - timestamp) * 1000.0)
                
                runOnMain { [weak self] in
                    guard let self = self else { return }
                    self.receivedFrame = image
                    self.lastFrameDate = now
                    self.latencyMs = max(0, min(999, latency))
                    
                    // Update FPS
                    self.frameCount += 1
                    let elapsed = now.timeIntervalSince(self.lastFPSUpdateTime)
                    if elapsed >= 1.0 {
                        self.fps = Double(self.frameCount) / elapsed
                        self.frameCount = 0
                        self.lastFPSUpdateTime = now
                    }
                }
                return
            }
        }
        
        // 2. Otherwise check if packet is a JSON Command (e.g. torch toggle or plug command)
        if let cmd = try? JSONDecoder().decode(RemoteCamCommand.self, from: data) {
            runOnMain { [weak self] in
                guard let self = self else { return }
                if cmd.type == "request_snapshot" {
                    if let frame = self.latestHostFrame {
                        self.sendHighResSnapshotToPeers(frame)
                        MycoOpticalHygrometerManager.shared.handleReceivedRemotePhoto(frame)
                    }
                } else if cmd.type == "torch", let on = cmd.torchOn {
                    self.remoteFlashActiveOnHost = on
                    self.isTorchOn = on
                    if let b = cmd.torchBrightness {
                        self.torchBrightness = b
                    }
                } else if cmd.type == "plug_toggle", let idStr = cmd.plugDeviceId, let id = UUID(uuidString: idStr) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("MycoLabRemotePlugToggle"),
                        object: nil,
                        userInfo: ["id": id, "trigger": cmd.plugTrigger ?? "Kijk-app (Stream Hub Relay)"]
                    )
                } else if cmd.type == "plug_test", let idStr = cmd.plugDeviceId, let id = UUID(uuidString: idStr) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("MycoLabRemotePlugTest"),
                        object: nil,
                        userInfo: ["id": id]
                    )
                }
                if let bat = cmd.batteryLevel {
                    LiveKitStreamManager.shared.remoteBatteryLevel = bat
                    MycoStore.shared?.db.environmentConfig.cameraBatteryLevel = bat
                    MycoStore.shared?.db.environmentConfig.cameraBatteryLastUpdated = Date()
                }
                if let chg = cmd.isCharging {
                    LiveKitStreamManager.shared.remoteIsCharging = chg
                    MycoStore.shared?.db.environmentConfig.cameraIsCharging = chg
                }
                if cmd.type == "screen_sleep_toggle" || cmd.type == "sleep_toggle" {
                    LiveKitStreamManager.shared.setOledSaver(active: !LiveKitStreamManager.shared.isOledSaverActive, notifyPeer: true)
                } else if cmd.type == "screen_sleep" || cmd.type == "sleep" {
                    LiveKitStreamManager.shared.setOledSaver(active: true, notifyPeer: true)
                } else if cmd.type == "screen_wake" || cmd.type == "wake" {
                    LiveKitStreamManager.shared.setOledSaver(active: false, notifyPeer: true)
                }
                self.onRemoteCommandReceived?(cmd)
            }
            return
        }
        
        // 3. Plaintext control commands (e.g. camera selection, cams_sync, sleep, torch)
        if let text = String(data: data, encoding: .utf8) {
            runOnMain {
                LiveKitStreamManager.shared.handleIncomingControlMessage(text)
            }
        }
    }
    
    nonisolated public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNEARBYSERVICEADVERTISER DELEGATE (HOST)
extension MycoCamStreamManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Direct auto-accept: seamless automatic pairing without PIN
        Task { @MainActor in
            guard let sess = self.session else {
                invitationHandler(false, nil)
                return
            }
            invitationHandler(true, sess)
            self.connectionState = .connected
            self.connectedPeerName = peerID.displayName
            self.statusMessage = "Verbonden met kijker: \(peerID.displayName)"
        }
    }
    
    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        runOnMain { [weak self] in
            self?.statusMessage = "Fout bij adverteren: \(error.localizedDescription)"
        }
    }
}

// MARK: - MCNEARBYSERVICEBROWSER DELEGATE (VIEWER)
extension MycoCamStreamManager: MCNearbyServiceBrowserDelegate {
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
            self.statusMessage = "Kweekcamera \(peerID.displayName) ontdekt. Direct verbinden via P2P..."
            // Auto-invite peer immediately for instant 0-token local streaming
            if let sess = self.session, !sess.connectedPeers.contains(peerID) {
                self.connectionState = .connecting
                browser.invitePeer(peerID, to: sess, withContext: nil, timeout: 10.0)
            }
        }
    }
    
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.discoveredPeers.removeAll { $0 == peerID }
            if self.discoveredPeers.isEmpty {
                self.statusMessage = "Geen actieve kweekcamera's in de buurt..."
            }
        }
    }
    
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        runOnMain { [weak self] in
            self?.statusMessage = "Fout bij zoeken: \(error.localizedDescription)"
        }
    }
}
