//
//  MycoCleanroomAIIntentEngine.swift
//  MycoLab
//
//  On-Device Natural Language Understanding (NLU) & Fuzzy Intent AI Engine:
//  - Handles incomplete, colloquial, and "sloppy" cleanroom voice input
//  - Uses fuzzy semantic token analysis, Dutch/English colloquial duration parsing,
//    and mycology-specific contextual slot filling
//  - Provides intelligent defaults when parameters are omitted (e.g. "autoclaaf" -> 90 min)
//  - Categorizes lab notes automatically (Contamination alert, Inoculation, Pinning, Harvest)
//  - Operates 100% offline inside the sterile cleanroom with zero latency
//

import Foundation
import NaturalLanguage
import SwiftUI

// MARK: - Recognized Cleanroom Intent
enum CleanroomIntent: Equatable {
    case startTimer(minutes: Int, title: String, isDefaultFallback: Bool)
    case stopTimer
    case queryClimate(aspect: ClimateQueryAspect)
    case controlDevice(deviceType: String, turnOn: Bool)
    case stopAllDevices
    case logHarvest(grams: Double)
    case togglePinningTrigger(enable: Bool)
    case controlCameraSleep(putToSleep: Bool?)
    case queryCameraCapabilities
    case logSterileNote(category: SterileNoteCategory, cleanSummary: String)
    case queryBatches
    case askAdvisor(topic: MycoAdvisorTopic, question: String)
    case requestHelp
    case conversationalGreeting
    case unhandled(rawText: String)
}

enum MycoAdvisorTopic: Equatable {
    case pinningConditions
    case colonizationConditions
    case fruitingConditions
    case substrateWaterRatio(coirGrams: Double)
    case contaminationCheck(type: String)
    case harvestTiming
    case generalAdvice(query: String)
}

enum ClimateQueryAspect: Equatable {
    case general
    case temperature
    case humidity
    case vpd
    case dewPoint
}

enum SterileNoteCategory: String, CaseIterable, Equatable {
    case contamination = "Contamination Alert"
    case inoculation = "Inoculation / Transfer"
    case pinning = "Primordia / Pinning"
    case harvest = "Harvest / Flush"
    case general = "Sterile Observation"
    
    var icon: String {
        switch self {
        case .contamination: return "exclamationmark.triangle.fill"
        case .inoculation: return "arrow.triangle.swap"
        case .pinning: return "sparkles"
        case .harvest: return "basket.fill"
        case .general: return "pencil.and.list.clipboard"
        }
    }
    
    var color: Color {
        switch self {
        case .contamination: return MycoTheme.red
        case .inoculation: return MycoTheme.blue
        case .pinning: return Color.cyan
        case .harvest: return MycoTheme.green
        case .general: return MycoTheme.textSecondary
        }
    }
}

// MARK: - Smart NLU Engine
final class MycoCleanroomAIIntentEngine {
    static let shared = MycoCleanroomAIIntentEngine()
    
    private init() {}
    
    // MARK: - Main Intent Classification
    func interpret(spokenText: String) -> CleanroomIntent {
        let cleaned = spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return .unhandled(rawText: spokenText) }
        
        let lower = cleaned.lowercased()
        
        // 0. Greeting & Wake Words
        if isGreeting(lower) {
            return .conversationalGreeting
        }
        
        // 1. Help Query
        if lower.contains("help") || lower.contains("wat kan ik zeggen") || lower.contains("welke commando") || lower.contains("wat snap je") {
            return .requestHelp
        }
        
        // 2. Stop Timer
        if (lower.contains("stop") || lower.contains("annuleer") || lower.contains("uit")) && lower.contains("timer") {
            return .stopTimer
        }
        
        // 3. Stop All Devices (Emergency Stop)
        if (lower.contains("alles uit") || lower.contains("stop alles") || lower.contains("alle apparaten uit") || lower.contains("noodstop")) {
            return .stopAllDevices
        }
        
        // 3b. Pinning Induction / Cold Shock Trigger
        if lower.contains("pinning") || lower.contains("koudeval") || lower.contains("primordia trigger") {
            if lower.contains("stop") || lower.contains("deactiveer") || lower.contains("uit") {
                return .togglePinningTrigger(enable: false)
            } else if lower.contains("start") || lower.contains("activeer") || lower.contains("trigger") || lower.contains("shock") || lower.contains("aan") {
                return .togglePinningTrigger(enable: true)
            }
        }
        
