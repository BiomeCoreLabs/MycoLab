//
//  MycoOpticalHygrometerView.swift
//  MycoLab
//
//  Dedicated UI voor de Autonome Optische Telelens Thermo- & Hygrometer Scanner
//

import SwiftUI
import AVFoundation
import PhotosUI
import Charts

@MainActor
public struct MycoOpticalHygrometerView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared

    @State private var showSettingsSheet = false
    @State private var showCalibrationSheet = false
    @State private var showGrowSpaceSheet = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    OpticalHardwareBannerCard()
                    OpticalCameraSourcePickerCard()
                    OpticalCalibrationBannerCard(showCalibration: $showCalibrationSheet)
                    OpticalGrowSpaceSyncCard(showGrowSpaceCalculator: $showGrowSpaceSheet)
                    OpticalLastReadingCard(showCalibration: $showCalibrationSheet)

                    if manager.isHumidifierRunning || manager.isFogSettling {
                        OpticalActiveStateCard()
                    }

                    OpticalActionButtonsCard(showCalibration: $showCalibrationSheet)
                    OpticalSimulationCard()

                    if !manager.readingHistory.isEmpty {
                        OpticalHistoryCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Telelens Optische Meter", en: "Telephoto Optical Meter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Klaar", en: "Done")) {
                        dismiss()
                    }
                    .foregroundColor(MycoTheme.blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(MycoTheme.blue)
                    }
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                OpticalHygrometerSettingsSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showCalibrationSheet) {
                OpticalMeterSetupSheet()
                    .environmentObject(store)
            }
            .task {
                if manager.config.cameraSource == .remoteStream {
                    if !LiveKitStreamManager.shared.isConnected {
                        await LiveKitStreamManager.shared.autoConnectToActiveCameraAsViewer()
                    }
                    LiveKitStreamManager.shared.requestRemoteCameras()
                }
            }
        }
    }
}

// MARK: - CAMERA SOURCE PICKER CARD
@MainActor
public struct OpticalCameraSourcePickerCard: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared
    @ObservedObject private var streamMgr = LiveKitStreamManager.shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .foregroundColor(Color.cyan)
                    .font(.subheadline)
                Text(store.t(nl: "Kies Scancamera & Lens", en: "Select Scan Camera & Lens"))
                    .font(.caption.bold())
                    .foregroundColor(MycoTheme.textPrimary)
                Spacer()
                Text(manager.activeTelephotoDescription)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.15))
                    .foregroundColor(Color.cyan)
                    .cornerRadius(6)
            }

            // 1. Bron Keuze: Kweekcamera (Livestream) vs Lokale Camera
            Picker(store.t(nl: "Camerabron", en: "Camera Source"), selection: $manager.config.cameraSource) {
                Text(store.t(nl: "📹 Kweekcamera (Stream)", en: "📹 Grow Camera (Stream)"))
                    .tag(OpticalHygrometerConfig.CameraSource.remoteStream)

                Text(store.t(nl: "📱 Dit Toestel (Lokaal)", en: "📱 This Device (Local)"))
                    .tag(OpticalHygrometerConfig.CameraSource.localDevice)
            }
            .pickerStyle(.segmented)
            .onChange(of: manager.config.cameraSource) { _, newSource in
                manager.detectTelephotoHardware()
                if newSource == .remoteStream {
                    Task {
                        await streamMgr.autoConnectToActiveCameraAsViewer()
                        streamMgr.requestRemoteCameras()
                    }
                }
            }

            // 2. Lens Details & Keuze
            if manager.config.cameraSource == .remoteStream {
                remoteCameraSelector
            } else {
                localCameraSelector
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MycoTheme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
        )
        .onAppear {
            if manager.config.cameraSource == .remoteStream {
                streamMgr.requestRemoteCameras()
            }
        }
    }

    private var remoteCameraSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.t(nl: "Meetscan Lens (Kweekcamera):", en: "Measurement Lens (Grow Camera):"))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                Spacer()

                if !streamMgr.remoteAvailableCameras.isEmpty {
                    Picker("", selection: Binding<String>(
                        get: {
                            if manager.config.preferredCameraId.isEmpty {
                                return manager.resolveRemoteTelephotoCameraID() ?? streamMgr.remoteActiveCameraID
                            }
                            return manager.config.preferredCameraId
                        },
                        set: { (newId: String) in
                            manager.config.preferredCameraId = newId
                            manager.detectTelephotoHardware()
                        }
                    )) {
                        ForEach(streamMgr.remoteAvailableCameras, id: \.id) { cam in
                            let isTele = cam.shortLabel.localizedCaseInsensitiveContains("tele") || cam.name.localizedCaseInsensitiveContains("tele") || cam.name.localizedCaseInsensitiveContains("zoom")
                            Text("\(cam.name) (\(cam.shortLabel))\(isTele ? " 🎯 Tele" : "")").tag(cam.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.cyan)
                } else {
                    Button {
                        streamMgr.sendDataCommand(command: "camera:next")
                        streamMgr.requestRemoteCameras()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "camera.rotate.fill")
                            Text(streamMgr.remoteActiveCameraLabel.isEmpty ? store.t(nl: "Wissel Lens", en: "Switch Lens") : streamMgr.remoteActiveCameraLabel)
                        }
                        .font(.caption.bold())
                        .foregroundColor(Color.cyan)
                    }
                }
            }

            Text(store.t(
                nl: "🎯 Optische meetscan gebruikt uitsluitend de telelens tijdens het aflezen en herstelt direct daarna de stream- of timelapse-camera.",
                en: "🎯 Optical measurement scan only uses the telephoto lens during reading and immediately restores the stream or timelapse camera."
            ))
            .font(.system(size: 10))
            .foregroundColor(MycoTheme.textSecondary)

            HStack(spacing: 6) {
                Circle()
                    .fill(streamMgr.isConnected ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(streamMgr.isConnected ?
                    store.t(nl: "Livestream gekoppeld via kamer '\(streamMgr.currentRoomName)'", en: "Livestream connected via room '\(streamMgr.currentRoomName)'") :
                    store.t(nl: "Kweekcamera livestream niet verbonden", en: "Grow camera livestream offline")
                )
                .font(.system(size: 10))
                .foregroundColor(streamMgr.isConnected ? Color.green : Color.orange)
                .lineLimit(1)
            }
        }
    }

    private var localCameraSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.t(nl: "Meetscan Lens (Dit Toestel):", en: "Measurement Lens (This Device):"))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                Spacer()

                Picker("", selection: Binding<String>(
                    get: {
                        if manager.config.preferredCameraId.isEmpty {
                            return manager.resolveTelephotoCameraID() ?? streamMgr.selectedCameraID
                        }
                        return manager.config.preferredCameraId
                    },
                    set: { (newId: String) in
                        manager.config.preferredCameraId = newId
                        manager.detectTelephotoHardware()
                    }
                )) {
                    ForEach(streamMgr.availableCameras, id: \.id) { cam in
                        let isTele = cam.deviceType == .builtInTelephotoCamera || cam.shortLabel.localizedCaseInsensitiveContains("tele") || cam.name.localizedCaseInsensitiveContains("tele") || cam.name.localizedCaseInsensitiveContains("zoom")
                        Text("\(cam.name) (\(cam.shortLabel))\(isTele ? " 🎯 Tele" : "")").tag(cam.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(MycoTheme.blue)
            }

            Text(store.t(
                nl: "🎯 Optische meetscan gebruikt uitsluitend de telelens tijdens het aflezen en herstelt direct daarna de actieve stream- of timelapse-camera.",
                en: "🎯 Optical measurement scan only uses the telephoto lens during reading and immediately restores the active stream or timelapse camera."
            ))
            .font(.system(size: 10))
            .foregroundColor(MycoTheme.textSecondary)
        }
    }
}

