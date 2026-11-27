//
//  MycoCamPairingManager.swift
//  MycoLab
//
//  Automatic zero-configuration Wi-Fi / Bluetooth discovery and persistent mesh networking
//  between all MycoLab devices (Phones, Tablets, Kweekcamera, Remote Viewers).
//  Synchronizes Smart Plugs, Tuya device states, Lab data, and Live Video instantly.
//

import Foundation
import SwiftUI
import Combine
@preconcurrency import MultipeerConnectivity
import Network
import AVFoundation
import CoreImage.CIFilterBuiltins

public struct DiscoveredCamera: Identifiable, Hashable, Sendable {
    public var id: String { cameraId }
    public let cameraId: String
    public let name: String
    public let model: String
    public let peerID: MCPeerID
    public let cluster: String
    public let isVerifiedCluster: Bool

    public init(cameraId: String, name: String, model: String, peerID: MCPeerID, cluster: String = "", isVerifiedCluster: Bool = true) {
        self.cameraId = cameraId
        self.name = name
        self.model = model
        self.peerID = peerID
        self.cluster = cluster
        self.isVerifiedCluster = isVerifiedCluster
    }
}

@MainActor
public final class MycoCamPairingManager: NSObject, ObservableObject {
    public static let shared = MycoCamPairingManager()

    // MARK: - Constants & Storage Keys
    private let kLocalCameraId = "mycolab_local_camera_id"
    private let kPairedCameraId = "mycolab_paired_camera_id"
    private let kPairedCameraName = "mycolab_paired_camera_name"
    private let kPairedDate = "mycolab_paired_date"
    private let kCloudRegisteredCameraId = "mycolab_registered_camera_id"
    private let kCloudRegisteredCameraName = "mycolab_registered_camera_name"
    private let serviceType = "mycolab-pair" // Max 15 chars, declared in Info.plist

    // MARK: - Published Properties
    @Published public private(set) var localCameraId: String = ""
    @Published public private(set) var localCameraName: String = ""
    @Published public private(set) var pairedCameraId: String? = nil
    @Published public private(set) var pairedCameraName: String? = nil
    @Published public private(set) var pairedDate: Date? = nil
    @Published public private(set) var isPaired: Bool = false

    // Discovery State
    @Published public var isSearching: Bool = false
    @Published public var isAdvertising: Bool = false
    @Published public var discoveredCameras: [DiscoveredCamera] = []
    @Published public var statusMessage: String = "Gereed"
    @Published public var justPairedSuccessfully: Bool = false

    public func localizedStatus(isEnglish: Bool) -> String {
        guard isEnglish else { return statusMessage }
        if statusMessage == "Gereed" { return "Ready" }
        if statusMessage.contains("staat open voor automatische koppeling") {
            return "Grow camera is open for automatic pairing via Wi-Fi."
        }
        if statusMessage.contains("Automatisch zoeken") {
            return "Searching automatically for grow cameras on local Wi-Fi..."
        }
        if statusMessage.contains("Gekoppeld met:") || statusMessage.contains("Verbonden met:") {
            return statusMessage.replacingOccurrences(of: "Verbonden met:", with: "Connected to:")
                .replacingOccurrences(of: "Gekoppeld met:", with: "Paired with:")
        }
        if statusMessage.contains("gevonden via Wi-Fi!") {
            return statusMessage.replacingOccurrences(of: "gevonden via Wi-Fi!", with: "found via Wi-Fi!")
                .replacingOccurrences(of: "Kweekcamera", with: "Grow camera")
        }
        if statusMessage.contains("Fout bij Wi-Fi") {
            return statusMessage.replacingOccurrences(of: "Fout bij Wi-Fi adverteren:", with: "Wi-Fi advertising error:")
                .replacingOccurrences(of: "Fout bij Wi-Fi zoeken:", with: "Wi-Fi discovery error:")
        }
        return statusMessage
    }

    // Network Telemetry
    @Published public var isCellular: Bool = false
    @Published public var isWiFi: Bool = false
    @Published public var isOnline: Bool = true

    // Auto-pair callback
    public var onAutoPaired: ((String) -> Void)? = nil