        // 3c. Direct Hands-Free Harvest Logging
        if (lower.contains("oogst") || lower.contains("harvest") || lower.contains("pluk") || lower.contains("geplukt")) {
            if let grams = extractHarvestGrams(from: lower) {
                return .logHarvest(grams: grams)
            }
        }
        
        // 3d. Camera Screen Sleep / OLED Standby Control & Device Adaptation
        if let camIntent = interpretCameraScreenSleep(from: lower) {
            return camIntent
        }
        
        // 4. Timer & Sterilization Presets (With Fuzzy & Omission Handling)
        if let timerIntent = interpretTimerIntent(from: lower) {
            return timerIntent
        }
        
        // 5. Hardware Device Toggles (With Fuzzy Aliases)
        if let deviceIntent = interpretDeviceIntent(from: lower) {
            return deviceIntent
        }
        
        // 6. Climate & Telemetry Questions
        if let climateIntent = interpretClimateQuery(from: lower) {
            return climateIntent
        }
        
        // 7. Batch & Project Queries
        if let batchIntent = interpretBatchQuery(from: lower) {
            return batchIntent
        }
        
        // 8. Advisor & Mycology Questions (Substrate ratios, pinning, sterilization, harvest)
        if let advisorIntent = interpretAdvisorQuery(from: lower) {
            return advisorIntent
        }
        
        // 9. Smart Sterile Journaling / Observations
        if let noteIntent = interpretSterileNote(from: cleaned, lower: lower) {
            return noteIntent
        }
        