// MARK: - 1. HARDWARE BANNER CARD
@MainActor
private struct OpticalHardwareBannerCard: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared

    private func formatNextScanDate(_ nextDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: nextDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            topRow
            Divider().background(Color.white.opacity(0.1))
            intervalSelectorRow
            Divider().background(Color.white.opacity(0.1))
            bottomRow
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MycoTheme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MycoTheme.border, lineWidth: 1)
        )
    }

    private var intervalSelectorRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(store.t(nl: "Scan Frequentie:", en: "Scan Frequency:"))
                    .font(.caption2)
                    .foregroundColor(MycoTheme.textSecondary)
                Spacer()
                Text("\(manager.config.scanIntervalMinutes) min")
                    .font(.caption2.bold())
                    .foregroundColor(Color.cyan)
            }

            HStack(spacing: 6) {
                ForEach([5, 10, 15, 30, 60], id: \.self) { mins in
                    Button {
                        manager.config.scanIntervalMinutes = mins
                        if manager.config.isEnabled {
                            manager.togglePeriodicMonitoring(enabled: true)
                        }
                    } label: {
                        Text("\(mins)m")
                            .font(.caption2.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(manager.config.scanIntervalMinutes == mins ? Color.cyan : Color.white.opacity(0.08))
                            .foregroundColor(manager.config.scanIntervalMinutes == mins ? Color.black : Color.white)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    private var topRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(manager.config.isEnabled ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "binoculars.fill")
                    .font(.headline)
                    .foregroundColor(manager.config.isEnabled ? Color.blue : Color.gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(store.t(nl: "Optische Meter Scanner", en: "Optical Meter Scanner"))
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    InfoTipButton(
                        title: store.t(nl: "Optische Meter Scanner", en: "Optical Meter Scanner"),
                        message: store.t(
                            nl: "De camera scant via Apple Vision OCR autonoom je fysieke thermo/hygrometer af door het tentvenster. Zo blijft de tent hermetisch gesloten en behoud je de ideale RV en CO₂ concentraties.",
                            en: "The camera autonomously scans your physical thermo/hygrometer through the tent window using Apple Vision OCR. Keeps the tent sealed and microclimate stable."
                        ),
                        icon: "questionmark.circle.fill",
                        color: Color.cyan
                    )
                    Circle()
                        .fill(manager.config.isEnabled ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                }
                Text(manager.activeTelephotoDescription)
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
            }

            Spacer()

            Button {
                manager.togglePeriodicMonitoring(enabled: !manager.config.isEnabled)
            } label: {
                Image(systemName: manager.config.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(manager.config.isEnabled ? Color.green : Color.gray)
            }
        }
    }

    @ViewBuilder
    private var flashBadge: some View {
        if manager.config.useFlash {
            Label(store.t(nl: "Flits Aan", en: "Flash On"), systemImage: "bolt.fill")
                .font(.caption2)
                .foregroundColor(Color.yellow)
        } else {
            Label(store.t(nl: "Geen Flits", en: "No Flash"), systemImage: "bolt.slash")
                .font(.caption2)
                .foregroundColor(Color.gray)
        }
    }

    @ViewBuilder
    private var growLightsBadge: some View {
        if manager.config.useGrowLights {
            Label(store.t(nl: "Lampen Aan", en: "Lights On"), systemImage: "lightbulb.fill")
                .font(.caption2)
                .foregroundColor(Color.green)
        } else {
            Label(store.t(nl: "Lampen Uit", en: "Lights Off"), systemImage: "lightbulb.slash")
                .font(.caption2)
                .foregroundColor(Color.gray)
        }
    }

    @ViewBuilder
    private var nextScanIndicator: some View {
        if manager.config.isEnabled && !manager.isFogSettling, let nextDate = manager.nextScanDate {
            Text(store.t(nl: "Volgende: ", en: "Next: ") + formatNextScanDate(nextDate))
                .font(.caption2.bold())
                .foregroundColor(Color.cyan)
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 12) {
            flashBadge
            growLightsBadge
            Spacer()
            nextScanIndicator
        }
    }
}

// MARK: - 1B. CALIBRATION BANNER CARD
@MainActor
private struct OpticalCalibrationBannerCard: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared
    @Binding var showCalibration: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: manager.config.isConfigured ? "checkmark.seal.fill" : "viewfinder.circle.fill")
                    .font(.title2)
                    .foregroundColor(manager.config.isConfigured ? Color.green : Color.orange)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(manager.config.isConfigured
                             ? store.t(nl: "Meterzones Gekalibreerd", en: "Meter Zones Calibrated")
                             : store.t(nl: "Kalibratie / Set-up Vereist", en: "Calibration / Setup Required"))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        InfoTipButton(
                            title: store.t(nl: "Display Detectiezones", en: "Display Detection Zones"),
                            message: store.t(
                                nl: "Door de oranje (temperatuur) en blauwe (luchtvochtigheid) kaders nauwkeurig over de cijfers te plaatsen, weet de AI precies waar de cijfers staan. Dit garandeert 100% trefzekere herkenning, zelfs bij lichte nevel of reflecties.",
                                en: "By placing orange and blue boxes precisely over digits, the AI focuses directly on the numbers for maximum accuracy."
                            ),
                            icon: "questionmark.circle.fill",
                            color: Color.orange
                        )
                    }

                    Text(manager.config.isConfigured
                         ? store.t(nl: "Oranje zone: Temp • Blauwe zone: RV", en: "Orange zone: Temp • Blue zone: RH")
                         : store.t(nl: "Stel de kaders in zodat de AI weet waar te kijken.", en: "Set boxes so AI knows where to read digits."))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                }

                Spacer()

                Button {
                    showCalibration = true
                } label: {
                    Text(manager.config.isConfigured
                         ? store.t(nl: "Wijzig", en: "Edit")
                         : store.t(nl: "Instellen", en: "Set Up"))
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(manager.config.isConfigured ? Color.white.opacity(0.12) : Color.orange)
                        .foregroundColor(manager.config.isConfigured ? Color.white : Color.black)
                        .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(manager.config.isConfigured ? MycoTheme.card : Color.orange.opacity(0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(manager.config.isConfigured ? MycoTheme.border : Color.orange.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - 2. KWEEKRUIMTE & AI SYNC CARD (Replaces Bulky Mist Explanation)
@MainActor
private struct OpticalGrowSpaceSyncCard: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared
    @Binding var showGrowSpaceCalculator: Bool

    var body: some View {
        let env = store.db.environmentConfig
        let volumeM3 = env.roomVolumeM3 > 0.01 ? env.roomVolumeM3 : manager.config.chamberVolumeM3
        let outputMlH = env.humidifierOutputMlH > 0 ? env.humidifierOutputMlH : manager.config.humidifierOutputMlH

        VStack(alignment: .leading, spacing: 10) {
            // Header: Title + Status + Questionmark Info Tip
            HStack(spacing: 8) {
                Image(systemName: "cube.transparent.fill")
                    .foregroundColor(MycoTheme.green)
                    .font(.system(size: 14, weight: .bold))

                Text(store.t(nl: "Kweekruimte & AI Berekening", en: "Grow Space & AI Calculation"))
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                // InfoTipButton requested by user with questionmark circle!
                InfoTipButton(
                    title: store.t(nl: "Automatische AI Kweekruimte Berekening", en: "Automatic AI Grow Space Calculation"),
                    message: store.t(
                        nl: """
                        De optische meter gebruikt automatisch de afmetingen van je kweekruimte en het vermogen van je bevochtiger uit het AI-klimaatmodel. Handmatig invullen is niet meer nodig!

                        Zodra de bevochtiger start, vult de kweekruimte zich met dichte nevel en beslaat het fysieke display met condens. Hierdoor is realtime aflezen tijdens het nevelen onmogelijk. De AI berekent daarom vóóraf exact het aantal benodigde seconden op basis van kamervolume (\(String(format: "%.2f", volumeM3)) m³) en het actuele vochttekort.
                        """,
                        en: """
                        The optical meter automatically pulls dimensions and humidifier output from your AI grow space climate model. Manual entry is no longer required!

                        As soon as misting starts, dense fog and condensation cover the physical display. The AI calculates exact runtime upfront based on room volume (\(String(format: "%.2f", volumeM3)) m³) and humidity deficit.
                        """
                    ),
                    icon: "questionmark.circle.fill",
                    color: MycoTheme.green
                )

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(MycoTheme.green)
                        .frame(width: 6, height: 6)
                    Text(store.t(nl: "AI SYNC", en: "AI SYNC"))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(MycoTheme.green)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(MycoTheme.green.opacity(0.15))
                .cornerRadius(6)
            }

            // Metric Summary Chips
            HStack(spacing: 8) {
                // Room & Dimensions Chip
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t(nl: "RUIMTE", en: "SPACE"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(MycoTheme.textSecondary)
                    Text(env.spacePreset)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(Int(env.roomLengthCm))×\(Int(env.roomWidthCm))×\(Int(env.roomHeightCm)) cm")
                        .font(.system(size: 9))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)

                // Volume Chip
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t(nl: "VOLUME", en: "VOLUME"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(MycoTheme.textSecondary)
                    Text("\(String(format: "%.2f", volumeM3)) m³")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.cyan)
                    Text("\(Int(volumeM3 * 1000)) L")
                        .font(.system(size: 9))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)

                // Humidifier Output Chip
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t(nl: "BEVOCHTIGER", en: "HUMIDIFIER"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(MycoTheme.textSecondary)
                    Text("\(Int(outputMlH)) ml/u")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.blue)
                    Text(store.t(nl: "Capaciteit", en: "Capacity"))
                        .font(.system(size: 9))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }

            // Quick Link Button to Kweekruimte & AI Calculator
            Button {
                showGrowSpaceCalculator = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.2.square")
                        .font(.system(size: 11))
                    Text(store.t(nl: "Pas Afmetingen of Bevochtiger aan in AI Calculator", en: "Adjust Dimensions or Humidifier in AI Calculator"))
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                }
                .foregroundColor(MycoTheme.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(MycoTheme.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MycoTheme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MycoTheme.green.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Optical Zone Types & Bounding Box Overlay
enum OpticalZoneType: String, CaseIterable, Identifiable {
    case temperature
    case humidity
    case meter

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .temperature: return Color.orange
        case .humidity: return Color.cyan
        case .meter: return Color.yellow
        }
    }
}

struct OpticalROIBoundingBoxOverlay: View {
    var meterROI: NormalizedROI?
    var temperatureROI: NormalizedROI?
    var humidityROI: NormalizedROI?
    var selectedZone: OpticalZoneType? = nil
    var showLabels: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .topLeading) {
                // 1. Meter Buitenkader (Dashed Yellow)
                if let m = meterROI {
                    let rx = m.x * w
                    let ry = m.y * h
                    let rw = m.width * w
                    let rh = m.height * h

                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow.opacity(selectedZone == .meter ? 0.95 : 0.6), style: StrokeStyle(lineWidth: selectedZone == .meter ? 2.5 : 1.5, dash: selectedZone == .meter ? [8, 4] : [6, 4]))
                        .background(Color.yellow.opacity(selectedZone == .meter ? 0.15 : 0.03))
                        .frame(width: rw, height: rh)
                        .offset(x: rx, y: ry)

                    if selectedZone == .meter {
                        // Corner handles for display bounding
                        Circle().fill(Color.yellow).frame(width: 8, height: 8).offset(x: rx - 4, y: ry - 4)
                        Circle().fill(Color.yellow).frame(width: 8, height: 8).offset(x: rx + rw - 4, y: ry - 4)
                        Circle().fill(Color.yellow).frame(width: 8, height: 8).offset(x: rx - 4, y: ry + rh - 4)
                        Circle().fill(Color.yellow).frame(width: 8, height: 8).offset(x: rx + rw - 4, y: ry + rh - 4)
                    }

                    if showLabels {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 7))
                            Text(selectedZone == .meter ? "LCD Display (AI Focus)" : "Display")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.yellow.opacity(0.90))
                        .foregroundColor(.black)
                        .cornerRadius(3)
                        .offset(x: rx + 4, y: ry + 4)
                    }
                }

                // 2. Temperatuur (Oranje)
                if let t = temperatureROI {
                    let rx = t.x * w
                    let ry = t.y * h
                    let rw = t.width * w
                    let rh = t.height * h

                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.orange, lineWidth: selectedZone == .temperature ? 3.0 : 1.8)
                        .background(Color.orange.opacity(selectedZone == .temperature ? 0.25 : 0.08))
                        .frame(width: rw, height: rh)
                        .offset(x: rx, y: ry)

                    if selectedZone == .temperature {
                        // Hoekpunten voor nauwkeurige plaatsing op de cijfers
                        Circle().fill(Color.orange).frame(width: 8, height: 8).offset(x: rx - 4, y: ry - 4)
                        Circle().fill(Color.orange).frame(width: 8, height: 8).offset(x: rx + rw - 4, y: ry - 4)
                        Circle().fill(Color.orange).frame(width: 8, height: 8).offset(x: rx - 4, y: ry + rh - 4)
                        Circle().fill(Color.orange).frame(width: 8, height: 8).offset(x: rx + rw - 4, y: ry + rh - 4)
                    }

                    if showLabels {
                        HStack(spacing: 2) {
                            Image(systemName: "thermometer.medium")
                            Text("Temp")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(3)
                        .offset(x: rx + 4, y: ry + 4)
                    }
                }

                // 3. Luchtvochtigheid (Blauw)
                if let h_roi = humidityROI {
                    let rx = h_roi.x * w
                    let ry = h_roi.y * h
                    let rw = h_roi.width * w
                    let rh = h_roi.height * h

                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.cyan, lineWidth: selectedZone == .humidity ? 3.0 : 1.8)
                        .background(Color.cyan.opacity(selectedZone == .humidity ? 0.25 : 0.08))
                        .frame(width: rw, height: rh)
                        .offset(x: rx, y: ry)

                    if selectedZone == .humidity {
                        // Hoekpunten voor nauwkeurige plaatsing op de cijfers
                        Circle().fill(Color.cyan).frame(width: 8, height: 8).offset(x: rx - 4, y: ry - 4)
                        Circle().fill(Color.cyan).frame(width: 8, height: 8).offset(x: rx + rw - 4, y: ry - 4)
                        Circle().fill(Color.cyan).frame(width: 8, height: 8).offset(x: rx - 4, y: ry + rh - 4)
                        Circle().fill(Color.cyan).frame(width: 8, height: 8).offset(x: rx + rw - 4, y: ry + rh - 4)
                    }

                    if showLabels {
                        HStack(spacing: 2) {
                            Image(systemName: "humidity.fill")
                            Text("RV%")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.cyan)
                        .foregroundColor(.black)
                        .cornerRadius(3)
                        .offset(x: rx + 4, y: ry + 4)
                    }
                }
            }
        }
    }
}

