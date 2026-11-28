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


// MARK: - DATA MODELS EXTRACTED TO MycoModels.swift


// MARK: - CENTRAL STORE EXTRACTED TO MycoStore.swift


struct EmptyStateCard: View {
    var icon: String
    var title: String
    var message: String
    var buttonTitle: String
    var action: () -> Void
    
    var body: some View {
        MycoCard {
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(MycoTheme.blue)
                    .padding(.top, 8)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(MycoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(MycoTheme.blue)
                        .cornerRadius(10)
                }
                .padding(.bottom, 6)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Reusable Info Tip Button (Clean contextual information without UI clutter)
struct InfoTipButton: View {
    let title: String
    let message: String
    var icon: String = "info.circle"
    var color: Color = MycoTheme.blue

    @State private var showingAlert = false

    var body: some View {
        Button {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
            showingAlert = true
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color.opacity(0.85))
                .padding(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alert(title, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

// MARK: - 7. MAIN ENTRY VIEW (ContentView)
@MainActor struct ContentView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var syncManager = MycoSyncManager.shared
    @ObservedObject private var liveKitManager = LiveKitStreamManager.shared
    @ObservedObject private var alertManager = MycoLabAlertManager.shared
    @AppStorage("mycolab_is_dedicated_camera_device") private var isDedicatedCameraDevice: Bool = false
    @State private var showRemoteMonitorFromPiP: Bool = false
    @State private var selectedTab: Int = {
        if let tabIdx = ProcessInfo.processInfo.arguments.firstIndex(of: "-demoTab"),
           tabIdx + 1 < ProcessInfo.processInfo.arguments.count,
           let tabInt = Int(ProcessInfo.processInfo.arguments[tabIdx + 1]) {
            return tabInt
        }
        return 0
    }()
    @State private var isSidebarCollapsed: Bool = false
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "mycolab_onboarding_completed")
    @State private var showQRScanner = false
    @State private var scannedProject: GrowProject?
    @State private var scannedCulture: CultureItem?
    @State private var scannedSupply: LabSupplyItem?
    @State private var scanErrorAlert = false
    @State private var manualQRInput = ""
    @State private var scannedDossierText: String? = nil
    @State private var isShowingSplash: Bool = !ProcessInfo.processInfo.arguments.contains("-noSplash") && !ProcessInfo.processInfo.arguments.contains("-demoMode")
    
    private var isDesktopOrPadLayout: Bool {
        MycoDevicePlatform.isMac || horizontalSizeClass == .regular
    }
    
    var body: some View {
        ZStack {
            MycoTheme.bg.ignoresSafeArea()
            
            if isDedicatedCameraDevice {
                DedicatedCameraDeviceView()
                    .environmentObject(store)
                    .transition(.opacity)
            } else if store.db.biometricLock && !store.isUnlocked {
                MycoBiometricAndDecoyLockView()
            } else if isDesktopOrPadLayout {
                HStack(spacing: 0) {
                    desktopSidebar
                    
                    Rectangle()
                        .fill(MycoTheme.border)
                        .frame(width: 1)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        if store.isDecoyMode {
                            decoyVaultBanner
                        }
                        mainTabContent
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    mainTabContent
                }
                .safeAreaInset(edge: .bottom) {
                    customBottomNavBar
                }
            }
            
            if isShowingSplash && store.db.splashAnimationMode != .disabled && !isDedicatedCameraDevice {
                MycoSplashScreenView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowingSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let alert = alertManager.latestBannerAlert {
                    HStack(spacing: 10) {
                        Image(systemName: alert.severity.icon)
                            .foregroundColor(alert.severity == .critical ? .red : .yellow)
                            .font(.system(size: 16, weight: .bold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Text(alert.message)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(2)
                        }
                        Spacer()
                        Button {
                            withAnimation {
                                alertManager.latestBannerAlert = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(size: 16))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(alert.severity == .critical ? Color(hex: "#7F1D1D") : Color(hex: "#78350F"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(alert.severity == .critical ? Color.red.opacity(0.6) : Color.yellow.opacity(0.6), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: 10, y: 5)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 44)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1000)
                }

                if syncManager.showToast, let msg = syncManager.toastMessage {
                    HStack(spacing: 8) {
                        Image(systemName: msg.contains("UIT") || msg.contains("OFF") ? "power.circle.fill" : "bolt.circle.fill")
                            .foregroundColor(msg.contains("UIT") || msg.contains("OFF") ? .orange : MycoTheme.green)
                            .font(.system(size: 16, weight: .bold))
                        Text(msg)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#161B22").opacity(0.96))
                            .overlay(
                                Capsule()
                                    .stroke(msg.contains("UIT") || msg.contains("OFF") ? Color.orange.opacity(0.5) : MycoTheme.green.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 10, y: 5)
                    .padding(.top, alertManager.latestBannerAlert != nil ? 4 : 50)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if liveKitManager.showFloatingPiP, let track = liveKitManager.remoteVideoTrack {
                FloatingCameraPiPView(track: track) {
                    liveKitManager.showFloatingPiP = false
                    showRemoteMonitorFromPiP = true
                }
                .padding(.trailing, 16)
                .padding(.bottom, 82)
                .transition(.scale.combined(with: .opacity))
                .zIndex(900)
            }
        }
        .onAppear {
            if store.db.hasCompletedOnboarding || !store.db.projects.isEmpty || !store.db.cultures.isEmpty || !store.db.strains.isEmpty || !store.db.smartDevices.isEmpty {
                showOnboarding = false
                UserDefaults.standard.set(true, forKey: "mycolab_onboarding_completed")
            }
        }
        .sheet(isPresented: $showRemoteMonitorFromPiP) {
            RemoteLabMonitorView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerModalView(
                manualCode: $manualQRInput,
                onScanned: { code in
                    showQRScanner = false
                    handleScannedQRCode(code)
                }
            )
        }
        .sheet(isPresented: $store.showDynamicIslandExpanded) {
            DynamicIslandExpandedModalView()
        }
        .sheet(item: $scannedProject) { project in
            NavigationStack {
                ProjectDetailView(projectID: project.id)
                    .environmentObject(store)
            }
        }
        .sheet(item: $scannedCulture) { culture in
            NavigationStack {
                QRLabelStudioView(
                    labels: [(
                        title: store.displayTitle(name: culture.strainName, sku: culture.skuCode),
                        subtitle: "\(culture.cultureType) • \(culture.generation)",
                        date: culture.dateCreated.formatted(date: .numeric, time: .omitted),
                        qr: culture.qrCodeID
                    )]
                )
            }
        }
        .sheet(item: $scannedSupply) { supply in
            QuickSupplyAdjustSheet(item: supply)
                .environmentObject(store)
        }
        .sheet(item: Binding(
            get: { scannedDossierText.map { ScannedDossierWrapper(text: $0) } },
            set: { scannedDossierText = $0?.text }
        )) { wrapper in
            ScannedDossierSheetView(rawText: wrapper.text)
        }
        .alert("QR-Code Niet Gevonden", isPresented: $scanErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Deze QR-code staat nog niet in je MycoLabs database.")
        }
        .fullScreenCover(isPresented: Binding(
            get: { showOnboarding && (!store.db.biometricLock || store.isUnlocked) && !isDedicatedCameraDevice },
            set: { showOnboarding = $0 }
        )) {
            AIOnboardingWizardView(isPresented: $showOnboarding)
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MycoLabShowOnboardingWizard"))) { _ in
            showOnboarding = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MycoLabSwitchTab"))) { notif in
            if let tabIndex = notif.object as? Int {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedTab = tabIndex
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MycoLabOpenQRScanner"))) { _ in
            showQRScanner = true
        }
    }
    
    private var desktopSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            // App Branding Header + Collapse Toggle
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [MycoTheme.blue, Color(hex: "5E5CE6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "flask.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
                
                if !isSidebarCollapsed {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.db.stealthMode ? "LabOS" : "MycoLabs")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Text(MycoDevicePlatform.isMac ? store.t(nl: "MacBook Werkstation", en: "MacBook Workstation") : store.t(nl: "iPad Lab Station", en: "iPad Lab Station"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(MycoTheme.blue)
                    }
                    Spacer()
                }
                
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isSidebarCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: isSidebarCollapsed ? "sidebar.right" : "sidebar.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MycoTheme.textSecondary)
                        .padding(7)
                        .background(MycoTheme.bg)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            
            // Primary QR & AI Scanner Button
            Button {
                showQRScanner = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: MycoDevicePlatform.isMac ? "sparkles.tv.fill" : "viewfinder.circle.fill")
                        .font(.system(size: 19, weight: .bold))
                    if !isSidebarCollapsed {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(MycoDevicePlatform.isMac ? store.t(nl: "AI Vision & Code", en: "AI Vision & Code") : store.t(nl: "AI & QR Scanner", en: "AI & QR Scanner"))
                                .font(.subheadline.bold())
                            Text(MycoDevicePlatform.isMac ? store.t(nl: "Foto-analyse & batch zoeken", en: "Photo analysis & batch lookup") : store.t(nl: "Scan potten, platen & labels", en: "Scan jars, plates & labels"))
                                .font(.system(size: 10))
                                .opacity(0.85)
                        }
                        Spacer()
                        Text("⌘K")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(5)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .padding(.horizontal, isSidebarCollapsed ? 0 : 12)
                .background(
                    LinearGradient(
                        colors: [MycoTheme.blue, Color(hex: "5E5CE6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color(hex: "5E5CE6").opacity(0.35), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            
            if !isSidebarCollapsed {
                Text(store.t(nl: "LABORATORIUM", en: "LABORATORY"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(MycoTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
            }
            
            // Sidebar Navigation Items
            VStack(spacing: 6) {
                sidebarNavRow(
                    index: 0,
                    icon: "square.grid.2x2.fill",
                    title: store.t(nl: "Dashboard", en: "Dashboard"),
                    badge: store.db.projects.filter { !$0.isArchived }.count,
                    shortcut: "⌘1"
                )
                sidebarNavRow(
                    index: 1,
                    icon: "allergens",
                    title: store.t(nl: "Culturen & Genetica", en: "Cultures & Genetics"),
                    badge: store.db.cultures.count,
                    shortcut: "⌘2"
                )
                sidebarNavRow(
                    index: 2,
                    icon: "archivebox.fill",
                    title: store.t(nl: "Stash & Voorraad", en: "Stash & Stock"),
                    badge: store.db.stash.count,
                    shortcut: "⌘3"
                )
                sidebarNavRow(
                    index: 3,
                    icon: "slider.horizontal.3",
                    title: store.t(nl: "Tools & Presets", en: "Tools & Presets"),
                    badge: 0,
                    shortcut: "⌘4"
                )
            }
            
            Spacer()
            
            // Live Cloud & Lab Telemetry Footer Card
            if !isSidebarCollapsed {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(MycoTheme.green)
                            .frame(width: 7, height: 7)
                        Text(store.t(nl: "Multi-Device Sync Actief", en: "Multi-Device Sync Active"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text(store.t(
                        nl: "\(store.db.projects.filter { !$0.isArchived }.count) actieve batches • \(store.db.cultures.count) culturen",
                        en: "\(store.db.projects.filter { !$0.isArchived }.count) active batches • \(store.db.cultures.count) cultures"
                    ))
                    .font(.system(size: 10))
                    .foregroundColor(MycoTheme.textSecondary)
                    
                    Button {
                        selectedTab = 0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            NotificationCenter.default.post(name: NSNotification.Name("MycoLabNewBatchShortcut"), object: nil)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text(store.t(nl: "Nieuwe Batch", en: "New Batch"))
                            Spacer()
                            Text("⌘N")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        .font(.caption.bold())
                        .foregroundColor(MycoTheme.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(MycoTheme.blue.opacity(0.14))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(MycoTheme.bg.opacity(0.7))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
            }
        }
        .padding(14)
        .frame(width: isSidebarCollapsed ? 76 : 256)
        .frame(maxHeight: .infinity)
        .background(MycoTheme.card.ignoresSafeArea())
    }
    
    private func sidebarNavRow(index: Int, icon: String, title: String, badge: Int, shortcut: String) -> some View {
        let isSelected = selectedTab == index
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : MycoTheme.textSecondary)
                    .frame(width: 24)
                
                if !isSidebarCollapsed {
                    Text(title)
                        .font(.subheadline.weight(isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : MycoTheme.textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? .white : MycoTheme.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isSelected ? Color.white.opacity(0.22) : MycoTheme.blue.opacity(0.15))
                            .cornerRadius(6)
                    } else {
                        Text(shortcut)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : MycoTheme.textSecondary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, isSidebarCollapsed ? 0 : 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? MycoTheme.blue : Color.clear)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private var mainTabContent: AnyView {
        switch selectedTab {
        case 0:
            return AnyView(ModernDashboardTabView().environmentObject(store))
        case 1:
            return AnyView(ModernGeneticsLabTabView().environmentObject(store))
        case 2:
            return AnyView(ModernStashAndStockTabView().environmentObject(store))
        case 3:
            return AnyView(ModernToolsAndPresetsTabView().environmentObject(store))
        default:
            return AnyView(ModernDashboardTabView().environmentObject(store))
        }
    }
    
    private var customBottomNavBar: some View {
        HStack(spacing: 0) {
            navBarButton(index: 0, icon: "square.grid.2x2.fill", title: store.t(nl: "Dashboard", en: "Dashboard"))
            navBarButton(index: 1, icon: "allergens", title: store.t(nl: "Culturen", en: "Cultures"))
            
            // Center Floating AI & QR Scanner Button
            Button {
                showQRScanner = true
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [MycoTheme.blue, Color(hex: "5E5CE6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .shadow(color: Color(hex: "5E5CE6").opacity(0.4), radius: 8, y: 2)
                    Image(systemName: "viewfinder.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -10)
            .frame(maxWidth: .infinity)
            
            navBarButton(index: 2, icon: "archivebox.fill", title: store.t(nl: "Oogst", en: "Harvest"))
            navBarButton(index: 3, icon: "slider.horizontal.3", title: store.t(nl: "Tools", en: "Tools"))
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            MycoTheme.card
                .overlay(Rectangle().fill(MycoTheme.border).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private func navBarButton(index: Int, icon: String, title: String) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(selectedTab == index ? MycoTheme.blue : MycoTheme.textSecondary)
            .frame(maxWidth: .infinity)
        }
    }
    
    @State private var showExitDecoyPrompt: Bool = false
    @State private var exitDecoyPin: String = ""

    private var decoyVaultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.circle.fill")
                .foregroundColor(MycoTheme.green)
                .font(.system(size: 13, weight: .bold))
            Text(store.t(nl: "Culinaire Vault Actief (Decoy)", en: "Culinary Vault Active (Decoy)"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Button {
                showExitDecoyPrompt = true
            } label: {
                Text(store.t(nl: "Wissel Vault", en: "Switch Vault"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(MycoTheme.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(MycoTheme.blue.opacity(0.15))
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.45))
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(MycoTheme.border),
            alignment: .bottom
        )
        .alert(store.t(nl: "Wissel naar Beveiligd Lab", en: "Switch to Secured Lab"), isPresented: $showExitDecoyPrompt) {
            SecureField(store.t(nl: "Master PIN", en: "Master PIN"), text: $exitDecoyPin)
            Button(store.t(nl: "Ontgrendel", en: "Unlock")) {
                let master = store.db.masterPin.isEmpty ? "1234" : store.db.masterPin
                if exitDecoyPin == master {
                    store.exitDecoyMode()
                }
                exitDecoyPin = ""
            }
            Button(store.t(nl: "Annuleer", en: "Cancel"), role: .cancel) {
                exitDecoyPin = ""
            }
        } message: {
            Text(store.t(nl: "Voer je 4-cijferige Master PIN in om terug te keren naar je volledige kweekdata.", en: "Enter your 4-digit Master PIN to return to your full cultivation data."))
        }
    }

    private var biometricLockScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(MycoTheme.blue.opacity(0.12))
                    .frame(width: 110, height: 110)
                
                Image(systemName: MycoDevicePlatform.biometricIcon)
                    .font(.system(size: 54, weight: .light))
                    .foregroundColor(MycoTheme.blue)
            }
            
            VStack(spacing: 8) {
                Text(store.db.stealthMode ? (store.isEnglish ? "LabOS Secured" : "LabOS Beveiligd") : (store.isEnglish ? "MycoLabs Secured" : "MycoLabs Beveiligd"))
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text(MycoDevicePlatform.isMac
                     ? store.t(nl: "Gebruik Touch ID of je wachtwoord om je laboratorium data te ontgrendelen", en: "Use Touch ID or your password to unlock your laboratory data")
                     : store.t(nl: "Scan je gezicht om toegang te krijgen tot je laboratorium data", en: "Scan your face to access your laboratory data"))
                    .font(.subheadline)
                    .foregroundColor(MycoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button {
                store.authenticateBiometrics()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: MycoDevicePlatform.biometricIcon)
                    Text(store.t(nl: "Ontgrendel met \(MycoDevicePlatform.biometricName) / Code", en: "Unlock with \(MycoDevicePlatform.biometricName) / Passcode"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(maxWidth: 360)
                .padding(.vertical, 14)
                .background(MycoTheme.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
            
            Spacer()
            
            Text(store.t(nl: "Eénmalige verificatie bij het opstarten van de app", en: "One-time verification when opening the app"))
                .font(.caption2)
                .foregroundColor(MycoTheme.textSecondary.opacity(0.7))
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MycoTheme.bg.ignoresSafeArea())
        .onAppear {
            store.triggerStartupBiometrics()
        }
    }
    
    private func handleScannedQRCode(_ code: String) {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.lowercased().hasPrefix("mycolab://hub") || clean.lowercased().hasPrefix("mycolab://pair-hub") || (clean.contains(":8088") && clean.contains("http")) {
            if let url = URL(string: clean) {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                   let items = components.queryItems {
                    if let host = items.first(where: { $0.name == "host" || $0.name == "ip" })?.value, !host.isEmpty {
                        store.db.environmentConfig.piHubIP = host
                        if let portStr = items.first(where: { $0.name == "port" })?.value, let p = Int(portStr) {
                            store.db.environmentConfig.piHubPort = p
                        }
                        store.saveImmediately()
                        MycoSyncManager.shared.triggerToast(message: "🍓 MycoLab Hub: \(host)")
                        selectedTab = 3
                        return
                    }
                } else if let host = url.host {
                    store.db.environmentConfig.piHubIP = host
                    if let port = url.port { store.db.environmentConfig.piHubPort = port }
                    store.saveImmediately()
                    MycoSyncManager.shared.triggerToast(message: "🍓 MycoLab Hub: \(host)")
                    selectedTab = 3
                    return
                }
            }
        }
        if let proj = store.db.projects.first(where: {
            clean.localizedCaseInsensitiveContains($0.qrCodeID) || $0.qrCodeID.localizedCaseInsensitiveContains(clean)
        }) {
            scannedProject = proj
            return
        }
        if let cult = store.db.cultures.first(where: {
            clean.localizedCaseInsensitiveContains($0.qrCodeID) || $0.qrCodeID.localizedCaseInsensitiveContains(clean)
        }) {
            scannedCulture = cult
            return
        }
        if let supply = store.db.supplies.first(where: {
            clean.localizedCaseInsensitiveContains($0.qrCodeID) || (!clean.isEmpty && $0.qrCodeID.localizedCaseInsensitiveContains(clean))
        }) {
            scannedSupply = supply
            return
        }
        if clean.contains("MYCOLAB-STASH") || store.db.stash.contains(where: {
            clean.localizedCaseInsensitiveContains($0.qrCodeID) || $0.qrCodeID.localizedCaseInsensitiveContains(clean)
        }) {
            selectedTab = 2
            return
        }
        
        if clean.contains("MYCOLAB") || clean.contains("PROCES") || clean.contains("VERIFICATIE") || clean.contains("TRACEERBAARHEID") || clean.contains("Herkomst") {
            scannedDossierText = clean
            return
        }
        
        scanErrorAlert = true
    }
}


// MARK: - CLASSIC TAB VIEWS EXTRACTED TO ClassicLabViews.swift



// MARK: - SCANNER, VISION & QR STUDIO EXTRACTED TO MycoScannerAndVisionViews.swift


// MARK: - SETTINGS & ONBOARDING SUITE EXTRACTED TO MycoSettingsAndOnboardingViews.swift

// MARK: - Picture-in-Picture Floating Mini Player
private struct FloatingCameraPiPView: View {
    let track: VideoTrack
    @ObservedObject var liveKitManager = LiveKitStreamManager.shared
    @EnvironmentObject var store: MycoStore
    @State private var dragOffset: CGSize = .zero
    var onExpand: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SwiftUIVideoView(track, layoutMode: .fill)
                .frame(width: 148, height: 100)
                .cornerRadius(14)
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MycoTheme.blue.opacity(0.7), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.55), radius: 10, y: 4)

            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text("LIVE")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.75))
                .cornerRadius(4)

                Spacer()

                Button {
                    onExpand()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        liveKitManager.showFloatingPiP = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(6)

            VStack {
                Spacer()
                HStack {
                    if let hum = store.latestSensorHumidityPct {
                        Text("\(Int(hum))% RV")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    if let temp = store.latestSensorTempC {
                        Text("\(String(format: "%.1f", temp))°C")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    Spacer()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.75))
                .cornerRadius(4)
                .padding(6)
            }
        }
        .frame(width: 148, height: 100)
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { _ in }
        )
        .onTapGesture {
            onExpand()
        }
    }
}
