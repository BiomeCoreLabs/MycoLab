import PhotosUI
import AVKit
import AVFoundation
import UniformTypeIdentifiers
//
//  MycoSettingsSubmenuViews.swift
//  MycoLab
//
//  Dedicated submenu views for Settings & Configuration:
//  - Themes & Custom Theme Creator (Eigen Thema Maken)
//  - Language & Localization
//  - Dashboard Camera Button Mode
//  - Security & Privacy (FaceID / Encryption)
//  - QR Code & Label Styling
//  - Sterilization & Pressure Cooker Presets
//  - Hardware & Container User Presets
//  - Smart Home & Tuya Sensor Webhook API
//  - Backup, Export & Data Management
//  - Dedicated Grow Camera & Lab Hub Mode
//

import SwiftUI
import Combine

// MARK: - 1. THEMES & CUSTOM THEME CREATOR SUBMENU
@MainActor struct ThemeSettingsSubmenuView: View {
    @EnvironmentObject var store: MycoStore
    @State private var showCustomThemeBuilder = false
    @State private var showSplashPreview = false
    @State private var selectedVideoPickerItem: PhotosPickerItem? = nil
    @State private var isImportingVideo = false
    @State private var videoImportAlertMessage: String? = nil
    @State private var showVideoImportAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Live Theme Preview Card
                activeThemePreviewCard
                
                // Section: Opstart & Splash Animatie
                splashAnimationSection
                
                // Section: Mijn Eigen Thema's
                customThemesSection
                
                // Section: Ingebouwde Thema's
                builtinThemesSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "Thema's & Vormgeving", en: "Themes & Appearance"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCustomThemeBuilder = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text(store.t(nl: "Eigen Thema", en: "Custom Theme"))
                    }
                    .font(.caption.bold())
                    .foregroundColor(MycoTheme.blue)
                }
            }
        }
        .sheet(isPresented: $showCustomThemeBuilder) {
            CustomThemeBuilderSheet()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showSplashPreview) {
            MycoSplashScreenView(isPreview: true) {
                showSplashPreview = false
            }
            .environmentObject(store)
        }
        .onChange(of: selectedVideoPickerItem) { _, newItem in
            guard let item = newItem else { return }
            loadCustomVideo(from: item)
        }
        .alert(isPresented: $showVideoImportAlert) {
            Alert(
                title: Text(store.t(nl: "Video Aanpassen", en: "Customize Video")),
                message: Text(videoImportAlertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    

    // MARK: - Splash Animation Section
    private var splashAnimationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "film.stack.fill")
                    .foregroundColor(MycoTheme.blue)
                    .font(.subheadline)
                Text(store.t(nl: "Opstart & Splash Animatie", en: "Startup & Splash Animation"))
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text(store.t(
                nl: "Kies hoe MycoLabs opstart. Als je de video niet mooi vindt, kun je hier kiezen voor een minimalistische logopuls, een eigen video inladen, of de animatie direct uitschakelen.",
                en: "Choose how MycoLabs launches. If you don't like the video, you can switch to a sleek logo pulse, import your own video, or disable it completely."
            ))
            .font(.caption)
            .foregroundColor(MycoTheme.textSecondary)
            .lineSpacing(2)
            
            // Mode Selectors
            VStack(spacing: 8) {
                ForEach(SplashAnimationMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.setSplashAnimationMode(mode)
                        }
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.icon)
                                .font(.body)
                                .foregroundColor(store.db.splashAnimationMode == mode ? MycoTheme.blue : MycoTheme.textSecondary)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.localizedTitle(isEnglish: store.isEnglish))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(mode.subtitle(isEnglish: store.isEnglish))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            if store.db.splashAnimationMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(MycoTheme.blue)
                            } else {
                                Circle()
                                    .stroke(MycoTheme.border, lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(MycoTheme.card)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(store.db.splashAnimationMode == mode ? MycoTheme.blue.opacity(0.6) : MycoTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Additional controls for Video Mode
            if store.db.splashAnimationMode == .video {
                VStack(spacing: 10) {
                    // Sound toggle
                    Toggle(isOn: Binding(
                        get: { store.db.isSplashSoundEnabled },
                        set: { _ in store.toggleSplashSound() }
                    )) {
                        HStack(spacing: 8) {
                            Image(systemName: store.db.isSplashSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .foregroundColor(store.db.isSplashSoundEnabled ? MycoTheme.green : MycoTheme.textSecondary)
                                .font(.caption)
                            Text(store.t(nl: "Video Geluid Afspelen", en: "Play Video Sound"))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: MycoTheme.blue))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(MycoTheme.card)
                    .cornerRadius(10)
                    
                    // Video customization buttons
                    HStack(spacing: 10) {
                        // Preview Button
                        Button {
                            showSplashPreview = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.circle.fill")
                                Text(store.t(nl: "Voorvertoning", en: "Preview"))
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(MycoTheme.blue)
                            .cornerRadius(10)
                        }
                        
                        // Custom Video Picker
                        let chooseVideoTitle = store.t(nl: "Kies Eigen Video", en: "Choose Video")
                        PhotosPicker(selection: $selectedVideoPickerItem, matching: .videos) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.badge.plus")
                                Text(chooseVideoTitle)
                            }
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(MycoTheme.card)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(MycoTheme.blue.opacity(0.5), lineWidth: 1))
                        }
                    }
                    
                    if SplashVideoManager.shared.hasCustomVideo {
                        Button {
                            SplashVideoManager.shared.removeCustomVideo()
                            videoImportAlertMessage = store.t(nl: "Standaard video animycolab.mp4 is hersteld.", en: "Default video animycolab.mp4 restored.")
                            showVideoImportAlert = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text(store.t(nl: "Herstel naar Standaard Video (animycolab.mp4)", en: "Reset to Default Video (animycolab.mp4)"))
                            }
                            .font(.caption2.bold())
                            .foregroundColor(MycoTheme.red)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.top, 4)
            } else if store.db.splashAnimationMode == .modernLogo {
                Button {
                    showSplashPreview = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                        Text(store.t(nl: "Voorvertoning Logo Puls", en: "Preview Logo Pulse"))
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(MycoTheme.blue)
                    .cornerRadius(10)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(MycoTheme.card.opacity(0.5))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
    }
    
    @MainActor
    private func loadCustomVideo(from item: PhotosPickerItem) {
        isImportingVideo = true
        Task {
            let result = try? await item.loadTransferable(type: Data.self)
            await MainActor.run {
                self.isImportingVideo = false
                if let data = result, !data.isEmpty {
                    let success = SplashVideoManager.shared.saveCustomVideoData(data)
                    if success {
                        self.videoImportAlertMessage = self.store.t(
                            nl: "Je eigen video is succesvol ingesteld als opstart-animatie! Je kunt hem meteen testen via 'Voorvertoning'.",
                            en: "Your custom video has been set as startup animation! You can test it via 'Preview'."
                        )
                    } else {
                        self.videoImportAlertMessage = self.store.t(nl: "Kon video niet opslaan.", en: "Could not save video.")
                    }
                } else {
                    self.videoImportAlertMessage = self.store.t(nl: "Geen geldige videodata ontvangen.", en: "No valid video data received.")
                }
                self.showVideoImportAlert = true
            }
        }
    }

    // MARK: - Active Preview Card
    private var activeThemePreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(MycoTheme.green)
                        .frame(width: 8, height: 8)
                    Text(store.t(nl: "Actief Thema Voorbeeld", en: "Active Theme Preview"))
                        .font(.caption2.bold())
                        .foregroundColor(MycoTheme.green)
                }
                Spacer()
                Text(store.currentThemeTitle)
                    .font(.caption.bold())
                    .foregroundColor(MycoTheme.blue)
            }
            
            // Mock grow card
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(MycoTheme.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .foregroundColor(MycoTheme.blue)
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lion's Mane #01")
                        .font(.subheadline.bold())
                        .foregroundColor(MycoTheme.textPrimary)
                    Text(store.t(nl: "Fruiting Stage • 94% RH • 23.5°C", en: "Fruiting Stage • 94% RH • 23.5°C"))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                }
                Spacer()
                Text(store.t(nl: "OOGSTKLAAR", en: "READY TO HARVEST"))
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(MycoTheme.green.opacity(0.2))
                    .foregroundColor(MycoTheme.green)
                    .cornerRadius(4)
            }
            .padding(12)
            .background(MycoTheme.card)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(MycoTheme.border, lineWidth: 1))
        }
        .padding(14)
        .background(MycoTheme.card.opacity(0.6))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
    }
    
    // MARK: - Custom Themes Section
    private var customThemesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(store.t(nl: "Mijn Eigen Thema's", en: "My Custom Themes"))
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showCustomThemeBuilder = true
                } label: {
                    Text(store.t(nl: "+ Nieuw Thema Maken", en: "+ Create New Theme"))
                        .font(.caption.bold())
                        .foregroundColor(MycoTheme.blue)
                }
            }
            
            if store.db.customThemes.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "paintpalette")
                        .font(.title3)
                        .foregroundColor(MycoTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Nog geen eigen thema's", en: "No custom themes yet"))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(store.t(nl: "Kies je favoriete achtergrond, kaarttinten en accentkleuren.", en: "Pick your favorite background, card tones, and accent colors."))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(MycoTheme.card)
                .cornerRadius(10)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.db.customThemes) { custom in
                        HStack(spacing: 12) {
                            // Swatches
                            HStack(spacing: -5) {
                                Circle().fill(Color(hex: custom.bgHex)).frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                                Circle().fill(Color(hex: custom.cardHex)).frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                                Circle().fill(Color(hex: custom.primaryAccentHex)).frame(width: 18, height: 18)
                                Circle().fill(Color(hex: custom.secondaryAccentHex)).frame(width: 18, height: 18)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(custom.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.t(nl: "Aangepast Kleurenpalet", en: "Custom Color Palette"))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            if store.db.selectedCustomThemeId == custom.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(Color(hex: custom.primaryAccentHex))
                            }
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    store.deleteCustomTheme(id: custom.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(Color.red.opacity(0.8))
                                    .padding(6)
                            }
                        }
                        .padding(12)
                        .background(MycoTheme.card)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(store.db.selectedCustomThemeId == custom.id ? Color(hex: custom.primaryAccentHex) : MycoTheme.border, lineWidth: 1.2)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                store.applyCustomTheme(custom)
                            }
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Builtin Themes Section
    private var builtinThemesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.t(nl: "Ingebouwde Thema's", en: "Built-in Themes"))
                .font(.subheadline.bold())
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                ForEach(AppTheme.allCases) { theme in
                    HStack(spacing: 12) {
                        HStack(spacing: -5) {
                            Circle().fill(theme.bg).frame(width: 18, height: 18)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                            Circle().fill(theme.card).frame(width: 18, height: 18)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                            Circle().fill(theme.blue).frame(width: 18, height: 18)
                            Circle().fill(theme.green).frame(width: 18, height: 18)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: theme.icon)
                                    .font(.caption2)
                                    .foregroundColor(theme.blue)
                                Text(theme.localizedTitle(isEnglish: store.isEnglish))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                            Text(theme.localizedSubtitle(isEnglish: store.isEnglish))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if store.db.selectedCustomThemeId == nil && store.currentTheme == theme {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(theme.blue)
                        }
                    }
                    .padding(12)
                    .background(MycoTheme.card)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(store.db.selectedCustomThemeId == nil && store.currentTheme == theme ? theme.blue : MycoTheme.border, lineWidth: 1.2)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            store.applyBuiltinTheme(theme)
                        }
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                    }
                }
            }
        }
    }
}


