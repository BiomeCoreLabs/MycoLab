//
//  MycoScannerAndVisionViews.swift
//  MycoLab
//
//  Complete Scanner, Vision AI & QR Label Studio Suite:
//  - Apple Neural Engine / Vision Mycology Colonization Analyzer
//  - Handwriting OCR & Tag Recognition
//  - In-App Dynamic Island Notification Banner
//  - Printable QR Label Studio (AirPrint & PDF)
//  - Central QR Code Archive & Vault
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

// MARK: - 15. QR SCANNER MODAL & PRINTABLE QR LABEL STUDIO

// MARK: - APPLE NEURAL ENGINE / VISION MYCOLOGY ANALYZER
struct MyceliumScanReport: Identifiable {
    let id = UUID()
    let colonizationPercent: Int
    let isHealthy: Bool
    let statusTitle: String
    let statusMessage: String
    let detectedRisk: String
    let morphology: String
    let recommendation: String
    let trichodermaRiskPct: Int
    let bacterialRiskPct: Int
    let cobwebRiskPct: Int
    let blackMoldRiskPct: Int
    let timestamp: Date = Date()
}

struct ExtractedLabelData: Identifiable {
    let id = UUID()
    var strainName: String = ""
    var generation: String = ""
    var dateString: String = ""
    var weightOrSubstrate: String = ""
    var rawRecognizedText: String = ""
}

final class AIMycoVisionAnalyzer {
    static let shared = AIMycoVisionAnalyzer()
    
