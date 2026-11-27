//
//  ModernToolsAndPresetsTabView.swift
//  MycoLab
//
//  Modern Living Lab Tools & Presets Hub:
//  - Clean Bento architecture grouping Calculators, Hardware, Timers & Presets
//  - Living countdown timer ring with real-time breathing visuals
//  - Connected Tuya & Cam telemetry status indicators
//  - 100% reversible: instant toggle to Classic Tools view
//

import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - STATIC LAB BADGE COMPONENT (NO FLICKER / CLEAN)
struct StaticLabFlameBadge: View {
    var size: CGFloat = 30
    var iconName: String = "timer"
    var color: Color = MycoTheme.amber
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: size, height: size)
            Image(systemName: iconName)
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundColor(color)
        }
    }
}

struct ModernToolsAndPresetsTabView: View {
    @EnvironmentObject var store: MycoStore
    
    // Calculator Selection (0: Substraat & CVG, 1: AI Recept, 2: Agar & LC, 3: Dosering)
    @State private var activeCalculatorIndex: Int = 0
    
    // Hardware & Sheets
    @State private var showSmartEnvironmentHub = false
    @State private var showRemoteMonitor = false
    @State private var showSpaceCalculator = false
    @State private var showMaintenanceSheet = false
    @State private var showCalculatorsSheet = false
    @State private var showQRArchive = false
    @State private var showOpticalHygrometerSheet = false
    @State private var showZoneSetupSheet = false
    @State private var showCleanroomVoiceSheet = false
    @State private var showAdvancedClimateSettings = false
    @State private var showPiHubVideoArchive = false
    @State private var isSyncingToPi = false
    @State private var showCreateBatchSheetFromCalc = false
    @State private var showSettings = false
    @State private var editingPreset: UserPreset? = nil
    @State private var showAddPreparationRecipe = false
    @State private var editingPreparationRecipe: PreparationRecipe? = nil
    @State private var viewingPreparationRecipe: PreparationRecipe? = nil
    @State private var batchRecipeToStart: PreparationRecipe? = nil
    @State private var batchRecipeMultiplier: Int = 1
    @State private var showUserTestingAgentSheet = false
    @State private var showAICommandCenter = false
    @State private var savedRecipeBanner: String? = nil
    
    // Substrate & CVG Calculator State
    @State private var substrateMode: Int = 0 // 0: Grammen, 1: Liters, 2: Blokken
    @State private var coirGrams: Double = 650
    @State private var coirInputText: String = ""
    @State private var targetSubstrateLiters: Double = 8.5
    @State private var targetLitersText: String = ""
    @State private var hydrationRatio: Double = 5.0
    @State private var spawnAmountInput: String = ""
    @State private var spawnRatioVal: Double = 2.0
    
    // LC & Agar Media Calculator State
    @State private var waterVolumeML: Double = 500
    @State private var waterVolumeText: String = ""
    @State private var mediaKind: String = "Agar"
    
    // Dosage Calculator State
    @State private var isFreshWet: Bool = false
    @State private var potencyFactor: Double = 1.0
    @State private var targetIntensityBaseGrams: Double = 1.5
    @State private var daysSinceLastDose: Double = 14
    
    // AI Recipe State
    @State private var aiCategory: MycoAIRecipeEngine.RecipeCategory = .substrate
    @State private var aiBatchSize: Double = 10.0
    @State private var aiBatchSizeText: String = "10"
    @State private var aiCalculationResult: AIRecipeResult? = nil
    
    // Presets Manager State
    @State private var newPresetName = ""
    @State private var newPresetCat: PresetCategory = .container
    @State private var selectedPresetCategoryFilter: PresetCategory? = nil
    
    // Top Section Selector: 0: Apparaten & Tools, 1: Calculators, 2: Recepten & Presets
    @State private var selectedTabSection: Int = 0
    
    // Timer State
    @State private var customTimerMinutesText = ""
    @State private var customTimerLabel = ""
    @State private var showCustomTimerSheet = false
    
    private var activeSmartDevicesCount: Int {
        store.db.smartDevices.filter { $0.autoControlEnabled }.count
    }
    
