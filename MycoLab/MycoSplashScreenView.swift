//
//  MycoSplashScreenView.swift
//  MycoLab
//
//  Created for MycoLab on 15/11/2026.
//  Flexible startup splash system: Video splash (animycolab.mp4),
//  minimalist glowing logo animation, or instant start with customizable settings.
//

import SwiftUI
import AVKit
import AVFoundation

// MARK: - Splash Video Manager

public final class SplashVideoManager {
    public static let shared = SplashVideoManager()
    
    private let customVideoFilename = "custom_splash.mp4"
    
    private init() {}
    
    public var customVideoURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(customVideoFilename)
    }
    
    public var bundleVideoURL: URL? {
        Bundle.main.url(forResource: "animycolab", withExtension: "mp4")
    }
    
    public var hasCustomVideo: Bool {
        FileManager.default.fileExists(atPath: customVideoURL.path)
    }
    
    public var activeVideoURL: URL? {
        if hasCustomVideo {
            return customVideoURL
        }
        return bundleVideoURL
    }
    
    @discardableResult
    public func saveCustomVideo(from sourceURL: URL) -> Bool {
        do {
            let dest = customVideoURL
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            return true
        } catch {
            print("[SplashVideoManager] Kon video niet opslaan: \(error)")
            return false
        }
    }
    
    @discardableResult
    public func saveCustomVideoData(_ data: Data) -> Bool {
        do {
            let dest = customVideoURL
            try data.write(to: dest, options: .atomic)
            return true
        } catch {
            print("[SplashVideoManager] Kon videodata niet wegschrijven: \(error)")
            return false
        }
    }
    
    public func removeCustomVideo() {
        let dest = customVideoURL
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
    }
}

// MARK: - Native Splash Video Player View (Zero Lag, Borderless, Fill)

struct SplashAVPlayerLayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = videoGravity
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.videoGravity = videoGravity
    }
}

// MARK: - Main Splash Screen View

public struct MycoSplashScreenView: View {
    @EnvironmentObject var store: MycoStore
    public var isPreview: Bool = false
    public var onFinished: () -> Void
    
    @State private var player: AVPlayer? = nil
    @State private var endObserver: Any? = nil
    @State private var isDismissing: Bool = false
    @State private var logoPulse: Bool = false
    @State private var logoGlow: Bool = false
    @State private var opacity: Double = 1.0
    @State private var showSkipBadge: Bool = false
    
    public init(isPreview: Bool = false, onFinished: @escaping () -> Void) {
        self.isPreview = isPreview
        self.onFinished = onFinished
    }
    
    private var currentMode: SplashAnimationMode {
        store.db.splashAnimationMode
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch currentMode {
            case .video:
                if let videoURL = SplashVideoManager.shared.activeVideoURL {
                    videoSplashContent(url: videoURL)
                } else {
                    // Fallback to minimalist logo animation if video file is missing
                    minimalistLogoSplashContent
                }
            case .modernLogo:
                minimalistLogoSplashContent
            case .disabled:
                Color.clear
                    .onAppear {
                        if !isPreview {
                            onFinished()
                        }
                    }
            }
            
            // Skip button & overlay tap helper
            if currentMode != .disabled {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: dismissAndFinish) {
                            HStack(spacing: 5) {
                                Text(store.t(nl: "Overslaan", en: "Skip"))
                                    .font(.system(size: 11, weight: .bold))
                                Image(systemName: "chevron.right.2")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.trailing, 18)
                        .padding(.top, isPreview ? 50 : 20)
                    }
                    Spacer()
                }
            }
        }
        .opacity(opacity)
        .contentShape(Rectangle())
        .onTapGesture {
            dismissAndFinish()
        }
        .onAppear {
            setupSplash()
        }
        .onDisappear {
            teardownPlayer()
        }
    }
    
    // MARK: - Video Splash Content
    private func videoSplashContent(url: URL) -> some View {
        ZStack {
            if let p = player {
                SplashAVPlayerLayerView(player: p, videoGravity: .resizeAspectFill)
                    .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Minimalist Logo Splash Content
    private var minimalistLogoSplashContent: some View {
        ZStack {
            // Subtle radial gradient backdrop
            RadialGradient(
                colors: [
                    Color(red: 0.08, green: 0.16, blue: 0.28),
                    Color(red: 0.02, green: 0.03, blue: 0.06)
                ],
                center: .center,
                startRadius: 20,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 22) {
                Spacer()
                
                // Pulsing glowing logo core
                ZStack {
                    // Outer glow pulse
                    Circle()
                        .fill(MycoTheme.blue.opacity(logoGlow ? 0.25 : 0.05))
                        .frame(width: 150, height: 150)
                        .scaleEffect(logoPulse ? 1.25 : 0.85)
                    
                    Circle()
                        .fill(MycoTheme.green.opacity(logoGlow ? 0.20 : 0.05))
                        .frame(width: 120, height: 120)
                        .scaleEffect(logoPulse ? 1.15 : 0.9)
                    
                    // Brand Icon Container
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.12, green: 0.18, blue: 0.32),
                                        Color(red: 0.05, green: 0.08, blue: 0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [MycoTheme.blue, MycoTheme.green],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: MycoTheme.blue.opacity(0.4), radius: 16, x: 0, y: 8)
                        
                        Image(systemName: "cross.vial.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, MycoTheme.blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                
                // Typography
                VStack(spacing: 6) {
                    Text("MYCOLAB")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(store.t(nl: "Geavanceerd Mycologie & Kweek Platform", en: "Intelligent Mycology & Cultivation Platform"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                
                Spacer()
                
                // Subtle version tag
                Text("v1.0 • Lab Alpha")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.3))
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                logoPulse = true
                logoGlow = true
            }
        }
    }
    
    // MARK: - Setup Logic
    private func setupSplash() {
        switch currentMode {
        case .video:
            guard let videoURL = SplashVideoManager.shared.activeVideoURL else {
                startLogoTimer()
                return
            }
            
            let asset = AVAsset(url: videoURL)
            let item = AVPlayerItem(asset: asset)
            let p = AVPlayer(playerItem: item)
            p.actionAtItemEnd = .none
            p.isMuted = !store.db.isSplashSoundEnabled
            self.player = p
            
            // Listen for video completion
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                dismissAndFinish()
            }
            
            p.play()
            
            // Safety timeout: In case video stalls or hangs, auto dismiss after 12s
            DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) {
                if !isDismissing {
                    dismissAndFinish()
                }
            }
            
        case .modernLogo:
            startLogoTimer()
            
        case .disabled:
            if !isPreview {
                onFinished()
            }
        }
    }
    
    private func startLogoTimer() {
        // Logo splash stays for ~1.8 seconds then gracefully fades out
        let displayDuration: Double = isPreview ? 2.5 : 1.8
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
            if !isDismissing {
                dismissAndFinish()
            }
        }
    }
    
    // MARK: - Dismiss & Cleanup
    private func dismissAndFinish() {
        guard !isDismissing else { return }
        isDismissing = true
        
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        
        player?.pause()
        
        withAnimation(.easeInOut(duration: 0.35)) {
            opacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            teardownPlayer()
            onFinished()
        }
    }
    
    private func teardownPlayer() {
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        player?.pause()
        player = nil
    }
}