        return .unhandled(rawText: spokenText)
    }
    

    // MARK: - Harvest Grams Extractor
    private func extractHarvestGrams(from text: String) -> Double? {
        // Match expressions like "250 gram", "125.5g", "300 gr", "oogst 450"
        let pattern = #"(\d+(?:[.,]\d+)?)\s*(?:gram|gr|g\b)?"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in matches where match.numberOfRanges > 1 {
                if let range = Range(match.range(at: 1), in: text) {
                    let valStr = text[range].replacingOccurrences(of: ",", with: ".")
                    if let val = Double(valStr), val > 0 && val <= 25000 {
                        return val
                    }
                }
            }
        }
        return nil
    }

    // MARK: - 1. Timer Intent with Fuzzy Durations & Mycology Presets
    private func interpretTimerIntent(from lower: String) -> CleanroomIntent? {
        let hasTimerWord = lower.contains("timer") || lower.contains("wekker") || lower.contains("alarm") || lower.contains("zet") || lower.contains("start")
        let hasMycoPresetWord = lower.contains("autoclaaf") || lower.contains("snelkookpan") || lower.contains("pressure cooker") ||
            lower.contains("agar") || lower.contains("graan") || lower.contains("broed") || lower.contains("steriliseer") ||
            lower.contains("sterilisatie") || lower.contains("scalpel") || lower.contains("mesje") || lower.contains("uv")
        
        guard hasTimerWord || hasMycoPresetWord else { return nil }
        
        // Check for specific durations first (numbers, words like 'half uur', 'kwartier')
        let parsedMinutes = extractFuzzyMinutes(from: lower)
        
        // Check presets with smart defaults if user forgot or omitted the duration!
        if lower.contains("autoclaaf") || lower.contains("snelkookpan") || lower.contains("pressure cooker") || (lower.contains("graan") && lower.contains("steriliseer")) {
            let minutes = parsedMinutes ?? 90
            let isDefault = (parsedMinutes == nil)
            return .startTimer(minutes: minutes, title: "Autoclaaf Sterilisatie (15 PSI)", isDefaultFallback: isDefault)
        }
        
        if lower.contains("agar") {
            let minutes = parsedMinutes ?? 45
            let isDefault = (parsedMinutes == nil)
            return .startTimer(minutes: minutes, title: "Agar Media Sterilisatie", isDefaultFallback: isDefault)
        }
        
        if lower.contains("vloeibaar") || lower.contains("lc") || lower.contains("liquid culture") {
            let minutes = parsedMinutes ?? 25
            let isDefault = (parsedMinutes == nil)
            return .startTimer(minutes: minutes, title: "Vloeibare Cultuur Sterilisatie", isDefaultFallback: isDefault)
        }
        
        if lower.contains("scalpel") || lower.contains("mesje") || lower.contains("afkoelen") {
            let minutes = parsedMinutes ?? 1
            let isDefault = (parsedMinutes == nil)
            return .startTimer(minutes: minutes, title: "Scalpel Afkoeltijd", isDefaultFallback: isDefault)
        }
        
        if lower.contains("uv") || lower.contains("uvc") || lower.contains("desinfect") {
            let minutes = parsedMinutes ?? 15
            let isDefault = (parsedMinutes == nil)
            return .startTimer(minutes: minutes, title: "UV-C Sterilisatie Cyclus", isDefaultFallback: isDefault)
        }
        
        // If a general timer word was mentioned with an extracted duration
        if let minutes = parsedMinutes {
            return .startTimer(minutes: minutes, title: "Lab Timer (\(minutes)m)", isDefaultFallback: false)
        }
        
        return nil
    }
    
    // MARK: - Fuzzy Duration Parser (Handles Dutch colloquial terms + digits)
    private func extractFuzzyMinutes(from text: String) -> Int? {
        // Colloquial Dutch time expressions
        if text.contains("kwartier") || text.contains("kwartiertje") {
            if text.contains("drie kwartier") { return 45 }
            return 15
        }
        if text.contains("half uur") || text.contains("half uurtje") { return 30 }
        if text.contains("anderhalf uur") { return 90 }
        if text.contains("twee uur") || text.contains("2 uur") { return 120 }
        if text.contains("drie uur") || text.contains("3 uur") { return 180 }
        if text.contains("uurtje") || (text.contains("1 uur") || text.contains("een uur")) { return 60 }
        if text.contains("tien minuten") || text.contains("10 minuutjes") { return 10 }
        if text.contains("vijf minuten") || text.contains("5 minuutjes") { return 5 }
        if text.contains("twintig minuten") { return 20 }
        
        // Regex: e.g. "90 minuten", "45 min", "15m"
        let pattern = #"(\d+)\s*(?:minuten|minuut|min|m\b)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: text),
           let val = Int(text[range]) {
            return val
        }
        
        // Standalone numbers: "timer 90", "zet 45"
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        for w in words {
            let digitsOnly = w.filter { $0.isNumber }
            if let n = Int(digitsOnly), n > 0 && n <= 360 {
                return n
            }
        }
        
        return nil
    }
    
    // MARK: - 2. Device Control Intent (Handles slang, partial sentences, aliases)
    private func interpretDeviceIntent(from lower: String) -> CleanroomIntent? {
        let isTurnOn = lower.contains("aan") || lower.contains("on") || lower.contains("start") || lower.contains("activeer") || lower.contains("in")
        let isTurnOff = lower.contains("uit") || lower.contains("off") || lower.contains("stop") || lower.contains("deactiveer")
        
        // If neither on nor off is specified, but device is named with "mag/kan": default to turn on
        let effectiveState = isTurnOff ? false : (isTurnOn ? true : true)
        
        // Humidifier aliases: bevochtiger, mist, nevel, fogger, humidifier, sproeier
        if lower.contains("bevochtig") || lower.contains("mist") || lower.contains("nevel") || lower.contains("fogger") || lower.contains("sproei") {
            return .controlDevice(deviceType: "Humidifier", turnOn: effectiveState)
        }
        
        // Exhaust Fan aliases: fan, afzuiging, afzuig, ventilatie, ventilator, fae, blazer, luchtverversing
        if lower.contains("fan") || lower.contains("afzuig") || lower.contains("ventil") || lower.contains("fae") || lower.contains("blazer") || lower.contains("lucht") {
            return .controlDevice(deviceType: "ExhaustFan", turnOn: effectiveState)
        }
        
        // Light aliases: lamp, licht, led, verlichting, groeilamp
        if lower.contains("lamp") || lower.contains("licht") || lower.contains("led") || lower.contains("verlichting") {
            return .controlDevice(deviceType: "Light", turnOn: effectiveState)
        }
        
        // Heater aliases: kachel, verwarm, warmte, warmtemat, matje, thermostaat
        if lower.contains("kachel") || lower.contains("verwarm") || lower.contains("warmte") || lower.contains("mat") {
            return .controlDevice(deviceType: "Heater", turnOn: effectiveState)
        }
        
        return nil
    }
    
    // MARK: - 3. Climate Queries (Handles natural questions)
    private func interpretClimateQuery(from lower: String) -> CleanroomIntent? {
        let isQuestionOrInquiry = lower.contains("hoe") || lower.contains("wat") || lower.contains("status") ||
            lower.contains("is het") || lower.contains("klimaat") || lower.contains("moet ik") || lower.contains("vertel")
        
        let hasTemp = lower.contains("warm") || lower.contains("koud") || lower.contains("temperatuur") || lower.contains("graden") || lower.contains("temp")
        let hasHumidity = lower.contains("vochtig") || lower.contains("luchtvochtigheid") || lower.contains("rv") || lower.contains("droog") || lower.contains("sproeien")
        let hasVPD = lower.contains("vpd") || lower.contains("dampdruk")
        let hasDewPoint = lower.contains("dauwpunt") || lower.contains("condensatie") || lower.contains("dau")
        
        if hasVPD {
            return .queryClimate(aspect: .vpd)
        }
        if hasDewPoint {
            return .queryClimate(aspect: .dewPoint)
        }
        if hasTemp && !hasHumidity {
            return .queryClimate(aspect: .temperature)
        }
        if hasHumidity && !hasTemp {
            return .queryClimate(aspect: .humidity)
        }
        if (hasTemp && hasHumidity) || isQuestionOrInquiry || lower.contains("klimaat") || lower.contains("milieu") {
            return .queryClimate(aspect: .general)
        }
        
        return nil
    }
    
    // MARK: - 4. Batch Queries
    private func interpretBatchQuery(from lower: String) -> CleanroomIntent? {
        if lower.contains("batch") || lower.contains("potten") || lower.contains("bakken") || lower.contains("projecten") || lower.contains("kweek") {
            if lower.contains("hoeveel") || lower.contains("welke") || lower.contains("actief") || lower.contains("wat staat er") {
                return .queryBatches
            }
        }
        return nil
    }
    
    // MARK: - 5. Advisor Queries & Substrate Calculator
    private func interpretAdvisorQuery(from lower: String) -> CleanroomIntent? {
        let isQuestion = lower.contains("wat") || lower.contains("hoe") || lower.contains("wanneer") || lower.contains("advies") || lower.contains("recept") || lower.contains("waarom") || lower.contains("is het") || lower.contains("zou ik") || lower.contains("moet ik")
        
        // Substrate & CVG Water Calculator
        if (lower.contains("water") || lower.contains("recept") || lower.contains("verhouding") || lower.contains("field capacity")) && (lower.contains("coir") || lower.contains("kokos") || lower.contains("substraat") || lower.contains("cvg")) {
            var grams = 650.0
            let words = lower.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            for word in words {
                if let val = Double(word), val >= 50 && val <= 5000 {
                    grams = val
                    break
                }
            }
            return .askAdvisor(topic: .substrateWaterRatio(coirGrams: grams), question: lower)
        }
        
        // Pinning Advice
        if lower.contains("pinning") || lower.contains("primordia") || lower.contains("pinheads") || (lower.contains("pinnen") && !lower.contains("koken")) {
            return .askAdvisor(topic: .pinningConditions, question: lower)
        }
        
        // Kolonisatie & Incubatie Advice
        if lower.contains("kolonisatie") || lower.contains("koloniseer") || lower.contains("incubatie") || (lower.contains("mycelium") && (lower.contains("groei") || lower.contains("temperatuur"))) {
            return .askAdvisor(topic: .colonizationConditions, question: lower)
        }
        
        // Fruiting / Vruchtvorming Advice
        if lower.contains("fruiting") || lower.contains("vruchtvorming") || lower.contains("paddenstoelen kweken") {
            return .askAdvisor(topic: .fruitingConditions, question: lower)
        }
        
        // Contamination Questions
        if (isQuestion || lower.contains("behandel") || lower.contains("help") || lower.contains("herken")) && (lower.contains("trichoderma") || lower.contains("groene schimmel") || lower.contains("cobweb") || lower.contains("natrot") || lower.contains("bacterie")) {
            let moldType = lower.contains("groen") || lower.contains("tricho") ? "trichoderma" : (lower.contains("cobweb") ? "cobweb" : "algemeen")
            return .askAdvisor(topic: .contaminationCheck(type: moldType), question: lower)
        }
        
        // Harvest Timing
        if lower.contains("wanneer oogsten") || lower.contains("oogsttijd") || lower.contains("plukken") || lower.contains("vliesje") || lower.contains("veil") {
            return .askAdvisor(topic: .harvestTiming, question: lower)
        }
        
        return nil
    }
    
    // MARK: - 6. Smart Sterile Note & Auto-Categorization
    private func interpretSterileNote(from raw: String, lower: String) -> CleanroomIntent? {
        // Detect Contamination
        let contamKeywords = ["besmet", "trichoderma", "groene schimmel", "gecontamineerd", "schimmel gezien", "stinkt", "bacterieel", "natrot", "weggegooid"]
        for kw in contamKeywords {
            if lower.contains(kw) {
                return .logSterileNote(category: .contamination, cleanSummary: raw)
            }
        }
        
        // Detect Inoculation / Transfer
        let inocKeywords = ["overgezet", "geënt", "geinoculeerd", "geïnoculeerd", "transfer", "isolatie", "van plaat", "naar lc", "naar pot", "gesneden"]
        for kw in inocKeywords {
            if lower.contains(kw) {
                return .logSterileNote(category: .inoculation, cleanSummary: raw)
            }
        }
        
        // Detect Pinning / Primordia
        let pinKeywords = ["pins", "primordia", "paddenstoeltjes", "knoppen", "pinhead", "knopjes"]
        for kw in pinKeywords {
            if lower.contains(kw) {
                return .logSterileNote(category: .pinning, cleanSummary: raw)
            }
        }
        
        // Detect Harvest
        let harvestKeywords = ["oogst", "geoogst", "flush", "geplukt", "plukken", "sporenprint"]
        for kw in harvestKeywords {
            if lower.contains(kw) {
                return .logSterileNote(category: .harvest, cleanSummary: raw)
            }
        }
        
        // Explicit log command: "noteer ...", "schrijf op ...", "log ...", "notitie ..."
        if lower.contains("noteer") || lower.contains("schrijf") || lower.contains("log") || lower.contains("onthoud") || lower.contains("notitie") {
            var clean = raw
            for prefix in ["noteer", "schrijf op", "schrijf", "log", "onthoud", "notitie"] {
                if let r = clean.range(of: prefix, options: .caseInsensitive) {
                    clean.removeSubrange(clean.startIndex..<r.upperBound)
                    clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            let summary = clean.isEmpty ? raw : clean
            return .logSterileNote(category: .general, cleanSummary: summary)
        }
        
        return nil
    }
    
    private func interpretCameraScreenSleep(from lower: String) -> CleanroomIntent? {
        let mentionsCamera = lower.contains("camera") || lower.contains("cam") || lower.contains("kweekcamera")
        let mentionsScreen = lower.contains("scherm") || lower.contains("display") || lower.contains("beeld")
        let mentionsSleep = lower.contains("slaap") || lower.contains("sleep") || lower.contains("spaarstand") || lower.contains("dim") || lower.contains("blackout") || lower.contains("oled")
        let mentionsWake = lower.contains("wakker") || lower.contains("wake") || lower.contains("ontwaak")
        
        // Capability query: "heeft camera een scherm", "kan de camera slapen", "wat voor camera", "camera eigenschappen", "welke camera"
        if (mentionsCamera || mentionsScreen) && (lower.contains("heeft") || lower.contains("welk") || lower.contains("wat voor") || lower.contains("soort") || lower.contains("eigenschap") || lower.contains("display") || lower.contains("kan") || lower.contains("verbonden")) && !lower.contains("slaap") && !lower.contains("uit") && !lower.contains("dim") {
            return .queryCameraCapabilities
        }
        
        // Sleep commands: "sleep cam", "slaapstand camera", "scherm uit", "dim camerascherm", "doe het scherm van de camera uit"
        if (mentionsCamera && mentionsSleep) || (mentionsScreen && (lower.contains("uit") || lower.contains("donker") || lower.contains("zwart") || mentionsSleep)) {
            if mentionsWake {
                return .controlCameraSleep(putToSleep: false)
            }
            if lower.contains("aan") && !lower.contains("slaapstand aan") && !lower.contains("spaarstand aan") {
                return .controlCameraSleep(putToSleep: false)
            }
            return .controlCameraSleep(putToSleep: true)
        }
        
        // Wake commands: "wake camera", "scherm aan", "maak camera wakker", "haal camera uit slaapstand"
        if (mentionsCamera && mentionsWake) || (mentionsScreen && (lower.contains("aan") || lower.contains("activeer") || lower.contains("zichtbaar") || mentionsWake)) {
            return .controlCameraSleep(putToSleep: false)
        }
        
        return nil
    }
    
    private func isGreeting(_ lower: String) -> Bool {
        lower == "hallo mycolab" || lower == "hoi" || lower == "hey mycolab" || lower == "luister" || lower == "start"
    }
}
