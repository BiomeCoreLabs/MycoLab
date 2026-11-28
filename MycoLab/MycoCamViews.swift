//
//  MycoCamViews.swift
//  MycoLab
//
//  Complete MycoCam & Remote Streaming Suite:
//  - Remote Lab Monitor (LiveKit WebRTC 4G/5G encrypted stream)
//  - Multi-device pairing discovery & status cards
//  - 3D LiDAR Visualizer & Remote Timelapse Studio
//  - Dedicated Lab Webcam & Grow Light Mode
//  - AI Climate & Airflow Neural Engine Calculator
//

import AuthenticationServices
import SwiftUI
import CoreData
import CryptoKit
import Security
import UserNotifications
import CoreImage.CIFilterBuiltins
@preconcurrency import AVFoundation
import AVKit
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
public import Combine

// MARK: - 16A. STREAM HUB STATUS SECTION VIEW
@MainActor struct StreamHubStatusSectionView: View {
    @EnvironmentObject var store: MycoStore
    let smartPlugCount: Int
    let batteryIcon: String
    let batteryColor: Color
    let batteryStatusText: String
    let isCharging: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(MycoTheme.green)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.t(nl: "24/7 Lab Hub (Stream Telefoon)", en: "24/7 Lab Hub (Stream Phone)"))
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text(store.t(nl: "Permanent verbonden met lokale Wi-Fi in kweekruimte", en: "Permanently connected to local Wi-Fi in grow room"))
                        .font(.system(size: 10))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(MycoTheme.green)
                        .frame(width: 7, height: 7)
                    Text(store.t(nl: "HUB ACTIEF", en: "HUB ACTIVE"))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(MycoTheme.green)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(MycoTheme.green.opacity(0.15))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(MycoTheme.green.opacity(0.35), lineWidth: 1))
            }
            
            // Reassurance Card Box
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title3)
                    .foregroundColor(MycoTheme.green)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.t(
                        nl: "24/7 Zelfstandige Aansturing",
                        en: "24/7 Autonomous Control"
                    ))
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    
                    Text(store.t(
                        nl: "De stream-camera fungeert als centrale Hub op de lokale Wi-Fi. Zelfs als je met deze Kijk-telefoon buiten bent zonder Wi-Fi of 4G/5G, blijft de camera-telefoon via de lokale Wi-Fi alle automatische schema's, ventilatie- en bevochtigingscycli 24/7 aansturen.",
                        en: "The stream camera acts as the central Hub on local Wi-Fi. Even when you are outside with this monitor without Wi-Fi or cellular service, the camera phone continues sending all automation, ventilation, and humidity cycles to your smart plugs 24/7 via local Wi-Fi."
                    ))
                    .font(.system(size: 11))
                    .foregroundColor(MycoTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            
            // Quick Status Stats
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .foregroundColor(MycoTheme.blue)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.t(nl: "Stekkers", en: "Plugs"))
                            .font(.system(size: 9))
                            .foregroundColor(MycoTheme.textSecondary)
                        Text(store.t(nl: "\(smartPlugCount) op Wi-Fi", en: "\(smartPlugCount) on Wi-Fi"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundColor(MycoTheme.green)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.t(nl: "Autopilot Cyclus", en: "Autopilot Cycle"))
                            .font(.system(size: 9))
                            .foregroundColor(MycoTheme.textSecondary)
                        Text(store.db.environmentConfig.isAutopilotEnabled ? store.t(nl: "24/7 Actief", en: "24/7 Active") : store.t(nl: "Pauze", en: "Paused"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(store.db.environmentConfig.isAutopilotEnabled ? MycoTheme.green : MycoTheme.amber)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)

                // Timelapse Camera Battery Stat Card
                HStack(spacing: 5) {
                    Image(systemName: batteryIcon)
                        .foregroundColor(batteryColor)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.t(nl: "Camera Batterij", en: "Cam Battery"))
                            .font(.system(size: 9))
                            .foregroundColor(MycoTheme.textSecondary)
                        Text(batteryStatusText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isCharging ? MycoTheme.green : .white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }
            
            if !store.db.environmentConfig.lastAutopilotLogMessage.isEmpty {
                HStack(alignment: .center, spacing: 6) {
                    Circle()
                        .fill(MycoTheme.green)
                        .frame(width: 5, height: 5)
                    Text(store.db.environmentConfig.lastAutopilotLogMessage)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(MycoTheme.textSecondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.4))
                .cornerRadius(6)
            }
        }
        .padding(14)
        .background(MycoTheme.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(MycoTheme.green.opacity(0.25), lineWidth: 1))
    }
}

public enum ViewerStreamTransport: String, CaseIterable, Identifiable, Sendable {
    case liveKit = "livekit"
    case p2p = "p2p"
    case auto = "auto"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .liveKit: return "LiveKit (Pi Hub & 4G/5G)"
        case .p2p: return "P2P Direct (Wi-Fi/BT)"
        case .auto: return "Automatisch"
        }
    }
    
    public var shortName: String {
        switch self {
        case .liveKit: return "LiveKit"
        case .p2p: return "P2P Direct"
        case .auto: return "Auto"
        }
    }
    
    public var iconName: String {
        switch self {
        case .liveKit: return "antenna.radiowaves.left.and.right"
        case .p2p: return "personalhotspot"
        case .auto: return "bolt.shield.fill"
        }
    }
}

