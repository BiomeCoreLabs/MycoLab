//
//  LiveKitTokenGenerator.swift
//  MycoLab
//
//  Generates LiveKit compatible JWT tokens on-device using CryptoKit (HMAC-SHA256),
//  or fetches them securely from an optional external token authentication endpoint.
//

import Foundation
import CryptoKit

nonisolated public enum LiveKitTokenGenerator: Sendable {
    public static let defaultServerUrl = "ws://192.168.1.100:7880"
    public static let defaultApiKey = "mycolab_key"
    public static let defaultApiSecret = "mycolab_secret_lab_key_2026"
    public static let defaultRoom = "mycolab-grow-room"

    private static let keyServerUrl = "mycolab_livekit_server_url"
    private static let keyApiKey = "mycolab_livekit_api_key"
    private static let keyApiSecret = "mycolab_livekit_api_secret"
    private static let keyRoom = "mycolab_livekit_room"
    private static let keyTokenEndpoint = "mycolab_livekit_token_endpoint"

    public static var currentServerUrl: String {
        let stored = UserDefaults.standard.string(forKey: keyServerUrl)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? defaultServerUrl : stored
    }

    public static var currentApiKey: String {
        let stored = UserDefaults.standard.string(forKey: keyApiKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? defaultApiKey : stored
    }

    public static var currentApiSecret: String {
        let stored = UserDefaults.standard.string(forKey: keyApiSecret)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? defaultApiSecret : stored
    }

    public static var currentRoom: String {
        let stored = UserDefaults.standard.string(forKey: keyRoom)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? defaultRoom : stored
    }

    public static var tokenEndpointURL: String? {
        let stored = UserDefaults.standard.string(forKey: keyTokenEndpoint)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? nil : stored
    }

    public static func saveConfiguration(
        serverUrl: String? = nil,
        apiKey: String? = nil,
        apiSecret: String? = nil,
        room: String? = nil,
        tokenEndpointURL: String? = nil
    ) {
        if let s = serverUrl { UserDefaults.standard.set(s, forKey: keyServerUrl) }
        if let k = apiKey { UserDefaults.standard.set(k, forKey: keyApiKey) }
        if let sec = apiSecret { UserDefaults.standard.set(sec, forKey: keyApiSecret) }
        if let r = room { UserDefaults.standard.set(r, forKey: keyRoom) }
        if let ep = tokenEndpointURL { UserDefaults.standard.set(ep, forKey: keyTokenEndpoint) }
    }

    public static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: keyServerUrl)
        UserDefaults.standard.removeObject(forKey: keyApiKey)
        UserDefaults.standard.removeObject(forKey: keyApiSecret)
        UserDefaults.standard.removeObject(forKey: keyRoom)
        UserDefaults.standard.removeObject(forKey: keyTokenEndpoint)
    }

    public static func switchToPiLabHub() {
        saveConfiguration(
            serverUrl: defaultServerUrl,
            apiKey: defaultApiKey,
            apiSecret: defaultApiSecret,
            room: defaultRoom
        )
    }

    /// Fetches token from remote endpoint if configured; otherwise generates locally with HMAC-SHA256
    public static func fetchOrGenerateToken(
        identity: String,
        room: String? = nil,
        name: String? = nil,
        canPublish: Bool = true,
        canSubscribe: Bool = true,
        durationInHours: Double = 72
    ) async -> String? {
        let targetRoom = room ?? currentRoom
        if let endpointStr = tokenEndpointURL,
           let url = URL(string: "\(endpointStr)?room=\(targetRoom)&identity=\(identity)&publish=\(canPublish)&subscribe=\(canSubscribe)") {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !token.isEmpty {
                return token
            }
        }

        return generateToken(
            apiKey: currentApiKey,
            apiSecret: currentApiSecret,
            room: targetRoom,
            identity: identity,
            name: name,
            canPublish: canPublish,
            canSubscribe: canSubscribe,
            durationInHours: durationInHours
        )
    }

    public static func generateToken(
        apiKey: String = currentApiKey,
        apiSecret: String = currentApiSecret,
        room: String = currentRoom,
        identity: String,
        name: String? = nil,
        canPublish: Bool = true,
        canSubscribe: Bool = true,
        durationInHours: Double = 72
    ) -> String? {
        let now = Date().timeIntervalSince1970
        let exp = now + (durationInHours * 3600)
        let nbf = now - 60 // 1 minute clock skew tolerance

        let headerDict: [String: Any] = [
            "alg": "HS256",
            "typ": "JWT"
        ]

        var videoDict: [String: Any] = [
            "room": room,
            "roomJoin": true,
            "canPublish": canPublish,
            "canSubscribe": canSubscribe,
            "canPublishData": true
        ]
        if canPublish {
            videoDict["canPublishSources"] = ["camera", "microphone", "screen_share"]
        }

        var payloadDict: [String: Any] = [
            "exp": Int(exp),
            "nbf": Int(nbf),
            "iss": apiKey,
            "sub": identity,
            "video": videoDict
        ]
        if let name = name {
            payloadDict["name"] = name
        }

        guard let headerData = try? JSONSerialization.data(withJSONObject: headerDict, options: []),
              let payloadData = try? JSONSerialization.data(withJSONObject: payloadDict, options: []) else {
            return nil
        }

        let headerB64 = base64UrlEncoded(headerData)
        let payloadB64 = base64UrlEncoded(payloadData)
        let signingInput = "\(headerB64).\(payloadB64)"

        guard let inputData = signingInput.data(using: .utf8),
              let secretData = apiSecret.data(using: .utf8) else {
            return nil
        }

        let key = SymmetricKey(data: secretData)
        let signature = HMAC<SHA256>.authenticationCode(for: inputData, using: key)
        let signatureB64 = base64UrlEncoded(Data(signature))

        return "\(signingInput).\(signatureB64)"
    }

    private static func base64UrlEncoded(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