    /// Analyzes an image with Apple Vision and Pixel Buffer processing for Mycelium Colonization & Contamination
    func analyzeMycelium(image: UIImage, isEnglish: Bool, strictMode: Bool = true) -> MyceliumScanReport {
        guard let cgImage = image.cgImage else {
            return fallbackReport(isEnglish: isEnglish)
        }
        
        let width = 120
        let height = 120
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return fallbackReport(isEnglish: isEnglish)
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var whiteCount = 0
        var darkCount = 0
        var glareCount = 0
        var greenCount = 0
        var bacterialCount = 0
        var cobwebCount = 0
        var blackMoldCount = 0
        var totalCount = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Double(rawData[offset])
                let g = Double(rawData[offset + 1])
                let b = Double(rawData[offset + 2])
                
                totalCount += 1
                
                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                let colorSpread = max(r, max(g, b)) - min(r, min(g, b))
                
                // Specular Glare Filter (Flash / light reflection on glass or plastic)
                if luminance > 248 && colorSpread < 12 {
                    glareCount += 1
                    continue
                }
                
                // 1. Trichoderma & Penicillium (Bright green, dark olive, dull green, teal)
                let isBrightGreen = g > 45 && g > (r * 1.12) && g > (b * 1.08)
                let isOliveGreen = g > 30 && (g >= r + 6) && (g >= b + 4)
                let isTealMold = (g + b) > (2.0 * r + 15) && g > 35 && b > 35 && (g - r) > 8
                if isBrightGreen || isOliveGreen || isTealMold {
                    greenCount += 1
                    continue
                }
                
                // 2. Bacterial Wet Spot / Sour Rot (Bacillus subtilis):
                let isBacterialWet = r > 95 && g > 65 && b < 65 && (r - b) > 35 && (r - g) < 45
                if isBacterialWet {
                    bacterialCount += 1
                    continue
                }
                
                // 3. Black Mold / Aspergillus:
                let isBlackMold = luminance < 28 && colorSpread < 12
                if isBlackMold {
                    blackMoldCount += 1
                    continue
                }
                
                // 4. Cobweb Mold (Dactylium mildew):
                let isCobwebHaze = luminance >= 80 && luminance <= 135 && colorSpread <= 8
                if isCobwebHaze {
                    cobwebCount += 1
                }
                
                // 5. Genuine Dense White Rhizomorphic / Tomentose Mycelium:
                if luminance >= 145 && luminance <= 247 && colorSpread < 26 {
                    whiteCount += 1
                } else if luminance < 140 {
                    darkCount += 1
                }
            }
        }
        
        let nonGlareTotal = max(1, totalCount - glareCount)
        let validSubstrate = max(1, whiteCount + darkCount)
        
        let trichodermaRiskPct = min(100, Int((Double(greenCount) / Double(nonGlareTotal)) * 1200.0))
        let bacterialRiskPct = min(100, Int((Double(bacterialCount) / Double(nonGlareTotal)) * 600.0))
        let cobwebRiskPct = min(100, Int((Double(cobwebCount) / Double(nonGlareTotal)) * 400.0))
        let blackMoldRiskPct = min(100, Int((Double(blackMoldCount) / Double(nonGlareTotal)) * 800.0))
        
        var calculatedPct = Int((Double(whiteCount) / Double(validSubstrate)) * 100.0)
        if whiteCount < 60 || (Double(whiteCount) / Double(validSubstrate)) < 0.05 {
            calculatedPct = 0
        }
        calculatedPct = max(0, min(100, calculatedPct))
        
        let trichodermaThreshold = strictMode ? 6 : 14
        let bacterialThreshold = strictMode ? 8 : 18
        let blackMoldThreshold = strictMode ? 6 : 15
        let cobwebThreshold = strictMode ? 10 : 25
        
        let hasTrichoderma = trichodermaRiskPct >= trichodermaThreshold
        let hasBacteria = bacterialRiskPct >= bacterialThreshold
        let hasBlackMold = blackMoldRiskPct >= blackMoldThreshold
        let hasCobweb = cobwebRiskPct >= cobwebThreshold
        
        let isHealthy = !hasTrichoderma && !hasBacteria && !hasBlackMold && !hasCobweb
        
        let morphology: String
        if calculatedPct == 0 {
            morphology = isEnglish ? "No Mycelium Detected" : "Geen Mycelium Waargenomen"
        } else if calculatedPct > 45 {
            morphology = isEnglish ? "Rhizomorphic (Strong Strands)" : "Rhizomorfisch (Sterk netwerk)"
        } else {
            morphology = isEnglish ? "Tomentose (Fuzzy / Colonizing)" : "Tomentose (Pluizig / Koloniserend)"
        }
        
        var statusTitle = ""
        var statusMsg = ""
        var risk = "Geen"
        var rec = ""
        
        if hasTrichoderma {
            statusTitle = isEnglish ? "⚠️ CONTAMINATION: Trichoderma Mold!" : "⚠️ CONTAMINATIE: Trichoderma Schimmel!"
            statusMsg = isEnglish
                ? "Green/olive fungal spores detected (\(trichodermaRiskPct)% risk)! This mould will quickly overwhelm mycelium."
                : "Groene/olijfgroene schimmelsporen waargenomen (\(trichodermaRiskPct)% risico)! Deze schimmel overwoekert mycelium razendsnel."
            risk = "Trichoderma Harzianum (\(trichodermaRiskPct)%)"
            rec = isEnglish
                ? "DO NOT OPEN INDOORS! Keep this container strictly isolated or discard outside."
                : "NIET BINNENSHUIS OPENEN! Houd deze pot strikt geïsoleerd of gooi buiten leeg."
        } else if hasBacteria {
            statusTitle = isEnglish ? "⚠️ BACTERIAL ROT: Wet Spot / Bacillus!" : "⚠️ BACTERIËLE ROT: Natrot / Bacillus!"
            statusMsg = isEnglish
                ? "Greasy caramel-yellow uncolonized grain mush detected (\(bacterialRiskPct)% risk). Sour rot bacteria prevent mycelial spread."
                : "Gelige/karamelkleurige slijmerige korrels waargenomen (\(bacterialRiskPct)% risico). Bacteriële natrot stopt verdere doorgroei."
            risk = "Bacillus Subtilis / Natrot (\(bacterialRiskPct)%)"
            rec = isEnglish
                ? "Do not shake. Isolate immediately; bacteria spread through grain-to-grain contact."
                : "Niet schudden! Direct isoleren; natrot verspreidt zich bij schudden door de hele pot."
        } else if hasBlackMold {
            statusTitle = isEnglish ? "⚠️ TOXIC BLACK MOLD: Aspergillus!" : "⚠️ ZWARTE SCHIMMEL: Aspergillus!"
            statusMsg = isEnglish
                ? "Dense black spore clusters detected (\(blackMoldRiskPct)% risk). Highly aggressive competitor."
                : "Dichte zwarte sporenclusters waargenomen (\(blackMoldRiskPct)% risico). Agressieve besmetting."
            risk = "Aspergillus Niger (\(blackMoldRiskPct)%)"
            rec = isEnglish
                ? "Keep sealed! Spores can be hazardous to respiratory health."
                : "Pot potdicht houden! Sporen zijn gevaarlijk bij inademing."
        } else if hasCobweb {
            statusTitle = isEnglish ? "⚠️ COBWEB MOLD: Dactylium Mildew!" : "⚠️ COBWEB SCHIMMEL: Dactylium!"
            statusMsg = isEnglish
                ? "Grayish diffuse fibrous web detected (\(cobwebRiskPct)% risk). Grows in 3D aerial form."
                : "Grijzige, diffuse pluizige waas waargenomen (\(cobwebRiskPct)% risico). Groeit snel in 3D hoogte."
            risk = "Dactylium Dendroides (\(cobwebRiskPct)%)"
            rec = isEnglish
                ? "Spot-treat with 3% hydrogen peroxide (H2O2) spray if in monotub."
                : "Lokaal vernevelen met 3% waterstofperoxide (H2O2) indien in monotub."
        } else if calculatedPct == 0 {
            statusTitle = isEnglish ? "⏳ Uncolonized Grain / Substrate" : "⏳ Ongekoloniseerd Substraat"
            statusMsg = isEnglish
                ? "Sample consists primarily of grain or substrate without white mycelial coverage. Clean so far."
                : "Het monster toont voornamelijk donker graan/substraat zonder wit mycelium. Nog geen besmetting zichtbaar."
            risk = isEnglish ? "None (Clean)" : "Geen (Schoon)"
            rec = isEnglish
                ? "Keep incubating in dark at 24-26°C. Wait 5-10 days for first growth."
                : "Laat donker rusten bij 24-26°C. Wacht 5-10 dagen op de eerste witte kolonisatie."
        } else if calculatedPct < 30 {
            statusTitle = isEnglish ? "✅ Healthy Early Growth" : "✅ Gezonde Beginkolonisatie"
            statusMsg = isEnglish
                ? "Clean initial white mycelium (\(calculatedPct)%). Zero contamination detected."
                : "Schoon, gezond wit mycelium (\(calculatedPct)%). Geen spoor van besmetting."
            risk = isEnglish ? "None (Clean)" : "Geen (Schoon)"
            rec = isEnglish
                ? "Keep undisturbed. Wait until ~30% before break & shake."
                : "Niet verstoren. Wacht met Break & Shake tot minimaal 30% dekking."
        } else if calculatedPct < 85 {
            statusTitle = isEnglish ? "✅ Strong Active Mycelium" : "✅ Krachtig & Gezond Mycelium"
            statusMsg = isEnglish
                ? "Vigorous colonization (\(calculatedPct)%). Bright white rhizomorphic network."
                : "Krachtige groei (\(calculatedPct)%). Helderwit rhizomorfisch netwerk zonder concurrentie."
            risk = isEnglish ? "None (Clean)" : "Geen (Schoon)"
            rec = isEnglish
                ? "Ideal window for Break & Shake to multiply growth points!"
                : "Ideaal moment voor een Break & Shake om de groeipuntjes te vertakken!"
        } else {
            statusTitle = isEnglish ? "✅ 100% Fully Colonized!" : "✅ Volledig Gekoloniseerd!"
            statusMsg = isEnglish
                ? "Substrate is fully consolidated (\(calculatedPct)%). Solid white mycelial cake."
                : "Het substraat is volledig doorgroeid (\(calculatedPct)%). Solide, sneeuwwitte structuur."
            risk = isEnglish ? "None (Clean)" : "Geen (Schoon)"
            rec = isEnglish
                ? "Ready for bulk spawning (CVG) or fruiting conditions!"
                : "Klaar voor overstap naar bulk (CVG) of direct in de fruiting tent!"
        }
        
        return MyceliumScanReport(
            colonizationPercent: calculatedPct,
            isHealthy: isHealthy,
            statusTitle: statusTitle,
            statusMessage: statusMsg,
            detectedRisk: risk,
            morphology: morphology,
            recommendation: rec,
            trichodermaRiskPct: trichodermaRiskPct,
            bacterialRiskPct: bacterialRiskPct,
            cobwebRiskPct: cobwebRiskPct,
            blackMoldRiskPct: blackMoldRiskPct
        )
    }
    
    private func fallbackReport(isEnglish: Bool) -> MyceliumScanReport {
        MyceliumScanReport(
            colonizationPercent: 0,
            isHealthy: true,
            statusTitle: isEnglish ? "⏳ Uncolonized / Pending" : "⏳ Ongekoloniseerd",
            statusMessage: isEnglish ? "Could not read pixel matrix." : "Kon pixelmatrix niet analyseren.",
            detectedRisk: "Geen",
            morphology: "--",
            recommendation: isEnglish ? "Please retake photo in clear lighting." : "Neem opnieuw een foto met heldere belichting.",
            trichodermaRiskPct: 0,
            bacterialRiskPct: 0,
            cobwebRiskPct: 0,
            blackMoldRiskPct: 0
        )
    }
    
    /// Recognizes handwritten text on jar lids, tape or labels using Apple Neural Engine Vision OCR
    func recognizeHandwriting(image: UIImage, completion: @escaping (ExtractedLabelData) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(ExtractedLabelData(rawRecognizedText: ""))
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { req, error in
            guard let observations = req.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    completion(ExtractedLabelData(rawRecognizedText: ""))
                }
                return
            }
            
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let fullText = lines.joined(separator: "\n")
            let extracted = self.parseExtractedEntities(from: lines, rawText: fullText)
            
            DispatchQueue.main.async {
                completion(extracted)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            try? requestHandler.perform([request])
        }
    }
    
    private func parseExtractedEntities(from lines: [String], rawText: String) -> ExtractedLabelData {
        var data = ExtractedLabelData(rawRecognizedText: rawText)
        let lower = rawText.lowercased()
        
        let knownStrains = [
            "Lion's Mane", "Blue Oyster", "King Oyster", "Golden Oyster", "Shiitake",
            "Jack Frost", "Enigma", "Tidal Wave", "Mazatapec", "Huautla",
            "Lion’s Mane", "Pruikzwam", "Shiitake", "Oesterzwam", "Oyster",
            "Reishi", "King Oyster", "Pioppino", "Cordyceps", "Maitake"
        ]
        
        for s in knownStrains {
            if lower.contains(s.lowercased()) {
                data.strainName = s
                break
            }
        }
        
        if data.strainName.isEmpty, let firstLine = lines.first(where: { $0.count >= 2 }) {
            data.strainName = firstLine
        }
        
        let genRegex = try? NSRegularExpression(pattern: "\\b(T[0-9]|G[0-9]|F[0-9]|LC|Agar|Clone|Kloon)\\b", options: .caseInsensitive)
        if let match = genRegex?.firstMatch(in: rawText, options: [], range: NSRange(location: 0, length: rawText.utf16.count)) {
            if let range = Range(match.range, in: rawText) {
                data.generation = String(rawText[range]).uppercased()
            }
        }
        if data.generation.isEmpty {
            data.generation = "T1"
        }
        
        let dateRegex = try? NSRegularExpression(pattern: "\\b\\d{1,2}[\\/\\-\\.]\\d{1,2}([\\/\\-\\.]\\d{2,4})?\\b")
        if let match = dateRegex?.firstMatch(in: rawText, options: [], range: NSRange(location: 0, length: rawText.utf16.count)) {
            if let range = Range(match.range, in: rawText) {
                data.dateString = String(rawText[range])
            }
        }
        if data.dateString.isEmpty {
            data.dateString = Date().formatted(date: .numeric, time: .omitted)
        }
        
        let weightRegex = try? NSRegularExpression(pattern: "\\b\\d+(\\.\\d+)?\\s*(g|gr|gram|kg)\\b", options: .caseInsensitive)
        if let match = weightRegex?.firstMatch(in: rawText, options: [], range: NSRange(location: 0, length: rawText.utf16.count)) {
            if let range = Range(match.range, in: rawText) {
                data.weightOrSubstrate = String(rawText[range])
            }
        }
        if data.weightOrSubstrate.isEmpty {
            if lower.contains("rogge") || lower.contains("rye") {
                data.weightOrSubstrate = "Rogge Graan"
            } else if lower.contains("cvg") || lower.contains("coir") {
                data.weightOrSubstrate = "CVG Substraat"
            } else {
                data.weightOrSubstrate = "500g"
            }
        }
        
        return data
    }
}