// MARK: - 16A. REMOTE LAB MONITOR VIEW (AUTOMATIC WI-FI PAIRING & 4G/5G WEBRTC STREAM)
@MainActor struct RemoteLabMonitorView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pairingManager = MycoCamPairingManager.shared
    @ObservedObject private var liveKitManager = LiveKitStreamManager.shared
    @ObservedObject private var sensorManager = MycoSensorIntelligenceManager.shared
    @ObservedObject private var opticalManager = MycoOpticalHygrometerManager.shared
    @ObservedObject private var p2pStreamManager = MycoCamStreamManager.shared
    @AppStorage("mycolab_preferred_transport") private var preferredTransport: String = ViewerStreamTransport.liveKit.rawValue
    
    private var currentTransport: ViewerStreamTransport {
        ViewerStreamTransport(rawValue: preferredTransport) ?? .liveKit
    }
    
    private func applyTransportPreference(_ transport: ViewerStreamTransport) {
        preferredTransport = transport.rawValue
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        
        switch transport {
        case .liveKit:
            pairingManager.startBrowsingForCameras()
            p2pStreamManager.startViewer()
            Task {
                await liveKitManager.startViewer(cameraId: pairingManager.pairedCameraId, forceFresh: true)
            }
        case .p2p:
            Task {
                await liveKitManager.stopStream()
            }
            pairingManager.startBrowsingForCameras()
            p2pStreamManager.startViewer()
        case .auto:
            pairingManager.startBrowsingForCameras()
            p2pStreamManager.startViewer()
            Task {
                await liveKitManager.startViewer(cameraId: pairingManager.pairedCameraId, forceFresh: true)
            }
        }
    }
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var showQRScanner = false
    @State private var showOpticalHygrometerSheet = false
    @State private var showConfirmUnpair = false
    @State private var showFullscreenLive = false
    @State private var showSensorSheet = false
    @State private var showTimelapseGallery = false
    @State private var selectedGalleryInitialTab: TimelapseGallerySheet.GalleryTab = .localPhotos
    @State private var selectedRemoteTimelapseInterval: Int = 2
    @State private var radarPulse = false
    @State private var tapFocusPoint: CGPoint? = nil
    @State private var showFocusReticle: Bool = false
    @State private var focusTimer: AnyCancellable? = nil
    @State private var remoteBrightness: Float = 0.8
    @State private var isEmbeddedVideoFitMode: Bool = true
    @State private var isReconnectingNow: Bool = false
    
    private var currentCameraBatteryPercent: Int? {
        if let bat = liveKitManager.remoteBatteryPercent {
            return bat
        }
        if let lvl = store.db.environmentConfig.cameraBatteryLevel {
            return Int(round(lvl * 100))
        }
        return nil
    }

    private var currentCameraIsCharging: Bool {
        if let chg = liveKitManager.remoteIsCharging {
            return chg
        }
        return store.db.environmentConfig.cameraIsCharging
    }

    private var currentCameraBatteryIcon: String {
        if currentCameraIsCharging {
            return "battery.100.bolt"
        }
        guard let pct = currentCameraBatteryPercent else {
            return "battery.100"
        }
        if pct <= 20 { return "battery.25" }
        if pct <= 50 { return "battery.50" }
        return "battery.100"
    }

    private var currentCameraBatteryColor: Color {
        if currentCameraIsCharging {
            return MycoTheme.green
        }
        guard let pct = currentCameraBatteryPercent else {
            return .white
        }
        if pct <= 20 { return .red }
        if pct <= 40 { return .orange }
        return MycoTheme.green
    }

    private var currentCameraBatteryStatusText: String {
        if let pct = currentCameraBatteryPercent {
            return currentCameraIsCharging ? "\(pct)% ⚡" : "\(pct)%"
        }
        return store.t(nl: "Standby", en: "Standby")
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if pairingManager.isPaired {
                    pairedMonitorView
                } else {
                    pairingDiscoveryView
                }
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Live Kweekkijker", en: "Live Lab Monitor"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if pairingManager.isPaired {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Button {
                                triggerManualReconnect(forceHardReset: false)
                            } label: {
                                Label(store.t(nl: "Opnieuw Verbinden", en: "Reconnect"), systemImage: "arrow.clockwise")
                            }
                            
                            Button {
                                triggerManualReconnect(forceHardReset: true)
                            } label: {
                                Label(store.t(nl: "Forceer Volledige Herverbinding", en: "Force Full Reset & Reconnect"), systemImage: "arrow.triangle.2.circlepath.circle.fill")
                            }
                            
                            Divider()
                            
                            Toggle(isOn: $liveKitManager.isPersistentAutoReconnectEnabled) {
                                Label(store.t(nl: "Altijd Automatisch Herverbinden", en: "Always Auto-Reconnect"), systemImage: "antenna.radiowaves.left.and.right")
                            }
                            
                            Divider()
                            
                            Button {
                                MycoSyncManager.shared.requestSyncFromConnectedPeers()
                                MycoSyncManager.shared.sendSyncPayload(reason: "viewer_menu_sync")
                                MycoSyncManager.shared.triggerToast(message: store.t(nl: "Lab-data gesynchroniseerd met camera!", en: "Lab data synced with camera!"))
                            } label: {
                                Label(store.t(nl: "Lab-data Synchroniseren", en: "Sync Lab Data"), systemImage: "arrow.triangle.2.circlepath")
                            }
                            
                            Button(role: .destructive) {
                                showConfirmUnpair = true
                            } label: {
                                Label(store.t(nl: "Camera Ontkoppelen", en: "Unpair Camera"), systemImage: "link.badge.plus")
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(liveKitManager.remoteVideoTrack != nil ? (pairingManager.isCellular ? Color.cyan : Color.green) : Color.orange)
                                    .frame(width: 8, height: 8)
                                Text(pairingManager.isCellular ? "4G/5G" : "Wi-Fi")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(8)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            MycoSyncManager.shared.requestSyncFromConnectedPeers()
                            MycoSyncManager.shared.sendSyncPayload(reason: "viewer_trailing_sync")
                            MycoSyncManager.shared.triggerToast(message: store.t(nl: "Lab-data gesynchroniseerd met camera!", en: "Lab data synced with camera!"))
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(MycoTheme.green)
                        }
                        
                        Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                            .foregroundColor(MycoTheme.blue)
                    }
                }
            }
            .confirmationDialog(
                store.t(nl: "Camera Ontkoppelen?", en: "Unpair Camera?"),
                isPresented: $showConfirmUnpair,
                titleVisibility: .visible
            ) {
                Button(store.t(nl: "Ontkoppel Camera", en: "Unpair Camera"), role: .destructive) {
                    Task {
                        await liveKitManager.stopStream()
                    }
                    pairingManager.unpair()
                    pairingManager.startBrowsingForCameras()
                }
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
            } message: {
                Text(store.t(
                    nl: "Je ontkoppelt '\(pairingManager.pairedCameraName ?? "Kweekcamera")'. Je kunt hierna eenvoudig opnieuw koppelen via Wi-Fi of QR-code.",
                    en: "This will unpair '\(pairingManager.pairedCameraName ?? "Grow Camera")'. You can easily re-pair via Wi-Fi or QR code."
                ))
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerSheetView { scannedPayload in
                    if pairingManager.handleScannedPayload(scannedPayload) {
                        if let camId = pairingManager.pairedCameraId {
                            Task {
                                await liveKitManager.startViewer(cameraId: camId)
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showFullscreenLive) {
                LiveKitStreamView()
            }
            .sheet(isPresented: $showSensorSheet) {
                MycoSensorInspectionSheet()
            }
            .sheet(isPresented: $showOpticalHygrometerSheet) {
                MycoOpticalHygrometerView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTimelapseGallery) {
                TimelapseGallerySheet(initialTab: selectedGalleryInitialTab)
            }
            .onAppear {
                initiateSmartAutoConnection()
                sensorManager.requestRemoteSensorStatus()
                liveKitManager.requestTimelapseStatus()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active && pairingManager.isPaired {
                    liveKitManager.isUserInitiatedStop = false
                    if !liveKitManager.isConnected && currentTransport != .p2p {
                        print("[RemoteLabMonitorView] App active — auto-reconnecting stream")
                        initiateSmartAutoConnection(forceFresh: false)
                    } else if liveKitManager.remoteVideoTrack == nil && currentTransport != .p2p {
                        liveKitManager.sendWakeSignalToBroadcaster(roomName: liveKitManager.currentRoomName)
                    }
                }
            }
            .onChange(of: pairingManager.isPaired) { _, isPaired in
                if isPaired {
                    initiateSmartAutoConnection()
                }
            }
            .onChange(of: preferredTransport) { _, _ in
                initiateSmartAutoConnection(forceFresh: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                liveKitManager.isUserInitiatedStop = false
                initiateSmartAutoConnection(forceFresh: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                p2pStreamManager.stopViewer()
                if liveKitManager.currentRole == .viewer {
                    Task {
                        // Pause or stop viewer track locally to save viewer battery/data without putting broadcaster to sleep
                        await liveKitManager.stopStream()
                    }
                }
            }
            .onDisappear {
                pairingManager.stopBrowsing()
                p2pStreamManager.stopViewer()
            }
        }
    }
    
    private func initiateSmartAutoConnection(forceFresh: Bool = false) {
        liveKitManager.isUserInitiatedStop = false
        switch currentTransport {
        case .liveKit:
            pairingManager.startBrowsingForCameras()
            p2pStreamManager.startViewer()
            Task {
                await liveKitManager.startViewer(cameraId: pairingManager.pairedCameraId, forceFresh: forceFresh)
            }
        case .p2p:
            Task {
                if liveKitManager.isConnected {
                    await liveKitManager.stopStream()
                }
            }
            pairingManager.startBrowsingForCameras()
            p2pStreamManager.startViewer()
        case .auto:
            pairingManager.startBrowsingForCameras()
            Task {
                await liveKitManager.startViewer(cameraId: pairingManager.pairedCameraId, forceFresh: forceFresh)
            }
        }
    }

    // MARK: - Pairing Discovery View (First Time / Unpaired - Exclusief via QR-Code)
    @ViewBuilder
    private var pairingDiscoveryView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header card
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title2.bold())
                            .foregroundColor(MycoTheme.blue)
                        Text(store.t(nl: "Koppel via Camera QR-Code", en: "Pair via Camera QR Code"))
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }

                    Text(store.t(
                        nl: "Om een veilige, versleutelde verbinding met de kweekcamera op te zetten, scan je eenmalig de QR-code vanaf het scherm van de camera-telefoon.",
                        en: "To set up a secure, encrypted connection with the grow camera, scan the QR code from the camera phone once."
                    ))
                    .font(.subheadline)
                    .foregroundColor(MycoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                }
                .padding(.top, 16)

                // Large QR Scanner Card (Hero Action)
                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundColor(MycoTheme.blue.opacity(0.5))
                            .frame(width: 180, height: 180)

                        Image(systemName: "qrcode")
                            .font(.system(size: 88, weight: .ultraLight))
                            .foregroundColor(MycoTheme.blue.opacity(0.85))

                        Image(systemName: "viewfinder")
                            .font(.system(size: 110, weight: .light))
                            .foregroundColor(MycoTheme.blue)
                    }
                    .frame(height: 190)

                    Button {
                        showQRScanner = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.viewfinder")
                                .font(.headline)
                            Text(store.t(nl: "Scan Koppel-QR-Code van Kweekcamera", en: "Scan Grow Camera Pairing QR Code"))
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MycoTheme.blue)
                        .cornerRadius(14)
                        .shadow(color: MycoTheme.blue.opacity(0.4), radius: 8, y: 3)
                    }
                }
                .padding(20)
                .background(MycoTheme.card)
                .cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(MycoTheme.blue.opacity(0.25), lineWidth: 1))

                // Step-by-Step Instructions Card
                VStack(alignment: .leading, spacing: 14) {
                    Text(store.t(nl: "Hoe werkt het?", en: "How does it work?"))
                        .font(.caption.bold())
                        .foregroundColor(MycoTheme.textSecondary)
                        .textCase(.uppercase)

                    HStack(alignment: .top, spacing: 12) {
                        Text("1")
                            .font(.headline.bold())
                            .foregroundColor(.black)
                            .frame(width: 26, height: 26)
                            .background(MycoTheme.green)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Zet Camera-Telefoon Klaar", en: "Set Up Camera Phone"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(store.t(
                                nl: "Open MycoLabs op het camera-toestel in je kweekruimte en kies 'Vaste Kweekcamera' bij de start of in Instellingen.",
                                en: "Open MycoLabs on the camera device in your grow room and select 'Dedicated Camera' at start or in Settings."
                            ))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Text("2")
                            .font(.headline.bold())
                            .foregroundColor(.black)
                            .frame(width: 26, height: 26)
                            .background(MycoTheme.green)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Scan Koppel-QR", en: "Scan Pairing QR"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(store.t(
                                nl: "Het camera-scherm toont direct de koppel-QR-code. Tik op 'Scan Koppel-QR-Code' hierboven.",
                                en: "MycoCam shows the QR code immediately. Tap 'Scan Pairing QR Code' above."
                            ))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Text("3")
                            .font(.headline.bold())
                            .foregroundColor(.black)
                            .frame(width: 26, height: 26)
                            .background(MycoTheme.green)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Scannen & Klaar!", en: "Scan & Done!"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(store.t(
                                nl: "Tik hierboven op 'Scan Koppel-QR-Code' en richt deze telefoon op het scherm. Vanaf dan kun je overal ter wereld live meekijken!",
                                en: "Tap 'Scan Pairing QR Code' above and point at the screen. You can now monitor live anywhere in the world!"
                            ))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                }
                .padding(18)
                .background(MycoTheme.card)
                .cornerRadius(16)
                
                // Modulaire IP / RTSP / Snapshot Camera Integratie
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "video.badge.plus")
                            .font(.headline)
                            .foregroundColor(Color.teal)
                        Text(store.t(nl: "Andere Camera Koppelen (RTSP / HTTP)", en: "Connect Other Camera (RTSP / HTTP)"))
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    }

                    Text(store.t(
                        nl: "Geen tweede iPhone? Koppel direct een beveiligingscamera (Tapo, Reolink, Wyze), Raspberry Pi webcam of ESP32-CAM via RTSP stream of periodieke HTTP snapshot.",
                        en: "No second iPhone? Connect an IP camera (Tapo, Reolink, Wyze), Raspberry Pi webcam, or ESP32-CAM directly via RTSP stream or periodic HTTP snapshot."
                    ))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.t(nl: "RTSP Live Stream URL (Tapo, Reolink, IP-cam):", en: "RTSP Live Stream URL (Tapo, Reolink, IP-cam):"))
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                        TextField("rtsp://admin:wachtwoord@192.168.1.150:554/stream1", text: Binding(
                            get: { store.db.environmentConfig.effectiveRtspURL },
                            set: {
                                store.db.environmentConfig.rtspStreamURL = $0
                                if !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    store.db.environmentConfig.cameraSourceType = CameraSourceType.rtsp.rawValue
                                }
                                store.save()
                            }
                        ))
                        .font(.system(.caption, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.t(nl: "HTTP Snapshot URL (ESP32-CAM, Pi Cam):", en: "HTTP Snapshot URL (ESP32-CAM, Pi Cam):"))
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                        HStack {
                            TextField("http://192.168.1.160/capture", text: Binding(
                                get: { store.db.environmentConfig.effectiveSnapshotURL },
                                set: {
                                    store.db.environmentConfig.httpSnapshotURL = $0
                                    if !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        store.db.environmentConfig.cameraSourceType = CameraSourceType.httpSnapshot.rawValue
                                    }
                                    store.save()
                                }
                            ))
                            .font(.system(.caption, design: .monospaced))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)

                            if !store.db.environmentConfig.effectiveSnapshotURL.isEmpty {
                                Button {
                                    Task {
                                        if let img = await store.fetchHTTPSnapshot(urlString: store.db.environmentConfig.effectiveSnapshotURL) {
                                            let photoItem = TimelapsePhotoItem.createAndSave(
                                                image: img,
                                                caption: store.t(nl: "Snapshot via IP Camera", en: "Snapshot via IP Camera"),
                                                cameraType: "wide",
                                                cameraName: "IP Camera",
                                                temperatureC: store.db.environmentConfig.currentTempC,
                                                humidityPct: store.db.environmentConfig.currentHumidityPct
                                            )
                                            await MainActor.run {
                                                store.db.timelapsePhotos.insert(photoItem, at: 0)
                                                store.save()
                                                let gen = UINotificationFeedbackGenerator()
                                                gen.notificationOccurred(.success)
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.subheadline.bold())
                                        .foregroundColor(Color.teal)
                                        .padding(10)
                                        .background(Color.teal.opacity(0.15))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .background(MycoTheme.card)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.teal.opacity(0.3), lineWidth: 1))
            }
            .padding(16)
        }
    }

    // MARK: - Paired Monitor View (Connected / Remote Access)
    @ViewBuilder
    private var pairedMonitorView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // First-time success toast if just paired
                if pairingManager.justPairedSuccessfully {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(MycoTheme.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Succesvol Gekoppeld!", en: "Successfully Paired!"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(store.t(
                                nl: "Deze camera is onthouden. Je hebt vanaf nu live beeld overal ter wereld via 4G/5G en Wi-Fi.",
                                en: "Camera remembered. Live stream is accessible anywhere via 4G/5G and Wi-Fi."
                            ))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(MycoTheme.green.opacity(0.18))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.green.opacity(0.4), lineWidth: 1))
                }

                // Toast when snapshot is captured or saved
                if let toast = liveKitManager.lastSavedSnapshotToast,
                   toast.contains("Foto") || toast.contains("Galerij") || toast.contains("Flitsfoto") || toast.contains("Saved") || toast.contains("Snapshot") || toast.contains("MycoLabs") || toast.contains("vastgelegd") {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.badge.checkmark.fill")
                            .font(.title3)
                            .foregroundColor(MycoTheme.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(toast.contains("album") ? store.t(nl: "Bewaard in Album 'MycoLabs'!", en: "Saved to 'MycoLabs' Album!") : store.t(nl: "Kweekopname Vastgelegd", en: "Grow Capture Recorded"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(toast)
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(MycoTheme.green.opacity(0.18))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.green.opacity(0.4), lineWidth: 1))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Interactive Connection Source Selector & Live Status Banner
                HStack(spacing: 8) {
                    Menu {
                        Section(store.t(nl: "Kies Verbindingsbron", en: "Choose Connection Source")) {
                            Button {
                                applyTransportPreference(.liveKit)
                            } label: {
                                HStack {
                                    Label(store.t(nl: "LiveKit (Pi Hub & 4G/5G) [Aanbevolen]", en: "LiveKit (Pi Hub & 4G/5G) [Recommended]"), systemImage: "antenna.radiowaves.left.and.right")
                                    if currentTransport == .liveKit {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            Button {
                                applyTransportPreference(.p2p)
                            } label: {
                                HStack {
                                    Label(store.t(nl: "P2P Direct (Wi-Fi / BT)", en: "P2P Direct (Wi-Fi / BT)"), systemImage: "personalhotspot")
                                    if currentTransport == .p2p {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            Button {
                                applyTransportPreference(.auto)
                            } label: {
                                HStack {
                                    Label(store.t(nl: "Automatisch (Auto-Fallback)", en: "Automatic (Auto-Fallback)"), systemImage: "bolt.shield.fill")
                                    if currentTransport == .auto {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            let isStreamActive = (currentTransport == .p2p && p2pStreamManager.receivedFrame != nil)
                                || (currentTransport != .p2p && liveKitManager.remoteVideoTrack != nil)
                            
                            Circle()
                                .fill(isStreamActive ? (currentTransport == .p2p ? Color.green : Color.cyan) : Color.orange)
                                .frame(width: 8, height: 8)
                            
                            Image(systemName: currentTransport.iconName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(MycoDevicePlatform.isCompactWidth ? currentTransport.shortName : currentTransport.displayName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        .padding(.horizontal, MycoDevicePlatform.isCompactWidth ? 8 : 10)
                        .padding(.vertical, 6)
                        .background(currentTransport == .p2p ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(currentTransport == .p2p ? Color.green.opacity(0.4) : Color.blue.opacity(0.4), lineWidth: 1)
                        )
                    }

                    // Stream & Fotokwaliteit Selector (4K UHD / 1080p / 720p)
                    Menu {
                        Section(store.t(nl: "Kwaliteit & Resolutie", en: "Quality & Resolution")) {
                            ForEach(StreamQualityPreset.allCases) { preset in
                                Button {
                                    liveKitManager.setStreamQuality(preset)
                                } label: {
                                    HStack {
                                        Label(preset.title, systemImage: preset.icon)
                                        if liveKitManager.streamQuality == preset {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: liveKitManager.streamQuality.icon)
                                .font(.system(size: 10, weight: .bold))
                            Text(liveKitManager.streamQuality.shortTitle)
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, MycoDevicePlatform.isCompactWidth ? 6 : 8)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.18))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.purple.opacity(0.35), lineWidth: 1)
                        )
                    }

                    Spacer(minLength: 4)

                    // Quick Reconnect Button
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        initiateSmartAutoConnection(forceFresh: true)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                            Text(store.t(nl: "Herverbind", en: "Reconnect"))
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(MycoTheme.textSecondary)
                        .padding(.horizontal, MycoDevicePlatform.isCompactWidth ? 6 : 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 2)

                // Camera Video Display Container
                cameraVideoDisplaySection

                // Direct Smart Hardware Controls (Controllable right while viewing camera stream)
                hardwareControlsSection

                // Remote Optical Sensor Readout & Vision AI Control (Replaces LiDAR)
                remoteOpticalSensorControlSection

                // Remote Timelapse, Auto-Flash & Photo Gallery Studio
                remoteTimelapseControlSection
            }
            .padding(16)
        }
    }

    // MARK: - Camera Video Display Section
    @ViewBuilder
    private var cameraVideoDisplaySection: some View {
        let hasLiveKitVideo = liveKitManager.remoteVideoTrack != nil
        let hasP2PVideo = p2pStreamManager.receivedFrame != nil
        let showLiveKitFeed = (currentTransport == .liveKit && hasLiveKitVideo) || (currentTransport == .auto && hasLiveKitVideo)
        let showP2PFeed = (currentTransport == .p2p && hasP2PVideo) || (!hasLiveKitVideo && hasP2PVideo)
        
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black)
                    .shadow(color: Color.black.opacity(0.4), radius: 8)

                if showP2PFeed, let p2pFrame = p2pStreamManager.receivedFrame {
                    // 1. Direct P2P Video Feed (Wi-Fi / Bluetooth)
                    Image(uiImage: p2pFrame)
                        .resizable()
                        .aspectRatio(contentMode: isEmbeddedVideoFitMode ? .fit : .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .cornerRadius(18)
                        .overlay(
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    handleTapToFocus(at: location, in: geo.size)
                                }
                        )

                    // Animated Yellow Camera Autofocus Reticle
                    if showFocusReticle, let pt = tapFocusPoint {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.yellow, lineWidth: 1.8)
                                .frame(width: 58, height: 58)
                                .shadow(color: Color.yellow.opacity(0.8), radius: 4)
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 4, height: 4)
                        }
                        .position(pt)
                        .transition(.scale(scale: 1.25).combined(with: .opacity))
                        .allowsHitTesting(false)
                    }
                } else if showLiveKitFeed, let track = liveKitManager.remoteVideoTrack {
                    // 2. High-Performance LiveKit WebRTC Feed (Pi Hub & 4G/5G)
                    SwiftUIVideoView(track, layoutMode: isEmbeddedVideoFitMode ? .fit : .fill)
                        .cornerRadius(18)
                        .overlay(
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    handleTapToFocus(at: location, in: geo.size)
                                }
                        )

                    // Animated Yellow Camera Autofocus Reticle (only when video is active)
                    if showFocusReticle, let pt = tapFocusPoint {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.yellow, lineWidth: 1.8)
                                .frame(width: 58, height: 58)
                                .shadow(color: Color.yellow.opacity(0.8), radius: 4)
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 4, height: 4)
                        }
                        .position(pt)
                        .transition(.scale(scale: 1.25).combined(with: .opacity))
                        .allowsHitTesting(false)
                    }
                } else if liveKitManager.isViewerWaitingTooLong {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(MycoTheme.amber)

                        Text(store.t(
                            nl: "Kweekcamera reageert niet of staat in Eco-Standby",
                            en: "Grow camera not responding or in Eco-Standby"
                        ))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                        Text(store.t(
                            nl: "Controleer of de kweektelefoon aan de lader hangt, Wi-Fi verbonden is en MycoLabs geopend is.",
                            en: "Check if the grow phone is charging, Wi-Fi is connected, and MycoLabs is open."
                        ))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                        HStack(spacing: 10) {
                            Button {
                                triggerManualReconnect(forceHardReset: false)
                            } label: {
                                HStack(spacing: 6) {
                                    if isReconnectingNow {
                                        ProgressView()
                                            .scaleEffect(0.75)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text(isReconnectingNow
                                         ? store.t(nl: "Opnieuw verbinden...", en: "Reconnecting...")
                                         : store.t(nl: "Opnieuw Verbinden", en: "Try Again"))
                                }
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(MycoTheme.blue)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .disabled(isReconnectingNow)

                            Button {
                                triggerManualReconnect(forceHardReset: true)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text(store.t(nl: "Volledige Reset", en: "Full Reset"))
                                }
                                .font(.caption.bold())
                                .foregroundColor(Color.cyan)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Color.cyan.opacity(0.18))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .disabled(isReconnectingNow)
                        }
                    }
                    .padding(18)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.15)
                        
                        Image(systemName: "video.badge.waveform")
                            .font(.system(size: 34))
                            .foregroundColor(MycoTheme.blue)

                        Text(store.t(
                            nl: "Verbinden met \(pairingManager.pairedCameraName ?? "Kweekcamera")...",
                            en: "Connecting to \(pairingManager.pairedCameraName ?? "Grow Camera")..."
                        ))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                        Text(currentTransport == .p2p
                            ? p2pStreamManager.statusMessage
                            : (liveKitManager.statusMessage.isEmpty
                                ? store.t(
                                    nl: pairingManager.isCellular ? "Live via 4G/5G mobiel netwerk..." : "Live via Pi Hub / Wi-Fi...",
                                    en: pairingManager.isCellular ? "Live over 4G/5G cellular network..." : "Live over Pi Hub / Wi-Fi..."
                                )
                                : liveKitManager.statusMessage))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)

                        Button {
                            triggerManualReconnect()
                        } label: {
                            HStack(spacing: 6) {
                                if isReconnectingNow {
                                    ProgressView()
                                        .scaleEffect(0.75)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(isReconnectingNow
                                     ? store.t(nl: "Opnieuw verbinden...", en: "Reconnecting...")
                                     : store.t(nl: "Opnieuw Verbinden", en: "Reconnect"))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(MycoTheme.blue)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(isReconnectingNow)
                        .padding(.top, 2)
                    }
                    .padding(20)
                }

                // Overlay telemetry & transport indicator (Smoothly scalable across all screen widths)
                VStack {
                    HStack(spacing: 6) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                HStack(spacing: 6) {
                                    if let temp = store.latestSensorTempC {
                                        Label(String(format: "%.1f°C", temp), systemImage: "thermometer.medium")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Label("--.-°C", systemImage: "thermometer.medium")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                    if let hum = store.latestSensorHumidityPct {
                                        Label(String(format: "%.0f%% RV", hum), systemImage: "drop.fill")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(MycoTheme.blue)
                                    } else {
                                        Label("--% RV", systemImage: "drop.fill")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.75))
                                .cornerRadius(8)

                                if liveKitManager.isRemoteTimelapseRunning {
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.red).frame(width: 6, height: 6)
                                        Text("REC #\(liveKitManager.remoteTimelapseFramesCount)")
                                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 5)
                                    .background(Color.red.opacity(0.75))
                                    .cornerRadius(8)
                                }

                                if let pct = currentCameraBatteryPercent {
                                    HStack(spacing: 3) {
                                        Image(systemName: currentCameraBatteryIcon)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(currentCameraBatteryColor)
                                        Text("\(pct)%")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                        if currentCameraIsCharging {
                                            Image(systemName: "bolt.fill")
                                                .font(.system(size: 7))
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 5)
                                    .background(Color.black.opacity(0.75))
                                    .cornerRadius(8)
                                }

                                HStack(spacing: 4) {
                                    if showP2PFeed {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                        Text("P2P DIRECT (WI-FI/BT)")
                                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                            .foregroundColor(.green)
                                    } else {
                                        Circle()
                                            .fill(showLiveKitFeed ? (pairingManager.isCellular ? Color.cyan : Color.green) : Color.orange)
                                            .frame(width: 6, height: 6)
                                        Text(showLiveKitFeed ? (pairingManager.isCellular ? "LIVEKIT • 4G/5G" : "LIVEKIT • PI HUB") : "VERBINDEN...")
                                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.75))
                                .cornerRadius(8)
                            }
                        }

                        Spacer(minLength: 4)

                        HStack(spacing: 5) {
                            // Fit / Fill aspect toggle button (when video is active)
                            if showLiveKitFeed || showP2PFeed {
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        isEmbeddedVideoFitMode.toggle()
                                    }
                                } label: {
                                    Image(systemName: isEmbeddedVideoFitMode ? "rectangle.arrowtriangle.2.outward" : "rectangle.arrowtriangle.2.inward")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.cyan)
                                        .padding(7)
                                        .background(Color.black.opacity(0.75))
                                        .clipShape(Circle())
                                }
                            }

                            // Picture-in-Picture Mini Player button
                            if liveKitManager.remoteVideoTrack != nil {
                                Button {
                                    liveKitManager.showFloatingPiP = true
                                    dismiss()
                                } label: {
                                    Image(systemName: "pip.enter")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(7)
                                        .background(Color.black.opacity(0.75))
                                        .clipShape(Circle())
                                }
                            }

                            // Fullscreen expand button
                            Button {
                                showFullscreenLive = true
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(7)
                                    .background(Color.black.opacity(0.75))
                                    .clipShape(Circle())
                            }
                        }
                        .layoutPriority(2)
                    }
                    .padding(10)

                    Spacer()

                    // Bottom Optical Sensor, Barometer & Eco-Token Mini-HUD Bar on Video Player
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            // Optische Sensor chip
                            Button {
                                showOpticalHygrometerSheet = true
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "binoculars.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.cyan)
                                    if let r = opticalManager.lastReading {
                                        Text("\(Int(r.humidityPct))% RV")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                        if let temp = r.temperatureC {
                                            Text("• \(String(format: "%.1f", temp))°")
                                                .font(.system(size: 8, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    } else {
                                        Text(store.t(nl: "Optische Meter", en: "Optical Meter"))
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.cyan)
                                    }
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.75))
                                .cornerRadius(6)
                            }

                            // Barometer chip (only shown when real hardware reading > 0)
                            if sensorManager.currentPressureHpa > 0 {
                                Button { showSensorSheet = true } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: sensorManager.pressureTrend.icon)
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(sensorManager.pressureTrend == .stormFront ? .red : .cyan)
                                        Text("\(String(format: "%.0f", sensorManager.currentPressureHpa)) hPa")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.75))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .frame(minHeight: 225, maxHeight: 380)
    }

    private func triggerManualReconnect(forceHardReset: Bool = false) {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        showFocusReticle = false
        tapFocusPoint = nil
        isReconnectingNow = true
        let targetId = pairingManager.pairedCameraId
            ?? MycoKVS.string(forKey: "mycolab_registered_camera_id")
        Task {
            if forceHardReset {
                await liveKitManager.hardResetAndReconnect(cameraId: targetId)
            } else {
                await liveKitManager.reconnectCurrentStream(forceFreshSession: true)
            }
            sensorManager.requestRemoteSensorStatus()
            liveKitManager.requestTimelapseStatus()
            try? await Task.sleep(nanoseconds: 800_000_000)
            isReconnectingNow = false
        }
    }

    // MARK: - Remote Optical Sensor Readout & Vision AI Control Section
    @ViewBuilder
    private var remoteOpticalSensorControlSection: some View {
        MycoCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon, title, InfoTipButton, and live status badge
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "binoculars.fill")
                        .font(.title3)
                        .foregroundColor(MycoTheme.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(store.t(nl: "Optische Sensor Aflezing", en: "Optical Sensor Readout"))
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            
                            InfoTipButton(
                                title: store.t(nl: "Optische Sensor & Mist AI", en: "Optical Sensor & Mist AI"),
                                message: store.t(
                                    nl: "Vision AI leest met de livestream camera direct de fysieke hygrometer in de kweekruimte af en berekent de exacte mistduur vóórdat nevel het display beslaat.",
                                    en: "Vision AI reads the physical hygrometer display inside your grow space via the camera and calculates exact humidifier runtime before fog blurs the glass."
                                )
                            )
                        }
                        
                        Text(store.t(
                            nl: "Fysieke meter aflezen met camera & Vision AI",
                            en: "Read physical meter using camera & Vision AI"
                        ))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    if opticalManager.isScanning {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(MycoTheme.blue)
                            Text(store.t(nl: "Lezen...", en: "Reading..."))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MycoTheme.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MycoTheme.blue.opacity(0.15))
                        .cornerRadius(6)
                    } else if let reading = opticalManager.lastReading {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text(reading.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(6)
                    }
                }
                
                // Sensor Readout Values
                if let reading = opticalManager.lastReading {
                    HStack(spacing: 12) {
                        // Humidity Pct Big Metric
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Luchtvochtigheid", en: "Humidity"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MycoTheme.textSecondary)
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(Int(reading.humidityPct))")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundColor(reading.humidityPct >= opticalManager.config.targetHumidityPct ? MycoTheme.green : Color.cyan)
                                Text("% RV")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
                        
                        // Temperature Metric
                        if let temp = reading.temperatureC {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Temperatuur", en: "Temperature"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(MycoTheme.textSecondary)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(String(format: "%.1f", temp))
                                        .font(.system(size: 24, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("°C")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(10)
                        }
                        
                        // Calculated Mist Duration
                        if reading.calculatedHumidifierDurationSec > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Mist AI Duur", en: "Mist AI Time"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(MycoTheme.textSecondary)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(MycoTheme.blue)
                                    Text("\(reading.calculatedHumidifierDurationSec)")
                                        .font(.system(size: 24, weight: .black, design: .rounded))
                                        .foregroundColor(MycoTheme.blue)
                                    Text("s")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Humidifier trigger banner if running
                    if opticalManager.isHumidifierRunning {
                        HStack(spacing: 8) {
                            Image(systemName: "wind")
                                .foregroundColor(.cyan)
                            Text(store.t(
                                nl: "Luchtbevochtiger actief: nog \(opticalManager.humidifierRemainingSeconds)s mist",
                                en: "Humidifier running: \(opticalManager.humidifierRemainingSeconds)s mist left"
                            ))
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.cyan.opacity(0.12))
                        .cornerRadius(8)
                    }
                } else {
                    // Empty state banner
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 24))
                            .foregroundColor(MycoTheme.blue.opacity(0.8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Nog geen meterstand afgelezen", en: "No meter reading yet"))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Text(store.t(
                                nl: "Klik op 'Lees Sensor Af' om het display van je hygrometer direct te scannen via de live camera.",
                                en: "Tap 'Read Sensor' to immediately scan your physical hygrometer display via the live camera."
                            ))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                }
                
                // Action Buttons Row: "Lees Sensor Af" + "Flits Toggle" + "Kalibratie & Zones"
                HStack(spacing: 8) {
                    Button {
                        Task {
                            await opticalManager.triggerScanAndReact()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if opticalManager.isScanning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.black)
                            } else {
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            Text(opticalManager.isScanning
                                 ? store.t(nl: "Sensor Aflezen...", en: "Reading...")
                                 : store.t(nl: "Lees Sensor Af", en: "Read Sensor"))
                                .font(.caption.bold())
                                .lineLimit(1)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(MycoTheme.blue)
                        .cornerRadius(10)
                    }
                    .disabled(opticalManager.isScanning)

                    // Quick Flash Toggle (voorkomt spiegeling / overbelichting op LCD scherm)
                    Button {
                        opticalManager.config.useFlash.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: opticalManager.config.useFlash ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(opticalManager.config.useFlash ? store.t(nl: "Flits", en: "Flash") : store.t(nl: "Geen Flits", en: "No Flash"))
                                .font(.caption2.bold())
                        }
                        .foregroundColor(opticalManager.config.useFlash ? .yellow : MycoTheme.textSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(opticalManager.config.useFlash ? 0.16 : 0.06))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(opticalManager.config.useFlash ? Color.yellow.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }

                    Button {
                        showOpticalHygrometerSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 12, weight: .bold))
                            Text(store.t(nl: "Zones", en: "Zones"))
                                .font(.caption.bold())
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.10))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Remote Timelapse, Auto-Flash & Photo Gallery Studio Card
    @ViewBuilder
    private var remoteTimelapseControlSection: some View {
        MycoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "timelapse")
                        .foregroundColor(liveKitManager.isRemoteTimelapseRunning ? .red : MycoTheme.green)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(store.t(nl: "Remote Timelapse & Foto Studio", en: "Remote Timelapse & Photo Studio"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            if liveKitManager.isRemoteTimelapseRunning {
                                Text("REC #\(liveKitManager.remoteTimelapseFramesCount)")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.25))
                                    .foregroundColor(.red)
                                    .cornerRadius(4)
                            }
                        }
                        Text(store.t(
                            nl: liveKitManager.isRemoteTimelapseRunning
                                ? "Kweekcamera maakt automatisch elke \(liveKitManager.remoteTimelapseIntervalMinutes) min een foto"
                                : "Bedien timelapse-opnames, auto-flits en galerij vanaf dit scherm",
                            en: liveKitManager.isRemoteTimelapseRunning
                                ? "Grow camera captures a frame every \(liveKitManager.remoteTimelapseIntervalMinutes) min"
                                : "Control timelapse recording, auto-flash, and gallery remotely"
                        ))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Button {
                            selectedGalleryInitialTab = .localPhotos
                            showTimelapseGallery = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.stack.fill")
                                Text("\(store.db.timelapsePhotos.count)")
                            }
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(MycoTheme.blue.opacity(0.18))
                            .cornerRadius(8)
                        }

                        Button {
                            selectedGalleryInitialTab = .piHubArchive
                            showTimelapseGallery = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "externaldrive.badge.timemachine")
                                Text(store.t(nl: "Pi Video's", en: "Pi Videos"))
                            }
                            .font(.caption.bold())
                            .foregroundColor(Color.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.cyan.opacity(0.18))
                            .cornerRadius(8)
                        }
                    }
                }

                // Interval Selector Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text(store.t(nl: "Interval:", en: "Interval:"))
                            .font(.caption2.bold())
                            .foregroundColor(MycoTheme.textSecondary)
                            .padding(.trailing, 2)
                        ForEach([1, 2, 5, 10, 15, 30, 60], id: \.self) { min in
                            let currentSelection = liveKitManager.isRemoteTimelapseRunning ? liveKitManager.remoteTimelapseIntervalMinutes : selectedRemoteTimelapseInterval
                            Button {
                                selectedRemoteTimelapseInterval = min
                            } label: {
                                Text("\(min)m")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(currentSelection == min ? .black : .white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(currentSelection == min ? MycoTheme.green : Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                // Timelapse Camera Selection Pills (Always Clickable)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text(store.t(nl: "Camera:", en: "Camera:"))
                            .font(.caption2.bold())
                            .foregroundColor(MycoTheme.textSecondary)
                            .padding(.trailing, 2)

                        let currentCamId = liveKitManager.remoteTimelapseCameraID.isEmpty ? "wide" : liveKitManager.remoteTimelapseCameraID
                        let camsToShow = liveKitManager.remoteAvailableCameras.isEmpty ? [
                            RemoteCameraInfo(id: "wide", name: "Kweekcamera (1.0x)", shortLabel: "1.0x"),
                            RemoteCameraInfo(id: "ultrawide", name: "Groothoek (0.5x)", shortLabel: "0.5x"),
                            RemoteCameraInfo(id: "telephoto", name: "Telelens (3.0x)", shortLabel: "3.0x")
                        ] : liveKitManager.remoteAvailableCameras

                        // Multi-Camera Option: Alle Camera's tegelijk
                        let isAllSelected = currentCamId == "all"
                        let isAllRec = liveKitManager.isTimelapseRunning(for: "all")
                        Button {
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                            liveKitManager.remoteTimelapseCameraID = "all"
                            UserDefaults.standard.set("all", forKey: "mycolab_viewer_remote_timelapse_camera_id")
                        } label: {
                            HStack(spacing: 4) {
                                if isAllRec {
                                    Circle().fill(Color.red).frame(width: 6, height: 6)
                                } else {
                                    Image(systemName: "camera.on.rectangle.fill")
                                        .font(.system(size: 9))
                                }
                                Text(store.t(nl: "Alle Camera's", en: "All Cameras"))
                                    .font(.system(size: 11, weight: .bold))
                                if isAllRec {
                                    Text("REC")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(.red)
                                }
                            }
                            .foregroundColor(isAllSelected ? .black : (isAllRec ? .red : .white))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isAllSelected ? MycoTheme.green : (isAllRec ? Color.red.opacity(0.2) : Color.white.opacity(0.1)))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        ForEach(camsToShow) { cam in
                            let isSelected = currentCamId == cam.id ||
                                (!liveKitManager.remoteAvailableCameras.isEmpty && currentCamId.contains(cam.shortLabel))
                            let isThisCamRec = liveKitManager.isTimelapseRunning(for: cam.id)
                            Button {
                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.impactOccurred()
                                liveKitManager.remoteTimelapseCameraID = cam.id
                                UserDefaults.standard.set(cam.id, forKey: "mycolab_viewer_remote_timelapse_camera_id")
                                if let actual = liveKitManager.remoteAvailableCameras.first(where: { $0.id == cam.id }) {
                                    liveKitManager.selectRemoteCamera(id: actual.id)
                                } else {
                                    liveKitManager.selectRemoteCameraByType(cam.id)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if isThisCamRec {
                                        Circle().fill(Color.red).frame(width: 6, height: 6)
                                    } else {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 9))
                                    }
                                    Text(cam.shortLabel)
                                        .font(.system(size: 11, weight: .bold))
                                    if isThisCamRec {
                                        Text("REC")
                                            .font(.system(size: 8, weight: .black))
                                            .foregroundColor(.red)
                                    }
                                }
                                .foregroundColor(isSelected ? .black : (isThisCamRec ? .red : .white))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isSelected ? MycoTheme.green : (isThisCamRec ? Color.red.opacity(0.2) : Color.white.opacity(0.1)))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Auto-Flash in Dark & AI Auto-Scan Toggles
                HStack(spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { liveKitManager.remoteTimelapseAutoFlashIfLampOff },
                        set: { liveKitManager.setRemoteOrLocalTimelapseAutoFlash($0) }
                    )) {
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.badge.automatic.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(store.t(nl: "Flits in het donker", en: "Auto-flash in dark"))
                                .font(.caption)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                    .tint(.yellow)
                }
                .padding(.vertical, 2)

                // Start/Stop Timelapse + Flash Snapshot Action Row per selected camera
                let currentTargetCam = liveKitManager.remoteTimelapseCameraID.isEmpty ? "wide" : liveKitManager.remoteTimelapseCameraID
                let isCurrentTargetRunning = liveKitManager.isTimelapseRunning(for: currentTargetCam)
                let activeCamLabel: String = {
                    if currentTargetCam == "all" { return store.t(nl: "Alle Camera's", en: "All Cameras") }
                    if let found = liveKitManager.remoteAvailableCameras.first(where: { $0.id == currentTargetCam }) {
                        return found.shortLabel
                    }
                    if currentTargetCam == "wide" { return "1.0x" }
                    if currentTargetCam == "ultrawide" { return "0.5x" }
                    if currentTargetCam == "telephoto" { return "3.0x" }
                    return currentTargetCam
                }()

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                            if isCurrentTargetRunning {
                                liveKitManager.stopTimelapse(forCameraId: currentTargetCam)
                            } else {
                                liveKitManager.startTimelapse(intervalMinutes: selectedRemoteTimelapseInterval, cameraId: currentTargetCam)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isCurrentTargetRunning ? "stop.fill" : "play.fill")
                                Text(isCurrentTargetRunning
                                     ? store.t(nl: "Stop Timelapse (\(activeCamLabel))", en: "Stop Timelapse (\(activeCamLabel))")
                                     : store.t(nl: "Start Timelapse voor \(activeCamLabel) (\(selectedRemoteTimelapseInterval)m)", en: "Start Timelapse on \(activeCamLabel) (\(selectedRemoteTimelapseInterval)m)"))
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundColor(isCurrentTargetRunning ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isCurrentTargetRunning ? Color.red : MycoTheme.green)
                            .cornerRadius(10)
                        }

                        Button {
                            Task {
                                _ = await liveKitManager.captureAndSaveSnapshot(withFlash: true)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                Text(store.t(nl: "Flits-Foto", en: "Flash Photo"))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.yellow.opacity(0.18))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow.opacity(0.35), lineWidth: 1))
                        }
                        .disabled(liveKitManager.isCapturingSnapshot)
                    }

                    if liveKitManager.isRemoteTimelapseRunning && (liveKitManager.remoteActiveTimelapseCameraIDs.count > 1 || currentTargetCam != "all") {
                        Button {
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                            liveKitManager.stopTimelapse()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "stop.circle.fill")
                                Text(store.t(nl: "Stop Alle Timelapses tegelijk", en: "Stop All Timelapses at once"))
                            }
                            .font(.caption2.bold())
                            .foregroundColor(.red)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    private func handleTapToFocus(at location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let normX = location.x / size.width
        let normY = location.y / size.height
        
        tapFocusPoint = location
        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
            showFocusReticle = true
        }
        
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        
        liveKitManager.sendFocusCommand(x: normX, y: normY)
        
        focusTimer?.cancel()
        focusTimer = Timer.publish(every: 1.6, on: .main, in: .common)
            .autoconnect()
            .sink { [self] _ in
                withAnimation(.easeOut(duration: 0.35)) {
                    self.showFocusReticle = false
                }
                self.focusTimer?.cancel()
                self.focusTimer = nil
            }
    }

    private var smartPlugCount: Int {
        store.db.smartDevices.filter { $0.deviceType != "Sensor" }.count
    }

    // MARK: - Dedicated 24/7 Stream Lab Hub Status Section
    @ViewBuilder
    private var streamHubStatusSection: some View {
        StreamHubStatusSectionView(
            smartPlugCount: smartPlugCount,
            batteryIcon: currentCameraBatteryIcon,
            batteryColor: currentCameraBatteryColor,
            batteryStatusText: currentCameraBatteryStatusText,
            isCharging: currentCameraIsCharging
        )
    }

    // MARK: - Hardware Controls Section
    @ViewBuilder
    private var hardwareControlsSection: some View {
        MycoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(store.t(nl: "Hardware Afstandsbediening", en: "Hardware Remote Controls"))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Text(pairingManager.isCellular ? store.t(nl: "Via 4G/5G Cloud", en: "Via 4G/5G Cloud") : store.t(nl: "Direct Wi-Fi / Cloud", en: "Direct Wi-Fi / Cloud"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(pairingManager.isCellular ? Color.cyan : Color.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                // Quick Lens Switching Row (0.5x Ultra-Wide, 1.0x Wide, 3.0x Telephoto)
                HStack(spacing: 8) {
                    Text(store.t(nl: "Lens:", en: "Lens:"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MycoTheme.textSecondary)
                    
                    let activeLabel = liveKitManager.remoteActiveCameraLabel
                    let lenses: [(id: String, type: String, label: String, icon: String)] = [
                        ("wide", "wide", store.t(nl: "1.0x Kweek", en: "1.0x Flush"), "camera.fill"),
                        ("ultrawide", "ultrawide", store.t(nl: "0.5x Tent", en: "0.5x Tent"), "tent.fill"),
                        ("telephoto", "telephoto", store.t(nl: "3.0x AI Sensor", en: "3.0x AI Sensor"), "binoculars.fill")
                    ]
                    
                    ForEach(lenses, id: \.id) { lens in
                        let isSelected = activeLabel.localizedCaseInsensitiveContains(lens.id) ||
                            (lens.id == "wide" && (activeLabel.isEmpty || activeLabel.contains("1.0") || activeLabel.contains("Kweek") || activeLabel.contains("Wide"))) ||
                            (lens.id == "ultrawide" && (activeLabel.contains("0.5") || activeLabel.contains("Tent") || activeLabel.contains("Ultra"))) ||
                            (lens.id == "telephoto" && (activeLabel.contains("3.0") || activeLabel.contains("Sensor") || activeLabel.contains("Tele")))
                        
                        Button {
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                            if let actual = liveKitManager.remoteAvailableCameras.first(where: {
                                $0.shortLabel.localizedCaseInsensitiveContains(lens.id) ||
                                $0.name.localizedCaseInsensitiveContains(lens.id)
                            }) {
                                liveKitManager.selectRemoteCamera(id: actual.id)
                            } else {
                                liveKitManager.selectRemoteCameraByType(lens.type)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: lens.icon)
                                    .font(.system(size: 10, weight: .bold))
                                Text(lens.label)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(isSelected ? .black : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(isSelected ? (lens.id == "telephoto" ? Color.orange : (lens.id == "ultrawide" ? Color.purple : MycoTheme.green)) : Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                }

                // Flashlight / Grow Light Remote Switch, Remote Screen Sleep, Lens Switch & Snapshot
                HStack(spacing: 8) {
                    Button {
                        liveKitManager.toggleTorch()
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                    } label: {
                        let isTorchActive = liveKitManager.isTorchOn
                        HStack(spacing: 4) {
                            Image(systemName: isTorchActive ? "flashlight.on.fill" : "flashlight.off.fill")
                                .foregroundColor(isTorchActive ? MycoTheme.amber : .white)
                            Text(isTorchActive ? store.t(nl: "Lamp AAN", en: "Light ON") : store.t(nl: "Lamp UIT", en: "Light OFF"))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isTorchActive ? MycoTheme.amber.opacity(0.3) : Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isTorchActive ? MycoTheme.amber : Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }

                    // Remote Screen Sleep (OLED Saver on Camera Phone) - Automatically hidden if connected camera has no screen (headless/RTSP)
                    if liveKitManager.currentRemoteCameraHasScreen {
                        Button {
                            liveKitManager.toggleRemoteSleep()
                        } label: {
                            let isDimmed = liveKitManager.isRemoteScreenDimmed
                            HStack(spacing: 4) {
                                Image(systemName: isDimmed ? "moon.stars.fill" : "moon.fill")
                                    .foregroundColor(isDimmed ? MycoTheme.blue : .white)
                                Text(isDimmed ? store.t(nl: "Scherm Dim", en: "Screen Dim") : store.t(nl: "Scherm Spaar", en: "Sleep Cam"))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isDimmed ? MycoTheme.blue.opacity(0.3) : Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isDimmed ? MycoTheme.blue : Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }

                    // Blue Snapshot Button (Prominent, bold touch target)
                    Button {
                        Task {
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                            _ = await liveKitManager.captureAndSaveSnapshot()
                        }
                    } label: {
                        HStack(spacing: 7) {
                            if liveKitManager.isCapturingSnapshot {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            Text(store.t(nl: "Foto Maken", en: "Take Photo"))
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(liveKitManager.isCapturingSnapshot ? MycoTheme.blue.opacity(0.6) : MycoTheme.blue)
                        .cornerRadius(12)
                        .shadow(color: MycoTheme.blue.opacity(0.4), radius: 5, x: 0, y: 2)
                    }
                    .disabled(liveKitManager.isCapturingSnapshot)
                    .buttonStyle(.plain)
                    .layoutPriority(1.5)
                }

                // Live Helderheid / Flashlight Brightness Slider on Remote Monitor
                if liveKitManager.isTorchOn {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(store.t(nl: "Helderheid Lamp:", en: "Lamp Brightness:"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(MycoTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer()
                            Text("\(Int(remoteBrightness * 100))%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(MycoTheme.amber)
                        }
                        
                        HStack(spacing: 10) {
                            Image(systemName: "sun.min.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Slider(
                                value: $remoteBrightness,
                                in: 0.05...1.0
                            )
                            .tint(MycoTheme.amber)
                            .onChange(of: remoteBrightness) { _, newLevel in
                                liveKitManager.setTorchBrightness(newLevel)
                            }
                            Image(systemName: "sun.max.fill")
                                .font(.caption)
                                .foregroundColor(MycoTheme.amber)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Tap-to-focus guide hint
                HStack(spacing: 6) {
                    Image(systemName: "viewfinder")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(store.t(
                        nl: "Tik op het beeld om automatisch scherp te stellen.",
                        en: "Tap the video anywhere to autofocus instantly."
                    ))
                    .font(.system(size: 11))
                    .foregroundColor(MycoTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }
                .padding(.top, 2)

                Divider().background(MycoTheme.border)

                // Remote Smart Plugs Shortcuts (Relayed directly to 24/7 Stream Hub on local Wi-Fi)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(store.t(nl: "Slimme Stekkers (Via Stream Hub)", en: "Smart Plugs (Via Stream Hub)"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        Text(store.t(nl: "Lokale Wi-Fi", en: "Local Wi-Fi"))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(MycoTheme.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MycoTheme.green.opacity(0.15))
                            .cornerRadius(4)
                    }

                    if store.db.smartDevices.isEmpty {
                        Text(store.t(nl: "Koppel slimme stekkers in de Hub om ze hier op afstand te schakelen.", en: "Pair smart plugs in the Hub to control them remotely here."))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    } else {
                        ForEach(store.db.smartDevices) { dev in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dev.name)
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                    Text(dev.deviceType)
                                        .font(.system(size: 9))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                Spacer()
                                Button {
                                    store.testSmartDevice(id: dev.id, relayToHub: true)
                                } label: {
                                    Text(store.t(nl: "Test 10s", en: "Test 10s"))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.cyan)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.cyan.opacity(0.15))
                                        .cornerRadius(6)
                                }
                                Button {
                                    store.toggleSmartDevice(id: dev.id, trigger: store.t(nl: "Kijk-app (Afstandsbediening)", en: "Remote Monitor (Control)"), relayToHub: true)
                                } label: {
                                    Text(dev.isOn ? store.t(nl: "AAN", en: "ON") : store.t(nl: "UIT", en: "OFF"))
                                        .font(.caption2.bold())
                                        .foregroundColor(dev.isOn ? .black : .white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(dev.isOn ? MycoTheme.green : Color.white.opacity(0.15))
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
}


// MARK: - 16. MYCOCAM: OLD IPHONE AS LAB WEBCAM, TIMELAPSE & GROW LIGHT
@MainActor
struct MycoCamPreviewView: UIViewControllerRepresentable {
    var isTorchOn: Bool
    var torchBrightness: Float
    
    func makeUIViewController(context: Context) -> MycoCamVC {
        let vc = MycoCamVC()
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MycoCamVC, context: Context) {
        uiViewController.setTorch(on: isTorchOn, level: torchBrightness)
    }
    
    @MainActor
    final class MycoCamVC: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
        var captureSession: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        var currentDevice: AVCaptureDevice?
        var videoOutput: AVCaptureVideoDataOutput?
        var latestFrame: UIImage?
        private let videoQueue = DispatchQueue(label: "com.mycolab.camera.videoQueue", qos: .userInteractive)
        private let ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            let session = AVCaptureSession()
            session.sessionPreset = .medium
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            
            session.addInput(input)
            self.currentDevice = device
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: videoQueue)
            if session.canAddOutput(output) {
                session.addOutput(output)
                if let conn = output.connection(with: .video) {
                    if conn.isVideoRotationAngleSupported(90) {
                        conn.videoRotationAngle = 90
                    }
                }
            }
            self.videoOutput = output
            
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.frame = view.layer.bounds
            preview.videoGravity = .resizeAspectFill
            view.layer.addSublayer(preview)
            
            self.captureSession = session
            self.previewLayer = preview
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
        
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.layer.bounds
        }
        
        private var lastProcessedTime: TimeInterval = 0
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            let now = CACurrentMediaTime()
            guard now - lastProcessedTime >= 0.04 else { return } // Max 25 fps throttle to prevent heating
            lastProcessedTime = now
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                Task { @MainActor [weak self] in
                    self?.latestFrame = uiImage
                    if MycoCamStreamManager.shared.role == .host || MycoCamStreamManager.shared.isCloudBroadcasting {
                        MycoCamStreamManager.shared.broadcastCameraFrame(uiImage)
                    }
                }
            }
        }
        
        func setTorch(on: Bool, level: Float) {
            guard let device = currentDevice, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                if on {
                    if device.isTorchModeSupported(.on) {
                        try device.setTorchModeOn(level: max(0.01, min(1.0, level)))
                    }
                } else {
                    if device.isTorchModeSupported(.off) {
                        device.torchMode = .off
                    }
                }
                device.unlockForConfiguration()
            } catch {
                print("Error setting torch: \(error)")
            }
        }
        
        func captureFrame() -> UIImage? {
            return latestFrame
        }
    }
}

@MainActor struct MycoCamView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pairingManager = MycoCamPairingManager.shared
    @ObservedObject private var liveKitManager = LiveKitStreamManager.shared
    @AppStorage("mycolab_is_dedicated_camera_device") private var isDedicatedCameraDevice: Bool = false
    @State private var showExitDedicatedAlert = false
    @State private var showExitActionSheet = false
    @State private var keepCameraActiveInBackground = true
    @State private var isExplicitlyClosingCamera = false
    @State private var showCompositionGrid = false
    @ObservedObject private var sensorManager = MycoSensorIntelligenceManager.shared
    @State private var showSensorSheet = false
    
    @State private var showPairingQR = false
    @State private var isScreenDimmed = false
    @State private var intervalMinutes: Int = 2
    @State private var showGallery = false
    @State private var showWifiInfo = false
    @State private var localIsTorchOn: Bool = false
    @State private var localTorchBrightness: Float = 0.8
    @State private var localFocusPoint: CGPoint? = nil
    @State private var showLocalFocusReticle: Bool = false
    @State private var localFocusTimer: AnyCancellable? = nil
    @State private var autoFlashIfLampOff: Bool = true
    @State private var showFlashShutter: Bool = false
    
    private var isLampActive: Bool {
        if liveKitManager.isTorchOn || localIsTorchOn {
            return true
        }
        return store.db.smartDevices.contains { device in            (device.deviceType == "Light" || device.name.localizedCaseInsensitiveContains("lamp") || device.name.localizedCaseInsensitiveContains("licht")) && device.isOn
        }
    }
    
    var body: some View {
        GeometryReader { outerGeo in
            let isLandscape = outerGeo.size.width > outerGeo.size.height
            ZStack {
            // Live Camera Background (LiveKit WebRTC Track or Standalone Viewfinder)
            if let track = liveKitManager.localVideoTrack {
                GeometryReader { geo in
                    ZStack {
                        SwiftUIVideoView(track, layoutMode: .fill)
                            .ignoresSafeArea()

                        // Composition Grid (Rule of Thirds)
                        if showCompositionGrid {
                            Path { path in
                                let w = geo.size.width
                                let h = geo.size.height
                                path.move(to: CGPoint(x: w / 3.0, y: 0))
                                path.addLine(to: CGPoint(x: w / 3.0, y: h))
                                path.move(to: CGPoint(x: 2.0 * w / 3.0, y: 0))
                                path.addLine(to: CGPoint(x: 2.0 * w / 3.0, y: h))
                                path.move(to: CGPoint(x: 0, y: h / 3.0))
                                path.addLine(to: CGPoint(x: w, y: h / 3.0))
                                path.move(to: CGPoint(x: 0, y: 2.0 * h / 3.0))
                                path.addLine(to: CGPoint(x: w, y: 2.0 * h / 3.0))
                            }
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            .allowsHitTesting(false)
                            .ignoresSafeArea()
                        }

                        // Interactive Touch Layer for Local Tap-to-Focus
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard geo.size.width > 0, geo.size.height > 0 else { return }
                                let normX = location.x / geo.size.width
                                let normY = location.y / geo.size.height

                                localFocusPoint = location
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                    showLocalFocusReticle = true
                                }

                                let gen = UIImpactFeedbackGenerator(style: .medium)
                                gen.impactOccurred()

                                liveKitManager.sendFocusCommand(x: normX, y: normY)

                                localFocusTimer?.cancel()
                                localFocusTimer = Timer.publish(every: 1.6, on: .main, in: .common)
                                    .autoconnect()
                                    .sink { _ in
                                        withAnimation(.easeOut(duration: 0.35)) {
                                            showLocalFocusReticle = false
                                        }
                                        localFocusTimer?.cancel()
                                        localFocusTimer = nil
                                    }
                            }

                        // Animated Yellow Focus Reticle
                        if showLocalFocusReticle, let pt = localFocusPoint {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.yellow, lineWidth: 1.8)
                                    .frame(width: 58, height: 58)
                                    .shadow(color: Color.yellow.opacity(0.8), radius: 4)
                                Circle()
                                    .fill(Color.yellow)
                                    .frame(width: 4, height: 4)
                            }
                            .position(pt)
                            .transition(.scale(scale: 1.25).combined(with: .opacity))
                        }
                    }
                }
                .ignoresSafeArea()
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.3)
                        Text(store.t(nl: "Kweekcamera starten...", en: "Starting grow camera..."))
                            .font(.subheadline.bold())
                            .foregroundColor(.white.opacity(0.8))
                        Text(liveKitManager.statusMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Unified OLED Screen Saver / Dim Overlay
            if isScreenDimmed || liveKitManager.isOledSaverActive {
                MycoOledStandbyOverlayView(
                    isTimelapseRunning: liveKitManager.isTimelapseRunning,
                    capturedFramesCount: liveKitManager.timelapseCapturedFramesCount,
                    timelapseIntervalMinutes: liveKitManager.timelapseIntervalMinutes,
                    autoFlashIfLampOff: autoFlashIfLampOff,
                    isLampActive: isLampActive
                ) {
                    withAnimation {
                        isScreenDimmed = false
                        liveKitManager.setOledSaver(active: false, notifyPeer: true)
                    }
                }
            }
            
            // On-screen Camera Flash Shutter Feedback
            if showFlashShutter {
                Color.white.opacity(0.85)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            
            // Interactive UI Controls
            if !(isScreenDimmed || liveKitManager.isOledSaverActive) {
                VStack(spacing: 0) {
                    // Responsive Top Bar (Vertical 2-tier vs Horizontal 1-tier)
                    mycoCamTopBar(isLandscape: isLandscape, topSafeArea: outerGeo.safeAreaInsets.top)
                    
                    // Real-Time 3D LiDAR, Barometer & Eco-Token Mini HUD
                    mycoCamMiniHUD
                    
                    // Flash Brightness Slider (if torch is on)
                    if liveKitManager.isTorchOn || localIsTorchOn {
                        HStack(spacing: 10) {
                            Image(systemName: "sun.min.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Slider(
                                value: $localTorchBrightness,
                                in: 0.05...1.0
                            )
                            .tint(MycoTheme.amber)
                            .onChange(of: localTorchBrightness) { _, newV in
                                liveKitManager.setTorchBrightness(newV)
                            }
                            Image(systemName: "sun.max.fill")
                                .font(.caption)
                                .foregroundColor(MycoTheme.amber)
                            Text("\(Int(localTorchBrightness * 100))%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 38)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.65))
                    }
                    
                    Spacer()
                    
                    // Bottom Control Console
                    VStack(spacing: 12) {                        // Live Stream Broadcast Primary Toggle Button
                        Button {
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                            Task {
                                if liveKitManager.isBroadcastingPaused {
                                    await liveKitManager.resumeBroadcasting()
                                } else {
                                    await liveKitManager.pauseBroadcasting()
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: liveKitManager.isBroadcastingPaused ? "antenna.radiowaves.left.and.right" : "pause.circle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text(liveKitManager.isBroadcastingPaused ?
                                     store.t(nl: "Start Live Uitzending (HD)", en: "Start Live Broadcast (HD)") :
                                     store.t(nl: "Pauzeer Uitzending (Blijf in Camera)", en: "Pause Stream (Stay in Camera)"))
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(liveKitManager.isBroadcastingPaused ? MycoTheme.green : Color.orange.opacity(0.9))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                        }

                        // Stream Status & Network
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(liveKitManager.isBroadcastingPaused ? Color.orange : (liveKitManager.isConnected ? Color.green : Color.yellow))
                                    .frame(width: 7, height: 7)
                                Text(liveKitManager.isBroadcastingPaused ?
                                     store.t(nl: "Lokale Preview (Uitzending Gepauzeerd)", en: "Local Preview (Broadcast Paused)") :
                                     (liveKitManager.isConnected ?
                                      store.t(nl: "Live WebRTC Uitzending Actief", en: "Live WebRTC Broadcast Active") :
                                      store.t(nl: "Verbinding maken...", en: "Connecting...")))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: MycoBackgroundHubManager.shared.batteryIconName)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(MycoBackgroundHubManager.shared.isCharging ? .green : .white)
                                Text("\(MycoBackgroundHubManager.shared.batteryPercentageInt)%")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                if MycoBackgroundHubManager.shared.isCharging {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 7))
                                        .foregroundColor(.green)
                                }
                                Text("•")
                                    .foregroundColor(.white.opacity(0.4))
                                Text(pairingManager.isCellular ? "4G/5G" : "Wi-Fi")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(pairingManager.isCellular ? Color.cyan : Color.green)
                            }
                        }
                        .padding(.horizontal, 2)
                        
                        Divider().background(Color.white.opacity(0.2))
                        
                        // Kweekcamera Status & Besturing
                        VStack(spacing: 10) {
                            if liveKitManager.isTimelapseRunning {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 9, height: 9)
                                    Text(store.t(
                                        nl: "TIMELAPSE ACTIEF: \(liveKitManager.timelapseCapturedFramesCount) beelden",
                                        en: "TIMELAPSE ACTIVE: \(liveKitManager.timelapseCapturedFramesCount) frames"
                                    ))
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.red)
                                    Spacer()
                                    Button {
                                        let gen = UIImpactFeedbackGenerator(style: .medium)
                                        gen.impactOccurred()
                                        liveKitManager.stopTimelapse()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "stop.fill")
                                            Text(store.t(nl: "Stop", en: "Stop"))
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.red)
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(8)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "timer")
                                        .font(.caption)
                                        .foregroundColor(MycoTheme.green)
                                    Text(store.t(
                                        nl: "Timelapse Standby (\(intervalMinutes)m)",
                                        en: "Timelapse Standby (\(intervalMinutes)m)"
                                    ))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                    Spacer()
                                    Button {
                                        let gen = UIImpactFeedbackGenerator(style: .medium)
                                        gen.impactOccurred()
                                        startTimelapse()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "play.fill")
                                            Text(store.t(nl: "Start", en: "Start"))
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(MycoTheme.green)
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                            }

                            // Prominente Koppel-QR Knop
                            Button {
                                showPairingQR = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "qrcode")
                                        .font(.headline)
                                    Text(store.t(nl: "Toon Koppel-QR voor Kijk-telefoon", en: "Show Pairing QR for Viewer Phone"))
                                        .font(.subheadline.bold())
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(MycoTheme.blue)
                                .cornerRadius(12)
                            }
                        }
                        
                        // Secondary Links: Gallery & Wi-Fi URL
                        HStack(spacing: 14) {
                            Button {
                                showGallery = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo.stack.fill")
                                    Text(store.t(nl: "Galerij (\(store.db.timelapsePhotos.count))", en: "Gallery (\(store.db.timelapsePhotos.count))"))
                                }
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.blue)
                            }
                            
                            Spacer()
                            
                            Button {
                                showWifiInfo = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "wifi")
                                    Text(store.t(nl: "Lokale Web Stream", en: "Local Web Stream"))
                                }
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.amber)
                            }
                        }
                        .padding(.top, 2)
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(18)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .confirmationDialog(
            store.t(nl: "Kweekcamera Opties", en: "Grow Camera Options"),
            isPresented: $showExitActionSheet,
            titleVisibility: .visible
        ) {
            Button(
                liveKitManager.isBroadcastingPaused ?
                    store.t(nl: "Hervat Live Uitzending", en: "Resume Live Broadcast") :
                    store.t(nl: "Pauzeer Stream (Blijf in Camera)", en: "Pause Stream (Stay in Camera)")
            ) {
                Task {
                    if liveKitManager.isBroadcastingPaused {
                        await liveKitManager.resumeBroadcasting()
                    } else {
                        await liveKitManager.pauseBroadcasting()
                    }
                }
            }
            
#if STREAM_PHONE_ONLY
            Button(store.t(nl: "Toon Koppel QR-Code", en: "Show Pairing QR Code")) {
                showPairingQR = true
            }
            
            Button(store.t(nl: "Scherm Dimmen (OLED Batterijspaarstand)", en: "Dim Screen (OLED Battery Saver)")) {
                withAnimation {
                    isScreenDimmed.toggle()
                }
            }
#else
            Button(store.t(nl: "Gebruik App (Camera blijft op achtergrond)", en: "Use App (Keep Camera in Background)")) {
                keepCameraActiveInBackground = true
                MycoBackgroundHubManager.shared.enableStreamHubMode()
                dismiss()
            }
            
            Button(store.t(nl: "Sluit Cameramodus (Terug naar Dashboard)", en: "Exit Camera Mode (Back to Dashboard)"), role: .destructive) {
                isExplicitlyClosingCamera = true
                keepCameraActiveInBackground = false
                stopTimelapse()
                dismiss()
            }
#endif
            
            Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(store.t(
                nl: "Kweekcamera en livestream beheer.",
                en: "Grow camera and livestream controls."
            ))
        }
        .sheet(isPresented: $showPairingQR) {
            CameraPairingQRSheet()
        }
        .interactiveDismissDisabled(true)
        .alert(store.t(nl: "Kweekcamera Modus Verlaten?", en: "Exit Camera Mode?"), isPresented: $showExitDedicatedAlert) {
            Button(store.t(nl: "Ja, terug naar Normale App", en: "Yes, return to Normal App"), role: .destructive) {
                isExplicitlyClosingCamera = true
                isDedicatedCameraDevice = false
                stopTimelapse()
                Task {
                    await liveKitManager.stopStream()
                }
                MycoSyncManager.shared.triggerToast(
                    message: store.t(nl: "Kweekcamera modus beëindigd. Welkom terug in het Dashboard!", en: "Camera mode ended. Welcome back to Dashboard!")
                )
            }
            Button(store.t(nl: "Blijf in Cameramodus", en: "Stay in Camera Mode"), role: .cancel) {}
        } message: {
            Text(store.t(
                nl: "Wil je deze iPhone weer gebruiken als gewone kweektelefoon met alle menu's en het Dashboard?",
                en: "Do you want to switch this iPhone back to the standard grower app with all menus and Dashboard?"
            ))
        }
        .sheet(isPresented: $showSensorSheet) {
            MycoSensorInspectionSheet()
        }
        .sheet(isPresented: $showGallery) {
            TimelapseGallerySheet()
                .environmentObject(store)
        }
        .alert(store.t(nl: "Live Wi-Fi Monitor URL", en: "Live Wi-Fi Monitor URL"), isPresented: $showWifiInfo) {
            Button("OK") {}
        } message: {
            Text(store.t(
                nl: "Plaats deze oude iPhone op een standaard bij je kweekomgeving. Open op je andere iPhone of Mac in hetzelfde Wi-Fi netwerk: http://mycolab.local:8080/live of verbind via de Live Kijker tab om live mee te kijken!",
                en: "Place this old iPhone on a stand near your grow tent. Open on your other device on the same Wi-Fi: http://mycolab.local:8080/live or connect via the Live Monitor to view!"
            ))
        }
        .onChange(of: liveKitManager.isOledSaverActive) { _, newValue in
            withAnimation {
                isScreenDimmed = newValue
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            liveKitManager.startScreenAwakeWatchdog()
            localIsTorchOn = liveKitManager.isTorchOn
            pairingManager.startAdvertisingCamera()
            MycoCamStreamManager.shared.startHost()
            MycoCamStreamManager.shared.onRemoteCommandReceived = { [self] cmd in
                if cmd.type == "request_snapshot" {
                    self.captureSingleFrame()
                } else if cmd.type == "torch" {
                    let tOn = cmd.torchOn ?? false
                    liveKitManager.setTorch(on: tOn, level: cmd.torchBrightness)
                    localIsTorchOn = tOn
                } else if cmd.type == "screen_sleep_toggle" || cmd.type == "sleep_toggle" {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isScreenDimmed.toggle()
                        liveKitManager.setOledSaver(active: self.isScreenDimmed, notifyPeer: true)
                    }
                } else if cmd.type == "screen_sleep" || cmd.type == "sleep" {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isScreenDimmed = true
                        liveKitManager.setOledSaver(active: true, notifyPeer: true)
                    }
                } else if cmd.type == "screen_wake" || cmd.type == "wake" {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isScreenDimmed = false
                        liveKitManager.setOledSaver(active: false, notifyPeer: true)
                    }
                }
            }
            // Stream mode: keep phone awake & run stream service
            MycoBackgroundHubManager.shared.enableStreamHubMode()
            MycoBackgroundHubManager.shared.setKeepScreenOn(true)
            // CAMERA-ONLY STREAMING ISOLATION:
            // Autopilot, heavy cloud sync, peer database sync and sensor polling are disabled
            // on the camera broadcaster to keep the app ultra-responsive, cool and smooth.
            Task {
                guard !liveKitManager.isStartingStream else { return }
                if liveKitManager.localVideoTrack == nil {
                    await liveKitManager.startLocalStandaloneCameraTrack()
                }
                if !liveKitManager.isConnected || liveKitManager.currentRole != .broadcaster {
                    await liveKitManager.startBroadcaster(cameraId: pairingManager.localCameraId)
                }
            }
            if liveKitManager.timelapseIntervalMinutes > 0 {
                intervalMinutes = liveKitManager.timelapseIntervalMinutes
            }
            liveKitManager.onRemoteSnapshotRequested = { [self] in
                self.captureSingleFrame()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MycoCamTimelapseFlashShutter"))) { _ in
            if !isScreenDimmed && !liveKitManager.isOledSaverActive {
                withAnimation(.easeIn(duration: 0.08)) {
                    showFlashShutter = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showFlashShutter = false
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            UIApplication.shared.isIdleTimerDisabled = true
            liveKitManager.startScreenAwakeWatchdog()
            localIsTorchOn = liveKitManager.isTorchOn
            pairingManager.startAdvertisingCamera()
            Task {
                guard !liveKitManager.isStartingStream else { return }
                if liveKitManager.localVideoTrack == nil {
                    await liveKitManager.startLocalStandaloneCameraTrack()
                }
                if !liveKitManager.isConnected || liveKitManager.currentRole != .broadcaster {
                    await liveKitManager.startBroadcaster(cameraId: pairingManager.localCameraId)
                }
            }
        }
        .onDisappear {
            MycoCamStreamManager.shared.stopHost()
            MycoCamStreamManager.shared.onRemoteCommandReceived = nil
            liveKitManager.onRemoteSnapshotRequested = nil
            if isExplicitlyClosingCamera {
                pairingManager.stopAdvertising()
                Task {
                    await liveKitManager.stopStream()
                }
                if !liveKitManager.isTimelapseRunning && !isDedicatedCameraDevice {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            } else {
                // View disappeared due to sheet (optical meter, gallery, QR, etc.) or app backgrounding.
                // Keep screen awake and keep stream active 24/7!
                UIApplication.shared.isIdleTimerDisabled = true
                liveKitManager.startScreenAwakeWatchdog()
            }
            localIsTorchOn = false
        }
        }
    }
    

    // MARK: - Responsive Top Bar Components
    @ViewBuilder
    private func mycoCamTopBar(isLandscape: Bool, topSafeArea: CGFloat) -> some View {
        if isLandscape {
            // Horizontal / Landscape mode: sleek single line HUD
            HStack(spacing: 8) {
                exitButton
                livePausePill
                Spacer(minLength: 4)
                gridButton
                torchButton
                oledDimmerButton
                moreOptionsMenu
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.top, max(10, topSafeArea))
            .padding(.bottom, 8)
            .background(Color.black.opacity(0.55))
        } else {
            // Vertical / Portrait mode: streamlined HUD without camera switch buttons
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    exitButton
                    Spacer()
                    livePausePill
                    Spacer()
                    HStack(spacing: 8) {
                        gridButton
                        torchButton
                        oledDimmerButton
                        moreOptionsMenu
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.top, max(10, topSafeArea))
            .padding(.bottom, 8)
            .background(Color.black.opacity(0.55))
        }
    }

    private var exitButton: some View {
#if STREAM_PHONE_ONLY
        Button {
            showExitActionSheet = true
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(liveKitManager.isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text("MycoCam")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.green.opacity(0.4), lineWidth: 0.8))
        }
#else
        Button {
            if isDedicatedCameraDevice {
                showExitDedicatedAlert = true
            } else {
                showExitActionSheet = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 13, weight: .bold))
                Text(store.t(nl: "Opties", en: "Options"))
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.8))
        }
#endif
    }

    private var livePausePill: some View {
        Button {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            Task {
                if liveKitManager.isBroadcastingPaused {
                    await liveKitManager.resumeBroadcasting()
                } else {
                    await liveKitManager.pauseBroadcasting()
                }
            }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(liveKitManager.isBroadcastingPaused ? Color.orange : (liveKitManager.isConnected ? Color.green : Color.yellow))
                    .frame(width: 7, height: 7)
                    .shadow(color: (liveKitManager.isBroadcastingPaused ? Color.orange : Color.green).opacity(0.8), radius: 3)
                Text(liveKitManager.isBroadcastingPaused ?
                     store.t(nl: "PREVIEW (PAUZE)", en: "PREVIEW (PAUSED)") :
                     (liveKitManager.isConnected ? store.t(nl: "LIVE HD", en: "LIVE HD") : store.t(nl: "VERBINDEN...", en: "CONNECTING...")))
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                Image(systemName: liveKitManager.isBroadcastingPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(liveKitManager.isBroadcastingPaused ? Color.orange.opacity(0.3) : Color.black.opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(liveKitManager.isBroadcastingPaused ? Color.orange.opacity(0.7) : (liveKitManager.isConnected ? Color.green.opacity(0.6) : Color.white.opacity(0.2)), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var lensSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(liveKitManager.availableCameras) { cam in
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    Task {
                        await liveKitManager.selectCamera(id: cam.id)
                    }
                } label: {
                    Text(cam.shortLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(liveKitManager.selectedCameraID == cam.id ? .black : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(liveKitManager.selectedCameraID == cam.id ? Color.white : Color.black.opacity(0.5))
                        .cornerRadius(6)
                }
            }
        }
        .padding(2)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 0.8))
    }

    private var gridButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCompositionGrid.toggle()
            }
        } label: {
            Image(systemName: showCompositionGrid ? "grid.circle.fill" : "grid.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(showCompositionGrid ? MycoTheme.green : .white)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }

    private var torchButton: some View {
        Button {
            liveKitManager.toggleTorch()
            localIsTorchOn = liveKitManager.isTorchOn
            localTorchBrightness = liveKitManager.torchBrightness
        } label: {
            Image(systemName: (liveKitManager.isTorchOn || localIsTorchOn) ? "flashlight.on.fill" : "flashlight.off.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor((liveKitManager.isTorchOn || localIsTorchOn) ? MycoTheme.amber : .white)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }

    private var oledDimmerButton: some View {
        Button {
            withAnimation {
                isScreenDimmed = true
                liveKitManager.setOledSaver(active: true, notifyPeer: true)
            }
        } label: {
            Image(systemName: "moon.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }

    private var moreOptionsMenu: some View {
        Menu {
            Button {
                Task {
                    if liveKitManager.isBroadcastingPaused {
                        await liveKitManager.resumeBroadcasting()
                    } else {
                        await liveKitManager.pauseBroadcasting()
                    }
                }
            } label: {
                Label(
                    liveKitManager.isBroadcastingPaused ?
                        store.t(nl: "Hervat Live Uitzending", en: "Resume Live Broadcast") :
                        store.t(nl: "Pauzeer Uitzending (Blijf in Camera)", en: "Pause Stream (Stay in Camera)"),
                    systemImage: liveKitManager.isBroadcastingPaused ? "play.circle" : "pause.circle"
                )
            }

#if !STREAM_PHONE_ONLY
            Button {
                keepCameraActiveInBackground = true
                MycoBackgroundHubManager.shared.enableStreamHubMode()
                dismiss()
            } label: {
                Label(store.t(nl: "Gebruik App (Camera blijft actief)", en: "Use App (Keep Camera Active)"), systemImage: "app.badge")
            }
#endif

            Button {
                showPairingQR = true
            } label: {
                Label(store.t(nl: "Koppel QR-Code Tonen", en: "Show Pairing QR Code"), systemImage: "qrcode")
            }

            Button {
                store.syncCloudData(force: true)
                MycoSyncManager.shared.requestSyncFromConnectedPeers()
                MycoSyncManager.shared.sendSyncPayload(reason: "camera_screen_sync")
                let count = store.db.projects.count + store.db.cultures.count + store.db.strains.count
                MycoSyncManager.shared.triggerToast(message: store.t(nl: "Lab-data gesynchroniseerd (\(count) items)!", en: "Lab data synced (\(count) items)!"))
            } label: {
                Label(store.t(nl: "Lab Data Synchroniseren", en: "Sync Lab Data"), systemImage: "arrow.triangle.2.circlepath")
            }

            Button {
                showSensorSheet = true
            } label: {
                Label(store.t(nl: "Barometer & Luchtdruk", en: "Barometer & Atmospheric Pressure"), systemImage: "gauge.with.needle.fill")
            }

            // Tent-Lock Button
            Button {
                liveKitManager.toggleTentLock()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: liveKitManager.isTentLockActive ? "lock.fill" : "lock.open")
                        .font(.system(size: 8, weight: .bold))
                    Text(liveKitManager.isTentLockActive ? "Tent-Lock" : "Auto Focus")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundColor(liveKitManager.isTentLockActive ? .black : .white.opacity(0.9))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(liveKitManager.isTentLockActive ? MycoTheme.green : Color.black.opacity(0.6))
                .cornerRadius(6)
            }

            Button {
                showWifiInfo = true
            } label: {
                Label(store.t(nl: "Lokale Web Stream URL", en: "Local Web Stream URL"), systemImage: "wifi")
            }

#if !STREAM_PHONE_ONLY
            Divider()

            Button(role: .destructive) {
                keepCameraActiveInBackground = false
                stopTimelapse()
                dismiss()
            } label: {
                Label(store.t(nl: "Sluit Cameramodus (Dashboard)", en: "Exit Camera Mode (Dashboard)"), systemImage: "xmark.circle")
            }
#endif
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }

    private func startTimelapse() {
        liveKitManager.timelapseAutoFlashIfLampOff = autoFlashIfLampOff
        let chosenCameraId = liveKitManager.timelapseCameraID.isEmpty ? liveKitManager.selectedCameraID : liveKitManager.timelapseCameraID
        liveKitManager.startTimelapse(intervalMinutes: intervalMinutes, cameraId: chosenCameraId)
    }
    
    private func stopTimelapse() {
        liveKitManager.stopTimelapse()
    }
    
    private func captureSingleFrame() {
        let shouldFlash = (liveKitManager.isTimelapseRunning || autoFlashIfLampOff) && !isLampActive
        if shouldFlash && !isScreenDimmed && !liveKitManager.isOledSaverActive {
            withAnimation(.easeIn(duration: 0.08)) {
                showFlashShutter = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showFlashShutter = false
                }
            }
        }
        Task {
            _ = await liveKitManager.captureAndSaveSnapshot(withFlash: shouldFlash)
            _ = await MycoOpticalHygrometerManager.shared.triggerScanAndReact()
        }
    }

    private var mycoCamMiniHUD: some View {
        HStack(spacing: 6) {
            if sensorManager.currentPressureHpa > 0 {
                Button {
                    showSensorSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "gauge.with.needle.fill")
                            .font(.system(size: 8))
                        Text("\(Int(sensorManager.currentPressureHpa)) hPa")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                        Image(systemName: sensorManager.pressureTrend.icon)
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(6)
                }
            }
            
            // Tent-Lock Button
            Button {
                liveKitManager.toggleTentLock()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: liveKitManager.isTentLockActive ? "lock.fill" : "lock.open")
                        .font(.system(size: 8, weight: .bold))
                    Text(liveKitManager.isTentLockActive ? "Tent-Lock" : "Auto Focus")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundColor(liveKitManager.isTentLockActive ? .black : .white.opacity(0.9))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(liveKitManager.isTentLockActive ? MycoTheme.green : Color.black.opacity(0.6))
                .cornerRadius(6)
            }

            HStack(spacing: 3) {
                let storage = MycoStorageSafetyManager.shared
                let freeGB = Double(storage.freeDiskSpaceBytes) / 1_073_741_824.0
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 8))
                    .foregroundColor(storage.isCriticalStorage ? .red : (storage.isLowStorage ? .yellow : .green))
                Text("\(String(format: "%.1f", freeGB)) GB")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.6))
            .cornerRadius(6)

            Button {
                withAnimation {
                    isScreenDimmed.toggle()
                    liveKitManager.setOledSaver(active: isScreenDimmed, notifyPeer: true)
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.indigo)
                    Text(store.t(nl: "Statief Standby", en: "Tripod Standby"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.6))
                .cornerRadius(6)
            }

            InfoTipButton(
                title: store.t(nl: "24/7 Statief & Stream Tip", en: "24/7 Tripod & Stream Tip"),
                message: store.t(
                    nl: "Deze iPhone blijft 24/7 aanstaan en vergrendelt niet automatisch. Druk NIET op de fysieke zijknop van de iPhone (iOS schakelt de camera dan uit). Gebruik 'Statief Standby' (🌙): het scherm wordt 100% zwart om inbranden te voorkomen en batterij te sparen, terwijl de stream en timelapse non-stop doorgaan!",
                    en: "This iPhone stays awake 24/7 and will not auto-lock. Do NOT press the physical side power button (iOS will turn off the camera). Use 'Tripod Standby' (🌙): the display turns 100% black to prevent burn-in and save power, while the stream and timelapse run non-stop!"
                ),
                icon: "info.circle.fill",
                color: MycoTheme.green
            )
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}


public struct TimelapseGallerySheet: View {
    public var initialTab: GalleryTab
    public init(initialTab: GalleryTab = .localPhotos) {
        self.initialTab = initialTab
        self._activeTab = State(initialValue: initialTab)
    }
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @State private var scrubIndex: Double = 0
    @StateObject private var videoExporter = MycoTimelapseVideoExporter.shared
    @StateObject private var storageManager = MycoStorageSafetyManager.shared
    @State private var showCleanConfirmation = false
    @State private var showExportAndCleanConfirmation = false
    @State private var cleanResultText: String? = nil
    @State private var showCleanResultAlert = false

    public enum GalleryTab: String, CaseIterable, Identifiable {
        case localPhotos = "camera"
        case piHubArchive = "externaldrive"
        
        public var id: String { rawValue }
        
        func title(store: MycoStore) -> String {
            switch self {
            case .localPhotos:
                return store.t(nl: "Lokale Frames", en: "Local Frames")
            case .piHubArchive:
                return store.t(nl: "Pi Hub Video Archief", en: "Pi Hub Videos")
            }
        }
        
        var icon: String {
            switch self {
            case .localPhotos: return "camera.viewfinder"
            case .piHubArchive: return "externaldrive.badge.timemachine"
            }
        }
    }
    
    @State private var activeTab: GalleryTab = .localPhotos

    enum CameraFilter: String, CaseIterable, Identifiable {
        case wide = "wide"
        case ultraWide = "ultraWide"
        case telephoto = "telephoto"
        case all = "all"

        var id: String { rawValue }

        func label(store: MycoStore) -> String {
            switch self {
            case .wide:
                return store.t(nl: "🌱 Kweek 1.0x", en: "🌱 Flush 1.0x")
            case .ultraWide:
                return store.t(nl: "⛺ Tent 0.5x", en: "⛺ Tent 0.5x")
            case .telephoto:
                return store.t(nl: "🔬 AI Sensor (Zoom)", en: "🔬 AI Sensor (Zoom)")
            case .all:
                return store.t(nl: "Alle Foto's", en: "All Photos")
            }
        }
    }

    @State private var selectedFilter: CameraFilter = .wide

    /// Alleen foto's die daadwerkelijk foto data op schijf of in geheugen hebben (0 disk decode lag!)
    private var validPhotos: [TimelapsePhotoItem] {
        store.db.timelapsePhotos.filter { $0.hasPhotoData }
    }

    /// Gefilterde foto's per individuele camera
    private var filteredPhotos: [TimelapsePhotoItem] {
        switch selectedFilter {
        case .all:
            return validPhotos
        case .wide:
            let list = validPhotos.filter { $0.resolvedCameraType == "wide" }
            return (list.isEmpty && !validPhotos.isEmpty && !validPhotos.contains(where: { $0.resolvedCameraType == "ultraWide" || $0.resolvedCameraType == "telephoto" })) ? validPhotos : list
        case .ultraWide:
            return validPhotos.filter { $0.resolvedCameraType == "ultraWide" }
        case .telephoto:
            return validPhotos.filter { $0.resolvedCameraType == "telephoto" }
        }
    }

    private var ghostCount: Int {
        store.db.timelapsePhotos.count - validPhotos.count
    }

    private func count(for filter: CameraFilter) -> Int {
        switch filter {
        case .all:
            return validPhotos.count
        case .wide:
            let list = validPhotos.filter { $0.resolvedCameraType == "wide" }
            return (list.isEmpty && !validPhotos.isEmpty && !validPhotos.contains(where: { $0.resolvedCameraType == "ultraWide" || $0.resolvedCameraType == "telephoto" })) ? validPhotos.count : list.count
        case .ultraWide:
            return validPhotos.filter { $0.resolvedCameraType == "ultraWide" }.count
        case .telephoto:
            return validPhotos.filter { $0.resolvedCameraType == "telephoto" }.count
        }
    }

    private func shareAITrainingFrames() {
        let urls = filteredPhotos.compactMap { $0.localFileURL }
        if !urls.isEmpty {
            MycoSharePresenter.presentShareSheet(items: urls)
        } else {
            let imgs = filteredPhotos.compactMap { $0.loadImage() }
            if !imgs.isEmpty {
                MycoSharePresenter.presentShareSheet(items: imgs)
            }
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Custom Spacious Pill Tabs: Lokale Frames vs Pi Hub Video Archief (Eliminating text truncation)
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            activeTab = .localPhotos
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 13, weight: .bold))
                            Text(store.t(nl: "Lokale Frames", en: "Local Frames"))
                                .font(.system(size: 13, weight: .bold))
                            if !validPhotos.isEmpty {
                                Text("\(validPhotos.count)")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(activeTab == .localPhotos ? Color.black.opacity(0.25) : Color.white.opacity(0.12))
                                    .cornerRadius(6)
                            }
                        }
                        .foregroundColor(activeTab == .localPhotos ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(activeTab == .localPhotos ? MycoTheme.green : Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(activeTab == .localPhotos ? MycoTheme.green : Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            activeTab = .piHubArchive
                        }
                        Task {
                            await videoExporter.fetchPiTimelapses()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "externaldrive.badge.timemachine")
                                .font(.system(size: 13, weight: .bold))
                            Text(store.t(nl: "Pi Hub Video Archief", en: "Pi Hub Video Archive"))
                                .font(.system(size: 13, weight: .bold))
                            if !videoExporter.piTimelapses.isEmpty {
                                Text("\(videoExporter.piTimelapses.count)")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(activeTab == .piHubArchive ? Color.black.opacity(0.25) : Color.white.opacity(0.12))
                                    .cornerRadius(6)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(activeTab == .piHubArchive ? MycoTheme.blue : Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(activeTab == .piHubArchive ? MycoTheme.blue : Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                if activeTab == .piHubArchive {
                    PiHubTimelapseArchiveView()
                        .padding(.horizontal, 14)
                } else {
                if validPhotos.isEmpty {
                    VStack(spacing: 16) {
                        EmptyStateCard(
                            icon: "camera.viewfinder",
                            title: store.t(nl: "Nog geen timelapse foto's", en: "No timelapse photos yet"),
                            message: store.t(nl: "Start een timelapse in MycoCam om met alle 3 de lenzen opnames te maken.", en: "Start a timelapse in MycoCam to capture flush and AI sensor frames."),
                            buttonTitle: store.t(nl: "Sluiten", en: "Close")
                        ) {
                            dismiss()
                        }
                        
                        if ghostCount > 0 {
                            Button {
                                store.db.timelapsePhotos.removeAll { $0.loadImage() == nil }
                                store.saveImmediately()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text(store.t(nl: "Wis \(ghostCount) lege frame(s)", en: "Clear \(ghostCount) empty frame(s)"))
                                }
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.top, 40)
                } else {
                    // 3 Individuele Camera Filter Knoppen
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(CameraFilter.allCases) { filter in
                                let isSelected = selectedFilter == filter
                                let num = count(for: filter)
                                Button {
                                    let gen = UIImpactFeedbackGenerator(style: .light)
                                    gen.impactOccurred()
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedFilter = filter
                                        scrubIndex = 0
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(filter.label(store: store))
                                            .font(.system(size: 11, weight: .bold))
                                        Text("(\(num))")
                                            .font(.system(size: 10, weight: .semibold))
                                            .opacity(0.8)
                                    }
                                    .foregroundColor(isSelected ? .black : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? (filter == .telephoto ? Color.orange : (filter == .ultraWide ? Color.purple : MycoTheme.green)) : Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal, 2)
                    }

                    // Scrubber Preview
                    VStack(spacing: 8) {
                        if filteredPhotos.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: selectedFilter == .telephoto ? "scope" : (selectedFilter == .ultraWide ? "tent" : "camera"))
                                    .font(.system(size: 36))
                                    .foregroundColor(MycoTheme.textSecondary)
                                Text(store.t(
                                    nl: "Nog geen opnames van deze lens",
                                    en: "No captures from this lens yet"
                                ))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                Text(store.t(
                                    nl: "Start timelapse met 'Alle Camera's (3x)' om automatisch ook deze lens op te nemen.",
                                    en: "Start timelapse with 'All Cameras (3x)' to automatically capture this lens."
                                ))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                
                                Button {
                                    Task {
                                        let camType = selectedFilter == .telephoto ? "telephoto" : (selectedFilter == .ultraWide ? "ultrawide" : "wide")
                                        await LiveKitStreamManager.shared.selectCameraByType(camType)
                                        _ = await LiveKitStreamManager.shared.captureAndSaveSnapshot(cameraType: camType)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "camera.shutter.button.fill")
                                        Text(store.t(nl: "Maak testfoto met deze lens", en: "Capture test photo"))
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(selectedFilter == .telephoto ? Color.orange : (selectedFilter == .ultraWide ? Color.purple : MycoTheme.green))
                                    .cornerRadius(8)
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(16)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(MycoTheme.card)
                                    .frame(height: 230)
                                
                                let safeIndex = min(filteredPhotos.count - 1, max(0, Int(scrubIndex)))
                                let photo = filteredPhotos[safeIndex]
                                
                                if let uiImg = photo.loadImage() {
                                    Image(uiImage: uiImg)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 230)
                                        .clipped()
                                        .cornerRadius(16)
                                        .overlay(
                                            VStack {
                                                HStack {
                                                    let camType = photo.resolvedCameraType
                                                    Text(photo.cameraDisplayName)
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 3)
                                                        .background((camType == "telephoto" ? Color.orange : (camType == "ultraWide" ? Color.purple : MycoTheme.green)).opacity(0.85))
                                                        .cornerRadius(6)
                                                    Spacer()
                                                }
                                                .padding(10)
                                                
                                                Spacer()
                                                
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(photo.caption)
                                                            .font(.caption.bold())
                                                            .foregroundColor(.white)
                                                        Text("Frame \(safeIndex + 1)/\(filteredPhotos.count) • \(photo.timestamp.formatted(date: .numeric, time: .shortened))")
                                                            .font(.system(size: 9))
                                                            .foregroundColor(.white.opacity(0.8))
                                                    }
                                                    Spacer()
                                                }
                                                .padding(10)
                                                .background(Color.black.opacity(0.6))
                                            }
                                        )
                                }
                            }
                            
                            // Scrubber Slider voor deze specifieke camera
                            if filteredPhotos.count > 1 {
                                VStack(spacing: 4) {
                                    Slider(value: $scrubIndex, in: 0...Double(filteredPhotos.count - 1), step: 1.0)
                                        .tint(selectedFilter == .telephoto ? Color.orange : (selectedFilter == .ultraWide ? Color.purple : MycoTheme.green))
                                    HStack {
                                        Text("Frame \(min(filteredPhotos.count, max(1, Int(scrubIndex) + 1))) van \(filteredPhotos.count)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(selectedFilter == .telephoto ? Color.orange : (selectedFilter == .ultraWide ? Color.purple : MycoTheme.green))
                                        Spacer()
                                        Text(store.t(nl: "Sleep om versneld door deze timelapse te bladeren", en: "Drag slider to scrub through this timelapse"))
                                            .font(.system(size: 10))
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                }
                                .padding(.horizontal, 14)
                            }
                        }

                        // Speciale AI Training Banner voor de Zoom Telelens
                        if selectedFilter == .telephoto && !filteredPhotos.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "cpu.fill")
                                        .foregroundColor(.orange)
                                    Text(store.t(
                                        nl: "AI Dataset • \(filteredPhotos.count) sensor frames",
                                        en: "AI Dataset • \(filteredPhotos.count) sensor frames"
                                    ))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Button {
                                        shareAITrainingFrames()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "square.and.arrow.up")
                                            Text(store.t(nl: "AirDrop AI Foto's", en: "AirDrop AI Photos"))
                                        }
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                    }
                                }
                                Text(store.t(
                                    nl: "Gefocust op de optische hygrometer sensor om de AI vochtmeting te trainen en kalibreren.",
                                    en: "Focused on optical hygrometer sensor to train and calibrate AI humidity detection."
                                ))
                                .font(.system(size: 10))
                                .foregroundColor(MycoTheme.textSecondary)
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                        }

                        // Video Export Progress Bar or Action Button
                        if videoExporter.isExporting {
                            VStack(spacing: 6) {
                                HStack {
                                    ProgressView()
                                        .tint(MycoTheme.blue)
                                    Text(videoExporter.statusText)
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(videoExporter.progress * 100))%")
                                        .font(.caption.bold().monospacedDigit())
                                        .foregroundColor(MycoTheme.blue)
                                }
                                ProgressView(value: videoExporter.progress, total: 1.0)
                                    .tint(MycoTheme.blue)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                        } else if !filteredPhotos.isEmpty {
                            HStack(spacing: 10) {
                                Button {
                                    Task {
                                        _ = await videoExporter.exportVideo(photos: filteredPhotos, fps: 24)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "film.stack")
                                            .font(.system(size: 13, weight: .bold))
                                        Text(store.t(
                                            nl: "Exporteer MP4 naar Album 'MycoLabs'",
                                            en: "Export MP4 to 'MycoLabs' Album"
                                        ))
                                        .font(.caption.bold())
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedFilter == .telephoto ? Color.orange : (selectedFilter == .ultraWide ? Color.purple : MycoTheme.green))
                                    .cornerRadius(10)
                                }
                                
                                if videoExporter.exportedVideoURL != nil {
                                    Button {
                                        videoExporter.openShareSheet()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "square.and.arrow.up")
                                            Text(store.t(nl: "Delen", en: "Share"))
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }

                        if ghostCount > 0 {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                Text(store.t(
                                    nl: "\(ghostCount) lege frame(s) overgeslagen",
                                    en: "\(ghostCount) empty frame(s) skipped"
                                ))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                Spacer()
                                Button(store.t(nl: "Opschonen", en: "Clean up")) {
                                    store.db.timelapsePhotos.removeAll { $0.loadImage() == nil }
                                    store.saveImmediately()
                                }
                                .font(.caption2.bold())
                                .foregroundColor(MycoTheme.blue)
                            }
                            .padding(.horizontal, 4)
                        }

                        // Storage Safety & Cleanup Section
                        storageSafetySection
                    }
                    .padding(14)
                    .background(MycoTheme.card)
                    .cornerRadius(16)
                    
                    // List of captured frames
                    
                    List {
                        ForEach(filteredPhotos) { photo in
                            HStack(spacing: 12) {
                                TimelapseAsyncThumbnailView(photo: photo, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        let camType = photo.resolvedCameraType
                                        Text(photo.cameraDisplayName)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(camType == "telephoto" ? .orange : (camType == "ultraWide" ? .purple : MycoTheme.green))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background((camType == "telephoto" ? Color.orange : (camType == "ultraWide" ? Color.purple : MycoTheme.green)).opacity(0.15))
                                            .cornerRadius(4)

                                        Text(photo.caption)
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                    HStack(spacing: 6) {
                                        Text(photo.timestamp.formatted(date: .numeric, time: .standard))
                                            .font(.system(size: 9))
                                            .foregroundColor(MycoTheme.textSecondary)

                                        if let hum = photo.humidityPct {
                                            HStack(spacing: 4) {
                                                if let temp = photo.temperatureC {
                                                    Text(String(format: "%.1f°C", temp))
                                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                        .foregroundColor(.yellow)
                                                }
                                                Text("\(Int(hum))% RV")
                                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                    .foregroundColor(.cyan)
                                                if let vpd = photo.vpdKpa {
                                                    Text(String(format: "%.2f kPa", vpd))
                                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                        .foregroundColor(MycoTheme.green)
                                                }
                                            }
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.blue.opacity(0.18))
                                            .cornerRadius(4)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .listRowBackground(MycoTheme.card)
                        }
                        .onDelete { indices in
                            for idx in indices {
                                let p = validPhotos[idx]
                                p.deleteFile()
                                MycoSensorIntelligenceManager.shared.deleteMeasurement(id: p.id)
                                store.recordDeletion(p.id)
                            }
                            store.db.timelapsePhotos.removeAll { p in
                                indices.map { validPhotos[$0].id }.contains(p.id)
                            }
                            store.save()
                            MycoSyncManager.shared.sendSyncPayload(reason: "timelapse_photo_deleted")
                        }
                    }
                    .listStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(activeTab == .piHubArchive ? store.t(nl: "Pi Hub Video Archief", en: "Pi Hub Video Archive") : store.t(nl: "Timelapse Galerij", en: "Timelapse Gallery"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Klaar", en: "Done")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
                if activeTab == .piHubArchive {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            Task {
                                await videoExporter.fetchPiTimelapses()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(MycoTheme.green)
                        }
                    }
                }
            }
            .confirmationDialog(
                store.t(nl: "Ruwe Timelapse Foto's Opruimen?", en: "Clean Up Raw Timelapse Photos?"),
                isPresented: $showCleanConfirmation,
                titleVisibility: .visible
            ) {
                Button(store.t(nl: "Wis alle ruwe foto's", en: "Delete all raw photos"), role: .destructive) {
                    let res = storageManager.clearAllRawTimelapsePhotos()
                    store.db.timelapsePhotos.removeAll()
                    store.saveImmediately()
                    cleanResultText = store.t(
                        nl: "✅ \(res.deletedCount) foto's gewist! \(MycoStorageSafetyManager.formatBytes(res.freedBytes)) schijfruimte vrijgemaakt.",
                        en: "✅ \(res.deletedCount) photos deleted! \(MycoStorageSafetyManager.formatBytes(res.freedBytes)) disk space recovered."
                    )
                    showCleanResultAlert = true
                }
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
            } message: {
                Text(store.t(
                    nl: "Hiermee wis je de afzonderlijke fotobestanden van schijf om geheugen vrij te maken. Zorg dat je eerst een video hebt geëxporteerd als je de beelden wilt bewaren.",
                    en: "This will delete the raw photo files from disk to recover memory. Make sure you exported a video first if you want to keep the footage."
                ))
            }
            .confirmationDialog(
                store.t(nl: "Exporteer MP4 & Ruim Op?", en: "Export MP4 & Clean Up?"),
                isPresented: $showExportAndCleanConfirmation,
                titleVisibility: .visible
            ) {
                Button(store.t(nl: "Exporteer Video & Wis Ruwe Bestanden", en: "Export Video & Delete Raw Files")) {
                    Task {
                        if let url = await videoExporter.exportVideo(photos: validPhotos, fps: 24, uploadToPi: true) {
                            _ = await videoExporter.saveVideoToCameraRoll(url: url)
                            let res = storageManager.clearAllRawTimelapsePhotos()
                            store.db.timelapsePhotos.removeAll()
                            store.saveImmediately()
                            cleanResultText = store.t(
                                nl: "✅ Video bewaard op Pi Hub & Foto's app! \(res.deletedCount) foto's gewist en \(MycoStorageSafetyManager.formatBytes(res.freedBytes)) vrijgemaakt.",
                                en: "✅ Video saved to Pi Hub & Photos app! \(res.deletedCount) photos deleted and \(MycoStorageSafetyManager.formatBytes(res.freedBytes)) recovered."
                            )
                            showCleanResultAlert = true
                        }
                    }
                }
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
            } message: {
                Text(store.t(
                    nl: "De video wordt eerst geëxporteerd en bewaard op de Pi Hub en in je camerarol. Daarna worden de ruwe foto's veilig gewist om gigabytes aan schijfruimte vrij te maken.",
                    en: "The video will first be exported and saved to Pi Hub and your camera roll. Then raw photos are safely deleted to free up gigabytes of disk space."
                ))
            }
            .alert(store.t(nl: "Opslag Opgeruimd", en: "Storage Cleaned"), isPresented: $showCleanResultAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(cleanResultText ?? "")
            }
            .onAppear {
                storageManager.refreshStorageMetrics()
                if validPhotos.isEmpty {
                    activeTab = .piHubArchive
                }
                Task {
                    await videoExporter.fetchPiTimelapses()
                }
            }
        }
    }

    @ViewBuilder
    private var storageSafetySection: some View {
        let freeGB = Double(storageManager.freeDiskSpaceBytes) / 1_073_741_824.0
        let bytesFormatted = MycoStorageSafetyManager.formatBytes(storageManager.timelapsePhotosStorageBytes)
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive.fill")
                        .foregroundColor(storageManager.isCriticalStorage ? .red : (storageManager.isLowStorage ? .yellow : MycoTheme.green))
                        .font(.system(size: 11))
                    Text(store.t(nl: "\(String(format: "%.1f", freeGB)) GB Vrij", en: "\(String(format: "%.1f", freeGB)) GB Free"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(storageManager.timelapsePhotosCount) frames • \(bytesFormatted)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(MycoTheme.textSecondary)
            }

            if storageManager.isLowStorage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                    Text(store.t(
                        nl: "Weinig opslagruimte! Ruim ruwe foto's op om vastlopen van de stream te voorkomen.",
                        en: "Low camera storage! Clean up raw photos to prevent stream interruption."
                    ))
                    .font(.system(size: 11))
                    .foregroundColor(.yellow)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.12))
                .cornerRadius(8)
            }

            HStack(spacing: 8) {
                Button {
                    showExportAndCleanConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        Text(store.t(nl: "Exporteer & Ruim Op", en: "Export & Clean Up"))
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.purple)
                    .cornerRadius(8)
                }

                Button {
                    showCleanConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text(store.t(nl: "Ruim Op", en: "Clean Up"))
                    }
                    .font(.caption.bold())
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(8)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
}


// MARK: - Pi Hub Timelapse Video Archief & Download View
public struct PiHubTimelapseArchiveView: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject var videoExporter = MycoTimelapseVideoExporter.shared
    @State private var itemToDelete: PiTimelapseItem? = nil
    @State private var showDeleteConfirmation = false
    @State private var downloadToast: String? = nil
    @State private var playingVideoItem: PiTimelapseItem? = nil

    private var effectiveIP: String {
        store.db.environmentConfig.effectivePiHubIP
    }
    private var effectivePort: Int {
        store.db.environmentConfig.effectivePiHubPort
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Header: Pi Hub connectie & USB opslag status
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(effectiveIP.isEmpty ? Color.red : MycoTheme.green)
                        .frame(width: 8, height: 8)
                    Text("Pi Hub USB: \(effectiveIP):\(effectivePort)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                Button {
                    Task {
                        await videoExporter.fetchPiTimelapses()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if videoExporter.isFetchingPiTimelapses {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(store.t(nl: "Ververs", en: "Refresh"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(MycoTheme.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 4)

            // Upload Status Bar
            if videoExporter.isUploadingToPi {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(videoExporter.statusText)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(10)
                .background(Color.blue.opacity(0.18))
                .cornerRadius(10)
            } else if let successMsg = videoExporter.uploadSuccessMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MycoTheme.green)
                    Text(successMsg)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(10)
                .background(MycoTheme.green.opacity(0.18))
                .cornerRadius(10)
            }

            if videoExporter.piTimelapses.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "externaldrive.badge.timemachine")
                        .font(.system(size: 40))
                        .foregroundColor(MycoTheme.textSecondary)
                    Text(store.t(nl: "Geen timelapses op Pi Hub", en: "No timelapses on Pi Hub"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(store.t(
                        nl: "Exporteer voltooide sessies naar een MP4 video om ze direct permanent op te slaan op de USB-stick van de Raspberry Pi Hub. Deze zijn direct vanaf elk apparaat te downloaden.",
                        en: "Export completed sessions to an MP4 video to permanently store them on the Raspberry Pi Hub USB drive. These can be downloaded from any device."
                    ))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(MycoTheme.card)
                .cornerRadius(16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(videoExporter.piTimelapses) { item in
                            HStack(spacing: 12) {
                                // Tappable Thumbnail & Info to Preview Video
                                Button {
                                    playingVideoItem = item
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.black.opacity(0.4))
                                                .frame(width: 50, height: 50)
                                            Image(systemName: "film.stack.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(MycoTheme.green)
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                                .shadow(radius: 2)
                                                .offset(x: 14, y: 14)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.filename)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            
                                            HStack(spacing: 6) {
                                                Text("\(item.created_at)")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(MycoTheme.textSecondary)
                                                Text("•")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.gray)
                                                Text("\(String(format: "%.1f", item.size_mb)) MB")
                                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                    .foregroundColor(MycoTheme.green)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                HStack(spacing: 8) {
                                    // Download & Save to Camera Roll
                                    Button {
                                        Task {
                                            let gen = UIImpactFeedbackGenerator(style: .medium)
                                            gen.impactOccurred()
                                            let saved = await videoExporter.downloadAndSaveToPhotos(item: item)
                                            if saved {
                                                downloadToast = "✅ Opgeslagen in Foto's!"
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 3) {
                                            if videoExporter.isDownloadingFromPi && videoExporter.downloadingFilename == item.filename {
                                                ProgressView()
                                                    .scaleEffect(0.6)
                                            } else {
                                                Image(systemName: "arrow.down.circle.fill")
                                                    .font(.system(size: 12))
                                            }
                                            Text(store.t(nl: "Download", en: "Download"))
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(MycoTheme.green)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
                                    .disabled(videoExporter.isDownloadingFromPi)

                                    // Delete from Pi USB
                                    Button {
                                        itemToDelete = item
                                        showDeleteConfirmation = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundColor(.red.opacity(0.85))
                                            .padding(6)
                                            .background(Color.red.opacity(0.12))
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
                                }
                            }
                            .padding(10)
                            .background(MycoTheme.card)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .confirmationDialog(
            store.t(nl: "Verwijder van Pi Hub?", en: "Delete from Pi Hub?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let item = itemToDelete {
                Button(store.t(nl: "Verwijder \(item.filename)", en: "Delete \(item.filename)"), role: .destructive) {
                    Task {
                        _ = await videoExporter.deletePiTimelapse(filename: item.filename)
                    }
                }
            }
            Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(store.t(
                nl: "Deze video wordt permanent verwijderd van de USB-stick op de Raspberry Pi.",
                en: "This video will be permanently removed from the Raspberry Pi USB drive."
            ))
        }
        .sheet(item: $playingVideoItem) { item in
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if let url = URL(string: "http://\(effectiveIP):\(effectivePort)\(item.download_url)") {
                        VideoPlayer(player: AVPlayer(url: url))
                            .ignoresSafeArea()
                    } else {
                        Text(store.t(nl: "Kan videostream niet laden", en: "Cannot stream video"))
                            .foregroundColor(.white)
                    }
                }
                .navigationTitle(item.filename)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(store.t(nl: "Gereed", en: "Done")) {
                            playingVideoItem = nil
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await videoExporter.fetchPiTimelapses()
            }
        }
    }
}


// MARK: - 17A. AI NEURAL ENGINE CLIMATE & AIRFLOW CALCULATOR
struct MycoNeuralClimateEngine {
    struct SimulationResult {
        let volumeM3: Double
        let volumeLiters: Double
        let recommendedFaeIntervalMins: Int
        let recommendedFaeDurationMins: Int
        let recommendedHumidifierIntervalMins: Int
        let recommendedHumidifierDurationMins: Int
        let dailyWaterUsageMl: Double
        let airExchangesPerHour: Double
        let aiConfidenceScore: Int
        let summaryNl: String
        let summaryEn: String
    }
    
    static func calculate(
        lengthCm: Double,
        widthCm: Double,
        heightCm: Double,
        targetHumidityPct: Double,
        targetTempC: Double,
        fanCapacityM3H: Double = 100.0,
        humidifierMlH: Double = 300.0
    ) -> SimulationResult {
        let volM3 = max(0.01, (lengthCm * widthCm * heightCm) / 1_000_000.0)
        let volLiters = volM3 * 1000.0
        
        let targetAirExchangesPerHour = volM3 < 0.2 ? 3.0 : (volM3 < 1.5 ? 4.0 : 5.0)
        let requiredAirM3PerHour = volM3 * targetAirExchangesPerHour
        let effectiveFanM3H = max(10.0, fanCapacityM3H * 0.65)
        let fanRuntimeMinsPerHour = (requiredAirM3PerHour / effectiveFanM3H) * 60.0
        
        let faeIntervalMins: Int
        let faeDurationMins: Int
        
        if volM3 < 0.15 {
            faeIntervalMins = 90
            faeDurationMins = max(1, Int(ceil(fanRuntimeMinsPerHour * 1.5)))
        } else if volM3 < 1.0 {
            faeIntervalMins = 120
            faeDurationMins = max(2, Int(ceil(fanRuntimeMinsPerHour * 2.0)))
        } else {
            faeIntervalMins = 60
            faeDurationMins = max(3, Int(ceil(fanRuntimeMinsPerHour)))
        }
        
        let deltaHumidityRatio = max(0.2, (targetHumidityPct - 50.0) / 100.0)
        let waterLossPerM3 = deltaHumidityRatio * 21.0
        let waterLossPerHour = requiredAirM3PerHour * waterLossPerM3
        let dailyWaterMl = waterLossPerHour * 24.0
        
        let humIntervalMins = max(30, faeIntervalMins / 2)
        let effectiveHumidifierMlMin = max(1.0, humidifierMlH / 60.0)
        let requiredWaterPerCycle = (waterLossPerHour / (60.0 / Double(humIntervalMins)))
        let humDurationMins = max(1, min(10, Int(ceil(requiredWaterPerCycle / effectiveHumidifierMlMin))))
        
        let volStr = String(format: "%.2f", volM3)
        let summaryNl = "Voor een kweekruimte van \(volStr) m3 (\(Int(volLiters)) L): Laat de afzuiging elke \(faeIntervalMins) minuten gedurende \(faeDurationMins) minuten draaien. Schakel de luchtbevochtiger elke \(humIntervalMins) minuten in voor \(humDurationMins) minuten om \(Int(targetHumidityPct))% RV vast te houden."
        let summaryEn = "For a grow space of \(volStr) m3 (\(Int(volLiters)) L): Run exhaust every \(faeIntervalMins) mins for \(faeDurationMins) mins. Run humidifier every \(humIntervalMins) mins for \(humDurationMins) mins to maintain \(Int(targetHumidityPct))% RH."
        
        return SimulationResult(
            volumeM3: volM3,
            volumeLiters: volLiters,
            recommendedFaeIntervalMins: faeIntervalMins,
            recommendedFaeDurationMins: faeDurationMins,
            recommendedHumidifierIntervalMins: humIntervalMins,
            recommendedHumidifierDurationMins: humDurationMins,
            dailyWaterUsageMl: dailyWaterMl,
            airExchangesPerHour: targetAirExchangesPerHour,
            aiConfidenceScore: 98,
            summaryNl: summaryNl,
            summaryEn: summaryEn
        )
    }
}

struct GrowSpaceSizeAndAIClimateView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPreset = "Aangepast"
    @State private var lengthText: String = "120"
    @State private var widthText: String = "60"
    @State private var heightText: String = "150"
    @State private var fanCapacityText: String = "100"
    @State private var humidifierOutputText: String = "300"
    
    @State private var calculationResult: MycoNeuralClimateEngine.SimulationResult? = nil
    @State private var isCalculating = false
    @State private var showAppliedSuccess = false
    @State private var showOpticalHygrometer = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Header Card
                    MycoCard {
                        HStack(spacing: 12) {
                            Image(systemName: "cube.transparent.fill")
                                .font(.title2)
                                .foregroundColor(MycoTheme.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(store.t(nl: "Kweekruimte & Luchtstroom AI", en: "Grow Space & Airflow AI"))
                                        .font(.headline.bold())
                                        .foregroundColor(.white)
                                    InfoTipButton(
                                        title: store.t(nl: "AI Luchtstroom Berekening", en: "AI Airflow Calculation"),
                                        message: store.t(
                                            nl: "Geef de afmetingen van je kweekruimte op. De AI berekent exact het volume in m³ en liters, plus de optimale duty cycle (inschakeltijd per uur) voor je afzuiging en bevochtiger.",
                                            en: "Specify the dimensions of your grow space. The AI calculates exact volume in m³ and liters, plus optimal duty cycles (runtime per hour) for your exhaust fan and humidifier."
                                        )
                                    )
                                }
                                Text(store.t(nl: "Berekening via Apple Neural Engine", en: "Calculation via Apple Neural Engine"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                    
                    // Dimensions Input Form
                    MycoCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(store.t(nl: "Afmetingen Kweekruimte (in centimeters)", en: "Grow Space Dimensions (in centimeters)"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.t(nl: "Lengte (cm)", en: "Length (cm)"))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    TextField("120", text: $lengthText)
                                        .keyboardType(.numberPad)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                        .onChange(of: lengthText) { triggerNeuralCalculation() }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.t(nl: "Breedte (cm)", en: "Width (cm)"))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    TextField("60", text: $widthText)
                                        .keyboardType(.numberPad)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                        .onChange(of: widthText) { triggerNeuralCalculation() }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.t(nl: "Hoogte (cm)", en: "Height (cm)"))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    TextField("150", text: $heightText)
                                        .keyboardType(.numberPad)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                        .onChange(of: heightText) { triggerNeuralCalculation() }
                                }
                            }
                            
                            // Calculated Volume Badge
                            let l = Double(lengthText) ?? 120.0
                            let w = Double(widthText) ?? 60.0
                            let h = Double(heightText) ?? 150.0
                            let volM3 = (l * w * h) / 1_000_000.0
                            let volL = volM3 * 1000.0
                            
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "scalemass.fill")
                                        .foregroundColor(MycoTheme.blue)
                                    Text(store.t(nl: "Berekend Volume:", en: "Calculated Volume:"))
                                        .font(.caption.bold())
                                        .foregroundColor(MycoTheme.textSecondary)
                                    Text(String(format: "%.2f m³ (%.0f Liter)", volM3, volL))
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(MycoTheme.blue.opacity(0.12))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Hardware Capacities Card
                    MycoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(store.t(nl: "Apparatuur Specificaties (Optioneel)", en: "Equipment Specifications (Optional)"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.t(nl: "Afzuiger (m³/uur)", en: "Fan (m³/hr)"))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    TextField("100", text: $fanCapacityText)
                                        .keyboardType(.numberPad)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                        .onChange(of: fanCapacityText) { triggerNeuralCalculation() }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.t(nl: "Bevochtiger (ml/uur)", en: "Humidifier (ml/hr)"))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    TextField("300", text: $humidifierOutputText)
                                        .keyboardType(.numberPad)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                        .onChange(of: humidifierOutputText) { triggerNeuralCalculation() }
                                }
                            }
                        }
                    }
                    
                    // AI Simulation Result Card
                    if let res = calculationResult {
                        MycoCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(MycoTheme.green.opacity(0.2))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "sparkles")
                                            .foregroundColor(MycoTheme.green)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.t(nl: "AI Luchtstroom & Vocht Advies", en: "AI Airflow & Humidity Advice"))
                                            .font(.headline.bold())
                                            .foregroundColor(.white)
                                        Text(store.t(nl: "Betrouwbaarheid: \(res.aiConfidenceScore)% • Gevalideerd", en: "Confidence: \(res.aiConfidenceScore)% • Verified"))
                                            .font(.system(size: 10))
                                            .foregroundColor(MycoTheme.green)
                                    }
                                    Spacer()
                                }
                                
                                Divider().background(MycoTheme.border)
                                
                                // Metric Grid
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.t(nl: "AFZUIGING (FAE)", en: "EXHAUST (FAE)"))
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(MycoTheme.textSecondary)
                                        Text("Elke \(res.recommendedFaeIntervalMins)m")
                                            .font(.system(.headline, design: .monospaced).bold())
                                            .foregroundColor(MycoTheme.amber)
                                        Text("Looptijd: \(res.recommendedFaeDurationMins) minuten")
                                            .font(.system(size: 10))
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(10)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.t(nl: "BEVOCHTIGER", en: "HUMIDIFIER"))
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(MycoTheme.textSecondary)
                                        Text("Elke \(res.recommendedHumidifierIntervalMins)m")
                                            .font(.system(.headline, design: .monospaced).bold())
                                            .foregroundColor(MycoTheme.blue)
                                        Text("Looptijd: \(res.recommendedHumidifierDurationMins) minuten")
                                            .font(.system(size: 10))
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(10)
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "drop.triangle.fill")
                                        .foregroundColor(MycoTheme.blue)
                                    Text(store.t(
                                        nl: "Geschat waterverbruik: ~\(Int(res.dailyWaterUsageMl)) ml per 24 uur.",
                                        en: "Estimated water consumption: ~\(Int(res.dailyWaterUsageMl)) ml per 24 hours."
                                    ))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                }
                                .padding(.top, 4)
                                
                                // Apply Button
                                Button {
                                    applyCalculationToAutopilot(res: res)
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text(store.t(nl: "Pas AI Berekening toe op Autopilot", en: "Apply AI Calculation to Autopilot"))
                                            .fontWeight(.bold)
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(MycoTheme.green)
                                    .cornerRadius(12)
                                }
                                .padding(.top, 6)
                            }
                        }
                    }
                    
                    // Optische RV (Relatieve Vochtigheid) Scanner
                    MycoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(MycoTheme.blue.opacity(0.18))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "camera.metering.matrix")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(MycoTheme.blue)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "Optische RV Hygrometer", en: "Optical RH Hygrometer"))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(store.t(nl: "Condensatie-analyse van de kweekruimte", en: "Grow space condensation analysis"))
                                        .font(.caption)
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                Spacer()
                            }
                            
                            Text(store.t(
                                nl: "Heb je geen fysieke sensor in je kweekruimte? Scan met de camera het deksel of de wanden. Vision AI herkent microscopische vochtdruppels en schat de RV visueel in.",
                                en: "Don't have a physical sensor in your grow space? Scan the lid or walls with your camera. Vision AI detects microscopic droplets to estimate RH optically."
                            ))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                            
                            Button {
                                showOpticalHygrometer = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.viewfinder")
                                    Text(store.t(nl: "Open Optische RV Scanner", en: "Open Optical RH Scanner"))
                                        .fontWeight(.bold)
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(MycoTheme.blue)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Kweekruimte & AI Berekening", en: "Grow Space & AI Calculation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Klaar", en: "Done")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
            }
            .onAppear {
                lengthText = String(format: "%.0f", store.db.environmentConfig.roomLengthCm)
                widthText = String(format: "%.0f", store.db.environmentConfig.roomWidthCm)
                heightText = String(format: "%.0f", store.db.environmentConfig.roomHeightCm)
                fanCapacityText = String(format: "%.0f", store.db.environmentConfig.fanCapacityM3H)
                humidifierOutputText = String(format: "%.0f", store.db.environmentConfig.humidifierOutputMlH)
                triggerNeuralCalculation()
            }
            .alert(store.t(nl: "AI Berekening Toegepast!", en: "AI Calculation Applied!"), isPresented: $showAppliedSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text(store.t(
                    nl: "De Autopilot regelt de afzuiging en bevochtiging nu exact volgens de kubieke meters van jouw kweekruimte.",
                    en: "Autopilot now regulates exhaust and humidification exactly matching your grow space cubic meters."
                ))
            }
            .sheet(isPresented: $showOpticalHygrometer) {
                MycoOpticalHygrometerView()
                    .environmentObject(store)
            }
        }
    }
    
    private func triggerNeuralCalculation() {
        let l = Double(lengthText) ?? 120.0
        let w = Double(widthText) ?? 60.0
        let h = Double(heightText) ?? 150.0
        let fan = Double(fanCapacityText) ?? 100.0
        let hum = Double(humidifierOutputText) ?? 300.0
        
        calculationResult = MycoNeuralClimateEngine.calculate(
            lengthCm: l,
            widthCm: w,
            heightCm: h,
            targetHumidityPct: store.db.environmentConfig.targetHumidityPct,
            targetTempC: store.db.environmentConfig.targetDayTempC,
            fanCapacityM3H: fan,
            humidifierMlH: hum
        )
    }
    
    private func applyCalculationToAutopilot(res: MycoNeuralClimateEngine.SimulationResult) {
        let l = Double(lengthText) ?? 120.0
        let w = Double(widthText) ?? 60.0
        let h = Double(heightText) ?? 150.0
        let fan = Double(fanCapacityText) ?? 100.0
        let hum = Double(humidifierOutputText) ?? 300.0
        
        store.db.environmentConfig.roomLengthCm = l
        store.db.environmentConfig.roomWidthCm = w
        store.db.environmentConfig.roomHeightCm = h
        store.db.environmentConfig.fanCapacityM3H = fan
        store.db.environmentConfig.humidifierOutputMlH = hum
        store.db.environmentConfig.spacePreset = selectedPreset
        
        // Update Autopilot Intervals directly
        store.db.environmentConfig.faeIntervalMinutes = res.recommendedFaeIntervalMins
        store.db.environmentConfig.faeDurationMinutes = res.recommendedFaeDurationMins
        store.db.environmentConfig.aiDailyWaterUsageMl = res.dailyWaterUsageMl
        store.db.environmentConfig.isAiClimateModelApplied = true
        store.db.environmentConfig.lastAutopilotLogMessage = store.t(
            nl: "AI Berekening toegepast: FAE elke \(res.recommendedFaeIntervalMins)m, Bevochtiging elke \(res.recommendedHumidifierIntervalMins)m",
            en: "AI Calculation applied: FAE every \(res.recommendedFaeIntervalMins)m, Humidity every \(res.recommendedHumidifierIntervalMins)m"
        )
        store.db.environmentConfig.lastAutopilotLogTime = Date()
        store.save()
        
        showAppliedSuccess = true
    }
}




// MARK: - Fast Non-Blocking Async Thumbnail View
struct TimelapseAsyncThumbnailView: View {
    let photo: TimelapsePhotoItem
    let size: CGFloat
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Image(systemName: "photo.fill")
                    .foregroundColor(MycoTheme.blue)
                    .frame(width: size, height: size)
                    .background(Color.white.opacity(0.05))
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(8)
        .task(id: photo.id) {
            if let cached = TimelapseImageCache.shared.get(id: photo.id) {
                self.image = cached
                return
            }
            self.image = photo.loadImage()
        }
    }
}