// MARK: - Geavanceerde Kweek- & Klimaatinstellingen (Volledig Vrije Invoer)
struct AdvancedClimateAndLabSettingsSubmenuView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @State private var showSavedToast = false

    var body: some View {
        Form {
            // MARK: - 1. Temperatuur & Dag/Nacht Schema
            Section(
                header: Text(store.t(nl: "Temperatuur & Dag/Nacht Schema", en: "Temperature & Day/Night Schedule")),
                footer: Text(store.t(
                    nl: "Stel de gewenste dag- en nachttemperaturen in. Het schema schakelt automatisch op basis van de ingestelde uren.",
                    en: "Set target day and night temperatures. The schedule switches automatically based on configured hours."
                ))
            ) {
                HStack {
                    Text(store.t(nl: "Doel Dagtemperatuur", en: "Target Day Temp"))
                    Spacer()
                    TextField("23.5", value: $store.db.environmentConfig.targetDayTempC, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 65)
                        .font(.body.bold())
                    Text("°C")
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.targetDayTempC, in: 10.0...35.0, step: 0.5)
                        .labelsHidden()
                }

                HStack {
                    Text(store.t(nl: "Doel Nachttemperatuur", en: "Target Night Temp"))
                    Spacer()
                    TextField("19.5", value: $store.db.environmentConfig.targetNightTempC, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 65)
                        .font(.body.bold())
                    Text("°C")
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.targetNightTempC, in: 10.0...35.0, step: 0.5)
                        .labelsHidden()
                }

                Toggle(isOn: $store.db.environmentConfig.isDayNightCycleEnabled) {
                    Text(store.t(nl: "Dag/Nacht Cyclus Actief", en: "Day/Night Cycle Active"))
                }
                .tint(MycoTheme.green)

                if store.db.environmentConfig.isDayNightCycleEnabled {
                    Picker(store.t(nl: "Dag Start Uur", en: "Day Start Hour"), selection: $store.db.environmentConfig.dayStartHour) {
                        ForEach(0..<24) { h in
                            Text(String(format: "%02d:00", h)).tag(h)
                        }
                    }

                    Picker(store.t(nl: "Nacht Start Uur", en: "Night Start Hour"), selection: $store.db.environmentConfig.nightStartHour) {
                        ForEach(0..<24) { h in
                            Text(String(format: "%02d:00", h)).tag(h)
                        }
                    }
                }

                HStack {
                    Text(store.t(nl: "Temperatuur Hysteresis", en: "Temperature Hysteresis"))
                    Spacer()
                    TextField("0.5", value: $store.db.environmentConfig.tempHysteresisC, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                        .font(.body.bold())
                    Text("°C")
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.tempHysteresisC, in: 0.1...3.0, step: 0.1)
                        .labelsHidden()
                }
            }

            // MARK: - 2. Luchtvochtigheid & Bevochtiging
            Section(
                header: Text(store.t(nl: "Luchtvochtigheid & Nevel", en: "Humidity & Mist Control")),
                footer: Text(store.t(
                    nl: "Hysteresis bepaalt hoeveel procent de luchtvochtigheid mag dalen voor de bevochtiger automatisch aanslaat.",
                    en: "Hysteresis controls how many percent humidity may drop before the humidifier kicks in automatically."
                ))
            ) {
                HStack {
                    Text(store.t(nl: "Doel Luchtvochtigheid", en: "Target Humidity"))
                    Spacer()
                    TextField("90", value: $store.db.environmentConfig.targetHumidityPct, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 55)
                        .font(.body.bold())
                    Text("% RH")
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.targetHumidityPct, in: 40.0...99.0, step: 1.0)
                        .labelsHidden()
                }

                HStack {
                    Text(store.t(nl: "Vochtigheid Hysteresis", en: "Humidity Hysteresis"))
                    Spacer()
                    TextField("2.0", value: $store.db.environmentConfig.humidityHysteresisPct, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                        .font(.body.bold())
                    Text("%")
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.humidityHysteresisPct, in: 0.5...10.0, step: 0.5)
                        .labelsHidden()
                }

                HStack {
                    Text(store.t(nl: "Bevochtiger Looptijd / puls", en: "Humidifier Run / pulse"))
                    Spacer()
                    TextField("120", value: $store.db.environmentConfig.humidifierDurationSeconds, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 55)
                        .font(.body.bold())
                    Text(store.t(nl: "sec", en: "sec"))
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.humidifierDurationSeconds, in: 10...600, step: 10)
                        .labelsHidden()
                }
            }

            // MARK: - 3. Verse Lucht (FAE) & CO2 Drempel
            Section(
                header: Text(store.t(nl: "Verse Lucht (FAE) & CO2 Drempel", en: "Fresh Air (FAE) & CO2 Limit")),
                footer: Text(store.t(
                    nl: "Stel de ventilatiecyclus en de maximale CO2 drempel in. Bij overschrijding wordt direct geventileerd.",
                    en: "Configure FAE exhaust cycles and max CO2 limit. Ventilation triggers immediately when exceeded."
                ))
            ) {
                HStack {
                    Text(store.t(nl: "FAE Interval (elke)", en: "FAE Interval (every)"))
                    Spacer()
                    TextField("180", value: $store.db.environmentConfig.faeIntervalMinutes, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 55)
                        .font(.body.bold())
                    Text(store.t(nl: "min", en: "min"))
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.faeIntervalMinutes, in: 10...720, step: 10)
                        .labelsHidden()
                }

                HStack {
                    Text(store.t(nl: "FAE Looptijd", en: "FAE Run Duration"))
                    Spacer()
                    TextField("5", value: $store.db.environmentConfig.faeDurationMinutes, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 45)
                        .font(.body.bold())
                    Text(store.t(nl: "min", en: "min"))
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.faeDurationMinutes, in: 1...30, step: 1)
                        .labelsHidden()
                }

                HStack {
                    Text(store.t(nl: "Max CO2 Ventilatiedrempel", en: "Max CO2 Vent Threshold"))
                    Spacer()
                    TextField("1000", value: $store.db.environmentConfig.maxCo2ThresholdPpm, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .font(.body.bold())
                    Text("ppm")
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.maxCo2ThresholdPpm, in: 400...3000, step: 50)
                        .labelsHidden()
                }
            }

            // MARK: - 4. Pinning / Koudeval Shock Instellingen
            Section(
                header: Text(store.t(nl: "Pinning & Koudeval Parameters", en: "Pinning & Cold Shock Parameters")),
                footer: Text(store.t(
                    nl: "Wanneer je de pinning shock activeert (handmatig of via spraak), verlaagt MycoLabs de temperatuur en intensiveert de verse lucht.",
                    en: "When you trigger a pinning shock (manually or by voice), MycoLabs drops temperature and boosts fresh air exchange."
                ))
            ) {
                HStack {
                    Text(store.t(nl: "Pinning Doeltemperatuur", en: "Pinning Target Temp"))
                    Spacer()
                    TextField("18.5", value: $store.db.environmentConfig.pinningTargetTempC, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 65)
                        .font(.body.bold())
                    Text("°C")
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.pinningTargetTempC, in: 10.0...25.0, step: 0.5)
                        .labelsHidden()
                }

                HStack {
                    Text(store.t(nl: "Pinning FAE Multiplier", en: "Pinning FAE Multiplier"))
                    Spacer()
                    TextField("2.0", value: $store.db.environmentConfig.pinningFaeMultiplier, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                        .font(.body.bold())
                    Text("x")
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.pinningFaeMultiplier, in: 1.0...5.0, step: 0.5)
                        .labelsHidden()
                }
            }

            // MARK: - 5. Kweekcamera Timelapse Interval (Vrije Invoer)
            Section(
                header: Text(store.t(nl: "Kweekcamera Timelapse Interval", en: "Grow Camera Timelapse Interval")),
                footer: Text(store.t(
                    nl: "Kies een exact interval in minuten voor de timelapse. Geen verplichte vaste opties; je kunt elk getal invoeren.",
                    en: "Choose an exact interval in minutes for timelapse. No forced presets; you can enter any custom number."
                ))
            ) {
                HStack {
                    Text(store.t(nl: "Timelapse Interval", en: "Timelapse Interval"))
                    Spacer()
                    TextField("15", value: $store.db.environmentConfig.customTimelapseIntervalMinutes, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .font(.body.bold())
                    Text(store.t(nl: "minuten", en: "minutes"))
                        .foregroundColor(MycoTheme.textSecondary)
                    Stepper("", value: $store.db.environmentConfig.customTimelapseIntervalMinutes, in: 1...1440, step: 5)
                        .labelsHidden()
                }
            }

            // MARK: - 6. Opslaan Actie
            Section {
                Button {
                    store.saveImmediately()
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    showSavedToast = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(MycoTheme.green)
                        Text(store.t(nl: "Instellingen Opslaan & Toepassen", en: "Save & Apply Settings"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "Klimaat- & Kweekinstellingen", en: "Climate & Grow Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if showSavedToast {
                Text(store.t(nl: "✅ Instellingen direct opgeslagen!", en: "✅ Settings saved immediately!"))
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(MycoTheme.card)
                    .cornerRadius(20)
                    .shadow(radius: 6)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation { showSavedToast = false }
                        }
                    }
            }
        }
    }
}

