//
//  LivingGrowCameraCard.swift
//  MycoLab
//
//  Dedicated Dashboard Module for the Grow Camera (Kweekcamera):
//  - Displays recent wide-angle snapshot taken with flash during optical measurements when in standby
//  - Clean, minimal card without live-stream distraction; tap image to open full live monitor
//  - "Update" button to request an instant fresh snapshot with flash
//  - InfoTipButton popovers to keep interface uncluttered
//

import SwiftUI
import LiveKit

public struct LivingGrowCameraCard: View {
    @EnvironmentObject var store: MycoStore
    let onOpenLiveMonitor: () -> Void
    var onOpenBroadcaster: (() -> Void)? = nil
    var onOpenSpaceAndClimate: (() -> Void)? = nil
    
    @ObservedObject private var camStreamMgr = MycoCamStreamManager.shared
    @ObservedObject private var liveKitMgr = LiveKitStreamManager.shared
    @State private var isUpdating: Bool = false
    
    private var isCamConnected: Bool {
        camStreamMgr.connectionState == .connected ||
        camStreamMgr.role != .idle ||
        liveKitMgr.connectionState == .connected
    }
    
    private var latestSnapshot: UIImage? {
        if let liveFrame = camStreamMgr.receivedFrame ?? camStreamMgr.cloudFrame ?? liveKitMgr.lastRemoteSnapshot {
            return liveFrame
        }
        if let photoItem = store.db.timelapsePhotos.first(where: { $0.hasPhotoData }),
           let img = photoItem.loadImage() {
            return img
        }
        return nil
    }

    private var latestSnapshotItem: TimelapsePhotoItem? {
        store.db.timelapsePhotos.first(where: { $0.hasPhotoData })
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(alignment: .center) {
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(isCamConnected ? MycoTheme.green.opacity(0.2) : Color.teal.opacity(0.18))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: isCamConnected ? "video.fill" : "camera.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isCamConnected ? MycoTheme.green : Color.teal)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.t(nl: "Kweekcamera in Tent", en: "Tent Grow Camera"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(isCamConnected ? store.t(nl: "Gekoppeld • Tik voor Live", en: "Connected • Tap for Live") : store.t(nl: "Standby • P2P Mesh & Cloud", en: "Standby • P2P Mesh & Cloud"))
                            .font(.system(size: 10))
                            .foregroundColor(isCamConnected ? MycoTheme.green : MycoTheme.textSecondary)
                    }
                    
                    InfoTipButton(
                        title: store.t(nl: "Kweekcamera Standby & Live", en: "Grow Camera Standby & Live"),
                        message: store.t(
                            nl: "Hier zie je de meest recente overzichtsfoto van je kweekruimte. Tik op de foto om direct live mee te kijken via WebRTC. Tik op 'Update' om direct een nieuwe overzichtsfoto met flits te maken.",
                            en: "Displays the most recent overview photo of your grow room. Tap the image to watch live via WebRTC. Tap 'Update' to take an instant fresh overview snapshot with flash."
                        )
                    )
                }
                
                Spacer()
                
                // Update Button: Requests a fresh photo from the camera
                Button {
                    Task {
                        await triggerUpdateSnapshot()
                    }
                } label: {
                    HStack(spacing: 5) {
                        if isUpdating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: MycoTheme.green))
                                .scaleEffect(0.65)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(MycoTheme.green)
                        }
                        Text(isUpdating ? store.t(nl: "Laden...", en: "Updating...") : store.t(nl: "Update", en: "Update"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(MycoTheme.green)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(MycoTheme.green.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(MycoTheme.green.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isUpdating)
            }
            
            // Preview Container (Directly interactive: tap anywhere to launch Live Monitor)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MycoTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isCamConnected ? MycoTheme.green.opacity(0.4) : MycoTheme.border, lineWidth: 1)
                    )
                
                VStack(spacing: 0) {
                    if let snap = latestSnapshot {
                        // Image Thumbnail with Standby / Recent Scan Overlay
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: snap)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 145)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(8)
                            
                            VStack {
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 8, weight: .bold))
                                        Text(store.t(nl: "STANDBY • RECENTE SCAN", en: "STANDBY • RECENT SCAN"))
                                            .font(.system(size: 8, weight: .black, design: .monospaced))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.72))
                                    .cornerRadius(4)
                                    
                                    Spacer()
                                    
                                    if let snapItem = latestSnapshotItem {
                                        Text(snapItem.timestamp.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.9))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.black.opacity(0.72))
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(6)
                                
                                Spacer()
                                
                                HStack {
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 10, weight: .bold))
                                        Text(store.t(nl: "Tik voor live kijker", en: "Tap for live monitor"))
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.75))
                                    .cornerRadius(6)
                                    .padding(6)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onOpenLiveMonitor()
                        }
                    } else if let track = liveKitMgr.remoteVideoTrack {
                        // Fallback stream view if no snapshot is available yet
                        ZStack(alignment: .bottomTrailing) {
                            SwiftUIVideoView(track, layoutMode: .fill)
                                .frame(height: 145)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(8)
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.teal)
                                    .frame(width: 6, height: 6)
                                Text(store.t(nl: "STANDBY PREVIEW", en: "STANDBY PREVIEW"))
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .padding(6)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onOpenLiveMonitor()
                        }
                    } else {
                        // Standby Preview Slate
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.28))
                                .frame(height: 76)
                            
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.teal.opacity(0.14))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "camera.aperture")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color.teal)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "Kweekcamera Standby", en: "Grow Camera Standby"))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(store.t(nl: "Tik om live kweekkijker te openen", en: "Tap to open live monitor"))
                                        .font(.system(size: 11))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(MycoTheme.textSecondary.opacity(0.7))
                            }
                            .padding(.horizontal, 12)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onOpenLiveMonitor()
                        }
                    }
                }
                .padding(6)
            }
        }
    }
    
    private func triggerUpdateSnapshot() async {
        guard !isUpdating else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        isUpdating = true
        defer { isUpdating = false }

        // 1. Modulaire HTTP Snapshot Camera (ESP32-CAM / IP Camera URL)
        let snapUrl = store.db.environmentConfig.effectiveSnapshotURL
        if !snapUrl.isEmpty {
            if let img = await store.fetchHTTPSnapshot(urlString: snapUrl) {
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
                }
                return
            }
        }

        // 2. Vraag een nieuwe groothoek overzichtsfoto met flits op van de kweekcamera
        await MycoOpticalHygrometerManager.shared.captureWideOverviewWithFlashForStandby()

        if liveKitMgr.currentRole == .viewer {
            liveKitMgr.requestWideFlashSnapshot()
            MycoCamPairingManager.shared.sendDirectCommandToPeers("cmd:snapshot:wide:flash")
        }

        // Wacht kort tot de nieuwe foto binnenkomt en lokaal is opgeslagen
        let initialTime = latestSnapshotItem?.timestamp
        for _ in 0..<15 {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if let newTime = latestSnapshotItem?.timestamp, newTime != initialTime {
                break
            }
        }
    }
}

