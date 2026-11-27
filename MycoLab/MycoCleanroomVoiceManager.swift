//
//  MycoCleanroomVoiceManager.swift
//  MycoLab
//
//  Hands-Free Cleanroom & Flow Hood Voice Assistant:
//  - Fully local Speech Recognition via SFSpeechRecognizer & AVAudioEngine
//  - Verbal voice feedback via AVSpeechSynthesizer with feedback-loop suppression
//  - Hands-free command routing: timers, notes, climate telemetry & device controls
//  - Auto-recovering listening session: stays alive during silence pauses
//

import Foundation
import SwiftUI
import Speech
import AVFoundation
import Combine

@MainActor
public final class MycoCleanroomVoiceManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = MycoCleanroomVoiceManager()
    
    // MARK: - Published Properties
    @Published public var isListening: Bool = false
    @Published public var isPermissionGranted: Bool = false
    @Published public var currentTranscript: String = ""
    @Published public var lastExecutedCommand: String = ""
    @Published public var assistantStatusMessage: String = "Tap microphone or speak cleanroom command"
    @Published public var recentCleanroomNotes: [String] = []
    @Published public var lastRecognizedIntentLabel: String = ""
    @Published public var audioLevel: Float = 0.0
    
    // MARK: - Private Speech Engine State
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private var isAudioEngineRunning = false
    private var isSynthesizerSpeaking = false
    private var commandDebounceTimer: Timer?
    private var lastProcessedCommandTime: Date = .distantPast
    private var restartRetryCount = 0
    
    private override init() {
        super.init()
        self.speechSynthesizer.delegate = self
        configureRecognizerLocale()
        checkPermissions()
    }
    
    private func configureRecognizerLocale() {
        // Try Dutch first, fallback to device locale, then US English
        let preferLocale = (MycoStore.shared?.isEnglish ?? true) ? "en-US" : "nl-NL"
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: preferLocale))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            ?? SFSpeechRecognizer(locale: Locale.current)
    }
    
    // MARK: - Permissions
    public func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            Task { @MainActor in
                switch authStatus {
                case .authorized:
                    if #available(iOS 17.0, *) {
                        AVAudioApplication.requestRecordPermission { granted in
                            Task { @MainActor in
                                self?.isPermissionGranted = granted
                            }
                        }
                    } else {
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            Task { @MainActor in
                                self?.isPermissionGranted = granted
                            }
                        }
                    }
                default:
                    self?.isPermissionGranted = false
                }
            }
        }
    }
    
    // MARK: - Start / Stop / Toggle Controls
    public func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    public func startListening() {
        guard !isListening else { return }
        isListening = true
        assistantStatusMessage = "Hands-free microfoon actief..."
        startEngineAndRecognitionSession()
    }
    
    public func stopListening() {
        isListening = false
        commandDebounceTimer?.invalidate()
        commandDebounceTimer = nil
        stopAudioEngineOnly()
        currentTranscript = ""
        audioLevel = 0.0
        assistantStatusMessage = "Microfoon gepauzeerd"
    }
    
    // MARK: - Engine Session Management
    private func startEngineAndRecognitionSession() {
        guard isListening else { return }
        
        // Teardown any lingering tasks
        stopAudioEngineOnly()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            assistantStatusMessage = "Kon audio-sessie niet configureren: \(error.localizedDescription)"
            isListening = false
            return
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Suppress audio input when assistant is speaking aloud to avoid acoustic feedback
            if self.isSynthesizerSpeaking {
                return
            }
            
            self.recognitionRequest?.append(buffer)
            
            // Audio level metering
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            var sum: Float = 0
            for sample in channelDataArray {
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(buffer.frameLength))
            let level = max(0.0, min(1.0, rms * 5.0))
            Task { @MainActor in
                self.audioLevel = level
            }
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isAudioEngineRunning = true
            restartRetryCount = 0
            assistantStatusMessage = "Cleanroom Assistant luistert..."
        } catch {
            assistantStatusMessage = "Microfoon fout: \(error.localizedDescription)"
            isListening = false
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Disregard if synthesizer was speaking
                if self.isSynthesizerSpeaking { return }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    self.currentTranscript = text
                    self.scheduleDebouncedParse(text: text, isFinal: result.isFinal)
                }
                
                if error != nil || (result?.isFinal ?? false) {
                    self.handleSessionTermination()
                }
            }
        }
    }
    
    private func stopAudioEngineOnly() {
        if isAudioEngineRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            isAudioEngineRunning = false
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func handleSessionTermination() {
        guard isListening else { return }
        stopAudioEngineOnly()
        
        // Auto-restart session cleanly after short backoff if user wants to keep listening
        restartRetryCount += 1
        let delay = restartRetryCount > 5 ? 1.0 : 0.25
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isListening else { return }
            self.startEngineAndRecognitionSession()
        }
    }
    
    // MARK: - Debounced Command Parser
    private func scheduleDebouncedParse(text: String, isFinal: Bool) {
        commandDebounceTimer?.invalidate()
        
        if isFinal {
            self.parseVoiceCommand(text)
            return
        }
        
        // Wait 0.75s after last word before committing the command
        commandDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.parseVoiceCommand(text)
            }
        }
    }
    
    public func processVoiceCommand(_ raw: String) {
        lastProcessedCommandTime = .distantPast
        parseVoiceCommand(raw)
    }

    private func parseVoiceCommand(_ raw: String) {
        guard !isSynthesizerSpeaking else { return }
        
        // Prevent rapid duplicate executions within 2.5 seconds
        guard Date().timeIntervalSince(lastProcessedCommandTime) > 2.5 else { return }
        
        let intent = MycoCleanroomAIIntentEngine.shared.interpret(spokenText: raw)
        
        switch intent {
        case .startTimer(let minutes, let title, let isDefaultFallback):
            lastProcessedCommandTime = Date()
            NotificationCenter.default.post(
                name: NSNotification.Name("MycoLabStartLabTimerFromVoice"),
                object: nil,
                userInfo: ["minutes": minutes, "title": title]
            )
            lastRecognizedIntentLabel = "⏱️ \(title): \(minutes) min"
            let confirm = isDefaultFallback
                ? "\(title) started for the default \(minutes) minutes."
                : "Timer for \(minutes) minutes started: \(title)."
            lastExecutedCommand = confirm
            speak(confirm)
            
        case .stopTimer:
            lastProcessedCommandTime = Date()
            NotificationCenter.default.post(
                name: NSNotification.Name("MycoLabStopLabTimerFromVoice"),
                object: nil
            )
            lastRecognizedIntentLabel = "⏹️ Timer Stopped"
            let confirm = "The active timer has been stopped."
            lastExecutedCommand = confirm
            speak(confirm)
            
        case .controlDevice(let deviceType, let turnOn):
            guard let store = MycoStore.shared else { return }
            if let dev = store.db.smartDevices.first(where: { $0.deviceType.lowercased() == deviceType.lowercased() }) {
                lastProcessedCommandTime = Date()
                if dev.isManualOnly {
                    let actionText = (deviceType == "Humidifier")
                        ? "Give 3 to 4 fine mist sprays to your grow tub."
                        : "Ventilate your tent or crack the tub lid for 5 minutes."
                    lastRecognizedIntentLabel = "✋ \(dev.name) (Manual)"
                    let msg = "You have a manual setup for \(dev.name). \(actionText)"
                    lastExecutedCommand = msg
                    speak(msg)
                    return
                }
                if dev.isOn != turnOn {
                    store.toggleSmartDevice(id: dev.id)
                }
                let stateWord = turnOn ? "turned on" : "turned off"
                lastRecognizedIntentLabel = "⚡️ \(dev.name) \(stateWord)"
                let msg = "\(dev.name) is now \(stateWord)."
                lastExecutedCommand = msg
                speak(msg)
            } else {
                lastProcessedCommandTime = Date()
                let msg = "No linked \(deviceType) found in the Smart Hub."
                lastExecutedCommand = msg
                speak(msg)
            }
            
        case .stopAllDevices:
            guard let store = MycoStore.shared else { return }
            lastProcessedCommandTime = Date()
            var count = 0
            for dev in store.db.smartDevices where dev.isOn {
                store.toggleSmartDevice(id: dev.id)
                count += 1
            }
            lastRecognizedIntentLabel = "🛑 Emergency Stop: All devices off"
            let msg = count > 0 ? "All \(count) active devices have been shut off." : "All devices were already off."
            lastExecutedCommand = msg
            speak(msg)
            

        case .logHarvest(let grams):
            guard let store = MycoStore.shared else { return }
            lastProcessedCommandTime = Date()
            
            let activeProjects = store.db.projects.filter { !$0.isArchived && $0.phase != .archived && $0.phase != .contaminated }
            let targetProject = activeProjects.first(where: { $0.phase == .fruiting || $0.phase == .flushing })
                ?? activeProjects.first
            
            if let project = targetProject {
                let existingFlushes = store.db.harvests.filter { $0.projectID == project.id }
                let flushNum = existingFlushes.count + 1
                let dryEst = grams * 0.08
                
                let harvest = HarvestRecord(
                    id: UUID(),
                    projectID: project.id,
                    strainName: project.strainName,
                    skuCode: project.skuCode,
                    flushNumber: flushNum,
                    harvestDate: Date(),
                    wetWeightGrams: grams,
                    dehydratorTempC: 50.0,
                    dehydratorHours: 12.0,
                    dryWeightGrams: dryEst,
                    notes: "Hands-free via Cleanroom Voice Assistant"
                )
                store.db.harvests.append(harvest)
                
                let log = GrowLog(
                    id: UUID(),
                    projectID: project.id,
                    timestamp: Date(),
                    actionType: "Harvest (Voice)",
                    temperatureC: store.db.environmentConfig.currentTempC,
                    humidityPct: store.db.environmentConfig.currentHumidityPct,
                    notes: "Flush #\(flushNum) harvested: \(String(format: "%.1f", grams))g wet (est dry: \(String(format: "%.1f", dryEst))g)"
                )
                store.db.logs.append(log)
                store.saveImmediately()
                
                MycoLiveActivityManager.shared.startOrUpdateLiveActivity(
                    batchName: project.strainName,
                    phaseName: "Flush #\(flushNum)",
                    dayCount: max(Calendar.current.dateComponents([.day], from: project.startDate, to: Date()).day ?? 1, 1),
                    tempC: store.db.environmentConfig.currentTempC ?? 23.5,
                    humidityPct: store.db.environmentConfig.currentHumidityPct ?? 90.0,
                    vpdKpa: store.currentVpdKpa,
                    statusSummary: "Harvest logged: \(Int(grams))g"
                )
                
                lastRecognizedIntentLabel = "🍄 Harvest: \(Int(grams))g (Flush #\(flushNum))"
                let msg = "Logged harvest of \(Int(grams)) grams as Flush \(flushNum) for \(project.strainName)!"
                lastExecutedCommand = msg
                speak(msg)
            } else {
                lastRecognizedIntentLabel = "🍄 No active batch"
                let msg = "Logged \(Int(grams)) grams, but no active cultivation batch was found."
                lastExecutedCommand = msg
                speak(msg)
            }

        case .togglePinningTrigger(let enable):
            guard let store = MycoStore.shared else { return }
            lastProcessedCommandTime = Date()
            store.db.environmentConfig.isPinningInductionActive = enable
            store.saveImmediately()
            
            lastRecognizedIntentLabel = enable ? "❄️ Pinning Trigger AAN" : "🌤️ Pinning Trigger UIT"
            let msg = enable
                ? (store.isEnglish ? "Pinning trigger activated. Target dropped to 18.5 degrees and FAE doubled." : "Pinning trigger geactiveerd. Doeltemperatuur verlaagd naar 18.5 graden en ventilatie verdubbeld.")
                : (store.isEnglish ? "Pinning trigger deactivated. Restored regular day and night schedule." : "Pinning trigger uitgeschakeld. Regulier dag en nachtklimaat hersteld.")
            lastExecutedCommand = msg
            speak(msg)

        case .controlCameraSleep(let putToSleep):
            guard let store = MycoStore.shared else { return }
            lastProcessedCommandTime = Date()
            let liveKitManager = LiveKitStreamManager.shared
            let isConnected = liveKitManager.isConnected || liveKitManager.localVideoTrack != nil || liveKitManager.remoteVideoTrack != nil || store.db.environmentConfig.effectiveCameraSource != .none
            let hasScreen = liveKitManager.currentRemoteCameraHasScreen
            let camName = liveKitManager.connectedCameraDisplayName
            
            if !isConnected {
                lastRecognizedIntentLabel = "📷 Geen Camera"
                let msg = store.isEnglish
                    ? "No camera is currently connected to MycoLabs."
                    : "Er is momenteel geen camera verbonden met MycoLabs."
                lastExecutedCommand = msg
                speak(msg)
            } else if !hasScreen {
                lastRecognizedIntentLabel = "📷 Geen Scherm (Headless)"
                let msg = store.isEnglish
                    ? "The connected camera (\(camName)) is a screenless dedicated camera. It has no physical display to sleep or dim."
                    : "De verbonden camera (\(camName)) is een externe camera zonder beeldscherm. Er is geen fysiek display om te dimmen."
                lastExecutedCommand = msg
                speak(msg)
            } else {
                let shouldSleep = putToSleep ?? !liveKitManager.isRemoteScreenDimmed
                if shouldSleep {
                    liveKitManager.sendDataCommand(command: "screen:sleep:on")
                    liveKitManager.isRemoteScreenDimmed = true
                    lastRecognizedIntentLabel = "🌙 Scherm Spaarstand AAN"
                    let msg = store.isEnglish
                        ? "Grow camera display set to OLED standby mode."
                        : "Kweekcamera scherm in OLED spaarstand gezet."
                    lastExecutedCommand = msg
                    speak(msg)
                } else {
                    liveKitManager.sendDataCommand(command: "screen:sleep:off")
                    liveKitManager.isRemoteScreenDimmed = false
                    lastRecognizedIntentLabel = "☀️ Scherm Gewekt"
                    let msg = store.isEnglish
                        ? "Grow camera display awakened from standby."
                        : "Kweekcamera scherm gewekt uit spaarstand."
                    lastExecutedCommand = msg
                    speak(msg)
                }
            }

        case .queryCameraCapabilities:
            guard let store = MycoStore.shared else { return }
            lastProcessedCommandTime = Date()
            let liveKitManager = LiveKitStreamManager.shared
            let hasScreen = liveKitManager.currentRemoteCameraHasScreen
            let camName = liveKitManager.connectedCameraDisplayName
            lastRecognizedIntentLabel = "📷 Camera Eigenschappen"
            let msg: String
            if hasScreen {
                msg = store.isEnglish
                    ? "The connected \(camName) has an active display and supports remote OLED sleep mode, torch, and multi-lens capture."
                    : "De verbonden \(camName) heeft een beeldscherm en ondersteunt OLED-spaarstand, zaklamp en meervoudige lenzen."
            } else {
                msg = store.isEnglish
                    ? "The connected \(camName) is a dedicated screenless camera lens without a display."
                    : "De verbonden \(camName) is een externe camera zonder beeldscherm. Schermknoppen zijn automatisch verborgen."
            }
            lastExecutedCommand = msg
            speak(msg)

        case .queryClimate(let aspect):
            guard let store = MycoStore.shared else { return }
            lastProcessedCommandTime = Date()
            let t = store.db.environmentConfig.currentTempC
            let h = store.db.environmentConfig.currentHumidityPct
            
            if let t = t, let h = h {
                let vpd = MycoVPDCalculator.analyze(tempC: t, humidityPct: h)
                let vpdVal = vpd.map { String(format: "%.2f", $0.vpdKPa) } ?? ""
                let dewVal = vpd.map { String(format: "%.1f", $0.dewPointC) } ?? ""
                
                var answer = ""
                switch aspect {
                case .temperature:
                    let comment = t < 20.0 ? "That is slightly on the cool side." : (t > 26.0 ? "That is on the warm side." : "Temperature is ideal.")
                    answer = "It is currently \(String(format: "%.1f", t)) degrees Celsius. \(comment)"
                case .humidity:
                    let comment = h >= 85.0 ? "Optimal for fruiting." : "Humidity could be raised slightly for fruiting."
                    answer = "Relative humidity is \(Int(h)) percent. \(comment)"
                case .vpd:
                    let advice = vpd?.summaryEN ?? ""
                    answer = "Vapor pressure deficit is \(vpdVal) kiloPascals. \(advice)"
                case .dewPoint:
                    answer = "The dew point is \(dewVal) degrees Celsius."
                case .general:
                    answer = "The temperature is \(String(format: "%.1f", t)) degrees at \(Int(h)) percent humidity. VPD is \(vpdVal) kiloPascals."
                }
                lastRecognizedIntentLabel = "🌡️ Climate Status"
                lastExecutedCommand = answer
                speak(answer)
            } else {
                let msg = "There is currently no active sensor telemetry available."
                lastExecutedCommand = msg
                speak(msg)
            }
            
        case .queryBatches:
            guard let store = MycoStore.shared else { return }
            lastProcessedCommandTime = Date()
            let active = store.db.projects.filter { !$0.isArchived }
            if active.isEmpty {
                let msg = "There are no active cultivation batches right now."
                lastRecognizedIntentLabel = "📦 No active batches"
                lastExecutedCommand = msg
                speak(msg)
            } else {
                let names = active.prefix(3).map { "\($0.strainName) in \($0.phase.rawValue)" }.joined(separator: ", ")
                let msg = "You have \(active.count) active \(active.count == 1 ? "batch" : "batches"): \(names)."
                lastRecognizedIntentLabel = "📦 \(active.count) active batches"
                lastExecutedCommand = msg
                speak(msg)
            }
            
        case .askAdvisor(let topic, _):
            lastProcessedCommandTime = Date()
            let (label, reply) = generateAdvisorReply(for: topic, store: MycoStore.shared)
            lastRecognizedIntentLabel = label
            lastExecutedCommand = reply
            speak(reply)
            
        case .logSterileNote(let category, let cleanSummary):
            lastProcessedCommandTime = Date()
            let timeStr = Date().formatted(date: .omitted, time: .shortened)
            let entry = "[\(category.rawValue) • \(timeStr)] \(cleanSummary)"
            recentCleanroomNotes.insert(entry, at: 0)
            lastRecognizedIntentLabel = "\(category.icon) \(category.rawValue)"
            
            var batchContextSpoken = ""
            if let store = MycoStore.shared {
                let lower = cleanSummary.lowercased()
                if let match = lower.range(of: "batch ") {
                    let suffix = lower[match.upperBound...]
                    if let firstChar = suffix.first, let num = Int(String(firstChar)) {
                        if let idx = store.db.projects.firstIndex(where: { $0.batchNumber == num }) {
                            if !store.db.projects[idx].sterilizationNotes.isEmpty {
                                store.db.projects[idx].sterilizationNotes += "\n"
                            }
                            store.db.projects[idx].sterilizationNotes += "[\(timeStr)] \(cleanSummary)"
                            store.save()
                            batchContextSpoken = " for batch \(num)"
                        }
                    }
                } else if let firstActive = store.db.projects.first(where: { !$0.isArchived }) {
                    if let idx = store.db.projects.firstIndex(where: { $0.id == firstActive.id }) {
                        if !store.db.projects[idx].sterilizationNotes.isEmpty {
                            store.db.projects[idx].sterilizationNotes += "\n"
                        }
                        store.db.projects[idx].sterilizationNotes += "[\(timeStr)] \(cleanSummary)"
                        store.save()
                        batchContextSpoken = " for batch \(firstActive.batchNumber)"
                    }
                }
            }
            
            let confirm: String
            switch category {
            case .contamination:
                confirm = "Warning: contamination alert recorded\(batchContextSpoken) in sterile logbook."
            case .inoculation:
                confirm = "Inoculation recorded\(batchContextSpoken) in sterile logbook."
            case .pinning:
                confirm = "Primordia observation recorded\(batchContextSpoken)."
            case .harvest:
                confirm = "Harvest recorded\(batchContextSpoken)."
            case .general:
                confirm = "Observation saved\(batchContextSpoken) in sterile logbook."
            }
            lastExecutedCommand = "\(category.rawValue): \(cleanSummary)"
            speak(confirm)
            
        case .requestHelp:
            lastProcessedCommandTime = Date()
            lastRecognizedIntentLabel = "💡 Voice Help"
            let msg = "You can speak naturally. For example: autoclave timer, turn on the humidifier, how warm is it, or log transfer to jar two."
            lastExecutedCommand = msg
            speak(msg)
            
        case .conversationalGreeting:
            lastProcessedCommandTime = Date()
            lastRecognizedIntentLabel = "👋 Hello MycoLabs"
            let msg = "Hello! Cleanroom flowhood voice assistant is listening."
            lastExecutedCommand = msg
            speak(msg)
            
        case .unhandled:
            // Do NOT save arbitrary speech as notes or speak aloud, preventing feedback loops!
            break
        }
    }
    
    // MARK: - Advisor Engine Reply Generator
    private func generateAdvisorReply(for topic: MycoAdvisorTopic, store: MycoStore?) -> (String, String) {
        let isEnglish = store?.isEnglish ?? true
        switch topic {
        case .pinningConditions:
            let label = "🌱 Pinning Advice"
            let reply = isEnglish ?
                "For pinning, aim for 20 to 22 degrees Celsius with 90 to 95 percent humidity, fresh air exchange, and 12 hours of ambient light to trigger primordia." :
                "Voor pinning adviseren we 20 tot 22 graden Celsius met 90 tot 95 procent luchtvochtigheid, voldoende verse lucht en 12 uur indirect licht om knopvorming te stimuleren."
            return (label, reply)
            
        case .colonizationConditions:
            let label = "🧪 Colonization Advice"
            let reply = isEnglish ?
                "During colonization, keep jars or tubs between 23 and 25 degrees Celsius in darkness with minimal air exchange so CO2 stays elevated." :
                "Tijdens kolonisatie houd je de potten of kweekruimte tussen 23 en 25 graden Celsius in het donker, met minimale ventilatie zodat CO2 hoog blijft voor snelle myceliumgroei."
            return (label, reply)
            
        case .fruitingConditions:
            let label = "🍄 Fruiting Conditions"
            let reply = isEnglish ?
                "For fruiting, maintain 21 to 24 degrees Celsius, 88 to 92 percent humidity, and regular FAE to keep CO2 below 1000 ppm." :
                "Voor vruchtvorming richt je op 21 tot 24 graden Celsius, 88 tot 92 procent luchtvochtigheid en regelmatige ventilatie om CO2 onder 1000 ppm te houden."
            return (label, reply)
            
        case .substrateWaterRatio(let coirGrams):
            let label = "💧 Substrate Calculator"
            let liters = coirGrams * 0.005
            let litersStr = String(format: "%.1f", liters)
            let reply = isEnglish ?
                "For \(Int(coirGrams)) grams of coco coir, add approximately \(litersStr) liters of boiling water for field capacity. Squeeze a handful firmly: only one drop should escape." :
                "Voor \(Int(coirGrams)) gram kokosvezel voeg je ongeveer \(litersStr) liter kokend water toe voor field capacity. Knijp een handvol stevig uit: er mag slechts één druppel tussen je vingers doorkomen."
            return (label, reply)
            
        case .contaminationCheck(let type):
            let label = "⚠️ Contamination Advice"
            let reply: String
            if type == "trichoderma" {
                reply = isEnglish ?
                    "Green mold indicates Trichoderma. Never open the container inside your cleanroom, as spores spread instantly. Isolate the container outside immediately." :
                    "Groene schimmel duidt op Trichoderma. Open de bak of pot nooit binnen je kweekruimte, want de sporen verspreiden razendsnel. Isoleer de container direct buiten het lab."
            } else if type == "cobweb" {
                reply = isEnglish ?
                    "Cobweb mold grows very fast like grey cotton. A light misting of 3 percent hydrogen peroxide can dissolve cobweb without harming mushroom mycelium." :
                    "Cobweb schimmel groeit heel snel als grijsachtige watten. Een lichte nevel van 3 procent waterstofperoxide kan cobweb oplossen zonder het gezonde mycelium te beschadigen."
            } else {
                reply = isEnglish ?
                    "Check for sweet mushroom aroma versus sour or foul smells. Healthy mycelium is solid white, never green, bright yellow, or grey." :
                    "Let op de geur: gezond mycelium ruikt aards en zoet. Zure of rotte geuren en afwijkende kleuren zoals groen of felgeel duiden op besmetting."
            }
            return (label, reply)
            
        case .harvestTiming:
            let label = "✂️ Harvest Timing"
            let reply = isEnglish ?
                "Harvest right when the veil beneath the mushroom cap starts to stretch and tear. If the cap flattens completely and drops dark spores, fruit quality declines." :
                "Oogst precies op het moment dat het vliesje onder de hoed begint op te rekken en net scheurt. Als de hoed helemaal openklapt en sporen laat vallen, stopt de groei en worden de hoeden zwart."
            return (label, reply)
            
        case .generalAdvice:
            let label = "🧠 Myco Advice"
            let reply = isEnglish ?
                "Keep temperature and humidity stable according to your current phase. Check dashboard metrics for real-time VPD." :
                "Houd temperatuur en luchtvochtigheid stabiel passend bij de kweekfase. Bekijk het dashboard voor actuele VPD status."
            return (label, reply)
        }
    }
    
    // MARK: - Speech Output & Feedback Loop Suppression
    public func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        let langCode = (MycoStore.shared?.isEnglish ?? true) ? "en-US" : "nl-NL"
        utterance.voice = AVSpeechSynthesisVoice(language: langCode) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        
        // Mark synthesizer as active so recognizer drops acoustic feedback
        isSynthesizerSpeaking = true
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSynthesizerSpeaking = true
        }
    }
    
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Add slight 350ms buffer for room reverberation to settle
            try? await Task.sleep(nanoseconds: 350_000_000)
            self.isSynthesizerSpeaking = false
        }
    }
    
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSynthesizerSpeaking = false
        }
    }
}