// MARK: - CUSTOM THEME BUILDER SHEET
struct CustomThemeBuilderSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var themeName: String = ""
    @State private var selectedBasePaletteIndex: Int = 0
    @State private var primaryColor: Color = Color(hex: "00D2D3")
    @State private var secondaryColor: Color = Color(hex: "00C853")
    
    // Preset Dark Base Canvas Palettes
    private struct BasePalette {
        let title: String
        let sub: String
        let bgHex: String
        let cardHex: String
        let borderHex: String
    }
    
    private let basePalettes: [BasePalette] = [
        BasePalette(title: "OLED Zwart", sub: "100% Puur Zwart & Batterijbesparing", bgHex: "000000", cardHex: "0D1117", borderHex: "21262D"),
        BasePalette(title: "Donker Laboratorium", sub: "Cleanroom grafietgrijs", bgHex: "121417", cardHex: "1B1F24", borderHex: "2A2E35"),
        BasePalette(title: "Diep Woud", sub: "Organisch mycelium bosnacht", bgHex: "08140E", cardHex: "0F241A", borderHex: "193829"),
        BasePalette(title: "Cyber Midnight", sub: "Futuristisch diep spaceblauw", bgHex: "070B14", cardHex: "101828", borderHex: "1A2840"),
        BasePalette(title: "Cosmic Mycota", sub: "Mystiek aards violet", bgHex: "0E0A17", cardHex: "1A1428", borderHex: "2C2042"),
        BasePalette(title: "Warm Houtskool", sub: "Aards substraat amberzwart", bgHex: "14110E", cardHex: "211C18", borderHex: "332B25")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: basePalettes[selectedBasePaletteIndex].bgHex).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        // Section 1: Live Interactive Preview
                        liveCardPreview
                        
                        // Section 2: Name Input
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.t(nl: "Themanaam", en: "Theme Name"))
                                .font(.caption.bold())
                                .foregroundColor(primaryColor)
                            TextField(store.t(nl: "Bijv. Mijn Neon Spore Lab", en: "e.g. My Neon Spore Lab"), text: $themeName)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(14)
                        .background(Color(hex: basePalettes[selectedBasePaletteIndex].cardHex))
                        .cornerRadius(12)
                        
                        // Section 3: Base Background Tone Picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text(store.t(nl: "Basis Achtergrond & Kaartkleur", en: "Base Background & Card Canvas"))
                                .font(.caption.bold())
                                .foregroundColor(primaryColor)
                            
                            ForEach(Array(basePalettes.enumerated()), id: \.offset) { index, pal in
                                HStack {
                                    HStack(spacing: 8) {
                                        Circle().fill(Color(hex: pal.bgHex)).frame(width: 20, height: 20)
                                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                        Circle().fill(Color(hex: pal.cardHex)).frame(width: 20, height: 20)
                                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pal.title)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                        Text(pal.sub)
                                            .font(.caption2)
                                            .foregroundColor(Color.gray)
                                    }
                                    Spacer()
                                    if selectedBasePaletteIndex == index {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(primaryColor)
                                    }
                                }
                                .padding(10)
                                .background(Color(hex: pal.cardHex).opacity(0.7))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedBasePaletteIndex == index ? primaryColor : Color(hex: pal.borderHex), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedBasePaletteIndex = index
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(hex: basePalettes[selectedBasePaletteIndex].cardHex))
                        .cornerRadius(12)
                        
                        // Section 4: Accent Color Pickers
                        VStack(alignment: .leading, spacing: 14) {
                            Text(store.t(nl: "Kies Jouw Accentkleuren", en: "Pick Your Accent Colors"))
                                .font(.caption.bold())
                                .foregroundColor(primaryColor)
                            
                            ColorPicker(store.t(nl: "Primaire Accentkleur (Knoppen & Titels)", en: "Primary Accent Color (Buttons & Titles)"), selection: $primaryColor)
                                .foregroundColor(.white)
                                .font(.subheadline)
                            
                            ColorPicker(store.t(nl: "Secundaire Kleur (Succes & Indicatoren)", en: "Secondary Color (Success & Badges)"), selection: $secondaryColor)
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                        .padding(14)
                        .background(Color(hex: basePalettes[selectedBasePaletteIndex].cardHex))
                        .cornerRadius(12)
                        
                        // Save Button
                        Button {
                            saveTheme()
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text(store.t(nl: "Thema Opslaan & Direct Toepassen", en: "Save & Apply Theme"))
                            }
                            .font(.headline.bold())
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(primaryColor)
                            .cornerRadius(12)
                        }
                        .disabled(themeName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(themeName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(store.t(nl: "Eigen Thema Maken", en: "Create Custom Theme"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Annuleer", en: "Cancel")) { dismiss() }
                        .foregroundColor(Color.gray)
                }
            }
        }
    }
    
    private var liveCardPreview: some View {
        let base = basePalettes[selectedBasePaletteIndex]
        return VStack(alignment: .leading, spacing: 10) {
            Text(store.t(nl: "Live Voorbeeld Kweekkaart", en: "Live Grow Card Preview"))
                .font(.caption2.bold())
                .foregroundColor(primaryColor)
            
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(primaryColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "drop.fill")
                            .font(.title3)
                            .foregroundColor(primaryColor)
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(themeName.isEmpty ? "Blauwe Oesterzwam (Cluster A)" : themeName)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Text("Monotub #2 • Flush 1 • 23.8°C")
                        .font(.caption2)
                        .foregroundColor(Color.gray)
                }
                Spacer()
                
                Text(store.t(nl: "OPTIMAAL", en: "OPTIMAL"))
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(secondaryColor.opacity(0.2))
                    .foregroundColor(secondaryColor)
                    .cornerRadius(6)
            }
            .padding(14)
            .background(Color(hex: base.cardHex))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: base.borderHex), lineWidth: 1.2))
        }
        .padding(14)
        .background(Color(hex: base.cardHex).opacity(0.4))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(primaryColor.opacity(0.4), lineWidth: 1.2))
    }
    
    private func saveTheme() {
        let cleanName = themeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        let base = basePalettes[selectedBasePaletteIndex]
        let pColorHex = primaryColor.toHexRGB()
        let sColorHex = secondaryColor.toHexRGB()
        
        let newCustom = CustomAppTheme(
            id: UUID(),
            name: cleanName,
            bgHex: base.bgHex,
            cardHex: base.cardHex,
            borderHex: base.borderHex,
            primaryAccentHex: pColorHex,
            secondaryAccentHex: sColorHex,
            textPrimaryHex: "FFFFFF",
            textSecondaryHex: "8E97A6"
        )
        
        withAnimation(.easeInOut(duration: 0.25)) {
            store.saveCustomTheme(newCustom)
        }
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - 2. LANGUAGE SUBMENU
struct LanguageSettingsSubmenuView: View {
    @EnvironmentObject var store: MycoStore
    
    var body: some View {
        Form {
            Section(header: Text(store.t(nl: "Kies Applicatietaal", en: "Choose Application Language"))) {
                Button {
                    selectLanguage("nl")
                } label: {
                    HStack {
                        Text("🇳🇱 Nederlands")
                            .foregroundColor(.white)
                        Spacer()
                        if store.db.language == "nl" {
                            Image(systemName: "checkmark")
                                .foregroundColor(MycoTheme.green)
                        }
                    }
                }
                
                Button {
                    selectLanguage("en")
                } label: {
                    HStack {
                        Text("🇬🇧 English")
                            .foregroundColor(.white)
                        Spacer()
                        if store.db.language == "en" {
                            Image(systemName: "checkmark")
                                .foregroundColor(MycoTheme.green)
                        }
                    }
                }
            }
            
            Section(footer: Text(store.t(
                nl: "Alle knoppen, statussen, waarschuwingen en menu's schakelen direct live over zonder herstart van de app.",
                en: "All buttons, statuses, alerts, and navigation menus switch instantly without restarting."
            ))) {
                EmptyView()
            }
        }
        .scrollContentBackground(.hidden)
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "Taal / Language", en: "Language / Taal"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func selectLanguage(_ lang: String) {
        store.db.language = lang
        store.save()
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
    }
}

// MARK: - 3. DASHBOARD CAMERA SUBMENU
struct DashboardCameraSubmenuView: View {
    @EnvironmentObject var store: MycoStore
    
    var body: some View {
        Form {
            Section(header: Text(store.t(nl: "Kweekcamera Architectuur", en: "Grow Camera Architecture"))) {
                HStack(spacing: 12) {
                    Image(systemName: "play.tv.fill")
                        .foregroundColor(Color.teal)
                        .font(.title3)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.t(nl: "Centrale Live Kijker (Meekijken)", en: "Central Live Monitor (Viewer)"))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(store.t(
                            nl: "In MycoLabs opent de Kweekcamera-knop altijd direct de live videoverbinding en volledige afstandsbediening van je kweekruimte.",
                            en: "In MycoLabs, the Grow Camera button always opens the live video feed and full remote control directly."
                        ))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MycoTheme.green)
                }
                .padding(.vertical, 6)
                
                HStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .foregroundColor(MycoTheme.blue)
                        .font(.title3)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.t(nl: "Uitzenden via Vaste Kweekcamera", en: "Broadcasting via Dedicated Grow Camera"))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(store.t(
                            nl: "Voor het uitzenden vanuit de tent open je MycoLabs op je stream-telefoon en kies je 'Vaste Kweekcamera'. Die schakelt automatisch over naar een OLED spaarscherm.",
                            en: "For broadcasting from the tent, install the separate MycoCam app on your stream phone. It switches to an OLED power-saving screen automatically."
                        ))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .scrollContentBackground(.hidden)
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "Kweekcamera Info", en: "Grow Camera Info"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 4. SECURITY & PRIVACY SUBMENU
struct SecurityPrivacySubmenuView: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var security = MycoSecurityManager.shared
    
    private var bioName: String {
        MycoDevicePlatform.biometricName
    }
    
    var body: some View {
        Form {
            Section(header: Text(store.t(nl: "Toegangsbeveiliging & \(bioName)", en: "Access Security & \(bioName)"))) {
                Toggle(store.t(
                    nl: "Vergrendel gehele app met \(bioName)",
                    en: "Lock entire app with \(bioName)"
                ), isOn: $store.db.biometricLock)
                .onChange(of: store.db.biometricLock) { _, _ in store.save() }
                
                Toggle(store.t(
                    nl: "\(bioName) vereist voor Stash Vault",
                    en: "\(bioName) required for Stash Vault"
                ), isOn: $store.db.stashBiometricLock)
                .onChange(of: store.db.stashBiometricLock) { _, _ in store.save() }
                
                Toggle(store.t(
                    nl: "Incognito / Stealth Modus (Verberg namen met SKU-codes)",
                    en: "Incognito / Stealth Mode (Hide names with SKU codes)"
                ), isOn: $store.db.stealthMode)
                .onChange(of: store.db.stealthMode) { _, _ in store.save() }
            }
            
            Section(header: HStack(spacing: 6) {
                Text(store.t(nl: "Duress / Decoy PIN & Noodkluis", en: "Duress / Decoy PIN & Vault"))
                InfoTipButton(
                    title: store.t(nl: "Duress / Decoy Beveiliging", en: "Duress / Decoy Security"),
                    message: store.t(
                        nl: "Als je ooit gedwongen wordt om de app te ontgrendelen, voer je de Decoy PIN in op het vergrendelscherm. De app ontgrendelt onmiddellijk in een decoy profiel met uitsluitend culinaire oesterzwammen. Je echte kweekbatches en voorraad blijven 100% onzichtbaar en versleuteld.",
                        en: "If coerced to unlock, enter your Decoy PIN on the lock screen. The app unlocks into an innocent decoy vault with gourmet oyster mushrooms, keeping sensitive batches and stash hidden and encrypted."
                    )
                )
            }) {
                HStack {
                    Text(store.t(nl: "Decoy PIN (Noodcode)", en: "Decoy PIN (Duress)"))
                    Spacer()
                    TextField("9999", text: $store.db.decoyPin)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: store.db.decoyPin) { _, _ in store.save() }
                }
                
                HStack {
                    Text(store.t(nl: "Master PIN (Echt Lab)", en: "Master PIN (Real Lab)"))
                    Spacer()
                    TextField("1234", text: $store.db.masterPin)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: store.db.masterPin) { _, _ in store.save() }
                }
            }
            
            Section(header: Text(store.t(nl: "Hardware Encryptie & Privacy", en: "Hardware Encryption & Privacy"))) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(MycoTheme.green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Secure Enclave & AES-GCM 256")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(store.t(nl: "Alle data lokaal op schijf en alle videostreams zijn end-to-end hardware-versleuteld.", en: "All data on disk and all video streams are end-to-end hardware encrypted."))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text(store.t(nl: "Privé Cluster & Apparaatbeveiliging", en: "Private Cluster & Device Security"))) {
                HStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(MycoTheme.green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Persoonlijke Cluster-Sleutel", en: "Personal Cluster Key"))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(store.t(
                            nl: "Wi-Fi, Bluetooth en Cloud communiceren uitsluitend tussen jouw eigen apparaten. Vreemden worden direct geweigerd.",
                            en: "Wi-Fi, Bluetooth, and Cloud communicate strictly between your own devices. Strangers are rejected automatically."
                        ))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(MycoTheme.green)
                }
                .padding(.vertical, 4)
                
                HStack {
                    Text(store.t(nl: "Cluster ID Handshake", en: "Cluster ID Handshake"))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                    Spacer()
                    Text(security.clusterHash.uppercased())
                        .font(.caption.monospaced().bold())
                        .foregroundColor(MycoTheme.green)
                }
                
                HStack {
                    Text(store.t(nl: "Apple ID iCloud Sleutel", en: "Apple ID iCloud Key"))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                    Spacer()
                    Text(store.t(nl: "Gesynchroniseerd", en: "Synchronized"))
                        .font(.caption.bold())
                        .foregroundColor(MycoTheme.green)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "Beveiliging & Privacy", en: "Security & Privacy"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 5. QR CODE SUBMENU
struct QRCodeSettingsSubmenuView: View {
    @EnvironmentObject var store: MycoStore
    
    private var previewImage: UIImage {
        QRCodeGenerator.generateImage(
            from: "MYCOLAB-BATCH-LC01",
            size: 260,
            includeLogo: store.db.includeLogoInQR,
            correctionLevel: store.db.qrErrorCorrectionLevel
        )
    }
    
    var body: some View {
        Form {
            // Live Interactive Preview
            Section(header: Text(store.t(nl: "Interactieve Label Preview", en: "Interactive Label Preview"))) {
                VStack(spacing: 12) {
                    Image(uiImage: previewImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
                    
                    VStack(spacing: 4) {
                        Text("Lion's Mane Liquid Culture #01")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        HStack(spacing: 8) {
                            Text(labelSizeText(store.db.qrLabelPresetSize))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(MycoTheme.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MycoTheme.blue.opacity(0.15))
                                .cornerRadius(4)
                            
                            Text("Level-\(store.db.qrErrorCorrectionLevel) (Reed-Solomon)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(MycoTheme.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MycoTheme.green.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            
            // Foutcorrectie & Logo
            Section(header: Text(store.t(nl: "Foutcorrectie & Opmaak", en: "Error Correction & Design")),
                    footer: Text(store.t(
                        nl: "Level-H (30%) is sterk aanbevolen in kweekruimtes: de QR-code blijft scanbaar, zelfs als deze nat wordt, beslaat door condens of bedekt wordt door het MycoLabs logo in het midden.",
                        en: "Level-H (30%) is strongly recommended in grow rooms: the code remains 100% scan-ready even when wet, misted by humidity, or covered by the center logo."
                    ))) {
                Picker(store.t(nl: "Foutcorrectieniveau", en: "Error Correction Level"), selection: $store.db.qrErrorCorrectionLevel) {
                    Text(store.t(nl: "Level L (7% - Laagste dichtheid)", en: "Level L (7% - Low density)")).tag("L")
                    Text(store.t(nl: "Level M (15% - Standaard)", en: "Level M (15% - Standard)")).tag("M")
                    Text(store.t(nl: "Level Q (25% - Hoge betrouwbaarheid)", en: "Level Q (25% - High reliability)")).tag("Q")
                    Text(store.t(nl: "Level H (30% - Maximaal / Aanbevolen)", en: "Level H (30% - Maximum / Recommended)")).tag("H")
                }
                .onChange(of: store.db.qrErrorCorrectionLevel) { _, _ in store.save() }
                
                Toggle(store.t(
                    nl: "MycoLabs logo toevoegen in het midden",
                    en: "Include MycoLabs logo in center"
                ), isOn: $store.db.includeLogoInQR)
                .onChange(of: store.db.includeLogoInQR) { _, newVal in
                    if newVal && store.db.qrErrorCorrectionLevel != "H" {
                        store.db.qrErrorCorrectionLevel = "H"
                    }
                    store.save()
                }
            }
            
            // Label Formaten & Presets
            Section(header: Text(store.t(nl: "Label Formaten & Print Presets", en: "Label Formats & Print Presets")),
                    footer: Text(store.t(
                        nl: "Direct compatibel met Brother QL, Dymo LabelWriter, Zebra en AirPrint printers.",
                        en: "Directly compatible with Brother QL, Dymo LabelWriter, Zebra and AirPrint printers."
                    ))) {
                Picker(store.t(nl: "Standaard Labelformaat", en: "Default Label Size"), selection: $store.db.qrLabelPresetSize) {
                    Text(store.t(nl: "38 x 38 mm (Standaard Potten & Zakken)", en: "38 x 38 mm (Standard Jars & Bags)")).tag("38x38")
                    Text(store.t(nl: "25 x 25 mm (Reageerbuis & Slant)", en: "25 x 25 mm (Test tube & Slant)")).tag("25x25")
                    Text(store.t(nl: "50 x 50 mm (Grote Monotub & Bakken)", en: "50 x 50 mm (Large Monotub & Tubs)")).tag("50x50")
                    Text(store.t(nl: "A4 Stickervel (24 labels per pagina)", en: "A4 Sticker Sheet (24 labels per page)")).tag("a4")
                }
                .onChange(of: store.db.qrLabelPresetSize) { _, _ in store.save() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "QR-Codes & Labels", en: "QR Codes & Labels"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func labelSizeText(_ preset: String) -> String {
        switch preset {
        case "25x25": return "25 × 25 mm"
        case "50x50": return "50 × 50 mm"
        case "a4": return "A4 Stickervel"
        default: return "38 × 38 mm"
        }
    }
}

// MARK: - 7. USER PRESETS SUBMENU
struct UserPresetsSubmenuView: View {
    @EnvironmentObject var store: MycoStore
    
    @State private var newPresetName = ""
    @State private var newPresetCat: PresetCategory = .container
    @State private var newPresetDetails = ""
    @State private var showConfirmClearAll = false
    
    var body: some View {
        Form {
            if store.db.presets.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "pencil.and.list.clipboard")
                                .foregroundColor(MycoTheme.green)
                            Text(store.t(nl: "Volledig Blanco (Geen Presets)", en: "Completely Blank (No Presets)"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }
                        Text(store.t(
                            nl: "Er zijn geen vaste presets geladen. Je hebt de volledige vrijheid om alle potten, zakken en recepten zelf in te voeren.",
                            en: "No fixed presets loaded. You have complete freedom to define all jars, bags, and recipes yourself."
                        ))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section(header: HStack {
                    Text(store.t(nl: "Opgeslagen Presets", en: "Saved Presets"))
                    Spacer()
                    Button(role: .destructive) {
                        showConfirmClearAll = true
                    } label: {
                        Text(store.t(nl: "Wis Alles (Blanco)", en: "Clear All (Blank)"))
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.red)
                    }
                }) {
                    ForEach(store.db.presets) { p in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(p.category.localized(isEnglish: store.isEnglish)): \(store.localizePresetName(p.name))")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                if !p.details.isEmpty {
                                    Text(store.localizePresetNotes(p.details))
                                        .font(.caption2)
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                withAnimation {
                                    store.deletePreset(id: p.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.red)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            if idx < store.db.presets.count {
                                store.deletePreset(id: store.db.presets[idx].id)
                            }
                        }
                    }
                }
            }
            
            Section(header: Text(store.t(nl: "Nieuwe Preset Toevoegen", en: "Add New Preset"))) {
                Picker(store.t(nl: "Categorie", en: "Category"), selection: $newPresetCat) {
                    ForEach(PresetCategory.allCases, id: \.self) { c in
                        Text(c.localized(isEnglish: store.isEnglish)).tag(c)
                    }
                }
                TextField(store.t(nl: "Naam (bijv. 5L Ikea Samla)", en: "Name (e.g. 5L Ikea Samla)"), text: $newPresetName)
                TextField(store.t(nl: "Details (optioneel)", en: "Details (optional)"), text: $newPresetDetails)
                
                Button {
                    let clean = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else { return }
                    let p = UserPreset(category: newPresetCat, name: clean, details: newPresetDetails.trimmingCharacters(in: .whitespacesAndNewlines))
                    store.db.presets.append(p)
                    store.save()
                    newPresetName = ""
                    newPresetDetails = ""
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(store.t(nl: "Preset Opslaan", en: "Save Preset"))
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : MycoTheme.blue)
                    .cornerRadius(8)
                }
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "Kweek- & Container Presets", en: "Grow & Container Presets"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(store.t(nl: "Alle Presets Wissen?", en: "Clear All Presets?"), isPresented: $showConfirmClearAll) {
            Button(store.t(nl: "Annuleer", en: "Cancel"), role: .cancel) {}
            Button(store.t(nl: "Wis Alles (Start Blanco)", en: "Clear All (Start Blank)"), role: .destructive) {
                withAnimation {
                    store.db.presets.removeAll()
                    store.save()
                }
            }
        } message: {
            Text(store.t(
                nl: "Weet je zeker dat je alle opgeslagen presets wilt verwijderen? Je kunt daarna alle velden in de app handmatig invullen zonder vooringestelde keuzes.",
                en: "Are you sure you want to delete all saved presets? You can then fill in all fields across the app manually without preset choices."
            ))
        }
    }
}

// MARK: - 8. SMART HOME API SUBMENU (Home Assistant & Externe Webhooks)
struct SmartHomeApiSubmenuView: View {
    @EnvironmentObject var store: MycoStore
    @State private var showCopiedAlert = false
    @State private var showTestSentAlert = false
    @State private var isShowingHomeAssistantSheet = false
    
    var body: some View {
        Form {
            hubShortcutSection
            homeAssistantSection
            webhookSection
        }
        .scrollContentBackground(.hidden)
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "Home Assistant & Webhooks", en: "Home Assistant & Webhooks"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingHomeAssistantSheet) {
            HomeAssistantYamlSheet()
                .environmentObject(store)
        }
        .alert(store.t(nl: "Gekopieerd", en: "Copied"), isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.t(nl: "API sleutel is gekopieerd naar je klembord.", en: "API key copied to clipboard."))
        }
        .alert(store.t(nl: "Sensor Meting Ontvangen! ✅", en: "Sensor Reading Received! ✅"), isPresented: $showTestSentAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.t(nl: "De testmeting (23.4°C, 91.5% RH, 680 ppm CO2) is succesvol verwerkt en geregistreerd in je telemetry logs.", en: "Test reading (23.4°C, 91.5% RH, 680 ppm CO2) has been processed and logged successfully in your telemetry logs."))
        }
    }
    
    // MARK: - Direct Pointer to Central Smart Lab Hub
    @ViewBuilder
    private var hubShortcutSection: some View {
        Section(header: Text(store.t(nl: "Centraal Apparatenbeheer", en: "Central Device Management"))) {
            NavigationLink {
                SmartEnvironmentHubView()
                    .environmentObject(store)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(MycoTheme.green.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(MycoTheme.green)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.t(nl: "Open Smart Lab & Hardware Hub", en: "Open Smart Lab & Hardware Hub"))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(store.t(
                            nl: "\(store.db.smartDevices.count) stekkers gekoppeld • 24/7 Autopilot, Pi Server & schema's",
                            en: "\(store.db.smartDevices.count) plugs paired • 24/7 Autopilot, Pi Server & timers"
                        ))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Section: Home Assistant Integration
    @ViewBuilder
    private var homeAssistantSection: some View {
        Section(header: Text(store.t(nl: "Home Assistant & Automations", en: "Home Assistant & Automations")),
                footer: Text(store.t(
                    nl: "Exporteer kant-en-klare YAML configuraties en scripts voor Home Assistant om klimaatdata en slimme stekkers bidirectioneel te synchroniseren.",
                    en: "Export ready-to-use YAML configurations and scripts for Home Assistant to synchronize climate data and smart plugs bi-directionally."
                ))) {
            Button {
                isShowingHomeAssistantSheet = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.1, green: 0.6, blue: 0.9).opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: "house.and.flag.fill")
                            .foregroundColor(Color(red: 0.2, green: 0.7, blue: 1.0))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Home Assistant YAML Configurator", en: "Home Assistant YAML Configurator"))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(store.t(nl: "REST Command, Webhook & VPD Automations", en: "REST Command, Webhook & VPD Automations"))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Section: Webhook API
    @ViewBuilder
    private var webhookSection: some View {
        Section(header: Text(store.t(nl: "Webhook API & Externe Sensoren", en: "Webhook API & External Sensors")),
                footer: Text(store.t(
                    nl: "Stuur temperatuur, relatieve luchtvochtigheid en CO2 rechtstreeks vanuit Home Assistant, ESP32 of Apple Shortcuts naar MycoLabs.",
                    en: "Send temperature, RH and CO2 directly from Home Assistant, ESP32 or Apple Shortcuts to MycoLabs."
                ))) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t(nl: "API Sleutel", en: "API Key"))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    Text(store.db.webhookKey)
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .foregroundColor(MycoTheme.blue)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = store.db.webhookKey
                    showCopiedAlert = true
                } label: {
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundColor(MycoTheme.blue)
                }
                .buttonStyle(.borderless)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(store.t(nl: "Direct URL Scheme Endpoint", en: "Direct URL Scheme Endpoint"))
                    .font(.caption2.bold())
                    .foregroundColor(MycoTheme.textSecondary)
                Text("mycolab://sensor?key=\(store.db.webhookKey)&temp=23.5&humidity=90&co2=650")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
            }
            .padding(.vertical, 4)
            
            Button {
                store.recordSensorReading(tempC: 23.4, humidityPct: 91.5, co2Ppm: 680, source: "API Webhook Test")
                showTestSentAlert = true
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text(store.t(nl: "Verzend Test Sensor Meting (23.4°C / 91.5% RH)", en: "Send Test Sensor Reading (23.4°C / 91.5% RH)"))
                }
                .font(.caption.bold())
                .foregroundColor(MycoTheme.green)
            }
        }
    }
}

// MARK: - 9. BACKUP & DATA SUBMENU
// Complete BackupAndDataSubmenuView
struct BackupAndDataSubmenuView: View {
    @EnvironmentObject var store: MycoStore
    @State private var confirmReset = false
    @State private var showFileImporter = false
    @State private var showRestoreSuccess = false
    @State private var restoreSuccessMessage = ""
    @State private var showRestoreError = false
    @State private var restoreErrorMessage = ""
    @State private var showBackupSuccess = false
    @State private var backupSuccessMessage = ""
    
    var body: some View {
        Form {
            // Status overview
            Section(header: Text(store.t(nl: "Huidige Lab Back-up Status", en: "Current Lab Backup Status"))) {
                let pCount = store.db.projects.count
                let sCount = store.db.strains.count
                let plugCount = store.db.smartDevices.count
                let hasTuya = !store.db.environmentConfig.tuyaApiKey.isEmpty
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(MycoTheme.green)
                        Text(store.t(nl: "Volledige Lab & Tuya Kluis", en: "Full Lab & Tuya Vault"))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                    Text(store.t(
                        nl: "\(pCount) projecten • \(sCount) soorten • \(plugCount) stekkers",
                        en: "\(pCount) projects • \(sCount) strains • \(plugCount) plugs"
                    ))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(hasTuya ? MycoTheme.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(hasTuya ? store.t(nl: "Tuya Koppeling Inbegrepen", en: "Tuya Connection Included") : store.t(nl: "Geen Tuya Sleutels", en: "No Tuya Keys"))
                            .font(.caption2.bold())
                            .foregroundColor(hasTuya ? MycoTheme.green : Color.orange)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Backup Actions
            Section(header: Text(store.t(nl: "Opslaan & Exporteren", en: "Save & Export"))) {
                Button {
                    let res = store.saveCompleteBackupToFilesAndCloud()
                    if res.success {
                        backupSuccessMessage = res.message
                        showBackupSuccess = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .foregroundColor(MycoTheme.green)
                            .frame(width: 24)
                        Text(store.t(nl: "Maak Volledig Back-up Bestand (Kluis)", en: "Create Full Backup File (Vault)"))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 2)
                }
                
                ShareLink(item: store.exportBackupFileURL()) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(MycoTheme.blue)
                            .frame(width: 24)
                        Text(store.t(nl: "Exporteer / Deel Back-upbestand (JSON)", en: "Export / Share Backup File (JSON)"))
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 2)
                }
            }
            
            // Restore Actions
            Section(header: Text(store.t(nl: "Herstellen", en: "Restore"))) {
                Button {
                    do {
                        let res = try store.restoreLatestBackupFromCloudOrFiles()
                        let tuyaMsg = res.hasTuya ? store.t(nl: " én Tuya verbinding hersteld", en: " and Tuya credentials restored") : ""
                        restoreSuccessMessage = store.t(
                            nl: "✅ Meest recente back-up hersteld! (\(res.projectsCount) projecten, \(res.devicesCount) stekkers\(tuyaMsg)).",
                            en: "✅ Latest backup restored! (\(res.projectsCount) projects, \(res.devicesCount) plugs\(tuyaMsg))."
                        )
                        showRestoreSuccess = true
                    } catch {
                        restoreErrorMessage = error.localizedDescription
                        showRestoreError = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                            .foregroundColor(MycoTheme.blue)
                            .frame(width: 24)
                        Text(store.t(nl: "Herstel Meest Recente iCloud Back-up", en: "Restore Latest iCloud Backup"))
                            .font(.subheadline.bold())
                            .foregroundColor(MycoTheme.blue)
                    }
                    .padding(.vertical, 2)
                }
                
                Button {
                    showFileImporter = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(MycoTheme.amber)
                            .frame(width: 24)
                        Text(store.t(nl: "Kies & Herstel Specifiek JSON Bestand...", en: "Pick & Restore Specific JSON File..."))
                            .font(.subheadline)
                            .foregroundColor(MycoTheme.amber)
                    }
                    .padding(.vertical, 2)
                }
            }
            
            // Starter Pack
            Section(header: Text(store.t(nl: "Starterspakket", en: "Starter Pack"))) {
                Button {
                    store.seedDefaultData(packageType: .allRound, force: true)
                    MycoSyncManager.shared.triggerToast(message: store.t(
                        nl: "Starterspakket ingeladen (5 soorten, 11 presets & 8 voorraaditems)!",
                        en: "Starter pack loaded (5 strains, 11 presets & 8 supply items)!"
                    ))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .foregroundColor(MycoTheme.amber)
                            .frame(width: 24)
                        Text(store.t(nl: "Laad Volledig Starterspakket (Alles)", en: "Load Full Starter Pack (All)"))
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 2)
                }
            }
            
            privacyTelemetrySection

            // Danger Zone
            Section(header: Text(store.t(nl: "Gevaarlijke Zone", en: "Danger Zone"))) {
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(Color.red)
                            .frame(width: 24)
                        Text(store.t(nl: "Wis Alle Lab Data (Schone Start)", en: "Wipe All Lab Data (Clean Slate)"))
                            .foregroundColor(Color.red)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "Back-up & Gegevens", en: "Backup & Data"))
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedURL = urls.first else { return }
                if selectedURL.startAccessingSecurityScopedResource() {
                    defer { selectedURL.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: selectedURL)
                        try store.restoreFromData(data)
                        restoreSuccessMessage = store.t(
                            nl: "Back-up succesvol hersteld! (\(store.db.projects.count) projecten, \(store.db.strains.count) soorten)",
                            en: "Backup successfully restored! (\(store.db.projects.count) projects, \(store.db.strains.count) strains)"
                        )
                        showRestoreSuccess = true
                    } catch {
                        restoreErrorMessage = store.t(
                            nl: "Fout bij inladen van bestand: \(error.localizedDescription)",
                            en: "Error loading file: \(error.localizedDescription)"
                        )
                        showRestoreError = true
                    }
                }
            case .failure(let error):
                restoreErrorMessage = store.t(
                    nl: "Kan bestand niet openen: \(error.localizedDescription)",
                    en: "Cannot open file: \(error.localizedDescription)"
                )
                showRestoreError = true
            }
        }
        .alert(store.t(nl: "Alle data wissen?", en: "Wipe all data?"), isPresented: $confirmReset) {
            Button(store.t(nl: "Ja, maak alles 100% leeg", en: "Yes, wipe everything"), role: .destructive) {
                store.resetAllData()
            }
            Button(store.t(nl: "Annuleer", en: "Cancel"), role: .cancel) {}
        }
        .alert(store.t(nl: "Back-up Opgeslagen", en: "Backup Saved"), isPresented: $showBackupSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupSuccessMessage)
        }
        .alert(store.t(nl: "Back-up Hersteld", en: "Backup Restored"), isPresented: $showRestoreSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreSuccessMessage)
        }
        .alert(store.t(nl: "Fout bij Herstellen", en: "Restore Error"), isPresented: $showRestoreError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreErrorMessage)
        }
    }
    @ViewBuilder
    private var privacyTelemetrySection: some View {
        Section(header: Text(store.t(nl: "Privacy & App-Verbetering", en: "Privacy & App Improvement"))) {
            Toggle(isOn: Binding(get: { store.isAnonymousAnalyticsAllowed }, set: { newVal in store.isAnonymousAnalyticsAllowed = newVal })) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.t(nl: "Help MycoLabs Verbeteren", en: "Help Improve MycoLabs"))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(store.t(
                        nl: "Deel anonieme crash- en prestatiestatistieken om bugs sneller op te lossen. Bevat nooit persoonlijke gegevens, kweekfoto's of notities.",
                        en: "Share anonymous crash and performance telemetry to resolve bugs faster. Never contains personal data, grow photos, or notes."
                    ))
                    .font(.caption2)
                    .foregroundColor(MycoTheme.textSecondary)
                }
            }
            .tint(MycoTheme.green)
            .padding(.vertical, 3)
        }
    }
}