public struct LivingCleanroomVoiceCard: View {
    @EnvironmentObject var store: MycoStore
    let onOpenVoiceConsole: () -> Void
    
    @ObservedObject private var voiceMgr = MycoCleanroomVoiceManager.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(alignment: .center) {
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(voiceMgr.isListening ? MycoTheme.green.opacity(0.25) : Color.cyan.opacity(0.18))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: voiceMgr.isListening ? "waveform" : "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(voiceMgr.isListening ? MycoTheme.green : Color.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.t(nl: "Cleanroom Voice Assistent", en: "Cleanroom Voice Assistant"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(voiceMgr.isListening ? store.t(nl: "Luistert Handsfree...", en: "Listening Hands-Free...") : store.t(nl: "On-Device AI • Spreektaal & Halve Zinnen", en: "On-Device AI • Casual Phrasing & Incomplete Sentences"))
                            .font(.system(size: 10))
                            .foregroundColor(voiceMgr.isListening ? MycoTheme.green : MycoTheme.textSecondary)
                    }
                    
                    InfoTipButton(
                        title: store.t(nl: "Handsfree Cleanroom Spraak AI", en: "Hands-Free Cleanroom Voice AI"),
                        message: store.t(
                            nl: "Werk 100% steriel onder de flowhood zonder schermen aan te raken. Zeg gewoon 'autoclaaf', 'hoe warm is het?', of 'zet mist aan'. De lokale Apple AI vult ontbrekende tijden en apparaten automatisch aan.",
                            en: "Work 100% sterile under the laminar flow hood without touching screens. Say casual phrases like 'autoclave', 'what's the temp?', or 'turn on mist'. On-device AI infers standard times and devices automatically."
                        )
                    )
                }
                
                Spacer()
                
                Button {
                    onOpenVoiceConsole()
                } label: {
                    HStack(spacing: 4) {
                        Text(store.t(nl: "Console", en: "Console"))
                            .font(.system(size: 11, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Color.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(8)
                }
            }
            
            // Interaction Box
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MycoTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(voiceMgr.isListening ? Color.cyan.opacity(0.6) : MycoTheme.border, lineWidth: 1)
                    )
                
                VStack(alignment: .leading, spacing: 10) {
                    // Quick Action Prompts
                    HStack(spacing: 6) {
                        quickPromptChip(label: store.t(nl: "⏱️ Autoclaaf (90m)", en: "⏱️ Autoclave (90m)")) {
                            voiceMgr.processVoiceCommand("zet de autoclaaf aan")
                            onOpenVoiceConsole()
                        }
                        
                        quickPromptChip(label: store.t(nl: "🌡️ Hoe warm?", en: "🌡️ Temp Check")) {
                            voiceMgr.processVoiceCommand("hoe warm is het?")
                            onOpenVoiceConsole()
                        }
                        
                        quickPromptChip(label: store.t(nl: "💧 Mist aan", en: "💧 Mist On")) {
                            voiceMgr.processVoiceCommand("zet mist aan")
                            onOpenVoiceConsole()
                        }
                    }
                    
                    // Main Tap-to-Talk / Direct Toggle Button
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        if voiceMgr.isListening {
                            voiceMgr.stopListening()
                        } else {
                            voiceMgr.startListening()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: voiceMgr.isListening ? "stop.circle.fill" : "mic.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(voiceMgr.isListening ? Color.white : Color.black)
                            
                            Text(voiceMgr.isListening ? store.t(nl: "Luistert Handsfree • Tik om te stoppen", en: "Listening Hands-Free • Tap to stop") : store.t(nl: "Start Handsfree Luisteren", en: "Start Hands-Free Listening"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(voiceMgr.isListening ? Color.white : Color.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(voiceMgr.isListening ? Color.red : Color.cyan)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
            }
        }
    }
    
    private func quickPromptChip(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(MycoTheme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
