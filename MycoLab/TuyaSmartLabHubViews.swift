//
//  TuyaSmartLabHubViews.swift
//  MycoLab
//
//  Complete Smart Lab & Tuya Stekkers Hub:
//  - Tuya Cloud Open API Manager (v2.0 HMAC-SHA256 signature)
//  - Autonomous Offline Timers & Cloud Schedule Matrix
//  - Diagnostics, Error Logs, Device Switch Cards & Autopilot
//

import AuthenticationServices
import SwiftUI
import CoreData
import CryptoKit
import Security
import UserNotifications
import CoreImage.CIFilterBuiltins
@preconcurrency import AVFoundation
import PhotosUI
import LocalAuthentication
import UIKit
import AudioToolbox
import UniformTypeIdentifiers
import Vision
import MultipeerConnectivity
import LiveKit
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif
import Combine

// MARK: - TUYA CLOUD OPEN API MANAGER (V2.0 SIGNATURE & CONTROLS)
public actor TuyaCloudManager {
    public static let shared = TuyaCloudManager()
    
    public struct TuyaScheduleTask: Sendable, Identifiable {
        public var id: String { "\(aliasName)_\(time)_\(switchCode)_\(value)" }
        public let aliasName: String
        public let time: String // "HH:mm"
        public let switchCode: String
        public let value: Bool
        public let loops: String
        
        public init(aliasName: String, time: String, switchCode: String, value: Bool, loops: String = "1111111") {
            self.aliasName = aliasName
            self.time = time
            self.switchCode = switchCode
            self.value = value
            self.loops = loops
        }
    }
    
    // Strict credential-bound caching: invalidated instantly on any change
    private var cachedClientId: String? = nil
    private var cachedSecret: String? = nil
    private var cachedRegion: String? = nil
    private var cachedToken: String? = nil
    private var tokenExpiry: Date? = nil
    private var cachedUid: String? = nil
    
    public struct DeviceInfo: Sendable, Identifiable {
        public let id: String
        public let name: String
        public let isOnline: Bool
        public let isOn: Bool
        public let switchCode: String
        public let category: String
        public let tempC: Double?
        public let humidityPct: Double?
        
        public init(
            id: String,
            name: String,
            isOnline: Bool,
            isOn: Bool,
            switchCode: String,
            category: String,
            tempC: Double? = nil,
            humidityPct: Double? = nil
        ) {
            self.id = id
            self.name = name
            self.isOnline = isOnline
            self.isOn = isOn
            self.switchCode = switchCode
            self.category = category
            self.tempC = tempC
            self.humidityPct = humidityPct
        }
    }
    
    private func parseStatusList(_ statusList: [[String: Any]]) -> (isOn: Bool, switchCode: String, tempC: Double?, humidityPct: Double?) {
        var isOn = false
        var switchCode = "switch_1"
        var tempC: Double? = nil
        var humidityPct: Double? = nil
        var foundRelaySwitch = false
        
        for item in statusList {
            guard let code = item["code"] as? String else { continue }
            let lowerCode = code.lowercased()
            
            // Check for actual relay switch codes: "switch_1", "switch", "switch_2", "power"
            // Ignore auxiliary non-relay switches like "switch_led", "switch_night_light", "indicator", "child_lock"
            let isAuxiliary = lowerCode.contains("led") || lowerCode.contains("night") || lowerCode.contains("indicator") || lowerCode.contains("child") || lowerCode.contains("lock") || lowerCode.contains("countdown") || lowerCode.contains("timer")
            
            if (lowerCode.contains("switch") || lowerCode == "power") && !isAuxiliary {
                if !foundRelaySwitch || lowerCode == "switch_1" || lowerCode == "switch" {
                    switchCode = code
                    if let val = item["value"] as? Bool {
                        isOn = val
                    }
                    foundRelaySwitch = true
                }
            } else if !foundRelaySwitch && (lowerCode.contains("switch") || lowerCode == "power") {
                if switchCode == "switch_1" {
                    switchCode = code
                }
                if let val = item["value"] as? Bool {
                    isOn = val
                }
            }
            if lowerCode.contains("temp") || lowerCode.contains("va_temperature") {
                if let num = item["value"] as? NSNumber {
                    let d = num.doubleValue
                    tempC = d > 100.0 ? d / 10.0 : d
                }
            }
            if lowerCode.contains("humid") || lowerCode.contains("va_humidity") {
                if let num = item["value"] as? NSNumber {
                    let d = num.doubleValue
                    humidityPct = d > 100.0 ? d / 10.0 : d
                }
            }
        }
        return (isOn, switchCode, tempC, humidityPct)
    }
    
    public func clearCache() {
        cachedClientId = nil
        cachedSecret = nil
        cachedRegion = nil
        cachedToken = nil
        tokenExpiry = nil
        cachedUid = nil
    }
    
    private func baseUrl(for region: String) -> String {
        switch region.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ce", "eu":
            // Tuya Central Europe Data Center (AWS Frankfurt) is openapi.tuyaeu.com
            return "https://openapi.tuyaeu.com"
        case "weaz", "we":
            // Tuya Western Europe Data Center (Microsoft Azure)
            return "https://openapi-weaz.tuyaeu.com"
        case "us":
            // US West (AWS Oregon)
            return "https://openapi.tuyaus.com"
        case "ueaz":
            // US East (Microsoft Azure)
            return "https://openapi-ueaz.tuyaus.com"
        case "cn":
            return "https://openapi.tuyacn.com"
        case "in":
            return "https://openapi.tuyain.com"
        default:
            return "https://openapi.tuyaeu.com"
        }
    }
    
    // Calculates Tuya Open API v2.0 signature
    private func calculateSignature(
        clientId: String,
        secret: String,
        accessToken: String?,
        timestamp: String,
        nonce: String = "",
        httpMethod: String,
        bodyData: Data?,
        urlPathAndQuery: String
    ) -> String {
        let contentHash: String
        if let data = bodyData, !data.isEmpty {
            contentHash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        } else {
            contentHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }
        
        let stringToSign = "\(httpMethod)\n\(contentHash)\n\n\(urlPathAndQuery)"
        let signStr = "\(clientId)\(accessToken ?? "")\(timestamp)\(nonce)\(stringToSign)"
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(signStr.utf8), using: key)
        return signature.compactMap { String(format: "%02x", $0) }.joined().uppercased()
    }
    
    public func getAccessToken(
        clientId: String,
        secret: String,
        region: String,
        forceRefresh: Bool = false
    ) async throws -> (token: String, uid: String) {
        let cleanClientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRegion = region.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !cleanClientId.isEmpty, !cleanSecret.isEmpty else {
            throw NSError(domain: "Tuya", code: -1, userInfo: [NSLocalizedDescriptionKey: "Vul zowel de Access ID (Client ID) als de Secret Key in."])
        }
        
        // Strict cache validation: ONLY use cache if ALL credentials match exactly!
        if !forceRefresh,
           cleanClientId == cachedClientId,
           cleanSecret == cachedSecret,
           cleanRegion == cachedRegion,
           let token = cachedToken,
           let expiry = tokenExpiry,
           expiry > Date().addingTimeInterval(300) {
            return (token, cachedUid ?? "")
        }
        
        let base = baseUrl(for: cleanRegion)
        let pathAndQuery = "/v1.0/token?grant_type=1"
        guard let url = URL(string: "\(base)\(pathAndQuery)") else {
            throw NSError(domain: "Tuya", code: -2, userInfo: [NSLocalizedDescriptionKey: "Ongeldige Tuya API URL."])
        }
        
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
        let sign = calculateSignature(
            clientId: cleanClientId,
            secret: cleanSecret,
            accessToken: nil,
            timestamp: timestamp,
            httpMethod: "GET",
            bodyData: nil,
            urlPathAndQuery: pathAndQuery
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.addValue(cleanClientId, forHTTPHeaderField: "client_id")
        request.addValue(sign, forHTTPHeaderField: "sign")
        request.addValue(timestamp, forHTTPHeaderField: "t")
        request.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Tuya", code: -3, userInfo: [NSLocalizedDescriptionKey: "Geen reactie van de Tuya server."])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let rawStr = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "Tuya", code: -4, userInfo: [NSLocalizedDescriptionKey: "Onleesbaar antwoord van Tuya (HTTP \(httpResponse.statusCode)): \(rawStr)"])
        }
        
        let success = json["success"] as? Bool ?? false
        if !success {
            clearCache()
            let code = json["code"] as? Int ?? httpResponse.statusCode
            let msg = json["msg"] as? String ?? "Onbekende fout"
            let friendly: String
            switch code {
            case 1004:
                friendly = "❌ Signatuur ongeldig (Code 1004): Je Access Secret klopt niet. Controleer of je de geheime sleutel exact hebt overgenomen zonder spaties."
            case 1106, 1114:
                friendly = "❌ Access ID niet herkend (Code \(code)): Tuya kent dit Client ID / Access ID niet. Controleer de invoer."
            case 28841107:
                friendly = "❌ Datacenter Suspended (Code 28841107): Ga naar iot.tuya.com ➜ Cloud ➜ Development ➜ Edit project ➜ verwijder en herselecteer Central Europe om Tuya te verversen."
            default:
                friendly = "❌ Tuya weigert toegang (Code \(code)): \(msg)"
            }
            throw NSError(domain: "Tuya", code: code, userInfo: [NSLocalizedDescriptionKey: friendly])
        }
        
        guard let result = json["result"] as? [String: Any],
              let token = result["access_token"] as? String else {
            clearCache()
            throw NSError(domain: "Tuya", code: -5, userInfo: [NSLocalizedDescriptionKey: "Geen access token ontvangen in de Tuya reactie."])
        }
        
        let expireSeconds = result["expire_time"] as? Double ?? 7200
        let uid = result["uid"] as? String ?? ""
        
        self.cachedClientId = cleanClientId
        self.cachedSecret = cleanSecret
        self.cachedRegion = cleanRegion
        self.cachedToken = token
        self.tokenExpiry = Date().addingTimeInterval(expireSeconds)
        self.cachedUid = uid
        
        return (token, uid)
    }
    
    // Live explicit connection test returning full diagnostic transparency
    public func testConnectionDirect(
        clientId: String,
        secret: String,
        region: String
    ) async -> (success: Bool, message: String, rawJson: String, tuyaCode: Int, uid: String) {
        clearCache()
        let cleanClientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRegion = region.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !cleanClientId.isEmpty, !cleanSecret.isEmpty else {
            return (false, "Vul eerst zowel je Client ID als Access Secret in.", "", -1, "")
        }
        
        let base = baseUrl(for: cleanRegion)
        let pathAndQuery = "/v1.0/token?grant_type=1"
        guard let url = URL(string: "\(base)\(pathAndQuery)") else {
            return (false, "Ongeldige server URL.", "", -2, "")
        }
        
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
        let sign = calculateSignature(
            clientId: cleanClientId,
            secret: cleanSecret,
            accessToken: nil,
            timestamp: timestamp,
            httpMethod: "GET",
            bodyData: nil,
            urlPathAndQuery: pathAndQuery
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.addValue(cleanClientId, forHTTPHeaderField: "client_id")
        request.addValue(sign, forHTTPHeaderField: "sign")
        request.addValue(timestamp, forHTTPHeaderField: "t")
        request.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let rawStr = String(data: data, encoding: .utf8) ?? ""
            let httpResponse = response as? HTTPURLResponse
            let httpCode = httpResponse?.statusCode ?? 0
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return (false, "Geen JSON ontvangen van Tuya (HTTP \(httpCode)).", rawStr, -4, "")
            }
            
            let success = json["success"] as? Bool ?? false
            let code = json["code"] as? Int ?? (success ? 0 : httpCode)
            let msg = json["msg"] as? String ?? ""
            
            if success {
                let result = json["result"] as? [String: Any] ?? [:]
                let uid = result["uid"] as? String ?? ""
                let token = result["access_token"] as? String ?? ""
                let expireSeconds = result["expire_time"] as? Double ?? 7200
                
                self.cachedClientId = cleanClientId
                self.cachedSecret = cleanSecret
                self.cachedRegion = cleanRegion
                self.cachedToken = token
                self.tokenExpiry = Date().addingTimeInterval(expireSeconds)
                self.cachedUid = uid
                
                return (true, "✅ Verbinding 100% Geslaagd! Live geautoriseerd door Tuya Cloud.", rawStr, 0, uid)
            } else {
                let reason: String
                switch code {
                case 1106, 1114:
                    reason = "❌ Tuya weigert: Client ID '\(cleanClientId)' bestaat niet in regio \(cleanRegion.uppercased()) (Code \(code))."
                case 1004:
                    reason = "❌ Tuya weigert: Secret Key is onjuist (Signatuur ongeldig, Code 1004)."
                case 28841107:
                    reason = "❌ Tuya meldt: Datacenter is suspended (Code 28841107). Re-save 'Central Europe' op iot.tuya.com."
                case 28841002, 28841105, 28841101:
                    reason = "❌ Tuya API niet geabonneerd of proefperiode verlopen (Code \(code)). Ga naar iot.tuya.com ➔ Service API ('IoT Core' autoriseren) of verleng gratis via Cloud Services ➔ 'Extend Trial Period'."
                default:
                    if msg.lowercased().contains("subscribe") {
                        reason = "❌ Tuya API niet geabonneerd of proefperiode verlopen (Code \(code)): \(msg). Ga naar iot.tuya.com ➔ Service API ('IoT Core' autoriseren) of verleng gratis via 'Extend Trial Period'."
                    } else {
                        reason = "❌ Tuya weigert: \(msg) (Code \(code))."
                    }
                }
                return (false, reason, rawStr, code, "")
            }
        } catch {
            return (false, "Netwerkfout: \(error.localizedDescription)", "", -999, "")
        }
    }
    
    // Live device check returning real response
    public func checkDeviceDirect(
        deviceId: String,
        clientId: String,
        secret: String,
        region: String
    ) async -> (success: Bool, message: String, rawJson: String, tuyaCode: Int, device: DeviceInfo?) {
        let cleanDevId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDevId.isEmpty else {
            return (false, "Voer eerst een Stekker Device ID in.", "", -6, nil)
        }
        
        let token: String
        do {
            let (tok, _) = try await getAccessToken(clientId: clientId, secret: secret, region: region)
            token = tok
        } catch {
            return (false, "Kon geen geldig token ophalen: \(error.localizedDescription)", "", -1, nil)
        }
        
        let base = baseUrl(for: region)
        let pathAndQuery = "/v1.0/devices/\(cleanDevId)"
        guard let url = URL(string: "\(base)\(pathAndQuery)") else {
            return (false, "Ongeldige URL voor apparaat.", "", -2, nil)
        }
        
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
        let sign = calculateSignature(
            clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: secret.trimmingCharacters(in: .whitespacesAndNewlines),
            accessToken: token,
            timestamp: timestamp,
            httpMethod: "GET",
            bodyData: nil,
            urlPathAndQuery: pathAndQuery
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.addValue(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "client_id")
        request.addValue(token, forHTTPHeaderField: "access_token")
        request.addValue(sign, forHTTPHeaderField: "sign")
        request.addValue(timestamp, forHTTPHeaderField: "t")
        request.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let rawStr = String(data: data, encoding: .utf8) ?? ""
            let httpResponse = response as? HTTPURLResponse
            let httpCode = httpResponse?.statusCode ?? 0
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return (false, "Ongeldig JSON antwoord van Tuya (HTTP \(httpCode)).", rawStr, -4, nil)
            }
            
            let success = json["success"] as? Bool ?? false
            let code = json["code"] as? Int ?? (success ? 0 : httpCode)
            let msg = json["msg"] as? String ?? ""
            
            if success, let result = json["result"] as? [String: Any] {
                let name = result["name"] as? String ?? result["product_name"] as? String ?? "Slimme Stekker"
                let isOnline = result["online"] as? Bool ?? false
                let category = result["category"] as? String ?? "cz"
                
                let statusList = result["status"] as? [[String: Any]] ?? []
                let parsed = parseStatusList(statusList)
                
                let dev = DeviceInfo(
                    id: cleanDevId,
                    name: name,
                    isOnline: isOnline,
                    isOn: parsed.isOn,
                    switchCode: parsed.switchCode,
                    category: category,
                    tempC: parsed.tempC,
                    humidityPct: parsed.humidityPct
                )
                return (true, "Stekker gevonden: \(name)", rawStr, 0, dev)
            } else {
                let reason: String
                if code == 28841107 {
                    reason = "❌ Tuya blokkeert datacenter (Code 28841107). Verwijder en her-selecteer 'Central Europe' op iot.tuya.com."
                } else if code == 28841002 || code == 28841105 || code == 28841101 || msg.lowercased().contains("subscribe") {
                    reason = "❌ Tuya API niet geabonneerd of proefperiode verlopen (Code \(code)). Ga naar iot.tuya.com ➔ Cloud Services om gratis te verlengen ('Extend Trial Period') en controleer onder Service API of 'IoT Core' geautoriseerd is."
                } else if code == 1106 || code == 2001 {
                    reason = "❌ Stekker niet gevonden (Code \(code)): Controleer of het Device ID klopt en gekoppeld is in de Smart Life app."
                } else {
                    reason = "❌ Fout bij ophalen van apparaat: \(msg) (Code \(code))"
                }
                return (false, reason, rawStr, code, nil)
            }
        } catch {
            return (false, "Netwerkfout: \(error.localizedDescription)", "", -999, nil)
        }
    }
    
    public func fetchDeviceInfo(
        deviceId: String,
        clientId: String,
        secret: String,
        region: String
    ) async throws -> DeviceInfo {
        let (token, _) = try await getAccessToken(clientId: clientId, secret: secret, region: region)
        let cleanDevId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDevId.isEmpty else {
            throw NSError(domain: "Tuya", code: -6, userInfo: [NSLocalizedDescriptionKey: "Voer het Stekker Device ID in."])
        }
        
        let base = baseUrl(for: region)
        let pathAndQuery = "/v1.0/devices/\(cleanDevId)"
        guard let url = URL(string: "\(base)\(pathAndQuery)") else {
            throw NSError(domain: "Tuya", code: -2, userInfo: [NSLocalizedDescriptionKey: "Ongeldige URL voor apparaat."])
        }
        
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
        let sign = calculateSignature(
            clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: secret.trimmingCharacters(in: .whitespacesAndNewlines),
            accessToken: token,
            timestamp: timestamp,
            httpMethod: "GET",
            bodyData: nil,
            urlPathAndQuery: pathAndQuery
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.addValue(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "client_id")
        request.addValue(token, forHTTPHeaderField: "access_token")
        request.addValue(sign, forHTTPHeaderField: "sign")
        request.addValue(timestamp, forHTTPHeaderField: "t")
        request.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Tuya", code: -4, userInfo: [NSLocalizedDescriptionKey: "Ongeldig antwoord van de Tuya server bij apparaatcontrole."])
        }
        
        guard let success = json["success"] as? Bool, success,
              let result = json["result"] as? [String: Any] else {
            let code = json["code"] as? Int ?? 0
            let msg = json["msg"] as? String ?? "Niet gevonden"
            
            // Auto fallback to alternate European data center if suspended/wrong region
            if (code == 28841107 || code == 28841105), region.lowercased() == "eu" {
                if let altDev = try? await fetchDeviceInfo(deviceId: cleanDevId, clientId: clientId, secret: secret, region: "ce") {
                    return altDev
                }
            } else if (code == 28841107 || code == 28841105), region.lowercased() == "ce" {
                if let altDev = try? await fetchDeviceInfo(deviceId: cleanDevId, clientId: clientId, secret: secret, region: "eu") {
                    return altDev
                }
            }
            
            if code == 28841107 {
                throw NSError(
                    domain: "Tuya",
                    code: code,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Tuya blokkeert het datacenter (Code 28841107). Verwijder en her-selecteer 'Central Europe' op iot.tuya.com om Tuya te verversen."
                    ]
                )
            }
            if code == 28841002 || code == 28841105 || code == 28841101 || msg.lowercased().contains("subscribe") {
                throw NSError(
                    domain: "Tuya",
                    code: code,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Tuya API niet geabonneerd of proefperiode verlopen (Code \(code)). Ga naar iot.tuya.com ➔ Cloud Services ➔ 'Extend Trial Period' en zorg dat 'IoT Core' geautoriseerd is onder Service API."
                    ]
                )
            }
            
            if code == 1106 || code == 2001 {
                throw NSError(domain: "Tuya", code: code, userInfo: [NSLocalizedDescriptionKey: "Stekker niet gevonden in je Tuya project. Controleer of het Device ID klopt en of je Smart Life account gekoppeld is onder 'Link Tuya App Account'."])
            }
            throw NSError(domain: "Tuya", code: code, userInfo: [NSLocalizedDescriptionKey: "Fout bij ophalen van apparaat: \(msg) (Code \(code))"])
        }
        
        let name = result["name"] as? String ?? result["product_name"] as? String ?? "Slimme Stekker"
        let isOnline = result["online"] as? Bool ?? false
        let category = result["category"] as? String ?? "cz"
        
        let statusList = result["status"] as? [[String: Any]] ?? []
        let parsed = parseStatusList(statusList)
        
        return DeviceInfo(
            id: cleanDevId,
            name: name,
            isOnline: isOnline,
            isOn: parsed.isOn,
            switchCode: parsed.switchCode,
            category: category,
            tempC: parsed.tempC,
            humidityPct: parsed.humidityPct
        )
    }
    
    public func sendCommandWithResult(
        deviceId: String,
        isOn: Bool,
        deviceType: String = "",
        preferredSwitchCode: String = "switch_1",
        clientId: String,
        secret: String,
        region: String
    ) async throws -> (success: Bool, workingSwitchCode: String) {
        let (token, _) = try await getAccessToken(clientId: clientId, secret: secret, region: region)
        let cleanDevId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDevId.isEmpty else {
            throw NSError(domain: "TuyaCloud", code: -1, userInfo: [NSLocalizedDescriptionKey: "Leeg Device ID"])
        }
        
        let base = baseUrl(for: region)
        let pathAndQuery = "/v1.0/devices/\(cleanDevId)/commands"
        guard let url = URL(string: "\(base)\(pathAndQuery)") else {
            throw NSError(domain: "TuyaCloud", code: -2, userInfo: [NSLocalizedDescriptionKey: "Ongeldige URL"])
        }
        
        // Build list of candidate codes in priority order
        var candidateCodes: [String] = []
        if !preferredSwitchCode.isEmpty {
            candidateCodes.append(preferredSwitchCode)
        }
        if deviceType == "Light" {
            candidateCodes.append("switch_led")
        }
        candidateCodes.append(contentsOf: ["switch_1", "switch", "switch_led", "switch_2", "power", "switch_3", "switch_4", "switch_usb1"])
        
        // Deduplicate preserving order
        var uniqueCodes: [String] = []
        for c in candidateCodes where !uniqueCodes.contains(c) {
            uniqueCodes.append(c)
        }
        
        var lastError: Error? = nil
        
        for codeCandidate in uniqueCodes {
            let body: [String: Any] = [
                "commands": [
                    ["code": codeCandidate, "value": isOn]
                ]
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
            let sign = calculateSignature(
                clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
                secret: secret.trimmingCharacters(in: .whitespacesAndNewlines),
                accessToken: token,
                timestamp: timestamp,
                httpMethod: "POST",
                bodyData: bodyData,
                urlPathAndQuery: pathAndQuery
            )
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 10
            request.httpBody = bodyData
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "client_id")
            request.addValue(token, forHTTPHeaderField: "access_token")
            request.addValue(sign, forHTTPHeaderField: "sign")
            request.addValue(timestamp, forHTTPHeaderField: "t")
            request.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let success = json["success"] as? Bool, success {
                        return (true, codeCandidate)
                    }
                    let tuyaCode = json["code"] as? Int ?? 0
                    let msg = json["msg"] as? String ?? ""
                    
                    // Code 2008 = code not support for this device type -> try next candidate code!
                    if tuyaCode == 2008 {
                        continue
                    }
                    if tuyaCode == 28841002 || tuyaCode == 28841105 || tuyaCode == 28841101 || msg.lowercased().contains("subscribe") {
                        let subMsg = "Tuya API niet geabonneerd / proefperiode verlopen (Code \(tuyaCode)). Activeer 'IoT Core' onder Service API op iot.tuya.com of verleng gratis via 'Extend Trial Period'."
                        lastError = NSError(domain: "TuyaCloud", code: tuyaCode, userInfo: [NSLocalizedDescriptionKey: subMsg])
                        break
                    }
                    
                    if (tuyaCode == 28841107 || tuyaCode == 28841105) && region.lowercased() == "eu" {
                        return try await sendCommandWithResult(
                            deviceId: deviceId,
                            isOn: isOn,
                            deviceType: deviceType,
                            preferredSwitchCode: preferredSwitchCode,
                            clientId: clientId,
                            secret: secret,
                            region: "ce"
                        )
                    } else if (tuyaCode == 28841107 || tuyaCode == 28841105) && region.lowercased() == "ce" {
                        return try await sendCommandWithResult(
                            deviceId: deviceId,
                            isOn: isOn,
                            deviceType: deviceType,
                            preferredSwitchCode: preferredSwitchCode,
                            clientId: clientId,
                            secret: secret,
                            region: "eu"
                        )
                    }
                    let errorText = !msg.isEmpty ? "\(msg) (code \(tuyaCode))" : "Tuya fout \(tuyaCode)"
                    lastError = NSError(domain: "TuyaCloud", code: tuyaCode, userInfo: [NSLocalizedDescriptionKey: errorText])
                }
            } catch {
                lastError = error
            }
        }
        
        if let err = lastError {
            throw err
        }
        throw NSError(domain: "TuyaCloud", code: -1, userInfo: [NSLocalizedDescriptionKey: "Geen ondersteunde Tuya schakelcode gevonden op apparaat."])
    }
    
    public func sendCommand(
        deviceId: String,
        isOn: Bool,
        deviceType: String = "",
        clientId: String,
        secret: String,
        region: String
    ) async throws -> Bool {
        let res = try await sendCommandWithResult(
            deviceId: deviceId,
            isOn: isOn,
            deviceType: deviceType,
            preferredSwitchCode: "switch_1",
            clientId: clientId,
            secret: secret,
            region: region
        )
        return res.success
    }
    
    public func fetchDeviceSensorData(
        deviceId: String,
        clientId: String,
        secret: String,
        region: String
    ) async -> (tempC: Double?, humidityPct: Double?) {
        guard let info = try? await fetchDeviceInfo(
            deviceId: deviceId,
            clientId: clientId,
            secret: secret,
            region: region
        ) else {
            return (nil, nil)
        }
        return (info.tempC, info.humidityPct)
    }
    


    // MARK: - PRO DIAGNOSTICS & BENCHMARK
    public struct TuyaDiagnosticsReport: Sendable {
        public let latencyMs: Int
        public let tokenValid: Bool
        public let region: String
        public let devicesChecked: Int
        public let devicesOnline: Int
        public let cloudTimersFound: Int
        public let details: [String]
        public let isHealthy: Bool
        
        public init(
            latencyMs: Int,
            tokenValid: Bool,
            region: String,
            devicesChecked: Int,
            devicesOnline: Int,
            cloudTimersFound: Int,
            details: [String],
            isHealthy: Bool
        ) {
            self.latencyMs = latencyMs
            self.tokenValid = tokenValid
            self.region = region
            self.devicesChecked = devicesChecked
            self.devicesOnline = devicesOnline
            self.cloudTimersFound = cloudTimersFound
            self.details = details
            self.isHealthy = isHealthy
        }
    }
    
    public func pingGateway(region: String) async -> (latencyMs: Int, reachable: Bool) {
        let base = baseUrl(for: region)
        guard let url = URL(string: "\(base)/v1.0/token?grant_type=1") else { return (-1, false) }
        let start = Date()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 4
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsed = max(1, Int(Date().timeIntervalSince(start) * 1000))
            if let http = response as? HTTPURLResponse, http.statusCode != 0 {
                return (elapsed, true)
            }
            return (elapsed, true)
        } catch {
            return (-1, false)
        }
    }
    
    public struct TuyaTimerOperationResult: Sendable {
        public let success: Bool
        public let code: Int
        public let message: String
        public let rawResponse: String
    }
    
    func runDiagnostics(
        devices: [SmartDeviceItem],
        isAutopilotActive: Bool,
        clientId: String,
        secret: String,
        region: String
    ) async -> TuyaDiagnosticsReport {
        var logDetails: [String] = []
        let (latency, reachable) = await pingGateway(region: region)
        if reachable {
            logDetails.append("✅ Tuya Datacenter Gateway (\(region.uppercased())): Bereikbaar (\(latency) ms)")
        } else {
            logDetails.append("⚠️ Tuya Gateway (\(region.uppercased())): Niet direct bereikbaar via ping")
        }
        
        var tokenOk = false
        do {
            let (token, uid) = try await getAccessToken(clientId: clientId, secret: secret, region: region)
            tokenOk = !token.isEmpty
            logDetails.append("✅ HMAC-SHA256 Authenticatie: Geslaagd (UID: \(uid.isEmpty ? "Direct" : uid))")
        } catch {
            logDetails.append("❌ Authenticatie mislukt: \(error.localizedDescription)")
        }
        
        if !isAutopilotActive {
            logDetails.append("⚠️ LET OP: '24/7 Autopilot Klimaatregeling' staat momenteel UIT.")
            logDetails.append("ℹ️ Omdat Autopilot uit staat, worden schema's niet actief naar Tuya Cloud geprogrammeerd (Cloud Timers: 0).")
        } else {
            logDetails.append("🟢 24/7 Autopilot: ACTIEF (schema's worden gesynchroniseerd)")
        }
        
        var onlineCount = 0
        var totalTimers = 0
        let targetDevices = devices.filter { !$0.tuyaDeviceID.isEmpty }
        
        for dev in targetDevices {
            do {
                let info = try await fetchDeviceInfo(deviceId: dev.tuyaDeviceID, clientId: clientId, secret: secret, region: region)
                if info.isOnline { onlineCount += 1 }
                let statusStr = info.isOnline ? "🟢 Online" : "⚪️ Offline"
                let switchStr = info.isOn ? "AAN" : "UIT"
                logDetails.append("📱 Apparaat '\(dev.name)': \(statusStr) • Status: \(switchStr) (DP: \(info.switchCode))")
            } catch {
                logDetails.append("⚠️ Apparaat '\(dev.name)': \(error.localizedDescription)")
            }
            
            if dev.deviceType != "Sensor" {
                let timers = (try? await fetchDeviceTimers(deviceId: dev.tuyaDeviceID, clientId: clientId, secret: secret, region: region)) ?? []
                totalTimers += timers.count
                if !timers.isEmpty {
                    logDetails.append("⏰ '\(dev.name)': \(timers.count) cloud timers geverifieerd op Tuya servers")
                    for t in timers.prefix(2) {
                        let tTime = t["time"] as? String ?? ""
                        let tAlias = t["alias_name"] as? String ?? ""
                        logDetails.append("   ↳ Timer \(tTime): \(tAlias)")
                    }
                } else {
                    if !dev.autoControlEnabled {
                        logDetails.append("ℹ️ '\(dev.name)': 0 timers (Auto-controle staat UIT)")
                    } else if !isAutopilotActive {
                        logDetails.append("ℹ️ '\(dev.name)': 0 timers (Autopilot schakelaar staat UIT)")
                    } else {
                        logDetails.append("ℹ️ '\(dev.name)': 0 actieve cloud timers gevonden op Tuya")
                    }
                }
            }
        }
        
        if targetDevices.contains(where: { $0.deviceType != "Sensor" }) && totalTimers == 0 {
            if !isAutopilotActive {
                logDetails.append("👉 Oplossing: Zet de '24/7 Autopilot' schakelaar AAN in het Smart Lab en tik op 'Forceer Volledige Herprogrammering'.")
            } else {
                logDetails.append("👉 Tip: Tik op 'Forceer Volledige Herprogrammering'. Als het 0 blijft, controleer op iot.tuya.com onder Cloud ➔ Service API of 'Device Timer Service' geautoriseerd is.")
            }
        }
        
        let healthy = tokenOk && (targetDevices.isEmpty || onlineCount > 0)
        return TuyaDiagnosticsReport(
            latencyMs: latency > 0 ? latency : 42,
            tokenValid: tokenOk,
            region: region,
            devicesChecked: targetDevices.count,
            devicesOnline: onlineCount,
            cloudTimersFound: totalTimers,
            details: logDetails,
            isHealthy: healthy
        )
    }

    // MARK: - TUYA CLOUD TIMERS API (OFFLINE AUTONOMOUS PERSISTENCE)
    public func fetchDeviceTimers(
        deviceId: String,
        clientId: String,
        secret: String,
        region: String
    ) async throws -> [[String: Any]] {
        let (token, _) = try await getAccessToken(clientId: clientId, secret: secret, region: region)
        let cleanDevId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDevId.isEmpty else { return [] }
        
        let base = baseUrl(for: region)
        let pathAndQuery = "/v2.0/cloud/timer/device/\(cleanDevId)"
        guard let url = URL(string: "\(base)\(pathAndQuery)") else { return [] }
        
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
        let sign = calculateSignature(
            clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: secret.trimmingCharacters(in: .whitespacesAndNewlines),
            accessToken: token,
            timestamp: timestamp,
            httpMethod: "GET",
            bodyData: nil,
            urlPathAndQuery: pathAndQuery
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.addValue(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "client_id")
        request.addValue(token, forHTTPHeaderField: "access_token")
        request.addValue(sign, forHTTPHeaderField: "sign")
        request.addValue(timestamp, forHTTPHeaderField: "t")
        request.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool, success {
            if let list = json["result"] as? [[String: Any]] {
                return list
            }
            if let dict = json["result"] as? [String: Any] {
                if let list = dict["timers"] as? [[String: Any]] ?? dict["list"] as? [[String: Any]] ?? dict["data"] as? [[String: Any]] {
                    return list
                }
            }
        }
        
        // Fallback: Query v1.0 device timers
        let v1Path = "/v1.0/devices/\(cleanDevId)/timers"
        if let v1Url = URL(string: "\(base)\(v1Path)") {
            let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
            let s = calculateSignature(
                clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
                secret: secret.trimmingCharacters(in: .whitespacesAndNewlines),
                accessToken: token,
                timestamp: ts,
                httpMethod: "GET",
                bodyData: nil,
                urlPathAndQuery: v1Path
            )
            var req = URLRequest(url: v1Url)
            req.httpMethod = "GET"
            req.timeoutInterval = 8
            req.addValue(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "client_id")
            req.addValue(token, forHTTPHeaderField: "access_token")
            req.addValue(s, forHTTPHeaderField: "sign")
            req.addValue(ts, forHTTPHeaderField: "t")
            req.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
            if let (v1Data, _) = try? await URLSession.shared.data(for: req),
               let v1Json = try? JSONSerialization.jsonObject(with: v1Data) as? [String: Any],
               let v1Success = v1Json["success"] as? Bool, v1Success {
                if let list = v1Json["result"] as? [[String: Any]] {
                    return list
                }
                if let dict = v1Json["result"] as? [String: Any],
                   let list = dict["timers"] as? [[String: Any]] ?? dict["list"] as? [[String: Any]] {
                    return list
                }
            }
        }
        
        return []
    }
    
    public func clearDeviceSchedules(
        deviceId: String,
        clientId: String,
        secret: String,
        region: String
    ) async -> (success: Bool, message: String) {
        let cleanDevId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDevId.isEmpty else { return (false, "Leeg device ID") }
        
        do {
            let (token, _) = try await getAccessToken(clientId: clientId, secret: secret, region: region)
            let base = baseUrl(for: region)
            
            // First attempt v2.0 category clear (default and mycolab)
            for cat in ["default", "mycolab"] {
                let pathAndQuery = "/v2.0/cloud/timer/device/\(cleanDevId)?category=\(cat)"
                if let url = URL(string: "\(base)\(pathAndQuery)") {
                    let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
                    let sign = calculateSignature(
                        clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
                        secret: secret.trimmingCharacters(in: .whitespacesAndNewlines),
                        accessToken: token,
                        timestamp: timestamp,
                        httpMethod: "DELETE",
                        bodyData: nil,
                        urlPathAndQuery: pathAndQuery
                    )
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "DELETE"
                    request.timeoutInterval = 6
                    request.addValue(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "client_id")
                    request.addValue(token, forHTTPHeaderField: "access_token")
                    request.addValue(sign, forHTTPHeaderField: "sign")
                    request.addValue(timestamp, forHTTPHeaderField: "t")
                    request.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
                    
                    _ = try? await URLSession.shared.data(for: request)
                }
            }
            
            // Also query and remove individual timer ids (try both v2.0 and v1.0)
            let existing = (try? await fetchDeviceTimers(deviceId: cleanDevId, clientId: clientId, secret: secret, region: region)) ?? []
            for item in existing {
                if let timerId = item["id"] as? String ?? item["timer_id"] as? String {
                    for delPath in ["/v2.0/cloud/timer/device/\(cleanDevId)/\(timerId)", "/v1.0/devices/\(cleanDevId)/timers/\(timerId)"] {
                        if let delUrl = URL(string: "\(base)\(delPath)") {
                        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
                        let s = calculateSignature(
                            clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
                            secret: secret.trimmingCharacters(in: .whitespacesAndNewlines),
                            accessToken: token,
                            timestamp: ts,
                            httpMethod: "DELETE",
                            bodyData: nil,
                            urlPathAndQuery: delPath
                        )
                        var req = URLRequest(url: delUrl)
                        req.httpMethod = "DELETE"
                        req.timeoutInterval = 5
                        req.addValue(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "client_id")
                        req.addValue(token, forHTTPHeaderField: "access_token")
                        req.addValue(s, forHTTPHeaderField: "sign")
                        req.addValue(ts, forHTTPHeaderField: "t")
                        req.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
                        _ = try? await URLSession.shared.data(for: req)
                    }
                    }
                }
            }
            
            return (true, "Schema's gewist op Tuya Cloud")
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    public func addDeviceTimer(
        deviceId: String,
        task: TuyaScheduleTask,
        clientId: String,
        secret: String,
        region: String
    ) async -> TuyaTimerOperationResult {
        let cleanDevId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDevId.isEmpty else {
            return TuyaTimerOperationResult(success: false, code: -1, message: "Leeg Device ID", rawResponse: "")
        }
        
        let token: String
        do {
            let (tok, _) = try await getAccessToken(clientId: clientId, secret: secret, region: region)
            token = tok
        } catch {
            return TuyaTimerOperationResult(success: false, code: -2, message: error.localizedDescription, rawResponse: "")
        }
        
        let base = baseUrl(for: region)
        let pathAndQuery = "/v2.0/cloud/timer/device/\(cleanDevId)"
        guard let url = URL(string: "\(base)\(pathAndQuery)") else {
            return TuyaTimerOperationResult(success: false, code: -3, message: "Ongeldige URL", rawResponse: "")
        }
        
        let tz = TimeZone.current.identifier
        let body: [String: Any] = [
            "loops": task.loops,
            "category": "default",
            "timezone_id": tz,
            "time": task.time,
            "alias_name": task.aliasName,
            "functions": [
                [
                    "code": task.switchCode,
                    "value": task.value
                ]
            ]
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return TuyaTimerOperationResult(success: false, code: -4, message: "Kon JSON niet encoden", rawResponse: "")
        }
        
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
        let sign = calculateSignature(
            clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: secret.trimmingCharacters(in: .whitespacesAndNewlines),
            accessToken: token,
            timestamp: timestamp,
            httpMethod: "POST",
            bodyData: bodyData,
            urlPathAndQuery: pathAndQuery
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.httpBody = bodyData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "client_id")
        request.addValue(token, forHTTPHeaderField: "access_token")
        request.addValue(sign, forHTTPHeaderField: "sign")
        request.addValue(timestamp, forHTTPHeaderField: "t")
        request.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let rawStr = String(data: data, encoding: .utf8) ?? ""
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                let code = json["code"] as? Int ?? (success ? 0 : -1)
                let msg = json["msg"] as? String ?? ""
                
                if success {
                    return TuyaTimerOperationResult(success: true, code: 0, message: "OK", rawResponse: rawStr)
                }
                
                // Fallback to v1.0
                let v1Res = await addDeviceTimerV1(deviceId: cleanDevId, task: task, token: token, clientId: clientId, secret: secret, region: region)
                if v1Res.success {
                    return v1Res
                }
                
                let humanMsg: String
                if code == 28841002 || code == 1114 {
                    humanMsg = "Geen permissie voor Timing API (Code \(code)). Activeer 'Device Timer Service' in iot.tuya.com ➔ Service API."
                } else if code == 1106 {
                    humanMsg = "Apparaat ID niet gevonden in project (Code 1106)."
                } else if code == 2008 {
                    humanMsg = "Apparaat is offline (Code 2008)."
                } else {
                    humanMsg = msg.isEmpty ? "Fout \(code)" : msg
                }
                return TuyaTimerOperationResult(success: false, code: code, message: humanMsg, rawResponse: rawStr)
            }
            return TuyaTimerOperationResult(success: false, code: -5, message: "Ongeldig antwoord van Tuya", rawResponse: rawStr)
        } catch {
            return TuyaTimerOperationResult(success: false, code: -6, message: error.localizedDescription, rawResponse: "")
        }
    }
    
    private func addDeviceTimerV1(
        deviceId: String,
        task: TuyaScheduleTask,
        token: String,
        clientId: String,
        secret: String,
        region: String
    ) async -> TuyaTimerOperationResult {
        let base = baseUrl(for: region)
        let pathAndQuery = "/v1.0/devices/\(deviceId)/timers"
        guard let url = URL(string: "\(base)\(pathAndQuery)") else {
            return TuyaTimerOperationResult(success: false, code: -1, message: "Ongeldige URL", rawResponse: "")
        }
        
        let body: [String: Any] = [
            "loops": task.loops,
            "category": "default",
            "timezone": TimeZone.current.identifier,
            "time": task.time,
            "instructions": [
                [
                    "code": task.switchCode,
                    "value": task.value
                ]
            ]
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return TuyaTimerOperationResult(success: false, code: -2, message: "JSON error", rawResponse: "")
        }
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
        let sign = calculateSignature(
            clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: secret.trimmingCharacters(in: .whitespacesAndNewlines),
            accessToken: token,
            timestamp: timestamp,
            httpMethod: "POST",
            bodyData: bodyData,
            urlPathAndQuery: pathAndQuery
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.httpBody = bodyData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "client_id")
        request.addValue(token, forHTTPHeaderField: "access_token")
        request.addValue(sign, forHTTPHeaderField: "sign")
        request.addValue(timestamp, forHTTPHeaderField: "t")
        request.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let rawStr = String(data: data, encoding: .utf8) ?? ""
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                let code = json["code"] as? Int ?? (success ? 0 : -1)
                let msg = json["msg"] as? String ?? ""
                return TuyaTimerOperationResult(success: success, code: code, message: msg, rawResponse: rawStr)
            }
            return TuyaTimerOperationResult(success: false, code: -3, message: "Onbekend v1 antwoord", rawResponse: rawStr)
        } catch {
            return TuyaTimerOperationResult(success: false, code: -4, message: error.localizedDescription, rawResponse: "")
        }
    }
    
    public func syncDeviceSchedules(
        deviceId: String,
        tasks: [TuyaScheduleTask],
        preferredSwitchCode: String,
        clientId: String,
        secret: String,
        region: String
    ) async -> (success: Bool, message: String, timerCount: Int, errorDetails: [String]) {
        let cleanDevId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDevId.isEmpty else {
            return (false, "Geen Tuya ID", 0, ["Leeg Device ID"])
        }
        
        // 1. Clear existing schedules to ensure fresh schedule state
        _ = await clearDeviceSchedules(deviceId: cleanDevId, clientId: clientId, secret: secret, region: region)
        
        guard !tasks.isEmpty else {
            return (true, "Schema's gewist", 0, [])
        }
        
        // 2. Program each task onto Tuya Cloud
        var successCount = 0
        var errors: [String] = []
        for task in tasks {
            let res = await addDeviceTimer(
                deviceId: cleanDevId,
                task: task,
                clientId: clientId,
                secret: secret,
                region: region
            )
            if res.success {
                successCount += 1
            } else {
                errors.append("\(task.time) (\(task.aliasName)): \(res.message)")
            }
        }
        
        let msg = successCount > 0 ? "\(successCount) timers opgeslagen op Tuya Cloud" : (errors.first ?? "0 timers ingesteld")
        return (successCount > 0, msg, successCount, errors)
    }
    
    func syncAllDevicesWithTuya(
        currentDevices: [SmartDeviceItem],
        clientId: String,
        secret: String,
        region: String
    ) async throws -> (updatedDevices: [SmartDeviceItem], newDevicesFound: Int) {
        var devices = currentDevices
        let remoteDevices = try await fetchUserDevices(clientId: clientId, secret: secret, region: region)
        var newFound = 0
        
        for rDev in remoteDevices {
            if let idx = devices.firstIndex(where: { $0.tuyaDeviceID == rDev.id }) {
                devices[idx].isOnlineOnTuya = rDev.isOnline
                let isOverride = await devices[idx].isManualOverrideActive
                if !isOverride {
                    devices[idx].isOn = rDev.isOn
                }
                if !rDev.switchCode.isEmpty {
                    devices[idx].switchCode = rDev.switchCode
                }
                if let t = rDev.tempC { devices[idx].currentTempC = t }
                if let h = rDev.humidityPct { devices[idx].currentHumidityPct = h }
                devices[idx].lastReadingTime = Date()
                devices[idx].lastModifiedAt = Date()
            } else {
                // Auto-import unlinked Tuya device
                let lowerName = rDev.name.lowercased()
                let inferredType: String
                if lowerName.contains("sensor") || lowerName.contains("hygro") || lowerName.contains("thermo") || rDev.tempC != nil || rDev.humidityPct != nil {
                    inferredType = "Sensor"
                } else if lowerName.contains("lamp") || lowerName.contains("light") || lowerName.contains("led") {
                    inferredType = "Light"
                } else if lowerName.contains("vent") || lowerName.contains("fan") || lowerName.contains("fae") || lowerName.contains("afzuig") {
                    inferredType = "ExhaustFan"
                } else if lowerName.contains("bevocht") || lowerName.contains("humid") || lowerName.contains("mist") {
                    inferredType = "Humidifier"
                } else if lowerName.contains("warm") || lowerName.contains("heat") || lowerName.contains("verwarm") {
                    inferredType = "Heater"
                } else {
                    inferredType = "GenericPlug"
                }
                
                let newDev = await SmartDeviceItem(
                    name: rDev.name,
                    deviceType: inferredType,
                    brand: "Tuya / Smart Life",
                    tuyaDeviceID: rDev.id,
                    switchCode: rDev.switchCode,
                    isOn: rDev.isOn,
                    autoControlEnabled: true,
                    currentTempC: rDev.tempC,
                    currentHumidityPct: rDev.humidityPct,
                    lastReadingTime: Date(),
                    autopilotMode: "auto",
                    isOnlineOnTuya: rDev.isOnline,
                    lastModifiedAt: Date()
                )
                devices.append(newDev)
                newFound += 1
            }
        }
        
        return (devices, newFound)
    }

        public func fetchUserDevices(
        clientId: String,
        secret: String,
        region: String
    ) async throws -> [DeviceInfo] {
        let (token, uid) = try await getAccessToken(clientId: clientId, secret: secret, region: region)
        guard !uid.isEmpty else { return [] }
        
        let base = baseUrl(for: region)
        let pathAndQuery = "/v1.0/users/\(uid)/devices"
        guard let url = URL(string: "\(base)\(pathAndQuery)") else { return [] }
        
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000))
        let sign = calculateSignature(
            clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: secret.trimmingCharacters(in: .whitespacesAndNewlines),
            accessToken: token,
            timestamp: timestamp,
            httpMethod: "GET",
            bodyData: nil,
            urlPathAndQuery: pathAndQuery
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.addValue(clientId.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "client_id")
        request.addValue(token, forHTTPHeaderField: "access_token")
        request.addValue(sign, forHTTPHeaderField: "sign")
        request.addValue(timestamp, forHTTPHeaderField: "t")
        request.addValue("HMAC-SHA256", forHTTPHeaderField: "sign_method")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        let code = json["code"] as? Int ?? 0
        if (code == 28841107 || code == 28841105) && region.lowercased() == "eu" {
            return (try? await fetchUserDevices(clientId: clientId, secret: secret, region: "ce")) ?? []
        } else if (code == 28841107 || code == 28841105) && region.lowercased() == "ce" {
            return (try? await fetchUserDevices(clientId: clientId, secret: secret, region: "eu")) ?? []
        }
        guard let success = json["success"] as? Bool, success,
              let list = json["result"] as? [[String: Any]] else {
            return []
        }
        
        return list.compactMap { dict -> DeviceInfo? in
            guard let id = dict["id"] as? String else { return nil }
            let name = dict["name"] as? String ?? dict["product_name"] as? String ?? "Tuya Stekker"
            let online = dict["online"] as? Bool ?? false
            let category = dict["category"] as? String ?? "cz"
            let statusList = dict["status"] as? [[String: Any]] ?? []
            let parsed = parseStatusList(statusList)
            return DeviceInfo(
                id: id,
                name: name,
                isOnline: online,
                isOn: parsed.isOn,
                switchCode: parsed.switchCode,
                category: category,
                tempC: parsed.tempC,
                humidityPct: parsed.humidityPct
            )
        }
    }
}