// MARK: - 10. LAB HUB & DEDICATED CAMERA SUBMENU
struct LabHubModeSubmenuView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("mycolab_is_dedicated_camera_device") private var isDedicatedCameraDevice: Bool = false
    @State private var showConfirmAlert = false
    
    var body: some View {
        Form {
            if MycoDevicePlatform.isMac {
                Section(header: Text(store.t(nl: "MacBook Rol in het Lab", en: "MacBook Lab Role"))) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "laptopcomputer.and.iphone")
                                .font(.title2)
                                .foregroundColor(MycoTheme.blue)
                            Text(store.t(nl: "Centraal Werkstation & Live Kijker", en: "Central Workstation & Live Monitor"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }
                        Text(store.t(
                            nl: "Je MacBook fungeert als hoofdwerkstation en live monitor om je kweekruimte op een groot scherm te volgen en op afstand te bedienen. Gebruik een iPhone of iPad in de kweekruimte als vaste 24/7 streamcamera.",
                            en: "Your MacBook acts as the main workstation and live monitor to watch and control your grow space on a large screen. Use an iPhone or iPad inside the grow room as a dedicated 24/7 stream camera."
                        ))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    .padding(.vertical, 6)
                }
            } else {
                Section(header: Text(store.t(nl: "Over de Vaste Kweekcamera Modus", en: "About Dedicated Camera Mode"))) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.t(
                            nl: "Transformeert deze \(MycoDevicePlatform.deviceName) in een 24/7 dedicated livestream camera en sensor-hub voor in je kweekruimte.",
                            en: "Transforms this \(MycoDevicePlatform.deviceName) into a 24/7 dedicated livestream camera and sensor hub for your grow room."
                        ))
                        .font(.subheadline)
                        .foregroundColor(.white)
                        
                        Text(store.t(
                            nl: "Alle normale menu's en tabbladen worden verborgen. De camera zendt continu HD-beeld uit, maakt timelapses en stuurt sensor- en batterijtelemetrie door naar je kweektelefoon en MacBook.",
                            en: "All standard menus and tabs are hidden. The camera broadcasts HD video continuously, captures timelapses, and streams telemetry to your phone and MacBook."
                        ))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button {
                        showConfirmAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "video.badge.waveform.fill")
                            Text(store.t(nl: "Start Vaste Kweekcamera Modus 📹", en: "Start Dedicated Camera Mode 📹"))
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "Vaste Kweekcamera", en: "Dedicated Camera"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(store.t(nl: "Schakelen naar Vaste Kweekcamera?", en: "Switch to Dedicated Grow Camera?"), isPresented: $showConfirmAlert) {
            Button(store.t(nl: "Ja, start Kweekcamera Modus", en: "Yes, start Camera Mode")) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    isDedicatedCameraDevice = true
                }
                dismiss()
            }
            Button(store.t(nl: "Annuleer", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(store.t(
                nl: "De app schakelt direct over naar de livestream HUD. Je kunt later altijd weer terugschakelen naar de gewone app via het cameramenu.",
                en: "The app switches directly into the livestream HUD. You can switch back anytime via the camera menu."
            ))
        }
    }
}

