//
//  CleanroomVoiceConsoleView.swift
//  MycoLab
//
//  Sterile Hands-Free Voice Console for Flow Hood & Cleanroom work:
//  - Big high-contrast status & live audio waveform
//  - Hands-free voice recognition with verbal responses
//  - Sterile elbow-friendly touch targets
//  - Clean InfoTipButton integration (zero screen clutter)
//

import SwiftUI
import Speech
import AVFoundation

struct CleanroomVoiceConsoleView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var voiceMgr = MycoCleanroomVoiceManager.shared
    
    @State private var waveAnimation: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "080C10").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Header with InfoTipButton
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(voiceMgr.isListening ? MycoTheme.green : Color.orange)
                                        .frame(width: 8, height: 8)
                                    Text(store.t(nl: "Cleanroom Voice Console", en: "Cleanroom Voice Console"))
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    InfoTipButton(
                                        title: store.t(nl: "Hands-Free Voice Assistent", en: "Hands-Free Voice Assistant"),
                                        message: store.t(
                                            nl: "Bedien MycoLabs hands-free tijdens werk voor de laminaire flowhood of Still Air Box. Zeg bijvoorbeeld: 'MycoLabs, start timer voor 90 minuten autoclaaf' of 'Noteer isolatie van Plaat 1 naar Pot 2'. Je handschoenen blijven 100% steriel.",
                                            en: "Operate MycoLabs hands-free under the laminar flow hood or SAB. Say: 'MycoLabs, start timer for 90 minutes autoclave' or 'Note isolation from Plate 1 to Jar 2'. Keeps your gloves 100% sterile."
                                        )
                                    )
                                }
                                
                                Text(voiceMgr.isListening ? store.t(nl: "Hands-free actief • Microfoon luistert", en: "Hands-free active • Mic listening") : store.t(nl: "Microfoon gepauzeerd", en: "Microphone paused"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                voiceMgr.stopListening()
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Permission alert banner if not granted
                        if !voiceMgr.isPermissionGranted {
                            VStack(spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: "mic.slash.fill")
                                        .foregroundColor(MycoTheme.amber)
                                        .font(.system(size: 18))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.t(nl: "Microfoontoegang vereist", en: "Microphone access required"))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(store.t(nl: "Geef toestemming voor microfoon en spraakherkenning om de console te gebruiken.", en: "Grant microphone and speech permissions to use hands-free voice console."))
                                            .font(.system(size: 11))
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                    Spacer()
                                    Button {
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        Text(store.t(nl: "Instellingen", en: "Settings"))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(MycoTheme.amber)
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(12)
                                .background(MycoTheme.amber.opacity(0.12))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MycoTheme.amber.opacity(0.3), lineWidth: 1))
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Live Waveform Visualizer & Microphone Centerpiece
                        ZStack {
                            // Pulsing outer aura
                            Circle()
                                .fill(voiceMgr.isListening ? MycoTheme.green.opacity(0.12) : Color.white.opacity(0.04))
                                .frame(width: 170, height: 170)
                                .scaleEffect(voiceMgr.isListening ? 1.0 + CGFloat(voiceMgr.audioLevel) * 0.45 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: voiceMgr.audioLevel)
                            
                            // Middle ring
                            Circle()
                                .stroke(voiceMgr.isListening ? MycoTheme.green.opacity(0.4) : MycoTheme.border, lineWidth: 2)
                                .frame(width: 130, height: 130)
                            
                            // Main Action Button
                            Button {
                                voiceMgr.toggleListening()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(voiceMgr.isListening ? MycoTheme.green : Color(hex: "1F242D"))
                                        .frame(width: 96, height: 96)
                                        .shadow(color: (voiceMgr.isListening ? MycoTheme.green : Color.black).opacity(0.4), radius: 12, y: 4)
                                    
                                    Image(systemName: voiceMgr.isListening ? "mic.fill" : "mic.slash.fill")
                                        .font(.system(size: 38, weight: .bold))
                                        .foregroundColor(voiceMgr.isListening ? .black : MycoTheme.textSecondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                        
                        // Live Transcript Card
                        VStack(spacing: 8) {
                            Text(voiceMgr.currentTranscript.isEmpty ? (voiceMgr.isListening ? store.t(nl: "Spreek een commando uit...", en: "Speak a command...") : store.t(nl: "Tik op de microfoon om te starten", en: "Tap microphone to start")) : "\"\(voiceMgr.currentTranscript)\"")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(voiceMgr.currentTranscript.isEmpty ? MycoTheme.textSecondary : .white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(MycoTheme.border, lineWidth: 1)
                                )
                            
                            if !voiceMgr.lastRecognizedIntentLabel.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(Color.cyan)
                                        .font(.system(size: 13, weight: .bold))
                                    Text("AI Begrepen:")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    Text(voiceMgr.lastRecognizedIntentLabel)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color.cyan)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.cyan.opacity(0.12))
                                .cornerRadius(8)
                            } else if !voiceMgr.lastExecutedCommand.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(MycoTheme.green)
                                        .font(.system(size: 13))
                                    Text(voiceMgr.lastExecutedCommand)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(MycoTheme.green)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(MycoTheme.green.opacity(0.12))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // AI Fuzzy Speech Suggestions (Tappable for Quick Testing)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(store.t(nl: "SLIMME AI HERKENNING (PRAAT NATUURLIJK)", en: "SMART AI UNDERSTANDING (SPEAK NATURALLY)"))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(MycoTheme.textSecondary)
                                Spacer()
                                InfoTipButton(
                                    title: store.t(nl: "AI Flowhood Spraakbegrip", en: "AI Flow Hood Speech Engine"),
                                    message: store.t(
                                        nl: "De ingebouwde Natural Language AI begrijpt halve zinnen en informele spreektaal. Je hoeft geen vaste robot-zinnetjes te gebruiken: zeg gerust \"autoclaaf\" (begrijpt automatisch 90 min), \"half uurtje timer\", \"hoe warm is het?\" of \"zet mist aan\". Het systeem vult ontbrekende data automatisch aan met mykologische standaarden. Je kunt de knoppen hieronder ook aantikken om te testen.",
                                        en: "The on-device Natural Language AI understands incomplete sentences and natural slang. No rigid robotic phrasing needed: simply say \"autoclave\" (defaults to 90 min), \"half hour timer\", \"how warm is it?\" or \"turn on mist\". The system automatically infers missing parameters using mycological best practices. You can also tap the chips below to test."
                                    )
                                )
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    aiSuggestionChip(text: "⏱️ \"autoclaaf\" (90m)", command: "start autoclaaf")
                                    aiSuggestionChip(text: "⏳ \"half uurtje timer\"", command: "start timer voor een half uur")
                                    aiSuggestionChip(text: "🌡️ \"hoe warm is het?\"", command: "hoe warm is het?")
                                    aiSuggestionChip(text: "💧 \"zet mist aan\"", command: "zet mist aan")
                                    aiSuggestionChip(text: "⚠️ \"pot 3 trichoderma\"", command: "pot 3 trichoderma besmetting")
                                    aiSuggestionChip(text: "📦 \"welke batches?\"", command: "welke batches zijn actief?")
                                    aiSuggestionChip(text: "🛑 \"alles uit\"", command: "alles uit")
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Sterile Quick-Action Touch Targets (Designed for clean elbows/wrists)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(store.t(nl: "STERIELE SNELKEUZE (ELLEBOOG / POLS)", en: "STERILE QUICK TARGETS (ELBOW / WRIST)"))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(MycoTheme.textSecondary)
                                
                                Spacer()
                                
                                InfoTipButton(
                                    title: store.t(nl: "Grote Doelvlakken", en: "Large Touch Targets"),
                                    message: store.t(
                                        nl: "Deze extra grote knoppen kun je zonder handschoenen aan te raken met de zijkant van je onderarm of elleboog bedienen als de spraakherkenning door flowhood-ruis wordt overstemd.",
                                        en: "These extra large buttons can be tapped with your forearm or elbow if loud flow hood fan noise interrupts speech."
                                    )
                                )
                            }
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                // 90 Min Autoclave
                                Button {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("MycoLabStartLabTimerFromVoice"),
                                        object: nil,
                                        userInfo: ["minutes": 90, "title": "Autoclaaf Sterilisatie 15 PSI"]
                                    )
                                    voiceMgr.speak("90 minuten autoclaaf timer gestart")
                                } label: {
                                    sterileBigTile(icon: "timer", title: "90 min Autoclaaf", subtitle: "15 PSI Sterilisatie", color: MycoTheme.amber)
                                }
                                
                                // 45 Min Agar
                                Button {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("MycoLabStartLabTimerFromVoice"),
                                        object: nil,
                                        userInfo: ["minutes": 45, "title": "Agar Sterilisatie 15 PSI"]
                                    )
                                    voiceMgr.speak("45 minuten agar timer gestart")
                                } label: {
                                    sterileBigTile(icon: "circle.hexagongrid.fill", title: "45 min Agar", subtitle: "Petri Medium Cyclus", color: MycoTheme.blue)
                                }
                                
                                // Climate Status Readout
                                Button {
                                    let t = store.db.environmentConfig.currentTempC ?? 0.0
                                    let h = store.db.environmentConfig.currentHumidityPct ?? 0.0
                                    let vpd = MycoVPDCalculator.analyze(tempC: t, humidityPct: h)?.vpdKPa ?? 0.0
                                    let msg = "Klimaat: \(Int(h))% RV, \(String(format: "%.1f", t))°C, VPD \(String(format: "%.2f", vpd)) kPa"
                                    voiceMgr.speak(msg)
                                } label: {
                                    sterileBigTile(icon: "waveform.badge.magnifyingglass", title: "Klimaat Status", subtitle: "Verbaal Rapport", color: MycoTheme.green)
                                }
                                
                                // 10 Min SAB Settling Timer
                                Button {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("MycoLabStartLabTimerFromVoice"),
                                        object: nil,
                                        userInfo: ["minutes": 10, "title": "Still Air Box Bezinning"]
                                    )
                                    voiceMgr.speak("10 minuten stilstand timer gestart voor rustige lucht")
                                } label: {
                                    sterileBigTile(icon: "wind", title: "10 min SAB Rust", subtitle: "Luchtdeeltjes Bezinning", color: Color.purple)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Recent Sterile Voice Notes
                        if !voiceMgr.recentCleanroomNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(store.t(nl: "STERIELE SESSIE NOTITIES", en: "STERILE SESSION NOTES"))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(MycoTheme.textSecondary)
                                
                                ForEach(voiceMgr.recentCleanroomNotes, id: \.self) { note in
                                    HStack(spacing: 8) {
                                        Image(systemName: "note.text")
                                            .foregroundColor(MycoTheme.blue)
                                            .font(.system(size: 13))
                                        Text(note)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(nl: "Klaar", en: "Done")) {
                        voiceMgr.stopListening()
                        dismiss()
                    }
                    .foregroundColor(MycoTheme.blue)
                }
            }
        }
        .onAppear {
            voiceMgr.checkPermissions()
            voiceMgr.startListening()
        }
        .onDisappear {
            voiceMgr.stopListening()
        }
    }
    
    private func aiSuggestionChip(text: String, command: String) -> some View {
        Button {
            voiceMgr.processVoiceCommand(command)
        } label: {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.cyan.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func sterileBigTile(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(MycoTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(hex: "131821"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MycoTheme.border, lineWidth: 1)
        )
    }
}