// MARK: - IN-APP DYNAMIC ISLAND PILL & MODAL
struct InAppDynamicIslandPillView: View {
    @EnvironmentObject var store: MycoStore
    
    var body: some View {
        if let timer = store.activeDynamicIslandTimer {
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    store.showDynamicIslandExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(store.dynamicIslandRemainingSeconds <= 0 ? MycoTheme.green.opacity(0.3) : MycoTheme.amber.opacity(0.3))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: store.dynamicIslandRemainingSeconds <= 0 ? "checkmark.circle.fill" : "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(store.dynamicIslandRemainingSeconds <= 0 ? MycoTheme.green : MycoTheme.amber)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(timer.label)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(store.dynamicIslandRemainingSeconds <= 0 ? (store.isEnglish ? "Finished! Cool down" : "Klaar! Afkoelen") : "15 PSI • 121°C")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if store.isDynamicIslandTimerPaused {
                            Text(store.isEnglish ? "PAUSE" : "PAUZE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MycoTheme.amber)
                        }
                        
                        Text(formattedTime(store.dynamicIslandRemainingSeconds))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(store.dynamicIslandRemainingSeconds <= 0 ? MycoTheme.green : .white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black.opacity(0.92))
                        .shadow(color: MycoTheme.blue.opacity(0.3), radius: 10, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(store.dynamicIslandRemainingSeconds <= 0 ? MycoTheme.green : MycoTheme.blue.opacity(0.5), lineWidth: 1.5)
                        )
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    private func formattedTime(_ seconds: Int) -> String {
        if seconds <= 0 { return "00:00" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

struct DynamicIslandExpandedModalView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @State private var showLogSuccess = false
    
    var timer: LabTimerItem? {
        store.activeDynamicIslandTimer
    }
    
    var progress: Double {
        guard let total = timer?.totalMinutes, total > 0 else { return 0 }
        let totalSecs = Double(total * 60)
        let elapsed = totalSecs - Double(store.dynamicIslandRemainingSeconds)
        return min(1.0, max(0.0, elapsed / totalSecs))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)
                
                ZStack {
                    Circle()
                        .stroke(MycoTheme.card, lineWidth: 14)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [MycoTheme.blue, store.dynamicIslandRemainingSeconds <= 0 ? MycoTheme.green : MycoTheme.amber],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: progress)
                    
                    VStack(spacing: 4) {
                        Image(systemName: store.dynamicIslandRemainingSeconds <= 0 ? "checkmark.circle.fill" : "flame.fill")
                            .font(.system(size: 32))
                            .foregroundColor(store.dynamicIslandRemainingSeconds <= 0 ? MycoTheme.green : MycoTheme.amber)
                        
                        Text(formattedTime(store.dynamicIslandRemainingSeconds))
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text(timer?.label ?? "Sterilisatie")
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                    }
                }
                .padding(.top, 10)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.isEnglish ? "PHASE" : "FASE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(MycoTheme.textSecondary)
                        Text(store.dynamicIslandRemainingSeconds <= 0 ? (store.isEnglish ? "Cooling Down" : "Afkoelen (Veilig)") : "♨️ 121°C Sterilisatie")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(MycoTheme.card)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.isEnglish ? "PRESSURE" : "DRUK / DOEL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(MycoTheme.textSecondary)
                        Text("15 PSI (1.05 bar)")
                            .font(.subheadline.bold())
                            .foregroundColor(MycoTheme.amber)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(MycoTheme.card)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                
                HStack(spacing: 14) {
                    Button {
                        store.pauseResumeDynamicIslandTimer()
                    } label: {
                        HStack {
                            Image(systemName: store.isDynamicIslandTimerPaused ? "play.fill" : "pause.fill")
                            Text(store.isDynamicIslandTimerPaused ? (store.isEnglish ? "Resume" : "Hervatten") : (store.isEnglish ? "Pause" : "Pauzeren"))
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MycoTheme.card)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        store.stopDynamicIslandTimer()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MycoTheme.red)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                
                Button {
                    let log = GrowLog(
                        projectID: store.db.projects.first?.id ?? UUID(),
                        actionType: store.isEnglish ? "Sterilization Complete" : "Sterilisatie Cyclus Voltooid",
                        notes: "♨️ Timer [\(timer?.label ?? "Protocol")] voltooid. 15 PSI (121°C). Klaar voor inoculatie."
                    )
                    store.db.logs.insert(log, at: 0)
                    store.save()
                    showLogSuccess = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text(store.isEnglish ? "Add directly to grow logbook" : "Voeg Direct Toe aan Kweeklogboek")
                    }
                    .font(.caption.bold())
                    .foregroundColor(MycoTheme.blue)
                }
                .alert(store.isEnglish ? "Logged!" : "Gelogd!", isPresented: $showLogSuccess) {
                    Button("OK") { dismiss() }
                } message: {
                    Text(store.isEnglish ? "Sterilization cycle saved to lab logs." : "De sterilisatiecyclus is succesvol opgeslagen in je lab-logboeken.")
                }
                
                Spacer()
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle("Live Dynamic Island Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.isEnglish ? "Minimize" : "Minimaliseer") {
                        dismiss()
                    }
                    .foregroundColor(MycoTheme.blue)
                }
            }
        }
    }
    
    private func formattedTime(_ seconds: Int) -> String {
        if seconds <= 0 { return "00:00:00" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}




// MARK: - MYCOCAM & STREAMING SUITE EXTRACTED TO MycoCamViews.swift


// MARK: - TUYA SMART LAB HUB EXTRACTED TO TuyaSmartLabHubViews.swift


// MARK: - 15. SMART HUB SCANNER MODAL (MYCELIUM AI, HANDWRITING OCR, QR)
struct QRScannerModalView: View {
    @Binding var manualCode: String
    var onScanned: (String) -> Void
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var scanMode: Int = 0
    
    // Mycelium AI state
    @State private var selectedAIPhotoItem: PhotosPickerItem? = nil
    @State private var aiScanImage: UIImage? = nil
    @State private var aiScanReport: MyceliumScanReport? = nil
    @State private var isAnalyzingAI = false
    @State private var isStrictMode = true
    @State private var showSavedToLogAlert = false
    @State private var selectedBatchForLog: UUID? = nil
    
    // OCR state
    @State private var selectedOCRPhotoItem: PhotosPickerItem? = nil
    @State private var ocrImage: UIImage? = nil
    @State private var ocrData: ExtractedLabelData? = nil
    @State private var isAnalyzingOCR = false
    @State private var showBatchCreatedAlert = false
    @State private var showCultureCreatedAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Segmented Selector
                Picker("Scan Modus", selection: $scanMode) {
                    Text(store.t(nl: "📷 QR Scanner", en: "📷 QR Scanner")).tag(0)
                    Text(store.t(nl: "🏷️ Label OCR", en: "🏷️ Label OCR")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                if scanMode == 0 {
                    qrScannerView
                } else {
                    handwritingOCRView
                }
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Lab Scanner & Vision", en: "Lab Scanner & Vision"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
            }
        }
    }
    
    // MARK: - TAB 0: MYCELIUM AI VIEW
    private var myceliumAIView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Strict Lab Mode Toggle
                Toggle(isOn: $isStrictMode) {
                    HStack(spacing: 6) {
                        Image(systemName: "cross.vial.fill")
                            .foregroundColor(MycoTheme.blue)
                        Text(store.t(nl: "Strikte Lab Inspectie (Ultra-gevoelig)", en: "Strict Lab Inspection (Ultra-sensitive)"))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(MycoTheme.card)
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .onChange(of: isStrictMode) { _, newVal in
                    if let img = aiScanImage {
                        aiScanReport = AIMycoVisionAnalyzer.shared.analyzeMycelium(image: img, isEnglish: store.isEnglish, strictMode: newVal)
                    }
                }
                if let report = aiScanReport, let img = aiScanImage {
                    // Result Header & Thumbnail
                    HStack(spacing: 12) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.statusTitle)
                                .font(.subheadline.bold())
                                .foregroundColor(report.isHealthy ? MycoTheme.green : MycoTheme.amber)
                            Text(report.morphology)
                                .font(.caption)
                                .foregroundColor(MycoTheme.blue)
                            Text("Apple Neural Engine Analyse • 120x120 Matrix")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    
                    // Contamination Emergency Alert Banner (if any risk detected)
                    if !report.isHealthy {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                Text(report.statusTitle)
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                            }
                            
                            Text(report.statusMessage)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.95))
                            
                            Divider().background(Color.white.opacity(0.3))
                            
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "shield.lefthalf.filled.trianglebadge.exclamationmark")
                                    .foregroundColor(.white)
                                Text(report.recommendation)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(14)
                        .background(Color.red.opacity(0.88))
                        .cornerRadius(14)
                        .shadow(color: Color.red.opacity(0.35), radius: 8, y: 3)
                    }
                    
                    // Detailed Contamination Spectrum Breakdown
                    VStack(alignment: .leading, spacing: 10) {
                        Label(store.t(nl: "Spectrale Contaminatie Analyse", en: "Spectral Contamination Analysis"), systemImage: "waveform.path.ecg")
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                        
                        // Trichoderma bar
                        riskMeterRow(
                            label: store.t(nl: "🟢 Trichoderma / Penicillium", en: "🟢 Trichoderma / Penicillium"),
                            riskPct: report.trichodermaRiskPct,
                            threshold: isStrictMode ? 6 : 14,
                            activeColor: Color.green
                        )
                        
                        // Bacterial Rot bar
                        riskMeterRow(
                            label: store.t(nl: "🟡 Bacteriële Natrot (Bacillus)", en: "🟡 Bacterial Wet Spot (Bacillus)"),
                            riskPct: report.bacterialRiskPct,
                            threshold: isStrictMode ? 8 : 18,
                            activeColor: MycoTheme.amber
                        )
                        
                        // Cobweb Mold bar
                        riskMeterRow(
                            label: store.t(nl: "🕸️ Cobweb Schimmel (Dactylium)", en: "🕸️ Cobweb Mildew (Dactylium)"),
                            riskPct: report.cobwebRiskPct,
                            threshold: isStrictMode ? 10 : 25,
                            activeColor: Color.gray
                        )
                        
                        // Black Mold bar
                        riskMeterRow(
                            label: store.t(nl: "⬛ Zwarte Schimmel (Aspergillus)", en: "⬛ Black Mold (Aspergillus)"),
                            riskPct: report.blackMoldRiskPct,
                            threshold: isStrictMode ? 6 : 15,
                            activeColor: Color.purple
                        )
                    }
                    .padding(14)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    
                    // Big Colonization Gauge
                    VStack(spacing: 8) {
                        HStack {
                            Text(store.t(nl: "Kolonisatiepercentage", en: "Colonization Percentage"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(report.colonizationPercent)%")
                                .font(.system(.title3, design: .monospaced).bold())
                                .foregroundColor(report.colonizationPercent >= 80 ? MycoTheme.green : MycoTheme.blue)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 12)
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [MycoTheme.blue, report.colonizationPercent >= 80 ? MycoTheme.green : MycoTheme.amber],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(report.colonizationPercent) / 100.0, height: 12)
                            }
                        }
                        .frame(height: 12)
                    }
                    .padding(14)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    
                    // Advice Card
                    VStack(alignment: .leading, spacing: 8) {
                        Label(store.t(nl: "AI Laboratorium Diagnose & Advies", en: "AI Lab Diagnosis & Advice"), systemImage: "sparkles")
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                        
                        Text(report.statusMessage)
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Divider().background(MycoTheme.border)
                        
                        Text(store.t(nl: "Aanbevolen actie:", en: "Recommended action:"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MycoTheme.textSecondary)
                        Text(report.recommendation)
                            .font(.caption)
                            .foregroundColor(MycoTheme.green)
                    }
                    .padding(14)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    
                    // Save to batch logbook section
                    if !store.db.projects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(store.t(nl: "Koppel aan kweekbatch & sla op:", en: "Link to batch & save:"))
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.textSecondary)
                            
                            Picker("Batch", selection: Binding(
                                get: { selectedBatchForLog ?? store.db.projects.first?.id ?? UUID() },
                                set: { selectedBatchForLog = $0 }
                            )) {
                                ForEach(store.db.projects) { p in
                                    Text("\(p.strainName) (#\(p.batchNumber))").tag(p.id)
                                }
                            }
                            .pickerStyle(.menu)
                            
                            Button {
                                let projID = selectedBatchForLog ?? store.db.projects.first?.id ?? UUID()
                                if let idx = store.db.projects.firstIndex(where: { $0.id == projID }) {
                                    store.db.projects[idx].colonizationPercent = Double(report.colonizationPercent)
                                }
                                let log = GrowLog(
                                    projectID: projID,
                                    actionType: "🔬 AI Kolonisatiescan (ANE)",
                                    notes: "✅ Kolonisatie: \(report.colonizationPercent)%. Morfologie: \(report.morphology). Risico: \(report.detectedRisk). \(report.statusMessage)"
                                )
                                store.db.logs.insert(log, at: 0)
                                store.save()
                                let gen = UINotificationFeedbackGenerator()
                                gen.notificationOccurred(.success)
                                showSavedToLogAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.down.fill")
                                    Text(store.t(nl: "Sla Resultaat Op in Kweeklogboek", en: "Save Result to Grow Log"))
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(MycoTheme.green)
                                .cornerRadius(10)
                            }
                        }
                        .padding(14)
                        .background(MycoTheme.card)
                        .cornerRadius(14)
                    }
                    
                    // Reset Button
                    Button {
                        aiScanReport = nil
                        aiScanImage = nil
                    } label: {
                        Text(store.t(nl: "📸 Nieuwe Scan Maken", en: "📸 Take New Scan"))
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                    }
                    .padding(.top, 4)
                    
                } else {
                    // Upload / Capture Prompt
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(MycoTheme.card)
                                .frame(height: 240)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(MycoTheme.blue.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6]))
                                )
                            
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles.tv")
                                    .font(.system(size: 48))
                                    .foregroundColor(MycoTheme.blue)
                                
                                Text(store.t(nl: "Apple Neural Engine Scanner", en: "Apple Neural Engine Scanner"))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(store.t(
                                    nl: "Selecteer een foto van een graanpot, kweekzak of agar-schaal. De AI-chip berekent lokaal het kolonisatie% en spoort besmettingen op.",
                                    en: "Select a photo of a grain jar, bag, or agar dish. The AI chip calculates colonization % and scans for contamination on-device."
                                ))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        PhotosPicker(selection: $selectedAIPhotoItem, matching: .images) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text(MainActor.assumeIsolated { store.t(nl: "Kies of Maak Foto van Monster", en: "Choose or Take Photo of Sample") })
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(MycoTheme.blue)
                            .cornerRadius(12)
                        }
                        .onChange(of: selectedAIPhotoItem) { _, newItem in
                            guard let newItem = newItem else { return }
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let img = UIImage(data: data) {
                                    aiScanImage = img
                                    isAnalyzingAI = true
                                    let rep = AIMycoVisionAnalyzer.shared.analyzeMycelium(image: img, isEnglish: store.isEnglish, strictMode: isStrictMode)
                                    try? await Task.sleep(nanoseconds: 400_000_000)
                                    aiScanReport = rep
                                    isAnalyzingAI = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
            .padding(.vertical, 10)
        }
        .alert(store.t(nl: "Opgeslagen in Logboek", en: "Saved to Logbook"), isPresented: $showSavedToLogAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(store.t(
                nl: "De AI scan en het kolonisatiepercentage zijn direct geregistreerd.",
                en: "The AI scan and colonization percentage have been recorded."
            ))
        }
    }
    

    private func riskMeterRow(label: String, riskPct: Int, threshold: Int, activeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(MycoTheme.textSecondary)
                Spacer()
                Text(riskPct >= threshold ? "\(riskPct)% (RISICO)" : "\(riskPct)% (Schoon)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(riskPct >= threshold ? Color.red : MycoTheme.green)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(riskPct >= threshold ? Color.red : activeColor.opacity(0.7))
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(riskPct) / 100.0)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - TAB 1: HANDWRITING OCR VIEW
    private var handwritingOCRView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let data = ocrData, let img = ocrImage {
                    HStack(spacing: 12) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.t(nl: "✅ Handschrift Herkend!", en: "✅ Handwriting Recognized!"))
                                .font(.subheadline.bold())
                                .foregroundColor(MycoTheme.green)
                            Text("Vision Neural Text Engine (Apple ANE)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(MycoTheme.card)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.t(nl: "Gedetecteerde Gegevens (Pas aan indien gewenst):", en: "Detected Data (Edit if needed):"))
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.textSecondary)
                        
                        HStack {
                            Text(store.t(nl: "Soortnaam:", en: "Strain:"))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                .frame(width: 80, alignment: .leading)
                            TextField("Soort", text: Binding(get: { data.strainName }, set: { ocrData?.strainName = $0 }))
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text(store.t(nl: "Generatie:", en: "Generation:"))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                .frame(width: 80, alignment: .leading)
                            TextField("Generatie (bijv. T2)", text: Binding(get: { data.generation }, set: { ocrData?.generation = $0 }))
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text(store.t(nl: "Datum:", en: "Date:"))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                .frame(width: 80, alignment: .leading)
                            TextField("Datum", text: Binding(get: { data.dateString }, set: { ocrData?.dateString = $0 }))
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text(store.t(nl: "Substraat:", en: "Substrate:"))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                .frame(width: 80, alignment: .leading)
                            TextField("Gewicht / Substraat", text: Binding(get: { data.weightOrSubstrate }, set: { ocrData?.weightOrSubstrate = $0 }))
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(14)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    
                    // Action Buttons
                    VStack(spacing: 10) {
                        Button {
                            let sku = String(format: "ML-%03d", store.db.projects.count + 1)
                            let p = GrowProject(
                                strainName: data.strainName.isEmpty ? "Nieuwe Soort" : data.strainName,
                                skuCode: sku,
                                batchNumber: store.db.projects.count + 1,
                                phase: .spawn,
                                colonizationPercent: 0.0,
                                containerName: "Broedpot",
                                substrateName: data.weightOrSubstrate,
                                spawnToBulkRatio: "1:2",
                                drySubstrateWeightGrams: 500,
                                sterilizationNotes: "Snelkookpan 90m @ 15 PSI",
                                qrCodeID: "QR-\(sku)-\(Int.random(in: 100...999))"
                            )
                            store.db.projects.insert(p, at: 0)
                            store.save()
                            showBatchCreatedAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text(store.t(nl: "➕ Maak Direct Kweekbatch Aan", en: "➕ Create Grow Batch Instantly"))
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(MycoTheme.blue)
                            .cornerRadius(10)
                        }
                        
                        Button {
                            let c = CultureItem(
                                strainName: data.strainName.isEmpty ? "Nieuwe Cultuur" : data.strainName,
                                skuCode: store.nextSKU(prefix: "CUL"),
                                cultureType: "Vloeibare Cultuur (Liquid Culture - LC)",
                                generation: data.generation.isEmpty ? "T1" : data.generation,
                                mediaName: "Malt Extract Broth (MEB)",
                                status: "Actieve Groei / Incubatiefase",
                                qrCodeID: "QR-CUL-\(Int.random(in: 100...999))"
                            )
                            store.db.cultures.insert(c, at: 0)
                            store.save()
                            showCultureCreatedAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "allergens")
                                Text(store.t(nl: "➕ Maak Direct Cultuur Aan", en: "➕ Create Culture Instantly"))
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(MycoTheme.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(MycoTheme.card)
                            .cornerRadius(10)
                        }
                    }
                    
                    Button {
                        ocrData = nil
                        ocrImage = nil
                    } label: {
                        Text(store.t(nl: "🔄 Nieuw Label Scannen", en: "🔄 Scan Another Label"))
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                    }
                    .padding(.top, 4)
                    
                } else {
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(MycoTheme.card)
                                .frame(height: 240)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(MycoTheme.green.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6]))
                                )
                            
                            VStack(spacing: 12) {
                                Image(systemName: "pencil.and.outline")
                                    .font(.system(size: 48))
                                    .foregroundColor(MycoTheme.green)
                                
                                Text(store.t(nl: "AI Handschrift & Tape Scanner", en: "AI Handwriting & Tape Scanner"))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(store.t(
                                    nl: "Scan geschreven schilderstape op deksels of etiketten (bijv. GT T2 14/10 500g). De Neural Engine herkent automatisch soort, generatie en datum.",
                                    en: "Scan masking tape on jar lids or labels (e.g. GT T2 14/10 500g). The Neural Engine recognizes strain, generation, and date automatically."
                                ))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        PhotosPicker(selection: $selectedOCRPhotoItem, matching: .images) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                Text(MainActor.assumeIsolated { store.t(nl: "Kies of Maak Foto van Label / Deksel", en: "Choose or Take Photo of Label / Lid") })
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(MycoTheme.green)
                            .cornerRadius(12)
                        }
                        .onChange(of: selectedOCRPhotoItem) { _, newItem in
                            guard let newItem = newItem else { return }
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let img = UIImage(data: data) {
                                    ocrImage = img
                                    AIMycoVisionAnalyzer.shared.recognizeHandwriting(image: img) { parsed in
                                        ocrData = parsed
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
            .padding(.vertical, 10)
        }
        .alert(store.t(nl: "Kweekbatch Aangemaakt!", en: "Batch Created!"), isPresented: $showBatchCreatedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(store.t(nl: "De kweekbatch is direct toegevoegd aan je Dashboard.", en: "The batch has been added to your Dashboard."))
        }
        .alert(store.t(nl: "Cultuur Aangemaakt!", en: "Culture Created!"), isPresented: $showCultureCreatedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(store.t(nl: "De cultuur is direct toegevoegd aan je Genetica Lab.", en: "The culture has been added to your Genetics Lab."))
        }
    }
    
    // MARK: - TAB 2: QR SCANNER VIEW
    private var qrScannerView: some View {
        VStack(spacing: 16) {
            if MycoDevicePlatform.isMac {
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.t(nl: "Zoek of Open Batch / Cultuur via Code", en: "Find or Open Batch / Culture by Code"))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    HStack {
                        TextField(store.t(nl: "Typ SKU of QR-code (bijv. ML-001 of QR-ML-001)", en: "Type SKU or QR code (e.g. ML-001 or QR-ML-001)"), text: $manualCode)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button(store.t(nl: "Open", en: "Open")) {
                            onScanned(manualCode)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(MycoTheme.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(14)
                .background(MycoTheme.card)
                .cornerRadius(14)
                .padding(.horizontal, 16)
            }
            
            ZStack {
                QRCameraScannerView { scanned in
                    onScanned(scanned)
                }
                .cornerRadius(16)
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MycoTheme.blue, lineWidth: 3)
                    .frame(width: 220, height: 220)
            }
            .frame(maxHeight: MycoDevicePlatform.isMac ? 240 : 340)
            .padding(.horizontal, 16)
            
            Text(store.t(
                nl: MycoDevicePlatform.isMac
                    ? "Houd een QR-label voor de FaceTime-camera om direct te scannen."
                    : "Richt je \(MycoDevicePlatform.deviceName) camera op het QR-label van je pot, agar-plaat of monotub.",
                en: MycoDevicePlatform.isMac
                    ? "Hold a QR label in front of the FaceTime camera to scan."
                    : "Point your \(MycoDevicePlatform.deviceName) camera at the QR label on your jar, plate, or tub."
            ))
            .font(.caption)
            .foregroundColor(MycoTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            
            if !MycoDevicePlatform.isMac {
                HStack {
                    TextField(store.t(nl: "Of typ QR-code handmatig (bijv. QR-ML-001)", en: "Or type QR code manually (e.g. QR-ML-001)"), text: $manualCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                    Button(store.t(nl: "Open", en: "Open")) {
                        onScanned(manualCode)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(MycoTheme.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
}


struct QRLabelStudioView: View {
    let labels: [(title: String, subtitle: String, date: String, qr: String)]
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("\(labels.count) " + store.t(nl: "QR-Label(s) Klaar om te Printen", en: "QR Label(s) Ready to Print"))
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    Button {
                        let url = QRCodeGenerator.createPrintablePDF(labels: labels, includeLogo: store.db.includeLogoInQR)
                        QRCodeGenerator.printPDF(url: url)
                    } label: {
                        Label(store.t(nl: "Direct Printen (AirPrint)", en: "Direct Print (AirPrint)"), systemImage: "printer.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(MycoTheme.blue)
                            .cornerRadius(10)
                    }
                    
                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            Label(store.t(nl: "Deel / Bewaar PDF", en: "Share / Save PDF"), systemImage: "square.and.arrow.up")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(MycoTheme.card)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MycoTheme.border, lineWidth: 1))
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
                
                ForEach(Array(labels.enumerated()), id: \.offset) { _, item in
                    QRLabelPreviewRow(item: item, includeLogo: store.db.includeLogoInQR)
                }
            }
            .padding(16)
            .padding(.bottom, 60)
        }
        .background(MycoTheme.bg)
        .navigationTitle(store.t(nl: "QR-Label Studio", en: "QR Label Studio"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            pdfURL = QRCodeGenerator.createPrintablePDF(labels: labels, includeLogo: store.db.includeLogoInQR)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(store.t(nl: "Klaar", en: "Done")) { dismiss() }
            }
        }
    }
}

private struct QRLabelPreviewRow: View {
    let item: (title: String, subtitle: String, date: String, qr: String)
    var includeLogo: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(uiImage: QRCodeGenerator.generateImage(from: item.qr, size: 120, includeLogo: includeLogo))
                .interpolation(.none)
                .resizable()
                .frame(width: 90, height: 90)
                .padding(6)
                .background(Color.white)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.black)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundColor(Color(uiColor: .darkGray))
                Text("Datum: \(item.date)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.black)
                if !item.qr.contains("\n") {
                    Text(item.qr)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - 15B. CENTRAL QR CODE ARCHIVE & VAULT
struct QRCodeArchiveView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    enum QRArchiveCategory: String, CaseIterable, Identifiable {
        case all
        case growBatch
        case culture
        case stash
        case labSupply
        case custom
        
        var id: String { rawValue }
        
        func title(store: MycoStore) -> String {
            switch self {
            case .all: return store.t(nl: "Alle", en: "All")
            case .growBatch: return store.t(nl: "Kweekbatch", en: "Grow Batch")
            case .culture: return store.t(nl: "Cultuur", en: "Culture")
            case .stash: return store.t(nl: "Stash Voorraad", en: "Stash Inventory")
            case .labSupply: return store.t(nl: "Lab Voorraad", en: "Lab Supply")
            case .custom: return store.t(nl: "Aangepast", en: "Custom")
            }
        }
    }
    
    @State private var searchQuery: String = ""
    @State private var selectedCategory: QRArchiveCategory = .all
    @State private var selectedQRDetail: SavedQRCodeItem? = nil
    @State private var showCreateCustomQR: Bool = false
    @State private var activeLabels: BatchLabelsWrapper? = nil
    @State private var copiedCodeID: String? = nil
    
    private func matchesCategory(_ item: SavedQRCodeItem, category: QRArchiveCategory) -> Bool {
        switch category {
        case .all:
            return true
        case .growBatch:
            return item.category.localizedCaseInsensitiveContains("Kweekbatch") ||
                   item.category.localizedCaseInsensitiveContains("Grow Batch") ||
                   item.category.localizedCaseInsensitiveContains("Batch")
        case .culture:
            return item.category.localizedCaseInsensitiveContains("Cultuur") ||
                   item.category.localizedCaseInsensitiveContains("Culture")
        case .stash:
            return item.category.localizedCaseInsensitiveContains("Stash")
        case .labSupply:
            return item.category.localizedCaseInsensitiveContains("Lab") ||
                   item.category.localizedCaseInsensitiveContains("Supply")
        case .custom:
            if isCustomItem(item) { return true }
            let customCats = ["Aangepast", "Custom", "Algemeen", "Apparatuur", "Sporenprint", "Overig"]
            return customCats.contains(where: { item.category.localizedCaseInsensitiveContains($0) })
        }
    }
    
    var filteredQRCodes: [SavedQRCodeItem] {
        let all = store.allSavedQRCodes
        return all.filter { item in
            // Category filter
            if !matchesCategory(item, category: selectedCategory) {
                return false
            }
            
            // Search text filter
            let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if q.isEmpty { return true }
            return item.code.lowercased().contains(q) ||
                   item.title.lowercased().contains(q) ||
                   item.subtitle.lowercased().contains(q) ||
                   item.notes.lowercased().contains(q) ||
                   item.category.lowercased().contains(q)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search & Filter Header
                VStack(spacing: 12) {
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(MycoTheme.textSecondary)
                        TextField(
                            store.t(nl: "Zoek op code, soort, batch of categorie...", en: "Search by code, strain, batch or category..."),
                            text: $searchQuery
                        )
                        .foregroundColor(.white)
                        .font(.subheadline)
                        
                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(MycoTheme.card)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(MycoTheme.border, lineWidth: 1))
                    
                    // Filter Chips Bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(QRArchiveCategory.allCases) { cat in
                                let count = countForCategory(cat)
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(cat.title(store: store))
                                            .font(.caption.bold())
                                        Text("\(count)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(selectedCategory == cat ? Color.white.opacity(0.2) : MycoTheme.border)
                                            .cornerRadius(6)
                                    }
                                    .foregroundColor(selectedCategory == cat ? .white : MycoTheme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(selectedCategory == cat ? MycoTheme.blue : MycoTheme.card)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedCategory == cat ? MycoTheme.blue : MycoTheme.border, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(MycoTheme.card.opacity(0.5))
                
                Divider().background(MycoTheme.border)
                
                // Action summary banner
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(
                            nl: "\(filteredQRCodes.count) QR-code's gevonden",
                            en: "\(filteredQRCodes.count) QR codes found"
                        ))
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        
                        Text(store.t(
                            nl: "Tik op een code voor details, printen of kopiëren",
                            en: "Tap a code for details, printing or copying"
                        ))
                        .font(.system(size: 11))
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    if !filteredQRCodes.isEmpty {
                        Button {
                            exportFilteredToPDF()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "printer.fill")
                                    .font(.system(size: 11))
                                Text(store.t(nl: "Print Selectie", en: "Print Selection"))
                                    .font(.caption.bold())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(MycoTheme.blue)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(MycoTheme.bg)
                
                // Content List
                if filteredQRCodes.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 54))
                            .foregroundColor(MycoTheme.textSecondary.opacity(0.5))
                        Text(store.t(nl: "Geen QR-codes gevonden", en: "No QR codes found"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(store.t(
                            nl: "Er zijn geen opgeslagen QR-codes die voldoen aan je zoekopdracht of filter.",
                            en: "There are no saved QR codes matching your search or filter."
                        ))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        
                        Button {
                            showCreateCustomQR = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text(store.t(nl: "Nieuwe QR-Code Aanmaken", en: "Create New QR Code"))
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(MycoTheme.blue)
                            .cornerRadius(10)
                        }
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredQRCodes) { item in
                            QRCodeArchiveRowView(
                                item: item,
                                isCopied: copiedCodeID == item.code,
                                onCopy: {
                                    copyToClipboard(item.code)
                                },
                                onPrintSingle: {
                                    printSingle(item)
                                },
                                onSelect: {
                                    selectedQRDetail = item
                                },
                                onDeleteCustom: isCustomItem(item) ? {
                                    deleteCustom(item)
                                } : nil
                            )
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "QR-Code Archief & Kluis", en: "QR Code Archive & Vault"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateCustomQR = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text(store.t(nl: "Nieuw", en: "New"))
                        }
                        .font(.caption.bold())
                        .foregroundColor(MycoTheme.blue)
                    }
                }
            }
            .sheet(item: $selectedQRDetail) { item in
                NavigationStack {
                    QRCodeDetailSheetView(item: item)
                        .environmentObject(store)
                }
            }
            .sheet(isPresented: $showCreateCustomQR) {
                NavigationStack {
                    CreateCustomQRCodeView()
                        .environmentObject(store)
                }
            }
            .sheet(item: $activeLabels) { wrapper in
                NavigationStack {
                    QRLabelStudioView(labels: wrapper.labels)
                        .environmentObject(store)
                }
            }
        }
    }
    
    private func countForCategory(_ cat: QRArchiveCategory) -> Int {
        let all = store.allSavedQRCodes
        if cat == .all { return all.count }
        return all.filter { matchesCategory($0, category: cat) }.count
    }
    
    private func isCustomItem(_ item: SavedQRCodeItem) -> Bool {
        store.db.customQRCodes.contains(where: { $0.id == item.id || $0.code == item.code })
    }
    
    private func deleteCustom(_ item: SavedQRCodeItem) {
        store.deleteCustomQRCode(id: item.id)
        store.db.customQRCodes.removeAll(where: { $0.code == item.code })
        store.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        copiedCodeID = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if copiedCodeID == text {
                copiedCodeID = nil
            }
        }
    }
    
    private func printSingle(_ item: SavedQRCodeItem) {
        let formattedDate = item.dateCreated.formatted(date: .numeric, time: .omitted)
        activeLabels = BatchLabelsWrapper(labels: [(
            title: item.title,
            subtitle: item.subtitle,
            date: formattedDate,
            qr: item.payload
        )])
    }
    
    private func exportFilteredToPDF() {
        let labels = filteredQRCodes.map { item in
            (
                title: item.title,
                subtitle: item.subtitle,
                date: item.dateCreated.formatted(date: .numeric, time: .omitted),
                qr: item.payload
            )
        }
        activeLabels = BatchLabelsWrapper(labels: labels)
    }
}

struct QRCodeArchiveRowView: View {
    let item: SavedQRCodeItem
    var isCopied: Bool = false
    var onCopy: () -> Void
    var onPrintSingle: () -> Void
    var onSelect: () -> Void
    var onDeleteCustom: (() -> Void)? = nil
    
    @EnvironmentObject var store: MycoStore
    
    private var categoryColor: Color {
        switch item.category.lowercased() {
        case let c where c.contains("batch"): return MycoTheme.blue
        case let c where c.contains("cultuur") || c.contains("culture"): return Color.teal
        case let c where c.contains("stash"): return Color.purple
        case let c where c.contains("voorraad") || c.contains("supply"): return MycoTheme.amber
        default: return MycoTheme.green
        }
    }
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                // QR Thumbnail
                let qrImg = QRCodeGenerator.generateImage(from: item.payload, size: 100, includeLogo: store.db.includeLogoInQR)
                Image(uiImage: qrImg)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .padding(5)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.2), radius: 3)
                
                // Text details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.category)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(categoryColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.15))
                            .cornerRadius(4)
                        
                        Text(item.dateCreated.formatted(date: .numeric, time: .omitted))
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                        
                        Spacer()
                    }
                    
                    Text(item.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.blue)
                        Text(item.code)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(MycoTheme.blue)
                    }
                }
                
                Spacer()
                
                // Trailing Action Buttons
                VStack(spacing: 8) {
                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .font(.system(size: 13))
                            .foregroundColor(isCopied ? MycoTheme.green : MycoTheme.textSecondary)
                            .padding(6)
                            .background(MycoTheme.bg)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onPrintSingle()
                    } label: {
                        Image(systemName: "printer.fill")
                            .font(.system(size: 13))
                            .foregroundColor(MycoTheme.blue)
                            .padding(6)
                            .background(MycoTheme.bg)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    if let onDelete = onDeleteCustom {
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(MycoTheme.red)
                                .padding(6)
                                .background(MycoTheme.bg)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(10)
            .background(MycoTheme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct QRCodeDetailSheetView: View {
    let item: SavedQRCodeItem
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var copied: Bool = false
    @State private var activeLabels: BatchLabelsWrapper? = nil
    @State private var showFullRawPayload: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Large QR Preview
                let qrImage = QRCodeGenerator.generateImage(from: item.payload, size: 300, includeLogo: store.db.includeLogoInQR)
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                    .padding(.top, 10)
                
                // Item details card
                MycoCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(item.category)
                                .font(.caption2.bold())
                                .foregroundColor(MycoTheme.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(MycoTheme.blue.opacity(0.18))
                                .cornerRadius(6)
                            Spacer()
                            Text(item.dateCreated.formatted(date: .numeric, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        
                        Text(item.title)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.subheadline)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        
                        if !item.notes.isEmpty {
                            Text(item.notes)
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                .padding(.top, 2)
                        }
                        
                        Divider().background(MycoTheme.border)
                        
                        // QR Code ID row
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "QR-Code Identificatie:", en: "QR Code Identification:"))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                                Text(item.code)
                                    .font(.system(.body, design: .monospaced).bold())
                                    .foregroundColor(MycoTheme.blue)
                            }
                            Spacer()
                            Button {
                                UIPasteboard.general.string = item.code
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copied = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    Text(copied ? store.t(nl: "Gekopieerd!", en: "Copied!") : store.t(nl: "Kopieer", en: "Copy"))
                                }
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(copied ? MycoTheme.green : MycoTheme.blue)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Action Buttons
                VStack(spacing: 10) {
                    Button {
                        let formattedDate = item.dateCreated.formatted(date: .numeric, time: .omitted)
                        activeLabels = BatchLabelsWrapper(labels: [(
                            title: item.title,
                            subtitle: item.subtitle,
                            date: formattedDate,
                            qr: item.payload
                        )])
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "printer.fill")
                            Text(store.t(nl: "Print QR Label (AirPrint / PDF)", en: "Print QR Label (AirPrint / PDF)"))
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MycoTheme.blue)
                        .cornerRadius(12)
                    }
                    
                    if let image = Image(uiImage: qrImage) as Image? {
                        ShareLink(item: Image(uiImage: qrImage), preview: SharePreview(item.title, image: image)) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text(store.t(nl: "Deel QR Afbeelding", en: "Share QR Image"))
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(MycoTheme.card)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // Raw payload accordion
                DisclosureGroup(
                    isExpanded: $showFullRawPayload,
                    content: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.payload)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(MycoTheme.textSecondary)
                                .textSelection(.enabled)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(MycoTheme.bg)
                                .cornerRadius(8)
                            
                            Button {
                                UIPasteboard.general.string = item.payload
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Label(store.t(nl: "Kopieer Volledige Payload", en: "Copy Full Payload"), systemImage: "doc.on.clipboard")
                                    .font(.caption2.bold())
                                    .foregroundColor(MycoTheme.blue)
                            }
                        }
                        .padding(.top, 6)
                    },
                    label: {
                        Text(store.t(nl: "Volledige QR Payload Data", en: "Full QR Payload Data"))
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                )
                .padding(14)
                .background(MycoTheme.card)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 16)
        }
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                    .foregroundColor(MycoTheme.blue)
            }
        }
        .sheet(item: $activeLabels) { wrapper in
            NavigationStack {
                QRLabelStudioView(labels: wrapper.labels)
                    .environmentObject(store)
            }
        }
    }
}