// MARK: - 11. WIDGETS & TOEGANGSSCHERM SUBMENU
struct WidgetSettingsSubmenuView: View {
    @EnvironmentObject var store: MycoStore
    @State private var syncToast: Bool = false
    @State private var lastSyncTime: Date = Date()
    
    var body: some View {
        Form {
            Section(header: Text(store.t(nl: "Widget Synchronisatie", en: "Widget Synchronization"))) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundColor(MycoTheme.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "App Group Live Kweek-Feed", en: "App Group Live Grow Feed"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("group.com.mycolab.app")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    
                    Text(store.t(
                        nl: "Je widgets op het vergrendelscherm en startscherm worden automatisch ververst bij elke kweekupdate, sensorwijziging of autopilot-cyclus.",
                        en: "Your widgets on lock and home screens are automatically updated with each cultivation update, sensor change, or autopilot cycle."
                    ))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                    
                    Button {
                        MycoWidgetDataManager.shared.updateSnapshot(from: store.db)
                        lastSyncTime = Date()
                        withAnimation {
                            syncToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                syncToast = false
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: syncToast ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                            Text(syncToast ? store.t(nl: "Widgets Succesvol Bijgewerkt!", en: "Widgets Successfully Updated!") : store.t(nl: "Werk Widgets Nu Bij", en: "Update Widgets Now"))
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(syncToast ? Color.green : MycoTheme.blue)
                        .cornerRadius(10)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text(store.t(nl: "Ondersteunde Widget Formaten", en: "Supported Widget Formats"))) {
                // Toegangsscherm (Lock Screen)
                VStack(alignment: .leading, spacing: 8) {
                    Label(store.t(nl: "Vergrendelscherm (Lock Screen)", en: "Lock Screen"), systemImage: "lock.iphone")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("⭕️ " + store.t(nl: "Cirkel (Circular)", en: "Circular"))
                                .font(.caption.bold())
                                .foregroundColor(.cyan)
                            Text(store.t(nl: "Kolonisatie percentage gauge", en: "Colonization % gauge"))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("📄 " + store.t(nl: "Rechthoek", en: "Rectangular"))
                                .font(.caption.bold())
                                .foregroundColor(.cyan)
                            Text(store.t(nl: "Temp, RV, batch & alert", en: "Temp, RH, batch & alert"))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("➖ " + store.t(nl: "Inline Tekst (boven klok)", en: "Inline Text (above clock)"))
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                        Text("🍄 23.5°C • 91% RV • Lion's Mane")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
                .padding(.vertical, 4)
                
                // Beginscherm (Home Screen)
                VStack(alignment: .leading, spacing: 8) {
                    Label(store.t(nl: "Beginscherm (Home Screen)", en: "Home Screen"), systemImage: "apps.iphone")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("⬛️ " + store.t(nl: "Klein (Small 2x2)", en: "Small (2x2)"))
                                .font(.caption.bold())
                                .foregroundColor(.green)
                            Text(store.t(nl: "Grote klimaatmeters, status & B&S waarschuwing", en: "Large climate gauges, status & B&S alert"))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("🖥️ " + store.t(nl: "Medium (4x2)", en: "Medium (4x2)"))
                                .font(.caption.bold())
                                .foregroundColor(.green)
                            Text(store.t(nl: "Lab klimaat links + Actieve batch monitor rechts", en: "Lab climate left + Active batch monitor right"))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text(store.t(nl: "Hoe toe te voegen op iOS", en: "How to Add on iOS"))) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Text("1.")
                            .font(.subheadline.bold())
                            .foregroundColor(MycoTheme.blue)
                        Text(store.t(
                            nl: "Beginscherm: Houd je vinger ingedrukt op een leeg gedeelte van je beginscherm tot de iconen wiebelen.",
                            en: "Home Screen: Long press an empty area on your home screen until icons jiggle."
                        ))
                        .font(.caption)
                        .foregroundColor(.white)
                    }
                    
                    HStack(alignment: .top, spacing: 10) {
                        Text("2.")
                            .font(.subheadline.bold())
                            .foregroundColor(MycoTheme.blue)
                        Text(store.t(
                            nl: "Tik op de '+' knop linksboven in beeld en zoek naar 'MycoLabs'.",
                            en: "Tap the '+' button in the top left and search for 'MycoLabs'."
                        ))
                        .font(.caption)
                        .foregroundColor(.white)
                    }
                    
                    HStack(alignment: .top, spacing: 10) {
                        Text("3.")
                            .font(.subheadline.bold())
                            .foregroundColor(MycoTheme.blue)
                        Text(store.t(
                            nl: "Kies je gewenste formaat en sleep de widget naar je favoriete plek.",
                            en: "Select your desired size and drag the widget to your preferred position."
                        ))
                        .font(.caption)
                        .foregroundColor(.white)
                    }
                    
                    Divider().overlay(Color.white.opacity(0.1))
                    
                    HStack(alignment: .top, spacing: 10) {
                        Text("🔒")
                            .font(.subheadline)
                        Text(store.t(
                            nl: "Vergrendelscherm: Houd het vergrendelscherm ingedrukt, tik op 'Pas aan', selecteer Vergrendelscherm en tik op het widget-vak onder of boven de klok.",
                            en: "Lock Screen: Long press the lock screen, tap 'Customize', select Lock Screen, and tap the widget area under or above the clock."
                        ))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "Widgets & Toegangsscherm", en: "Widgets & Lock Screen"))
        .navigationBarTitleDisplayMode(.inline)
    }
}



// MARK: - Home Assistant YAML Configurator Sheet

struct HomeAssistantYamlSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var copiedSnippet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    
                    Picker("YAML Type", selection: $selectedTab) {
                        Text(store.t(nl: "1. REST Command", en: "1. REST Command")).tag(0)
                        Text(store.t(nl: "2. VPD Automaat", en: "2. VPD Automation")).tag(1)
                        Text(store.t(nl: "3. Shortcuts / URL", en: "3. Shortcuts / URL")).tag(2)
                    }
                    .pickerStyle(.segmented)
                    
                    codeCard
                    
                    interlockTipCard
                }
                .padding()
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Home Assistant YAML", en: "Home Assistant YAML"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(nl: "Sluit", en: "Close")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "house.lodge.fill")
                .font(.system(size: 28))
                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 1.0))
            VStack(alignment: .leading, spacing: 2) {
                Text(store.t(nl: "Home Assistant Integratie", en: "Home Assistant Integration"))
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Text(store.t(
                    nl: "Kopieer deze YAML-code direct naar Home Assistant voor automatische telemetrie-synchronisatie en VPD-schakeling.",
                    en: "Copy this YAML configuration directly into Home Assistant for automated telemetry sync and VPD control."
                ))
                .font(.caption)
                .foregroundColor(MycoTheme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MycoTheme.card)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tabTitle)
                    .font(.caption.bold())
                    .foregroundColor(MycoTheme.blue)
                Spacer()
                Button {
                    UIPasteboard.general.string = currentYamlSnippet
                    copiedSnippet = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        copiedSnippet = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedSnippet ? "checkmark.circle.fill" : "doc.on.doc.fill")
                        Text(copiedSnippet ? store.t(nl: "Gekopieerd!", en: "Copied!") : store.t(nl: "Kopieer YAML", en: "Copy YAML"))
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(copiedSnippet ? MycoTheme.green.opacity(0.2) : MycoTheme.blue.opacity(0.2))
                    .foregroundColor(copiedSnippet ? MycoTheme.green : MycoTheme.blue)
                    .cornerRadius(6)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: true) {
                Text(currentYamlSnippet)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(red: 0.9, green: 0.95, blue: 1.0))
                    .padding(12)
            }
            .background(Color.black.opacity(0.45))
            .cornerRadius(8)
            
            Text(tabInstructions)
                .font(.caption2)
                .foregroundColor(MycoTheme.textSecondary)
                .padding(.top, 4)
        }
        .padding(14)
        .background(MycoTheme.card)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var interlockTipCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.t(nl: "Tip voor veilige interlocks:", en: "Tip for safe interlocks:"))
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text(store.t(
                    nl: "MycoLabs hanteert een strikte scheiding tussen afzuiging en bevochtiging. Stel in Home Assistant een 'delay' in van minimaal 60 seconden tussen ventilator en bevochtiger om overdruk te voorkomen.",
                    en: "MycoLabs uses strict isolation between exhaust and misting. Set a minimum 60-second delay in Home Assistant between fan and humidifier to avoid pressure build-up."
                ))
                .font(.caption2)
                .foregroundColor(MycoTheme.textSecondary)
            }
        }
        .padding(12)
        .background(Color.yellow.opacity(0.08))
        .cornerRadius(10)
    }

    private var tabTitle: String {
        switch selectedTab {
        case 0: return store.t(nl: "REST Command (configuration.yaml)", en: "REST Command (configuration.yaml)")
        case 1: return store.t(nl: "VPD & Luchtvochtigheid Automaat (automations.yaml)", en: "VPD & Humidity Automation (automations.yaml)")
        default: return store.t(nl: "Apple Shortcuts & Direct URL Trigger", en: "Apple Shortcuts & Direct URL Trigger")
        }
    }

    private var tabInstructions: String {
        switch selectedTab {
        case 0:
            return store.t(
                nl: "Plak dit blok in configuration.yaml van Home Assistant. Pas eventueel de sensor-entiteitsnamen aan (bijv. sensor.tent_temperature).",
                en: "Paste this block in Home Assistant's configuration.yaml. Adjust entity IDs if needed (e.g. sensor.tent_temperature)."
            )
        case 1:
            return store.t(
                nl: "Plak dit in automations.yaml. Deze automatisering triggert bij sensorwijzigingen en stuurt live data naar MycoLabs.",
                en: "Paste this in automations.yaml. This automation triggers on sensor state changes and pushes live readings to MycoLabs."
            )
        default:
            return store.t(
                nl: "Gebruik deze URL in Apple Opdrachten (Shortcuts), curl of een ESP32 HTTP-client.",
                en: "Use this URL in Apple Shortcuts, curl or an ESP32 HTTP client."
            )
        }
    }

    private var currentYamlSnippet: String {
        let key = store.db.webhookKey
        switch selectedTab {
        case 0:
            return """
# Home Assistant: configuration.yaml
rest_command:
  mycolab_sync_climate:
    url: "http://homeassistant.local:8123/api/webhook/mycolab"
    method: POST
    content_type: "application/json"
    headers:
      Authorization: "Bearer \(key)"
    payload: >-
      {
        "api_key": "\(key)",
        "temperature_c": {{ states('sensor.tent_temperature') | float(23.0) }},
        "humidity_pct": {{ states('sensor.tent_humidity') | float(90.0) }},
        "co2_ppm": {{ states('sensor.tent_co2') | int(750) }},
        "source": "HomeAssistant-RestCommand"
      }
"""
        case 1:
            return """
# Home Assistant: automations.yaml
- id: 'mycolab_telemetry_push'
  alias: 'MycoLabs: Telemetrie Automatisch Doorsturen'
  trigger:
    - platform: state
      entity_id:
        - sensor.tent_temperature
        - sensor.tent_humidity
        - sensor.tent_co2
  action:
    - service: rest_command.mycolab_sync_climate

- id: 'mycolab_vpd_critical_alert'
  alias: 'MycoLabs: VPD Droogte Waarschuwing & Noodbevochtiging'
  trigger:
    - platform: numeric_state
      entity_id: sensor.tent_humidity
      below: 80.0
      for:
        minutes: 5
  action:
    - service: switch.turn_on
      target:
        entity_id: switch.tent_humidifier
"""
        default:
            return """
# Direct URL Scheme (Apple Shortcuts of iOS Safari):
mycolab://sensor?key=\(key)&temp=23.4&humidity=91.5&co2=680

# cURL Terminal Command:
curl -X POST "https://api.mycolab.app/v1/telemetry" \\
     -H "Content-Type: application/json" \\
     -d '{
       "key": "\(key)",
       "temp": 23.4,
       "humidity": 91.5,
       "co2": 680
     }'
"""
        }
    }
}