    // Unified Multipeer Objects
    private var myPeerID: MCPeerID?
    private var meshSession: MCSession?
    private var meshAdvertiser: MCNearbyServiceAdvertiser?
    private var meshBrowser: MCNearbyServiceBrowser?

    // Backward compatibility aliases
    public var advertiserSession: MCSession? { meshSession }
    public var browserSession: MCSession? { meshSession }
    public var advertiser: MCNearbyServiceAdvertiser? { meshAdvertiser }
    public var browser: MCNearbyServiceBrowser? { meshBrowser }

    // Network Monitor
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mycolab.pairing.networkMonitor")

    public override init() {
        super.init()
        loadPersistentState()
        startNetworkMonitoring()

        // Automatically start the zero-configuration local mesh network on startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startMeshNetwork()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.meshSession == nil || self.meshBrowser == nil {
                    self.startMeshNetwork()
                } else if self.hasConnectedPeers {
                    MycoSyncManager.shared.requestSyncFromConnectedPeers()
                    MycoSyncManager.shared.sendSyncPayload(reason: "foreground_auto_sync")
                }
            }
        }

        if MycoKVS.isAvailable {
            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: NSUbiquitousKeyValueStore.default,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.loadPersistentState()
                }
            }
        }
    }

    // MARK: - Persistence & Identity
    private func loadPersistentState() {
        // 1. Ensure local camera ID exists (generated once and kept permanently)
        if let existingId = UserDefaults.standard.string(forKey: kLocalCameraId), !existingId.isEmpty {
            self.localCameraId = existingId
        } else {
            let newId = "cam-" + UUID().uuidString.prefix(8).lowercased()
            UserDefaults.standard.set(newId, forKey: kLocalCameraId)
            self.localCameraId = newId
        }

        self.localCameraName = UIDevice.current.name

        // 2. Load saved paired camera (if viewer has paired previously)
        if let savedPairedId = UserDefaults.standard.string(forKey: kPairedCameraId), !savedPairedId.isEmpty {
            self.pairedCameraId = savedPairedId
            self.pairedCameraName = UserDefaults.standard.string(forKey: kPairedCameraName) ?? "Kweekcamera"
            if let dateInterval = UserDefaults.standard.object(forKey: kPairedDate) as? Double {
                self.pairedDate = Date(timeIntervalSince1970: dateInterval)
            }
            self.isPaired = true
        } else if let cloudCamId = MycoKVS.string(forKey: kCloudRegisteredCameraId),
                  !cloudCamId.isEmpty,
                  cloudCamId != self.localCameraId {
            // Auto-paired via shared iCloud Apple ID
            let cloudName = MycoKVS.string(forKey: kCloudRegisteredCameraName) ?? "Kweekcamera"
            self.pairedCameraId = cloudCamId
            self.pairedCameraName = cloudName
            self.pairedDate = Date()
            self.isPaired = true
            UserDefaults.standard.set(cloudCamId, forKey: kPairedCameraId)
            UserDefaults.standard.set(cloudName, forKey: kPairedCameraName)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: kPairedDate)
        } else {
            self.pairedCameraId = nil
            self.pairedCameraName = nil
            self.isPaired = false
        }
    }

    // MARK: - Mesh Networking (Always-On P2P Wi-Fi / Bluetooth)
    public func startMeshNetwork() {
        if meshSession != nil && meshAdvertiser != nil && meshBrowser != nil {
            return
        }

        let rawName = UIDevice.current.name.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
        let trimmed = String(rawName.prefix(10)).trimmingCharacters(in: .whitespaces)
        let shortId = String(localCameraId.suffix(4))
        let displayName = "\(trimmed.isEmpty ? "MycoLab" : trimmed)-\(shortId)"
        
        let peer = MCPeerID(displayName: displayName)
        self.myPeerID = peer

        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.meshSession = session

        let info: [String: String] = [
            "id": localCameraId,
            "name": UIDevice.current.name,
            "model": UIDevice.current.model,
            "cluster": MycoSecurityManager.shared.clusterHash
        ]

        let adv = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: info, serviceType: serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        self.meshAdvertiser = adv
        self.isAdvertising = true

        let brow = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        brow.delegate = self
        brow.startBrowsingForPeers()
        self.meshBrowser = brow
        self.isSearching = true
        self.statusMessage = "Wi-Fi & Bluetooth Mesh actief"
    }

    public func pair(with cameraId: String, name: String) {
        let cleanId = cameraId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }

        self.pairedCameraId = cleanId
        self.pairedCameraName = name.isEmpty ? "Kweekcamera" : name
        self.pairedDate = Date()
        self.isPaired = true
        self.justPairedSuccessfully = true
        self.isSearching = false

        UserDefaults.standard.set(self.pairedCameraId, forKey: kPairedCameraId)
        UserDefaults.standard.set(self.pairedCameraName, forKey: kPairedCameraName)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: kPairedDate)

        // Sync with iCloud Key-Value Store so other devices on the same Apple ID pair automatically
        MycoKVS.set(self.pairedCameraId, forKey: kPairedCameraId)
        MycoKVS.set(self.pairedCameraName, forKey: kPairedCameraName)
        MycoKVS.synchronize()

        // Automatically sync lab data between paired devices
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            MycoStore.shared?.syncCloudData()
            MycoSyncManager.shared.requestSyncFromConnectedPeers()
            MycoSyncManager.shared.sendSyncPayload(reason: "camera_paired")
        }

        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        self.onAutoPaired?(cleanId)

        // Reset justPaired flag after a short delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.justPairedSuccessfully = false
        }
    }

    public func connectAndPair(with cam: DiscoveredCamera) {
        self.pair(with: cam.cameraId, name: cam.name)
        if let sess = self.meshSession, !sess.connectedPeers.contains(cam.peerID), let brow = self.meshBrowser {
            let authContext = MycoSecurityManager.shared.invitationContext
            brow.invitePeer(cam.peerID, to: sess, withContext: authContext, timeout: 10.0)
        }
    }

    public func unpair() {
        self.pairedCameraId = nil
        self.pairedCameraName = nil
        self.pairedDate = nil
        self.isPaired = false
        self.justPairedSuccessfully = false

        UserDefaults.standard.removeObject(forKey: kPairedCameraId)
        UserDefaults.standard.removeObject(forKey: kPairedCameraName)
        UserDefaults.standard.removeObject(forKey: kPairedDate)

        MycoKVS.removeObject(forKey: kPairedCameraId)
        MycoKVS.removeObject(forKey: kPairedCameraName)
        MycoKVS.removeObject(forKey: kCloudRegisteredCameraId)
        MycoKVS.removeObject(forKey: kCloudRegisteredCameraName)
        MycoKVS.synchronize()

        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
    }

    // MARK: - Network Detection (Wi-Fi vs 4G/5G)
    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isOnline = path.status == .satisfied
                self.isCellular = path.isExpensive || path.usesInterfaceType(.cellular)
                self.isWiFi = path.usesInterfaceType(.wifi)
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    // MARK: - Legacy Compatibility API for Camera / Viewer modes
    public func startAdvertisingCamera() {
        startMeshNetwork()
        // Register camera identity in iCloud KVS so viewer on the same Apple ID can auto-pair anywhere in the world!
        MycoKVS.set(self.localCameraId, forKey: kCloudRegisteredCameraId)
        MycoKVS.set(self.localCameraName, forKey: kCloudRegisteredCameraName)
        MycoKVS.synchronize()
        self.statusMessage = "Kweekcamera staat open voor automatische koppeling via Wi-Fi & iCloud."
    }

    public func stopAdvertising() {
        // Keep mesh alive in background for smart devices sync
    }

    public func startBrowsingForCameras() {
        startMeshNetwork()
        self.statusMessage = "Automatisch zoeken naar kweekcamera's op lokaal Wi-Fi netwerk..."
    }

    public func stopBrowsing() {
        // Keep mesh alive in background for smart devices sync
    }

    // MARK: - QR Code Pairing (Instant Visual Fallback)
    public var qrCodePayload: String {
        let secret = MycoSecurityManager.shared.clusterSecret
        return "mycolab://pair?id=\(localCameraId)&name=\(localCameraName)&key=\(secret)"
    }

    public func generateQRCode() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        guard let data = qrCodePayload.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    public func handleScannedPayload(_ text: String) -> Bool {
        guard let url = URL(string: text),
              url.scheme == "mycolab",
              url.host == "pair",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return false
        }

        let id = queryItems.first(where: { $0.name == "id" })?.value ?? ""
        let name = queryItems.first(where: { $0.name == "name" })?.value ?? "Kweekcamera"
        let key = queryItems.first(where: { $0.name == "key" })?.value

        if let key = key, !key.isEmpty {
            MycoSecurityManager.shared.importClusterSecret(key)
        }

        if !id.isEmpty {
            pair(with: id, name: name)
            return true
        }
        return false
    }

    public var hasConnectedPeers: Bool {
        return (meshSession?.connectedPeers.count ?? 0) > 0
    }

    public var connectedPeerNames: [String] {
        return meshSession?.connectedPeers.map { $0.displayName } ?? []
    }

    @discardableResult
    public func sendDirectCommandToPeers(_ command: String) -> Bool {
        let signed = MycoSecurityManager.shared.signPacket(command)
        guard let data = signed.data(using: .utf8) else { return false }
        return sendDataToPeers(data)
    }

    // MARK: - P2P Sync Communication
    @discardableResult
    public func sendDataToPeers(_ data: Data) -> Bool {
        guard let session = meshSession, !session.connectedPeers.isEmpty else { return false }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            return true
        } catch {
            print("[MycoCamPairing] Fout bij zenden naar peers: \(error)")
            return false
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MycoCamPairingManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            guard let session = self.meshSession else {
                invitationHandler(false, nil)
                return
            }
            invitationHandler(true, session)
            self.statusMessage = "Veilig verbonden met: \(peerID.displayName)"
        }
    }

    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            self.statusMessage = "Fout bij Wi-Fi adverteren: \(error.localizedDescription)"
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MycoCamPairingManager: MCNearbyServiceBrowserDelegate {
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            let cameraId = info?["id"] ?? ""
            let cameraName = info?["name"] ?? peerID.displayName
            let model = info?["model"] ?? "iPhone"
            let cluster = info?["cluster"] ?? ""

            guard !cameraId.isEmpty, cameraId != self.localCameraId else { return }

            let discovered = DiscoveredCamera(cameraId: cameraId, name: cameraName, model: model, peerID: peerID, cluster: cluster, isVerifiedCluster: true)
            if let idx = self.discoveredCameras.firstIndex(where: { $0.cameraId == cameraId }) {
                self.discoveredCameras[idx] = discovered
            } else {
                self.discoveredCameras.append(discovered)
            }

            // Only auto-connect session if this camera was ALREADY paired by user
            if self.isPaired && self.pairedCameraId == cameraId {
                if let sess = self.meshSession, !sess.connectedPeers.contains(peerID) {
                    let authContext = MycoSecurityManager.shared.invitationContext
                    browser.invitePeer(peerID, to: sess, withContext: authContext, timeout: 10.0)
                }
            }
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredCameras.removeAll { $0.peerID == peerID }
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.statusMessage = "Fout bij Wi-Fi zoeken: \(error.localizedDescription)"
        }
    }
}

// MARK: - MCSessionDelegate
extension MycoCamPairingManager: MCSessionDelegate {
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            if state == .connected {
                let peerName = peerID.displayName
                self.statusMessage = "Veilig verbonden met: \(peerName)"
                MycoSyncManager.shared.onPeerConnected(peerName: peerName)
                if LiveKitStreamManager.shared.currentRole == .broadcaster {
                    LiveKitStreamManager.shared.broadcastCameraList()
                } else {
                    LiveKitStreamManager.shared.requestRemoteCameras()
                }
            } else if state == .notConnected {
                // Re-invite after disconnect if peer still in range
                if let brow = self.meshBrowser,
                   let found = self.discoveredCameras.first(where: { $0.peerID == peerID }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if let sess = self.meshSession, !sess.connectedPeers.contains(found.peerID) {
                            let authContext = MycoSecurityManager.shared.invitationContext
                            brow.invitePeer(found.peerID, to: sess, withContext: authContext, timeout: 10.0)
                        }
                    }
                }
            }
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            MycoSyncManager.shared.handleIncomingP2PPacket(data, from: peerID.displayName)
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