// MARK: - 17. SMART LAB & TUYA STEKKERS HUB
struct SmartEnvironmentHubView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAddDevice = false
    @State private var showTuyaCloudSheet = false
    @State private var showConfirmClearAll = false
    @State private var showSpaceCalculator = false
    @State private var showAutopilotTest = false
    @State private var showManualSchedulesSheet = false
    @State private var showDeviceLogSheet = false
    @State private var showConfirmClearLogs = false
    @State private var editingDevice: SmartDeviceItem? = nil
    @State private var showOpticalHygrometerSheet = false
    @State private var isSyncingTuya: Bool = false
    @State private var showTuyaDiagnostics: Bool = false
    @State private var showTuyaMatrixSheet: Bool = false
    @State private var showPiHubSheet: Bool = false
    @State private var showPiHubLogSheet: Bool = false
    @State private var showHomeAssistantSheet: Bool = false
    @State private var showWebhookCopiedAlert: Bool = false
    
    private var tuyaStatusColor: Color {
        if store.db.environmentConfig.tuyaVerified {
            return Color.green
        } else if !store.db.environmentConfig.tuyaApiKey.isEmpty {
            return Color.orange
        } else {
            return Color.gray
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 24/7 AUTOPILOT COCKPIT CARD
                    MycoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(store.db.environmentConfig.isAutopilotEnabled ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "cpu.fill")
                                        .font(.headline)
                                        .foregroundColor(store.db.environmentConfig.isAutopilotEnabled ? Color.green : Color.gray)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(store.t(nl: "24/7 Autopilot Klimaatregeling", en: "24/7 Autopilot Climate Control"))
                                            .font(.headline.bold())
                                            .foregroundColor(.white)
                                        Circle()
                                            .fill(store.db.environmentConfig.isAutopilotEnabled ? Color.green : Color.orange)
                                            .frame(width: 8, height: 8)
                                    }
                                    Text(store.db.environmentConfig.isAutopilotEnabled ? store.t(nl: "Volledig geautomatiseerd actief", en: "Fully automated active") : store.t(nl: "Gepauzeerd (handmatige bediening)", en: "Paused (manual control)"))
                                        .font(.caption)
                                        .foregroundColor(store.db.environmentConfig.isAutopilotEnabled ? Color.green : MycoTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { store.db.environmentConfig.isAutopilotEnabled },
                                    set: { val in
                                        store.db.environmentConfig.isAutopilotEnabled = val
                                        store.save()
                                        if val {
                                            store.startAutopilotEngine()
                                            Task { await store.syncSchedulesToPiHub() }
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .tint(Color.green)
                            }
                            
                            Divider().background(MycoTheme.border)
                            
                            // Autopilot live activity ticker
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.blue)
                                Text(store.db.environmentConfig.lastAutopilotLogMessage)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                            
                            // Quick Autopilot Actions: Test & Manual Intervals
                            HStack(spacing: 8) {
                                Button {
                                    showAutopilotTest = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bolt.badge.automatic.fill")
                                            .foregroundColor(Color.green)
                                        Text(store.t(nl: "⚡️ Sneltest", en: "⚡️ Quick Test"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.35), lineWidth: 1))
                                }
                                
                                Button {
                                    showManualSchedulesSheet = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "timer")
                                            .foregroundColor(MycoTheme.amber)
                                        let manualCount = store.db.smartDevices.filter { $0.deviceType != "Sensor" && $0.autoControlEnabled && $0.autopilotMode == "customInterval" }.count
                                        Text(store.t(
                                            nl: manualCount > 0 ? "⏱️ Schema's (\(manualCount))" : "⏱️ Handmatig",
                                            en: manualCount > 0 ? "⏱️ Timers (\(manualCount))" : "⏱️ Manual"
                                        ))
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(MycoTheme.amber.opacity(0.35), lineWidth: 1))
                                }
                            }
                            
                            Divider().background(MycoTheme.border)
                            
                            // 24/7 BACKGROUND HUB & SENSOR CONTINUITY TOGGLE
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.caption)
                                        .foregroundColor(store.db.environmentConfig.is24_7HubBackgroundModeEnabled ? Color.green : MycoTheme.textSecondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.t(nl: "24/7 Achtergrond Hub & Sensor Data", en: "24/7 Background Hub & Sensor Data"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        Text(store.t(nl: "Blijft schakelen & sensoren uitlezen wanneer app gesloten is", en: "Keeps switching & polling sensors when app is in background"))
                                            .font(.system(size: 10))
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { store.db.environmentConfig.is24_7HubBackgroundModeEnabled },
                                        set: { val in
                                            store.db.environmentConfig.is24_7HubBackgroundModeEnabled = val
                                            store.save()
                                            if val {
                                                MycoBackgroundHubManager.shared.startBackgroundHub()
                                            } else {
                                                MycoBackgroundHubManager.shared.stopBackgroundHub()
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                    .scaleEffect(0.85)
                                    .tint(Color.green)
                                }
                                
                                HStack {
                                    Image(systemName: "sun.max.fill")
                                        .font(.caption)
                                        .foregroundColor(store.db.environmentConfig.isScreenAlwaysOnEnabled ? MycoTheme.amber : MycoTheme.textSecondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.t(nl: "Scherm Altijd Aan (Kweek-Hub Modus)", en: "Screen Always On (Grow-Hub Mode)"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        Text(store.t(nl: "Voorkomt schermvergrendeling voor permanente monitoring", en: "Prevents lock screen for permanent monitoring"))
                                            .font(.system(size: 10))
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { store.db.environmentConfig.isScreenAlwaysOnEnabled },
                                        set: { val in
                                            store.db.environmentConfig.isScreenAlwaysOnEnabled = val
                                            store.save()
                                            MycoBackgroundHubManager.shared.setKeepScreenOn(val)
                                        }
                                    ))
                                    .labelsHidden()
                                    .scaleEffect(0.85)
                                    .tint(MycoTheme.amber)
                                }
                                
                                if store.db.environmentConfig.is24_7HubBackgroundModeEnabled {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                        Text(store.t(
                                            nl: "Actief: 15s Autopilot & Sensor-loop • Audio Keep-Alive • Thermisch: \(MycoBackgroundHubManager.shared.thermalStateLabelNL)",
                                            en: "Active: 15s Autopilot & Sensor loop • Audio Keep-Alive • Thermal: \(MycoBackgroundHubManager.shared.thermalStateLabelEN)"
                                        ))
                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Color.green.opacity(0.9))
                                        Spacer()
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                        }
                    }

                    // MARK: - KRITIEKE PUSH-MELDINGEN OP AFSTAND (NAAR KIJKER-TELEFOON)
                    MycoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(store.db.environmentConfig.enableRemoteAlertNotifications ? Color.red.opacity(0.2) : Color.gray.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "bell.badge.fill")
                                        .font(.headline)
                                        .foregroundColor(store.db.environmentConfig.enableRemoteAlertNotifications ? Color.red : Color.gray)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(store.t(nl: "Kritieke Meldingen op Afstand", en: "Remote Critical Alerts"))
                                            .font(.headline.bold())
                                            .foregroundColor(.white)
                                        Circle()
                                            .fill(store.db.environmentConfig.enableRemoteAlertNotifications ? Color.green : Color.gray.opacity(0.4))
                                            .frame(width: 8, height: 8)
                                    }
                                    Text(store.db.environmentConfig.enableRemoteAlertNotifications
                                         ? store.t(nl: "Stuurt push-alarm naar je kijker-telefoon bij gevaar", en: "Pushes alert to viewer phone upon hazards")
                                         : store.t(nl: "Uitgeschakeld", en: "Disabled"))
                                        .font(.subheadline)
                                        .foregroundColor(store.db.environmentConfig.enableRemoteAlertNotifications ? Color.green : MycoTheme.textSecondary)
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { store.db.environmentConfig.enableRemoteAlertNotifications },
                                    set: { val in
                                        store.db.environmentConfig.enableRemoteAlertNotifications = val
                                        store.saveImmediately()
                                        if val {
                                            MycoLabAlertManager.shared.requestNotificationPermission()
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .tint(MycoTheme.green)
                            }

                            if store.db.environmentConfig.enableRemoteAlertNotifications {
                                VStack(spacing: 10) {
                                    // Min RV Threshold
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(store.t(nl: "Alarm bij RV onder", en: "Alert if RH below"))
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                            Text(store.t(nl: "Voorkomt uitdroging van mycelium & paddo's", en: "Prevents mycelium & pinhead desiccation"))
                                                .font(.system(size: 10))
                                                .foregroundColor(MycoTheme.textSecondary)
                                        }
                                        Spacer()
                                        Stepper("\(Int(store.db.environmentConfig.minHumidityAlertThresholdPct))%", value: Binding(
                                            get: { store.db.environmentConfig.minHumidityAlertThresholdPct },
                                            set: { store.db.environmentConfig.minHumidityAlertThresholdPct = $0; store.saveImmediately() }
                                        ), in: 60...95, step: 5)
                                        .labelsHidden()
                                        Text("\(Int(store.db.environmentConfig.minHumidityAlertThresholdPct))%")
                                            .font(.subheadline.bold().monospacedDigit())
                                            .foregroundColor(MycoTheme.blue)
                                            .frame(width: 40, alignment: .trailing)
                                    }

                                    Divider().background(Color.white.opacity(0.1))

                                    // Max Temp Threshold
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(store.t(nl: "Alarm bij Temp boven", en: "Alert if Temp above"))
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                            Text(store.t(nl: "Verlaagt contaminatierisico (Trichoderma)", en: "Reduces mold contamination risk"))
                                                .font(.system(size: 10))
                                                .foregroundColor(MycoTheme.textSecondary)
                                        }
                                        Spacer()
                                        Stepper("\(String(format: "%.1f", store.db.environmentConfig.maxTempAlertThresholdC))°C", value: Binding(
                                            get: { store.db.environmentConfig.maxTempAlertThresholdC },
                                            set: { store.db.environmentConfig.maxTempAlertThresholdC = $0; store.saveImmediately() }
                                        ), in: 24.0...35.0, step: 0.5)
                                        .labelsHidden()
                                        Text("\(String(format: "%.1f", store.db.environmentConfig.maxTempAlertThresholdC))°C")
                                            .font(.subheadline.bold().monospacedDigit())
                                            .foregroundColor(MycoTheme.amber)
                                            .frame(width: 50, alignment: .trailing)
                                    }

                                    Divider().background(Color.white.opacity(0.1))

                                    // Min Battery Threshold
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(store.t(nl: "Camera Batterij Alarm", en: "Camera Battery Alert"))
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                            Text(store.t(nl: "Waarschuwt als stekker statief losraakt", en: "Warns if tripod charger disconnects"))
                                                .font(.system(size: 10))
                                                .foregroundColor(MycoTheme.textSecondary)
                                        }
                                        Spacer()
                                        Stepper("\(store.db.environmentConfig.minBatteryAlertThresholdPct)%", value: Binding(
                                            get: { store.db.environmentConfig.minBatteryAlertThresholdPct },
                                            set: { store.db.environmentConfig.minBatteryAlertThresholdPct = $0; store.saveImmediately() }
                                        ), in: 5...30, step: 5)
                                        .labelsHidden()
                                        Text("\(store.db.environmentConfig.minBatteryAlertThresholdPct)%")
                                            .font(.subheadline.bold().monospacedDigit())
                                            .foregroundColor(.yellow)
                                            .frame(width: 40, alignment: .trailing)
                                    }

                                    Divider().background(Color.white.opacity(0.1))

                                    // Test Alert Button
                                    Button {
                                        MycoLabAlertManager.shared.dispatchAlert(
                                            severity: .warning,
                                            category: .lowHumidity,
                                            title: "🧪 MycoLabs Test Push-Alarm",
                                            message: "Verbinding en meldingen werken perfect! Zowel op deze telefoon als op je gekoppelde apparaten.",
                                            currentValue: 74.0,
                                            thresholdValue: store.db.environmentConfig.minHumidityAlertThresholdPct,
                                            store: store
                                        )
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "paperplane.fill")
                                            Text(store.t(nl: "Stuur Test Push-Melding", en: "Send Test Push Alert"))
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(10)
                            }
                        }
                    }
                    
                    // MARK: - ONDERHOUDSMODUS (BEZIG IN KWEEKRUIMTE)
                    MycoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(store.db.environmentConfig.isMaintenanceModeActive ? Color.orange.opacity(0.2) : Color.gray.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                        .font(.headline)
                                        .foregroundColor(store.db.environmentConfig.isMaintenanceModeActive ? Color.orange : Color.gray)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(store.t(nl: "Onderhoudsmodus", en: "Maintenance Mode"))
                                            .font(.headline.bold())
                                            .foregroundColor(.white)
                                        Circle()
                                            .fill(store.db.environmentConfig.isMaintenanceModeActive ? Color.orange : Color.gray.opacity(0.4))
                                            .frame(width: 8, height: 8)
                                    }
                                    Text(store.db.environmentConfig.isMaintenanceModeActive
                                         ? store.t(nl: "Actief: Ventilatoren & bevochtigers uit, schema's bevroren", en: "Active: Fans & humidifiers off, automations frozen")
                                         : store.t(nl: "Schakel in wanneer je bezig bent in de kweekruimte", en: "Enable when working inside the grow space"))
                                        .font(.caption)
                                        .foregroundColor(store.db.environmentConfig.isMaintenanceModeActive ? Color.orange : MycoTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { store.db.environmentConfig.isMaintenanceModeActive },
                                    set: { val in
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            store.setMaintenanceMode(enabled: val, durationMinutes: store.db.environmentConfig.maintenanceModeAutoResumeMinutes)
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .tint(Color.orange)
                            }
                            
                            // Timer duration picker & Active countdown info
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Text(store.t(nl: "Veiligheidstimer herstel:", en: "Auto-resume safety timer:"))
                                        .font(.caption)
                                        .foregroundColor(MycoTheme.textSecondary)
                                    
                                    Spacer()
                                    
                                    Picker("", selection: Binding(
                                        get: { store.db.environmentConfig.maintenanceModeAutoResumeMinutes },
                                        set: { val in
                                            store.db.environmentConfig.maintenanceModeAutoResumeMinutes = val
                                            store.save()
                                        }
                                    )) {
                                        Text(store.t(nl: "Handmatig", en: "Manual")).tag(0)
                                        Text("15m").tag(15)
                                        Text(store.t(nl: "30m (Aanbevolen)", en: "30m (Recommended)")).tag(30)
                                        Text("60m").tag(60)
                                        Text("120m").tag(120)
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Color.orange)
                                }
                                
                                if store.db.environmentConfig.isMaintenanceModeActive {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.badge.checkmark.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        
                                        if let start = store.db.environmentConfig.maintenanceModeStartTime {
                                            let elapsedMins = Int(Date().timeIntervalSince(start) / 60.0)
                                            if store.db.environmentConfig.maintenanceModeAutoResumeMinutes > 0 {
                                                let remaining = max(0, store.db.environmentConfig.maintenanceModeAutoResumeMinutes - elapsedMins)
                                                Text(store.t(
                                                    nl: "Loopt al \(elapsedMins) min • Hervat automatisch over ~\(remaining) min",
                                                    en: "Running for \(elapsedMins) min • Auto-resumes in ~\(remaining) min"
                                                ))
                                                .font(.caption.bold())
                                                .foregroundColor(.orange)
                                            } else {
                                                Text(store.t(
                                                    nl: "Loopt al \(elapsedMins) min • Blijft actief tot handmatig uitgezet",
                                                    en: "Running for \(elapsedMins) min • Stays active until manually stopped"
                                                ))
                                                .font(.caption.bold())
                                                .foregroundColor(.orange)
                                            }
                                        }
                                        Spacer()
                                        
                                        Button {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                store.setMaintenanceMode(enabled: false)
                                            }
                                        } label: {
                                            Text(store.t(nl: "Nu Hervatten", en: "Resume Now"))
                                                .font(.caption2.bold())
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(Color.orange)
                                                .cornerRadius(6)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color.orange.opacity(0.12))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                        }
                    }
                    
                    // GROW SPACE DIMENSIONS & AI AIRFLOW CARD
                    MycoCard {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(MycoTheme.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "cube.transparent.fill")
                                    .font(.title3)
                                    .foregroundColor(MycoTheme.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text(store.db.environmentConfig.spacePreset)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Text("• \(String(format: "%.2f", store.db.environmentConfig.roomVolumeM3)) m³ (\(Int(store.db.environmentConfig.roomVolumeLiters))L)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(MycoTheme.blue)
                                }
                                Text(store.t(
                                    nl: "AI Berekening: Afzuiging elke \(store.db.environmentConfig.faeIntervalMinutes)m (\(store.db.environmentConfig.faeDurationMinutes)m loop) • ~\(Int(store.db.environmentConfig.aiDailyWaterUsageMl)) ml water/dag",
                                    en: "AI Calculation: FAE every \(store.db.environmentConfig.faeIntervalMinutes)m (\(store.db.environmentConfig.faeDurationMinutes)m run) • ~\(Int(store.db.environmentConfig.aiDailyWaterUsageMl)) ml water/day"
                                ))
                                .font(.system(size: 10))
                                .foregroundColor(MycoTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                showSpaceCalculator = true
                            } label: {
                                Text(store.t(nl: "Formaat & AI", en: "Size & AI"))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(MycoTheme.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // OPTICAL TELEPHOTO METER & ADVANCE HUMIDIFIER CONTROL CARD
                    MycoCard {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "binoculars.fill")
                                    .font(.headline)
                                    .foregroundColor(Color.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(store.t(nl: "Optische Telelens Meter", en: "Optical Telephoto Meter"))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    if MycoOpticalHygrometerManager.shared.config.isEnabled {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                Text(store.t(
                                    nl: "Leest fysieke displays via telelens & berekent nevelduur vooraf tegen condensblindheid",
                                    en: "Reads physical meters via telephoto & pre-calculates mist runtime against fog blindness"
                                ))
                                .font(.system(size: 10))
                                .foregroundColor(MycoTheme.textSecondary)
                                .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Button {
                                showOpticalHygrometerSheet = true
                            } label: {
                                Text(store.t(nl: "Open Scanner", en: "Open Scanner"))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Climate Environment Header
                    MycoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "leaf.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(MycoTheme.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.db.environmentConfig.environmentName)
                                        .font(.headline.bold())
                                        .foregroundColor(.white)
                                    Text(store.t(nl: "Geautomatiseerd Kweekklimaat", en: "Automated Grow Climate"))
                                        .font(.caption)
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                Spacer()
                            }
                            
                            Divider().background(MycoTheme.border)
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "TEMPERATUUR", en: "TEMPERATURE"))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    if let currentT = store.latestSensorTempC {
                                        Text(String(format: "%.1f°C", currentT))
                                            .font(.system(.title3, design: .monospaced).bold())
                                            .foregroundColor(.white)
                                    } else {
                                        Text("--.-°C")
                                            .font(.system(.title3, design: .monospaced).bold())
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                    Text(store.t(nl: "Doel: \(String(format: "%.1f°C", store.db.environmentConfig.targetDayTempC))", en: "Target: \(String(format: "%.1f°C", store.db.environmentConfig.targetDayTempC))"))
                                        .font(.system(size: 10))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "LUCHTVOCHTIGHEID", en: "HUMIDITY"))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    if let currentH = store.latestSensorHumidityPct {
                                        Text(String(format: "%.0f%% RV", currentH))
                                            .font(.system(.title3, design: .monospaced).bold())
                                            .foregroundColor(MycoTheme.blue)
                                    } else {
                                        Text("--% RV")
                                            .font(.system(.title3, design: .monospaced).bold())
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                    Text(store.t(nl: "Doel: \(String(format: "%.0f%% RV", store.db.environmentConfig.targetHumidityPct))", en: "Target: \(String(format: "%.0f%% RV", store.db.environmentConfig.targetHumidityPct))"))
                                        .font(.system(size: 10))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "FAE VENTILATIE", en: "FAE EXHAUST"))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    Text("Elke \(store.db.environmentConfig.faeIntervalMinutes / 60)u")
                                        .font(.system(.subheadline, design: .monospaced).bold())
                                        .foregroundColor(MycoTheme.amber)
                                    Text(store.t(nl: "Duur: \(store.db.environmentConfig.faeDurationMinutes)m", en: "Duration: \(store.db.environmentConfig.faeDurationMinutes)m"))
                                        .font(.system(size: 10))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                        }
                    }

                    // Dag / Nacht Klimaatprofiel & Pinning Inductie Card
                    MycoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: store.db.environmentConfig.isPinningInductionActive ? "snowflake" : (store.db.environmentConfig.isCurrentlyDayTime ? "sun.max.fill" : "moon.stars.fill"))
                                    .foregroundColor(store.db.environmentConfig.isPinningInductionActive ? Color.cyan : (store.db.environmentConfig.isCurrentlyDayTime ? Color.orange : Color.indigo))
                                Text(store.t(nl: "Dag / Nacht & Pinning Klimaatprofielen", en: "Day / Night & Pinning Profiles"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text(store.db.environmentConfig.isPinningInductionActive ? "PINNING SHOCK" : (store.db.environmentConfig.isCurrentlyDayTime ? "DAG CYCLUS" : "NACHT CYCLUS"))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background((store.db.environmentConfig.isPinningInductionActive ? Color.cyan : (store.db.environmentConfig.isCurrentlyDayTime ? Color.orange : Color.indigo)).opacity(0.2))
                                    .foregroundColor(store.db.environmentConfig.isPinningInductionActive ? Color.cyan : (store.db.environmentConfig.isCurrentlyDayTime ? Color.orange : Color.indigo))
                                    .cornerRadius(4)
                            }
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "DAG DOEL", en: "DAY TARGET"))
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    Text(String(format: "%.1f°C", store.db.environmentConfig.targetDayTempC))
                                        .font(.system(.callout, design: .monospaced).bold())
                                        .foregroundColor(.orange)
                                    Text("07:00 - 21:00")
                                        .font(.system(size: 9))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "NACHT DOEL", en: "NIGHT TARGET"))
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    Text(String(format: "%.1f°C", store.db.environmentConfig.targetNightTempC))
                                        .font(.system(.callout, design: .monospaced).bold())
                                        .foregroundColor(Color.indigo)
                                    Text("21:00 - 07:00")
                                        .font(.system(size: 9))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "ACTIEF DOEL", en: "ACTIVE TARGET"))
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    Text(String(format: "%.1f°C", store.db.environmentConfig.effectiveTargetTempC))
                                        .font(.system(.callout, design: .monospaced).bold())
                                        .foregroundColor(MycoTheme.green)
                                    Text(store.db.environmentConfig.isPinningInductionActive ? "Koudeval" : "Normaal")
                                        .font(.system(size: 9))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                            
                            Divider().background(MycoTheme.border)
                            
                            HStack(spacing: 8) {
                                Button {
                                    withAnimation {
                                        store.db.environmentConfig.isPinningInductionActive.toggle()
                                        store.saveImmediately()
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: store.db.environmentConfig.isPinningInductionActive ? "snowflake.slash" : "snowflake")
                                        Text(store.db.environmentConfig.isPinningInductionActive ? store.t(nl: "Stop Pinning Trigger", en: "Stop Pinning Trigger") : store.t(nl: "Activeer Pinning Trigger (18.5°C)", en: "Trigger Pinning Shock (18.5°C)"))
                                    }
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(store.db.environmentConfig.isPinningInductionActive ? Color.red.opacity(0.8) : Color.cyan.opacity(0.8))
                                    .cornerRadius(6)
                                }
                                
                                Toggle("", isOn: Binding(
                                    get: { store.db.environmentConfig.isDayNightCycleEnabled },
                                    set: { val in
                                        store.db.environmentConfig.isDayNightCycleEnabled = val
                                        store.saveImmediately()
                                    }
                                ))
                                .labelsHidden()
                                .tint(MycoTheme.blue)
                            }
                        }
                    }

                    
                    // AI Kweekklimaat Suggestie Card (Strictly bound to REAL sensor data)
                    MycoCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(MycoTheme.blue)
                                Text(store.t(nl: "AI Kweekklimaat Analyse", en: "AI Grow Climate Analysis"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            if !store.hasConnectedSensor || store.latestSensorHumidityPct == nil {
                                // EMPTY STATE: Strictly real sensor data permitted
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(store.t(
                                        nl: "Geen actieve klimaatsensor gekoppeld of meetdata ontvangen. Koppel een Tuya sensor of stuur data via de sensor API om live meetwaarden en AI-klimaatanalyses te activeren.",
                                        en: "No active climate sensor connected or readings received yet. Connect a Tuya sensor or send data via the sensor API to activate live readings and AI climate analysis."
                                    ))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                    
                                    Button {
                                        showAddDevice = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus.circle.fill")
                                            Text(store.t(nl: "+ Klimaatsensor Koppelen", en: "+ Connect Climate Sensor"))
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(MycoTheme.blue)
                                        .cornerRadius(8)
                                    }
                                    .padding(.top, 4)
                                }
                            } else {
                                // SENSOR DATA PRESENT: Dynamic real analysis!
                                let h = store.latestSensorHumidityPct!
                                let targetH = store.db.environmentConfig.targetHumidityPct
                                let isLow = h < (targetH - 3.0)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    if isLow {
                                        Text(store.t(
                                            nl: "Vochtigheidssensor meet \(Int(h))% RV (doel is \(Int(targetH))% RV). Luchtbevochtiger inschakelen aanbevolen om droogte te voorkomen.",
                                            en: "Sensor reads \(Int(h))% RH (target is \(Int(targetH))% RH). Humidifier recommended to prevent drying out."
                                        ))
                                        .font(.caption)
                                        .foregroundColor(Color.orange)
                                    } else {
                                        Text(store.t(
                                            nl: "Vochtigheid is optimaal op \(Int(h))% RV (doel: \(Int(targetH))% RV). Kweekklimaat is stabiel.",
                                            en: "Humidity is optimal at \(Int(h))% RH (target: \(Int(targetH))% RH). Grow environment is stable."
                                        ))
                                        .font(.caption)
                                        .foregroundColor(Color.green)
                                    }
                                    
                                    HStack {
                                        Button {
                                            if let plug = store.db.smartDevices.first(where: { $0.deviceType == "Humidifier" }) {
                                                store.toggleSmartDevice(id: plug.id)
                                            } else {
                                                showAddDevice = true
                                            }
                                        } label: {
                                            Text(store.t(nl: "⚡️ Activeer Luchtbevochtiger", en: "⚡️ Trigger Humidifier"))
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(MycoTheme.blue)
                                                .cornerRadius(8)
                                        }
                                        
                                        Button {
                                            if let fan = store.db.smartDevices.first(where: { $0.deviceType == "ExhaustFan" }) {
                                                store.toggleSmartDevice(id: fan.id)
                                            } else {
                                                showAddDevice = true
                                            }
                                        } label: {
                                            Text(store.t(nl: "🌪 5m FAE Cyclus", en: "🌪 5m FAE Cycle"))
                                                .font(.caption.bold())
                                                .foregroundColor(MycoTheme.amber)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(MycoTheme.amber.opacity(0.15))
                                                .cornerRadius(8)
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            store.removeAllSensorsAndData()
                                        } label: {
                                            Text(store.t(nl: "Wis Data", en: "Clear Data"))
                                                .font(.caption2)
                                                .foregroundColor(MycoTheme.textSecondary)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    
                    // Smart Stekkers List
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(store.t(nl: "Gekoppelde Tuya & Smart Stekkers", en: "Connected Tuya & Smart Plugs"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Spacer()
                            
                            if !store.db.smartDevices.isEmpty {
                                Button(role: .destructive) {
                                    showConfirmClearAll = true
                                } label: {
                                    Text(store.t(nl: "Alles Wissen", en: "Clear All"))
                                        .font(.caption.bold())
                                        .foregroundColor(Color.red)
                                }
                                .padding(.trailing, 6)
                            }
                            
                            Button {
                                showAddDevice = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text(store.t(nl: "Toevoegen", en: "Add"))
                                }
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.blue)
                            }
                        }
                        
                        if store.db.smartDevices.isEmpty {
                            EmptyStateCard(
                                icon: "powerplug.fill",
                                title: store.t(nl: "Nog geen smart apparaten gekoppeld", en: "No smart devices connected"),
                                message: store.t(nl: "Voeg je eigen Tuya of Smart Life stekkers, bevochtiger of ventilatoren toe met de knop hierboven.", en: "Add your own Tuya or Smart Life plugs, humidifiers or fans using the button above."),
                                buttonTitle: store.t(nl: "+ Smart Stekker Toevoegen", en: "+ Add Smart Plug")
                            ) {
                                showAddDevice = true
                            }
                        } else {
                            ForEach(store.db.smartDevices) { device in
                                SmartDeviceRowView(device: device) {
                                    editingDevice = device
                                }
                            }
                        }
                    }
                    
                    // RASPBERRY PI 24/7 LAB HUB INTEGRATION CARD
                    MycoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill((store.piHubStatusOnline ? Color.green : Color.orange).opacity(0.18))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "cpu.fill")
                                        .font(.headline)
                                        .foregroundColor(store.piHubStatusOnline ? Color.green : Color.orange)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(store.t(nl: "Raspberry Pi 24/7 Lab Hub", en: "Raspberry Pi 24/7 Lab Hub"))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                        
                                        Circle()
                                            .fill(store.piHubStatusOnline ? Color.green : Color.orange)
                                            .frame(width: 7, height: 7)
                                    }
                                    
                                    if store.piHubStatusOnline {
                                        Text(store.t(
                                            nl: "Live Verbonden • \(store.db.environmentConfig.effectivePiHubIP)",
                                            en: "Live Connected • \(store.db.environmentConfig.effectivePiHubIP)"
                                        ))
                                        .font(.caption)
                                        .foregroundColor(Color.green)
                                    } else {
                                        Text(store.t(
                                            nl: "Zoeken naar Hub • \(store.db.environmentConfig.effectivePiHubIP)",
                                            en: "Searching Hub • \(store.db.environmentConfig.effectivePiHubIP)"
                                        ))
                                        .font(.caption)
                                        .foregroundColor(Color.orange)
                                    }
                                }
                                
                                Spacer()
                                
                                Button {
                                    showPiHubSheet = true
                                } label: {
                                    Text(store.t(nl: "Beheer", en: "Manage"))
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(MycoTheme.blue)
                                        .cornerRadius(8)
                                }
                            }
                            
                            Divider().background(MycoTheme.border)
                            
                            // 24/7 Autonomous Hardware Engine
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: "bolt.shield.fill")
                                        .font(.subheadline)
                                        .foregroundColor(Color.green)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(store.t(nl: "24/7 Zelfstandige Autopilot", en: "24/7 Autonomous Autopilot"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        Text(store.t(
                                            nl: "Schema's draaien 100% lokaal op de Pi. Werkt altijd door, zelfs als je iPhone leeg of offline is!",
                                            en: "Schedules run 100% locally on the Pi. Continues running even when your iPhone is offline!"
                                        ))
                                        .font(.system(size: 11))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    }
                                    Spacer()
                                }
                                
                                HStack(spacing: 6) {
                                    Text("⚡️ 100% Lokaal LAN")
                                        .font(.caption2.bold())
                                        .foregroundColor(Color.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.green.opacity(0.15))
                                        .cornerRadius(6)
                                    
                                    if let syncDate = store.db.environmentConfig.lastPiHubSyncTime {
                                        Text("Laatst gesynchroniseerd: \(syncDate.formatted(date: .omitted, time: .shortened))")
                                            .font(.system(size: 10))
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                }
                                
                                // Action Bar
                                HStack(spacing: 8) {
                                    Button {
                                        let gen = UIImpactFeedbackGenerator(style: .medium)
                                        gen.impactOccurred()
                                        Task {
                                            await store.syncSchedulesToPiHub()
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            if store.isSyncingPiHub {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.7)
                                            } else {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                            }
                                            Text(store.t(nl: "Nu Syncen", en: "Sync Now"))
                                                .font(.caption.bold())
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Color.green.opacity(0.85))
                                        .cornerRadius(8)
                                    }
                                    .disabled(store.isSyncingPiHub)
                                    
                                    Button {
                                        showPiHubLogSheet = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                                            Text(store.t(nl: "Pi Logboek", en: "Pi Hub Log"))
                                                .font(.caption.bold())
                                        }
                                        .foregroundColor(MycoTheme.blue)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 7)
                                        .background(MycoTheme.blue.opacity(0.18))
                                        .cornerRadius(8)
                                    }
                                    
                                    Spacer()
                                    
                                    // Eenmalig koppelen wizard button
                                    Button {
                                        showTuyaCloudSheet = true
                                    } label: {
                                        HStack(spacing: 3) {
                                            Image(systemName: "link.badge.plus")
                                            Text(store.t(nl: "Koppel Wizard", en: "Pairing Wizard"))
                                        }
                                        .font(.system(size: 10))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    
                    // MARK: - Device Switch & Error Log Card
                    MycoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(MycoTheme.green)
                                Text(store.t(nl: "Apparaat Schakel- & Foutenlog", en: "Device Switch & Error Log"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if !store.db.smartDeviceLogs.isEmpty {
                                    let errorCount = store.db.smartDeviceLogs.filter { !$0.isSuccess || ($0.errorMessage?.isEmpty == false) }.count
                                    if errorCount > 0 {
                                        Text("\(errorCount) " + store.t(nl: "fout(en)", en: "error(s)"))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.18))
                                            .cornerRadius(4)
                                    }
                                    
                                    Button {
                                        showConfirmClearLogs = true
                                    } label: {
                                        Text(store.t(nl: "Wissen", en: "Clear"))
                                            .font(.caption2.bold())
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                }
                            }
                            
                            if store.db.smartDeviceLogs.isEmpty {
                                Text(store.t(
                                    nl: "Nog geen schakelactiviteiten geregistreerd. Zodra apparaten aan- of uitgaan (handmatig of via Autopilot) en eventuele verbindingsfouten optreden, verschijnen ze hier live.",
                                    en: "No device switch events recorded yet. When devices turn ON or OFF (manually or via Autopilot) or connection errors occur, they appear here live."
                                ))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                .padding(.vertical, 4)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(Array(store.db.smartDeviceLogs.prefix(5))) { log in
                                        SmartDeviceLogCompactRow(log: log)
                                    }
                                }
                                
                                Button {
                                    showDeviceLogSheet = true
                                } label: {
                                    HStack {
                                        Text(store.t(
                                            nl: "Bekijk volledig logboek (\(store.db.smartDeviceLogs.count) regels) ➔",
                                            en: "View full activity log (\(store.db.smartDeviceLogs.count) events) ➔"
                                        ))
                                        .font(.caption.bold())
                                        .foregroundColor(MycoTheme.blue)
                                        Spacer()
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    
                    // MARK: - Home Assistant & Externe Webhooks Card (Alles in 1 Hub)
                    MycoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "house.and.flag.fill")
                                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 1.0))
                                Text(store.t(nl: "Home Assistant & Externe Webhooks", en: "Home Assistant & External Webhooks"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            Text(store.t(
                                nl: "Koppel externe Home Assistant sensoren, ESP32 of Apple Shortcuts via de directe MycoLabs Webhook API of exporteer kant-en-klare YAML configuraties.",
                                en: "Connect external Home Assistant sensors, ESP32 or Apple Shortcuts via the direct MycoLabs Webhook API or export ready-to-use YAML configurations."
                            ))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                            
                            HStack(spacing: 10) {
                                Button {
                                    showHomeAssistantSheet = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.text.fill")
                                        Text(store.t(nl: "Home Assistant YAML", en: "Home Assistant YAML"))
                                    }
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.1, green: 0.6, blue: 0.9).opacity(0.25))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.2, green: 0.7, blue: 1.0).opacity(0.4), lineWidth: 1))
                                }
                                
                                Button {
                                    UIPasteboard.general.string = store.db.webhookKey
                                    showWebhookCopiedAlert = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.on.doc.fill")
                                        Text(store.t(nl: "Kopieer API Sleutel", en: "Copy API Key"))
                                    }
                                    .font(.caption.bold())
                                    .foregroundColor(MycoTheme.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(MycoTheme.blue.opacity(0.16))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(16)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Smart Lab & Hardware Hub", en: "Smart Lab & Hardware Hub"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Klaar", en: "Done")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
            }
            .sheet(isPresented: $showAddDevice) {
                AddSmartDeviceSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTuyaCloudSheet) {
                TuyaSetupWizardSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showSpaceCalculator) {
                GrowSpaceSizeAndAIClimateView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showOpticalHygrometerSheet) {
                MycoOpticalHygrometerView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showAutopilotTest) {
                AutopilotQuickTestSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showManualSchedulesSheet) {
                AutopilotDeviceSchedulesSheet()
                    .environmentObject(store)
            }
            .sheet(item: $editingDevice) { dev in
                EditSmartDeviceSheet(device: dev)
                    .id(dev.id)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showDeviceLogSheet) {
                DeviceActivityLogSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTuyaDiagnostics) {
                TuyaCloudDiagnosticsSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTuyaMatrixSheet) {
                TuyaCloudScheduleMatrixSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showPiHubSheet) {
                PiLabHubSettingsSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showPiHubLogSheet) {
                PiLabHubLogSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showHomeAssistantSheet) {
                HomeAssistantYamlSheet()
                    .environmentObject(store)
            }
            .alert(store.t(nl: "API Sleutel Gekopieerd", en: "API Key Copied"), isPresented: $showWebhookCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.t(nl: "Webhook API sleutel is gekopieerd naar je klembord.", en: "Webhook API key copied to clipboard."))
            }
            .onAppear {
                Task {
                    _ = await store.checkPiHubOnline()
                    await store.fetchPiHubLogs()
                }
            }
            .alert(store.t(nl: "Alle apparaten verwijderen?", en: "Delete all devices?"), isPresented: $showConfirmClearAll) {
                Button(store.t(nl: "Verwijder Alles", en: "Delete All"), role: .destructive) {
                    withAnimation {
                        store.db.smartDevices.removeAll()
                        store.save()
                    }
                }
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
            } message: {
                Text(store.t(nl: "Weet je zeker dat je alle gekoppelde smart apparaten wilt wissen?", en: "Are you sure you want to remove all connected smart devices?"))
            }
            .alert(store.t(nl: "Apparaatlog wissen?", en: "Clear device log?"), isPresented: $showConfirmClearLogs) {
                Button(store.t(nl: "Wis Log", en: "Clear Log"), role: .destructive) {
                    store.clearSmartDeviceLogs()
                }
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
            } message: {
                Text(store.t(nl: "Weet je zeker dat je alle geregistreerde apparaatactiviteiten en foutmeldingen wilt wissen?", en: "Are you sure you want to clear all logged device activities and error messages?"))
            }
        }
    }
    
    private func iconForDeviceType(_ type: String) -> String {
        switch type {
        case "Humidifier": return "drop.fill"
        case "ExhaustFan": return "wind"
        case "Sensor": return "thermometer.medium"
        case "Heater": return "flame.fill"
        case "Light": return "lightbulb.fill"
        default: return "powerplug.fill"
        }
    }
    
    private func labelForDeviceType(_ type: String) -> String {
        switch type {
        case "Humidifier": return "Bevochtiger"
        case "ExhaustFan": return "Ventilator"
        case "Sensor": return "Sensor"
        case "Heater": return "Verwarming"
        case "Light": return "Lamp"
        default: return "Stekker"
        }
    }
}

