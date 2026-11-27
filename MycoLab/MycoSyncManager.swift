//
//  MycoSyncManager.swift
//  MycoLab
//
//  Real-time bidirectional synchronization engine for MycoLab.
//  Keeps all lab data (smartDevices, Tuya config, grow projects, cultures, strains, stash, harvests, logs, supplies)
//  synchronized silently in the background between multiple devices (e.g. Host Grow Camera and Daily Viewer)
//  over local Wi-Fi/Bluetooth (MultipeerConnectivity), 4G/5G Cloud (LiveKit WebRTC), and iCloud KVS.
//

import Foundation
import SwiftUI
import Combine
@preconcurrency import MultipeerConnectivity
import LiveKit

// MARK: - Safe iCloud Key-Value Store Wrapper (Guards against Personal Team Entitlement Faults)
public final class MycoKVS: @unchecked Sendable {
    public static let shared = MycoKVS()

    /// Returns true only if iCloud KVS entitlement is active and supported.
    /// Under Personal Developer Team provisioning profiles without ubiquity entitlement, this safely returns false.
    public static let isAvailable: Bool = {
        #if targetEnvironment(simulator)
        return false
        #else
        guard let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return false
        }
        return true
        #endif
    }()

    public static func string(forKey key: String) -> String? {
        guard isAvailable else { return nil }
        return MycoKVS.string(forKey: key)
    }

    public static func data(forKey key: String) -> Data? {
        guard isAvailable else { return nil }
        return MycoKVS.data(forKey: key)
    }

    public static func double(forKey key: String) -> Double {
        guard isAvailable else { return 0 }
        return MycoKVS.double(forKey: key)
    }

    public static func set(_ value: Any?, forKey key: String) {
        guard isAvailable else { return }
        MycoKVS.set(value, forKey: key)
    }

    public static func removeObject(forKey key: String) {
        guard isAvailable else { return }
        MycoKVS.removeObject(forKey: key)
    }

    public static func synchronize() {
        guard isAvailable else { return }
        MycoKVS.synchronize()
    }
}

// MARK: - Sync Envelope Protocol
struct MycoSyncEnvelope: Codable, Sendable {
    enum Action: String, Codable, Sendable {
        case requestSync = "request_sync"
        case fullPayload = "full_payload"
        case smartDevices = "smart_devices"
        case ack = "ack"
    }
    
    var action: Action
    var senderDeviceName: String
    var senderDeviceId: String
    var timestamp: Double
    var database: AppDatabase?
    var smartDevices: [SmartDeviceItem]?
    var deletedItemIDs: [UUID]?
    var deletedTuyaDeviceIDs: [String]?
    var tuyaApiKey: String?
    var tuyaApiSecret: String?
    var tuyaRegion: String?
    var tuyaDeviceID: String?
    var tuyaVerified: Bool?
    var appleUser: AppleUserProfile?
    var itemCount: Int
    
    init(
        action: Action,
        senderDeviceName: String,
        senderDeviceId: String,
        timestamp: Double = Date().timeIntervalSince1970,
        database: AppDatabase? = nil,
        smartDevices: [SmartDeviceItem]? = nil,
        deletedItemIDs: [UUID]? = nil,
        deletedTuyaDeviceIDs: [String]? = nil,
        tuyaApiKey: String? = nil,
        tuyaApiSecret: String? = nil,
        tuyaRegion: String? = nil,
        tuyaDeviceID: String? = nil,
        tuyaVerified: Bool? = nil,
        appleUser: AppleUserProfile? = nil,
        itemCount: Int = 0
    ) {
        self.action = action
        self.senderDeviceName = senderDeviceName
        self.senderDeviceId = senderDeviceId
        self.timestamp = timestamp
        self.database = database
        self.smartDevices = smartDevices
        self.deletedItemIDs = deletedItemIDs
        self.deletedTuyaDeviceIDs = deletedTuyaDeviceIDs
        self.tuyaApiKey = tuyaApiKey
        self.tuyaApiSecret = tuyaApiSecret
        self.tuyaRegion = tuyaRegion
        self.tuyaDeviceID = tuyaDeviceID
        self.tuyaVerified = tuyaVerified
        self.appleUser = appleUser
        self.itemCount = itemCount
    }
}

@MainActor
final class MycoSyncManager: ObservableObject {
    static let shared = MycoSyncManager()
    
    // MARK: - Published State for UI
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date? = nil
    @Published var lastSyncStatus: String = "Gereed"
    @Published var lastSyncTransport: String = "Standby"
    @Published var syncedItemsCount: Int = 0
    @Published var toastMessage: String? = nil
    @Published var showToast: Bool = false
    @Published var hasPendingLocalModifications: Bool = false
    @Published var lastModifiedDate: Date? = nil
    
    // Internal state
    var isApplyingRemoteSync: Bool = false
    private var debounceTimer: Timer? = nil

    func notifyLocalModification() {
        guard !isApplyingRemoteSync else { return }
        self.hasPendingLocalModifications = true
        self.lastModifiedDate = Date()
        self.lastSyncStatus = "Aangepast (klaar voor sync)"
    }
    
    var deviceId: String {
        return MycoCamPairingManager.shared.localCameraId
    }
    
    var deviceName: String {
        return UIDevice.current.name
    }
    
    private init() {
        let savedTimestamp = UserDefaults.standard.double(forKey: "mycolab_last_sync_timestamp")
        if savedTimestamp > 0 {
            self.lastSyncDate = Date(timeIntervalSince1970: savedTimestamp)
        }
    }
    