// MARK: - UNIFIED AI & AUTOMATION COMMAND CENTER VIEW (1 Centrale Hub voor Alle AI & Automatisering)
struct MycoAIAutomationCommandCenterView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var voiceMgr = MycoCleanroomVoiceManager.shared
    @ObservedObject private var opticalMgr = MycoOpticalHygrometerManager.shared
    
    @State private var showVoiceConsole = false
    @State private var showOpticalHygrometer = false
    @State private var showGrowSpaceConfig = false
    @State private var showDeviceSchedules = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Intro Banner
                introBannerCard
                
                // STAP 1: Cleanroom Hands-Free Voice AI
                step1VoiceCard
                
                // STAP 2: Optische Vision Hygrometer AI
                step2VisionCard
                
                // STAP 3: Autopilot & Kweekruimte AI
                step3AutopilotCard
                
                // STAP 4: Timing, Interlocks & Veiligheden (Pre-FAE Lockout, Post-FAE Herstel, Schema Ingangstijd)
                step4TimingAndSafetyCard
            }
            .padding(16)
        }
        .background(MycoTheme.bg.ignoresSafeArea())
        .navigationTitle(store.t(nl: "AI & Automatisering Hub", en: "AI & Automation Hub"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showVoiceConsole) {
            CleanroomVoiceConsoleView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showOpticalHygrometer) {
            MycoOpticalHygrometerView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showGrowSpaceConfig) {
            GrowSpaceSizeAndAIClimateView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showDeviceSchedules) {
            AutopilotDeviceSchedulesSheet()
                .environmentObject(store)
        }
    }
    
    // MARK: - Banner
    private var introBannerCard: some View {
        MycoCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.purple, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 46, height: 46)
                        Image(systemName: "sparkles")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(store.t(nl: "Centrale AI & Automatisering", en: "Central AI & Automation"))
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Text("4 STAPPEN")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.cyan)
                                .cornerRadius(4)
                        }
                        
                        Text(store.t(
                            nl: "Alle intelligente modules, spraak, vision camera's en veiligheden op 1 overzichtelijke plek.",
                            en: "All smart modules, voice, vision cameras and safety timing in 1 clear place."
                        ))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Stap 1: Voice AI
    private var step1VoiceCard: some View {
        MycoCard {
            VStack(alignment: .leading, spacing: 12) {
                stepHeader(
                    stepNum: "1",
                    title: store.t(nl: "Cleanroom Handsfree Spraak AI", en: "Cleanroom Hands-Free Voice AI"),
                    badge: voiceMgr.isListening ? store.t(nl: "ACTIEF", en: "ACTIVE") : store.t(nl: "STANDBY", en: "STANDBY"),
                    badgeColor: voiceMgr.isListening ? MycoTheme.green : Color.purple,
                    icon: "mic.fill",
                    accentColor: Color.purple
                )
                
                Text(store.t(
                    nl: "Bedien je lab steriel en handsfree via microfoon. Vraag live waarden op of stuur apparaten aan met stemcommando's.",
                    en: "Control your cleanroom hands-free via microphone. Check climate or trigger devices using voice commands."
                ))
                .font(.caption)
                .foregroundColor(MycoTheme.textSecondary)
                
                HStack(spacing: 8) {
                    Button {
                        showVoiceConsole = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.circle.fill")
                            Text(store.t(nl: "Open Spraak AI Console", en: "Open Voice AI Console"))
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    if voiceMgr.isListening {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text(store.t(nl: "Luistert mee", en: "Listening"))
                                .font(.caption2.bold())
                                .foregroundColor(Color.green)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Stap 2: Vision AI
    private var step2VisionCard: some View {
        MycoCard {
            VStack(alignment: .leading, spacing: 12) {
                stepHeader(
                    stepNum: "2",
                    title: store.t(nl: "Optische Vision Hygrometer AI", en: "Optical Vision Hygrometer AI"),
                    badge: opticalMgr.config.isEnabled ? store.t(nl: "OCR ACTIEF", en: "OCR ACTIVE") : store.t(nl: "STANDBY", en: "STANDBY"),
                    badgeColor: opticalMgr.config.isEnabled ? Color.cyan : Color.gray,
                    icon: "camera.metering.matrix",
                    accentColor: Color.cyan
                )
                
                Text(store.t(
                    nl: "Geen fysieke Wi-Fi sensor nodig: de AI leest analoge wijzers en digitale LCD-schermpjes via de kweekcamera en stuurt de Autopilot aan.",
                    en: "No physical Wi-Fi sensor needed: the AI reads analog dial needles & digital LCDs from camera and drives Autopilot."
                ))
                .font(.caption)
                .foregroundColor(MycoTheme.textSecondary)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Laatste AI Visuele Meting", en: "Latest AI Visual Reading"))
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                        if let reading = opticalMgr.lastReading {
                            Text(String(format: "%.1f%% RV", reading.humidityPct))
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundColor(Color.cyan)
                        } else {
                            Text(store.t(nl: "Nog geen meting", en: "No reading yet"))
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        showOpticalHygrometer = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "viewfinder")
                            Text(store.t(nl: "Configureer Meter AI", en: "Configure Meter AI"))
                        }
                        .font(.caption.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.cyan)
                        .cornerRadius(8)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Stap 3: Autopilot AI
    private var step3AutopilotCard: some View {
        MycoCard {
            VStack(alignment: .leading, spacing: 12) {
                stepHeader(
                    stepNum: "3",
                    title: store.t(nl: "Autopilot & Kweekruimte AI", en: "Autopilot & Grow Space AI"),
                    badge: store.db.environmentConfig.isAiClimateModelApplied ? store.t(nl: "AI ADAPTIEF", en: "AI ADAPTIVE") : store.t(nl: "STANDAARD", en: "STANDARD"),
                    badgeColor: store.db.environmentConfig.isAiClimateModelApplied ? MycoTheme.green : MycoTheme.amber,
                    icon: "slider.horizontal.3",
                    accentColor: MycoTheme.green
                )
                
                Text(store.t(
                    nl: "De AI berekent de ideale verversingstijd op basis van het tentvolume en past bevochtiging aan op basis van berekende VPD curves.",
                    en: "The AI calculates optimal refresh intervals based on chamber volume and adapts misting to VPD curves."
                ))
                .font(.caption)
                .foregroundColor(MycoTheme.textSecondary)
                
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Tentvolume:", en: "Tent volume:"))
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                        let volM3 = (store.db.environmentConfig.roomLengthCm * store.db.environmentConfig.roomWidthCm * store.db.environmentConfig.roomHeightCm) / 1_000_000.0
                        Text(String(format: "%.2f m³", volM3 > 0 ? volM3 : 1.08))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Doel RV:", en: "Target RH:"))
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                        Text(String(format: "%.0f%%", store.db.environmentConfig.targetHumidityPct))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundColor(MycoTheme.blue)
                    }
                    
                    Spacer()
                    
                    Button {
                        showGrowSpaceConfig = true
                    } label: {
                        Text(store.t(nl: "Ruimte Model", en: "Room Model"))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(MycoTheme.green)
                            .cornerRadius(8)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Stap 4: Timing, Interlocks & Veiligheden
    private var step4TimingAndSafetyCard: some View {
        MycoCard {
            VStack(alignment: .leading, spacing: 14) {
                stepHeader(
                    stepNum: "4",
                    title: store.t(nl: "Timing, Veiligheden & Schema Ingang", en: "Timing, Safeguards & Schedule Start"),
                    badge: store.t(nl: "GEAVANCEERD", en: "ADVANCED"),
                    badgeColor: MycoTheme.amber,
                    icon: "shield.lefthalf.filled",
                    accentColor: MycoTheme.amber
                )
                
                Text(store.t(
                    nl: "Stel in vanaf welk uur een nieuw schema actief wordt, en voorkom nevelverspilling voor en na de afzuiging.",
                    en: "Configure effective schedule start time, and prevent moisture waste before and after exhaust."
                ))
                .font(.caption)
                .foregroundColor(MycoTheme.textSecondary)
                
                // 1. Schema Ingangstijdstip (Effective Date & Hour)
                VStack(alignment: .leading, spacing: 6) {
                    let hasCustomStart = store.db.environmentConfig.scheduleEffectiveFrom != nil
                    Toggle(isOn: Binding(
                        get: { hasCustomStart },
                        set: { val in
                            store.db.environmentConfig.scheduleEffectiveFrom = val ? Date() : nil
                            store.save()
                        }
                    )) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(Color.cyan)
                            Text(store.t(nl: "Algemeen Schema Ingangstijdstip", en: "Global Schedule Effective Moment"))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }
                    .tint(Color.cyan)
                    
                    if hasCustomStart {
                        DatePicker(
                            store.t(nl: "Klimaatschema pas actief vanaf:", en: "Climate plan effective from:"),
                            selection: Binding(
                                get: { store.db.environmentConfig.scheduleEffectiveFrom ?? Date() },
                                set: { val in
                                    store.db.environmentConfig.scheduleEffectiveFrom = val
                                    store.save()
                                }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .font(.caption)
                        .foregroundColor(.white)
                        
                        Text(store.t(
                            nl: "Nieuwe temperatuur-, vocht- en ventilatorinstellingen gaan pas op dit exacte tijdstip in.",
                            en: "New temperature, RH and fan schedules will only take effect starting from this exact time."
                        ))
                        .font(.system(size: 10))
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                }
                .padding(10)
                .background(Color.cyan.opacity(0.08))
                .cornerRadius(8)
                
                // 2. Pre-FAE Bevochtiging-stop
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(MycoTheme.amber)
                        Text(store.t(nl: "Pre-FAE Bevochtiging-stop:", en: "Pre-FAE Mist Lockout:"))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(store.db.environmentConfig.preFaeHumidifierLockoutMinutes) " + store.t(nl: "min vóór afzuiging", en: "min before fan"))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundColor(MycoTheme.amber)
                    }
                    
                    Stepper(value: Binding(
                        get: { store.db.environmentConfig.preFaeHumidifierLockoutMinutes },
                        set: { val in
                            store.db.environmentConfig.preFaeHumidifierLockoutMinutes = val
                            store.save()
                        }
                    ), in: 0...30, step: 5) {
                        Text(store.t(
                            nl: "Stopt bevochtiging 10 of 15 minuten voordat de afzuiging start zodat verse vochtige lucht niet meteen wordt weggezogen.",
                            en: "Stops humidifier 10-15 minutes prior to exhaust so moisture isn't immediately evacuated."
                        ))
                        .font(.system(size: 10))
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                
                // 3. Post-FAE Vochtigheid Hersteltijd
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "humidity.fill")
                            .foregroundColor(Color.cyan)
                        Text(store.t(nl: "Post-FAE Vochtherstel Duur:", en: "Post-FAE Moisture Recovery:"))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Spacer()
                        if store.db.environmentConfig.postFaeRecoveryDurationSeconds == 0 {
                            Text(store.t(nl: "⚡ Dynamisch AI", en: "⚡ Dynamic AI"))
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundColor(Color.green)
                        } else {
                            Text("\(store.db.environmentConfig.postFaeRecoveryDurationSeconds) " + store.t(nl: "sec hersteltijd", en: "sec recovery"))
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundColor(Color.cyan)
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
                            nl: "Bepaalt hoelang de bevochtiger direct na de afzuiging aanstaat om de basisvochtigheid weer snel op peil te brengen.",
                            en: "Configures how long the humidifier runs immediately after exhaust to quickly return RH to baseline."
                        ))
                        .font(.system(size: 10))
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                
                // Button to open Device Schedules Sheet
                Button {
                    showDeviceSchedules = true
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.2.circlepath")
                        Text(store.t(nl: "Beheer Apparaat Schema's & Intervallen", en: "Manage Device Schedules & Intervals"))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(11)
                    .background(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Reusable Step Header
    private func stepHeader(stepNum: String, title: String, badge: String, badgeColor: Color, icon: String, accentColor: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(accentColor)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("STAP \(stepNum)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(accentColor)
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            Text(badge)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(badgeColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(badgeColor.opacity(0.15))
                .cornerRadius(4)
        }
    }
}