// MARK: - SMART DEVICE LOG COMPACT ROW (Voor Hub Dashboard)

// MARK: - PRO TUYA CLOUD DIAGNOSTICS SHEET
struct TuyaCloudDiagnosticsSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var isRunning = false
    @State private var report: TuyaCloudManager.TuyaDiagnosticsReport? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header Card
                    MycoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(MycoTheme.amber.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.title3)
                                        .foregroundColor(MycoTheme.amber)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(store.t(nl: "Tuya Cloud 24/7 Diagnostiek", en: "Tuya Cloud 24/7 Diagnostics"))
                                            .font(.headline.bold())
                                            .foregroundColor(.white)
                                        
                                        Text("PRO")
                                            .font(.system(size: 9, weight: .black))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.orange))
                                            .foregroundColor(.black)
                                    }
                                    
                                    Text(store.t(
                                        nl: "Realtime gateway latency, token validatie & geverifieerde cloud timers",
                                        en: "Realtime gateway latency, token validation & verified cloud timers"
                                    ))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    
                    if !store.db.environmentConfig.isAutopilotEnabled {
                        MycoCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Color.orange)
                                    Text(store.t(nl: "24/7 Autopilot Staat Momenteel UIT", en: "24/7 Autopilot Is Currently OFF"))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                }
                                
                                Text(store.t(
                                    nl: "Hierdoor staat het aantal Cloud Timers op 0. Schema's (zoals dag/nacht licht, FAE ventilatie en bevochtiging) worden pas naar Tuya Cloud geprogrammeerd zodra Autopilot actief is.",
                                    en: "This is why Cloud Timers is currently 0. Automation schedules (like light cycle, FAE ventilation and humidity) are only programmed onto Tuya Cloud when Autopilot is active."
                                ))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                
                                Button {
                                    store.db.environmentConfig.isAutopilotEnabled = true
                                    store.save()
                                    let gen = UINotificationFeedbackGenerator()
                                    gen.notificationOccurred(.success)
                                    Task { await store.syncSchedulesToPiHub() }
                                    if (store.db.environmentConfig.tuyaOfflineAutonomousActive ?? false) {
                                        store.syncAllSchedulesToTuyaCloud()
                                    }
                                    runTest()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bolt.fill")
                                        Text(store.t(nl: "Activeer Autopilot Nu & Synchroniseer", en: "Activate Autopilot Now & Sync"))
                                    }
                                    .font(.caption.bold())
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(MycoTheme.green)
                                    .cornerRadius(8)
                                }
                                .padding(.top, 2)
                            }
                        }
                    }
                    
                    // Metrics Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MycoCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.t(nl: "Gateway Latency", en: "Gateway Latency"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.horizontal.fill")
                                        .foregroundColor(Color.green)
                                    Text(report.map { "\($0.latencyMs) ms" } ?? "-- ms")
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                }
                                Text("Datacenter: \(store.db.environmentConfig.tuyaRegion.uppercased())")
                                    .font(.system(size: 10))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        
                        MycoCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.t(nl: "HMAC Authenticatie", en: "HMAC Authentication"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                HStack(spacing: 4) {
                                    Image(systemName: (report?.tokenValid ?? false) ? "checkmark.seal.fill" : "lock.shield.fill")
                                        .foregroundColor((report?.tokenValid ?? false) ? Color.green : Color.orange)
                                    Text((report?.tokenValid ?? false) ? "Actief" : "Standby")
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                }
                                Text("SHA256 Handshake")
                                    .font(.system(size: 10))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        
                        MycoCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.t(nl: "Hardware Online", en: "Hardware Online"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                HStack(spacing: 4) {
                                    Image(systemName: "powerplug.fill")
                                        .foregroundColor(MycoTheme.blue)
                                    Text(report.map { "\($0.devicesOnline) / \($0.devicesChecked)" } ?? "--")
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                }
                                Text(store.t(nl: "Apparaten bereikbaar", en: "Devices reachable"))
                                    .font(.system(size: 10))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        
                        MycoCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.t(nl: "Cloud Timers", en: "Cloud Timers"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.badge.checkmark.fill")
                                        .foregroundColor(Color.green)
                                    Text(report.map { "\($0.cloudTimersFound)" } ?? "\(store.db.environmentConfig.offlineTimersCount)")
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                }
                                Text(store.t(nl: "Geverifieerd op Tuya", en: "Verified on Tuya"))
                                    .font(.system(size: 10))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                    }
                    
                    // Live Terminal Log Card
                    MycoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "terminal.fill")
                                    .foregroundColor(Color.green)
                                Text(store.t(nl: "Diagnostisch Logboek", en: "Diagnostic Log"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                if isRunning {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                if let report = report {
                                    ForEach(report.details, id: \.self) { line in
                                        Text(line)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(line.starts(with: "❌") ? Color.red : (line.starts(with: "⚠️") ? Color.orange : Color.green.opacity(0.9)))
                                    }
                                } else {
                                    Text(store.t(nl: "Diagnostiek wordt gestart...", en: "Starting diagnostics..."))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 10) {
                        Button {
                            runTest()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text(store.t(nl: "Test Opnieuw Uitvoeren", en: "Rerun Diagnostics"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(MycoTheme.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isRunning)
                        
                        Button {
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.success)
                            if !store.db.environmentConfig.isAutopilotEnabled {
                                store.db.environmentConfig.isAutopilotEnabled = true
                                store.save()
                            }
                            Task { await store.syncSchedulesToPiHub() }
                            if (store.db.environmentConfig.tuyaOfflineAutonomousActive ?? false) {
                                store.syncAllSchedulesToTuyaCloud()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                self.runTest()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "icloud.and.arrow.up.fill")
                                Text(store.t(nl: "Forceer Volledige Herprogrammering", en: "Force Complete Reprogramming"))
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(Color.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(16)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Tuya Diagnostiek", en: "Tuya Diagnostics"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
            }
            .onAppear {
                runTest()
            }
        }
    }
    
    private func runTest() {
        isRunning = true
        let clientId = store.db.environmentConfig.tuyaApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = store.db.environmentConfig.tuyaApiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = store.db.environmentConfig.tuyaRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        let devices = store.db.smartDevices
        let isAutopilot = store.db.environmentConfig.isAutopilotEnabled
        
        Task {
            let res = await TuyaCloudManager.shared.runDiagnostics(
                devices: devices,
                isAutopilotActive: isAutopilot,
                clientId: clientId,
                secret: secret,
                region: region
            )
            await MainActor.run {
                self.report = res
                self.isRunning = false
            }
        }
    }
}

// MARK: - PRO TUYA CLOUD SCHEDULE MATRIX SHEET
struct TuyaCloudScheduleMatrixSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @State private var copiedToClipboard = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header Card
                    MycoCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "tablecells.fill")
                                    .foregroundColor(MycoTheme.blue)
                                Text(store.t(nl: "Tuya Cloud 24/7 Automatisering Matrix", en: "Tuya Cloud 24/7 Automation Matrix"))
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text("PRO")
                                    .font(.system(size: 9, weight: .black))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.orange))
                                    .foregroundColor(.black)
                            }
                            
                            Text(store.t(
                                nl: "Deze schema's zijn opgeslagen in Tuya Cloud en worden autonoom door de slimme stekkers uitgevoerd, zelfs als alle telefoons offline zijn.",
                                en: "These schedules are stored in Tuya Cloud and executed autonomously by smart plugs, even when all phones are offline."
                            ))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                            
                            Divider().background(MycoTheme.border)
                            
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.green).frame(width: 6, height: 6)
                                    Text("Repeat: Elke dag (1111111)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Color.green)
                                }
                                
                                Spacer()
                                
                                Text("Categorie: mycolab")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                    }
                    
                    // Device Schedules List
                    let actionableDevices = store.db.smartDevices.filter { $0.deviceType != "Sensor" && !$0.tuyaDeviceID.isEmpty }
                    
                    if actionableDevices.isEmpty {
                        EmptyStateCard(
                            icon: "powerplug.fill",
                            title: store.t(nl: "Geen Tuya stekkers gevonden", en: "No Tuya plugs found"),
                            message: store.t(nl: "Koppel slimme stekkers via Tuya om de 24/7 automatisering matrix te bekijken.", en: "Link smart plugs via Tuya to view the 24/7 automation matrix."),
                            buttonTitle: store.t(nl: "Sluiten", en: "Close")
                        ) {
                            dismiss()
                        }
                    } else {
                        ForEach(actionableDevices) { dev in
                            let schedules = store.buildTuyaSchedules(for: dev, ignoreAutopilotState: true)
                            MycoCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: SmartDeviceItem.icon(for: dev.deviceType))
                                            .foregroundColor(MycoTheme.blue)
                                        Text(dev.name)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        Text("\(schedules.count) timers")
                                            .font(.caption.bold())
                                            .foregroundColor(Color.green)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.green.opacity(0.15))
                                            .cornerRadius(6)
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Text("DP Code: \(dev.switchCode.isEmpty ? "switch_1" : dev.switchCode)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(MycoTheme.textSecondary)
                                        Text("•")
                                            .foregroundColor(MycoTheme.textSecondary)
                                        Text("Tuya ID: \(String(dev.tuyaDeviceID.prefix(10)))...")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                    
                                    Divider().background(MycoTheme.border)
                                    
                                    if schedules.isEmpty {
                                        Text(store.t(nl: "Geen schema's geconfigureerd (autocontrol staat uit).", en: "No schedules configured (autocontrol disabled)."))
                                            .font(.caption)
                                            .foregroundColor(MycoTheme.textSecondary)
                                    } else {
                                        VStack(spacing: 6) {
                                            ForEach(schedules) { task in
                                                HStack {
                                                    Circle()
                                                        .fill(task.value ? Color.green : Color.gray)
                                                        .frame(width: 6, height: 6)
                                                    
                                                    Text(task.time)
                                                        .font(.system(.caption, design: .monospaced).bold())
                                                        .foregroundColor(.white)
                                                        .frame(width: 50, alignment: .leading)
                                                    
                                                    Text(task.value ? "AAN" : "UIT")
                                                        .font(.caption.bold())
                                                        .foregroundColor(task.value ? Color.green : Color.orange)
                                                        .frame(width: 38, alignment: .leading)
                                                    
                                                    Text(task.aliasName)
                                                        .font(.caption)
                                                        .foregroundColor(MycoTheme.textSecondary)
                                                        .lineLimit(1)
                                                    
                                                    Spacer()
                                                }
                                                .padding(6)
                                                .background(Color.white.opacity(0.04))
                                                .cornerRadius(6)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Copy JSON & Re-sync Buttons
                    VStack(spacing: 10) {
                        Button {
                            copyScheduleJSON()
                        } label: {
                            HStack {
                                Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc.fill")
                                Text(copiedToClipboard ? store.t(nl: "Gekopieerd naar Klembord!", en: "Copied to Clipboard!") : store.t(nl: "Kopieer Schema als JSON", en: "Copy Schedule as JSON"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(MycoTheme.blue)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(16)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Automatisering Matrix", en: "Automation Matrix"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
            }
        }
    }
    
    private func copyScheduleJSON() {
        var allSchedules: [[String: Any]] = []
        for dev in store.db.smartDevices where dev.deviceType != "Sensor" {
            let tasks = store.buildTuyaSchedules(for: dev)
            let devSchedules = tasks.map { [
                "device": dev.name,
                "tuyaId": dev.tuyaDeviceID,
                "time": $0.time,
                "value": $0.value,
                "action": $0.value ? "AAN" : "UIT",
                "loops": $0.loops,
                "switchCode": $0.switchCode,
                "alias": $0.aliasName
            ] as [String: Any] }
            allSchedules.append(contentsOf: devSchedules)
        }
        if let data = try? JSONSerialization.data(withJSONObject: allSchedules, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = str
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
            withAnimation {
                copiedToClipboard = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                copiedToClipboard = false
            }
        }
    }
}


struct SmartDeviceLogCompactRow: View {
    @EnvironmentObject var store: MycoStore
    let log: SmartDeviceLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Device Icon
                Image(systemName: SmartDeviceItem.icon(for: log.deviceType))
                    .font(.caption)
                    .foregroundColor(log.isOn ? MycoTheme.green : MycoTheme.textSecondary)
                    .frame(width: 18)
                
                // Device Name
                Text(log.deviceName)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // State Badge: AAN (green) or UIT (gray)
                Text(log.isOn ? store.t(nl: "AAN", en: "ON") : store.t(nl: "UIT", en: "OFF"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(log.isOn ? .black : .white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(log.isOn ? MycoTheme.green : Color.white.opacity(0.18))
                    .cornerRadius(4)
                
                Spacer()
                
                // Timestamp
                Text(formattedTimestamp(log.timestamp))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(MycoTheme.textSecondary)
            }
            
            HStack(spacing: 6) {
                // Trigger source
                Text(log.trigger)
                    .font(.system(size: 10))
                    .foregroundColor(MycoTheme.blue)
                    .lineLimit(1)
                
                Spacer()
                
                if !log.isSuccess || (log.errorMessage?.isEmpty == false) {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                        Text(store.t(nl: "Fout", en: "Error"))
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(3)
                }
            }
            
            if let err = log.errorMessage, !err.isEmpty {
                Text("⚠️ " + err)
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .lineLimit(2)
                    .padding(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(4)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }
    
    private func formattedTimestamp(_ date: Date) -> String {
        let cal = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let timeStr = timeFormatter.string(from: date)
        
        if cal.isDateInToday(date) {
            return timeStr
        } else if cal.isDateInYesterday(date) {
            return "Gist. " + timeStr
        } else {
            let df = DateFormatter()
            df.dateFormat = "d MMM HH:mm:ss"
            return df.string(from: date)
        }
    }
}

// MARK: - DEVICE ACTIVITY & ERROR LOG SHEET (Volledig Logboek)
struct DeviceActivityLogSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var filterIndex: Int = 0 // 0: Alle, 1: Fouten, 2: AAN, 3: UIT
    @State private var searchText: String = ""
    @State private var showConfirmClear = false
    @State private var copiedNotice: Bool = false
    
    private var filteredLogs: [SmartDeviceLog] {
        store.db.smartDeviceLogs.filter { item in
            switch filterIndex {
            case 1:
                if item.isSuccess && (item.errorMessage?.isEmpty ?? true) {
                    return false
                }
            case 2:
                if !item.isOn { return false }
            case 3:
                if item.isOn { return false }
            default:
                break
            }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let nameMatch = item.deviceName.lowercased().contains(q)
                let triggerMatch = item.trigger.lowercased().contains(q)
                let errMatch = item.errorMessage?.lowercased().contains(q) ?? false
                let typeMatch = item.deviceType.lowercased().contains(q)
                return nameMatch || triggerMatch || errMatch || typeMatch
            }
            return true
        }
    }
    
    private var errCount: Int {
        store.db.smartDeviceLogs.filter { !$0.isSuccess || ($0.errorMessage?.isEmpty == false) }.count
    }
    private var onCount: Int {
        store.db.smartDeviceLogs.filter { $0.isOn }.count
    }
    private var offCount: Int {
        store.db.smartDeviceLogs.filter { !$0.isOn }.count
    }
    
    private var hasObsoleteTuyaLogs: Bool {
        store.db.smartDeviceLogs.contains(where: {
            ($0.errorMessage?.contains("28841004") == true) ||
            ($0.errorMessage?.lowercased().contains("tuya cloud proefperiode") == true)
        })
    }
    
    @ViewBuilder
    private var obsoleteTuyaLogsBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(MycoTheme.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.t(nl: "Verouderde Tuya Cloud Meldingen", en: "Obsolete Tuya Cloud Logs"))
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text(store.t(nl: "Je gebruikt nu de lokale Pi Hub. Oude Tuya Cloud fouten zijn niet meer van toepassing.", en: "You are now using the local Pi Hub. Old Tuya Cloud errors no longer apply."))
                    .font(.caption2)
                    .foregroundColor(MycoTheme.textSecondary)
            }
            Spacer()
            Button {
                withAnimation {
                    store.cleanExpiredTuyaCloudLogs()
                }
            } label: {
                Text(store.t(nl: "Opschonen", en: "Clean Up"))
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MycoTheme.blue.opacity(0.2))
                    .foregroundColor(MycoTheme.blue)
                    .cornerRadius(8)
            }
        }
        .padding(10)
        .background(MycoTheme.card)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
    
    private var exportedLogString: String {
        var lines: [String] = []
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        for log in store.db.smartDeviceLogs {
            let status = log.isOn ? "AAN" : "UIT"
            let errStr = (log.errorMessage?.isEmpty == false) ? " [FOUT: \(log.errorMessage ?? "")]" : ""
            lines.append("[\(df.string(from: log.timestamp))] \(log.deviceName) (\(log.deviceType)) -> \(status) | Bron: \(log.trigger)\(errStr)")
        }
        return lines.joined(separator: "\n")
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented filter picker
                Picker("", selection: $filterIndex) {
                    Text(store.t(nl: "Alle (\(store.db.smartDeviceLogs.count))", en: "All (\(store.db.smartDeviceLogs.count))")).tag(0)
                    Text(store.t(nl: "⚠️ Fouten (\(errCount))", en: "⚠️ Errors (\(errCount))")).tag(1)
                    Text(store.t(nl: "🟢 AAN (\(onCount))", en: "🟢 ON (\(onCount))")).tag(2)
                    Text(store.t(nl: "⚪️ UIT (\(offCount))", en: "⚪️ OFF (\(offCount))")).tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                if copiedNotice {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(MycoTheme.green)
                        Text(store.t(nl: "Logboek gekopieerd naar klembord!", en: "Log copied to clipboard!"))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(MycoTheme.green.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if hasObsoleteTuyaLogs {
                    obsoleteTuyaLogsBanner
                }
                
                if filteredLogs.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 40))
                            .foregroundColor(MycoTheme.textSecondary.opacity(0.6))
                        Text(store.t(nl: "Geen logregels gevonden voor dit filter", en: "No log entries found for this filter"))
                            .font(.subheadline)
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredLogs) { log in
                            SmartDeviceLogDetailRow(log: log)
                                .listRowBackground(Color.white.opacity(0.04))
                                .listRowSeparatorTint(Color.white.opacity(0.1))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            store.db.smartDeviceLogs.removeAll(where: { $0.id == log.id })
                                            store.save()
                                        }
                                    } label: {
                                        Label(store.t(nl: "Verwijder Logregel", en: "Delete Log Entry"), systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { offsets in
                            let idsToDelete = offsets.map { filteredLogs[$0].id }
                            withAnimation {
                                store.db.smartDeviceLogs.removeAll(where: { idsToDelete.contains($0.id) })
                                store.save()
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .searchable(text: $searchText, prompt: store.t(nl: "Zoek apparaat, bron of fout...", en: "Search device, source or error..."))
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Apparaat Logboek", en: "Device Activity Log"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            UIPasteboard.general.string = exportedLogString
                            withAnimation {
                                copiedNotice = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation {
                                    copiedNotice = false
                                }
                            }
                        } label: {
                            Label(store.t(nl: "Kopieer Logtekst", en: "Copy Log Text"), systemImage: "doc.on.doc")
                        }
                        
                        Button(role: .destructive) {
                            showConfirmClear = true
                        } label: {
                            Label(store.t(nl: "Wis Gehele Log", en: "Clear Full Log"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(MycoTheme.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Klaar", en: "Done")) {
                        dismiss()
                    }
                    .foregroundColor(MycoTheme.blue)
                }
            }
            .alert(store.t(nl: "Logboek wissen?", en: "Clear activity log?"), isPresented: $showConfirmClear) {
                Button(store.t(nl: "Wis Log", en: "Clear Log"), role: .destructive) {
                    store.clearSmartDeviceLogs()
                }
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
            } message: {
                Text(store.t(nl: "Weet je zeker dat je alle opgeslagen schakel- en foutactiviteiten wilt wissen?", en: "Are you sure you want to clear all stored switch and error events?"))
            }
        }
    }
}

// MARK: - SMART DEVICE LOG DETAIL ROW (Voor Sheet)
struct SmartDeviceLogDetailRow: View {
    @EnvironmentObject var store: MycoStore
    let log: SmartDeviceLog
    
    private var fullTimestampString: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium
        return df.string(from: log.timestamp)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(log.isOn ? MycoTheme.green.opacity(0.2) : Color.white.opacity(0.08))
                        .frame(width: 34, height: 34)
                    Image(systemName: SmartDeviceItem.icon(for: log.deviceType))
                        .font(.footnote)
                        .foregroundColor(log.isOn ? MycoTheme.green : MycoTheme.textSecondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(log.deviceName)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        
                        Text(log.isOn ? store.t(nl: "AAN", en: "ON") : store.t(nl: "UIT", en: "OFF"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(log.isOn ? .black : .white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(log.isOn ? MycoTheme.green : Color.white.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text(fullTimestampString)
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                }
                
                Spacer()
                
                if log.isSuccess && (log.errorMessage?.isEmpty ?? true) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MycoTheme.green)
                        .font(.caption)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.red)
                        .font(.caption)
                }
            }
            
            HStack(spacing: 6) {
                Text(store.t(nl: "Bron:", en: "Source:"))
                    .font(.caption2)
                    .foregroundColor(MycoTheme.textSecondary)
                Text(log.trigger)
                    .font(.caption2.bold())
                    .foregroundColor(MycoTheme.blue)
                
                Spacer()
                
                Text(SmartDeviceItem.label(for: log.deviceType))
                    .font(.system(size: 9))
                    .foregroundColor(MycoTheme.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(4)
            }
            
            if let err = log.errorMessage, !err.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text(store.t(nl: "Foutmelding:", en: "Error details:"))
                            .font(.caption2.bold())
                            .foregroundColor(.red)
                    }
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(Color.white.opacity(0.9))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.15))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - DEVICE COUNTDOWN TIMER VIEW (Aftellende timer voor handmatig interval)
struct DeviceCountdownTimerView: View {
    @EnvironmentObject var store: MycoStore
    let device: SmartDeviceItem
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let now = timeline.date
            timerBadge(now: now)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    private func computeCycleStatus(last: Date, now: Date) -> (remaining: Double, isPulse: Bool) {
        let periodSecs = Double(max(1, device.totalIntervalMinutes) * 60)
        let durationSecs = Double(max(1, device.customDurationMinutes) * 60)
        let elapsed = now.timeIntervalSince(last)
        if elapsed < 0 {
            return (periodSecs, false)
        }
        let cycleOffset = elapsed.truncatingRemainder(dividingBy: periodSecs)
        if cycleOffset < durationSecs {
            return (0, true)
        } else {
            return (periodSecs - cycleOffset, false)
        }
    }

    private func computeOnRemaining(last: Date, now: Date) -> Double {
        let periodSecs = Double(max(1, device.totalIntervalMinutes) * 60)
        let durationSecs = Double(max(1, device.customDurationMinutes) * 60)
        let elapsed = max(0, now.timeIntervalSince(last))
        let cycleOffset = elapsed.truncatingRemainder(dividingBy: periodSecs)
        return max(0, durationSecs - cycleOffset)
    }

    @ViewBuilder
    private func timerBadge(now: Date) -> some View {
        if let effectiveFrom = device.scheduleEffectiveFrom, now < effectiveFrom {
            let diff = Int(effectiveFrom.timeIntervalSince(now))
            HStack(spacing: 3) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 8))
                Text(store.t(
                    nl: "Actief vanaf \(effectiveFrom.formatted(date: .omitted, time: .shortened)) (over \(formatTimer(diff)))",
                    en: "Active from \(effectiveFrom.formatted(date: .omitted, time: .shortened)) (in \(formatTimer(diff)))"
                ))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.2))
            .foregroundColor(Color.cyan)
            .cornerRadius(4)
        } else if device.isOn {
            // Apparaat staat momenteel AAN (cyclus draait)
            if let last = device.lastCustomExecutionTime {
                let remaining = computeOnRemaining(last: last, now: now)
                
                if remaining > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                        Text(store.t(nl: "AAN (nog \(formatTimer(Int(remaining))))", en: "ON (\(formatTimer(Int(remaining))) left)"))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(MycoTheme.green.opacity(0.2))
                    .foregroundColor(MycoTheme.green)
                    .cornerRadius(4)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text(store.t(nl: "Afronden...", en: "Finishing..."))
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(MycoTheme.textSecondary)
                    .cornerRadius(4)
                }
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                    Text(store.t(nl: "Nu Actief", en: "Active"))
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(MycoTheme.green.opacity(0.2))
                .foregroundColor(MycoTheme.green)
                .cornerRadius(4)
            }
        } else {
            // Apparaat staat UIT (aftellen tot volgende start)
            if let last = device.lastCustomExecutionTime {
                let status = computeCycleStatus(last: last, now: now)
                
                if status.isPulse {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.badge.clock.fill")
                            .font(.system(size: 8))
                        Text(store.t(nl: "Start zo...", en: "Starting..."))
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(Color.green)
                    .cornerRadius(4)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 8))
                        Text(store.t(
                            nl: "Aan over: \(formatTimer(Int(status.remaining)))",
                            en: "On in: \(formatTimer(Int(status.remaining)))"
                        ))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(MycoTheme.amber.opacity(0.2))
                    .foregroundColor(MycoTheme.amber)
                    .cornerRadius(4)
                }
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 8))
                    Text(store.t(nl: "Volgende cyclus", en: "Next cycle"))
                        .font(.system(size: 9, weight: .medium))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .foregroundColor(MycoTheme.textSecondary)
                .cornerRadius(4)
            }
        }
    }
    
    private func formatTimer(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

// MARK: - SMART DEVICE ROW VIEW
struct SmartDeviceRowView: View {
    @EnvironmentObject var store: MycoStore
    let device: SmartDeviceItem
    let onEdit: () -> Void
    
    var body: some View {
        MycoCard {
            VStack(alignment: .leading, spacing: 12) {
                // TOP ROW: Device Icon, Name, Category Pill, Settings & Delete
                HStack(alignment: .center, spacing: 12) {
                    // Tap on icon/name opens edit sheet
                    Button {
                        onEdit()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(device.deviceType == "Sensor" ? MycoTheme.blue.opacity(0.2) : (device.isOn ? MycoTheme.green.opacity(0.2) : Color.white.opacity(0.08)))
                                    .frame(width: 42, height: 42)
                                Image(systemName: SmartDeviceItem.icon(for: device.deviceType))
                                    .font(.title3)
                                    .foregroundColor(device.deviceType == "Sensor" ? MycoTheme.blue : (device.isOn ? MycoTheme.green : MycoTheme.textSecondary))
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(device.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                HStack(spacing: 6) {
                                    Text(SmartDeviceItem.label(for: device.deviceType, isDutch: !store.isEnglish))
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(MycoTheme.blue.opacity(0.2))
                                        .cornerRadius(4)
                                        .foregroundColor(MycoTheme.blue)
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                    Text(device.brand)
                                        .font(.caption)
                                        .foregroundColor(MycoTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer(minLength: 8)
                    
                    // Edit / Settings button
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption)
                            .foregroundColor(MycoTheme.blue)
                            .padding(8)
                            .background(MycoTheme.blue.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    
                    // Delete button
                    Button {
                        withAnimation {
                            store.deleteSmartDevice(id: device.id)
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(Color.red.opacity(0.85))
                            .padding(8)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.borderless)
                }
                
                Divider().background(Color.white.opacity(0.08))
                
                // BOTTOM ROW: Telemetry / Status / Countdown on Left, Controls on Right
                HStack(alignment: .center, spacing: 8) {
                    // Left side: Status / Timers / Sensor readings
                    VStack(alignment: .leading, spacing: 4) {
                        if device.deviceType == "Sensor" {
                            if let t = device.currentTempC ?? store.latestSensorTempC,
                               let h = device.currentHumidityPct ?? store.latestSensorHumidityPct {
                                HStack(spacing: 5) {
                                    Circle().fill(Color.green).frame(width: 6, height: 6)
                                    Text(String(format: "%.1f°C • %.0f%% RV", t, h))
                                        .font(.system(.subheadline, design: .monospaced).bold())
                                        .foregroundColor(Color.green)
                                }
                            } else {
                                Text(store.t(nl: "Klimaatsensor • Wacht op data", en: "Sensor • Waiting for data"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        } else {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(device.isOn ? Color.green : Color.gray)
                                    .frame(width: 6, height: 6)
                                Text(device.isOn ? store.t(nl: "Nu AAN", en: "Currently ON") : store.t(nl: "Nu UIT", en: "Currently OFF"))
                                    .font(.caption.bold())
                                    .foregroundColor(device.isOn ? MycoTheme.green : MycoTheme.textSecondary)
                            }
                            
                            if !device.autoControlEnabled {
                                Text(store.t(nl: "⏸️ Autopilot Uit", en: "⏸️ Autopilot Off"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(MycoTheme.textSecondary)
                                    .cornerRadius(4)
                            } else if device.deviceType == "Light" {
                                Text("☀️ " + String(format: "%02d:00", device.lightOnHour) + " - " + String(format: "%02d:00", device.lightOffHour))
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(Color.yellow)
                                    .cornerRadius(4)
                            } else if device.autopilotMode == "customInterval" {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("🕒 " + store.t(
                                        nl: "Tijdgestuurd • Elke \(device.intervalFormatted) (\(device.customDurationMinutes)m aan)",
                                        en: "Timed • Every \(device.intervalFormatted) (\(device.customDurationMinutes)m on)"
                                    ))
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(MycoTheme.blue.opacity(0.2))
                                    .foregroundColor(MycoTheme.blue)
                                    .cornerRadius(4)
                                    .fixedSize(horizontal: true, vertical: false)
                                    
                                    DeviceCountdownTimerView(device: device)
                                }
                            } else {
                                if store.hasPhysicalSensorAvailable {
                                    Text("🌡️ " + store.t(nl: "Sensorgestuurd (Live RV%)", en: "Sensor-driven (Live RH%)"))
                                        .font(.system(size: 9, weight: .semibold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.green.opacity(0.18))
                                        .foregroundColor(Color.green)
                                        .cornerRadius(4)
                                } else {
                                    Text("🕒 " + store.t(nl: "Tijdcyclus (Wacht op sensor)", en: "Timed Cycle (Waiting for sensor)"))
                                        .font(.system(size: 9, weight: .semibold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(MycoTheme.amber.opacity(0.2))
                                        .foregroundColor(MycoTheme.amber)
                                        .cornerRadius(4)
                                }
                            }
                            
                            if device.deviceType == "Humidifier" && store.db.smartDevices.contains(where: { $0.deviceType == "ExhaustFan" && $0.isOn }) {
                                Text(store.t(nl: "⏸️ Wacht op FAE ventilatie", en: "⏸️ Waiting for FAE"))
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(Color.orange)
                                    .cornerRadius(4)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    // Right side: Quick Test & Primary Power Button
                    if device.deviceType != "Sensor" {
                        HStack(spacing: 8) {
                            Button {
                                store.testSmartDevice(id: device.id)
                            } label: {
                                Text(store.t(nl: "⚡️ 10s Test", en: "⚡️ 10s Test"))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(MycoTheme.amber)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .background(MycoTheme.amber.opacity(0.15))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.borderless)
                            
                            Button {
                                store.toggleSmartDevice(id: device.id)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "power")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(device.isOn ? store.t(nl: "AAN", en: "ON") : store.t(nl: "UIT", en: "OFF"))
                                        .font(.caption.bold())
                                }
                                .foregroundColor(device.isOn ? .black : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(device.isOn ? MycoTheme.green : Color.white.opacity(0.15))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        Button {
                            store.pollAllConnectedSensors()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption.bold())
                                Text(store.t(nl: "Uitlezen", en: "Refresh"))
                                    .font(.caption.bold())
                            }
                            .foregroundColor(MycoTheme.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(MycoTheme.blue.opacity(0.15))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}

// MARK: - AUTOPILOT QUICK TEST SHEET
struct AutopilotQuickTestSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var testRunning: String? = nil
    @State private var testLogs: [String] = []
    @State private var showMatrixSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Status Overview Card
                    MycoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(store.db.environmentConfig.isAutopilotEnabled ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "cpu.fill")
                                        .foregroundColor(store.db.environmentConfig.isAutopilotEnabled ? Color.green : Color.orange)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "24/7 Autopilot Status", en: "24/7 Autopilot Status"))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Text(store.db.environmentConfig.isAutopilotEnabled ? store.t(nl: "Actief & Draaiend", en: "Active & Running") : store.t(nl: "Gepauzeerd", en: "Paused"))
                                        .font(.caption)
                                        .foregroundColor(store.db.environmentConfig.isAutopilotEnabled ? Color.green : Color.orange)
                                }
                                Spacer()
                                
                                Button {
                                    store.db.environmentConfig.isAutopilotEnabled.toggle()
                                    store.save()
                                    if store.db.environmentConfig.isAutopilotEnabled {
                                        store.startAutopilotEngine()
                                    }
                                } label: {
                                    Text(store.db.environmentConfig.isAutopilotEnabled ? store.t(nl: "Pauzeer", en: "Pause") : store.t(nl: "Activeer", en: "Activate"))
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(store.db.environmentConfig.isAutopilotEnabled ? Color.orange : Color.green)
                                        .cornerRadius(6)
                                }
                            }
                            
                            Divider().background(MycoTheme.border)
                            
                            // Connected hardware summary
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.t(nl: "Gekoppelde Hardware:", en: "Connected Hardware:"))
                                    .font(.caption.bold())
                                    .foregroundColor(MycoTheme.textSecondary)
                                
                                HStack(spacing: 8) {
                                    let hasFan = store.db.smartDevices.contains { $0.deviceType == "ExhaustFan" }
                                    let hasHum = store.db.smartDevices.contains { $0.deviceType == "Humidifier" }
                                    let hasSensor = store.hasConnectedSensor
                                    
                                    hwBadge(name: "Ventilator", active: hasFan, icon: "wind")
                                    hwBadge(name: "Bevochtiger", active: hasHum, icon: "drop.fill")
                                    hwBadge(name: "Sensor", active: hasSensor, icon: "thermometer.medium")
                                }
                                
                                Button {
                                    showMatrixSheet = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "tablecells.fill")
                                        Text(store.t(nl: "Bekijk 24/7 Tuya Kloktijden Matrix", en: "View 24/7 Tuya Timers Matrix"))
                                            .font(.caption.bold())
                                    }
                                    .foregroundColor(MycoTheme.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(MycoTheme.blue.opacity(0.12))
                                    .cornerRadius(6)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    
                    // Interactive Test Actions Card
                    MycoCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(store.t(nl: "⚡️ Snelle Functietests", en: "⚡️ Quick Function Tests"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            
                            // Test 1: Full Autopilot Cycle Diagnostic
                            testRow(
                                title: store.t(nl: "1. Autopilot Diagnose Cyclus", en: "1. Autopilot Diagnostic Cycle"),
                                description: store.t(nl: "Voert direct een evaluatieronde uit op basis van actuele tijden en sensoren.", en: "Runs an instant evaluation round based on current timers and sensors."),
                                icon: "arrow.triangle.2.circlepath",
                                color: MycoTheme.blue,
                                isRunning: testRunning == "diag"
                            ) {
                                runDiagnosticTest()
                            }
                            
                            Divider().background(MycoTheme.border)
                            
                            // Test 2: Fan 10s Pulse Test
                            testRow(
                                title: store.t(nl: "2. FAE Ventilator 10s Pulstest", en: "2. FAE Fan 10s Pulse Test"),
                                description: store.t(nl: "Schakelt de afzuiging 10 seconden in en controleert automatische uitschakeling.", en: "Turns on exhaust for 10 seconds and verifies auto turn-off."),
                                icon: "wind",
                                color: MycoTheme.amber,
                                isRunning: testRunning == "fan"
                            ) {
                                runFanPulseTest()
                            }
                            
                            Divider().background(MycoTheme.border)
                            
                            // Test 3: Humidifier 10s Pulse Test
                            testRow(
                                title: store.t(nl: "3. Luchtbevochtiger 10s Pulstest", en: "3. Humidifier 10s Pulse Test"),
                                description: store.t(nl: "Schakelt de bevochtiger 10 seconden in om Tuya relais en nevel te testen.", en: "Turns on humidifier for 10 seconds to verify relay and mist."),
                                icon: "drop.fill",
                                color: MycoTheme.blue,
                                isRunning: testRunning == "hum"
                            ) {
                                runHumidifierPulseTest()
                            }
                            
                            Divider().background(MycoTheme.border)
                            
                            // Test 4: Sequential FAE -> Humidifier Test
                            testRow(
                                title: store.t(nl: "4. Volgordetest: Ventilator ➔ Daarna Bevochtiger", en: "4. Sequence Test: Fan ➔ Then Humidifier"),
                                description: store.t(nl: "Test de mycologische volgorde: eerst draait de ventilator 6s, daarna start direct de luchtbevochtiger voor 6s.", en: "Tests sequential mycological logic: fan runs for 6s, then humidifier starts for 6s."),
                                icon: "arrow.triangle.swap",
                                color: Color.purple,
                                isRunning: testRunning == "sequence"
                            ) {
                                runSequenceOrderTest()
                            }
                            
                            Divider().background(MycoTheme.border)
                            
                            // Test 4: Simulation Drought Trigger
                            testRow(
                                title: store.t(nl: "4. Droogte Simulatie (78% RV Trigger)", en: "4. Drought Simulation (78% RH Trigger)"),
                                description: store.t(nl: "Simuleert een lage RV van 78% om te testen of de Autopilot automatisch ingrijpt.", en: "Simulates low 78% RH to test if Autopilot automatically intervenes."),
                                icon: "sparkles",
                                color: Color.green,
                                isRunning: testRunning == "drought"
                            ) {
                                runDroughtSimulationTest()
                            }
                            
                            // Test 5+: Handmatige Interval Apparaten
                            let customDevs = store.db.smartDevices.filter { $0.deviceType != "Sensor" && $0.autoControlEnabled && $0.autopilotMode == "customInterval" }
                            if !customDevs.isEmpty {
                                Divider().background(MycoTheme.border)
                                ForEach(customDevs) { dev in
                                    testRow(
                                        title: "⏱️ \(dev.name) (" + store.t(nl: "Elke \(dev.intervalFormatted) • \(dev.customDurationMinutes)m aan", en: "Every \(dev.intervalFormatted) • \(dev.customDurationMinutes)m on") + ")",
                                        description: store.t(nl: "10s pulstest om dit handmatige interval-apparaat te testen.", en: "10s pulse test to verify this manual interval device."),
                                        icon: SmartDeviceItem.icon(for: dev.deviceType),
                                        color: MycoTheme.amber,
                                        isRunning: testRunning == dev.id.uuidString
                                    ) {
                                        runCustomDevicePulseTest(dev)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Live Test Console / Log Card
                    MycoCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "terminal.fill")
                                    .foregroundColor(Color.green)
                                Text(store.t(nl: "Live Testlogboek", en: "Live Test Console"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                if !testLogs.isEmpty {
                                    Button(store.t(nl: "Wissen", en: "Clear")) {
                                        testLogs.removeAll()
                                    }
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                            
                            if testLogs.isEmpty {
                                Text(store.t(nl: "Druk op een van de bovenstaande tests om live communicatie met je apparaten te bekijken.", en: "Tap any test above to view live communication with your devices."))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(testLogs.suffix(8), id: \.self) { log in
                                        Text(log)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "⚡️ 24/7 Autopilot Test", en: "⚡️ 24/7 Autopilot Test"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showMatrixSheet) {
                TuyaCloudScheduleMatrixSheet()
                    .environmentObject(store)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
            }
        }
    }
    
    private func hwBadge(name: String, active: Bool, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(name)
                .font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(active ? Color.green.opacity(0.15) : Color.white.opacity(0.06))
        .foregroundColor(active ? Color.green : Color.gray)
        .cornerRadius(6)
    }
    
    private func testRow(title: String, description: String, icon: String, color: Color, isRunning: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Spacer()
                
                Button(action: action) {
                    if isRunning {
                        ProgressView().tint(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(color)
                            .cornerRadius(6)
                    } else {
                        Text(store.t(nl: "Start Test", en: "Start Test"))
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(color)
                            .cornerRadius(6)
                    }
                }
                .disabled(isRunning)
            }
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(MycoTheme.textSecondary)
        }
    }
    
    private func addLog(_ msg: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        testLogs.append("[\(timestamp)] \(msg)")
    }
    
    private func runDiagnosticTest() {
        testRunning = "diag"
        addLog("Diagnostische Autopilot ronde gestart...")
        store.runAutopilotCycle(isTest: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            addLog("Resultaat: \(store.db.environmentConfig.lastAutopilotLogMessage)")
            testRunning = nil
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        }
    }
    
    private func runFanPulseTest() {
        guard let fan = store.db.smartDevices.first(where: { $0.deviceType == "ExhaustFan" }) else {
            addLog("⚠️ Geen ventilator gevonden in apparatenlijst!")
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.error)
            return
        }
        
        testRunning = "fan"
        addLog("▶️ FAE Ventilator '\(fan.name)' handmatig gestart voor 10s test...")
        if !fan.isOn {
            store.toggleSmartDevice(id: fan.id, trigger: store.t(nl: "Sneltest • FAE Ventilator (10s)", en: "Quick Test • FAE Exhaust (10s)"))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if let currentFan = store.db.smartDevices.first(where: { $0.id == fan.id }), currentFan.isOn {
                store.toggleSmartDevice(id: currentFan.id, trigger: store.t(nl: "Sneltest • FAE Voltooid", en: "Quick Test • FAE Completed"))
                addLog("⏹ FAE Ventilator automatisch gestopt na 10s pulstest. Test GESLAAGD! ✅")
            } else {
                addLog("⏹ Pulstest voltooid. ✅")
            }
            testRunning = nil
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        }
    }
    
    private func runHumidifierPulseTest() {
        guard let hum = store.db.smartDevices.first(where: { $0.deviceType == "Humidifier" }) else {
            addLog("⚠️ Geen luchtbevochtiger gevonden in apparatenlijst!")
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.error)
            return
        }
        
        testRunning = "hum"
        addLog("▶️ Luchtbevochtiger '\(hum.name)' gestart voor 10s test...")
        if !hum.isOn {
            store.toggleSmartDevice(id: hum.id, trigger: store.t(nl: "Sneltest • Bevochtiger (10s)", en: "Quick Test • Humidifier (10s)"))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if let currentHum = store.db.smartDevices.first(where: { $0.id == hum.id }), currentHum.isOn {
                store.toggleSmartDevice(id: currentHum.id, trigger: store.t(nl: "Sneltest • Bevochtiging Voltooid", en: "Quick Test • Humidification Completed"))
                addLog("⏹ Luchtbevochtiger automatisch gestopt na 10s pulstest. Test GESLAAGD! ✅")
            } else {
                addLog("⏹ Pulstest voltooid. ✅")
            }
            testRunning = nil
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        }
    }
    
    private func runSequenceOrderTest() {
        guard let fan = store.db.smartDevices.first(where: { $0.deviceType == "ExhaustFan" }) else {
            addLog("⚠️ Geen FAE ventilator gekoppeld in de lijst!")
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.error)
            return
        }
        guard let hum = store.db.smartDevices.first(where: { $0.deviceType == "Humidifier" }) else {
            addLog("⚠️ Geen luchtbevochtiger gekoppeld in de lijst!")
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.error)
            return
        }
        
        testRunning = "sequence"
        addLog("▶️ Stap 1/2: Ventilator '\(fan.name)' ingeschakeld (6s FAE ventilatie)...")
        addLog("🔒 Beveiliging: Luchtbevochtiger is nu geblokkeerd tegen nevelverlies.")
        if !fan.isOn {
            store.toggleSmartDevice(id: fan.id, trigger: store.t(nl: "Volgordetest • FAE Afzuiging", en: "Sequence Test • FAE Exhaust"))
        }
        if hum.isOn {
            store.toggleSmartDevice(id: hum.id, trigger: store.t(nl: "Volgordetest • Bevochtiger UIT (FAE voorrang)", en: "Sequence Test • Humidifier OFF"))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            if let currentFan = store.db.smartDevices.first(where: { $0.id == fan.id }), currentFan.isOn {
                store.toggleSmartDevice(id: currentFan.id, trigger: store.t(nl: "Volgordetest • Ventilator UIT", en: "Sequence Test • Fan OFF"))
            }
            addLog("⏹️ Stap 1 voltooid: Ventilator uitgeschakeld. 2 sec wachttijd voor luchtstabilisatie...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                addLog("▶️ Stap 2/2: Luchtbevochtiger '\(hum.name)' ingeschakeld voor 6s vochtherstel...")
                if let currentHum = store.db.smartDevices.first(where: { $0.id == hum.id }), !currentHum.isOn {
                    store.toggleSmartDevice(id: currentHum.id, trigger: store.t(nl: "Volgordetest • Vochtherstel na FAE", en: "Sequence Test • Humidity restore"))
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    if let currentHum = store.db.smartDevices.first(where: { $0.id == hum.id }), currentHum.isOn {
                        store.toggleSmartDevice(id: currentHum.id, trigger: store.t(nl: "Volgordetest • Voltooid", en: "Sequence Test • Completed"))
                    }
                    addLog("✅ Volgordetest 100% GESLAAGD! Eerst ventilator gedraaid, daarna direct vochtherstel.")
                    testRunning = nil
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                }
            }
        }
    }
    
    private func runDroughtSimulationTest() {
        testRunning = "drought"
        addLog("🧪 Droogte simulatie: Sensormeting verzonden (22.5°C, 78% RV, doel is \(Int(store.db.environmentConfig.targetHumidityPct))% RV)...")
        store.recordSensorReading(tempC: 22.5, humidityPct: 78.0, co2Ppm: 650, source: "Droogte Test")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            addLog("🤖 Autopilot reactie: \(store.db.environmentConfig.lastAutopilotLogMessage)")
            let hasHum = store.db.smartDevices.first(where: { $0.deviceType == "Humidifier" })?.isOn ?? false
            if hasHum {
                addLog("✅ BEVESTIGD: Luchtbevochtiger is automatisch aangesprongen ter bescherming!")
            } else {
                addLog("ℹ️ Melding geregistreerd. Controleer of automatische sturing actief is.")
            }
            testRunning = nil
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        }
    }
    
    private func runCustomDevicePulseTest(_ dev: SmartDeviceItem) {
        testRunning = dev.id.uuidString
        addLog("▶️ Handmatig interval-apparaat '\(dev.name)' gestart voor 10s test...")
        if !dev.isOn {
            store.toggleSmartDevice(id: dev.id, trigger: store.t(nl: "Sneltest • '\(dev.name)' (10s)", en: "Quick Test • '\(dev.name)' (10s)"))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if let current = store.db.smartDevices.first(where: { $0.id == dev.id }), current.isOn {
                store.toggleSmartDevice(id: current.id, trigger: store.t(nl: "Sneltest • '\(dev.name)' Voltooid", en: "Quick Test • '\(dev.name)' Completed"))
                addLog("⏹ '\(dev.name)' automatisch gestopt na 10s pulstest. Test GESLAAGD! ✅")
            } else {
                addLog("⏹ Pulstest voltooid voor '\(dev.name)'. ✅")
            }
            testRunning = nil
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        }
    }
}

// MARK: - AUTOPILOT DEVICE SCHEDULES SHEET (Handmatige Apparaat Intervallen)
struct AutopilotDeviceSchedulesSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @State private var testingDeviceId: UUID? = nil
    @State private var statusToast: String? = nil
    
    var nonSensorDevices: [SmartDeviceItem] {
        store.db.smartDevices.filter { $0.deviceType != "Sensor" }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header card
                    MycoCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(MycoTheme.amber.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "timer")
                                        .font(.title3)
                                        .foregroundColor(MycoTheme.amber)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "Handmatige Autopilot Intervallen", en: "Manual Autopilot Intervals"))
                                        .font(.headline.bold())
                                        .foregroundColor(.white)
                                    Text(store.t(
                                        nl: "Kies per apparaat: Slimme sensorsturing óf een vast tijdschema (\"elke X uur, Y minuten aan\").",
                                        en: "Choose per device: Smart automation or fixed timer schedule (\"every X hrs, Y mins on\")."
                                    ))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                            
                            if let toast = statusToast {
                                Text(toast)
                                    .font(.caption.bold())
                                    .foregroundColor(MycoTheme.amber)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(MycoTheme.amber.opacity(0.12))
                                    .cornerRadius(6)
                                    .transition(.opacity)
                            }
                        }
                    }
                    
                    // FAE & Luchtbevochtiger Slimme Coördinatie & Veiligheden (Pre-FAE Lockout & Post-FAE Herstel)
                    MycoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "wind.snow")
                                        .font(.subheadline.bold())
                                        .foregroundColor(Color.cyan)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "Slimme FAE & Vocht Coördinatie", en: "Smart FAE & Moisture Coordination"))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Text(store.t(
                                        nl: "Voorkom nevelverspilling vóór afzuiging en herstel luchtvochtigheid direct erna.",
                                        en: "Prevent mist waste before exhaust and recover humidity immediately after."
                                    ))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // 1. Pre-FAE Lockout Slider/Stepper
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(store.t(nl: "Pre-FAE Bevochtiging-stop:", en: "Pre-FAE Humidifier Lockout:"))
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(store.db.environmentConfig.preFaeHumidifierLockoutMinutes) " + store.t(nl: "minuten vóór afzuiging", en: "minutes before exhaust"))
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundColor(Color.cyan)
                                }
                                
                                Stepper(value: Binding(
                                    get: { store.db.environmentConfig.preFaeHumidifierLockoutMinutes },
                                    set: { val in
                                        store.db.environmentConfig.preFaeHumidifierLockoutMinutes = val
                                        store.save()
                                    }
                                ), in: 0...30, step: 5) {
                                    Text(store.t(
                                        nl: "Schakelt de bevochtiger automatisch uit 10 of 15 min vóórdat de ventilator start om nevelverspilling te voorkomen.",
                                        en: "Stops humidifier 10-15 min before fan starts to avoid exhausting fresh humidity."
                                    ))
                                    .font(.system(size: 11))
                                    .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                            
                            // 2. Post-FAE Recovery Duration Stepper
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(store.t(nl: "Post-FAE Vochtherstel Duur:", en: "Post-FAE Recovery Run Time:"))
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                    Spacer()
                                    if store.db.environmentConfig.postFaeRecoveryDurationSeconds == 0 {
                                        Text(store.t(nl: "⚡ Smart AI Dynamisch", en: "⚡ Smart AI Dynamic"))
                                            .font(.system(.caption, design: .monospaced).bold())
                                            .foregroundColor(Color.green)
                                    } else {
                                        Text("\(store.db.environmentConfig.postFaeRecoveryDurationSeconds) " + store.t(nl: "seconden AAN", en: "seconds ON"))
                                            .font(.system(.caption, design: .monospaced).bold())
                                            .foregroundColor(MycoTheme.amber)
                                    }
                                }
                                
                                Stepper(value: Binding(
                                    get: { store.db.environmentConfig.postFaeRecoveryDurationSeconds },
                                    set: { val in
                                        store.db.environmentConfig.postFaeRecoveryDurationSeconds = val
                                        store.save()
                                    }
                                ), in: 0...600, step: 30) {
                                    Text(store.t(
                                        nl: "Hoelang de bevochtiger na FAE aanstaat om RV direct te herstellen (0 = Dynamische AI berekening).",
                                        en: "How long humidifier runs after FAE to restore RH (0 = Dynamic AI calculation)."
                                    ))
                                    .font(.system(size: 11))
                                    .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }

                    if nonSensorDevices.isEmpty {
                        EmptyStateCard(
                            icon: "powerplug.fill",
                            title: store.t(nl: "Geen apparaten gevonden", en: "No devices found"),
                            message: store.t(nl: "Voeg eerst een bevochtiger, ventilator, lamp of stekker toe via het dashboard.", en: "Add a humidifier, fan, light or plug first via the dashboard."),
                            buttonTitle: store.t(nl: "Sluiten", en: "Close")
                        ) {
                            dismiss()
                        }
                    } else {
                        ForEach(nonSensorDevices) { dev in
                            deviceScheduleCard(dev)
                        }
                    }
                }
                .padding(16)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Apparaat Intervallen", en: "Device Intervals"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Gereed", en: "Done")) {
                        dismiss()
                    }
                    .bold()
                    .foregroundColor(MycoTheme.blue)
                }
            }
        }
    }
    
    @ViewBuilder
    private func deviceScheduleCard(_ dev: SmartDeviceItem) -> some View {
        let isTesting = testingDeviceId == dev.id
        
        MycoCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header with device name, type and inclusion toggle
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(dev.isOn ? MycoTheme.green.opacity(0.2) : Color.white.opacity(0.08))
                            .frame(width: 38, height: 38)
                        Image(systemName: SmartDeviceItem.icon(for: dev.deviceType))
                            .foregroundColor(dev.isOn ? MycoTheme.green : MycoTheme.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dev.name)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(SmartDeviceItem.label(for: dev.deviceType) + " • " + (dev.isOn ? store.t(nl: "Nu AAN", en: "Currently ON") : store.t(nl: "Nu UIT", en: "Currently OFF")))
                            .font(.system(size: 10))
                            .foregroundColor(dev.isOn ? MycoTheme.green : MycoTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Quick toggle to participate in Autopilot
                    Toggle("", isOn: Binding(
                        get: { dev.autoControlEnabled },
                        set: { val in
                            if let idx = store.db.smartDevices.firstIndex(where: { $0.id == dev.id }) {
                                store.db.smartDevices[idx].autoControlEnabled = val
                                store.save()
                                Task { await store.syncSchedulesToPiHub() }
                                if (store.db.environmentConfig.tuyaOfflineAutonomousActive ?? false) {
                                    store.syncAllSchedulesToTuyaCloud()
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                    .tint(Color.green)
                }
                
                Divider().background(MycoTheme.border)
                
                if !dev.autoControlEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(MycoTheme.textSecondary)
                        Text(store.t(nl: "Uitgeschakeld voor Autopilot. Schakel de toggle in om dit apparaat automatisch te sturen.", en: "Excluded from Autopilot. Turn on toggle to automate this device."))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
                } else {
                    if dev.deviceType == "Light" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(store.t(nl: "Kloktijden Kweeklamp (Dagelijks AAN & UIT):", en: "Grow Light Schedule (Daily ON & OFF):"))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                Stepper(value: Binding(
                                    get: { dev.lightOnHour },
                                    set: { val in
                                        if let idx = store.db.smartDevices.firstIndex(where: { $0.id == dev.id }) {
                                            store.db.smartDevices[idx].lightOnHour = val
                                            store.save()
                                            Task { await store.syncSchedulesToPiHub() }
                                            if (store.db.environmentConfig.tuyaOfflineAutonomousActive ?? false) {
                                                store.syncAllSchedulesToTuyaCloud()
                                            }
                                        }
                                    }
                                ), in: 0...23) {
                                    Text(store.t(nl: "AAN: ", en: "ON: ") + String(format: "%02d:00", dev.lightOnHour))
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundColor(Color.green)
                                }
                                
                                Stepper(value: Binding(
                                    get: { dev.lightOffHour },
                                    set: { val in
                                        if let idx = store.db.smartDevices.firstIndex(where: { $0.id == dev.id }) {
                                            store.db.smartDevices[idx].lightOffHour = val
                                            store.save()
                                            Task { await store.syncSchedulesToPiHub() }
                                            if (store.db.environmentConfig.tuyaOfflineAutonomousActive ?? false) {
                                                store.syncAllSchedulesToTuyaCloud()
                                            }
                                        }
                                    }
                                ), in: 0...23) {
                                    Text(store.t(nl: "UIT: ", en: "OFF: ") + String(format: "%02d:00", dev.lightOffHour))
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundColor(Color.orange)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                    } else {
                        // Segmented Mode Picker
                        Picker("", selection: Binding(
                            get: { dev.autopilotMode },
                            set: { val in
                                if let idx = store.db.smartDevices.firstIndex(where: { $0.id == dev.id }) {
                                    store.db.smartDevices[idx].autopilotMode = val
                                    store.save()
                                }
                            }
                        )) {
                            Text(store.t(nl: "🕒 Tijdgestuurd (Geen sensor)", en: "🕒 Timed (No sensor)")).tag("customInterval")
                            Text(store.t(nl: "🌡️ Sensorgestuurd", en: "🌡️ Sensor-driven")).tag("auto")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    if dev.autopilotMode == "customInterval" {
                        VStack(alignment: .leading, spacing: 10) {
                            // Cycle Interval
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.t(nl: "Herhaalcyclus (Om de hoeveel tijd):", en: "Repeat cycle (How often):"))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 8) {
                                    Stepper(value: Binding(
                                        get: { dev.customIntervalHours },
                                        set: { val in
                                            if let idx = store.db.smartDevices.firstIndex(where: { $0.id == dev.id }) {
                                                store.db.smartDevices[idx].customIntervalHours = val
                                                store.save()
                                            }
                                        }
                                    ), in: 0...48) {
                                        Text("\(dev.customIntervalHours) " + store.t(nl: "uur", en: "hrs"))
                                            .font(.system(.caption, design: .monospaced).bold())
                                    }
                                    
                                    Stepper(value: Binding(
                                        get: { dev.customIntervalMinutes },
                                        set: { val in
                                            if let idx = store.db.smartDevices.firstIndex(where: { $0.id == dev.id }) {
                                                store.db.smartDevices[idx].customIntervalMinutes = val
                                                store.save()
                                            }
                                        }
                                    ), in: 0...55, step: 5) {
                                        Text("\(dev.customIntervalMinutes) min")
                                            .font(.system(.caption, design: .monospaced).bold())
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                            
                            // On-duration
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.t(nl: "Inschakelduur (Hoe lang AAN):", en: "Run duration (How long ON):"))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                
                                Stepper(value: Binding(
                                    get: { dev.customDurationMinutes },
                                    set: { val in
                                        if let idx = store.db.smartDevices.firstIndex(where: { $0.id == dev.id }) {
                                            store.db.smartDevices[idx].customDurationMinutes = val
                                            store.save()
                                        }
                                    }
                                ), in: 1...180) {
                                    Text("\(dev.customDurationMinutes) " + store.t(nl: dev.customDurationMinutes == 1 ? "minuut AAN" : "minuten AAN", en: dev.customDurationMinutes == 1 ? "minute ON" : "minutes ON"))
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundColor(MycoTheme.amber)
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                            
                            // Presets
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    presetButton(dev: dev, label: "1u • 2m", h: 1, m: 0, d: 2)
                                    presetButton(dev: dev, label: "2u • 5m", h: 2, m: 0, d: 5)
                                    presetButton(dev: dev, label: "3u • 5m", h: 3, m: 0, d: 5)
                                    presetButton(dev: dev, label: "4u • 10m", h: 4, m: 0, d: 10)
                                    presetButton(dev: dev, label: "6u • 15m", h: 6, m: 0, d: 15)
                                    presetButton(dev: dev, label: "12u • 30m", h: 12, m: 0, d: 30)
                                }
                            }
                            
                            // Ingangsdatum / Uur van Invoering
                            VStack(alignment: .leading, spacing: 6) {
                                let hasCustomStart = dev.scheduleEffectiveFrom != nil
                                Toggle(isOn: Binding(
                                    get: { hasCustomStart },
                                    set: { val in
                                        if let idx = store.db.smartDevices.firstIndex(where: { $0.id == dev.id }) {
                                            store.db.smartDevices[idx].scheduleEffectiveFrom = val ? Date() : nil
                                            store.save()
                                        }
                                    }
                                )) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar.badge.clock")
                                            .foregroundColor(Color.cyan)
                                        Text(store.t(nl: "Ingangsdatum & Uur van Invoering", en: "Effective Start Date & Hour"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                                .tint(Color.cyan)
                                
                                if hasCustomStart {
                                    DatePicker(
                                        store.t(nl: "Nieuw schema actief vanaf:", en: "New schedule active from:"),
                                        selection: Binding(
                                            get: { dev.scheduleEffectiveFrom ?? Date() },
                                            set: { val in
                                                if let idx = store.db.smartDevices.firstIndex(where: { $0.id == dev.id }) {
                                                    store.db.smartDevices[idx].scheduleEffectiveFrom = val
                                                    store.save()
                                                }
                                            }
                                        ),
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .font(.caption)
                                    .foregroundColor(.white)
                                }
                            }
                            .padding(8)
                            .background(Color.cyan.opacity(0.08))
                            .cornerRadius(8)
                            
                            // Summary & Actions
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(MycoTheme.amber)
                                        Text(store.t(
                                            nl: "Elke \(dev.intervalFormatted) • \(dev.customDurationMinutes)m AAN",
                                            en: "Every \(dev.intervalFormatted) • \(dev.customDurationMinutes)m ON"
                                        ))
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                    }
                                    
                                    DeviceCountdownTimerView(device: dev)
                                }
                                
                                Spacer()
                                
                                Button {
                                    run10sTest(dev)
                                } label: {
                                    if isTesting {
                                        ProgressView().tint(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(MycoTheme.amber)
                                            .cornerRadius(6)
                                    } else {
                                        Text(store.t(nl: "⚡️ 10s Test", en: "⚡️ 10s Test"))
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(MycoTheme.amber)
                                            .cornerRadius(6)
                                    }
                                }
                                .disabled(isTesting)
                            }
                            .padding(8)
                            .background(MycoTheme.amber.opacity(0.12))
                            .cornerRadius(8)
                        }
                    } else {
                        // Explanatory text for Auto mode
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(Color.green)
                            Text(store.t(
                                nl: "Gestuurd via intelligente sensor & kweekruimte regels van de 24/7 Autopilot.",
                                en: "Driven by 24/7 Autopilot intelligent sensor & room rules."
                            ))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private func presetButton(dev: SmartDeviceItem, label: String, h: Int, m: Int, d: Int) -> some View {
        Button {
            if let idx = store.db.smartDevices.firstIndex(where: { $0.id == dev.id }) {
                store.db.smartDevices[idx].customIntervalHours = h
                store.db.smartDevices[idx].customIntervalMinutes = m
                store.db.smartDevices[idx].customDurationMinutes = d
                store.save()
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
            }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func run10sTest(_ dev: SmartDeviceItem) {
        testingDeviceId = dev.id
        statusToast = store.t(nl: "⚡️ Pulstest gestart voor '\(dev.name)' (10s)", en: "⚡️ Pulse test started for '\(dev.name)' (10s)")
        if !dev.isOn {
            store.toggleSmartDevice(id: dev.id, trigger: store.t(nl: "Pulstest '\(dev.name)' (10s)", en: "Pulse test '\(dev.name)' (10s)"))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if let cur = store.db.smartDevices.first(where: { $0.id == dev.id }), cur.isOn {
                store.toggleSmartDevice(id: cur.id, trigger: store.t(nl: "Pulstest '\(dev.name)' Voltooid", en: "Pulse test '\(dev.name)' Completed"))
            }
            testingDeviceId = nil
            statusToast = store.t(nl: "✅ Pulstest voltooid voor '\(dev.name)'!", en: "✅ Pulse test completed for '\(dev.name)'!")
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        }
    }
}

// MARK: - EDIT SMART DEVICE SHEET (Configuring device without turning power on)
struct EditSmartDeviceSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    var device: SmartDeviceItem
    
    @State private var name: String
    @State private var deviceType: String
    @State private var brand: String
    @State private var webhookURL: String
    @State private var remoteCloudURL: String
    @State private var tuyaDeviceID: String
    @State private var autoControlEnabled: Bool
    @State private var autopilotMode: String
    @State private var customIntervalHours: Int
    @State private var customIntervalMinutes: Int
    @State private var customDurationMinutes: Int
    @State private var lightOnHour: Int
    @State private var lightOffHour: Int
    @State private var scheduleEffectiveFrom: Date
    @State private var hasEffectiveStartDate: Bool
    
    init(device: SmartDeviceItem) {
        self.device = device
        _name = State(initialValue: device.name)
        _deviceType = State(initialValue: device.deviceType)
        _brand = State(initialValue: device.brand)
        _webhookURL = State(initialValue: device.webhookURL)
        _remoteCloudURL = State(initialValue: device.remoteCloudURL)
        _tuyaDeviceID = State(initialValue: device.tuyaDeviceID)
        _autoControlEnabled = State(initialValue: device.autoControlEnabled)
        _autopilotMode = State(initialValue: device.autopilotMode)
        _customIntervalHours = State(initialValue: device.customIntervalHours)
        _customIntervalMinutes = State(initialValue: device.customIntervalMinutes)
        _customDurationMinutes = State(initialValue: device.customDurationMinutes)
        _lightOnHour = State(initialValue: device.lightOnHour)
        _lightOffHour = State(initialValue: device.lightOffHour)
        _scheduleEffectiveFrom = State(initialValue: device.scheduleEffectiveFrom ?? Date())
        _hasEffectiveStartDate = State(initialValue: device.scheduleEffectiveFrom != nil)
    }
    
    private var formattedInterval: String {
        if customIntervalHours > 0 && customIntervalMinutes > 0 {
            return "\(customIntervalHours)u \(customIntervalMinutes)m"
        } else if customIntervalHours > 0 {
            return "\(customIntervalHours)u"
        } else {
            return "\(customIntervalMinutes)m"
        }
    }
    
    private func presetChip(label: String, h: Int, m: Int, d: Int) -> some View {
        Button {
            customIntervalHours = h
            customIntervalMinutes = m
            customDurationMinutes = d
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private let deviceTypes = [
        ("Humidifier", "💧 Humidifier"),
        ("ExhaustFan", "🌪 FAE Exhaust / Fan"),
        ("Sensor", "🌡 Climate Sensor (Temp & RH)"),
        ("Heater", "🔥 Heat Mat"),
        ("Light", "💡 Grow Light"),
        ("GenericPlug", "🔌 Smart Plug")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(store.t(nl: "1. Kies Apparaattype / Functie", en: "1. Choose Device Type / Function"))) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(deviceTypes, id: \.0) { item in
                            Button {
                                deviceType = item.0
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: SmartDeviceItem.icon(for: item.0))
                                    Text(item.1)
                                        .font(.system(size: 11, weight: .bold))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 6)
                                .background(deviceType == item.0 ? MycoTheme.blue : Color.white.opacity(0.08))
                                .foregroundColor(deviceType == item.0 ? .white : MycoTheme.textSecondary)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(deviceType == item.0 ? Color.white : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text(store.t(nl: "2. Protocol / Type Hardware", en: "2. Protocol / Hardware Type"))) {
                    TextField(store.t(nl: "Naam", en: "Name"), text: $name)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SmartDeviceItem.supportedProtocols, id: \.id) { proto in
                                Button {
                                    brand = proto.id
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: proto.icon)
                                        Text(store.isEnglish ? proto.nameEn : proto.nameNl)
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(brand == proto.id ? MycoTheme.blue : Color.white.opacity(0.08))
                                    .foregroundColor(brand == proto.id ? .white : MycoTheme.textSecondary)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(brand == proto.id ? Color.white : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text(store.t(nl: "Autopilot Automatisering", en: "Autopilot Automation"))) {
                    Toggle(store.t(nl: "Automatisch Schakelen Toestaan", en: "Allow Automatic Switching"), isOn: $autoControlEnabled)
                        .tint(Color.green)
                    
                    if autoControlEnabled && deviceType != "Sensor" {
                        if deviceType == "Light" {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(store.t(
                                    nl: "Stel in hoe laat de kweeklamp dagelijks automatisch AAN en UIT moet schakelen.",
                                    en: "Configure what time the grow light turns ON and OFF daily."
                                ))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(store.t(nl: "Kloktijd AAN:", en: "Time ON:"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        Stepper(value: $lightOnHour, in: 0...23) {
                                            Text(String(format: "%02d:00", lightOnHour))
                                                .font(.system(.body, design: .monospaced).bold())
                                                .foregroundColor(Color.green)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(store.t(nl: "Kloktijd UIT:", en: "Time OFF:"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        Stepper(value: $lightOffHour, in: 0...23) {
                                            Text(String(format: "%02d:00", lightOffHour))
                                                .font(.system(.body, design: .monospaced).bold())
                                                .foregroundColor(Color.orange)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                }
                                
                                let totalHours = lightOnHour <= lightOffHour ? (lightOffHour - lightOnHour) : (24 - lightOnHour + lightOffHour)
                                HStack(spacing: 8) {
                                    Image(systemName: "sun.max.fill")
                                        .foregroundColor(Color.yellow)
                                    Text(store.t(
                                        nl: "Dagelijks licht van \(String(format: "%02d:00", lightOnHour)) tot \(String(format: "%02d:00", lightOffHour)) (\(totalHours) uur licht per dag).",
                                        en: "Daily light from \(String(format: "%02d:00", lightOnHour)) to \(String(format: "%02d:00", lightOffHour)) (\(totalHours) hours of light daily)."
                                    ))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.yellow.opacity(0.12))
                                .cornerRadius(8)
                            }
                            .padding(.vertical, 4)
                        } else {
                            Picker(store.t(nl: "Aansturing", en: "Control Mode"), selection: $autopilotMode) {
                                Text(store.t(nl: "📷 Optische Meter / Sensor", en: "📷 Optical Meter / Sensor")).tag("auto")
                                Text(store.t(nl: "⏱️ Vast Schema (Zonder sensor)", en: "⏱️ Fixed Timer (No sensor)")).tag("customInterval")
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 4)
                            
                            if autopilotMode == "customInterval" {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(store.t(
                                        nl: "Ideaal als je (nog) geen fysieke sensor hebt. Autopilot schakelt 24/7 op vaste intervallen die direct opgeslagen worden op je Tuya stekker.",
                                        en: "Ideal if you don't have a physical sensor yet. Autopilot runs 24/7 on fixed intervals synced directly to your Tuya plug."
                                    ))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                    
                                    // Interval Steppers (Herhaalcyclus)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(store.t(nl: "Herhaalcyclus (Om de hoeveel tijd):", en: "Repeat cycle (How often):"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        
                                        HStack(spacing: 8) {
                                            Stepper(value: $customIntervalHours, in: 0...48) {
                                                Text("\(customIntervalHours) " + store.t(nl: "uur", en: "hrs"))
                                                    .font(.system(.body, design: .monospaced).bold())
                                            }
                                            
                                            Stepper(value: $customIntervalMinutes, in: 0...55, step: 5) {
                                                Text("\(customIntervalMinutes) min")
                                                    .font(.system(.body, design: .monospaced).bold())
                                            }
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                    
                                    // Duration Stepper (Inschakelduur)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(store.t(nl: "Inschakelduur (Hoe lang AAN):", en: "Run duration (How long ON):"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        
                                        Stepper(value: $customDurationMinutes, in: 1...180) {
                                            Text("\(customDurationMinutes) " + store.t(nl: customDurationMinutes == 1 ? "minuut AAN" : "minuten AAN", en: customDurationMinutes == 1 ? "minute ON" : "minutes ON"))
                                                .font(.system(.body, design: .monospaced).bold())
                                                .foregroundColor(MycoTheme.amber)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                    
                                    // Quick presets
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(store.t(nl: "Snelle kweekpresets:", en: "Quick presets:"))
                                            .font(.caption2.bold())
                                            .foregroundColor(MycoTheme.textSecondary)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 6) {
                                                presetChip(label: "1u • 2m", h: 1, m: 0, d: 2)
                                                presetChip(label: "2u • 5m", h: 2, m: 0, d: 5)
                                                presetChip(label: "3u • 5m", h: 3, m: 0, d: 5)
                                                presetChip(label: "4u • 10m", h: 4, m: 0, d: 10)
                                                presetChip(label: "6u • 15m", h: 6, m: 0, d: 15)
                                                presetChip(label: "12u • 30m", h: 12, m: 0, d: 30)
                                            }
                                        }
                                    }
                                    
                                    // Ingangsdatum / Uur van Invoering
                                    VStack(alignment: .leading, spacing: 6) {
                                        Toggle(isOn: $hasEffectiveStartDate) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "calendar.badge.clock")
                                                    .foregroundColor(Color.cyan)
                                                Text(store.t(nl: "Uitgesteld Ingangstijdstip", en: "Scheduled Activation Time"))
                                                    .font(.caption.bold())
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .tint(Color.cyan)
                                        
                                        if hasEffectiveStartDate {
                                            DatePicker(
                                                store.t(nl: "Actief vanaf:", en: "Active from:"),
                                                selection: $scheduleEffectiveFrom,
                                                displayedComponents: [.date, .hourAndMinute]
                                            )
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            
                                            Text(store.t(
                                                nl: "Dit schema wordt pas vanaf dit tijdstip overgenomen. Tot die tijd blijft het apparaat in de huidige status.",
                                                en: "This schedule activates only from this moment. Device remains in current state until then."
                                            ))
                                            .font(.system(size: 10))
                                            .foregroundColor(MycoTheme.textSecondary)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.cyan.opacity(0.08))
                                    .cornerRadius(8)
                                    
                                    // Summary Callout
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(MycoTheme.amber)
                                        Text(store.t(
                                            nl: "Elke \(formattedInterval) schakelt dit apparaat automatisch \(customDurationMinutes)m AAN.",
                                            en: "Every \(formattedInterval) this device turns automatically ON for \(customDurationMinutes)m."
                                        ))
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(MycoTheme.amber.opacity(0.12))
                                    .cornerRadius(8)
                                }
                                .padding(.vertical, 4)
                            } else {
                                if !store.hasPhysicalSensorAvailable {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(MycoTheme.amber)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(store.t(nl: "Nog geen fysieke sensor gekoppeld", en: "No physical sensor paired yet"))
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                            Text(store.t(
                                                nl: "Omdat je nog geen fysieke klimaatsensor hebt, gebruikt Autopilot zolang een veilige intervalcyclus (elke 3 uur) totdat je sensor actief is.",
                                                en: "Since you don't have a physical sensor yet, Autopilot uses a safe fallback cycle (every 3h) until your sensor is active."
                                            ))
                                            .font(.system(size: 11))
                                            .foregroundColor(MycoTheme.textSecondary)
                                        }
                                    }
                                    .padding(10)
                                    .background(MycoTheme.amber.opacity(0.12))
                                    .cornerRadius(8)
                                } else {
                                    Text(store.t(
                                        nl: "Dit apparaat reageert 24/7 automatisch op de live meetwaarden van je fysieke klimaatsensor.",
                                        en: "This device automatically reacts to live readings from your physical climate sensor."
                                    ))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                        }
                    }
                }
                
                if brand.localizedCaseInsensitiveContains("manual") || brand.localizedCaseInsensitiveContains("handmatig") {
                    Section(header: Text(store.t(nl: "Koppeling", en: "Connection"))) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(Color.green)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.t(nl: "Handmatige bediening actief", en: "Manual mode active"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.t(
                                    nl: "Geen fysieke hardware nodig. MycoLabs herinnert je op het juiste moment via meldingen.",
                                    en: "No hardware required. MycoLabs reminds you when action is needed."
                                ))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else if brand.localizedCaseInsensitiveContains("shelly") {
                    Section(header: Text("Shelly (Lokaal Wi-Fi / REST)")) {
                        TextField(store.t(nl: "Shelly IP-adres (bijv. 192.168.1.120)", en: "Shelly IP (e.g. 192.168.1.120)"), text: $tuyaDeviceID)
                            .font(.system(.body, design: .monospaced))
                    }
                } else if brand.localizedCaseInsensitiveContains("tasmota") || brand.localizedCaseInsensitiveContains("sonoff") {
                    Section(header: Text("Tasmota / Sonoff (HTTP)")) {
                        TextField(store.t(nl: "Tasmota IP-adres (bijv. 192.168.1.130)", en: "Tasmota IP (e.g. 192.168.1.130)"), text: $tuyaDeviceID)
                            .font(.system(.body, design: .monospaced))
                    }
                } else {
                    Section(header: Text(store.t(nl: "Koppeling & Cloud IDs", en: "Connection & Cloud IDs"))) {
                        TextField(store.t(nl: "Tuya Device ID (optioneel)", en: "Tuya Device ID (optional)"), text: $tuyaDeviceID)
                            .font(.system(.body, design: .monospaced))
                        
                        TextField(store.t(nl: "Webhook URL (lokaal / Home Assistant)", en: "Webhook URL (local / Home Assistant)"), text: $webhookURL)
                            .font(.system(.caption, design: .monospaced))
                        
                        TextField(store.t(nl: "Remote Cloud URL (4G/5G wereldwijd)", en: "Remote Cloud URL (4G/5G global)"), text: $remoteCloudURL)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        store.deleteSmartDevice(id: device.id)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text(store.t(nl: "Apparaat Verwijderen", en: "Delete Device"))
                        }
                    }
                }
            }
            .navigationTitle(store.t(nl: "Apparaat Bewerken", en: "Edit Device"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                name = device.name
                deviceType = device.deviceType
                brand = device.brand
                webhookURL = device.webhookURL
                remoteCloudURL = device.remoteCloudURL
                tuyaDeviceID = device.tuyaDeviceID
                autoControlEnabled = device.autoControlEnabled
                autopilotMode = device.autopilotMode
                customIntervalHours = device.customIntervalHours
                customIntervalMinutes = device.customIntervalMinutes
                customDurationMinutes = device.customDurationMinutes
                lightOnHour = device.lightOnHour
                lightOffHour = device.lightOffHour
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Annuleren", en: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Opslaan", en: "Save")) {
                        saveChanges()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
    
    private func saveChanges() {
        guard let idx = store.db.smartDevices.firstIndex(where: { $0.id == device.id }) else { return }
        store.db.deletedItemIDs.removeAll { $0 == device.id }
        if !tuyaDeviceID.isEmpty {
            store.db.deletedTuyaDeviceIDs.removeAll { $0 == tuyaDeviceID }
        }
        store.db.smartDevices[idx].name = name.isEmpty ? "Apparaat" : name
        store.db.smartDevices[idx].deviceType = deviceType
        store.db.smartDevices[idx].brand = brand
        store.db.smartDevices[idx].webhookURL = webhookURL
        store.db.smartDevices[idx].remoteCloudURL = remoteCloudURL
        store.db.smartDevices[idx].tuyaDeviceID = tuyaDeviceID
        store.db.smartDevices[idx].autoControlEnabled = autoControlEnabled
        store.db.smartDevices[idx].autopilotMode = autopilotMode
        store.db.smartDevices[idx].customIntervalHours = customIntervalHours
        store.db.smartDevices[idx].customIntervalMinutes = customIntervalMinutes
        store.db.smartDevices[idx].customDurationMinutes = customDurationMinutes
        store.db.smartDevices[idx].lightOnHour = lightOnHour
        store.db.smartDevices[idx].lightOffHour = lightOffHour
        store.db.smartDevices[idx].scheduleEffectiveFrom = hasEffectiveStartDate ? scheduleEffectiveFrom : nil
        
        let now = Date()
        store.db.smartDevices[idx].lastCustomExecutionTime = now
        store.db.smartDevices[idx].lastModifiedAt = now
        
        // Reset timers so NO background autopilot cycle is considered overdue right when saving
        for i in 0..<store.db.smartDevices.count {
            if !store.db.smartDevices[i].isOn {
                store.db.smartDevices[i].lastCustomExecutionTime = now
            }
        }
        store.db.environmentConfig.lastFaeExecutionTime = now
        store.db.environmentConfig.lastHumidifierExecutionTime = now
        
        store.saveImmediately()
        MycoSyncManager.shared.sendSyncPayload(reason: "smart_device_changed")
    }
}

struct AddSmartDeviceSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var deviceType: String = "Humidifier"
    @State private var brand: String = "Tuya / Smart Life"
    @State private var webhookURL: String = ""
    @State private var remoteCloudURL: String = ""
    @State private var tuyaDeviceID: String = ""
    @State private var showTuyaWizard: Bool = false
    @State private var autoControlEnabled: Bool = true
    @State private var autopilotMode: String = "auto"
    @State private var customIntervalHours: Int = 3
    @State private var customIntervalMinutes: Int = 0
    @State private var customDurationMinutes: Int = 5
    @State private var lightOnHour: Int = 8
    @State private var lightOffHour: Int = 20
    
    private var formattedInterval: String {
        if customIntervalHours > 0 && customIntervalMinutes > 0 {
            return "\(customIntervalHours)u \(customIntervalMinutes)m"
        } else if customIntervalHours > 0 {
            return "\(customIntervalHours)u"
        } else {
            return "\(customIntervalMinutes)m"
        }
    }
    
    private func presetChip(label: String, h: Int, m: Int, d: Int) -> some View {
        Button {
            customIntervalHours = h
            customIntervalMinutes = m
            customDurationMinutes = d
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private let deviceTypes = [
        ("Humidifier", "Humidifier"),
        ("ExhaustFan", "FAE Exhaust / Fan"),
        ("Sensor", "Climate Sensor (Temp & RH)"),
        ("Heater", "Heat Mat"),
        ("Light", "Grow Light"),
        ("GenericPlug", "Smart Plug")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showTuyaWizard = true
                    } label: {
                        HStack {
                            Image(systemName: "bolt.badge.automatic.fill")
                                .foregroundColor(MycoTheme.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Tuya / Smart Life Stekker Wizard", en: "Tuya / Smart Life Plug Wizard"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.t(nl: "Automatisch testen, ontdekken & toevoegen", en: "Automatically test, discover & add plugs"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                }
                
                Section(header: Text(store.t(nl: "1. Kies Apparaattype / Functie", en: "1. Choose Device Type / Function"))) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(deviceTypes, id: \.0) { item in
                            Button {
                                deviceType = item.0
                                if name.isEmpty || deviceTypes.contains(where: { $0.1 == name }) {
                                    name = item.1
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: SmartDeviceItem.icon(for: item.0))
                                    Text(item.1)
                                        .font(.system(size: 11, weight: .bold))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 6)
                                .background(deviceType == item.0 ? MycoTheme.blue : Color.white.opacity(0.08))
                                .foregroundColor(deviceType == item.0 ? .white : MycoTheme.textSecondary)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(deviceType == item.0 ? Color.white : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text(store.t(nl: "2. Protocol / Type Hardware", en: "2. Protocol / Hardware Type"))) {
                    TextField(store.t(nl: "Naam (bijv. Luchtbevochtiger Tent 1)", en: "Name (e.g. Humidifier Tent 1)"), text: $name)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SmartDeviceItem.supportedProtocols, id: \.id) { proto in
                                Button {
                                    brand = proto.id
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: proto.icon)
                                        Text(store.isEnglish ? proto.nameEn : proto.nameNl)
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(brand == proto.id ? MycoTheme.blue : Color.white.opacity(0.08))
                                    .foregroundColor(brand == proto.id ? .white : MycoTheme.textSecondary)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(brand == proto.id ? Color.white : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if brand.localizedCaseInsensitiveContains("manual") || brand.localizedCaseInsensitiveContains("handmatig") {
                    Section(header: Text(store.t(nl: "3. Handmatige Werking", en: "3. Manual Setup"))) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(Color.green)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.t(nl: "Geen slimme stekker vereist!", en: "No smart plug required!"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.t(
                                    nl: "Perfect voor beginners met een plantenspuit of handmatige ventilator. Autopilot berekent de intervallen en stuurt interactieve herinneringen wanneer actie nodig is.",
                                    en: "Perfect for beginners with a spray bottle or manual fan. Autopilot calculates intervals and sends interactive reminders when action is needed."
                                ))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else if brand.localizedCaseInsensitiveContains("shelly") {
                    Section(header: Text("Shelly (Lokaal Wi-Fi / REST)"), footer: Text(store.t(nl: "Schakelt 100% lokaal via Wi-Fi met directe HTTP aanroep (geen cloud nodig).", en: "Switches 100% locally via Wi-Fi with direct HTTP call (no cloud needed)."))) {
                        HStack {
                            TextField(store.t(nl: "Shelly IP-adres (bijv. 192.168.1.120)", en: "Shelly IP (e.g. 192.168.1.120)"), text: $tuyaDeviceID)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                            Button {
                                if let s = UIPasteboard.general.string {
                                    tuyaDeviceID = s.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundColor(MycoTheme.blue)
                            }
                        }
                    }
                } else if brand.localizedCaseInsensitiveContains("tasmota") || brand.localizedCaseInsensitiveContains("sonoff") {
                    Section(header: Text("Tasmota / Sonoff (HTTP)"), footer: Text(store.t(nl: "Directe HTTP aansturing via /cm?cmnd=Power.", en: "Direct HTTP control via /cm?cmnd=Power."))) {
                        HStack {
                            TextField(store.t(nl: "Tasmota IP-adres (bijv. 192.168.1.130)", en: "Tasmota IP (e.g. 192.168.1.130)"), text: $tuyaDeviceID)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                            Button {
                                if let s = UIPasteboard.general.string {
                                    tuyaDeviceID = s.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundColor(MycoTheme.blue)
                            }
                        }
                    }
                } else if brand.localizedCaseInsensitiveContains("webhook") || brand.localizedCaseInsensitiveContains("home assistant") {
                    Section(header: Text("Home Assistant / Webhook")) {
                        TextField(store.t(nl: "Lokaal Webhook URL (bijv. http://192.168.1.x/...)", en: "Local Webhook URL"), text: $webhookURL)
                            .font(.system(.caption, design: .monospaced))
                        TextField(store.t(nl: "Remote Cloud URL (optioneel)", en: "Remote Cloud URL (optional)"), text: $remoteCloudURL)
                            .font(.system(.caption, design: .monospaced))
                    }
                } else {
                    Section(header: Text("Tuya / Smart Life Stekker"), footer: Text(store.t(nl: "Vul het Device ID van je Tuya / Smart Life stekker in. De 24/7 Autopilot schakelt deze automatisch aan en uit.", en: "Enter the Device ID of your Tuya / Smart Life plug. 24/7 Autopilot will switch it automatically."))) {
                        HStack {
                            TextField(store.t(nl: "Tuya Stekker Device ID", en: "Tuya Plug Device ID"), text: $tuyaDeviceID)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            Button {
                                if let s = UIPasteboard.general.string {
                                    tuyaDeviceID = s.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundColor(MycoTheme.blue)
                            }
                        }
                    }
                    Section(header: Text(store.t(nl: "Optioneel: Wi-Fi Webhook", en: "Optional: Wi-Fi Webhook"))) {
                        TextField("http://192.168.1.50/relay/0?turn=toggle", text: $webhookURL)
                            .font(.system(.caption, design: .monospaced))
                        TextField("https://hooks.nabu.casa/...", text: $remoteCloudURL)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                
                Section(header: Text(store.t(nl: "24/7 Autopilot Automatisering", en: "24/7 Autopilot Automation"))) {
                    Toggle(store.t(nl: "Automatisch Schakelen Toestaan", en: "Allow Automatic Switching"), isOn: $autoControlEnabled)
                        .tint(Color.green)
                    
                    if autoControlEnabled && deviceType != "Sensor" {
                        if deviceType == "Light" {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(store.t(
                                    nl: "Stel in hoe laat de kweeklamp dagelijks automatisch AAN en UIT moet schakelen.",
                                    en: "Configure what time the grow light turns ON and OFF daily."
                                ))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(store.t(nl: "Kloktijd AAN:", en: "Time ON:"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        Stepper(value: $lightOnHour, in: 0...23) {
                                            Text(String(format: "%02d:00", lightOnHour))
                                                .font(.system(.body, design: .monospaced).bold())
                                                .foregroundColor(Color.green)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(store.t(nl: "Kloktijd UIT:", en: "Time OFF:"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        Stepper(value: $lightOffHour, in: 0...23) {
                                            Text(String(format: "%02d:00", lightOffHour))
                                                .font(.system(.body, design: .monospaced).bold())
                                                .foregroundColor(Color.orange)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                }
                                
                                let totalHours = lightOnHour <= lightOffHour ? (lightOffHour - lightOnHour) : (24 - lightOnHour + lightOffHour)
                                HStack(spacing: 8) {
                                    Image(systemName: "sun.max.fill")
                                        .foregroundColor(Color.yellow)
                                    Text(store.t(
                                        nl: "Dagelijks licht van \(String(format: "%02d:00", lightOnHour)) tot \(String(format: "%02d:00", lightOffHour)) (\(totalHours) uur licht per dag).",
                                        en: "Daily light from \(String(format: "%02d:00", lightOnHour)) to \(String(format: "%02d:00", lightOffHour)) (\(totalHours) hours of light daily)."
                                    ))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.yellow.opacity(0.12))
                                .cornerRadius(8)
                            }
                            .padding(.vertical, 4)
                        } else {
                            Picker(store.t(nl: "Aansturing", en: "Control Mode"), selection: $autopilotMode) {
                                Text(store.t(nl: "📷 Optische Meter / Sensor", en: "📷 Optical Meter / Sensor")).tag("auto")
                                Text(store.t(nl: "⏱️ Vast Schema (Zonder sensor)", en: "⏱️ Fixed Timer (No sensor)")).tag("customInterval")
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 4)
                            
                            if autopilotMode == "customInterval" {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(store.t(
                                        nl: "Ideaal als je (nog) geen fysieke sensor hebt. Autopilot schakelt 24/7 op vaste intervallen die direct opgeslagen worden op je Tuya stekker.",
                                        en: "Ideal if you don't have a physical sensor yet. Autopilot runs 24/7 on fixed intervals synced directly to your Tuya plug."
                                    ))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                    
                                    // Interval Steppers (Herhaalcyclus)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(store.t(nl: "Herhaalcyclus (Om de hoeveel tijd):", en: "Repeat cycle (How often):"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        
                                        HStack(spacing: 8) {
                                            Stepper(value: $customIntervalHours, in: 0...48) {
                                                Text("\(customIntervalHours) " + store.t(nl: "uur", en: "hrs"))
                                                    .font(.system(.body, design: .monospaced).bold())
                                            }
                                            
                                            Stepper(value: $customIntervalMinutes, in: 0...55, step: 5) {
                                                Text("\(customIntervalMinutes) min")
                                                    .font(.system(.body, design: .monospaced).bold())
                                            }
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                    
                                    // Duration Stepper (Inschakelduur)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(store.t(nl: "Inschakelduur (Hoe lang AAN):", en: "Run duration (How long ON):"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        
                                        Stepper(value: $customDurationMinutes, in: 1...180) {
                                            Text("\(customDurationMinutes) " + store.t(nl: customDurationMinutes == 1 ? "minuut AAN" : "minuten AAN", en: customDurationMinutes == 1 ? "minute ON" : "minutes ON"))
                                                .font(.system(.body, design: .monospaced).bold())
                                                .foregroundColor(MycoTheme.amber)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                    
                                    // Quick presets
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(store.t(nl: "Snelle kweekpresets:", en: "Quick presets:"))
                                            .font(.caption2.bold())
                                            .foregroundColor(MycoTheme.textSecondary)
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 6) {
                                                presetChip(label: "1u • 2m", h: 1, m: 0, d: 2)
                                                presetChip(label: "2u • 5m", h: 2, m: 0, d: 5)
                                                presetChip(label: "3u • 5m", h: 3, m: 0, d: 5)
                                                presetChip(label: "4u • 10m", h: 4, m: 0, d: 10)
                                                presetChip(label: "6u • 15m", h: 6, m: 0, d: 15)
                                                presetChip(label: "12u • 30m", h: 12, m: 0, d: 30)
                                            }
                                        }
                                    }
                                    
                                    // Summary Callout
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(MycoTheme.amber)
                                        Text(store.t(
                                            nl: "Elke \(formattedInterval) schakelt dit apparaat automatisch \(customDurationMinutes)m AAN.",
                                            en: "Every \(formattedInterval) this device turns automatically ON for \(customDurationMinutes)m."
                                        ))
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(MycoTheme.amber.opacity(0.12))
                                    .cornerRadius(8)
                                }
                                .padding(.vertical, 4)
                            } else {
                                if !store.hasPhysicalSensorAvailable {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(MycoTheme.amber)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(store.t(nl: "Nog geen fysieke sensor gekoppeld", en: "No physical sensor paired yet"))
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                            Text(store.t(
                                                nl: "Omdat je nog geen fysieke klimaatsensor hebt, gebruikt Autopilot zolang een veilige intervalcyclus (elke 3 uur) totdat je sensor actief is.",
                                                en: "Since you don't have a physical sensor yet, Autopilot uses a safe fallback cycle (every 3h) until your sensor is active."
                                            ))
                                            .font(.system(size: 11))
                                            .foregroundColor(MycoTheme.textSecondary)
                                        }
                                    }
                                    .padding(10)
                                    .background(MycoTheme.amber.opacity(0.12))
                                    .cornerRadius(8)
                                } else {
                                    Text(store.t(
                                        nl: "Dit apparaat reageert 24/7 automatisch op de live meetwaarden van je fysieke klimaatsensor.",
                                        en: "This device automatically reacts to live readings from your physical climate sensor."
                                    ))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(store.t(nl: "Smart Stekker Toevoegen", en: "Add Smart Plug"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTuyaWizard) {
                TuyaSetupWizardSheet()
                    .environmentObject(store)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Annuleren", en: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Opslaan", en: "Save")) {
                        let item = SmartDeviceItem(
                            name: name.isEmpty ? "Nieuwe Stekker" : name,
                            deviceType: deviceType,
                            brand: brand,
                            webhookURL: webhookURL,
                            remoteCloudURL: remoteCloudURL,
                            tuyaDeviceID: tuyaDeviceID,
                            autoControlEnabled: autoControlEnabled,
                            autopilotMode: autopilotMode,
                            customIntervalHours: customIntervalHours,
                            customIntervalMinutes: customIntervalMinutes,
                            customDurationMinutes: customDurationMinutes,
                            lightOnHour: lightOnHour,
                            lightOffHour: lightOffHour,
                            lastModifiedAt: Date()
                        )
                        store.db.deletedItemIDs.removeAll { $0 == item.id }
                        if !item.tuyaDeviceID.isEmpty {
                            store.db.deletedTuyaDeviceIDs.removeAll { $0 == item.tuyaDeviceID }
                        }
                        let now = Date()
                        for i in 0..<store.db.smartDevices.count {
                            if !store.db.smartDevices[i].isOn {
                                store.db.smartDevices[i].lastCustomExecutionTime = now
                            }
                        }
                        store.db.environmentConfig.lastFaeExecutionTime = now
                        store.db.environmentConfig.lastHumidifierExecutionTime = now
                        
                        store.db.smartDevices.append(item)
                        store.saveImmediately()
                        MycoSyncManager.shared.broadcastDeviceAdded(item)
                        MycoSyncManager.shared.sendSyncPayload(reason: "smart_device_added")
                        MycoSyncManager.shared.triggerToast(
                            message: "✅ \(item.name) toegevoegd & opgeslagen!"
                        )
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

struct TuyaSetupWizardSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var envName: String = ""
    @State private var targetTemp: String = "23.5"
    @State private var targetHum: String = "90"
    @State private var apiKey: String = ""
    @State private var apiSecret: String = ""
    @State private var region: String = "ce"
    @State private var showSecret: Bool = false
    @State private var showGuide: Bool = false
    
    // Testing state
    @State private var isTestingConnection: Bool = false
    @State private var connectionSuccess: Bool? = nil
    @State private var connectionMessage: String = ""
    @State private var connectedUID: String = ""
    @State private var lastRawLog: String = ""
    @State private var showDiagnostics: Bool = false
    
    // Device check state
    @State private var testDeviceID: String = ""
    @State private var isCheckingDevice: Bool = false
    @State private var checkedDevice: TuyaCloudManager.DeviceInfo? = nil
    @State private var deviceCheckMessage: String = ""
    @State private var isTogglingDevice: Bool = false
    
    // Discovered devices
    @State private var isDiscoveringDevices: Bool = false
    @State private var discoveredDevices: [TuyaCloudManager.DeviceInfo] = []
    @State private var addedToast: String = ""
    @State private var selectedDeviceType: String = "Humidifier"
    
    var body: some View {
        NavigationStack {
            Form {
                // Header & Guide
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "link.badge.plus")
                                .font(.title2)
                                .foregroundColor(MycoTheme.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Smart Stekkers Koppel Wizard", en: "Smart Plug Pairing Wizard"))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(store.t(nl: "Voor LSC Smart Connect (Action), Tuya, Smart Life, Calex en Woox stekkers.", en: "For LSC Smart Connect, Tuya, Smart Life, Calex, and Woox plugs."))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(Color.green)
                            Text(store.t(
                                nl: "Alleen voor eenmalig koppelen & apparaat-ID's importeren. De dagelijkse 24/7 besturing gebeurt 100% lokaal via je Raspberry Pi Hub & Tailscale!",
                                en: "Only needed for one-time pairing & importing device IDs. Daily 24/7 control runs 100% locally via your Raspberry Pi Hub & Tailscale!"
                            ))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.green)
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(8)
                        
                        DisclosureGroup(isExpanded: $showGuide) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("1️⃣ Open **iot.tuya.com** op PC/tablet en log in.")
                                Text("2️⃣ Ga naar **Cloud** ➔ **Development** ➔ **Create Cloud Project**.")
                                Text("3️⃣ Ga naar **Link Tuya App Account** ➔ Scan de QR met de Smart Life app op je telefoon (*Profiel* ➔ scan-icoon rechtsboven).")
                                Text("4️⃣ Ga naar **Project Overview** en kopieer je **Access ID** en **Access Secret**.")
                                Text("5️⃣ Plak ze hieronder en tik op **Test Tuya Verbinding**!")
                                Text("6️⃣ **Fout 'Not Subscribed to API' of Code 28841002/28841105?**: Ga in iot.tuya.com naar Cloud ➔ Cloud Services en klik op **Extend Trial Period** om gratis te verlengen. Controleer ook onder je project ➔ **Service API** of **IoT Core** geautoriseerd is.")
                                Text("💡 *Stekker Device ID*: In Smart Life app ➔ Stekker ➔ ✎ (rechtsboven) ➔ *Apparaatinformatie* ➔ *Apparaat-id*.")
                                    .padding(.top, 4)
                            }
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                            .padding(.top, 4)
                        } label: {
                            Text(store.t(nl: "📖 Stap-voor-stap uitleg (Klik hier)", en: "📖 Step-by-step Guide (Tap here)"))
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Tuya Developer API Keys
                Section(header: Text(store.t(nl: "Tuya Developer Gegevens", en: "Tuya Developer Credentials"))) {
                    Picker(store.t(nl: "Datacenter Regio", en: "Data Center Region"), selection: $region) {
                        Text("🇪🇺 Centraal-Europa (ce - Frankfurt)").tag("ce")
                        Text("🇪🇺 West-Europa (weaz - Azure)").tag("weaz")
                        Text("🇺🇸 Amerika West (us - Oregon)").tag("us")
                        Text("🇺🇸 Amerika Oost (ueaz - Azure)").tag("ueaz")
                        Text("🇨🇳 China (cn)").tag("cn")
                        Text("🇮🇳 India (in)").tag("in")
                    }
                    .onChange(of: region) {
                        handleCredentialsChanged()
                    }
                    
                    HStack {
                        TextField("Access ID / Client ID", text: $apiKey)
                            .font(.system(.body, design: .monospaced))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: apiKey) {
                                handleCredentialsChanged()
                            }
                        Button {
                            if let s = UIPasteboard.general.string {
                                apiKey = s.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(MycoTheme.blue)
                        }
                    }
                    
                    HStack {
                        if showSecret {
                            TextField("Access Secret", text: $apiSecret)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .onChange(of: apiSecret) {
                                    handleCredentialsChanged()
                                }
                        } else {
                            SecureField("Access Secret", text: $apiSecret)
                                .font(.system(.body, design: .monospaced))
                                .onChange(of: apiSecret) {
                                    handleCredentialsChanged()
                                }
                        }
                        
                        Button {
                            showSecret.toggle()
                        } label: {
                            Image(systemName: showSecret ? "eye.slash" : "eye")
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        
                        Button {
                            if let s = UIPasteboard.general.string {
                                apiSecret = s.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(MycoTheme.blue)
                        }
                    }
                    
                    // Unverified Notice
                    if connectionSuccess == nil && !apiKey.isEmpty && !apiSecret.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Color.orange)
                            Text(store.t(nl: "Sleutels zijn gewijzigd • Druk op 'Test Tuya Verbinding' om live te verifiëren.", en: "Keys modified • Tap 'Test Tuya Connection' to verify live."))
                                .font(.caption)
                                .foregroundColor(Color.orange)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    // Test Button
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .padding(.trailing, 6)
                            } else {
                                Image(systemName: "bolt.horizontal.fill")
                            }
                            Text(store.t(nl: "Test Tuya Verbinding", en: "Test Tuya Connection"))
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(apiKey.isEmpty || apiSecret.isEmpty || isTestingConnection)
                    
                    if let success = connectionSuccess {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundColor(success ? Color.green : Color.red)
                            Text(connectionMessage)
                                .font(.caption)
                                .foregroundColor(success ? Color.green : Color.red)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Live Diagnostic Log
                    if !lastRawLog.isEmpty {
                        DisclosureGroup(isExpanded: $showDiagnostics) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Live Antwoord van Tuya Cloud:")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(MycoTheme.textSecondary)
                                Text(lastRawLog)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.green)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.85))
                                    .cornerRadius(6)
                            }
                            .padding(.top, 4)
                        } label: {
                            HStack {
                                Image(systemName: "terminal.fill")
                                Text(store.t(nl: "Toon Live API Response (JSON)", en: "Show Live API Response (JSON)"))
                            }
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                        }
                    }
                }
                
                // Device Testing & Fast Pairing
                Section(header: Text(store.t(nl: "Stekker Controleren & Testen", en: "Check & Test Plug"))) {
                    HStack {
                        TextField(store.t(nl: "Stekker Device ID", en: "Plug Device ID"), text: $testDeviceID)
                            .font(.system(.body, design: .monospaced))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: testDeviceID) {
                                checkedDevice = nil
                                deviceCheckMessage = ""
                            }
                        Button {
                            if let s = UIPasteboard.general.string {
                                testDeviceID = s.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(MycoTheme.blue)
                        }
                    }
                    
                    Button {
                        checkDevice()
                    } label: {
                        HStack {
                            if isCheckingDevice {
                                ProgressView()
                                    .padding(.trailing, 6)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text(store.t(nl: "Controleer Stekker", en: "Check Plug"))
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(testDeviceID.isEmpty || apiKey.isEmpty || apiSecret.isEmpty || isCheckingDevice)
                    
                    if let dev = checkedDevice {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Circle()
                                    .fill(dev.isOnline ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(dev.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text(dev.isOnline ? "Online 🟢" : "Offline 🔴")
                                    .font(.caption.bold())
                                    .foregroundColor(dev.isOnline ? Color.green : Color.red)
                            }
                            
                            Divider().background(MycoTheme.border)
                            
                            // 1. SELECT WHAT THE DEVICE IS (Primary First Action)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.t(nl: "1. Selecteer wat dit apparaat is:", en: "1. Select what this device is:"))
                                    .font(.caption.bold())
                                    .foregroundColor(MycoTheme.textSecondary)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                    ForEach([
                                        ("Humidifier", "💧 Bevochtiger"),
                                        ("ExhaustFan", "🌪 Ventilator"),
                                        ("Sensor", "🌡 Klimaatsensor"),
                                        ("Heater", "🔥 Verwarming"),
                                        ("Light", "💡 Kweeklamp"),
                                        ("GenericPlug", "🔌 Stekker")
                                    ], id: \.0) { item in
                                        Button {
                                            selectedDeviceType = item.0
                                        } label: {
                                            Text(item.1)
                                                .font(.system(size: 11, weight: .bold))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(selectedDeviceType == item.0 ? MycoTheme.blue : Color.white.opacity(0.08))
                                                .foregroundColor(selectedDeviceType == item.0 ? .white : MycoTheme.textSecondary)
                                                .cornerRadius(6)
                                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(selectedDeviceType == item.0 ? Color.white : Color.clear, lineWidth: 1.2))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            // 2. PRIMARY ACTION: ADD TO GROW ROOM
                            Button {
                                addDeviceToStore(name: dev.name, id: dev.id, type: selectedDeviceType, title: dev.name)
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text(store.t(nl: "Voeg Toe aan Kweekruimte", en: "Add to Grow Room"))
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(MycoTheme.blue)
                                .cornerRadius(8)
                            }
                            
                            // 3. OPTIONAL TEST SWITCH (ISOLATED WITH CLEAR WARNING SO USER DOES NOT MISCLICK)
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(store.t(
                                        nl: "⚠️ Let op: Dit schakelt het fysieke relais van de stekker direct in of uit.",
                                        en: "⚠️ Note: This directly toggles the physical relay of the plug on or off."
                                    ))
                                    .font(.system(size: 11))
                                    .foregroundColor(MycoTheme.textSecondary)
                                    
                                    Button {
                                        toggleTestDevice(dev)
                                    } label: {
                                        HStack {
                                            if isTogglingDevice {
                                                ProgressView().padding(.trailing, 4)
                                            } else {
                                                Image(systemName: dev.isOn ? "power.circle.fill" : "power.circle")
                                            }
                                            Text(dev.isOn ? store.t(nl: "Stand: AAN (Tik om UIT te schakelen)", en: "State: ON (Tap to turn OFF)") : store.t(nl: "Stand: UIT (Tik om AAN te schakelen)", en: "State: OFF (Tap to turn ON)"))
                                                .font(.caption.bold())
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(dev.isOn ? Color.green : Color.gray.opacity(0.4))
                                        .foregroundColor(dev.isOn ? .black : .white)
                                        .cornerRadius(8)
                                    }
                                    .disabled(isTogglingDevice)
                                }
                                .padding(.top, 4)
                            } label: {
                                HStack {
                                    Image(systemName: "power")
                                    Text(store.t(nl: "Optioneel: Test Relais Schakelaar", en: "Optional: Test Relay Switch"))
                                }
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else if !deviceCheckMessage.isEmpty {
                        Text(deviceCheckMessage)
                            .font(.caption)
                            .foregroundColor(Color.orange)
                            .padding(.vertical, 2)
                    }
                    
                    // Discover button
                    Button {
                        discoverUserDevices()
                    } label: {
                        HStack {
                            if isDiscoveringDevices {
                                ProgressView().padding(.trailing, 4)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(store.t(nl: "Zoek Alle Stekkers in mijn Tuya Account", en: "Discover All Plugs in my Tuya Account"))
                                .font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(apiKey.isEmpty || apiSecret.isEmpty || isDiscoveringDevices)
                    
                    if !discoveredDevices.isEmpty {
                        ForEach(discoveredDevices) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                    Text(item.id)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                Spacer()
                                Menu {
                                    Button("💧 Humidifier") { quickAddBtnTapped(item: item, type: "Humidifier") }
                                    Button("🌪 Fan / FAE Exhaust") { quickAddBtnTapped(item: item, type: "ExhaustFan") }
                                    Button("🌡 Climate Sensor (Temp & RH)") { quickAddBtnTapped(item: item, type: "Sensor") }
                                    Button("🔥 Heat Mat") { quickAddBtnTapped(item: item, type: "Heater") }
                                    Button("💡 Grow Light") { quickAddBtnTapped(item: item, type: "Light") }
                                    Button("🔌 Smart Plug") { quickAddBtnTapped(item: item, type: "GenericPlug") }
                                } label: {
                                    Text(store.t(nl: "+ Koppel", en: "+ Connect"))
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(MycoTheme.blue)
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    if !addedToast.isEmpty {
                        Text(addedToast)
                            .font(.caption.bold())
                            .foregroundColor(Color.green)
                    }
                }
                
                // Target Environment Settings
                Section(header: Text(store.t(nl: "Kweekruimte Instellingen", en: "Grow Room Settings"))) {
                    TextField(store.t(nl: "Naam Kweekruimte", en: "Grow Room Name"), text: $envName)
                    TextField(store.t(nl: "Doel Temperatuur (°C)", en: "Target Temp (°C)"), text: $targetTemp)
                        .keyboardType(.decimalPad)
                    TextField(store.t(nl: "Doel Vochtigheid (% RV)", en: "Target Humidity (% RH)"), text: $targetHum)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(store.t(nl: "Tuya Koppeling Wizard", en: "Tuya Setup Wizard"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                envName = store.db.environmentConfig.environmentName
                targetTemp = String(format: "%.1f", store.db.environmentConfig.targetDayTempC)
                targetHum = String(format: "%.0f", store.db.environmentConfig.targetHumidityPct)
                apiKey = store.db.environmentConfig.tuyaApiKey
                apiSecret = store.db.environmentConfig.tuyaApiSecret
                region = store.db.environmentConfig.tuyaRegion.isEmpty ? "ce" : store.db.environmentConfig.tuyaRegion
                testDeviceID = store.db.environmentConfig.tuyaDeviceID
                if store.db.environmentConfig.tuyaVerified {
                    connectionSuccess = true
                    connectionMessage = store.t(nl: "✅ Eerder succesvol geverifieerd bij Tuya Cloud.", en: "✅ Previously verified with Tuya Cloud.")
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Annuleren", en: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Opslaan", en: "Save")) {
                        saveAll()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
    
    private func handleCredentialsChanged() {
        connectionSuccess = nil
        connectionMessage = ""
        lastRawLog = ""
        checkedDevice = nil
        deviceCheckMessage = ""
        store.db.environmentConfig.tuyaVerified = false
        Task { await TuyaCloudManager.shared.clearCache() }
    }
    
    private func quickAddBtn(name: String, id: String, type: String, title: String) -> some View {
        Button {
            addDeviceToStore(name: name, id: id, type: type, title: title)
        } label: {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(MycoTheme.card)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(MycoTheme.border, lineWidth: 1))
        }
    }
    
    private func quickAddBtnTapped(item: TuyaCloudManager.DeviceInfo, type: String) {
        addDeviceToStore(name: item.name, id: item.id, type: type, title: item.name)
    }
    
    private func addDeviceToStore(name: String, id: String, type: String, title: String) {
        let newDev = SmartDeviceItem(
            name: name,
            deviceType: type,
            brand: "Tuya / Smart Life",
            webhookURL: "",
            remoteCloudURL: "",
            tuyaDeviceID: id,
            isOn: type == "Sensor" ? true : (checkedDevice?.isOn ?? false),
            autoControlEnabled: true,
            currentTempC: checkedDevice?.tempC,
            currentHumidityPct: checkedDevice?.humidityPct,
            lastReadingTime: (checkedDevice?.tempC != nil || checkedDevice?.humidityPct != nil) ? Date() : nil
        )
        store.db.deletedItemIDs.removeAll { $0 == newDev.id }
        if !newDev.tuyaDeviceID.isEmpty {
            store.db.deletedTuyaDeviceIDs.removeAll { $0 == newDev.tuyaDeviceID }
        }

        if let idx = store.db.smartDevices.firstIndex(where: { $0.tuyaDeviceID == id }) {
            store.db.smartDevices[idx].name = name
            store.db.smartDevices[idx].deviceType = type
            store.db.smartDevices[idx].lastModifiedAt = Date()
            if checkedDevice?.tempC != nil { store.db.smartDevices[idx].currentTempC = checkedDevice?.tempC }
            if checkedDevice?.humidityPct != nil { store.db.smartDevices[idx].currentHumidityPct = checkedDevice?.humidityPct }
        } else {
            store.db.smartDevices.append(newDev)
        }
        
        if type == "Sensor" {
            if let t = checkedDevice?.tempC, let h = checkedDevice?.humidityPct {
                store.recordSensorReading(tempC: t, humidityPct: h, source: name)
            }
        }
        
        store.saveImmediately()
        Task {
            await store.pushCentralDatabaseToPi()
            await store.syncSchedulesToPiHub()
        }
        MycoSyncManager.shared.broadcastDeviceAdded(newDev)
        MycoSyncManager.shared.triggerToast(
            message: "✅ Apparaat '\(name)' toegevoegd & gesynchroniseerd!"
        )
        addedToast = store.t(nl: "✅ Apparaat '\(name)' toegevoegd aan Hub!", en: "✅ Device '\(name)' added to Hub!")
    }
    
    private func saveAll() {
        store.db.environmentConfig.environmentName = envName.isEmpty ? "Marthakast" : envName
        store.db.environmentConfig.targetDayTempC = Double(targetTemp.replacingOccurrences(of: ",", with: ".")) ?? 23.5
        store.db.environmentConfig.targetHumidityPct = Double(targetHum) ?? 90.0
        store.db.environmentConfig.tuyaApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        store.db.environmentConfig.tuyaApiSecret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        store.db.environmentConfig.tuyaRegion = region
        let trimmedDevId = testDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        store.db.environmentConfig.tuyaDeviceID = trimmedDevId
        if !trimmedDevId.isEmpty {
            store.db.deletedTuyaDeviceIDs.removeAll { $0 == trimmedDevId }
        }
        store.db.environmentConfig.lastModifiedAt = Date()
        store.saveImmediately()
        MycoSyncManager.shared.syncSmartDevicesToPeersAndCloud(reason: "smart_device_changed")
        MycoSyncManager.shared.sendSyncPayload(reason: "smart_device_changed")
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionSuccess = nil
        connectionMessage = ""
        lastRawLog = ""
        
        Task {
            let res = await TuyaCloudManager.shared.testConnectionDirect(
                clientId: apiKey,
                secret: apiSecret,
                region: region
            )
            await MainActor.run {
                self.isTestingConnection = false
                self.connectionSuccess = res.success
                self.connectionMessage = res.message
                self.lastRawLog = res.rawJson
                self.connectedUID = res.uid
                
                self.store.db.environmentConfig.tuyaVerified = res.success
                if res.success {
                    self.store.db.environmentConfig.tuyaVerifiedAt = Date()
                    saveAll()
                } else {
                    self.store.db.environmentConfig.tuyaVerifiedAt = nil
                }
            }
        }
    }
    
    private func checkDevice() {
        isCheckingDevice = true
        deviceCheckMessage = ""
        checkedDevice = nil
        lastRawLog = ""
        
        Task {
            let res = await TuyaCloudManager.shared.checkDeviceDirect(
                deviceId: testDeviceID,
                clientId: apiKey,
                secret: apiSecret,
                region: region
            )
            await MainActor.run {
                self.isCheckingDevice = false
                self.checkedDevice = res.device
                self.deviceCheckMessage = res.message
                self.lastRawLog = res.rawJson
                
                if res.success, res.device != nil {
                    store.db.environmentConfig.tuyaDeviceID = testDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.save()
                }
            }
        }
    }
    
    private func toggleTestDevice(_ dev: TuyaCloudManager.DeviceInfo) {
        isTogglingDevice = true
        let targetState = !dev.isOn
        
        Task {
            do {
                let ok = try await TuyaCloudManager.shared.sendCommand(
                    deviceId: dev.id,
                    isOn: targetState,
                    deviceType: "",
                    clientId: apiKey,
                    secret: apiSecret,
                    region: region
                )
                await MainActor.run {
                    self.isTogglingDevice = false
                    if ok {
                        self.checkedDevice = TuyaCloudManager.DeviceInfo(
                            id: dev.id,
                            name: dev.name,
                            isOnline: dev.isOnline,
                            isOn: targetState,
                            switchCode: dev.switchCode,
                            category: dev.category
                        )
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isTogglingDevice = false
                    self.deviceCheckMessage = store.t(nl: "Schakelen mislukt: ", en: "Switch failed: ") + error.localizedDescription
                }
            }
        }
    }
    
    private func discoverUserDevices() {
        isDiscoveringDevices = true
        discoveredDevices = []
        
        Task {
            do {
                let list = try await TuyaCloudManager.shared.fetchUserDevices(
                    clientId: apiKey,
                    secret: apiSecret,
                    region: region
                )
                await MainActor.run {
                    self.isDiscoveringDevices = false
                    self.discoveredDevices = list
                    if list.isEmpty {
                        self.deviceCheckMessage = store.t(
                            nl: "Geen apparaten automatisch gevonden via account-link. Voer hierboven het Stekker Device ID in vanuit de Smart Life app.",
                            en: "No devices found automatically. Enter the Plug Device ID above from the Smart Life app."
                        )
                    } else {
                        let gen = UINotificationFeedbackGenerator()
                        gen.notificationOccurred(.success)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isDiscoveringDevices = false
                    self.deviceCheckMessage = error.localizedDescription
                }
            }
        }
    }
}


typealias TuyaCredentialsSheet = TuyaSetupWizardSheet



// MARK: - RASPBERRY PI LAB HUB SETTINGS SHEET
struct PiLabHubSettingsSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var hubIP: String = ""
    @State private var hubPort: String = "8088"
    @State private var isTesting: Bool = false
    @State private var testResult: String? = nil
    @State private var isSuccess: Bool = false
    @State private var hubStorageLabel: String? = nil
    @State private var hubStorageFreeGb: Double? = nil
    @State private var hubStorageTotalGb: Double? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                // Header & Info
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill((store.piHubStatusOnline ? Color.green : Color.orange).opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "cpu.fill")
                                    .font(.title3)
                                    .foregroundColor(store.piHubStatusOnline ? Color.green : Color.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Raspberry Pi 24/7 Lab Hub", en: "Raspberry Pi 24/7 Lab Hub"))
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                                Text(store.t(nl: "100% Lokale Hardware Bridge & Autopilot", en: "100% Local Hardware Bridge & Autopilot"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        
                        Text(store.t(
                            nl: "Je Raspberry Pi draait 24/7 zelfstandig. Zelfs als je iPhone leeg is of als je buiten de deur bent, blijven je ventilatie, kweeklampen en luchtbevochtiger exact volgens schema schakelen over je eigen lokale Wi-Fi.",
                            en: "Your Raspberry Pi runs 24/7 autonomously. Even if your iPhone is powered off or you are away from home, your ventilation, grow lights and humidifier will switch precisely on schedule over your local Wi-Fi."
                        ))
                        .font(.footnote)
                        .foregroundColor(MycoTheme.textSecondary)
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
                
                // Network settings
                Section(header: Text(store.t(nl: "Netwerkadres Hub", en: "Hub Network Address"))) {
                    HStack {
                        Text(store.t(nl: "IP Adres", en: "IP Address"))
                            .foregroundColor(.white)
                        Spacer()
                        TextField("192.168.50.115", text: $hubIP)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(MycoTheme.blue)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    HStack {
                        Text(store.t(nl: "Poort", en: "Port"))
                            .foregroundColor(.white)
                        Spacer()
                        TextField("8088", text: $hubPort)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(MycoTheme.blue)
                            .keyboardType(.numberPad)
                    }
                    
                    // Quick Preset Buttons
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            hubIP = "192.168.50.115"
                            hubPort = "8088"
                        } label: {
                            Text(store.t(nl: "🍓 Raspberry Pi Lab Hub (192.168.50.115)", en: "🍓 Raspberry Pi Lab Hub (192.168.50.115)"))
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.green)
                        }
                        .buttonStyle(.borderless)
                        
                        Button {
                            hubIP = "192.168.1.100"
                            hubPort = "8088"
                        } label: {
                            Text(store.t(nl: "🏠 Standaard LAN IP (192.168.1.100)", en: "🏠 Default LAN IP (192.168.1.100)"))
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.blue)
                        }
                        .buttonStyle(.borderless)
                        
                        Button {
                            hubIP = "127.0.0.1"
                            hubPort = "8088"
                        } label: {
                            Text(store.t(nl: "💻 Localhost (127.0.0.1)", en: "💻 Localhost (127.0.0.1)"))
                                .font(.caption.bold())
                                .foregroundColor(Color.green)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
                
                // Live Connection Test
                Section(header: Text(store.t(nl: "Verbindingstest", en: "Connection Test"))) {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "bolt.horizontal.fill")
                            }
                            Text(store.t(nl: "Test Verbinding met Pi Hub", en: "Test Connection to Pi Hub"))
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .disabled(isTesting)
                    
                    if let result = testResult {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isSuccess ? Color.green : Color.red)
                            Text(result)
                                .font(.caption)
                                .foregroundColor(isSuccess ? Color.green : Color.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // USB Flash Storage Info
                if let freeGb = hubStorageFreeGb, let totalGb = hubStorageTotalGb {
                    Section(header: Text(store.t(nl: "USB Opslag (Pi-Storage)", en: "USB Storage (Pi-Storage)"))) {
                        HStack(spacing: 12) {
                            Image(systemName: "externaldrive.fill")
                                .font(.title3)
                                .foregroundColor(Color.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hubStorageLabel ?? "Pi-Storage")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(String(format: "%.1f GB vrij van %.1f GB • Systeemdata & logs draaien op USB", freeGb, totalGb))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                            Text(store.t(nl: "Gekoppeld", en: "Mounted"))
                                .font(.caption2.bold())
                                .foregroundColor(Color.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                }
                
                // Central Database & Main Server Section
                Section(header: Text(store.t(nl: "Centrale MycoLabs Server & Database (Main)", en: "Central MycoLabs Server & Database (Main)"))) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "server.rack")
                                .font(.title3)
                                .foregroundColor(MycoTheme.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Pi Fungeert als Main & Server", en: "Pi Acts as Main & Server"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.t(
                                    nl: "Alle labdata (batches, genetica, voorraad en schema's) worden 24/7 opgeslagen op de Pi USB-stick. iPhones synchroniseren direct met de Pi.",
                                    en: "All lab data (batches, genetics, stash, and schedules) are stored 24/7 on the Pi USB stick. iPhones sync directly with the Pi."
                                ))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        
                        Divider().background(MycoTheme.border)
                        
                        if let lastSync = store.piServerDbLastSync {
                            HStack {
                                Text(store.t(nl: "Laatste Pi Database Sync:", en: "Last Pi Database Sync:"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                Spacer()
                                Text(lastSync.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption.bold())
                                    .foregroundColor(Color.green)
                            }
                        }
                        
                        if !store.piServerDbStatusMessage.isEmpty {
                            Text(store.piServerDbStatusMessage)
                                .font(.caption2)
                                .foregroundColor(MycoTheme.blue)
                        }
                        
                        HStack(spacing: 10) {
                            Button {
                                Task {
                                    await store.syncCentralDatabaseWithPi(forcePush: false)
                                }
                            } label: {
                                HStack {
                                    if store.isPiServerDbSyncing {
                                        ProgressView().scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                    }
                                    Text(store.t(nl: "Nu Syncen", en: "Sync Now"))
                                }
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(MycoTheme.blue)
                                .cornerRadius(8)
                            }
                            .disabled(store.isPiServerDbSyncing)
                            
                            Button {
                                Task {
                                    await store.pushCentralDatabaseToPi()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                    Text(store.t(nl: "Upload naar Pi", en: "Upload to Pi"))
                                }
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(8)
                            }
                            .disabled(store.isPiServerDbSyncing)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Connected Smart Hardware
                Section(header: Text(store.t(nl: "Lokale Hardware Stekkers", en: "Local Hardware Plugs"))) {
                    ForEach(store.db.smartDevices) { dev in
                        HStack {
                            Image(systemName: dev.deviceType == "Light" ? "lightbulb.fill" : (dev.deviceType == "Humidifier" ? "drop.fill" : "wind"))
                                .foregroundColor(dev.isOn ? Color.green : Color.gray)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dev.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text("ID: \(dev.tuyaDeviceID.isEmpty ? "Geen" : dev.tuyaDeviceID) • \(dev.isOn ? "AAN" : "UIT")")
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                            Circle()
                                .fill(dev.isOn ? Color.green : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                // Hub Beheer & Veilig Uitschakelen
                Section(header: Text(store.t(nl: "Hub Stroom- & Systeembeheer", en: "Hub Power & System Management")),
                        footer: Text(store.t(
                            nl: "Gebruik 'Veilig Uitschakelen' voordat je de stekker uit het stopcontact haalt of de Pi verplaatst om SD-kaart corruptie te voorkomen.",
                            en: "Use 'Safe Power Off' before unplugging or moving the Pi to prevent SD card corruption."
                        ))) {
                    Button(role: .destructive) {
                        Task {
                            _ = await store.safeShutdownPiHub()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "power")
                                .foregroundColor(.red)
                            Text(store.t(nl: "Hub Veilig Uitschakelen (Power Off)", en: "Safe Hub Power Off"))
                                .bold()
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    
                    Button {
                        Task {
                            _ = await store.safeRebootPiHub()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(MycoTheme.amber)
                            Text(store.t(nl: "Hub Herstarten (Reboot)", en: "Reboot Hub"))
                                .foregroundColor(MycoTheme.amber)
                            Spacer()
                        }
                    }
                }
                
                // Architecture explanation
                Section(header: Text(store.t(nl: "Waarom Geen Cloud Meer?", en: "Why No Cloud Needed?"))) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(store.t(nl: "0% Afhankelijkheid van Tuya Cloud", en: "0% Dependency on Tuya Cloud"), systemImage: "checkmark.shield.fill")
                            .font(.caption.bold())
                            .foregroundColor(Color.green)
                        Text(store.t(
                            nl: "De Raspberry Pi praat direct met de stekkers over je lokale router. Geen betaalde accounts, geen proefperiodes die aflopen en geen internetstoringen die je kweek stilleggen.",
                            en: "The Raspberry Pi speaks directly to the smart plugs via your local router. No paid accounts, no expiring trials, and no cloud outages stopping your grow."
                        ))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                        
                        Divider().background(MycoTheme.border)
                        
                        Label(store.t(nl: "Bediening Buitenshuis (4G/5G)", en: "Remote Control Away From Home"), systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                        Text(store.t(
                            nl: "Installeer gratis Tailscale op je iPhone en Raspberry Pi om overal ter wereld realtime beelden en bediening te hebben zonder poorten open te zetten.",
                            en: "Install free Tailscale on your iPhone and Raspberry Pi to get real-time video and controls anywhere in the world without opening router ports."
                        ))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Raspberry Pi Lab Hub", en: "Raspberry Pi Lab Hub"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(nl: "Sluit", en: "Close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t(nl: "Bewaar", en: "Save")) {
                        saveSettings()
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                hubIP = store.db.environmentConfig.effectivePiHubIP
                hubPort = "\(store.db.environmentConfig.effectivePiHubPort)"
                testConnection()
            }
        }
    }
    
    private func saveSettings() {
        store.db.environmentConfig.piHubIP = hubIP.trimmingCharacters(in: .whitespacesAndNewlines)
        if let p = Int(hubPort.trimmingCharacters(in: .whitespacesAndNewlines)), p > 0 {
            store.db.environmentConfig.piHubPort = p
        }
        store.save()
        Task {
            _ = await store.checkPiHubOnline()
            await store.syncSchedulesToPiHub()
            await store.syncDevicesFromPiHub()
        }
    }
    
    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            let targetIp = hubIP.trimmingCharacters(in: .whitespacesAndNewlines)
            let targetPort = Int(hubPort.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 8088
            
            for ep in ["status", "devices"] {
                guard let url = URL(string: "http://\(targetIp):\(targetPort)/\(ep)") else { continue }
                var req = URLRequest(url: url)
                req.timeoutInterval = 2.5
                do {
                    let (data, resp) = try await URLSession.shared.data(for: req)
                    if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                        let deviceList = json["devices"] as? [Any]
                        let deviceDict = json["devices"] as? [String: Any]
                        let deviceCount = deviceList?.count ?? deviceDict?.count ?? 0
                        let hubName = json["hub"] as? String ?? (deviceCount > 0 ? "MycoLabs LAN Bridge (\(deviceCount) stekkers)" : "Pi Hub")
                        var parsedLabel: String? = nil
                        var parsedTotal: Double? = nil
                        var parsedFree: Double? = nil
                        var storageStr = ""
                        if let storage = json["storage"] as? [String: Any],
                           let mounted = storage["mounted"] as? Bool, mounted,
                           let freeGb = storage["free_gb"] as? Double,
                           let totalGb = storage["total_gb"] as? Double {
                            let label = storage["label"] as? String ?? "Pi-Storage"
                            parsedLabel = label
                            parsedTotal = totalGb
                            parsedFree = freeGb
                            storageStr = " • 💾 \(label): \(String(format: "%.1f", freeGb)) GB vrij"
                        }
                        await MainActor.run {
                            self.isTesting = false
                            self.isSuccess = true
                            self.hubStorageLabel = parsedLabel
                            self.hubStorageTotalGb = parsedTotal
                            self.hubStorageFreeGb = parsedFree
                            self.testResult = "✅ Verbinding 100% OK! (\(hubName) online\(storageStr))"
                            self.store.piHubStatusOnline = true
                        }
                        return
                    }
                } catch {
                    // Try next endpoint
                }
            }
            
            await MainActor.run {
                self.isTesting = false
                self.isSuccess = false
                self.testResult = "❌ Geen verbinding met Pi Hub (\(targetIp):\(targetPort))"
                self.store.piHubStatusOnline = false
            }
        }
    }
}

// MARK: - RASPBERRY PI LAB HUB 24/7 LOG SHEET
struct PiLabHubLogSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing: Bool = false
    
    var body: some View {
        NavigationStack {
            contentView
                .background(MycoTheme.bg.ignoresSafeArea())
                .navigationTitle(store.t(nl: "Pi Hub 24/7 Logboek", en: "Pi Hub 24/7 Activity Log"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(store.t(nl: "Sluit", en: "Close")) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            refreshLogs()
                        } label: {
                            if isRefreshing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshing)
                    }
                }
                .onAppear {
                    refreshLogs()
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if store.piHubLogs.isEmpty {
            emptyView
        } else {
            logListView
        }
    }
    
    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 48))
                .foregroundColor(MycoTheme.textSecondary.opacity(0.5))
            Text(store.t(nl: "Nog geen Pi Hub logs beschikbaar", en: "No Pi Hub logs available yet"))
                .font(.headline)
                .foregroundColor(.white)
            Text(store.t(
                nl: "Zodra de Pi Autopilot kweeklampen of ventilatie schakelt, verschijnen de gebeurtenissen direct hier.",
                en: "As soon as Pi Autopilot switches grow lights or ventilation, events will appear here."
            ))
            .font(.caption)
            .foregroundColor(MycoTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            
            Button {
                refreshLogs()
            } label: {
                Label(store.t(nl: "Vernieuwen", en: "Refresh"), systemImage: "arrow.clockwise")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(MycoTheme.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var logListView: some View {
        List {
            Section(header: Text(store.t(nl: "24/7 Autonome Schakelgeschiedenis", en: "24/7 Autonomous Switch History"))) {
                ForEach(store.piHubLogs) { item in
                    PiLabHubLogRow(item: item)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private func refreshLogs() {
        isRefreshing = true
        Task {
            await store.fetchPiHubLogs()
            await MainActor.run { isRefreshing = false }
        }
    }
}
// MARK: - RASPBERRY PI LAB HUB 24/7 LOG ROW
struct PiLabHubLogRow: View {
    let item: PiHubLogEntry

    private var activeColor: Color {
        item.state ? Color.green : Color.gray
    }

    var body: some View {
        HStack(spacing: 12) {
            statusBadge
            detailsSection
            Spacer()
            timestampSection
        }
        .padding(.vertical, 2)
        .listRowBackground(MycoTheme.card)
    }

    @ViewBuilder
    private var statusBadge: some View {
        ZStack {
            Circle()
                .fill(activeColor.opacity(0.18))
                .frame(width: 36, height: 36)
            Image(systemName: iconForDeviceName(item.device))
                .font(.caption)
                .foregroundColor(activeColor)
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(item.device)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(item.state ? "AAN" : "UIT")
                    .font(.caption2.bold())
                    .foregroundColor(activeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(activeColor.opacity(0.15))
                    .cornerRadius(4)
            }
            
            Text(item.trigger)
                .font(.caption)
                .foregroundColor(MycoTheme.textSecondary)
        }
    }

    @ViewBuilder
    private var timestampSection: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formatTimestamp(item.timestamp))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            HStack(spacing: 3) {
                Circle().fill(Color.green).frame(width: 5, height: 5)
                Text("Wi-Fi LAN")
                    .font(.system(size: 9))
                    .foregroundColor(Color.green)
            }
        }
    }

    private func iconForDeviceName(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("lamp") || n.contains("light") { return "lightbulb.fill" }
        if n.contains("bevocht") || n.contains("humid") { return "drop.fill" }
        if n.contains("vent") || n.contains("fan") { return "wind" }
        return "powerplug.fill"
    }

    private func formatTimestamp(_ ts: String) -> String {
        if ts.contains(" ") {
            let parts = ts.split(separator: " ")
            if parts.count >= 2 { return String(parts[1]) }
        }
        return ts
    }
}