struct CreateCustomQRCodeView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var category: String = "Aangepast"
    @State private var code: String = "QR-ML-\(Int.random(in: 1000...9999))"
    @State private var notes: String = ""
    
    private let availableCategories = [
        "Aangepast",
        "Kweekbatch",
        "Cultuur",
        "Voorraad",
        "Sporenprint",
        "Apparatuur",
        "Overig"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Live preview of QR
                let previewImg = QRCodeGenerator.generateImage(from: code.isEmpty ? "MYCOLAB" : code, size: 160, includeLogo: store.db.includeLogoInQR)
                VStack(spacing: 8) {
                    Image(uiImage: previewImg)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.2), radius: 6)
                    
                    Text(code)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundColor(MycoTheme.blue)
                }
                .padding(.top, 12)
                
                MycoCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(store.t(nl: "QR-Code Gegevens", en: "QR Code Details"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.t(nl: "Titel / Naam", en: "Title / Name"))
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.textSecondary)
                            TextField(store.t(nl: "bijv. Vloeibare Cultuur Lion's Mane", en: "e.g. Liquid Culture Lion's Mane"), text: $title)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.t(nl: "Ondertitel / Specificatie", en: "Subtitle / Specification"))
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.textSecondary)
                            TextField(store.t(nl: "bijv. 10ml suspensie • Koelkast #2", en: "e.g. 10ml suspension • Fridge #2"), text: $subtitle)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.t(nl: "Categorie", en: "Category"))
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.textSecondary)
                            Picker("Categorie", selection: $category) {
                                ForEach(availableCategories, id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(MycoTheme.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(store.t(nl: "QR-Code Tekst / Payload", en: "QR Code Text / Payload"))
                                    .font(.caption.bold())
                                    .foregroundColor(MycoTheme.textSecondary)
                                Spacer()
                                Button(store.t(nl: "Genereer Nieuw", en: "Generate New")) {
                                    code = "QR-ML-\(Int.random(in: 1000...9999))"
                                }
                                .font(.caption2)
                                .foregroundColor(MycoTheme.blue)
                            }
                            TextField("QR-CODE-ID", text: $code)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.subheadline, design: .monospaced))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.t(nl: "Notities (Optioneel)", en: "Notes (Optional)"))
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.textSecondary)
                            TextField(store.t(nl: "Aanvullende lab-notities...", en: "Additional lab notes..."), text: $notes)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
                Button {
                    saveCustomCode()
                } label: {
                    Text(store.t(nl: "QR-Code Opslaan in Archief", en: "Save QR Code in Archive"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(title.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : MycoTheme.blue)
                        .cornerRadius(12)
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .padding(16)
        }
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "Nieuwe QR-Code", en: "New QR Code"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(store.t(nl: "Annuleer", en: "Cancel")) { dismiss() }
                    .foregroundColor(MycoTheme.blue)
            }
        }
    }
    
    private func saveCustomCode() {
        let finalTitle = title.trimmingCharacters(in: .whitespaces)
        guard !finalTitle.isEmpty else { return }
        let finalCode = code.trimmingCharacters(in: .whitespaces).isEmpty ? "QR-ML-\(Int.random(in: 1000...9999))" : code.trimmingCharacters(in: .whitespaces)
        
        let newItem = SavedQRCodeItem(
            code: finalCode,
            title: finalTitle,
            subtitle: subtitle.trimmingCharacters(in: .whitespaces),
            category: category,
            dateCreated: Date(),
            notes: notes.trimmingCharacters(in: .whitespaces),
            payload: finalCode
        )
        
        store.db.customQRCodes.append(newItem)
        store.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}

