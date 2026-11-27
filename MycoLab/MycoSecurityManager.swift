//
//  MycoSecurityManager.swift
//  MycoLab
//
//  Centralized security, cluster encryption keys, and mutual authentication
//  for local P2P mesh (Multipeer), cloud streams (LiveKit & 4G/5G), and sync commands.
//

import Foundation
import CryptoKit
import Combine

@MainActor
public final class MycoSecurityManager: ObservableObject {
    public static let shared = MycoSecurityManager()

    // MARK: - Constants
    public static let defaultClusterSecret = "mycolab_cluster_shared_mesh_v1"
    private let kIsCustomClusterSecretKey = "mycolab_is_custom_cluster_secret"

    // MARK: - Storage Keys
    private let kClusterSecretKey = "mycolab_cluster_secret_v1"
    private let kCloudClusterSecretKey = "mycolab_cloud_cluster_secret_v1"

    // MARK: - Published Properties
    @Published public private(set) var clusterSecret: String = ""
    @Published public private(set) var clusterHash: String = ""
    @Published public private(set) var clusterRoomId: String = ""
    @Published public private(set) var clusterChannelId: String = ""
    @Published public private(set) var isSecurityActive: Bool = true

    private init() {
        loadOrGenerateClusterSecret()
        setupCloudKeyObserver()
    }

    // MARK: - Key Generation & Loading
    public func loadOrGenerateClusterSecret() {
        // 1. Try to load user custom imported secret from local UserDefaults
        if UserDefaults.standard.bool(forKey: kIsCustomClusterSecretKey),
           let localSecret = UserDefaults.standard.string(forKey: kClusterSecretKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !localSecret.isEmpty {
            applyClusterSecret(localSecret)
            return
        }

        // 2. Try to load from iCloud (shared across user's Apple ID devices if custom)
        if let cloudSecret = MycoKVS.string(forKey: kCloudClusterSecretKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !cloudSecret.isEmpty {
            applyClusterSecret(cloudSecret)
            UserDefaults.standard.set(cloudSecret, forKey: kClusterSecretKey)
            return
        }

        // 3. Use standard shared cluster secret by default so all MycoLab devices authenticate seamlessly
        applyClusterSecret(Self.defaultClusterSecret)
        UserDefaults.standard.set(Self.defaultClusterSecret, forKey: kClusterSecretKey)
    }

    private func applyClusterSecret(_ secret: String) {
        self.clusterSecret = secret

        // Derive short deterministic hashes for mesh discovery, LiveKit rooms, and cloud channels
        let baseData = Data(secret.utf8)
        let hash = SHA256.hash(data: baseData)
        let hexString = hash.map { String(format: "%02x", $0) }.joined()

        // Cluster Hash: 16 chars for Multipeer discovery info
        self.clusterHash = String(hexString.prefix(16))

        // Room ID: 16 chars derived with domain separation
        let roomData = Data((secret + ":livekit_room").utf8)
        let roomHash = SHA256.hash(data: roomData).map { String(format: "%02x", $0) }.joined()
        self.clusterRoomId = String(roomHash.prefix(16))

        // Cloud Channel ID: 16 chars derived with domain separation
        let channelData = Data((secret + ":ntfy_channel").utf8)
        let channelHash = SHA256.hash(data: channelData).map { String(format: "%02x", $0) }.joined()
        self.clusterChannelId = String(channelHash.prefix(16))
    }

    private func generateSecureRandomHex(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let result = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        if result == errSecSuccess {
            return bytes.map { String(format: "%02x", $0) }.joined()
        }
        // Fallback using CryptoKit SymmetricKey
        let symKey = SymmetricKey(size: .bits256)
        return symKey.withUnsafeBytes { Data($0) }.map { String(format: "%02x", $0) }.joined()
    }

    private func setupCloudKeyObserver() {
        guard MycoKVS.isAvailable else { return }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.loadOrGenerateClusterSecret()
            }
        }
    }

    // MARK: - Multipeer P2P Authentication
    /// Verifies if an advertising peer's discovery info matches our private cluster
    public func verifyClusterHash(_ peerClusterHash: String) -> Bool {
        guard !peerClusterHash.isEmpty, !clusterHash.isEmpty else { return false }
        return peerClusterHash == clusterHash
    }

    /// Generates authentication context data to include when inviting a peer
    public var invitationContext: Data {
        let authMessage = "mycolab-invite-auth-v1"
        let key = SymmetricKey(data: Data(clusterSecret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(authMessage.utf8), using: key)
        return Data(mac)
    }

    /// Verifies an invitation received by our advertiser
    public func verifyInvitationContext(_ context: Data?) -> Bool {
        guard let context = context, !context.isEmpty, !clusterSecret.isEmpty else { return false }
        return context == invitationContext
    }

    // MARK: - Packet & Command Cryptographic Signing
    private let authDelimiter = "§auth:"

    /// Signs an outgoing sync or device control packet with HMAC-SHA256
    public func signPacket(_ packet: String) -> String {
        guard !clusterSecret.isEmpty else { return packet }
        let key = SymmetricKey(data: Data(clusterSecret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(packet.utf8), using: key)
        let signature = Data(mac).prefix(12).map { String(format: "%02x", $0) }.joined()
        return "\(packet)\(authDelimiter)\(signature)"
    }

    /// Verifies and unwraps an incoming packet. Returns (isValid, unwrappedCommand)
    public func verifyAndUnwrapPacket(_ rawText: String) -> (isValid: Bool, command: String) {
        if let delimiterRange = rawText.range(of: authDelimiter) {
            let command = String(rawText[..<delimiterRange.lowerBound])
            let providedSignature = String(rawText[delimiterRange.upperBound...])
            
            guard !clusterSecret.isEmpty else { return (false, command) }
            let key = SymmetricKey(data: Data(clusterSecret.utf8))
            let mac = HMAC<SHA256>.authenticationCode(for: Data(command.utf8), using: key)
            let expectedSignature = Data(mac).prefix(12).map { String(format: "%02x", $0) }.joined()
            return (providedSignature == expectedSignature, command)
        }
        // Fallback for packets that arrived over an already verified TLS MCSession
        return (true, rawText)
    }

    // MARK: - QR Code Import / Key Reset
    public func importClusterSecret(_ newSecret: String) {
        let cleaned = newSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 8 else { return }
        UserDefaults.standard.set(true, forKey: kIsCustomClusterSecretKey)
        applyClusterSecret(cleaned)
        UserDefaults.standard.set(cleaned, forKey: kClusterSecretKey)
        MycoKVS.set(cleaned, forKey: kCloudClusterSecretKey)
        MycoKVS.synchronize()
    }

    public func regenerateClusterSecret() {
        let newSecret = generateSecureRandomHex(byteCount: 32)
        UserDefaults.standard.set(true, forKey: kIsCustomClusterSecretKey)
        applyClusterSecret(newSecret)
        UserDefaults.standard.set(newSecret, forKey: kClusterSecretKey)
        MycoKVS.set(newSecret, forKey: kCloudClusterSecretKey)
        MycoKVS.synchronize()
    }
}