    // MARK: - Auto Sync Debouncer
    func scheduleAutoSync(immediate: Bool = false) {
        guard !isApplyingRemoteSync else { return }
        guard hasPendingLocalModifications else { return }
        
        debounceTimer?.invalidate()
        if immediate {
            sendSyncPayload(reason: "immediate_change")
            return
        }
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendSyncPayload(reason: "auto_change")
            }
        }
    }
    
    // MARK: - Export Lightweight Sync Database
    func exportLightweightDatabase(from source: AppDatabase) -> AppDatabase {
        var clean = source
        // Strip large GrowLog image buffers (>45KB) for lightweight cloud/peer envelopes without main-thread UIImage recompression
        clean.logs = clean.logs.map { log in
            var sanitized = log
            if let data = log.imageData, data.count > 45_000 {
                sanitized.imageData = nil
            }
            return sanitized
        }
        // User policy: Geen losse foto-synchronisatie over P2P mesh of cloud enveloppes.
        // Foto's blijven lokaal op de camera totdat ze als complete MP4-video worden geexporteerd naar de Pi Hub.
        clean.timelapsePhotos = []
        return clean
    }
    
    func exportLightweightJSON(from source: AppDatabase) -> Data? {
        let clean = exportLightweightDatabase(from: source)
        let encoder = JSONEncoder()
        return try? encoder.encode(clean)
    }
    
    // MARK: - Dedicated Fast Smart Devices Sync
    func syncSmartDevicesToPeersAndCloud(reason: String = "smart_device_changed") {
        guard let store = MycoStore.shared else { return }
        let devices = store.db.smartDevices
        let deletedIDs = store.db.deletedItemIDs
        
        let deletedTuyaIDs = store.db.deletedTuyaDeviceIDs

        let envelope = MycoSyncEnvelope(
            action: .smartDevices,
            senderDeviceName: deviceName,
            senderDeviceId: deviceId,
            timestamp: Date().timeIntervalSince1970,
            smartDevices: devices,
            deletedItemIDs: deletedIDs,
            deletedTuyaDeviceIDs: deletedTuyaIDs,
            tuyaApiKey: store.db.environmentConfig.tuyaApiKey,
            tuyaApiSecret: store.db.environmentConfig.tuyaApiSecret,
            tuyaRegion: store.db.environmentConfig.tuyaRegion,
            tuyaDeviceID: store.db.environmentConfig.tuyaDeviceID,
            tuyaVerified: store.db.environmentConfig.tuyaVerified,
            itemCount: devices.count
        )
        
        guard let encodedEnvelope = try? JSONEncoder().encode(envelope) else { return }
        let base64Payload = encodedEnvelope.base64EncodedString()
        let commandString = "sync:smart_devices:\(base64Payload)"
        
        var sentViaMultipeer = false
        var sentViaLiveKit = false
        
        // 1. Send via Multipeer Wi-Fi / Bluetooth
        sentViaMultipeer = MycoCamPairingManager.shared.sendDataToPeers(encodedEnvelope)
        if !sentViaMultipeer {
            _ = MycoCamPairingManager.shared.sendDirectCommandToPeers(commandString)
        }
        
        // 2. Send via LiveKit WebRTC Cloud Data Channel (4G/5G) ONLY IF already actively connected (0 extra tokens)
        if LiveKitStreamManager.shared.isConnected {
            LiveKitStreamManager.shared.publishSyncData(encodedEnvelope)
            LiveKitStreamManager.shared.sendDataCommand(command: commandString)
            sentViaLiveKit = true
        }
        
        // 3. Update iCloud KVS immediately
        let nowTs = Date().timeIntervalSince1970
        if let smartDevicesData = try? JSONEncoder().encode(devices) {
            MycoKVS.set(smartDevicesData, forKey: "MycoLabSmartDevicesPayload")
            MycoKVS.set(nowTs, forKey: "MycoLabSmartDevicesTimestamp")
        }
        if let deletedData = try? JSONEncoder().encode(deletedIDs) {
            MycoKVS.set(deletedData, forKey: "MycoLabDeletedItemIDsPayload")
        }
        if let deletedTuyaData = try? JSONEncoder().encode(deletedTuyaIDs) {
            MycoKVS.set(deletedTuyaData, forKey: "MycoLabDeletedTuyaIDsPayload")
        }
        if !store.db.environmentConfig.tuyaApiKey.isEmpty {
            let tuyaDict: [String: Any] = [
                "tuyaApiKey": store.db.environmentConfig.tuyaApiKey,
                "tuyaApiSecret": store.db.environmentConfig.tuyaApiSecret,
                "tuyaRegion": store.db.environmentConfig.tuyaRegion,
                "tuyaDeviceID": store.db.environmentConfig.tuyaDeviceID,
                "tuyaVerified": store.db.environmentConfig.tuyaVerified
            ]
            if let tData = try? JSONSerialization.data(withJSONObject: tuyaDict) {
                MycoKVS.set(tData, forKey: "MycoLabTuyaCredentials")
            }
        }
        MycoKVS.synchronize()
        
        let transportName = sentViaMultipeer && sentViaLiveKit ? "Wi-Fi & LiveKit" : (sentViaMultipeer ? "Wi-Fi P2P" : (sentViaLiveKit ? "4G/5G LiveKit" : "iCloud KVS"))
        self.lastSyncTransport = transportName
        self.lastSyncDate = Date()
        self.lastSyncStatus = "Plugs Synchronized (\(transportName))"
        self.hasPendingLocalModifications = false
        MycoStore.shared?.hasPendingLocalModifications = false
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "mycolab_last_sync_timestamp")
    }
    
    // MARK: - Send Sync Payload
    func sendSyncPayload(reason: String = "manual") {
        guard let store = MycoStore.shared else { return }
        
        let cleanDB = exportLightweightDatabase(from: store.db)
        let totalItems = cleanDB.projects.count + cleanDB.cultures.count + cleanDB.strains.count + cleanDB.stash.count + cleanDB.supplies.count + cleanDB.smartDevices.count
        
        let envelope = MycoSyncEnvelope(
            action: .fullPayload,
            senderDeviceName: deviceName,
            senderDeviceId: deviceId,
            timestamp: Date().timeIntervalSince1970,
            database: cleanDB,
            appleUser: store.appleUser,
            itemCount: totalItems
        )
        
        guard let encoded = try? JSONEncoder().encode(envelope) else { return }
        
        var sentViaMultipeer = false
        var sentViaLiveKit = false
        
        // 1. Send via Multipeer Wi-Fi / Bluetooth (instant local P2P)
        sentViaMultipeer = MycoCamPairingManager.shared.sendDataToPeers(encoded)
        
        // 2. Send via LiveKit WebRTC Cloud Data Channel (4G/5G) ONLY IF already actively connected (0 extra tokens)
        if LiveKitStreamManager.shared.isConnected {
            LiveKitStreamManager.shared.publishSyncData(encoded)
            sentViaLiveKit = true
        }
        
        // 3. Update iCloud KVS (both full payload and fast dedicated smartDevices payload)
        if store.db.environmentConfig.enableRemoteCloudSync {
            let nowTs = Date().timeIntervalSince1970
            MycoKVS.set(encoded, forKey: "MycoLabCloudPayload")
            MycoKVS.set(nowTs, forKey: "MycoLabCloudTimestamp")
            if let smartDevicesData = try? JSONEncoder().encode(cleanDB.smartDevices) {
                MycoKVS.set(smartDevicesData, forKey: "MycoLabSmartDevicesPayload")
                MycoKVS.set(nowTs, forKey: "MycoLabSmartDevicesTimestamp")
            }
            if let deletedData = try? JSONEncoder().encode(cleanDB.deletedItemIDs) {
                MycoKVS.set(deletedData, forKey: "MycoLabDeletedItemIDsPayload")
            }
            if let deletedTuyaData = try? JSONEncoder().encode(cleanDB.deletedTuyaDeviceIDs) {
                MycoKVS.set(deletedTuyaData, forKey: "MycoLabDeletedTuyaIDsPayload")
            }
            MycoKVS.synchronize()
        }
        
        let transportName = sentViaMultipeer && sentViaLiveKit ? "Wi-Fi & LiveKit" : (sentViaMultipeer ? "Wi-Fi P2P" : (sentViaLiveKit ? "4G/5G LiveKit" : "iCloud KVS"))
        self.lastSyncTransport = transportName
        self.lastSyncDate = Date()
        self.lastSyncStatus = "Sent (\(transportName))"
        self.hasPendingLocalModifications = false
        MycoStore.shared?.hasPendingLocalModifications = false
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "mycolab_last_sync_timestamp")
    }
    
    // MARK: - Request Sync
    func requestSyncFromConnectedPeers() {
        let envelope = MycoSyncEnvelope(
            action: .requestSync,
            senderDeviceName: deviceName,
            senderDeviceId: deviceId,
            timestamp: Date().timeIntervalSince1970
        )
        
        guard let encoded = try? JSONEncoder().encode(envelope) else { return }
        
        _ = MycoCamPairingManager.shared.sendDataToPeers(encoded)
        if LiveKitStreamManager.shared.isConnected {
            LiveKitStreamManager.shared.publishSyncData(encoded)
        }
        
        // Also trigger iCloud KVS sync check
        MycoStore.shared?.syncCloudData()
    }
    
    // MARK: - Check Payload Type
    func isSyncPayload(_ data: Data) -> Bool {
        if let envelope = try? JSONDecoder().decode(MycoSyncEnvelope.self, from: data) {
            return envelope.action == .requestSync || envelope.action == .fullPayload || envelope.action == .smartDevices || envelope.action == .ack
        }
        return (try? JSONDecoder().decode([SmartDeviceItem].self, from: data)) != nil
    }
    
    // MARK: - Handle Incoming Data Packet (100% Silent in Background)
    func handleIncomingData(_ data: Data, transport: String) {
        if let directDevices = try? JSONDecoder().decode([SmartDeviceItem].self, from: data) {
            mergeIncomingSmartDevices(directDevices)
            self.lastSyncDate = Date()
            self.lastSyncTransport = transport
            self.syncedItemsCount = directDevices.count
            self.lastSyncStatus = "Synchronized (\(transport))"
            self.hasPendingLocalModifications = false
            MycoStore.shared?.hasPendingLocalModifications = false
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "mycolab_last_sync_timestamp")
            return
        }

        guard let envelope = try? JSONDecoder().decode(MycoSyncEnvelope.self, from: data) else {
            return
        }
        
        // Ignore echo of our own packets
        guard envelope.senderDeviceId != deviceId else { return }
        
        switch envelope.action {
        case .requestSync:
            // Peer asked for our database: reply with our current data
            sendSyncPayload(reason: "reply_to_request")
            
        case .smartDevices:
            if let incomingDevices = envelope.smartDevices {
                mergeIncomingSmartDevices(
                    incomingDevices,
                    incomingDeletedIDs: envelope.deletedItemIDs ?? [],
                    incomingDeletedTuyaIDs: envelope.deletedTuyaDeviceIDs ?? [],
                    tuyaApiKey: envelope.tuyaApiKey,
                    tuyaApiSecret: envelope.tuyaApiSecret,
                    tuyaRegion: envelope.tuyaRegion,
                    tuyaDeviceID: envelope.tuyaDeviceID,
                    tuyaVerified: envelope.tuyaVerified
                )
            }
            self.lastSyncDate = Date()
            self.lastSyncTransport = transport
            self.syncedItemsCount = envelope.smartDevices?.count ?? 0
            self.lastSyncStatus = "Synchronized (\(transport))"
            self.hasPendingLocalModifications = false
            MycoStore.shared?.hasPendingLocalModifications = false
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "mycolab_last_sync_timestamp")

        case .fullPayload:
            guard let incomingDB = envelope.database else { return }
            
            let changesCount = mergeIncomingDatabase(incomingDB, appleUser: envelope.appleUser)
            
            self.lastSyncDate = Date()
            self.lastSyncTransport = transport
            self.syncedItemsCount = changesCount
            self.lastSyncStatus = "Synchronized (\(transport))"
            self.hasPendingLocalModifications = false
            MycoStore.shared?.hasPendingLocalModifications = false
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "mycolab_last_sync_timestamp")
            
        case .ack:
            self.lastSyncStatus = "Confirmed by \(envelope.senderDeviceName)"
        }
    }
    
    // MARK: - Direct Mesh & Command Broadcasts
    func onPeerConnected(peerName: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.requestSyncFromConnectedPeers()
            self?.sendSyncPayload(reason: "peer_connected")
            self?.syncSmartDevicesToPeersAndCloud(reason: "peer_connected")
        }
        print("[MycoSyncManager] ⚡ Verbonden met \(peerName) (Wi-Fi)")
    }

    func broadcastDeviceAdded(_ device: SmartDeviceItem) {
        guard let encoded = try? JSONEncoder().encode(device) else { return }
        let base64 = encoded.base64EncodedString()
        let cmd = "plug:add:\(base64)"
        MycoCamPairingManager.shared.sendDirectCommandToPeers(cmd)
        if LiveKitStreamManager.shared.isConnected {
            LiveKitStreamManager.shared.sendDataCommand(command: cmd)
        }
        syncSmartDevicesToPeersAndCloud(reason: "smart_device_added")
        sendSyncPayload(reason: "smart_device_added")
    }

    func broadcastDeviceStateChanged(id: UUID, tuyaId: String, isOn: Bool, trigger: String, name: String) {
        let cleanTrigger = trigger.replacingOccurrences(of: ":", with: " ")
        let cleanName = name.replacingOccurrences(of: ":", with: " ")
        let cmd = "plug:sync_state:\(id.uuidString):\(tuyaId):\(isOn ? "1" : "0"):\(cleanTrigger):\(cleanName):\(self.deviceId)"
        MycoCamPairingManager.shared.sendDirectCommandToPeers(cmd)
        if LiveKitStreamManager.shared.isConnected {
            LiveKitStreamManager.shared.sendDataCommand(command: cmd)
        }
        syncSmartDevicesToPeersAndCloud(reason: "smart_device_state")
    }

    func broadcastDeviceError(id: UUID, revertedIsOn: Bool, error: String, name: String) {
        let cleanError = error.replacingOccurrences(of: ":", with: " ")
        let cleanName = name.replacingOccurrences(of: ":", with: " ")
        let cmd = "plug:sync_error:\(id.uuidString):\(revertedIsOn ? "1" : "0"):\(cleanError):\(cleanName)"
        MycoCamPairingManager.shared.sendDirectCommandToPeers(cmd)
        if LiveKitStreamManager.shared.isConnected {
            LiveKitStreamManager.shared.sendDataCommand(command: cmd)
        }
    }

    func broadcastDeviceDeleted(id: UUID, tuyaId: String, name: String) {
        if let store = MycoStore.shared {
            store.recordDeletion(id)
            if !tuyaId.isEmpty {
                store.recordTuyaDeletion(tuyaId)
            }
        }
        let cleanName = name.replacingOccurrences(of: ":", with: " ")
        let cmd = "plug:delete:\(id.uuidString):\(tuyaId):\(cleanName)"
        MycoCamPairingManager.shared.sendDirectCommandToPeers(cmd)
        if LiveKitStreamManager.shared.isConnected {
            LiveKitStreamManager.shared.sendDataCommand(command: cmd)
        }
        syncSmartDevicesToPeersAndCloud(reason: "smart_device_deleted")
    }

    // MARK: - Incoming P2P Packet Handling
    func handleIncomingP2PPacket(_ data: Data, from peerName: String) {
        // User policy: Geen losse foto's sturen tussen P2P en mesh.
        // Alle foto's worden lokaal bewaard en pas als complete MP4-timelapse video naar de Pi Hub verzonden.

        if let rawText = String(data: data, encoding: .utf8) {
            let (isValid, text) = MycoSecurityManager.shared.verifyAndUnwrapPacket(rawText)

            if text.hasPrefix("timelapse:request_photos") || rawText.hasPrefix("timelapse:request_photos") {
                // User policy: Geen losse foto-overdracht over mesh.
                return
            }

            // LiveKit wake & sleep remote commands (0 tokens)
            if text.hasPrefix("livekit:wake") || rawText.hasPrefix("livekit:wake") {
                Task { @MainActor in
                    await LiveKitStreamManager.shared.wakeFromEcoStandby()
                }
                return
            }
            if text.hasPrefix("livekit:sleep") || rawText.hasPrefix("livekit:sleep") {
                Task { @MainActor in
                    await LiveKitStreamManager.shared.enterEcoStandby()
                }
                return
            }

            // Remote torch commands over P2P (0 tokens)
            if text.hasPrefix("torch:on") || rawText.hasPrefix("torch:on") {
                Task { @MainActor in
                    LiveKitStreamManager.shared.setTorch(on: true)
                }
                return
            }
            if text.hasPrefix("torch:off") || rawText.hasPrefix("torch:off") {
                Task { @MainActor in
                    LiveKitStreamManager.shared.setTorch(on: false)
                }
                return
            }

            // Direct snapshot command for Optical Hygrometer / Remote Timelapse
            if text == "cmd:snapshot" || text == "cmd:snapshot:flash" || text == "cmd:snapshot:wide:flash" || rawText == "cmd:snapshot" || rawText == "cmd:snapshot:flash" || rawText == "cmd:snapshot:wide:flash" || text.hasPrefix("request:snapshot") || rawText.hasPrefix("request:snapshot") {
                let withFlash = (text == "cmd:snapshot:flash" || rawText == "cmd:snapshot:flash" || text == "cmd:snapshot:wide:flash" || rawText == "cmd:snapshot:wide:flash")
                let isWide = (text == "cmd:snapshot:wide:flash" || rawText == "cmd:snapshot:wide:flash")
                print("[MycoSyncManager] P2P snapshot command received from \(peerName), withFlash: \(withFlash), isWide: \(isWide)")
                Task { @MainActor in
                    if isWide {
                        await LiveKitStreamManager.shared.selectCameraByType("wide")
                        try? await Task.sleep(nanoseconds: 350_000_000)
                    }
                    _ = await LiveKitStreamManager.shared.captureAndSaveSnapshot(
                        withFlash: withFlash,
                        customCaption: isWide ? "Kweekruimte Overzicht (Optische Scan Flits)" : nil,
                        cameraType: isWide ? "wide" : nil,
                        cameraName: isWide ? "Kweek (1.0x Groothoek)" : nil
                    )
                }
                return
            }

            // Forward camera, lens, stream, torch, screen, timelapse & sensor commands directly to LiveKitStreamManager (0 tokens over P2P!)
            let isControlCmd = text.hasPrefix("camera:") || rawText.hasPrefix("camera:") ||
                text.hasPrefix("get:cams") || rawText.hasPrefix("get:cams") ||
                text.contains("\"cams_sync\"") || rawText.contains("\"cams_sync\"") ||
                text.hasPrefix("screen:sleep") || rawText.hasPrefix("screen:sleep") ||
                text.hasPrefix("timelapse:") || rawText.hasPrefix("timelapse:") ||
                text.hasPrefix("hub:") || rawText.hasPrefix("hub:") ||
                text.hasPrefix("sensor:") || rawText.hasPrefix("sensor:") ||
                text.hasPrefix("torch:") || rawText.hasPrefix("torch:") ||
                text.hasPrefix("focus:") || rawText.hasPrefix("focus:")
            
            if isControlCmd {
                let msg = !text.isEmpty ? text : rawText
                Task { @MainActor in
                    LiveKitStreamManager.shared.handleIncomingControlMessage(msg)
                }
                return
            }

            guard isValid else {
                print("[MycoSecurity] Inkomend P2P commando van \(peerName) afgewezen wegens ongeldige handtekening!")
                return
            }
            // 1. Device Add
            if text.hasPrefix("plug:add:") {
                let base64 = String(text.dropFirst("plug:add:".count))
                if let itemData = Data(base64Encoded: base64),
                   let newDev = try? JSONDecoder().decode(SmartDeviceItem.self, from: itemData),
                   let store = MycoStore.shared {
                    self.isApplyingRemoteSync = true
                    defer { self.isApplyingRemoteSync = false }
                    store.db.deletedItemIDs.removeAll { $0 == newDev.id }
                    if !newDev.tuyaDeviceID.isEmpty {
                        store.db.deletedTuyaDeviceIDs.removeAll { $0 == newDev.tuyaDeviceID }
                    }
                    if let idx = store.db.smartDevices.firstIndex(where: { $0.id == newDev.id || (!newDev.tuyaDeviceID.isEmpty && $0.tuyaDeviceID == newDev.tuyaDeviceID) }) {
                        store.db.smartDevices[idx] = newDev
                    } else {
                        store.db.smartDevices.append(newDev)
                    }
                    store.saveImmediately(fromSync: true)
                    triggerToast(message: "🔌 Apparaat '\(newDev.name)' toegevoegd!")
                }
                return
            }

            // 2. Device Delete
            if text.hasPrefix("plug:delete:") {
                let remainder = String(text.dropFirst("plug:delete:".count))
                let parts = remainder.split(separator: ":", omittingEmptySubsequences: false)
                if parts.count >= 1, let store = MycoStore.shared {
                    self.isApplyingRemoteSync = true
                    defer { self.isApplyingRemoteSync = false }
                    let idStr = String(parts[0])
                    let tuyaId = parts.count > 1 ? String(parts[1]) : ""
                    let devName = parts.count > 2 ? String(parts[2]) : "Apparaat"
                    var didDelete = false
                    if let id = UUID(uuidString: idStr) {
                        let before = store.db.smartDevices.count
                        store.db.smartDevices.removeAll(where: { $0.id == id })
                        store.recordDeletion(id)
                        if store.db.smartDevices.count != before { didDelete = true }
                    }
                    if !tuyaId.isEmpty {
                        let matchedIDs = store.db.smartDevices.filter { $0.tuyaDeviceID == tuyaId }.map { $0.id }
                        for mid in matchedIDs {
                            store.recordDeletion(mid)
                        }
                        let before = store.db.smartDevices.count
                        store.db.smartDevices.removeAll(where: { $0.tuyaDeviceID == tuyaId })
                        store.recordTuyaDeletion(tuyaId)
                        if store.db.smartDevices.count != before { didDelete = true }
                    }
                    store.saveImmediately(fromSync: true)
                    if didDelete {
                        triggerToast(message: "🗑️ '\(devName)' verwijderd")
                    }
                }
                return
            }

            // 3. Device Switch State (Aan / Uit)
            if text.hasPrefix("plug:sync_state:") {
                let remainder = String(text.dropFirst("plug:sync_state:".count))
                let parts = remainder.split(separator: ":", omittingEmptySubsequences: false)
                if parts.count >= 3, let store = MycoStore.shared {
                    let idStr = String(parts[0])
                    let tuyaId = String(parts[1])
                    let targetIsOn = (parts[2] == "1")
                    let trigger = parts.count > 3 && !parts[3].isEmpty ? String(parts[3]) : "Afstandsbediening"
                    let senderId = parts.count > 5 ? String(parts[5]) : ""

                    if senderId == self.deviceId { return }

                    let devUUID = UUID(uuidString: idStr)
                    if let idx = store.db.smartDevices.firstIndex(where: { ($0.id == devUUID && devUUID != nil) || (!tuyaId.isEmpty && $0.tuyaDeviceID == tuyaId) }) {
                        self.isApplyingRemoteSync = true
                        defer { self.isApplyingRemoteSync = false }

                        store.db.smartDevices[idx].isOn = targetIsOn
                        store.db.smartDevices[idx].lastModifiedAt = Date()

                        let logEntry = SmartDeviceLog(
                            id: UUID(),
                            deviceId: store.db.smartDevices[idx].id,
                            deviceName: store.db.smartDevices[idx].name,
                            deviceType: store.db.smartDevices[idx].deviceType,
                            isOn: targetIsOn,
                            timestamp: Date(),
                            trigger: "\(trigger) (\(peerName))",
                            isSuccess: true,
                            errorMessage: nil
                        )
                        store.addSmartDeviceLog(logEntry)
                        store.saveImmediately(fromSync: true)

                        // Silent UI state sync from peer, no toast spam
                    }
                }
                return
            }

            // 4. Device Error / Revert
            if text.hasPrefix("plug:sync_error:") {
                let remainder = String(text.dropFirst("plug:sync_error:".count))
                let parts = remainder.split(separator: ":", omittingEmptySubsequences: false)
                if parts.count >= 3, let store = MycoStore.shared {
                    let idStr = String(parts[0])
                    let revertedIsOn = (parts[1] == "1")
                    let errorMsg = String(parts[2])
                    let devName = parts.count > 3 ? String(parts[3]) : "Apparaat"

                    let devUUID = UUID(uuidString: idStr)
                    if let idx = store.db.smartDevices.firstIndex(where: { $0.id == devUUID && devUUID != nil }) {
                        self.isApplyingRemoteSync = true
                        defer { self.isApplyingRemoteSync = false }

                        // CRITICAL FIX: If revertedIsOn is true (reverting from OFF back to ON due to a failed switch-off),
                        // DO NOT force the device back to ON! Keep it OFF as requested by the user.
                        // ALSO: If device has an active manual override, DO NOT force it back to OFF!
                        if !revertedIsOn && !store.db.smartDevices[idx].isManualOverrideActive {
                            store.db.smartDevices[idx].isOn = false
                        }
                        let logEntry = SmartDeviceLog(
                            id: UUID(),
                            deviceId: store.db.smartDevices[idx].id,
                            deviceName: store.db.smartDevices[idx].name,
                            deviceType: store.db.smartDevices[idx].deviceType,
                            isOn: store.db.smartDevices[idx].isOn,
                            timestamp: Date(),
                            trigger: "Fout bij schakelen",
                            isSuccess: false,
                            errorMessage: errorMsg
                        )
                        store.addSmartDeviceLog(logEntry)
                        store.saveImmediately(fromSync: true)
                        triggerToast(message: "⚠️ Fout bij '\(devName)': \(errorMsg)")
                    }
                }
                return
            }

            // 5. Dedicated Smart Devices Sync
            if text.hasPrefix("sync:smart_devices:") {
                let remainder = String(text.dropFirst("sync:smart_devices:".count))
                if let payloadData = Data(base64Encoded: remainder) {
                    handleIncomingData(payloadData, transport: "Wi-Fi P2P Direct")
                }
                return
            }

            // 6. Legacy Commands (plug:set:)
            if text.hasPrefix("plug:set:") {
                let remainder = String(text.dropFirst("plug:set:".count))
                let parts = remainder.split(separator: ":", omittingEmptySubsequences: false)
                if parts.count >= 3, let store = MycoStore.shared {
                    let idStr = String(parts[0])
                    let tuyaId = String(parts[1])
                    let targetIsOn = (parts[2] == "1")
                    let devUUID = UUID(uuidString: idStr)
                    if let idx = store.db.smartDevices.firstIndex(where: { ($0.id == devUUID && devUUID != nil) || (!tuyaId.isEmpty && $0.tuyaDeviceID == tuyaId) }) {
                        self.isApplyingRemoteSync = true
                        defer { self.isApplyingRemoteSync = false }

                        store.db.smartDevices[idx].isOn = targetIsOn
                        store.saveImmediately(fromSync: true)
                        // Silent UI state sync from peer, no toast spam
                    }
                }
                return
            }
        }

        handleIncomingData(data, transport: "Wi-Fi P2P")
    }

    // MARK: - Toast Notification
    private var lastToastTime: Date = Date.distantPast
    private var lastToastMsg: String = ""

    func triggerToast(message: String) {
        let now = Date()
        // Prevent duplicate toast within 3s or back-to-back spam within 1.2s
        if message == lastToastMsg && now.timeIntervalSince(lastToastTime) < 3.0 {
            return
        }
        if now.timeIntervalSince(lastToastTime) < 1.2 {
            return
        }
        lastToastTime = now
        lastToastMsg = message

        withAnimation(.easeInOut(duration: 0.2)) {
            self.toastMessage = message
            self.showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                if self.toastMessage == message {
                    self.showToast = false
                    self.toastMessage = nil
                }
            }
        }
    }
    
    func clearDeletedTuyaID(_ tuyaId: String = "") {
        MycoKVS.removeObject(forKey: "MycoLabDeletedTuyaIDsPayload")
        MycoKVS.synchronize()
    }
    
    // MARK: - LiveKit Events
    func onLiveKitConnected() {
        requestSyncFromConnectedPeers()
        sendSyncPayload(reason: "livekit_connected")
    }
    
    // MARK: - Smart Merge Engine (Union Merge with Tombstones)
    @discardableResult
    func mergeIncomingDatabase(_ incoming: AppDatabase, appleUser: AppleUserProfile?) -> Int {
        guard let store = MycoStore.shared else { return 0 }
        
        self.isApplyingRemoteSync = true
        defer {
            self.isApplyingRemoteSync = false
        }
        
        var modified = false
        var changedCount = 0
        
        // 1. Sync Apple User Profile if remote is logged in and local is not
        if let incomingUser = appleUser, store.appleUser == nil {
            store.saveAppleUser(incomingUser)
            modified = true
        }
        
        var draft = store.db
        let existingDeletedSet = Set(draft.deletedItemIDs)
        let deletedIDs = existingDeletedSet.union(incoming.deletedItemIDs)
        let existingDeletedTuyaSet = Set(draft.deletedTuyaDeviceIDs)
        let deletedTuyaIDs = existingDeletedTuyaSet.union(incoming.deletedTuyaDeviceIDs)
        
        if deletedIDs.count != existingDeletedSet.count || deletedTuyaIDs.count != existingDeletedTuyaSet.count {
            draft.deletedItemIDs = Array(deletedIDs)
            draft.deletedTuyaDeviceIDs = Array(deletedTuyaIDs)
            modified = true
        }
        
        // Prune any local items that were deleted on the peer device (Tombstone enforcement)
        if !deletedIDs.isEmpty || !deletedTuyaIDs.isEmpty {
            let beforeSmartCount = draft.smartDevices.count
            draft.smartDevices.removeAll { dev in
                deletedIDs.contains(dev.id) || (!dev.tuyaDeviceID.isEmpty && deletedTuyaIDs.contains(dev.tuyaDeviceID))
            }
            if draft.smartDevices.count != beforeSmartCount {
                changedCount += (beforeSmartCount - draft.smartDevices.count)
                modified = true
            }
            
            let beforeProjects = draft.projects.count
            draft.projects.removeAll { deletedIDs.contains($0.id) }
            if draft.projects.count != beforeProjects { modified = true }
            
            let beforeCultures = draft.cultures.count
            draft.cultures.removeAll { deletedIDs.contains($0.id) }
            if draft.cultures.count != beforeCultures { modified = true }
            
            let beforeStrains = draft.strains.count
            draft.strains.removeAll { deletedIDs.contains($0.id) }
            if draft.strains.count != beforeStrains { modified = true }
            
            let beforeStash = draft.stash.count
            draft.stash.removeAll { deletedIDs.contains($0.id) }
            if draft.stash.count != beforeStash { modified = true }
            
            let beforeSupplies = draft.supplies.count
            draft.supplies.removeAll { deletedIDs.contains($0.id) }
            if draft.supplies.count != beforeSupplies { modified = true }
            
            let beforePresets = draft.presets.count
            draft.presets.removeAll { deletedIDs.contains($0.id) }
            if draft.presets.count != beforePresets { modified = true }
            
            let beforePrep = draft.preparationRecipes.count
            draft.preparationRecipes.removeAll { deletedIDs.contains($0.id) }
            if draft.preparationRecipes.count != beforePrep { modified = true }
            
            let beforeSterilization = draft.sterilizationPresets.count
            draft.sterilizationPresets.removeAll { deletedIDs.contains($0.id) }
            if draft.sterilizationPresets.count != beforeSterilization { modified = true }
            
            let beforeCustomQR = draft.customQRCodes.count
            draft.customQRCodes.removeAll { deletedIDs.contains($0.id) }
            if draft.customQRCodes.count != beforeCustomQR { modified = true }
            
            let beforeTimers = draft.timers.count
            draft.timers.removeAll { deletedIDs.contains($0.id) }
            if draft.timers.count != beforeTimers { modified = true }
            
            let beforeLogs = draft.logs.count
            draft.logs.removeAll { deletedIDs.contains($0.id) }
            if draft.logs.count != beforeLogs { modified = true }
            
            let beforeHarvests = draft.harvests.count
            draft.harvests.removeAll { deletedIDs.contains($0.id) }
            if draft.harvests.count != beforeHarvests { modified = true }
        }
        
        // 2. Merge Strains
        for item in incoming.strains where !deletedIDs.contains(item.id) {
            if let idx = draft.strains.firstIndex(where: { $0.id == item.id || (!item.name.isEmpty && $0.name.lowercased() == item.name.lowercased()) }) {
                let localTime = draft.strains[idx].lastModifiedAt ?? draft.strains[idx].dateCreated
                let incomingTime = item.lastModifiedAt ?? item.dateCreated
                if incomingTime >= localTime {
                    draft.strains[idx] = item
                    modified = true
                } else if item != draft.strains[idx] {
                    draft.strains[idx] = item
                    modified = true
                }
            } else {
                draft.strains.append(item)
                changedCount += 1
                modified = true
            }
        }
        
        // 3. Merge Cultures
        for item in incoming.cultures where !deletedIDs.contains(item.id) {
            if let idx = draft.cultures.firstIndex(where: { $0.id == item.id }) {
                let localTime = draft.cultures[idx].lastModifiedAt ?? draft.cultures[idx].dateCreated
                let incomingTime = item.lastModifiedAt ?? item.dateCreated
                if incomingTime >= localTime {
                    draft.cultures[idx] = item
                    modified = true
                } else if item != draft.cultures[idx] {
                    draft.cultures[idx] = item
                    modified = true
                }
            } else {
                draft.cultures.append(item)
                changedCount += 1
                modified = true
            }
        }
        
        // 4. Merge Grow Projects
        for item in incoming.projects where !deletedIDs.contains(item.id) {
            if let idx = draft.projects.firstIndex(where: { $0.id == item.id }) {
                let localTime = draft.projects[idx].lastModifiedAt ?? draft.projects[idx].startDate
                let incomingTime = item.lastModifiedAt ?? item.startDate
                if incomingTime >= localTime {
                    draft.projects[idx] = item
                    modified = true
                } else if item.phase != draft.projects[idx].phase || item.colonizationPercent != draft.projects[idx].colonizationPercent {
                    draft.projects[idx].phase = item.phase
                    draft.projects[idx].colonizationPercent = item.colonizationPercent
                    draft.projects[idx].lastModifiedAt = max(incomingTime, localTime)
                    modified = true
                } else if item != draft.projects[idx] {
                    draft.projects[idx] = item
                    modified = true
                }
            } else {
                draft.projects.append(item)
                changedCount += 1
                modified = true
            }
        }
        
        // 5. Merge Logs
        for item in incoming.logs where !deletedIDs.contains(item.id) {
            if !draft.logs.contains(where: { $0.id == item.id }) {
                draft.logs.insert(item, at: 0)
                changedCount += 1
                modified = true
            }
        }
        
        // 6. Merge Harvests
        for item in incoming.harvests where !deletedIDs.contains(item.id) {
            if !draft.harvests.contains(where: { $0.id == item.id }) {
                draft.harvests.insert(item, at: 0)
                changedCount += 1
                modified = true
            }
        }
        
        // 7. Merge Stash Jars
        for item in incoming.stash where !deletedIDs.contains(item.id) {
            if let idx = draft.stash.firstIndex(where: { $0.id == item.id }) {
                if item.lastUpdated > draft.stash[idx].lastUpdated {
                    draft.stash[idx] = item
                    modified = true
                }
            } else {
                draft.stash.append(item)
                changedCount += 1
                modified = true
            }
        }
        
        // 8. Merge Supplies
        for item in incoming.supplies where !deletedIDs.contains(item.id) {
            if let idx = draft.supplies.firstIndex(where: { $0.id == item.id || (!item.name.isEmpty && $0.name.lowercased() == item.name.lowercased() && $0.category == item.category) }) {
                if item.lastUpdated >= draft.supplies[idx].lastUpdated {
                    draft.supplies[idx] = item
                    modified = true
                } else if item.quantity != draft.supplies[idx].quantity {
                    draft.supplies[idx] = item
                    modified = true
                }
            } else {
                draft.supplies.append(item)
                changedCount += 1
                modified = true
            }
        }
        
        // 9. Merge Smart Devices (Distinguish locally modified values from synchronized values)
        var smartDevicesChanged = false

        let beforeSmartCount2 = draft.smartDevices.count
        draft.smartDevices.removeAll { dev in
            deletedIDs.contains(dev.id) || (!dev.tuyaDeviceID.isEmpty && deletedTuyaIDs.contains(dev.tuyaDeviceID))
        }
        if draft.smartDevices.count != beforeSmartCount2 {
            modified = true
            smartDevicesChanged = true
        }

        for item in incoming.smartDevices where !deletedIDs.contains(item.id) && (item.tuyaDeviceID.isEmpty || !deletedTuyaIDs.contains(item.tuyaDeviceID)) {
            if let idx = draft.smartDevices.firstIndex(where: {
                $0.id == item.id || (!item.tuyaDeviceID.isEmpty && $0.tuyaDeviceID == item.tuyaDeviceID)
            }) {
                var cur = draft.smartDevices[idx]
                if cur.id != item.id {
                    cur.id = item.id
                    modified = true
                    smartDevicesChanged = true
                }
                
                // Distinguish modified value (local) from synchronized value (incoming):
                if item.lastModifiedAt > cur.lastModifiedAt {
                    cur.applySynchronized(from: item)
                    modified = true
                    smartDevicesChanged = true
                } else if item.lastModifiedAt == cur.lastModifiedAt {
                    if cur.isOn != item.isOn {
                        cur.isOn = item.isOn
                        cur.lastModifiedAt = item.lastModifiedAt
                        modified = true
                        smartDevicesChanged = true
                    }
                    if let t = item.currentTempC { cur.currentTempC = t }
                    if let h = item.currentHumidityPct { cur.currentHumidityPct = h }
                    if let lr = item.lastReadingTime { cur.lastReadingTime = lr }
                    if let lc = item.lastCustomExecutionTime { cur.lastCustomExecutionTime = lc }
                } else {
                    // cur.lastModifiedAt > item.lastModifiedAt:
                    // Local modification is newer ("aangepaste waarde"). Do NOT overwrite with older remote!
                }
                
                draft.smartDevices[idx] = cur
            } else {
                draft.smartDevices.append(item)
                changedCount += 1
                modified = true
                smartDevicesChanged = true
            }
        }
        
        // 9b. Merge Smart Device Logs (with 4-second deduplication)
        var logsAdded = false
        for item in incoming.smartDeviceLogs where !deletedIDs.contains(item.id) {
            let isDuplicate = draft.smartDeviceLogs.contains(where: {
                $0.id == item.id ||
                ($0.deviceId == item.deviceId && $0.isOn == item.isOn && abs($0.timestamp.timeIntervalSince(item.timestamp)) < 4.0)
            })
            if !isDuplicate {
                draft.smartDeviceLogs.append(item)
                changedCount += 1
                modified = true
                logsAdded = true
            }
        }
        if logsAdded {
            draft.smartDeviceLogs.sort(by: { $0.timestamp > $1.timestamp })
            if draft.smartDeviceLogs.count > 250 {
                draft.smartDeviceLogs = Array(draft.smartDeviceLogs.prefix(250))
            }
        }
        
        // 10. Merge Timers
        for item in incoming.timers where !deletedIDs.contains(item.id) {
            if !draft.timers.contains(where: { $0.id == item.id }) {
                draft.timers.append(item)
                changedCount += 1
                modified = true
            }
        }
        
        // 11. Merge Environment Config (Timestamp-aware: distinguishes modified vs synchronized)
        let incomingConfigTime = incoming.environmentConfig.lastModifiedAt ?? Date.distantPast
        let localConfigTime = draft.environmentConfig.lastModifiedAt ?? Date.distantPast

        if incomingConfigTime > localConfigTime {
            draft.environmentConfig.applySynchronized(from: incoming.environmentConfig)
            modified = true
            smartDevicesChanged = true
        } else if incomingConfigTime == localConfigTime {
            // Adopt credentials if local was blank
            if draft.environmentConfig.tuyaApiKey.isEmpty && !incoming.environmentConfig.tuyaApiKey.isEmpty {
                draft.environmentConfig.applySynchronized(from: incoming.environmentConfig)
                modified = true
                smartDevicesChanged = true
            }
            // Sync Autopilot execution timestamps so Viewer & Hub share exact countdowns
            if let incomingFaeTime = incoming.environmentConfig.lastFaeExecutionTime {
                if draft.environmentConfig.lastFaeExecutionTime == nil || incomingFaeTime > draft.environmentConfig.lastFaeExecutionTime! {
                    draft.environmentConfig.lastFaeExecutionTime = incomingFaeTime
                    modified = true
                }
            }
            if let incomingHumTime = incoming.environmentConfig.lastHumidifierExecutionTime {
                if draft.environmentConfig.lastHumidifierExecutionTime == nil || incomingHumTime > draft.environmentConfig.lastHumidifierExecutionTime! {
                    draft.environmentConfig.lastHumidifierExecutionTime = incomingHumTime
                    modified = true
                }
            }
        } else {
            // localConfigTime > incomingConfigTime:
            // Local modification is newer ("aangepaste waarde"). Keep local!
        }
        
        // 12. Merge Custom QR Codes
        for item in incoming.customQRCodes where !deletedIDs.contains(item.id) {
            if !draft.customQRCodes.contains(where: { $0.id == item.id }) {
                draft.customQRCodes.append(item)
                changedCount += 1
                modified = true
            }
        }
        
        // 13. Merge User Presets
        for item in incoming.presets where !deletedIDs.contains(item.id) {
            if !draft.presets.contains(where: { $0.id == item.id }) {
                draft.presets.append(item)
                changedCount += 1
                modified = true
            }
        }
        
        // 13b. Merge Sterilization Presets
        for item in incoming.sterilizationPresets where !deletedIDs.contains(item.id) {
            if !draft.sterilizationPresets.contains(where: { $0.id == item.id }) {
                draft.sterilizationPresets.append(item)
                changedCount += 1
                modified = true
            }
        }
        
        // 13c. Merge Preparation Recipes
        for item in incoming.preparationRecipes where !deletedIDs.contains(item.id) {
            if !draft.preparationRecipes.contains(where: { $0.id == item.id }) {
                draft.preparationRecipes.append(item)
                changedCount += 1
                modified = true
            }
        }
        
        // 14. Merge Timelapse Gallery Photos
        for item in incoming.timelapsePhotos where !deletedIDs.contains(item.id) {
            if let idx = draft.timelapsePhotos.firstIndex(where: { $0.id == item.id }) {
                if draft.timelapsePhotos[idx].imageData == nil && item.imageData != nil {
                    draft.timelapsePhotos[idx].imageData = item.imageData
                    modified = true
                }
            } else {
                draft.timelapsePhotos.append(item)
                changedCount += 1
                modified = true
            }
        }
        draft.timelapsePhotos.sort(by: { $0.timestamp > $1.timestamp })
        if draft.timelapsePhotos.count > 100 {
            draft.timelapsePhotos = Array(draft.timelapsePhotos.prefix(100))
        }
        
        // Merge latest sensor readings if incoming reading is newer
        if let incomingReadingTime = incoming.environmentConfig.latestSensorReadingTime {
            let localReadingTime = draft.environmentConfig.latestSensorReadingTime ?? Date.distantPast
            if incomingReadingTime > localReadingTime {
                draft.environmentConfig.latestSensorTempC = incoming.environmentConfig.latestSensorTempC
                draft.environmentConfig.latestSensorHumidityPct = incoming.environmentConfig.latestSensorHumidityPct
                draft.environmentConfig.latestSensorCo2Ppm = incoming.environmentConfig.latestSensorCo2Ppm
                draft.environmentConfig.latestSensorReadingTime = incomingReadingTime
                draft.environmentConfig.sensorDeviceName = incoming.environmentConfig.sensorDeviceName
                if !incoming.environmentConfig.lastAutopilotLogMessage.isEmpty {
                    draft.environmentConfig.lastAutopilotLogMessage = incoming.environmentConfig.lastAutopilotLogMessage
                    draft.environmentConfig.lastAutopilotLogTime = incoming.environmentConfig.lastAutopilotLogTime
                }
                modified = true
            }
        }
        
        if let incomingBatteryTime = incoming.environmentConfig.cameraBatteryLastUpdated {
            let localBatteryTime = draft.environmentConfig.cameraBatteryLastUpdated ?? Date.distantPast
            if incomingBatteryTime > localBatteryTime {
                draft.environmentConfig.cameraBatteryLevel = incoming.environmentConfig.cameraBatteryLevel
                draft.environmentConfig.cameraIsCharging = incoming.environmentConfig.cameraIsCharging
                draft.environmentConfig.cameraBatteryLastUpdated = incomingBatteryTime
                modified = true
            }
        }
        
        if modified {
            store.db = draft
            store.saveFromSync()
            if smartDevicesChanged && (LiveKitStreamManager.shared.currentRole == .broadcaster || MycoBackgroundHubManager.shared.isStreamHubRoleActive) {
                store.startAutopilotEngine()
            }
        }
        
        return changedCount
    }
    
    // MARK: - Dedicated Fast Smart Devices Merge (from iCloud KVS or Peer)
    func mergeIncomingSmartDevices(
        _ incomingDevices: [SmartDeviceItem],
        incomingDeletedIDs: [UUID] = [],
        incomingDeletedTuyaIDs: [String] = [],
        tuyaApiKey: String? = nil,
        tuyaApiSecret: String? = nil,
        tuyaRegion: String? = nil,
        tuyaDeviceID: String? = nil,
        tuyaVerified: Bool? = nil
    ) {
        guard let store = MycoStore.shared else { return }
        self.isApplyingRemoteSync = true
        defer { self.isApplyingRemoteSync = false }
        
        var draft = store.db
        var modified = false
        
        let deletedSet = Set(draft.deletedItemIDs).union(incomingDeletedIDs)
        let deletedTuyaSet = Set(draft.deletedTuyaDeviceIDs).union(incomingDeletedTuyaIDs)
        
        if deletedSet.count != draft.deletedItemIDs.count || deletedTuyaSet.count != draft.deletedTuyaDeviceIDs.count {
            draft.deletedItemIDs = Array(deletedSet)
            draft.deletedTuyaDeviceIDs = Array(deletedTuyaSet)
            modified = true
        }
        
        let beforeCount = draft.smartDevices.count
        draft.smartDevices.removeAll { dev in
            deletedSet.contains(dev.id) || (!dev.tuyaDeviceID.isEmpty && deletedTuyaSet.contains(dev.tuyaDeviceID))
        }
        if draft.smartDevices.count != beforeCount {
            modified = true
        }
        
        for item in incomingDevices where !deletedSet.contains(item.id) && (item.tuyaDeviceID.isEmpty || !deletedTuyaSet.contains(item.tuyaDeviceID)) {
            if let idx = draft.smartDevices.firstIndex(where: {
                $0.id == item.id || (!item.tuyaDeviceID.isEmpty && $0.tuyaDeviceID == item.tuyaDeviceID)
            }) {
                var cur = draft.smartDevices[idx]
                if cur.id != item.id {
                    cur.id = item.id
                    modified = true
                }
                
                // Distinguish modified value (local) from synchronized value (incoming):
                if item.lastModifiedAt > cur.lastModifiedAt {
                    cur.applySynchronized(from: item)
                    modified = true
                } else if item.lastModifiedAt == cur.lastModifiedAt {
                    if cur.isOn != item.isOn {
                        cur.isOn = item.isOn
                        cur.lastModifiedAt = item.lastModifiedAt
                        modified = true
                    }
                    if let t = item.currentTempC { cur.currentTempC = t }
                    if let h = item.currentHumidityPct { cur.currentHumidityPct = h }
                    if let lr = item.lastReadingTime { cur.lastReadingTime = lr }
                    if let le = item.lastCustomExecutionTime { cur.lastCustomExecutionTime = le }
                } else {
                    // cur.lastModifiedAt > item.lastModifiedAt:
                    // Local modification is newer ("aangepaste waarde"). Keep local value!
                }
                draft.smartDevices[idx] = cur
            } else {
                draft.smartDevices.append(item)
                modified = true
            }
        }
        
        // Adopt Tuya credentials if provided
        if let key = tuyaApiKey, !key.isEmpty, draft.environmentConfig.tuyaApiKey != key {
            draft.environmentConfig.tuyaApiKey = key
            modified = true
        }
        if let sec = tuyaApiSecret, !sec.isEmpty, draft.environmentConfig.tuyaApiSecret != sec {
            draft.environmentConfig.tuyaApiSecret = sec
            modified = true
        }
        if let reg = tuyaRegion, !reg.isEmpty, draft.environmentConfig.tuyaRegion != reg {
            draft.environmentConfig.tuyaRegion = reg
            modified = true
        }
        if let devId = tuyaDeviceID, !devId.isEmpty, draft.environmentConfig.tuyaDeviceID != devId {
            draft.environmentConfig.tuyaDeviceID = devId
            modified = true
        }
        if let ver = tuyaVerified, draft.environmentConfig.tuyaVerified != ver {
            draft.environmentConfig.tuyaVerified = ver
            modified = true
        }
        
        if modified {
            store.db = draft
            store.saveFromSync()
            // Silent background adoption of smart devices without banner spam
            if LiveKitStreamManager.shared.currentRole == .broadcaster || MycoBackgroundHubManager.shared.isStreamHubRoleActive {
                store.startAutopilotEngine()
            }
        }
    }
}