    private var totalActiveQRsCount: Int {
        store.db.projects.filter { !$0.qrCodeID.isEmpty }.count
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    
                    // MARK: - 1. Serene Hub Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.db.stealthMode ? "LabOS Suite" : store.t(nl: "Lab Hub & Presets", en: "Lab Hub & Presets"))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(activeSmartDevicesCount > 0 ? MycoTheme.green : MycoTheme.textSecondary)
                                        .frame(width: 6, height: 6)
                                    Text(store.t(nl: "\(activeSmartDevicesCount) apparaten", en: "\(activeSmartDevicesCount) devices"))
                                }
                                Text("•")
                                    .foregroundColor(MycoTheme.textSecondary)
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 10))
                                    Text(store.t(nl: "\(store.db.timers.count) actieve timers", en: "\(store.db.timers.count) active timers"))
                                }
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(MycoTheme.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                    
                    // Toast / Confirmation Banner for Saved Recipes
                    if let banner = savedRecipeBanner {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(MycoTheme.green)
                            Text(banner)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(MycoTheme.green.opacity(0.18))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MycoTheme.green.opacity(0.4), lineWidth: 1))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // MARK: - 2. Top Segment Selector
                    sectionSelectorBar
                    
                    // MARK: - 3. Tab Contents
                    if selectedTabSection == 0 {
                        // 1. Lab Apparaten & Hardware (Physical Devices)
                        labDevicesBentoGrid
                        
                        // 2. Cleanroom AI & Geavanceerde Systeem Hub (CENTRALE MATRIX)
                        cleanroomAIAndAdvancedSystemCentralCard
                        
                        // Living Sterilization & Lab Timers
                        livingSterilizationTimersCard
                        
                        // QR Code Studio & Print Launcher
                        qrStudioLauncherCard
                    } else if selectedTabSection == 1 {
                        // Myco Calculators Suite
                        calculatorsSuiteSection
                    } else {
                        // Bereidingsrecepten & Ingrediënten Manager
                        modernPreparationRecipesCard
                        
                        // Presets & Hardwaresetups
                        modernPresetsManagerCard
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(16)
                .padding(.bottom, 60)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showCleanroomVoiceSheet = true
                        } label: {
                            Image(systemName: "waveform.and.mic")
                                .font(.system(size: 16))
                                .foregroundColor(Color.cyan)
                        }
                        .accessibilityLabel("Cleanroom Voice Assistant")
                        
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .sheet(item: $editingPreset) { p in
                EditUserPresetSheetView(preset: p)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showAddPreparationRecipe) {
                AddPreparationRecipeSheetView()
                    .environmentObject(store)
            }
            .sheet(item: $editingPreparationRecipe) { recipe in
                EditPreparationRecipeSheetView(recipe: recipe)
                    .environmentObject(store)
            }
            .sheet(item: $viewingPreparationRecipe) { recipe in
                PreparationRecipeDetailSheetView(
                    recipe: recipe,
                    onStartBatch: { rec, mult in
                        batchRecipeMultiplier = mult
                        batchRecipeToStart = rec
                    },
                    onEdit: { rec in
                        editingPreparationRecipe = rec
                    }
                )
                .environmentObject(store)
            }
            .sheet(item: $batchRecipeToStart) { rec in
                NavigationStack {
                    CreateBatchSheetView(
                        initialSubstrateName: rec.substrateName,
                        initialDryWeight: rec.drySubstrateWeightGrams > 0 ? String(format: "%.0f", rec.drySubstrateWeightGrams * Double(batchRecipeMultiplier)) : "650",
                        initialRecipeID: rec.id
                    )
                    .environmentObject(store)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheetView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showSmartEnvironmentHub) {
                SmartEnvironmentHubView().environmentObject(store)
            }
            .sheet(isPresented: $showRemoteMonitor) {
                RemoteLabMonitorView().environmentObject(store)
            }
            .sheet(isPresented: $showSpaceCalculator) {
                GrowSpaceSizeAndAIClimateView().environmentObject(store)
            }
            .sheet(isPresented: $showMaintenanceSheet) {
                MaintenanceModeSheet().environmentObject(store)
            }
            .sheet(isPresented: $showAdvancedClimateSettings) {
                NavigationStack {
                    AdvancedClimateAndLabSettingsSubmenuView()
                        .environmentObject(store)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(store.t(nl: "Gereed", en: "Done")) {
                                    showAdvancedClimateSettings = false
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(MycoTheme.blue)
                            }
                        }
                }
            }
            .sheet(isPresented: $showPiHubVideoArchive) {
                TimelapseGallerySheet(initialTab: .piHubArchive)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showUserTestingAgentSheet) {
                MycoUserTestingAgentSheet(store: store)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showAICommandCenter) {
                NavigationStack {
                    MycoAIAutomationCommandCenterView()
                        .environmentObject(store)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(store.t(nl: "Sluiten", en: "Close")) {
                                    showAICommandCenter = false
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color.cyan)
                            }
                        }
                }
            }
            .sheet(isPresented: $showCalculatorsSheet) {
                NavigationStack {
                    ScrollView {
                        calculatorsSuiteSection
                            .padding(16)
                    }
                    .background(MycoTheme.bg.ignoresSafeArea())
                    .navigationTitle(store.t(nl: "Myco Calculators", en: "Myco Calculators"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(store.t(nl: "Gereed", en: "Done")) {
                                showCalculatorsSheet = false
                            }
                            .foregroundColor(MycoTheme.blue)
                            .font(.system(size: 15, weight: .bold))
                        }
                    }
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showQRArchive) {
                QRCodeArchiveView().environmentObject(store)
            }
            .sheet(isPresented: $showOpticalHygrometerSheet) {
                MycoOpticalHygrometerView().environmentObject(store)
            }
            .sheet(isPresented: $showZoneSetupSheet) {
                OpticalMeterSetupSheet().environmentObject(store)
            }
            .sheet(isPresented: $showCleanroomVoiceSheet) {
                CleanroomVoiceConsoleView().environmentObject(store)
            }
            .sheet(isPresented: $showCreateBatchSheetFromCalc) {
                NavigationStack {
                    CreateBatchSheetView(
                        initialSubstrateName: "CVG Substraat (1:2)",
                        initialDryWeight: "\(Int(coirGrams))"
                    )
                    .environmentObject(store)
                }
            }
            .sheet(isPresented: $showCustomTimerSheet) {
                NavigationStack {
                    Form {
                        Section(
                            header: Text(store.t(nl: "Aangepaste Timer Instellen", en: "Set Custom Timer")),
                            footer: Text(store.t(
                                nl: "Geen vaste presets vooraf: vul zelf de gewenste timer-naam en minuten in.",
                                en: "No forced presets: enter your own custom timer name and minutes."
                            ))
                        ) {
                            TextField(store.t(nl: "Naam van de timer (bv. Snelkookpan)", en: "Timer Name (e.g. Pressure Cooker)"), text: $customTimerLabel)
                            HStack {
                                Text(store.t(nl: "Duur (minuten):", en: "Duration (minutes):"))
                                Spacer()
                                TextField(store.t(nl: "bijv. 90", en: "e.g. 90"), text: $customTimerMinutesText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                        }
                        
                        Section {
                            Button {
                                let mins = Int(customTimerMinutesText) ?? 90
                                let label = customTimerLabel.trimmingCharacters(in: .whitespaces).isEmpty ? store.t(nl: "Lab Timer", en: "Lab Timer") : customTimerLabel.trimmingCharacters(in: .whitespaces)
                                startTimer(label: label, minutes: mins)
                                showCustomTimerSheet = false
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "play.fill")
                                    Text(store.t(nl: "Start Aangepaste Timer", en: "Start Custom Timer"))
                                        .font(.headline)
                                        .foregroundColor(MycoTheme.green)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .navigationTitle(store.t(nl: "Eigen Timer Invullen", en: "Custom Timer"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(store.t(nl: "Annuleren", en: "Cancel")) {
                                showCustomTimerSheet = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - LIVING STERILIZATION TIMERS CARD
    private var livingSterilizationTimersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    StaticLabFlameBadge(size: 26, iconName: "timer")
                    Text(store.t(nl: "Sterilisatie & Lab Timers", en: "Sterilization & Lab Timers"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                
                if !store.db.timers.isEmpty {
                    Text(store.t(nl: "\(store.db.timers.count) Lopend", en: "\(store.db.timers.count) Running"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MycoTheme.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(MycoTheme.green.opacity(0.15))
                        .cornerRadius(8)
                }
            }
            
            // If active timers exist: show them with live animated countdown
            if !store.db.timers.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(store.db.timers.enumerated()), id: \.element.id) { idx, t in
                        HStack(spacing: 12) {
                            StaticLabFlameBadge(size: 32, iconName: "flame.fill", color: MycoTheme.amber)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("15 PSI (121°C) • \(t.totalMinutes) min")
                                    .font(.system(size: 10))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Realtime updating timer style
                            Text(t.endDate, style: .timer)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(MycoTheme.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(MycoTheme.green.opacity(0.12))
                                .cornerRadius(6)
                            
                            if !t.label.contains("Afkoelen") {
                                Button {
                                    startCooldownTimer(for: t)
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "snowflake")
                                            .font(.system(size: 8))
                                        Text(store.t(nl: "6u Afkoel", en: "6h Cool"))
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.cyan.opacity(0.14))
                                    .foregroundColor(Color.cyan)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button {
                                withAnimation {
                                    if idx < store.db.timers.count {
                                        store.db.timers.remove(at: idx)
                                        store.save()
                                    }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
                    }
                }
            }
            
            // 1-Tap Preset Timer Launchers or Custom Entry
            HStack {
                Text(store.t(nl: "Snel Starten of Zelf Instellen:", en: "Quick Start or Set Custom:"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(MycoTheme.textSecondary)
                Spacer()
                Button {
                    showCustomTimerSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(store.t(nl: "Zelf invullen", en: "Custom input"))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MycoTheme.blue)
                }
                .buttonStyle(.plain)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickTimerPill(name: "Graan 90m", minutes: 90, icon: "takeoutbag.and.cup.and.straw")
                    quickTimerPill(name: "Agar 45m", minutes: 45, icon: "flask.fill")
                    quickTimerPill(name: "LC 30m", minutes: 30, icon: "drop.fill")
                    quickTimerPill(name: "CVG 120m", minutes: 120, icon: "water.waves")
                    quickTimerPill(name: "Hout 150m", minutes: 150, icon: "leaf.fill")
                }
            }
        }
        .padding(14)
        .background(MycoTheme.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(MycoTheme.border, lineWidth: 1)
        )
    }
    
    private func quickTimerPill(name: String, minutes: Int, icon: String) -> some View {
        Button {
            startTimer(label: name, minutes: minutes)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(MycoTheme.amber)
                Text(name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.07))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    private func startTimer(label: String, minutes: Int) {
        let t = LabTimerItem(
            label: label,
            endDate: Date().addingTimeInterval(TimeInterval(minutes * 60)),
            totalMinutes: minutes
        )
        withAnimation {
            store.db.timers.append(t)
            store.save()
        }
        
        let isSterilization = minutes >= 30 && (label.contains("Graan") || label.contains("Agar") || label.contains("LC") || label.contains("CVG") || label.contains("Hout") || label.contains("Snelkookpan") || label.contains("Autoclaaf"))
        store.startDynamicIslandTimer(label: label, totalMinutes: minutes, notes: isSterilization ? "15 PSI • +6u Afkoeling" : "Lab Timer")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            
            // 1. Sterilization timer finished
            let content = UNMutableNotificationContent()
            content.title = isSterilization ? "🔥 Sterilisatie Voltooid (\(minutes)m)" : "⏱️ MycoLabs Timer Verstreken"
            content.body = isSterilization ? "De cyclus '\(label)' is klaar! Laat de snelkookpan gesloten en rustig afkoelen." : "De timer '\(label)' (\(minutes) min) is afgelopen!"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
            let request = UNNotificationRequest(identifier: t.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
            
            // 2. If sterilization, also schedule 6-hour cool-down alert (<25°C)
            if isSterilization {
                let coolContent = UNMutableNotificationContent()
                coolContent.title = "❄️ Substraat Veilig Afgekoeld (<25°C)"
                coolContent.body = "'\(label)' is afgekoeld naar kamertemperatuur. Het is nu veilig om te inoculeren!"
                coolContent.sound = .default
                let coolTrigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval((minutes * 60) + (6 * 3600)), repeats: false)
                let coolRequest = UNNotificationRequest(identifier: t.id.uuidString + "-cooldown", content: coolContent, trigger: coolTrigger)
                UNUserNotificationCenter.current().add(coolRequest)
            }
        }
    }
    
    private func startCooldownTimer(for timer: LabTimerItem) {
        let coolTimer = LabTimerItem(
            label: "❄️ Afkoelen: \(timer.label)",
            endDate: Date().addingTimeInterval(6 * 3600),
            totalMinutes: 360
        )
        withAnimation {
            store.db.timers.append(coolTimer)
            store.save()
        }
        store.startDynamicIslandTimer(label: "❄️ Afkoelen: \(timer.label)", totalMinutes: 360, notes: "Rustig afkoelen naar <25°C")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "❄️ Substraat Veilig Afgekoeld (<25°C)"
            content.body = "De inhoud van '\(timer.label)' is nu volledig op kamertemperatuur. Klaar om te inoculeren!"
            content.sound = .default
            let trig = UNTimeIntervalNotificationTrigger(timeInterval: 6 * 3600, repeats: false)
            let req = UNNotificationRequest(identifier: coolTimer.id.uuidString, content: content, trigger: trig)
            UNUserNotificationCenter.current().add(req)
        }
    }
    
    // MARK: - Section Selector Bar
    private var sectionSelectorBar: some View {
        HStack(spacing: 6) {
            sectionSelectorButton(title: store.t(nl: "Apparatuur", en: "Devices"), icon: "slider.horizontal.3", index: 0)
            sectionSelectorButton(title: store.t(nl: "Calculators", en: "Calculators"), icon: "function", index: 1)
            sectionSelectorButton(title: store.t(nl: "Recepten", en: "Recipes"), icon: "book.closed.fill", index: 2)
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    private func sectionSelectorButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTabSection = index
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: selectedTabSection == index ? .bold : .medium))
            }
            .foregroundColor(selectedTabSection == index ? .white : MycoTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedTabSection == index ? MycoTheme.blue : Color.clear)
            .cornerRadius(9)
        }
        .buttonStyle(.plain)
    }

    // MARK: - LAB APPARATEN & HARDWARE BENTO GRID (PHYSICAL DEVICES)
    private var labDevicesBentoGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.t(nl: "Lab Apparaten & Hardware", en: "Lab Devices & Hardware"))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(MycoTheme.textSecondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                // 1. Tuya Smart Hub
                Button {
                    showSmartEnvironmentHub = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(MycoTheme.green.opacity(0.18))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "powerplug.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(MycoTheme.green)
                            }
                            Spacer()
                            Circle()
                                .fill(activeSmartDevicesCount > 0 ? MycoTheme.green : MycoTheme.textSecondary)
                                .frame(width: 7, height: 7)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Smart Hardware Hub", en: "Smart Hardware Hub"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text(store.t(nl: "\(activeSmartDevicesCount) actief gekoppeld", en: "\(activeSmartDevicesCount) actively paired"))
                                .font(.system(size: 10))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
                
                // 2. Kweekcamera Stream
                Button {
                    showRemoteMonitor = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.teal.opacity(0.18))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "video.badge.waveform.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.teal)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Kweekcamera", en: "Grow Camera"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text(store.t(nl: "Live monitor & audio", en: "Live monitor & audio"))
                                .font(.system(size: 10))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // 3. Onderhoudsmodus (Veilig werken in kweekruimte)
                Button {
                    showMaintenanceSheet = true
                } label: {
                    let isMaint = store.db.environmentConfig.isMaintenanceModeActive
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(isMaint ? Color.orange.opacity(0.3) : Color.orange.opacity(0.18))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.orange)
                            }
                            Spacer()
                            Circle()
                                .fill(isMaint ? Color.orange : Color.white.opacity(0.2))
                                .frame(width: 7, height: 7)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Onderhoudsmodus", en: "Maintenance Mode"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text(isMaint ? store.t(nl: "Actief • Autopilot uit", en: "Active • Autopilot off") : store.t(nl: "Standby • Veilig werken", en: "Standby • Work safe"))
                                .font(.system(size: 10))
                                .foregroundColor(isMaint ? Color.orange : MycoTheme.textSecondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(isMaint ? Color.orange.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - CLEANROOM AI & GEAVANCEERDE SYSTEEM HUB (CENTRALE MATRIX)
    private var cleanroomAIAndAdvancedSystemCentralCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.35), Color.blue.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.cyan)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(store.t(nl: "Cleanroom AI & Systeem Hub", en: "Cleanroom AI & System Hub"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(store.t(nl: "CENTRALE", en: "CENTRAL"))
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.cyan)
                            .cornerRadius(4)
                    }
                    
                    Text(store.t(nl: "Centrale besturing van AI, Klimaatprofielen, Interlocks & Pi Autopilot", en: "Central control for AI, Climate Profiles, Interlocks & Pi Autopilot"))
                        .font(.system(size: 11))
                        .foregroundColor(MycoTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    showAICommandCenter = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text(store.t(nl: "AI Hub (4 Stappen)", en: "AI Hub (4 Steps)"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.cyan)
                    .cornerRadius(8)
                }
            }

            // Pi Hub IP Status & Direct Sync Bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.candidatePiHubIPs.isEmpty ? Color.orange : (store.piHubStatusOnline ? MycoTheme.green : Color.yellow))
                        .frame(width: 8, height: 8)
                    
                    Text(store.candidatePiHubIPs.isEmpty
                         ? store.t(nl: "Pi IP Instellen", en: "Set Pi IP")
                         : "Pi Hub: \(store.db.environmentConfig.effectivePiHubIP)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
                
                Spacer()

                // Direct Pi Sync Button
                Button {
                    Task {
                        isSyncingToPi = true
                        let gen = UINotificationFeedbackGenerator()
                        let ok = await store.syncSettingsToPiHub()
                        if ok {
                            gen.notificationOccurred(.success)
                        } else {
                            gen.notificationOccurred(.warning)
                        }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        isSyncingToPi = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        if isSyncingToPi {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(store.t(nl: "Sync naar Pi", en: "Sync to Pi"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(8)
                }
                .disabled(isSyncingToPi)

                // Pi Hub Video Archive Button
                Button {
                    showPiHubVideoArchive = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "externaldrive.badge.timemachine")
                            .font(.system(size: 11, weight: .bold))
                        Text(store.t(nl: "Pi Video's", en: "Pi Videos"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Color.cyan)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Color.cyan.opacity(0.18))
                    .cornerRadius(8)
                }
            }

            // Central AI & System Features Bento
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                // 1. Cleanroom Spraak AI Console
                Button {
                    showCleanroomVoiceSheet = true
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.purple)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Spraak AI Console", en: "Cleanroom Voice AI"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Text(store.t(nl: "Hands-free spraakcommando's", en: "Hands-free voice triggers"))
                                .font(.system(size: 10))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // 2. Optische Meter Lezer & Vision AI
                Button {
                    showOpticalHygrometerSheet = true
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.2))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "camera.metering.matrix")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.cyan)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Optische Meter AI", en: "Optical Meter AI"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Text(store.t(nl: "OCR & Analoge meters", en: "OCR & Analog gauges"))
                                .font(.system(size: 10))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // 3. Geavanceerde Dag/Nacht Matrix & Klimaat
                Button {
                    showAdvancedClimateSettings = true
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "sun.and.horizon.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.blue)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Klimaat & Dag/Nacht", en: "Climate & Day/Night"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Text(store.t(nl: "Doel RV & Temp curves", en: "Target RH & Temp curves"))
                                .font(.system(size: 10))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // 4. AI Zelfdiagnose & Simulatie Agent
                Button {
                    showUserTestingAgentSheet = true
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(MycoTheme.green.opacity(0.2))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "checklist.checked")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(MycoTheme.green)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "AI Test Agent", en: "AI Testing Agent"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Text(store.t(nl: "46 automatische lab-tests", en: "46 automated lab tests"))
                                .font(.system(size: 10))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.green.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Sequentiële Veiligheidsinterlock Status Info
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MycoTheme.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t(nl: "Sequentiële Interlock: Afzuiging vs Mist", en: "Sequential Interlock: Exhaust vs Mist"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text(store.t(nl: "Voorkomt dat mist direct wordt afgezogen. Pi Hub schakelt bevochtiger automatisch uit tijdens FAE met 30s post-boost.", en: "Prevents mist from being vented out. Pi Hub pauses humidifier during FAE with 30s post-boost."))
                        .font(.system(size: 10))
                        .foregroundColor(MycoTheme.textSecondary)
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.25))
            .cornerRadius(10)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.4), Color.purple.opacity(0.3), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    // MARK: - LAB TOOLS SUITE CARD (TOOLS)
    private var labToolsSuiteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.t(nl: "Lab Tools & Hulpmiddelen", en: "Lab Tools & Utilities"))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(MycoTheme.textSecondary)

            // Ruimte & Klimaat (CFM / m3)
            Button {
                showSpaceCalculator = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(MycoTheme.blue.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(MycoTheme.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Ruimte & Afzuiging AI", en: "Grow Space & Ventilation AI"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(store.t(nl: "Bereken kubieke meters (m³), vereiste luchtverversing (CFM) & ventilatorvermogen", en: "Calculate cubic meters (m³), fresh air exchange (CFM) & exhaust fan sizing"))
                            .font(.system(size: 11))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MycoTheme.card)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - CALCULATORS SUITE
    private var calculatorsSuiteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.t(nl: "Myco Calculators", en: "Myco Calculators"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Calculator Selector Segment
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    calcSelectorChip(title: "🌾 CVG Substraat", index: 0)
                    calcSelectorChip(title: "✨ AI Recepten", index: 1)
                    calcSelectorChip(title: "🧫 Agar & LC", index: 2)
                    calcSelectorChip(title: "⚖️ Oogst & Droog", index: 3)
                    calcSelectorChip(title: "💨 Ruimte & Ventilatie", index: 4)
                }
            }
            
            // Selected Calculator Content
            VStack(alignment: .leading, spacing: 12) {
                switch activeCalculatorIndex {
                case 0:
                    modernCVGCalculatorView
                case 1:
                    modernAIRecipeCalculatorView
                case 2:
                    modernAgarLCCalculatorView
                case 3:
                    modernDosageCalculatorView
                case 4:
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Kweekruimte & Ventilatie AI", en: "Grow Space & Ventilation AI"))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text(store.t(nl: "Berekent m³, vereiste CFM, afzuiging en FAE cycli", en: "Calculates m³, required CFM, ventilation and FAE"))
                                    .font(.system(size: 11))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                            Button {
                                showSpaceCalculator = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    Text(store.t(nl: "Volledig Scherm", en: "Full Screen"))
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(MycoTheme.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(MycoTheme.blue.opacity(0.12))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        GrowSpaceSizeAndAIClimateView()
                            .frame(minHeight: 480)
                    }
                default:
                    modernCVGCalculatorView
                }
            }
            .padding(14)
            .background(MycoTheme.card)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(MycoTheme.border, lineWidth: 1))
        }
    }
    
    private func calcSelectorChip(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                activeCalculatorIndex = index
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: activeCalculatorIndex == index ? .bold : .medium))
                .foregroundColor(activeCalculatorIndex == index ? .white : MycoTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(activeCalculatorIndex == index ? MycoTheme.blue : MycoTheme.card)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(activeCalculatorIndex == index ? MycoTheme.blue : MycoTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 1. CVG SUBSTRATE CALCULATOR
    private var modernCVGCalculatorView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t(nl: "Substraat & Veldcapaciteit (CVG)", en: "Substrate & Field Capacity (CVG)"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(store.t(nl: "Berekent exacte verhouding Coir, Vermiculiet & Gips", en: "Calculates exact Coir, Vermiculite & Gypsum ratio"))
                        .font(.system(size: 11))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                Spacer()
                
                HStack(spacing: 6) {
                    Button {
                        coirInputText = ""
                        coirGrams = 0
                        targetLitersText = ""
                        targetSubstrateLiters = 0
                        spawnAmountInput = ""
                        spawnRatioVal = 0
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "eraser")
                            Text(store.t(nl: "Blanco", en: "Blank"))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MycoTheme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                    }

                    Button {
                        showCreateBatchSheetFromCalc = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text(store.t(nl: "Start Batch", en: "Start Batch"))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MycoTheme.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MycoTheme.blue.opacity(0.12))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Mode selector
            Picker("Modus", selection: $substrateMode) {
                Text(store.t(nl: "Gewicht (g)", en: "Weight (g)")).tag(0)
                Text(store.t(nl: "Volume (L)", en: "Volume (L)")).tag(1)
                Text(store.t(nl: "Blokken", en: "Bricks")).tag(2)
            }
            .pickerStyle(.segmented)
            
            let activeCoirGrams: Double = {
                if substrateMode == 1 {
                    let clean = targetLitersText.replacingOccurrences(of: ",", with: ".")
                    if let val = Double(clean), val > 0 {
                        return val * 76.5
                    }
                    return 8.5 * 76.5
                } else {
                    let clean = coirInputText.replacingOccurrences(of: ",", with: ".")
                    if let val = Double(clean), val > 0 {
                        return val
                    }
                    return coirGrams > 0 ? coirGrams : 650.0
                }
            }()
            
            if substrateMode == 0 {
                HStack {
                    Text(store.t(nl: "Droge Kokosvezel (Coir):", en: "Dry Coco Coir:"))
                        .font(.system(size: 12))
                        .foregroundColor(MycoTheme.textSecondary)
                    Spacer()
                    TextField("bijv. 650", text: $coirInputText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .onChange(of: coirInputText) { _, newV in
                            let clean = newV.replacingOccurrences(of: ",", with: ".")
                            if let val = Double(clean), val > 0 { coirGrams = val }
                        }
                    Text("gram").font(.caption).foregroundColor(.white)
                }
            } else if substrateMode == 1 {
                HStack {
                    Text(store.t(nl: "Gewenst Doelvolume:", en: "Target Volume:"))
                        .font(.system(size: 12))
                        .foregroundColor(MycoTheme.textSecondary)
                    Spacer()
                    TextField("bijv. 8.5", text: $targetLitersText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .onChange(of: targetLitersText) { _, newV in
                            let clean = newV.replacingOccurrences(of: ",", with: ".")
                            if let val = Double(clean), val > 0 {
                                targetSubstrateLiters = val
                                coirGrams = val * 76.5
                            }
                        }
                    Text("liter").font(.caption).foregroundColor(.white)
                }
            } else {
                HStack(spacing: 8) {
                    ForEach([1, 2, 3], id: \.self) { bricks in
                        Button {
                            coirGrams = Double(bricks * 650)
                            coirInputText = "\(Int(coirGrams))"
                        } label: {
                            Text("\(bricks)x Blok (\(bricks * 650)g)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(coirGrams == Double(bricks * 650) ? .white : MycoTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(coirGrams == Double(bricks * 650) ? MycoTheme.blue : Color.white.opacity(0.06))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Computed Results Bento Tile
            let coirRatio = max(0.01, activeCoirGrams / 650.0)
            let waterNeededML = activeCoirGrams * hydrationRatio
            let vermiculiteGrams = 200.0 * coirRatio
            let vermiculiteLiters = 2.0 * coirRatio
            let vermiculiteCups = vermiculiteLiters * 4.2
            let gypsumGrams = 100.0 * coirRatio
            let gypsumTablespoons = gypsumGrams / 25.0
            let approxYieldLiters = activeCoirGrams / 76.5
            let approxYieldKg = (activeCoirGrams + waterNeededML + vermiculiteGrams + gypsumGrams) / 1000.0
            
            let vermiculiteDisplay: String = {
                if substrateMode == 1 {
                    return String(format: "%.1fL (%.0fg / ~%.0f kp)", vermiculiteLiters, vermiculiteGrams, vermiculiteCups)
                } else {
                    return String(format: "%.0fg (%.1fL / ~%.0f kp)", vermiculiteGrams, vermiculiteLiters, vermiculiteCups)
                }
            }()
            
            let waterDisplay: String = {
                if waterNeededML >= 1000 {
                    return String(format: "%.1fL (%.0f ml)", waterNeededML / 1000.0, waterNeededML)
                } else {
                    return String(format: "%.0f ml", waterNeededML)
                }
            }()
            
            let gypsumDisplay: String = {
                return String(format: "%.0fg (ca. %.1f el)", gypsumGrams, max(0.5, gypsumTablespoons))
            }()
            
            let yieldDisplay: String = {
                return String(format: "± %.1fL (ca. %.1f kg)", approxYieldLiters, approxYieldKg)
            }()
            
            VStack(spacing: 8) {
                HStack {
                    recipeResultRow(icon: "drop.fill", title: store.t(nl: "Kokend Water", en: "Boiling Water"), value: waterDisplay, color: MycoTheme.blue)
                    recipeResultRow(icon: "circle.grid.3x3.fill", title: store.t(nl: "Vermiculiet (Gewicht & Volume)", en: "Vermiculite (Weight & Vol)"), value: vermiculiteDisplay, color: MycoTheme.amber)
                }
                HStack {
                    recipeResultRow(icon: "sparkles", title: store.t(nl: "Gips (Gipsmeel)", en: "Gypsum (Calcium)"), value: gypsumDisplay, color: Color.purple)
                    recipeResultRow(icon: "cube.fill", title: store.t(nl: "Totale Opbrengst", en: "Total Yield"), value: yieldDisplay, color: MycoTheme.green)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            
            // Action Buttons: Save as Recipe & Start Batch
            HStack(spacing: 8) {
                Button {
                    saveCVGRecipe(
                        coirGrams: activeCoirGrams,
                        vermiculiteGrams: vermiculiteGrams,
                        gypsumGrams: gypsumGrams,
                        waterML: waterNeededML,
                        yieldLiters: approxYieldLiters
                    )
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bookmark.badge.plus")
                        Text(store.t(nl: "Opslaan als Recept", en: "Save as Recipe"))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MycoTheme.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(MycoTheme.green.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button {
                    showCreateBatchSheetFromCalc = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                        Text(store.t(nl: "Start Batch", en: "Start Batch"))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MycoTheme.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(MycoTheme.blue.opacity(0.12))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func saveCVGRecipe(coirGrams: Double, vermiculiteGrams: Double, gypsumGrams: Double, waterML: Double, yieldLiters: Double) {
        let name = "CVG Substraat (\(Int(coirGrams))g / \(String(format: "%.1f", yieldLiters))L)"
        let rec = PreparationRecipe(
            name: name,
            category: "Substraat",
            targetPhase: .bulk,
            containerName: "Monotub / Filterzak",
            substrateName: "CVG Mix (Kokos, Vermiculiet, Gips)",
            spawnToBulkRatio: "1:2",
            drySubstrateWeightGrams: coirGrams,
            sterilizationNotes: "Pasteurisatie in afgesloten emmer (6-8 uur) of 90 min op 15 PSI (121°C) in snelkookpan.",
            preparationInstructions: """
            1. Plaats de droge kokosvezel (\(Int(coirGrams))g) in een hittebestendige emmer of pot.
            2. Voeg \(Int(vermiculiteGrams))g vermiculiet en \(Int(gypsumGrams))g gips toe en meng droog.
            3. Breng \(Int(waterML))ml water aan de kook (100°C).
            4. Giet het kokende water over het droge substraat en sluit het deksel luchtdicht af.
            5. Laat minimaal 6 tot 8 uur rustig afkoelen tot kamertemperatuur (<25°C) alvorens te enten met broed.
            """,
            ingredients: [
                RecipeIngredient(name: "Kokosvezel (Coco Coir)", amountPerBatch: coirGrams, unit: "gram"),
                RecipeIngredient(name: "Vermiculiet", amountPerBatch: vermiculiteGrams, unit: "gram"),
                RecipeIngredient(name: "Gips (Calcium / Gipsmeel)", amountPerBatch: gypsumGrams, unit: "gram"),
                RecipeIngredient(name: "Kokend Water", amountPerBatch: waterML, unit: "ml")
            ]
        )
        store.db.preparationRecipes.insert(rec, at: 0)
        store.save()
        withAnimation {
            savedRecipeBanner = store.t(nl: "✅ Recept '\(name)' opgeslagen in Recepten!", en: "✅ Recipe '\(name)' saved to Recipes!")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { savedRecipeBanner = nil }
        }
    }
    
    private func saveAIRecipe(res: AIRecipeResult) {
        let ingredients = res.ingredients.map { ing in
            RecipeIngredient(name: ing.name, amountPerBatch: 1.0, unit: ing.amountFormatted)
        }
        let rec = PreparationRecipe(
            name: res.title,
            category: res.category.rawValue,
            targetPhase: .bulk,
            containerName: "Monotub / Growbox",
            substrateName: res.title,
            spawnToBulkRatio: "1:2",
            drySubstrateWeightGrams: 650,
            sterilizationNotes: res.sterilizationGuideNl,
            preparationInstructions: res.aiExplanationNl.isEmpty ? res.safetyNotesNl : res.aiExplanationNl,
            ingredients: ingredients
        )
        store.db.preparationRecipes.insert(rec, at: 0)
        store.save()
        withAnimation {
            savedRecipeBanner = store.t(nl: "✅ AI Recept '\(res.title)' opgeslagen in Recepten!", en: "✅ AI Recipe '\(res.title)' saved to Recipes!")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { savedRecipeBanner = nil }
        }
    }

    private func recipeResultRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(MycoTheme.textSecondary)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
    
    // MARK: - 2. AI RECIPE CALCULATOR
    private var modernAIRecipeCalculatorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.t(nl: "AI Recept & Balans Maker", en: "AI Recipe & Balance Formulator"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(store.t(nl: "Berekent veilige nutriënten en optimale hydratatiebalans", en: "Computes safe nutrients and optimal hydration balance"))
                .font(.system(size: 11))
                .foregroundColor(MycoTheme.textSecondary)
            
            HStack(spacing: 10) {
                Button {
                    aiCalculationResult = MycoAIRecipeEngine.calculate(
                        category: .substrate,
                        selectedIngredients: ["Kokosvezel (Coir)", "Vermiculiet", "Gips (Calcium)"],
                        batchSize: 8.5,
                        unit: .liter
                    )
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text(store.t(nl: "Genereer CVG Recept", en: "Generate CVG Recipe"))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MycoTheme.amber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(MycoTheme.amber.opacity(0.14))
                    .cornerRadius(8)
                }
                
                Button {
                    aiCalculationResult = MycoAIRecipeEngine.calculate(
                        category: .agar,
                        selectedIngredients: ["Agar-Agar Poeder", "Licht Moutextract (LME)"],
                        batchSize: 500,
                        unit: .milliliter
                    )
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flask.fill")
                        Text(store.t(nl: "Genereer MEA Agar", en: "Generate MEA Agar"))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MycoTheme.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(MycoTheme.green.opacity(0.14))
                    .cornerRadius(8)
                }
            }
            
            if let res = aiCalculationResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text(res.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    ForEach(res.ingredients) { ing in
                        HStack {
                            Text(ing.name).font(.system(size: 11)).foregroundColor(MycoTheme.textSecondary)
                            Spacer()
                            Text(ing.amountFormatted).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        }
                    }
                    
                    Button {
                        saveAIRecipe(res: res)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bookmark.badge.plus")
                            Text(store.t(nl: "Opslaan in Recepten", en: "Save in Recipes"))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MycoTheme.amber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(MycoTheme.amber.opacity(0.14))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - 3. AGAR & LC CALCULATOR
    private var modernAgarLCCalculatorView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.t(nl: "Agar & Liquid Culture Media", en: "Agar & Liquid Culture Media"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            Picker("Media", selection: $mediaKind) {
                Text("MEA Agar").tag("Agar")
                Text("Liquid Culture (LC)").tag("LC")
            }
            .pickerStyle(.segmented)
            
            let effectiveWaterML: Double = {
                let clean = waterVolumeText.replacingOccurrences(of: ",", with: ".")
                if let val = Double(clean), val > 0 { return val }
                return waterVolumeML > 0 ? waterVolumeML : 500.0
            }()
            
            HStack {
                Text(store.t(nl: "Waterhoeveelheid:", en: "Water Volume:"))
                    .font(.system(size: 12))
                    .foregroundColor(MycoTheme.textSecondary)
                Spacer()
                TextField("bijv. 500", text: $waterVolumeText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .onChange(of: waterVolumeText) { _, newV in
                        let clean = newV.replacingOccurrences(of: ",", with: ".")
                        if let val = Double(clean), val > 0 { waterVolumeML = val }
                    }
                Text("ml").font(.caption).foregroundColor(.white)
            }
            
            let factor = effectiveWaterML / 500.0
            if mediaKind == "Agar" {
                VStack(spacing: 6) {
                    recipeResultRow(icon: "drop.fill", title: store.t(nl: "Gedestilleerd Water", en: "Distilled Water"), value: "\(Int(effectiveWaterML)) ml", color: MycoTheme.blue)
                    recipeResultRow(icon: "sparkles", title: "Agar-Agar Poeder", value: String(format: "%.1f g", 10.0 * factor), color: MycoTheme.amber)
                    recipeResultRow(icon: "leaf.fill", title: "Licht Moutextract (LME)", value: String(format: "%.1f g", 10.0 * factor), color: MycoTheme.green)
                    recipeResultRow(icon: "circle.fill", title: "Optioneel: Gistextract / Peptone", value: String(format: "%.1f g", 0.5 * factor), color: Color.purple)
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
            } else {
                VStack(spacing: 6) {
                    recipeResultRow(icon: "drop.fill", title: store.t(nl: "Gedestilleerd Water", en: "Distilled Water"), value: "\(Int(effectiveWaterML)) ml", color: MycoTheme.blue)
                    recipeResultRow(icon: "drop.triangle.fill", title: "LME of Karo Glucosestroop (4%)", value: String(format: "%.1f g", 20.0 * factor), color: MycoTheme.amber)
                    recipeResultRow(icon: "sparkles", title: "Gistextract / Peptone", value: String(format: "%.1f g", 0.5 * factor), color: MycoTheme.green)
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - 4. DOSAGE CALCULATOR
    private var modernDosageCalculatorView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.t(nl: "Culinair Oogst- & Drooggewicht Calculator", en: "Culinary Harvest & Dehydration Calculator"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            Toggle(isOn: $isFreshWet) {
                Text(store.t(nl: "Vers geoogst (Nat / 90% waterverlies bij drogen)", en: "Freshly harvested (Wet / 90% moisture loss when drying)"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .tint(MycoTheme.blue)
            
            HStack {
                Text(store.t(nl: "Gewenst Drooggewicht (Eindopbrengst):", en: "Target Dry Weight (Final Yield):"))
                    .font(.system(size: 12))
                    .foregroundColor(MycoTheme.textSecondary)
                Spacer()
                Text(String(format: "%.1f g", targetIntensityBaseGrams))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(MycoTheme.green)
            }
            
            Slider(value: $targetIntensityBaseGrams, in: 1.0...50.0, step: 0.5)
                .tint(MycoTheme.green)
            
            let finalGrams = isFreshWet ? (targetIntensityBaseGrams * 10.0) : targetIntensityBaseGrams
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t(nl: "Benodigd Oogstgewicht:", en: "Calculated Harvest Weight:"))
                        .font(.system(size: 11))
                        .foregroundColor(MycoTheme.textSecondary)
                    Text(String(format: "%.1f gram %@", finalGrams, isFreshWet ? store.t(nl: "vers geoogst (nat)", en: "freshly harvested (wet)") : store.t(nl: "gedroogd", en: "dry")))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(MycoTheme.green)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
        }
    }
    
    // MARK: - QR CODE STUDIO CARD
    private var qrStudioLauncherCard: some View {
        Button {
            showQRArchive = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(MycoTheme.blue.opacity(0.2))
                        .frame(width: 42, height: 42)
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(MycoTheme.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(store.t(nl: "QR Label & Print Studio", en: "QR Label & Print Studio"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        if totalActiveQRsCount > 0 {
                            Text("\(totalActiveQRsCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MycoTheme.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(MycoTheme.blue.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    Text(store.t(nl: "Direct printen of exporteren van alle kweekpotten & zakken", en: "Directly print or export labels for jars & bags"))
                        .font(.system(size: 11))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MycoTheme.textSecondary)
            }
            .padding(14)
            .background(MycoTheme.card)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(MycoTheme.blue.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var userTestingAgentLauncherCard: some View {
        Button {
            showUserTestingAgentSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(MycoTheme.green.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(MycoTheme.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(store.t(nl: "AI Gebruikers Test Agent", en: "AI User Testing Agent"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(MycoUserTestingAgent.shared.overallScore)%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(MycoTheme.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(MycoTheme.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text(store.t(
                        nl: "Test autonoom de hele app als echte kweker bij elke wijziging",
                        en: "Autonomously tests entire app as real grower on every change"
                    ))
                    .font(.system(size: 11))
                    .foregroundColor(MycoTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MycoTheme.textSecondary)
            }
            .padding(14)
            .background(MycoTheme.card)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(MycoTheme.green.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - BEREIDINGSRECEPTEN & INGREDIËNTEN MANAGER
    private var modernPreparationRecipesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife.circle.fill")
                        .foregroundColor(MycoTheme.green)
                    Text(store.t(nl: "Bereidingsrecepten & Ingrediënten", en: "Preparation Recipes & Ingredients"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Button {
                    showAddPreparationRecipe = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text(store.t(nl: "Nieuw Recept", en: "New Recipe"))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MycoTheme.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MycoTheme.green.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Text(store.t(
                nl: "Stel kant-en-klare kweekrecepten in met exacte ingrediënten. Bij het starten van een batch worden alle hoeveelheden automatisch berekend en afgeboekt van je labvoorraad.",
                en: "Configure recipes with exact ingredients. When creating a batch, all quantities are automatically calculated and deducted from lab inventory."
            ))
            .font(.system(size: 11))
            .foregroundColor(MycoTheme.textSecondary)
            
            if store.db.preparationRecipes.isEmpty {
                Text(store.t(nl: "Nog geen bereidingsrecepten. Tik op '+ Nieuw Recept' om te beginnen.", en: "No preparation recipes yet. Tap '+ New Recipe' to start."))
                    .font(.system(size: 11))
                    .foregroundColor(MycoTheme.textSecondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.db.preparationRecipes) { recipe in
                        PreparationRecipeRowView(
                            recipe: recipe,
                            onSelect: { viewingPreparationRecipe = recipe },
                            onEdit: { editingPreparationRecipe = recipe },
                            onDelete: {
                                withAnimation {
                                    store.deletePreparationRecipe(id: recipe.id)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(MycoTheme.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(MycoTheme.border, lineWidth: 1))
    }

    // MARK: - PRESETS & RECEPTEN MANAGER
    private var modernPresetsManagerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.t(nl: "Eigen Presets & Hardwaresetups", en: "Custom Presets & Hardware"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                
                Picker("Categorie", selection: $newPresetCat) {
                    ForEach(PresetCategory.allCases, id: \.self) { c in
                        Text(c.localized(isEnglish: store.isEnglish)).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 11))
            }
            
            HStack(spacing: 8) {
                TextField(store.t(nl: "Nieuwe preset naam...", en: "New preset name..."), text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                
                Button {
                    guard !newPresetName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    store.db.presets.append(UserPreset(category: newPresetCat, name: newPresetName.trimmingCharacters(in: .whitespaces), details: ""))
                    store.save()
                    newPresetName = ""
                } label: {
                    Text(store.t(nl: "Toevoegen", en: "Add"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(MycoTheme.blue)
                        .cornerRadius(8)
                }
            }
            
            if store.db.presets.isEmpty {
                Text(store.t(nl: "Nog geen eigen hardware of recept presets opgeslagen.", en: "No custom presets saved yet."))
                    .font(.system(size: 11))
                    .foregroundColor(MycoTheme.textSecondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(store.db.presets) { p in
                        HStack {
                            Text("\(p.category.localized(isEnglish: store.isEnglish)): ")
                                .font(.system(size: 11))
                                .foregroundColor(MycoTheme.textSecondary)
                            Text(store.localizePresetName(p.name))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Button {
                                editingPreset = p
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundColor(MycoTheme.blue)
                                    .padding(.trailing, 4)
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                withAnimation {
                                    store.deletePreset(id: p.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(MycoTheme.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(14)
        .background(MycoTheme.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(MycoTheme.border, lineWidth: 1))
    }
}


// MARK: - EDIT USER PRESET SHEET VIEW
struct EditUserPresetSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss

    let preset: UserPreset

    @State private var name: String
    @State private var category: PresetCategory
    @State private var details: String
    @State private var showDeleteConfirm = false

    init(preset: UserPreset) {
        self.preset = preset
        _name = State(initialValue: preset.name)
        _category = State(initialValue: preset.category)
        _details = State(initialValue: preset.details)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(store.t(nl: "Preset Naam & Categorie", en: "Preset Name & Category"))) {
                    TextField(store.t(nl: "Naam preset (bijv. CVG Classic, MEA + Pepton)", en: "Preset Name"), text: $name)
                    Picker(store.t(nl: "Categorie", en: "Category"), selection: $category) {
                        ForEach([PresetCategory.container, PresetCategory.substrate, PresetCategory.grain, PresetCategory.media], id: \.self) { cat in
                            Text(cat.localized(isEnglish: store.isEnglish)).tag(cat)
                        }
                    }
                }

                Section(header: Text(store.t(nl: "Details & Ingrediënten", en: "Details & Ingredients"))) {
                    TextField(store.t(nl: "Verhoudingen, recept of afmetingen...", en: "Ratios, recipe or dimensions..."), text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text(store.t(nl: "Verwijder Deze Preset", en: "Delete This Preset"))
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Preset Bewerken", en: "Edit Preset"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Annuleren", en: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Opslaan", en: "Save")) {
                        saveChanges()
                    }
                    .font(.headline.bold())
                    .foregroundColor(MycoTheme.blue)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert(store.t(nl: "Preset Verwijderen?", en: "Delete Preset?"), isPresented: $showDeleteConfirm) {
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
                Button(store.t(nl: "Verwijderen", en: "Delete"), role: .destructive) {
                    store.deletePreset(id: preset.id)
                    dismiss()
                }
            } message: {
                Text(store.t(nl: "Weet je zeker dat je deze preset wilt verwijderen?", en: "Are you sure you want to delete this preset?"))
            }
        }
    }

    private func saveChanges() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        if let idx = store.db.presets.firstIndex(where: { $0.id == preset.id }) {
            store.db.presets[idx].name = cleanName
            store.db.presets[idx].category = category
            store.db.presets[idx].details = details
            store.save()
        }

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif

        MycoSyncManager.shared.triggerToast(message: store.t(
            nl: "✅ Preset succesvol bijgewerkt",
            en: "✅ Preset successfully updated"
        ))

        dismiss()
    }
}

// MARK: - PREPARATION RECIPE ROW VIEW
struct PreparationRecipeRowView: View {
    let recipe: PreparationRecipe
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var ingredientsSummary: String {
        recipe.ingredients.map { ing in
            let isWhole = ing.amountPerBatch.truncatingRemainder(dividingBy: 1) == 0
            let num = isWhole ? String(format: "%.0f", ing.amountPerBatch) : String(format: "%.1f", ing.amountPerBatch)
            return "\(ing.name) (\(num)\(ing.unit))"
        }.joined(separator: " • ")
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "fork.knife.circle.fill")
                        .foregroundColor(MycoTheme.green)
                        .font(.system(size: 14))
                    
                    Text(recipe.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(recipe.category)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MycoTheme.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(MycoTheme.green.opacity(0.15))
                        .cornerRadius(4)
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(MycoTheme.blue)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(MycoTheme.red.opacity(0.8))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                
                HStack(spacing: 12) {
                    if !recipe.containerName.isEmpty {
                        Label(recipe.containerName, systemImage: "shippingbox")
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    if !recipe.substrateName.isEmpty {
                        Label(recipe.substrateName, systemImage: "leaf")
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    if recipe.drySubstrateWeightGrams > 0 {
                        Label("\(String(format: "%.0f", recipe.drySubstrateWeightGrams))g", systemImage: "scalemass")
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }
                
                if !recipe.ingredients.isEmpty {
                    Text(ingredientsSummary)
                        .font(.system(size: 10))
                        .foregroundColor(MycoTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PREPARATION RECIPE DETAIL SHEET VIEW
struct PreparationRecipeDetailSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    let recipe: PreparationRecipe
    let onStartBatch: (PreparationRecipe, Int) -> Void
    let onEdit: (PreparationRecipe) -> Void
    
    @State private var batchMultiplier: Int = 1
    @State private var checkedIngredients: Set<UUID> = []
    @State private var checkedSteps: Set<Int> = []
    @State private var startedTimer: Bool = false
    
    private var instructionSteps: [String] {
        let lines = recipe.preparationInstructions.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? [recipe.preparationInstructions] : lines
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 1. Header Card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(recipe.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                            Text(recipe.category)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(MycoTheme.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(MycoTheme.green.opacity(0.15))
                                .cornerRadius(6)
                        }
                        
                        HStack(spacing: 8) {
                            Text(recipe.targetPhase.localized(isEnglish: store.isEnglish))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(MycoTheme.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(MycoTheme.blue.opacity(0.12))
                                .cornerRadius(6)
                            
                            if !recipe.containerName.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "shippingbox")
                                    Text(recipe.containerName)
                                }
                                .font(.system(size: 11))
                                .foregroundColor(MycoTheme.textSecondary)
                            }
                            
                            if !recipe.substrateName.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "leaf")
                                    Text(recipe.substrateName)
                                }
                                .font(.system(size: 11))
                                .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
                    
                    // 2. Batch Scaler
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Batch Vermenigvuldiger", en: "Batch Multiplier"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text(store.t(nl: "Schaal alle ingrediënten automatisch op", en: "Automatically scale all ingredients"))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        Spacer()
                        
                        HStack(spacing: 6) {
                            ForEach([1, 2, 3, 4], id: \.self) { mult in
                                Button {
                                    batchMultiplier = mult
                                } label: {
                                    Text("\(mult)x")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(batchMultiplier == mult ? .white : MycoTheme.textSecondary)
                                        .frame(width: 38, height: 32)
                                        .background(batchMultiplier == mult ? MycoTheme.blue : Color.white.opacity(0.06))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    
                    // 3. Scaled Ingredients with Checkboxes & Lab Stock
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "list.clipboard.fill")
                                .foregroundColor(MycoTheme.amber)
                            Text(store.t(nl: "Ingrediënten & Hoeveelheden (\(batchMultiplier)x)", en: "Ingredients & Quantities (\(batchMultiplier)x)"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(checkedIngredients.count)/\(recipe.ingredients.count) gereed")
                                .font(.caption.bold())
                                .foregroundColor(checkedIngredients.count == recipe.ingredients.count ? MycoTheme.green : MycoTheme.textSecondary)
                        }
                        
                        if recipe.ingredients.isEmpty {
                            Text(store.t(nl: "Geen ingrediënten vastgelegd.", en: "No ingredients recorded."))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(recipe.ingredients) { ing in
                                    let scaledAmount = ing.amountPerBatch * Double(batchMultiplier)
                                    let isChecked = checkedIngredients.contains(ing.id)
                                    let matchingSupply = store.db.supplies.first(where: {
                                        if let lId = ing.linkedSupplyID, $0.id == lId { return true }
                                        return $0.name.localizedCaseInsensitiveContains(ing.name) || ing.name.localizedCaseInsensitiveContains($0.name)
                                    })
                                    
                                    Button {
                                        if isChecked {
                                            checkedIngredients.remove(ing.id)
                                        } else {
                                            checkedIngredients.insert(ing.id)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 18))
                                                .foregroundColor(isChecked ? MycoTheme.green : MycoTheme.textSecondary)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(ing.name)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(isChecked ? MycoTheme.textSecondary : .white)
                                                    .strikethrough(isChecked)
                                                
                                                if let sup = matchingSupply {
                                                    Text("Voorraad: \(String(format: "%.1f", sup.quantity)) \(sup.unit)")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(sup.quantity < scaledAmount ? MycoTheme.red : MycoTheme.textSecondary)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            let isWhole = scaledAmount.truncatingRemainder(dividingBy: 1) == 0
                                            let numStr = isWhole ? String(format: "%.0f", scaledAmount) : String(format: "%.1f", scaledAmount)
                                            
                                            Text("\(numStr) \(ing.unit)")
                                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                .foregroundColor(isChecked ? MycoTheme.green : .white)
                                        }
                                        .padding(10)
                                        .background(isChecked ? MycoTheme.green.opacity(0.08) : Color.white.opacity(0.04))
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
                    
                    // 4. Step-by-Step Instructions
                    if !recipe.preparationInstructions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(MycoTheme.blue)
                                Text(store.t(nl: "Bereidingsinstructies", en: "Preparation Instructions"))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(Array(instructionSteps.enumerated()), id: \.offset) { idx, step in
                                    let isDone = checkedSteps.contains(idx)
                                    Button {
                                        if isDone {
                                            checkedSteps.remove(idx)
                                        } else {
                                            checkedSteps.insert(idx)
                                        }
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: isDone ? "checkmark.square.fill" : "square")
                                                .font(.system(size: 16))
                                                .foregroundColor(isDone ? MycoTheme.green : MycoTheme.blue)
                                                .padding(.top, 1)
                                            
                                            Text(step)
                                                .font(.system(size: 12))
                                                .foregroundColor(isDone ? MycoTheme.textSecondary : .white)
                                                .strikethrough(isDone)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(10)
                                        .background(isDone ? MycoTheme.green.opacity(0.06) : Color.white.opacity(0.03))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(14)
                        .background(MycoTheme.card)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
                    }
                    
                    // 5. Sterilization Protocol
                    if !recipe.sterilizationNotes.isEmpty {
                        sterilizationSection
                    }
                    
                    // 6. Action Button: Start Batch
                    Button {
                        dismiss()
                        onStartBatch(recipe, batchMultiplier)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text(store.t(nl: "Start Batch met dit Recept (\(batchMultiplier)x)", en: "Start Batch with this Recipe (\(batchMultiplier)x)"))
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MycoTheme.green)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Recept Detail", en: "Recipe Detail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            printRecipeSOP()
                        } label: {
                            Image(systemName: "printer.fill")
                                .font(.system(size: 14))
                                .foregroundColor(MycoTheme.amber)
                        }
                        
                        Button {
                            dismiss()
                            onEdit(recipe)
                        } label: {
                            Text(store.t(nl: "Bewerken", en: "Edit"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(MycoTheme.blue)
                        }
                    }
                }
            }
        }
    }
    
    private func printRecipeSOP() {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "MycoLabs-SOP-\(recipe.name)"
        printController.printInfo = printInfo
        
        var ingredientsHTML = ""
        for ing in recipe.ingredients {
            let scaled = ing.amountPerBatch * Double(batchMultiplier)
            let formattedAmount = String(format: scaled.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", scaled)
            ingredientsHTML += """
            <tr>
                <td style='padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px;'>\(ing.name)</td>
                <td style='padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; text-align: right; font-weight: bold; font-family: monospace;'>\(formattedAmount) \(ing.unit)</td>
            </tr>
            """
        }
        
        var stepsHTML = ""
        for (idx, step) in instructionSteps.enumerated() {
            stepsHTML += """
            <li style='margin-bottom: 8px; font-size: 13px; line-height: 1.5;'>
                <strong>Stap \(idx + 1):</strong> \(step)
            </li>
            """
        }
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    padding: 32px;
                    color: #0f172a;
                    background: #ffffff;
                }
                .header {
                    border-bottom: 3px solid #059669;
                    padding-bottom: 16px;
                    margin-bottom: 20px;
                }
                .badge {
                    display: inline-block;
                    padding: 4px 10px;
                    background: #ecfdf5;
                    color: #059669;
                    border-radius: 6px;
                    font-weight: 700;
                    font-size: 11px;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                }
                .title {
                    font-size: 24px;
                    font-weight: 800;
                    color: #064e3b;
                    margin: 8px 0 4px 0;
                }
                .meta {
                    font-size: 12px;
                    color: #64748b;
                }
                .info-grid {
                    display: grid;
                    grid-template-columns: 1fr 1fr;
                    gap: 12px;
                    margin-bottom: 24px;
                    background: #f8fafc;
                    padding: 14px;
                    border-radius: 8px;
                    border: 1px solid #e2e8f0;
                }
                .info-item {
                    font-size: 12px;
                }
                .info-label {
                    color: #64748b;
                    font-size: 10px;
                    text-transform: uppercase;
                    font-weight: 700;
                }
                .info-value {
                    font-weight: 600;
                    color: #1e293b;
                }
                h2 {
                    font-size: 15px;
                    font-weight: 700;
                    color: #0f172a;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                    margin-top: 24px;
                    margin-bottom: 10px;
                    border-bottom: 1px solid #cbd5e1;
                    padding-bottom: 4px;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin-bottom: 20px;
                }
                th {
                    background: #f1f5f9;
                    text-align: left;
                    padding: 8px 12px;
                    font-size: 11px;
                    text-transform: uppercase;
                    color: #475569;
                }
                ol {
                    padding-left: 20px;
                    margin: 0;
                }
                .sterilization-box {
                    background: #fffbeb;
                    border-left: 4px solid #f59e0b;
                    padding: 12px;
                    border-radius: 4px;
                    margin-bottom: 24px;
                }
                .footer {
                    margin-top: 40px;
                    border-top: 1px solid #e2e8f0;
                    padding-top: 12px;
                    text-align: center;
                    font-size: 10px;
                    color: #94a3b8;
                }
            </style>
        </head>
        <body>
            <div class="header">
                <div class="badge">\(recipe.category) • Schaal: \(batchMultiplier)x</div>
                <div class="title">🔬 \(recipe.name)</div>
                <div class="meta">MycoLabs Standaard Bereidingsprotocol (SOP) • Afgedrukt op \(Date().formatted(date: .long, time: .shortened))</div>
            </div>
            
            <div class="info-grid">
                <div class="info-item">
                    <div class="info-label">Doelfase</div>
                    <div class="info-value">\(recipe.targetPhase.rawValue)</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Aanbevolen Container</div>
                    <div class="info-value">\(recipe.containerName.isEmpty ? "Geen specifieke container" : recipe.containerName)</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Substraat Type</div>
                    <div class="info-value">\(recipe.substrateName.isEmpty ? "Standaard Mix" : recipe.substrateName)</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Spawn-to-Bulk Verhouding</div>
                    <div class="info-value">\(recipe.spawnToBulkRatio.isEmpty ? "1:2" : recipe.spawnToBulkRatio)</div>
                </div>
            </div>
            
            <h2>1. Benodigde Ingrediënten (\(batchMultiplier)x Batch)</h2>
            <table>
                <thead>
                    <tr>
                        <th>Ingrediënt</th>
                        <th style="text-align: right;">Hoeveelheid</th>
                    </tr>
                </thead>
                <tbody>
                    \(ingredientsHTML)
                </tbody>
            </table>
            
            <div class="sterilization-box">
                <div style="font-weight: 700; font-size: 12px; color: #b45309; margin-bottom: 4px;">🔥 Sterilisatie & Afkoelrichtlijn</div>
                <div style="font-size: 12px; color: #78350f;">\(recipe.sterilizationNotes.isEmpty ? "Standaard snelkookpan: 90 minuten @ 15 PSI (121°C). Minimaal 6-8 uur rustig laten afkoelen naar <25°C." : recipe.sterilizationNotes)</div>
            </div>
            
            <h2>2. Bereidingsprotocol Stap-voor-Stap</h2>
            <ol>
                \(stepsHTML)
            </ol>
            
            <div class="footer">
                MycoLabs Precision Cleanroom & Cultivation Assistant • BiomeCore Labs
            </div>
        </body>
        </html>
        """
        
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        printController.printFormatter = formatter
        
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            printController.present(animated: true, completionHandler: nil)
        }
    }

    private var sterilizationSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20))
                .foregroundColor(MycoTheme.amber)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(store.t(nl: "Sterilisatie / Pasteurisatie", en: "Sterilization / Pasteurization"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text(recipe.sterilizationNotes)
                    .font(.system(size: 11))
                    .foregroundColor(MycoTheme.textSecondary)
            }
            
            Spacer()
            
            Button {
                let timer = LabTimerItem(
                    label: recipe.name,
                    endDate: Date().addingTimeInterval(90 * 60),
                    totalMinutes: 90
                )
                store.db.timers.append(timer)
                store.save()
                store.startDynamicIslandTimer(label: recipe.name, totalMinutes: 90, notes: "15 PSI • +6u Afkoeling")
                startedTimer = true
                
                // Notifications: 1) 90m sterilisatie klaar, 2) 6u afkoelen klaar (<25°C)
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    let c1 = UNMutableNotificationContent()
                    c1.title = "🔥 Sterilisatie Voltooid (90m)"
                    c1.body = "'\(recipe.name)' is gesteriliseerd! Laat de potten/zakken afgesloten afkoelen."
                    c1.sound = .default
                    let trig1 = UNTimeIntervalNotificationTrigger(timeInterval: 90 * 60, repeats: false)
                    let req1 = UNNotificationRequest(identifier: timer.id.uuidString + "-sterilized", content: c1, trigger: trig1)
                    UNUserNotificationCenter.current().add(req1)
                    
                    let c2 = UNMutableNotificationContent()
                    c2.title = "❄️ Substraat Veilig Afgekoeld (<25°C)"
                    c2.body = "'\(recipe.name)' is afgekoeld naar kamertemperatuur. Je kunt nu veilig inoculeren/enten!"
                    c2.sound = .default
                    let trig2 = UNTimeIntervalNotificationTrigger(timeInterval: (90 * 60) + (6 * 3600), repeats: false)
                    let req2 = UNNotificationRequest(identifier: timer.id.uuidString + "-cooldown", content: c2, trigger: trig2)
                    UNUserNotificationCenter.current().add(req2)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: startedTimer ? "checkmark" : "timer")
                    Text(startedTimer ? store.t(nl: "Gestart (+ Afkoel)", en: "Started (+ Cool)") : store.t(nl: "Start 90m + Afkoel", en: "Start 90m + Cool"))
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(startedTimer ? MycoTheme.green : MycoTheme.amber)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((startedTimer ? MycoTheme.green : MycoTheme.amber).opacity(0.15))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(startedTimer)
        }
        .padding(12)
        .background(MycoTheme.amber.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.amber.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - ADD PREPARATION RECIPE SHEET VIEW
struct AddPreparationRecipeSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var category: String = "Substraat"
    @State private var customCategory: String = ""
    @State private var targetPhase: GrowPhase = .spawn
    @State private var containerName: String = ""
    @State private var substrateName: String = ""
    @State private var spawnToBulkRatio: String = ""
    @State private var dryWeightText: String = ""
    @State private var sterilizationNotes: String = ""
    @State private var preparationInstructions: String = ""
    @State private var ingredients: [RecipeIngredient] = []
    
    // New ingredient inputs
    @State private var newIngName: String = ""
    @State private var newIngAmount: String = ""
    @State private var newIngUnit: String = "gram"
    @State private var newIngLinkedSupplyID: UUID? = nil
    
    private let commonCategories = ["Substraat", "Graan & Broed", "Agar & Media", "Vloeibaar Medium", "Zaagsel & Hout", "Anders / Zelf typen..."]
    private let commonUnits = ["gram", "ml", "liter", "kg", "stuks", "blokken", "potten"]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(store.t(nl: "Recept Naam & Categorie", en: "Recipe Name & Category"))) {
                    TextField(store.t(nl: "Naam (bijv. CVG Monotub 1:2, Broedpot Rogge)", en: "Recipe Name"), text: $name)
                    
                    Picker(store.t(nl: "Categorie", en: "Category"), selection: $category) {
                        ForEach(commonCategories, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    if category == "Anders / Zelf typen..." {
                        TextField(store.t(nl: "Typ eigen categorie...", en: "Type custom category..."), text: $customCategory)
                    }
                    
                    Picker(store.t(nl: "Doelfase", en: "Target Phase"), selection: $targetPhase) {
                        ForEach(GrowPhase.startableCases, id: \.self) { p in
                            Text(p.localized(isEnglish: store.isEnglish)).tag(p)
                        }
                    }
                }
                
                Section(header: Text(store.t(nl: "Standaard Container & Substraat", en: "Default Container & Substrate"))) {
                    let containers = store.db.presets.filter { $0.category == .container }
                    if !containers.isEmpty {
                        Picker(store.t(nl: "Kies Container Preset", en: "Choose Container Preset"), selection: $containerName) {
                            Text(store.t(nl: "Handmatig...", en: "Manual...")).tag("")
                            ForEach(containers) { p in Text(store.localizePresetName(p.name)).tag(p.name) }
                        }
                    }
                    TextField(store.t(nl: "Container (bijv. 20L Monotub, 1L Broedpot)", en: "Container"), text: $containerName)
                    
                    let substrates = store.db.presets.filter { $0.category == .substrate || $0.category == .grain }
                    if !substrates.isEmpty {
                        Picker(store.t(nl: "Kies Substraat Preset", en: "Choose Substrate Preset"), selection: $substrateName) {
                            Text(store.t(nl: "Handmatig...", en: "Manual...")).tag("")
                            ForEach(substrates) { p in Text(store.localizePresetName(p.name)).tag(p.name) }
                        }
                    }
                    TextField(store.t(nl: "Substraat / Graan naam", en: "Substrate / Grain name"), text: $substrateName)
                    
                    TextField(store.t(nl: "Spawn to Bulk Ratio (bijv. 1:2)", en: "Spawn to Bulk Ratio (e.g. 1:2)"), text: $spawnToBulkRatio)
                    
                    HStack {
                        TextField(store.t(nl: "Drooggewicht in gram (bijv. 650)", en: "Dry weight in grams (e.g. 650)"), text: $dryWeightText)
                            .keyboardType(.decimalPad)
                        Text("gram")
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }
                
                Section(header: Text(store.t(nl: "Sterilisatie & Bereidingsinstructies", en: "Sterilization & Instructions"))) {
                    let sterilizations = store.db.sterilizationPresets
                    if !sterilizations.isEmpty {
                        Picker(store.t(nl: "Kies Sterilisatie Preset", en: "Choose Sterilization Preset"), selection: $sterilizationNotes) {
                            Text(store.t(nl: "Handmatig / Geen", en: "Manual / None")).tag("")
                            ForEach(sterilizations) { s in
                                Text("\(s.name) (\(s.durationMinutes)m - \(s.pressureOrNotes))").tag("\(s.name): \(s.durationMinutes)m @ \(s.pressureOrNotes)")
                            }
                        }
                    }
                    TextField(store.t(nl: "Sterilisatie / Pasteurisatie Protocol", en: "Sterilization / Pasteurization Protocol"), text: $sterilizationNotes)
                    
                    TextField(store.t(nl: "Bereidingsinstructies (stappen, verhoudingen, tips)...", en: "Preparation instructions (steps, tips)..."), text: $preparationInstructions, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text(store.t(nl: "Ingrediënten per Batch / Pot / Bak", en: "Ingredients per Batch / Jar / Tub"))) {
                    if ingredients.isEmpty {
                        Text(store.t(nl: "Nog geen ingrediënten toegevoegd. Voeg hieronder ingrediënten toe.", en: "No ingredients added yet. Add ingredients below."))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    } else {
                        ForEach(ingredients.indices, id: \.self) { idx in
                            let ing = ingredients[idx]
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ing.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    if let linkedID = ing.linkedSupplyID, let supply = store.db.supplies.first(where: { $0.id == linkedID }) {
                                        Text(store.t(nl: "Gekoppeld: \(supply.name)", en: "Linked: \(supply.name)"))
                                            .font(.caption2)
                                            .foregroundColor(MycoTheme.green)
                                    }
                                }
                                Spacer()
                                Text("\(String(format: ing.amountPerBatch.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", ing.amountPerBatch)) \(ing.unit)")
                                    .font(.system(.subheadline, design: .monospaced).bold())
                                    .foregroundColor(MycoTheme.textPrimary)
                                
                                Button(role: .destructive) {
                                    ingredients.remove(at: idx)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(MycoTheme.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                            }
                        }
                    }
                    
                    // Add new ingredient subsection
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.t(nl: "+ Nieuw Ingrediënt Toevoegen", en: "+ Add New Ingredient"))
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                        
                        TextField(store.t(nl: "Ingrediënt naam (bijv. Kokosvezel, Rogge)", en: "Ingredient name"), text: $newIngName)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack(spacing: 8) {
                            TextField(store.t(nl: "Aantal (bijv. 500)", en: "Amount (e.g. 500)"), text: $newIngAmount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 140)
                            
                            Picker("Eenheid", selection: $newIngUnit) {
                                ForEach(commonUnits, id: \.self) { u in Text(u).tag(u) }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        if !store.db.supplies.isEmpty {
                            Picker(store.t(nl: "Koppel aan labvoorraad (optioneel)", en: "Link to lab supply (optional)"), selection: $newIngLinkedSupplyID) {
                                Text(store.t(nl: "Geen koppeling / automatisch zoeken", en: "No link / auto-match")).tag(UUID?.none)
                                ForEach(store.db.supplies) { s in
                                    Text("\(s.name) (\(s.unit))").tag(UUID?.some(s.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption)
                        }
                        
                        Button {
                            guard !newIngName.trimmingCharacters(in: .whitespaces).isEmpty,
                                  let amount = Double(newIngAmount.replacingOccurrences(of: ",", with: ".")),
                                  amount > 0 else { return }
                            ingredients.append(
                                RecipeIngredient(
                                    name: newIngName.trimmingCharacters(in: .whitespaces),
                                    amountPerBatch: amount,
                                    unit: newIngUnit,
                                    linkedSupplyID: newIngLinkedSupplyID
                                )
                            )
                            newIngName = ""
                            newIngAmount = ""
                            newIngLinkedSupplyID = nil
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                Text(store.t(nl: "Ingrediënt Toevoegen", en: "Add Ingredient"))
                                Spacer()
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .background(newIngName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : MycoTheme.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(newIngName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Nieuw Bereidingsrecept", en: "New Preparation Recipe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Annuleren", en: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Opslaan", en: "Save")) {
                        saveRecipe()
                    }
                    .font(.headline.bold())
                    .foregroundColor(MycoTheme.blue)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveRecipe() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        let effectiveCategory = category == "Anders / Zelf typen..." ? (customCategory.trimmingCharacters(in: .whitespaces).isEmpty ? "Overig" : customCategory.trimmingCharacters(in: .whitespaces)) : category
        let parsedDryWeight = Double(dryWeightText.replacingOccurrences(of: ",", with: ".")) ?? (dryWeightText.isEmpty ? 650.0 : 0.0)
        let effectiveRatio = spawnToBulkRatio.trimmingCharacters(in: .whitespaces).isEmpty ? "1:2" : spawnToBulkRatio.trimmingCharacters(in: .whitespaces)
        
        let newRecipe = PreparationRecipe(
            name: cleanName,
            category: effectiveCategory,
            targetPhase: targetPhase,
            containerName: containerName,
            substrateName: substrateName,
            spawnToBulkRatio: effectiveRatio,
            drySubstrateWeightGrams: parsedDryWeight,
            sterilizationNotes: sterilizationNotes,
            preparationInstructions: preparationInstructions,
            ingredients: ingredients
        )
        
        store.db.preparationRecipes.append(newRecipe)
        store.save()
        
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif
        
        MycoSyncManager.shared.triggerToast(message: store.t(
            nl: "✅ Recept '\(cleanName)' opgeslagen met \(ingredients.count) ingrediënten",
            en: "✅ Recipe '\(cleanName)' saved with \(ingredients.count) ingredients"
        ))
        
        dismiss()
    }
}

// MARK: - EDIT PREPARATION RECIPE SHEET VIEW
struct EditPreparationRecipeSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    let recipe: PreparationRecipe
    
    @State private var name: String
    @State private var category: String
    @State private var customCategory: String = ""
    @State private var targetPhase: GrowPhase
    @State private var containerName: String
    @State private var substrateName: String
    @State private var spawnToBulkRatio: String
    @State private var dryWeightText: String
    @State private var sterilizationNotes: String
    @State private var preparationInstructions: String
    @State private var ingredients: [RecipeIngredient]
    
    // New ingredient inputs
    @State private var newIngName: String = ""
    @State private var newIngAmount: String = ""
    @State private var newIngUnit: String = "gram"
    @State private var newIngLinkedSupplyID: UUID? = nil
    @State private var showDeleteConfirm = false
    
    private let commonCategories = ["Substraat", "Graan & Broed", "Agar & Media", "Vloeibaar Medium", "Zaagsel & Hout", "Anders / Zelf typen..."]
    private let commonUnits = ["gram", "ml", "liter", "kg", "stuks", "blokken", "potten"]

    init(recipe: PreparationRecipe) {
        self.recipe = recipe
        _name = State(initialValue: recipe.name)
        _category = State(initialValue: recipe.category)
        _targetPhase = State(initialValue: recipe.targetPhase)
        _containerName = State(initialValue: recipe.containerName)
        _substrateName = State(initialValue: recipe.substrateName)
        _spawnToBulkRatio = State(initialValue: recipe.spawnToBulkRatio)
        _dryWeightText = State(initialValue: String(format: "%.0f", recipe.drySubstrateWeightGrams))
        _sterilizationNotes = State(initialValue: recipe.sterilizationNotes)
        _preparationInstructions = State(initialValue: recipe.preparationInstructions)
        _ingredients = State(initialValue: recipe.ingredients)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(store.t(nl: "Recept Naam & Categorie", en: "Recipe Name & Category"))) {
                    TextField(store.t(nl: "Naam recept", en: "Recipe Name"), text: $name)
                    
                    Picker(store.t(nl: "Categorie", en: "Category"), selection: $category) {
                        ForEach(commonCategories, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    if category == "Anders / Zelf typen..." {
                        TextField(store.t(nl: "Typ eigen categorie...", en: "Type custom category..."), text: $customCategory)
                    }
                    
                    Picker(store.t(nl: "Doelfase", en: "Target Phase"), selection: $targetPhase) {
                        ForEach(GrowPhase.startableCases, id: \.self) { p in
                            Text(p.localized(isEnglish: store.isEnglish)).tag(p)
                        }
                    }
                }
                
                Section(header: Text(store.t(nl: "Standaard Container & Substraat", en: "Default Container & Substrate"))) {
                    let containers = store.db.presets.filter { $0.category == .container }
                    if !containers.isEmpty {
                        Picker(store.t(nl: "Kies Container Preset", en: "Choose Container Preset"), selection: $containerName) {
                            Text(store.t(nl: "Handmatig...", en: "Manual...")).tag("")
                            ForEach(containers) { p in Text(store.localizePresetName(p.name)).tag(p.name) }
                        }
                    }
                    TextField(store.t(nl: "Container", en: "Container"), text: $containerName)
                    
                    let substrates = store.db.presets.filter { $0.category == .substrate || $0.category == .grain }
                    if !substrates.isEmpty {
                        Picker(store.t(nl: "Kies Substraat Preset", en: "Choose Substrate Preset"), selection: $substrateName) {
                            Text(store.t(nl: "Handmatig...", en: "Manual...")).tag("")
                            ForEach(substrates) { p in Text(store.localizePresetName(p.name)).tag(p.name) }
                        }
                    }
                    TextField(store.t(nl: "Substraat / Graan", en: "Substrate / Grain"), text: $substrateName)
                    
                    TextField(store.t(nl: "Spawn to Bulk Ratio", en: "Spawn to Bulk Ratio"), text: $spawnToBulkRatio)
                    
                    HStack {
                        TextField(store.t(nl: "Drooggewicht in gram (voor BE%)", en: "Dry weight in grams (for BE%)"), text: $dryWeightText)
                            .keyboardType(.decimalPad)
                        Text("gram")
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }
                
                Section(header: Text(store.t(nl: "Sterilisatie & Bereidingsinstructies", en: "Sterilization & Instructions"))) {
                    let sterilizations = store.db.sterilizationPresets
                    if !sterilizations.isEmpty {
                        Picker(store.t(nl: "Kies Sterilisatie Preset", en: "Choose Sterilization Preset"), selection: $sterilizationNotes) {
                            Text(store.t(nl: "Handmatig / Geen", en: "Manual / None")).tag("")
                            ForEach(sterilizations) { s in
                                Text("\(s.name) (\(s.durationMinutes)m - \(s.pressureOrNotes))").tag("\(s.name): \(s.durationMinutes)m @ \(s.pressureOrNotes)")
                            }
                        }
                    }
                    TextField(store.t(nl: "Sterilisatie Protocol", en: "Sterilization Protocol"), text: $sterilizationNotes)
                    
                    TextField(store.t(nl: "Bereidingsinstructies...", en: "Preparation instructions..."), text: $preparationInstructions, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text(store.t(nl: "Ingrediënten per Batch / Pot / Bak", en: "Ingredients per Batch / Jar / Tub"))) {
                    if ingredients.isEmpty {
                        Text(store.t(nl: "Geen ingrediënten ingesteld.", en: "No ingredients set."))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    } else {
                        ForEach(ingredients.indices, id: \.self) { idx in
                            let ing = ingredients[idx]
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ing.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    if let linkedID = ing.linkedSupplyID, let supply = store.db.supplies.first(where: { $0.id == linkedID }) {
                                        Text(store.t(nl: "Gekoppeld: \(supply.name)", en: "Linked: \(supply.name)"))
                                            .font(.caption2)
                                            .foregroundColor(MycoTheme.green)
                                    }
                                }
                                Spacer()
                                Text("\(String(format: ing.amountPerBatch.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", ing.amountPerBatch)) \(ing.unit)")
                                    .font(.system(.subheadline, design: .monospaced).bold())
                                    .foregroundColor(MycoTheme.textPrimary)
                                
                                Button(role: .destructive) {
                                    ingredients.remove(at: idx)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(MycoTheme.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                            }
                        }
                    }
                    
                    // Add new ingredient subsection
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.t(nl: "+ Ingrediënt Toevoegen", en: "+ Add Ingredient"))
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                        
                        TextField(store.t(nl: "Ingrediënt naam", en: "Ingredient name"), text: $newIngName)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack(spacing: 8) {
                            TextField("Hoeveelheid", text: $newIngAmount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 120)
                            
                            Picker("Eenheid", selection: $newIngUnit) {
                                ForEach(commonUnits, id: \.self) { u in Text(u).tag(u) }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        if !store.db.supplies.isEmpty {
                            Picker(store.t(nl: "Koppel aan labvoorraad (optioneel)", en: "Link to lab supply (optional)"), selection: $newIngLinkedSupplyID) {
                                Text(store.t(nl: "Geen koppeling / automatisch zoeken", en: "No link / auto-match")).tag(UUID?.none)
                                ForEach(store.db.supplies) { s in
                                    Text("\(s.name) (\(s.unit))").tag(UUID?.some(s.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption)
                        }
                        
                        Button {
                            guard !newIngName.trimmingCharacters(in: .whitespaces).isEmpty,
                                  let amount = Double(newIngAmount.replacingOccurrences(of: ",", with: ".")),
                                  amount > 0 else { return }
                            ingredients.append(
                                RecipeIngredient(
                                    name: newIngName.trimmingCharacters(in: .whitespaces),
                                    amountPerBatch: amount,
                                    unit: newIngUnit,
                                    linkedSupplyID: newIngLinkedSupplyID
                                )
                            )
                            newIngName = ""
                            newIngAmount = ""
                            newIngLinkedSupplyID = nil
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                Text(store.t(nl: "Ingrediënt Toevoegen", en: "Add Ingredient"))
                                Spacer()
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .background(newIngName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : MycoTheme.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(newIngName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text(store.t(nl: "Verwijder Dit Recept", en: "Delete This Recipe"))
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Recept Bewerken", en: "Edit Recipe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Annuleren", en: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Opslaan", en: "Save")) {
                        saveChanges()
                    }
                    .font(.headline.bold())
                    .foregroundColor(MycoTheme.blue)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert(store.t(nl: "Recept Verwijderen?", en: "Delete Recipe?"), isPresented: $showDeleteConfirm) {
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
                Button(store.t(nl: "Verwijderen", en: "Delete"), role: .destructive) {
                    store.deletePreparationRecipe(id: recipe.id)
                    dismiss()
                }
            } message: {
                Text(store.t(nl: "Weet je zeker dat je '\(recipe.name)' wilt verwijderen?", en: "Are you sure you want to delete '\(recipe.name)'?"))
            }
        }
    }
    
    private func saveChanges() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        let effectiveCategory = category == "Anders / Zelf typen..." ? (customCategory.trimmingCharacters(in: .whitespaces).isEmpty ? "Overig" : customCategory.trimmingCharacters(in: .whitespaces)) : category
        let parsedDryWeight = Double(dryWeightText.replacingOccurrences(of: ",", with: ".")) ?? recipe.drySubstrateWeightGrams
        
        if let idx = store.db.preparationRecipes.firstIndex(where: { $0.id == recipe.id }) {
            store.db.preparationRecipes[idx].name = cleanName
            store.db.preparationRecipes[idx].category = effectiveCategory
            store.db.preparationRecipes[idx].targetPhase = targetPhase
            store.db.preparationRecipes[idx].containerName = containerName
            store.db.preparationRecipes[idx].substrateName = substrateName
            store.db.preparationRecipes[idx].spawnToBulkRatio = spawnToBulkRatio
            store.db.preparationRecipes[idx].drySubstrateWeightGrams = parsedDryWeight
            store.db.preparationRecipes[idx].sterilizationNotes = sterilizationNotes
            store.db.preparationRecipes[idx].preparationInstructions = preparationInstructions
            store.db.preparationRecipes[idx].ingredients = ingredients
            store.db.preparationRecipes[idx].lastModifiedAt = Date()
            store.save()
        }
        
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif
        
        MycoSyncManager.shared.triggerToast(message: store.t(
            nl: "✅ Recept succesvol bijgewerkt",
            en: "✅ Recipe successfully updated"
        ))
        
        dismiss()
    }
}