// MARK: - 3. LAST READING CARD
@MainActor
private struct OpticalLastReadingCard: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared
    @Binding var showCalibration: Bool

    private func formatTimestampMedium(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.t(nl: "Laatste Optische Meting", en: "Latest Optical Reading"))
                    .font(.caption.bold())
                    .foregroundColor(MycoTheme.textSecondary)
                Spacer()
                if let reading = manager.lastReading {
                    Text(formatTimestampMedium(reading.timestamp))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                }
            }

            if let reading = manager.lastReading {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Luchtvochtigheid", en: "Humidity"))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(reading.humidityPct))")
                                .font(.system(size: 38, weight: .heavy, design: .rounded))
                                .foregroundColor(reading.humidityPct >= manager.config.targetHumidityPct ? Color.green : Color.blue)
                            Text("% RV")
                                .font(.subheadline.bold())
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }

                    if let temp = reading.temperatureC {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Temperatuur", en: "Temperature"))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(String(format: "%.1f", temp))
                                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                                    .foregroundColor(Color.orange)
                                Text("°C")
                                    .font(.subheadline.bold())
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(reading.sourceLens)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(Color.blue)
                            .cornerRadius(6)

                        if reading.sampleCount > 1 {
                            Text("\(reading.sampleCount)x Multi-Shot")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(Color.green)
                                .cornerRadius(4)
                        }

                        if reading.isFlashUsed {
                            Label("Flits", systemImage: "bolt.fill")
                                .font(.caption2)
                                .foregroundColor(Color.yellow)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Divider().background(Color.white.opacity(0.1))

                    HStack {
                        Text(store.t(nl: "Berekende Bevochtigerduur:", en: "Calculated Humidifier Duration:"))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        Text(reading.calculatedHumidifierDurationSec > 0 ? "\(reading.calculatedHumidifierDurationSec)s" : store.t(nl: "Geen (Op peil)", en: "None (On Target)"))
                            .font(.caption.bold())
                            .foregroundColor(reading.calculatedHumidifierDurationSec > 0 ? Color.cyan : Color.green)
                    }

                    if let summary = reading.verificationSummary ?? manager.lastMultiSampleSummary {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(Color.green)
                                .font(.caption)
                            Text(summary)
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                                .lineLimit(2)
                        }
                        .padding(.top, 2)
                    }
                }
            } else if let scanErr = manager.lastScanError {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.orange)
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.t(nl: "AI Herkenning Mislukt", en: "AI Recognition Failed"))
                            .font(.caption.bold())
                            .foregroundColor(Color.orange)
                        Text(scanErr)
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                        Button {
                            showCalibration = true
                        } label: {
                            Text(store.t(nl: "🎯 Pas Cijferzones Aan", en: "🎯 Adjust Digit Zones"))
                                .font(.caption2.bold())
                                .foregroundColor(Color.cyan)
                                .padding(.top, 2)
                        }
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Preview van de gemaakte foto met de AI-zones
            if let preview = manager.lastCapturedPreview {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(store.t(nl: "Camerabeeld met AI-zones:", en: "Camera view with AI zones:"))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        Button {
                            showCalibration = true
                        } label: {
                            Text(store.t(nl: "Zones Wijzigen", en: "Change Zones"))
                                .font(.caption2.bold())
                                .foregroundColor(Color.cyan)
                        }
                    }

                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .overlay(
                            OpticalROIBoundingBoxOverlay(
                                meterROI: manager.config.meterROI,
                                temperatureROI: manager.config.temperatureROI,
                                humidityROI: manager.config.humidityROI,
                                showLabels: true
                            )
                        )
                        .frame(maxHeight: 180)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
            } else if manager.lastReading == nil {
                VStack(spacing: 8) {
                    Image(systemName: "viewfinder")
                        .font(.largeTitle)
                        .foregroundColor(MycoTheme.textSecondary)
                    Text(store.t(nl: "Nog geen optische meting uitgevoerd.", en: "No optical reading taken yet."))
                        .font(.subheadline)
                        .foregroundColor(MycoTheme.textSecondary)
                    Text(store.t(nl: "Druk hieronder op 'Scan Nu' of start de set-up om beeld op te halen.", en: "Tap 'Scan Now' below or start set-up to fetch image."))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MycoTheme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MycoTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - 4. ACTIVE STATE CARD
@MainActor
private struct OpticalActiveStateCard: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if manager.isHumidifierRunning {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.cyan))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Luchtbevochtiger Nevelt...", en: "Humidifier Misting..."))
                            .font(.headline.bold())
                            .foregroundColor(Color.cyan)
                        Text(store.t(nl: "Nog \(manager.humidifierRemainingSeconds)s actief volgens vooruitberekening", en: "\(manager.humidifierRemainingSeconds)s remaining based on advance calculation"))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                }
            } else if manager.isFogSettling {
                HStack(spacing: 12) {
                    Image(systemName: "cloud.fog.fill")
                        .font(.title2)
                        .foregroundColor(Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Nevel Trekt Weg...", en: "Mist Settling..."))
                            .font(.headline.bold())
                            .foregroundColor(Color.orange)
                        let m = manager.fogSettlingRemainingSeconds / 60
                        let s = manager.fogSettlingRemainingSeconds % 60
                        Text(store.t(nl: "Display tijdelijk beslagen. Scan hervat over \(m)m \(s)s.", en: "Display fogged. Scanning resumes in \(m)m \(s)s."))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MycoTheme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MycoTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - 5. ACTION BUTTONS CARD
@MainActor
private struct OpticalActionButtonsCard: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared
    @Binding var showCalibration: Bool

    var body: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await manager.triggerScanAndReact()
                }
            } label: {
                HStack(spacing: 8) {
                    if manager.isScanning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "bolt.badge.automatic.fill")
                    }
                    let scanBtnTitle: String = {
                        if manager.isScanning {
                            return store.t(nl: "Scannen & Berekenen...", en: "Scanning & Calculating...")
                        }
                        if manager.config.cameraSource == .localDevice {
                            return store.t(nl: "Scan Nu met Dit Toestel", en: "Scan Now with This Device")
                        } else {
                            return store.t(nl: "Scan Nu met Kweekcamera", en: "Scan Now with Grow Camera")
                        }
                    }()
                    Text(scanBtnTitle)
                        .font(.headline.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(MycoTheme.blue)
                .cornerRadius(12)
            }
            .disabled(manager.isScanning)

            Button {
                showCalibration = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "viewfinder")
                    Text(store.t(nl: "🎯 Meter & Cijferzones Instellen", en: "🎯 Set Up Meter & Digit Zones"))
                        .font(.subheadline.bold())
                }
                .foregroundColor(Color.cyan)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.cyan.opacity(0.12))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                )
            }

            // Bron Indicator
            HStack(spacing: 6) {
                if LiveKitStreamManager.shared.remoteVideoTrack != nil {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text(store.t(nl: "Bron: Kweekcamera Livestream (Verbonden)", en: "Source: Grow Camera Livestream (Connected)"))
                        .font(.caption2.bold())
                        .foregroundColor(Color.green)
                } else {
                    Circle().fill(Color.cyan).frame(width: 7, height: 7)
                    Text(store.t(nl: "Bron: Lokale Camera op dit Toestel", en: "Source: Local Camera on this Device"))
                        .font(.caption2.bold())
                        .foregroundColor(MycoTheme.textSecondary)
                }
            }

            if let error = manager.lastScanError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(Color.orange.opacity(0.95))
                        .multilineTextAlignment(.leading)
                }
                .padding(8)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
            }

            Text(manager.scanStatus)
                .font(.caption2)
                .foregroundColor(MycoTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - 6. SIMULATION TEST CARD
@MainActor
private struct OpticalSimulationCard: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared
    @State private var simulationHumidity: Double = 75.0
    @State private var showSimulationCard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(store.t(nl: "⚡️ Berekening Simulator & Test", en: "⚡️ Calculation Simulator & Test"))
                    .font(.caption.bold())
                    .foregroundColor(Color.green)
                InfoTipButton(
                    title: store.t(nl: "Berekening Simulator", en: "Calculation Simulator"),
                    message: store.t(
                        nl: "Sleep de schuifregelaar om direct te testen hoeveel seconden de bevochtiger volgens de AI moet nevelen voor jouw tentvolume en vochttekort.",
                        en: "Drag the slider to test how many seconds the humidifier will run according to AI for your tent volume and humidity deficit."
                    ),
                    icon: "questionmark.circle.fill",
                    color: Color.green
                )
                Spacer()
                Button(showSimulationCard ? store.t(nl: "Verberg", en: "Hide") : store.t(nl: "Toon", en: "Show")) {
                    withAnimation { showSimulationCard.toggle() }
                }
                .font(.caption2.bold())
                .foregroundColor(MycoTheme.blue)
            }

            if showSimulationCard {
                let testCalc = manager.calculateHumidifierDuration(
                    currentRH: simulationHumidity,
                    targetRH: manager.config.targetHumidityPct
                )
                VStack(alignment: .leading, spacing: 10) {


                    HStack {
                        Text("\(Int(simulationHumidity))% RV")
                            .font(.headline.bold())
                            .foregroundColor(Color.cyan)
                        Slider(value: $simulationHumidity, in: 40...95, step: 1)
                        Text("\(Int(manager.config.targetHumidityPct))% Doel")
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                    }

                    HStack {
                        Text(store.t(nl: "Berekende Looptijd:", en: "Calculated Runtime:"))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Spacer()
                        Text(testCalc.seconds > 0 ? "\(testCalc.seconds) seconden" : store.t(nl: "0s (Reeds op peil)", en: "0s (On target)"))
                            .font(.headline.bold())
                            .foregroundColor(testCalc.seconds > 0 ? Color.cyan : Color.green)
                    }

                    Text(testCalc.explanation)
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)

                    Button {
                        Task {
                            await manager.triggerScanAndReact(simulateRH: simulationHumidity)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text(store.t(nl: "Test Simulatie Cyclus Uitvoeren", en: "Execute Test Simulation Cycle"))
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.3))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MycoTheme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MycoTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - 7. HISTORY CARD
@MainActor
private struct OpticalHistoryCard: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared

    private func formatTimestampShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 24-Uurs Visuele Grafiek
            if manager.readingHistory.count >= 2 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(store.t(nl: "24-Uurs Klimaat Trend", en: "24-Hour Climate Trend"), systemImage: "chart.xyaxis.line")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Spacer()
                        HStack(spacing: 8) {
                            HStack(spacing: 3) {
                                Circle().fill(Color.cyan).frame(width: 6, height: 6)
                                Text("% RV").font(.system(size: 9, weight: .bold)).foregroundColor(MycoTheme.textSecondary)
                            }
                            HStack(spacing: 3) {
                                Circle().fill(Color.orange).frame(width: 6, height: 6)
                                Text("°C").font(.system(size: 9, weight: .bold)).foregroundColor(MycoTheme.textSecondary)
                            }
                            HStack(spacing: 3) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("Doel").font(.system(size: 9, weight: .bold)).foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                    }

                    Chart {
                        let sortedReadings = manager.readingHistory.sorted(by: { $0.timestamp < $1.timestamp })
                        ForEach(sortedReadings) { r in
                            LineMark(
                                x: .value("Tijd", r.timestamp),
                                y: .value("RV %", r.humidityPct)
                            )
                            .foregroundStyle(Color.cyan)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Tijd", r.timestamp),
                                y: .value("RV %", r.humidityPct)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.22), Color.cyan.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            if let temp = r.temperatureC {
                                LineMark(
                                    x: .value("Tijd", r.timestamp),
                                    y: .value("Temp °C", temp)
                                )
                                .foregroundStyle(Color.orange)
                                .interpolationMethod(.catmullRom)
                            }
                        }

                        RuleMark(y: .value("Doel RV", manager.config.targetHumidityPct))
                            .foregroundStyle(Color.green.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 140)
                    .padding(.vertical, 4)
                }
                .padding(14)
                .background(MycoTheme.card)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
            }

            Text(store.t(nl: "Recente Scans", en: "Recent Scans"))
                .font(.caption.bold())
                .foregroundColor(MycoTheme.textSecondary)

            ForEach(manager.readingHistory.prefix(5)) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("\(Int(item.humidityPct))% RV")
                                .font(.subheadline.bold())
                                .foregroundColor(Color.white)
                            if let t = item.temperatureC {
                                Text("\(String(format: "%.1f", t))°C")
                                    .font(.caption)
                                    .foregroundColor(Color.orange)
                            }
                        }
                        Text(formatTimestampShort(item.timestamp))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if item.calculatedHumidifierDurationSec > 0 {
                            Text("\(item.calculatedHumidifierDurationSec)s mist")
                                .font(.caption.bold())
                                .foregroundColor(Color.cyan)
                        } else {
                            Text(store.t(nl: "Op peil", en: "On target"))
                                .font(.caption)
                                .foregroundColor(Color.green)
                        }
                        Text(item.sourceLens)
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MycoTheme.card)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(MycoTheme.border, lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - 8. OPTICAL HYGROMETER SETTINGS SHEET
@MainActor
struct OpticalHygrometerSettingsSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared

    private var availableHumidifiers: [SmartDeviceItem] {
        store.db.smartDevices.filter { $0.deviceType != "Sensor" }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(store.t(nl: "Kritieke Alarmen & Notificaties", en: "Critical Alerts & Notifications"))) {
                    Toggle(store.t(nl: "Alarm Notificaties", en: "Alert Notifications"), isOn: $manager.config.alertsEnabled)

                    if manager.config.alertsEnabled {
                        Stepper(value: $manager.config.minCriticalHumidityThreshold, in: 50...95, step: 1) {
                            HStack {
                                Text(store.t(nl: "Min. RV Alarm:", en: "Min. RH Alarm:"))
                                Spacer()
                                Text("\(Int(manager.config.minCriticalHumidityThreshold))% RV")
                                    .bold()
                                    .foregroundColor(Color.cyan)
                            }
                        }

                        Stepper(value: $manager.config.maxCriticalTempThreshold, in: 22...35, step: 0.5) {
                            HStack {
                                Text(store.t(nl: "Max. Temp Alarm:", en: "Max. Temp Alarm:"))
                                Spacer()
                                Text(String(format: "%.1f°C", manager.config.maxCriticalTempThreshold))
                                    .bold()
                                    .foregroundColor(Color.orange)
                            }
                        }
                    }
                }

                Section(header: Text(store.t(nl: "Automatisering & Schema", en: "Automation & Schedule"))) {
                    Toggle(store.t(nl: "Periodiek Scannen Actief", en: "Periodic Scanning Active"), isOn: Binding(
                        get: { manager.config.isEnabled },
                        set: { manager.togglePeriodicMonitoring(enabled: $0) }
                    ))

                    Picker(store.t(nl: "Scaninterval", en: "Scan Interval"), selection: $manager.config.scanIntervalMinutes) {
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("20 min").tag(20)
                        Text("30 min (Aanbevolen)").tag(30)
                        Text("45 min").tag(45)
                        Text("60 min").tag(60)
                        Text("90 min").tag(90)
                        Text("120 min").tag(120)
                    }

                    Stepper(value: $manager.config.scanIntervalMinutes, in: 5...240) {
                        HStack {
                            Text(store.t(nl: "Aangepast Interval:", en: "Custom Interval:"))
                            Spacer()
                            Text("\(manager.config.scanIntervalMinutes) min")
                                .bold()
                                .foregroundColor(Color.cyan)
                        }
                    }

                    Picker(store.t(nl: "Nevel-Hersteltijd", en: "Mist Settling Window"), selection: $manager.config.fogSettlingDurationMinutes) {
                        Text("10 min").tag(10)
                        Text("15 min (Standaard)").tag(15)
                        Text("20 min").tag(20)
                        Text("30 min").tag(30)
                    }

                    Toggle(isOn: $manager.config.autoScanAfterFAE) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "🍃 Scannen na Verse Lucht (FAE)", en: "🍃 Scan after Fresh Air (FAE)"))
                                .font(.subheadline)
                            Text(store.t(
                                nl: "Scant 60s nadat de afzuiging stopt. Scherm is kraakhelder en meet direct de verse RV.",
                                en: "Scans 60s after exhaust stops. Screen is crystal clear and immediately measures fresh RH."
                            ))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                }

                Section(header: Text(store.t(nl: "Scancamera & Lens", en: "Scan Camera & Lens"))) {
                    Picker(store.t(nl: "Camerabron", en: "Camera Source"), selection: $manager.config.cameraSource) {
                        Text(store.t(nl: "📹 Kweekcamera (Livestream)", en: "📹 Grow Camera (Livestream)")).tag(OpticalHygrometerConfig.CameraSource.remoteStream)
                        Text(store.t(nl: "📱 Dit Toestel (Lokaal)", en: "📱 This Device (Local)")).tag(OpticalHygrometerConfig.CameraSource.localDevice)
                    }
                    .onChange(of: manager.config.cameraSource) {
                        manager.detectTelephotoHardware()
                    }

                    if manager.config.cameraSource == .remoteStream {
                        if !LiveKitStreamManager.shared.remoteAvailableCameras.isEmpty {
                            Picker(store.t(nl: "Meetscan Lens (Telelens)", en: "Measurement Lens (Tele)"), selection: $manager.config.preferredCameraId) {
                                ForEach(LiveKitStreamManager.shared.remoteAvailableCameras, id: \.id) { cam in
                                    let isTele = cam.shortLabel.localizedCaseInsensitiveContains("tele") || cam.name.localizedCaseInsensitiveContains("tele") || cam.name.localizedCaseInsensitiveContains("zoom")
                                    Text("\(cam.name) (\(cam.shortLabel))\(isTele ? " 🎯 Tele" : "")").tag(cam.id)
                                }
                            }
                            .onChange(of: manager.config.preferredCameraId) { _, _ in
                                manager.detectTelephotoHardware()
                            }
                        } else {
                            HStack {
                                Text(store.t(nl: "Actieve Lens", en: "Active Lens"))
                                Spacer()
                                Text(LiveKitStreamManager.shared.remoteActiveCameraLabel.isEmpty ? "Standaard" : LiveKitStreamManager.shared.remoteActiveCameraLabel)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                    } else {
                        Picker(store.t(nl: "Meetscan Lens (Telelens)", en: "Measurement Lens (Tele)"), selection: $manager.config.preferredCameraId) {
                            ForEach(LiveKitStreamManager.shared.availableCameras, id: \.id) { cam in
                                let isTele = cam.deviceType == .builtInTelephotoCamera || cam.shortLabel.localizedCaseInsensitiveContains("tele") || cam.name.localizedCaseInsensitiveContains("tele") || cam.name.localizedCaseInsensitiveContains("zoom")
                                Text("\(cam.name) (\(cam.shortLabel))\(isTele ? " 🎯 Tele" : "")").tag(cam.id)
                            }
                        }
                        .onChange(of: manager.config.preferredCameraId) { _, _ in
                            manager.detectTelephotoHardware()
                        }
                    }

                    HStack {
                        Text(store.t(nl: "Camera Status", en: "Camera Status"))
                        Spacer()
                        Text(manager.activeTelephotoDescription)
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }

                Section(
                    header: Text(store.t(nl: "Verlichting", en: "Lighting")),
                    footer: Text(store.t(
                        nl: "Zorgt dat de kweeklampen automatisch branden tijdens de optische meting zodat het display kraakhelder verlicht is voor de camera en AI. Als de lampen uit stonden, worden ze na de scan direct weer netjes hersteld.",
                        en: "Ensures grow lights automatically turn on during optical measurement so the display is crystal clear for the camera and AI. If lights were off, they are cleanly restored after scanning."
                    ))
                ) {
                    Toggle(store.t(nl: "Flitser Inschakelen (Hoog Contrast)", en: "Use Camera Flash (High Contrast)"), isOn: $manager.config.useFlash)
                    Toggle(store.t(nl: "Kweeklampen Inschakelen Tijdens Meting", en: "Turn On Grow Lights During Measurement"), isOn: $manager.config.useGrowLights)
                        .onChange(of: manager.config.useGrowLights) { _, _ in
                            UserDefaults.standard.set(true, forKey: "mycolab_optical_lights_configured")
                            manager.saveConfig()
                        }
                }

                Section(header: HStack {
                    Text(store.t(nl: "Klimaat & Berekeningsparameters", en: "Climate & Calculation Parameters"))
                    Spacer()
                    InfoTipButton(
                        title: store.t(nl: "Kweekruimte & AI Synchronisatie", en: "Grow Space & AI Sync"),
                        message: store.t(
                            nl: "Het tentvolume en bevochtigervermogen worden automatisch overgenomen uit de Kweekruimte & Luchtstroom AI. Handmatig instellen is niet nodig.",
                            en: "Chamber volume and humidifier output are automatically synchronized with your Grow Space & Airflow AI settings. Manual adjustment is not needed."
                        ),
                        icon: "questionmark.circle.fill",
                        color: MycoTheme.green
                    )
                }) {
                    HStack {
                        Text(store.t(nl: "Doel Luchtvochtigheid", en: "Target Humidity"))
                        Spacer()
                        Text("\(Int(manager.config.targetHumidityPct))% RV")
                            .bold()
                            .foregroundColor(Color.green)
                    }
                    Slider(value: $manager.config.targetHumidityPct, in: 70...98, step: 1)
                        .onChange(of: manager.config.targetHumidityPct) { _, newVal in
                            store.db.environmentConfig.targetHumidityPct = newVal
                            store.save()
                        }

                    Toggle(store.t(nl: "Koppel automatisch aan Kweekruimte AI", en: "Auto-sync with Grow Space AI"), isOn: $manager.config.useGrowSpaceSync)
                        .onChange(of: manager.config.useGrowSpaceSync) { _, enabled in
                            if enabled {
                                manager.syncWithEnvironmentConfig()
                            }
                        }

                    if manager.config.useGrowSpaceSync {
                        let env = store.db.environmentConfig
                        let vol = env.roomVolumeM3 > 0.01 ? env.roomVolumeM3 : manager.config.chamberVolumeM3
                        let hum = env.humidifierOutputMlH > 0 ? env.humidifierOutputMlH : manager.config.humidifierOutputMlH

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Kweekruimte Volume (AI)", en: "Grow Space Volume (AI)"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                Text("\(String(format: "%.2f", vol)) m³ (\(Int(vol * 1000)) L)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(store.t(nl: "Bevochtiger (AI)", en: "Humidifier (AI)"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                Text("\(Int(hum)) ml/u")
                                    .font(.subheadline.bold())
                                    .foregroundColor(Color.cyan)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            Text(store.t(nl: "Kamer/Tent Volume (m³)", en: "Chamber Volume (m³)"))
                            Spacer()
                            Text("\(String(format: "%.2f", manager.config.chamberVolumeM3)) m³ (\(Int(manager.config.chamberVolumeM3 * 1000)) L)")
                                .bold()
                        }
                        Slider(value: $manager.config.chamberVolumeM3, in: 0.05...2.5, step: 0.05)

                        HStack {
                            Text(store.t(nl: "Bevochtiger Vermogen", en: "Humidifier Output"))
                            Spacer()
                            Text("\(Int(manager.config.humidifierOutputMlH)) ml/uur")
                                .bold()
                        }
                        Slider(value: $manager.config.humidifierOutputMlH, in: 100...800, step: 50)
                    }
                }

                Section(header: Text(store.t(nl: "Gekoppelde Luchtbevochtiger", en: "Connected Humidifier"))) {
                    if availableHumidifiers.isEmpty {
                        Text(store.t(nl: "Geen bevochtiger stekker gevonden. Voeg er een toe via het dashboard.", en: "No humidifier plug found. Add one via dashboard."))
                            .font(.caption)
                            .foregroundColor(Color.orange)
                    } else {
                        Picker(store.t(nl: "Selecteer Stekker", en: "Select Plug"), selection: $manager.config.selectedHumidifierDeviceId) {
                            Text(store.t(nl: "Automatisch (Slimme Detectie)", en: "Automatic (Smart Detection)")).tag(UUID?.none)
                            ForEach(availableHumidifiers) { dev in
                                Text("\(dev.name) (\(dev.isOn ? "AAN" : "UIT"))").tag(UUID?.some(dev.id))
                            }
                        }
                        .onChange(of: manager.config.selectedHumidifierDeviceId) { _, newId in
                            if let id = newId, let idx = store.db.smartDevices.firstIndex(where: { $0.id == id }) {
                                store.db.smartDevices[idx].autoControlEnabled = true
                                store.db.smartDevices[idx].autopilotMode = "auto"
                                store.save()
                            }
                        }

                        let activeTargetId = manager.config.selectedHumidifierDeviceId ?? availableHumidifiers.first(where: { $0.deviceType == "Humidifier" })?.id ?? availableHumidifiers.first?.id
                        if let targetId = activeTargetId, let targetDev = store.db.smartDevices.first(where: { $0.id == targetId }) {
                            Button {
                                if targetDev.isOn {
                                    store.setSmartDeviceState(id: targetId, isOn: false, trigger: "Handmatige Test Scanner Instellingen")
                                } else {
                                    store.setSmartDeviceState(id: targetId, isOn: true, trigger: "Handmatige Test Scanner Instellingen")
                                }
                            } label: {
                                HStack {
                                    Image(systemName: targetDev.isOn ? "power.circle.fill" : "power.circle")
                                        .foregroundColor(targetDev.isOn ? .green : .orange)
                                    Text(targetDev.isOn ? "Schakel '\(targetDev.name)' UIT" : "🔌 Test '\(targetDev.name)' AAN")
                                        .font(.subheadline.bold())
                                        .foregroundColor(targetDev.isOn ? .red : .primary)
                                    Spacer()
                                    Text(targetDev.isOn ? "Nu AAN" : "Nu UIT")
                                        .font(.caption)
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(store.t(nl: "Telelens Scanner Instellingen", en: "Telephoto Scanner Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Sluiten", en: "Close")) {
                        dismiss()
                    }
                    .foregroundColor(MycoTheme.blue)
                }
            }
        }
    }
}

// MARK: - 9. OPTICAL METER SETUP & ROI CALIBRATION SHEET
@MainActor
struct OpticalMeterSetupSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = MycoOpticalHygrometerManager.shared

    @State private var snapshotImage: UIImage? = nil
    @State private var isCapturing: Bool = false
    @State private var selectedZone: OpticalZoneType = .temperature
    @State private var photoPickerItem: PhotosPickerItem? = nil

    @State private var meterROI: NormalizedROI = NormalizedROI.defaultMeter
    @State private var tempROI: NormalizedROI = NormalizedROI.defaultTemperature
    @State private var humROI: NormalizedROI = NormalizedROI.defaultHumidity

    @State private var isRunningTest: Bool = false
    @State private var testResultText: String? = nil
    @State private var testTempResult: Double? = nil
    @State private var testHumResult: Double? = nil
    @State private var recognitionDetails: OpticalRecognitionDetails? = nil
    @State private var initialDragROI: NormalizedROI? = nil

    // Interactive Zoom, Pan & AI Display Focus
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var initialPanOffset: CGSize = .zero
    @State private var isZoomPanMode: Bool = false
    @State private var isDetectingDisplay: Bool = false

    init() {
        let cfg = MycoOpticalHygrometerManager.shared.config
        _meterROI = State(initialValue: cfg.meterROI ?? NormalizedROI.defaultMeter)
        _tempROI = State(initialValue: cfg.temperatureROI ?? NormalizedROI.defaultTemperature)
        _humROI = State(initialValue: cfg.humidityROI ?? NormalizedROI.defaultHumidity)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    OpticalCameraSourcePickerCard()
                    captureActionCard
                    interactiveViewfinderCard
                    zoneSelectionAndFineTuneCard
                    presetButtonsRow
                    aiTestSection
                }
                .padding(16)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Meter & Zones Instellen", en: "Setup Meter & Zones"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Annuleren", en: "Cancel")) {
                        dismiss()
                    }
                    .foregroundColor(MycoTheme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        InfoTipButton(
                            title: store.t(nl: "Kalibratie Stappen", en: "Calibration Steps"),
                            message: store.t(
                                nl: """
                                1. Neem een duidelijke foto van uw meterdisplay.
                                2. Sleep het Oranje kader over de temperatuurcijfers.
                                3. Sleep het Blauwe kader over de vochtigheidscijfers.
                                4. Test de AI om te zien of de cijfers meteen juist worden gelezen.
                                """,
                                en: """
                                1. Capture a clear photo of your meter.
                                2. Drag the Orange box over temperature digits.
                                3. Drag the Blue box over humidity digits.
                                4. Test AI to verify digit recognition.
                                """
                            ),
                            icon: "questionmark.circle.fill",
                            color: Color.cyan
                        )
                        Button(store.t(nl: "Opslaan", en: "Save")) {
                            saveAndDismiss()
                        }
                        .font(.headline.bold())
                        .foregroundColor(MycoTheme.blue)
                    }
                }
            }
            .task {
                if manager.config.cameraSource == .remoteStream {
                    if !LiveKitStreamManager.shared.isConnected {
                        await LiveKitStreamManager.shared.autoConnectToActiveCameraAsViewer()
                    }
                    LiveKitStreamManager.shared.requestRemoteCameras()
                }
                if snapshotImage == nil {
                    snapshotImage = manager.lastCapturedPreview
                }
                if snapshotImage == nil {
                    await captureSnapshot()
                }
            }
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.t(nl: "Instructies voor Kalibratie", en: "Calibration Instructions"))
                .font(.caption.bold())
                .foregroundColor(Color.cyan)

            Text(store.t(
                nl: "1. Neem een duidelijke foto van uw meterdisplay.\n2. Sleep het Oranje kader over de temperatuurcijfers.\n3. Sleep het Blauwe kader over de vochtigheidscijfers.\n4. Test de AI om te zien of de cijfers meteen juist worden gelezen.",
                en: "1. Capture a clear photo of your meter.\n2. Drag the Orange box over temperature digits.\n3. Drag the Blue box over humidity digits.\n4. Test the AI to verify readings."
            ))
            .font(.caption2)
            .foregroundColor(Color.white.opacity(0.85))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MycoTheme.card)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
    }

    private var captureActionCard: some View {
        VStack(spacing: 8) {
            if manager.config.cameraSource == .localDevice {
                HStack(spacing: 6) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text(store.t(nl: "Lokale Camera Actief (\(manager.activeTelephotoDescription))", en: "Local Camera Ready (\(manager.activeTelephotoDescription))"))
                        .font(.caption2.bold())
                        .foregroundColor(MycoTheme.blue)
                    Spacer()
                }
                .padding(.horizontal, 4)
            } else {
                // LiveKit Livestream Status Badge
                HStack(spacing: 6) {
                    if LiveKitStreamManager.shared.remoteVideoTrack != nil || LiveKitStreamManager.shared.isConnected {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text(store.t(nl: "Kweekcamera Livestream Verbonden", en: "Grow Camera Livestream Connected"))
                            .font(.caption2.bold())
                            .foregroundColor(Color.green)
                    } else {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text(store.t(nl: "Kweekcamera Livestream Offline", en: "Grow Camera Livestream Offline"))
                            .font(.caption2.bold())
                            .foregroundColor(Color.orange)
                        Spacer()
                        Button {
                            Task {
                                await LiveKitStreamManager.shared.autoConnectToActiveCameraAsViewer(forceFresh: true)
                            }
                        } label: {
                            Text(store.t(nl: "Verbinden", en: "Connect"))
                                .font(.caption2.bold())
                                .foregroundColor(MycoTheme.blue)
                                .underline()
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await captureSnapshot() }
                } label: {
                    HStack(spacing: 6) {
                        if isCapturing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            let capturingText = manager.config.cameraSource == .localDevice ?
                                store.t(nl: "Lokale foto maken...", en: "Taking local photo...") :
                                store.t(nl: "Ophalen van kweekcamera...", en: "Fetching from grow camera...")
                            Text(capturingText)
                                .font(.caption.bold())
                        } else {
                            Image(systemName: "camera.fill")
                            let btnText = manager.config.cameraSource == .localDevice ?
                                store.t(nl: "Foto Nemen met Dit Toestel", en: "Take Photo with This Device") :
                                store.t(nl: "Foto van Kweekcamera Ophalen", en: "Fetch Photo from Grow Camera")
                            Text(btnText)
                                .font(.caption.bold())
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(MycoTheme.blue)
                    .cornerRadius(8)
                }
                .disabled(isCapturing)

                Toggle(store.t(nl: "Flits", en: "Flash"), isOn: $manager.config.useFlash)
                    .font(.caption)
                    .toggleStyle(SwitchToggleStyle(tint: Color.cyan))
                    .fixedSize()
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text(MainActor.assumeIsolated { store.t(nl: "Kies uit Foto's", en: "Choose from Photos") })
                            .font(.caption.bold())
                    }
                    .foregroundColor(Color.cyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                }
                .onChange(of: photoPickerItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                self.snapshotImage = image
                                self.manager.lastCapturedPreview = image
                            }
                        }
                    }
                }

                Button {
                    Task {
                        isCapturing = true
                        if let track = await LiveKitStreamManager.shared.ensureLocalCameraTrackAvailable(),
                           let img = await LiveKitStreamManager.shared.captureCurrentFrame(from: track) {
                            self.snapshotImage = img
                            self.manager.lastCapturedPreview = img
                        }
                        isCapturing = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "iphone.circle")
                        Text(store.t(nl: "Lokale Camera (Handmatig)", en: "Local Camera (Manual)"))
                            .font(.caption.bold())
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }
                .disabled(isCapturing)
            }
        }
    }

    private var interactiveViewfinderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with AI Smart Focus Button
            HStack {
                Text(store.t(nl: "Interactieve Richtzoeker", en: "Interactive Viewfinder"))
                    .font(.caption.bold())
                    .foregroundColor(MycoTheme.textSecondary)
                Spacer()
                if snapshotImage != nil {
                    Button {
                        if let current = snapshotImage {
                            let rotated = MycoOpticalHygrometerManager.rotateImage90Degrees(current)
                            self.snapshotImage = rotated
                            self.manager.lastCapturedPreview = rotated
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rotate.right.fill")
                            Text(store.t(nl: "Draai 90°", en: "Rotate 90°"))
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                    }
                }
                
                Button {
                    triggerSmartDisplayFocus()
                } label: {
                    HStack(spacing: 5) {
                        if isDetectingDisplay {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(store.t(nl: "AI Zoek Scherm", en: "AI Find Display"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(LinearGradient(colors: [Color.yellow, Color.cyan], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(6)
                }
                .disabled(isDetectingDisplay || snapshotImage == nil)
            }

            // Mode & Zoom Toolbar
            HStack(spacing: 8) {
                // Mode Toggle: Zones vs Zoom/Pan
                HStack(spacing: 0) {
                    Button {
                        isZoomPanMode = false
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.point.up.left.fill")
                            Text(store.t(nl: "Zones", en: "Zones"))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(!isZoomPanMode ? selectedZone.color.opacity(0.3) : Color.clear)
                        .foregroundColor(!isZoomPanMode ? .white : MycoTheme.textSecondary)
                    }

                    Button {
                        isZoomPanMode = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right.magnifyingglass")
                            Text(store.t(nl: "Zoom / Pan", en: "Zoom / Pan"))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(isZoomPanMode ? Color.cyan.opacity(0.3) : Color.clear)
                        .foregroundColor(isZoomPanMode ? .white : MycoTheme.textSecondary)
                    }
                }
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))

                Spacer()

                // Zoom Level Controls
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            let newScale = max(1.0, zoomScale - 0.5)
                            zoomScale = newScale
                            lastZoomScale = newScale
                            if newScale == 1.0 {
                                panOffset = .zero
                                initialPanOffset = .zero
                            }
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                    }

                    Text(String(format: "%.1fx", zoomScale))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(zoomScale > 1.05 ? Color.cyan : .white)
                        .frame(minWidth: 38)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            let newScale = min(5.0, zoomScale + 0.5)
                            zoomScale = newScale
                            lastZoomScale = newScale
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                    }

                    if zoomScale > 1.05 || panOffset != .zero {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                zoomScale = 1.0
                                lastZoomScale = 1.0
                                panOffset = .zero
                                initialPanOffset = .zero
                            }
                        } label: {
                            Text(store.t(nl: "Reset", en: "Reset"))
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .frame(height: 24)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
                }
                .foregroundColor(.white)
            }

            // Quick Zoom Presets
            HStack(spacing: 6) {
                ForEach([1.0, 2.0, 3.0, 4.0], id: \.self) { level in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            zoomScale = level
                            lastZoomScale = level
                            if level == 1.0 {
                                panOffset = .zero
                                initialPanOffset = .zero
                            }
                        }
                    } label: {
                        Text(String(format: "%.0fx", level))
                            .font(.system(size: 10, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(abs(zoomScale - level) < 0.2 ? Color.cyan.opacity(0.3) : Color.white.opacity(0.05))
                            .foregroundColor(abs(zoomScale - level) < 0.2 ? Color.cyan : MycoTheme.textSecondary)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(abs(zoomScale - level) < 0.2 ? Color.cyan : Color.clear, lineWidth: 1)
                            )
                    }
                }
            }

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                let fitRect: CGRect = {
                    if let img = snapshotImage, img.size.width > 0, img.size.height > 0 {
                        let imgAspect = img.size.width / img.size.height
                        let containerAspect = w / h
                        if imgAspect > containerAspect {
                            let rw = w
                            let rh = rw / imgAspect
                            let ry = (h - rh) / 2
                            return CGRect(x: 0, y: ry, width: rw, height: rh)
                        } else {
                            let rh = h
                            let rw = rh * imgAspect
                            let rx = (w - rw) / 2
                            return CGRect(x: rx, y: 0, width: rw, height: rh)
                        }
                    } else {
                        return CGRect(x: 0, y: 0, width: w, height: h)
                    }
                }()

                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.85)

                    if let img = snapshotImage {
                        ZStack(alignment: .topLeading) {
                            Image(uiImage: img)
                                .resizable()
                                .frame(width: fitRect.width, height: fitRect.height)

                            OpticalROIBoundingBoxOverlay(
                                meterROI: meterROI,
                                temperatureROI: tempROI,
                                humidityROI: humROI,
                                selectedZone: selectedZone,
                                showLabels: true
                            )
                            .frame(width: fitRect.width, height: fitRect.height)
                        }
                        .frame(width: fitRect.width, height: fitRect.height)
                        .scaleEffect(zoomScale)
                        .offset(panOffset)
                        .position(x: fitRect.midX, y: fitRect.midY)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if isZoomPanMode {
                                        panOffset = CGSize(
                                            width: initialPanOffset.width + value.translation.width,
                                            height: initialPanOffset.height + value.translation.height
                                        )
                                    } else {
                                        handleDrag(translation: value.translation, in: fitRect.size)
                                    }
                                }
                                .onEnded { value in
                                    if isZoomPanMode {
                                        initialPanOffset = panOffset
                                    } else {
                                        if abs(value.translation.width) < 5 && abs(value.translation.height) < 5 && fitRect.width > 0 && fitRect.height > 0 {
                                            // Tik op de foto: stel het autofocuspunt in op deze plek
                                            let normX = max(0.05, min(0.95, value.location.x / fitRect.width))
                                            let normY = max(0.05, min(0.95, value.location.y / fitRect.height))
                                            let pt = CGPoint(x: normX, y: normY)
                                            manager.config.customFocusPoint = pt
                                            manager.saveConfig()
                                            Task {
                                                await manager.triggerAutofocusOnMeter(at: pt)
                                            }
                                        }
                                        initialDragROI = nil
                                    }
                                }
                        )
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { scale in
                                    let newScale = lastZoomScale * scale
                                    zoomScale = min(5.0, max(1.0, newScale))
                                }
                                .onEnded { _ in
                                    lastZoomScale = zoomScale
                                }
                        )
                    } else {
                        ZStack {
                            Color.black.opacity(0.6)
                            VStack(spacing: 10) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 44))
                                    .foregroundColor(Color.cyan.opacity(0.8))
                                Text(store.t(nl: "Nog geen foto geladen", en: "No photo loaded yet"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.t(nl: "Druk hierboven op 'Foto Nemen', kies de 'Lokale Camera' of laad een afbeelding via 'Kies uit Foto's'.", en: "Tap 'Take Photo' above, use 'Local Camera' or load an image from 'Choose from Photos'."))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                        }
                        .frame(width: w, height: h)
                    }
                }
                .frame(width: w, height: h)
                .clipped()
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(MycoTheme.border, lineWidth: 1)
                )
            }
            .frame(height: 310)

            // Status footnote
            HStack {
                if isZoomPanMode {
                    Text(store.t(nl: "🔍 Versleep met één vinger om door de foto te bewegen. Knijp om te zoomen.", en: "🔍 Drag with one finger to pan. Pinch to zoom."))
                        .font(.system(size: 10))
                        .foregroundColor(Color.cyan)
                } else {
                    Text(store.t(nl: "🎯 Sleep in het beeld om de geselecteerde zone (\(selectedZone == .meter ? "Display" : (selectedZone == .temperature ? "Temp" : "RV"))) te verplaatsen.", en: "🎯 Drag inside image to move active zone (\(selectedZone == .meter ? "Display" : (selectedZone == .temperature ? "Temp" : "RV")))."))
                        .font(.system(size: 10))
                        .foregroundColor(selectedZone.color)
                }
                Spacer()
            }
        }
        .padding(12)
        .background(MycoTheme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MycoTheme.border, lineWidth: 1)
        )
    }

    private var zoneSelectionAndFineTuneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.t(nl: "Selecteer Zone om aan te passen:", en: "Select Zone to adjust:"))
                .font(.caption.bold())
                .foregroundColor(MycoTheme.textSecondary)

            HStack(spacing: 8) {
                ForEach(OpticalZoneType.allCases) { zone in
                    Button {
                        selectedZone = zone
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(zone.color)
                                .frame(width: 8, height: 8)
                            Text(zone == .temperature ? "Temp" : (zone == .humidity ? "RV %" : "Scherm"))
                                .font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedZone == zone ? zone.color.opacity(0.25) : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedZone == zone ? zone.color : Color.clear, lineWidth: 1.5)
                        )
                        .foregroundColor(selectedZone == zone ? .white : MycoTheme.textSecondary)
                        .cornerRadius(8)
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))

            let activeROI = bindingForSelectedZone()

            VStack(spacing: 8) {
                HStack {
                    Text(store.t(nl: "Horizontaal (X):", en: "Horizontal (X):"))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    Slider(value: activeROI.x, in: 0.0...0.90)
                }
                HStack {
                    Text(store.t(nl: "Verticaal (Y):", en: "Vertical (Y):"))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    Slider(value: activeROI.y, in: 0.0...0.90)
                }
                HStack {
                    Text(store.t(nl: "Breedte:", en: "Width:"))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    Slider(value: activeROI.width, in: 0.05...0.95)
                }
                HStack {
                    Text(store.t(nl: "Hoogte:", en: "Height:"))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    Slider(value: activeROI.height, in: 0.05...0.95)
                }
            }

            // Fijnafstemming Nudge Knoppen
            HStack(spacing: 6) {
                Text(store.t(nl: "Fijnafstemming:", en: "Fine Nudge:"))
                    .font(.caption2.bold())
                    .foregroundColor(MycoTheme.textSecondary)
                Spacer()

                HStack(spacing: 3) {
                    Button(action: { nudgeActiveZone(dx: -0.01, dy: 0) }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 28, height: 26)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(5)
                    }
                    Button(action: { nudgeActiveZone(dx: 0.01, dy: 0) }) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 28, height: 26)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(5)
                    }
                    Button(action: { nudgeActiveZone(dx: 0, dy: -0.01) }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 28, height: 26)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(5)
                    }
                    Button(action: { nudgeActiveZone(dx: 0, dy: 0.01) }) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 28, height: 26)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(5)
                    }
                }
                .foregroundColor(.white)

                HStack(spacing: 3) {
                    Button(action: { scaleActiveZone(dw: -0.01, dh: -0.01) }) {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(5)
                    }
                    Button(action: { scaleActiveZone(dw: 0.01, dh: 0.01) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(5)
                    }
                }
                .foregroundColor(selectedZone.color)
            }
        }
        .padding(14)
        .background(MycoTheme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MycoTheme.border, lineWidth: 1)
        )
    }

    private var presetButtonsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.t(nl: "Snelle Layout Voorinstellingen:", en: "Quick Layout Presets:"))
                .font(.caption2)
                .foregroundColor(MycoTheme.textSecondary)

            HStack(spacing: 8) {
                Button {
                    // Boven Temp / Onder Vocht
                    meterROI = NormalizedROI(x: 0.15, y: 0.15, width: 0.70, height: 0.70)
                    tempROI = NormalizedROI(x: 0.20, y: 0.20, width: 0.60, height: 0.28)
                    humROI = NormalizedROI(x: 0.20, y: 0.52, width: 0.60, height: 0.28)
                } label: {
                    Text("Boven / Onder")
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }

                Button {
                    // Links Temp / Rechts Vocht
                    meterROI = NormalizedROI(x: 0.15, y: 0.20, width: 0.70, height: 0.60)
                    tempROI = NormalizedROI(x: 0.18, y: 0.25, width: 0.30, height: 0.50)
                    humROI = NormalizedROI(x: 0.52, y: 0.25, width: 0.30, height: 0.50)
                } label: {
                    Text("Naast Elkaar")
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }

                Button {
                    meterROI = NormalizedROI.defaultMeter
                    tempROI = NormalizedROI.defaultTemperature
                    humROI = NormalizedROI.defaultHumidity
                } label: {
                    Text("Herstel")
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(Color.orange)
                        .cornerRadius(6)
                }
            }
        }
    }

    private var aiTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Task { await runAITest() }
            } label: {
                HStack(spacing: 8) {
                    if isRunningTest {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isRunningTest ? store.t(nl: "AI Test Bezig...", en: "Testing AI...") : store.t(nl: "⚡ Test AI Herkenning Nu", en: "⚡ Test AI Recognition Now"))
                        .font(.subheadline.bold())
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.green)
                .cornerRadius(10)
            }
            .disabled(isRunningTest || snapshotImage == nil)

            if let details = recognitionDetails {
                VStack(spacing: 10) {
                    // Header Status Banner
                    HStack(spacing: 12) {
                        Image(systemName: details.isSuccess ? "checkmark.circle.fill" : (details.temperature != nil || details.humidity != nil ? "exclamationmark.circle.fill" : "xmark.circle.fill"))
                            .font(.title2)
                            .foregroundColor(details.isSuccess ? Color.green : (details.temperature != nil || details.humidity != nil ? Color.orange : Color.red))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(details.isSuccess ? store.t(nl: "Succesvol Herkend!", en: "Successfully Recognized!") : store.t(nl: "Gedeeltelijke / Geen Herkenning", en: "Partial / No Recognition"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                if let temp = details.temperature {
                                    HStack(spacing: 4) {
                                        Image(systemName: "thermometer.medium").foregroundColor(.orange)
                                        Text(String(format: "%.1f°C", temp))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                } else {
                                    Text("Geen Temp").font(.caption2).foregroundColor(.orange)
                                }

                                if let hum = details.humidity {
                                    HStack(spacing: 4) {
                                        Image(systemName: "drop.fill").foregroundColor(.cyan)
                                        Text("\(Int(hum))% RV")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                } else {
                                    Text("Geen RV%").font(.caption2).foregroundColor(.orange)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background((details.isSuccess ? Color.green : Color.orange).opacity(0.15))
                    .cornerRadius(8)

                    // AI Display Super-Resolution Zoom Preview
                    if let mCrop = details.meterCropImage {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text(store.t(nl: "AI Display Focus (2.5x Super-Resolutie)", en: "AI Display Focus (2.5x Super-Resolution)"))
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow)
                                Spacer()
                                Text(store.t(nl: "LCD Vergroot", en: "LCD Magnified"))
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.yellow)
                                    .cornerRadius(4)
                            }

                            Image(uiImage: mCrop)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 110)
                                .frame(maxWidth: .infinity)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.yellow.opacity(0.6), lineWidth: 1))
                        }
                        .padding(8)
                        .background(Color.yellow.opacity(0.06))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.25), lineWidth: 1))
                    }

                    // Live Zone Crop Previews: toont wat de AI exact ziet
                    HStack(spacing: 8) {
                        // Oranje Zone (Temp)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Oranje (Temp)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.orange)
                                Spacer()
                                if details.temperature != nil {
                                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.green)
                                }
                            }

                            if let crop = details.tempCropImage {
                                Image(uiImage: crop)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 50)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(6)
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 50)
                            }

                            Text(details.tempCandidatesText.isEmpty ? "Geen tekst" : details.tempCandidatesText)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(details.temperature != nil ? .green : .gray)
                                .lineLimit(1)
                        }
                        .padding(6)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4), lineWidth: 1))

                        // Blauwe Zone (RV)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Blauw (RV%)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.cyan)
                                Spacer()
                                if details.humidity != nil {
                                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.green)
                                }
                            }

                            if let crop = details.humCropImage {
                                Image(uiImage: crop)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 50)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(6)
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 50)
                            }

                            Text(details.humCandidatesText.isEmpty ? "Geen tekst" : details.humCandidatesText)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(details.humidity != nil ? .cyan : .gray)
                                .lineLimit(1)
                        }
                        .padding(6)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                    }

                    if !details.isSuccess {
                        Text("💡 Tip: Maak het kader iets ruimer rondom de cijfers met de pijltjestoetsen of de [+] knop als de cijfers aan de rand afgekapt worden.")
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }
            } else if let raw = testResultText {
                Text(raw)
                    .font(.caption2)
                    .foregroundColor(Color.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(MycoTheme.card)
        .cornerRadius(12)
    }

    private func bindingForSelectedZone() -> (x: Binding<Double>, y: Binding<Double>, width: Binding<Double>, height: Binding<Double>) {
        switch selectedZone {
        case .temperature:
            return (
                Binding(get: { tempROI.x }, set: { tempROI.x = $0 }),
                Binding(get: { tempROI.y }, set: { tempROI.y = $0 }),
                Binding(get: { tempROI.width }, set: { tempROI.width = $0 }),
                Binding(get: { tempROI.height }, set: { tempROI.height = $0 })
            )
        case .humidity:
            return (
                Binding(get: { humROI.x }, set: { humROI.x = $0 }),
                Binding(get: { humROI.y }, set: { humROI.y = $0 }),
                Binding(get: { humROI.width }, set: { humROI.width = $0 }),
                Binding(get: { humROI.height }, set: { humROI.height = $0 })
            )
        case .meter:
            return (
                Binding(get: { meterROI.x }, set: { meterROI.x = $0 }),
                Binding(get: { meterROI.y }, set: { meterROI.y = $0 }),
                Binding(get: { meterROI.width }, set: { meterROI.width = $0 }),
                Binding(get: { meterROI.height }, set: { meterROI.height = $0 })
            )
        }
    }

    private func nudgeActiveZone(dx: Double, dy: Double) {
        switch selectedZone {
        case .temperature:
            tempROI.x = max(0.0, min(1.0 - tempROI.width, tempROI.x + dx))
            tempROI.y = max(0.0, min(1.0 - tempROI.height, tempROI.y + dy))
        case .humidity:
            humROI.x = max(0.0, min(1.0 - humROI.width, humROI.x + dx))
            humROI.y = max(0.0, min(1.0 - humROI.height, humROI.y + dy))
        case .meter:
            meterROI.x = max(0.0, min(1.0 - meterROI.width, meterROI.x + dx))
            meterROI.y = max(0.0, min(1.0 - meterROI.height, meterROI.y + dy))
        }
    }

    private func scaleActiveZone(dw: Double, dh: Double) {
        switch selectedZone {
        case .temperature:
            tempROI.width = max(0.05, min(1.0 - tempROI.x, tempROI.width + dw))
            tempROI.height = max(0.05, min(1.0 - tempROI.y, tempROI.height + dh))
        case .humidity:
            humROI.width = max(0.05, min(1.0 - humROI.x, humROI.width + dw))
            humROI.height = max(0.05, min(1.0 - humROI.y, humROI.height + dh))
        case .meter:
            meterROI.width = max(0.05, min(1.0 - meterROI.x, meterROI.width + dw))
            meterROI.height = max(0.05, min(1.0 - meterROI.y, meterROI.height + dh))
        }
    }

    private func handleDrag(translation: CGSize, in size: CGSize) {
        guard size.width > 20, size.height > 20 else { return }
        if initialDragROI == nil {
            switch selectedZone {
            case .temperature: initialDragROI = tempROI
            case .humidity: initialDragROI = humROI
            case .meter: initialDragROI = meterROI
            }
        }
        guard let base = initialDragROI else { return }

        let effectiveZoom = max(1.0, zoomScale)
        let dx = Double(translation.width / (size.width * effectiveZoom))
        let dy = Double(translation.height / (size.height * effectiveZoom))

        let newX = max(0.0, min(1.0 - base.width, base.x + dx))
        let newY = max(0.0, min(1.0 - base.height, base.y + dy))

        switch selectedZone {
        case .temperature:
            tempROI.x = newX
            tempROI.y = newY
        case .humidity:
            humROI.x = newX
            humROI.y = newY
        case .meter:
            meterROI.x = newX
            meterROI.y = newY
        }
    }

    private func triggerSmartDisplayFocus() {
        guard let img = snapshotImage else { return }
        isDetectingDisplay = true
        Task {
            if let detected = await MycoOpticalHygrometerManager.autoDetectDisplayROI(in: img) {
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        meterROI = detected
                        selectedZone = .meter
                        tempROI = NormalizedROI(
                            x: detected.x + (detected.width * 0.06),
                            y: detected.y + (detected.height * 0.08),
                            width: detected.width * 0.88,
                            height: detected.height * 0.40
                        )
                        humROI = NormalizedROI(
                            x: detected.x + (detected.width * 0.06),
                            y: detected.y + (detected.height * 0.52),
                            width: detected.width * 0.88,
                            height: detected.height * 0.40
                        )
                        zoomScale = 2.4
                        lastZoomScale = 2.4
                        let normCenterX = (detected.x + (detected.width / 2.0)) - 0.5
                        let normCenterY = (detected.y + (detected.height / 2.0)) - 0.5
                        panOffset = CGSize(
                            width: -normCenterX * 280.0 * 2.4,
                            height: -normCenterY * 220.0 * 2.4
                        )
                        initialPanOffset = panOffset
                    }
                    isDetectingDisplay = false
                    MycoSyncManager.shared.triggerToast(message: "✨ AI Display Focus: LCD-scherm gedetecteerd en vergroot!")
                }
            } else {
                await MainActor.run {
                    isDetectingDisplay = false
                    withAnimation {
                        zoomScale = 2.0
                        lastZoomScale = 2.0
                    }
                    MycoSyncManager.shared.triggerToast(message: "ℹ️ Geen LCD scherm herkend. Zoom handmatig in op de meter.")
                }
            }
        }
    }

    private func captureSnapshot() async {
        isCapturing = true
        let img = await manager.captureCalibrationSnapshot()
        if let img = img {
            snapshotImage = img
            manager.lastCapturedPreview = img
        }
        isCapturing = false
    }

    private func runAITest() async {
        guard let img = snapshotImage else { return }
        isRunningTest = true
        testResultText = nil
        testTempResult = nil
        testHumResult = nil

        var draftConfig = manager.config
        draftConfig.meterROI = meterROI
        draftConfig.temperatureROI = tempROI
        draftConfig.humidityROI = humROI

        let details = await manager.recognizeMeterTextDetailed(image: img, config: draftConfig)
        recognitionDetails = details
        testTempResult = details.temperature
        testHumResult = details.humidity
        if details.humidity == nil && details.temperature == nil {
            testResultText = "Nog geen cijfers herkend. (Gelezen tekst: \"\(details.rawText.isEmpty ? "Geen tekst gevonden" : details.rawText)\")"
        } else {
            testResultText = "Herkend: \(details.rawText)"
        }
        isRunningTest = false
    }

    private func saveAndDismiss() {
        manager.config.meterROI = meterROI
        manager.config.temperatureROI = tempROI
        manager.config.humidityROI = humROI
        manager.config.isConfigured = true
        dismiss()
    }
}
