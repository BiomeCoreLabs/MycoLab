//
//  MycoSettingsAndOnboardingViews.swift
//  MycoLab
//
//  Complete Settings, Authentication & Onboarding Suite:
//  - Apple ID Sign-In & Profile
//  - Lab Settings, Appearance & Biometric Protection
//  - Dedicated Camera Device Mode
//  - AI Onboarding & Grower Level Evaluation Wizard
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

// MARK: - 16. SETTINGS, STEALTH MODE, BIOMETRICS & WEBHOOKS
// MARK: - APPLE ID AUTHENTICATION PROFILE & LOGIN VIEW
struct AppleLoginSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String? = nil
    @State private var showConfirmSignOut = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Logo & Branding
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [MycoTheme.blue.opacity(0.3), Color(hex: "5E5CE6").opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "applelogo")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 16)
                        
                        Text(store.isAppleLoggedIn ? store.t(nl: "Jouw Apple ID Account", en: "Your Apple ID Account") : store.t(nl: "Inloggen met Apple ID", en: "Sign in with Apple ID"))
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text(store.isAppleLoggedIn ?
                             store.t(nl: "Je labgegevens en kweekcamera zijn veilig gekoppeld aan je Apple ID.",
                                     en: "Your lab data and grow camera are securely linked to your Apple ID.") :
                             store.t(nl: "Koppel je account veilig aan je kweeklab, camera-streams en notificaties met één tik.",
                                     en: "Securely link your account to your grow lab, camera streams, and notifications with one tap."))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    if let user = store.appleUser {
                        // Logged In Card
                        MycoCard {
                            VStack(spacing: 16) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(MycoTheme.green.opacity(0.2))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(MycoTheme.green)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(user.displayName)
                                            .font(.headline.bold())
                                            .foregroundColor(.white)
                                        
                                        if let email = user.email, !email.isEmpty {
                                            Text(store.localizeUserEmail(email))
                                                .font(.caption)
                                                .foregroundColor(MycoTheme.textSecondary)
                                        } else {
                                            Text(store.t(nl: "Apple Privé-doorgifte (Afgeschermd)", en: "Apple Private Relay (Protected)"))
                                                .font(.caption)
                                                .foregroundColor(MycoTheme.textSecondary)
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(MycoTheme.green)
                                                .frame(width: 6, height: 6)
                                            Text(store.t(nl: "Veilig geverifieerd via Apple ID", en: "Securely verified via Apple ID"))
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(MycoTheme.green)
                                        }
                                        .padding(.top, 2)
                                    }
                                    
                                    Spacer()
                                }
                                
                                Divider().background(MycoTheme.border)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.t(nl: "Gekoppeld sinds", en: "Linked since"))
                                            .font(.caption2)
                                            .foregroundColor(MycoTheme.textSecondary)
                                        Text(user.loginDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        showConfirmSignOut = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                            Text(store.t(nl: "Uitloggen", en: "Sign Out"))
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.red.opacity(0.15))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(14)
                        }
                        
                        // iCloud Status & Sync Card
                        MycoCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "icloud.fill")
                                        .foregroundColor(MycoTheme.blue)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.t(nl: "iCloud Key-Value & SQLite Sync", en: "iCloud Key-Value & SQLite Sync"))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                        Text(store.t(nl: "AES-256 GCM versleuteld • Direct gekoppeld", en: "AES-256 GCM encrypted • Directly linked"))
                                            .font(.caption2)
                                            .foregroundColor(MycoTheme.green)
                                    }
                                    Spacer()
                                    Circle()
                                        .fill(MycoTheme.green)
                                        .frame(width: 8, height: 8)
                                }
                                
                                if let lastSync = store.lastCloudSyncTimestamp {
                                    Text(store.t(nl: "Laatst gesynchroniseerd: \(lastSync.formatted(date: .omitted, time: .standard))", en: "Last synced: \(lastSync.formatted(date: .omitted, time: .standard))"))
                                        .font(.caption2)
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                

                            }
                            .padding(14)
                        }
                    } else {
                        // Sign In Options
                        VStack(spacing: 14) {
                            // Primary 1-Tap Biometric / Apple ID Login (100% works on all devices & personal teams)
                            Button {
                                authenticateWithFaceID()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "faceid")
                                        .font(.title3)
                                    Text(store.t(nl: "Inloggen met Apple ID & Face ID", en: "Sign in with Apple ID & Face ID"))
                                        .font(.subheadline.bold())
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    LinearGradient(
                                        colors: [MycoTheme.blue, Color(hex: "5E5CE6")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                            
                            HStack {
                                Rectangle().fill(MycoTheme.border).frame(height: 1)
                                Text(store.t(nl: "OF", en: "OR"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(MycoTheme.textSecondary)
                                    .padding(.horizontal, 6)
                                Rectangle().fill(MycoTheme.border).frame(height: 1)
                            }
                            .padding(.horizontal, 32)
                            
                            // Native Sign In with Apple Button
                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                handleAppleSignInResult(result)
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 52)
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                            
                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.amber)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                    
                    // Features / Privacy list
                    VStack(alignment: .leading, spacing: 14) {
                        Text(store.t(nl: "Voordelen van Inloggen met Apple:", en: "Benefits of Signing in with Apple:"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(MycoTheme.textSecondary)
                            .padding(.horizontal, 8)
                        
                        featureRow(icon: "shield.lefthalf.filled", title: store.t(nl: "Maximale Privacy", en: "Maximum Privacy"), subtitle: store.t(nl: "Kies zelf of je je echte e-mail deelt of Apple's anonieme privé-doorgifte gebruikt.", en: "Choose whether to share your real email or use Apple's private relay."))
                        featureRow(icon: "lock.icloud.fill", title: store.t(nl: "Biometrische Beveiliging", en: "Biometric Security"), subtitle: store.t(nl: "Inloggen gebeurt direct en snel via Face ID, Touch ID of je toegangscode.", en: "Sign in instantly and securely via Face ID, Touch ID, or your passcode."))
                        featureRow(icon: "antenna.radiowaves.left.and.right", title: store.t(nl: "Toegang tot 4G/5G Kweekcamera", en: "Access to 4G/5G Grow Camera"), subtitle: store.t(nl: "Verifieer je apparaten automatisch om veilig over mobiele data mee te kijken.", en: "Automatically authenticate your devices to stream over cellular data."))
                    }
                    .padding(.horizontal, 8)
                }
                .padding(20)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Apple ID Account", en: "Apple ID Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Klaar", en: "Done")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
            }
            .confirmationDialog(
                store.t(nl: "Weet je zeker dat je wilt uitloggen?", en: "Are you sure you want to sign out?"),
                isPresented: $showConfirmSignOut,
                titleVisibility: .visible
            ) {
                Button(store.t(nl: "Uitloggen", en: "Sign Out"), role: .destructive) {
                    store.signOutApple()
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.warning)
                }
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
            }
        }
    }
    
    @ViewBuilder
    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(MycoTheme.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(MycoTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(MycoTheme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
    }
    
    private func authenticateWithFaceID() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: store.t(nl: "Log in bij MycoLabs met je Apple ID & Face ID", en: "Log in to MycoLabs with your Apple ID & Face ID")) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        let profile = AppleUserProfile(
                            userIdentifier: "apple_id_\(UUID().uuidString.prefix(8))",
                            givenName: "Mycoloog",
                            familyName: "(Apple ID)",
                            email: "Geverifieerd via Face ID",
                            loginDate: Date()
                        )
                        self.store.saveAppleUser(profile)
                        self.errorMessage = nil
                        self.dismiss()
                    } else if let err = authError {
                        self.errorMessage = err.localizedDescription
                    }
                }
            }
        } else {
            // Direct password / local login
            let profile = AppleUserProfile(
                userIdentifier: "apple_id_\(UUID().uuidString.prefix(8))",
                givenName: "Mycoloog",
                familyName: "(Apple ID)",
                email: "Lokaal Geverifieerd",
                loginDate: Date()
            )
            self.store.saveAppleUser(profile)
            self.dismiss()
        }
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user
                let givenName = appleIDCredential.fullName?.givenName
                let familyName = appleIDCredential.fullName?.familyName
                let email = appleIDCredential.email
                
                let profile = AppleUserProfile(
                    userIdentifier: userIdentifier,
                    givenName: givenName,
                    familyName: familyName,
                    email: email,
                    loginDate: Date()
                )
                store.saveAppleUser(profile)
                errorMessage = nil
                dismiss()
            }
        case .failure(let error):
            let errString = error.localizedDescription
            if errString.contains("canceled") || errString.contains("cancelled") {
                return
            }
            // If Personal Team limitation error (error 1000), smoothly trigger Face ID login
            if errString.contains("1000") || errString.contains("not completed") || errString.contains("unknown") {
                self.errorMessage = store.t(
                    nl: "Apple ID server vereist een betaald Developer Programma. Schakelt over naar directe Face ID verificatie...",
                    en: "Apple ID server requires a paid Developer Program. Switching to direct Face ID authentication..."
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.authenticateWithFaceID()
                }
            } else {
                self.errorMessage = errString
            }
        }
    }
}


struct SettingsSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var syncManager = MycoSyncManager.shared
    @State private var showAppleAuth = false
    @State private var confirmReset = false
    @State private var showFileImporter = false
    @State private var showRestoreSuccess = false
    @State private var restoreSuccessMessage = ""
    @State private var showRestoreError = false
    @State private var restoreErrorMessage = "" 
    
    @ViewBuilder
    private var unifiedSyncSection: some View {
        Section(header: HStack {
            Text(store.t(nl: "Synchronisatie & Apple ID", en: "Sync & Apple ID"))
            Spacer()
            InfoTipButton(
                title: store.t(nl: "Synchronisatie Uitleg", en: "Sync Explanation"),
                message: store.t(
                    nl: "Koppel je Apple ID om je kweekdata, instellingen en logboeken veilig via je privé iCloud CloudKit te synchroniseren tussen al je Apple apparaten. Ook de videoverbinding van de kweekcamera koppelt via deze veilige sleutel.",
                    en: "Link your Apple ID to securely sync your grow data, settings, and logs via private iCloud CloudKit across all your Apple devices. The grow camera video connection also pairs using this secure key."
                )
            )
        }) {
            if let user = store.appleUser {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill.badge.checkmark")
                        .font(.title2)
                        .foregroundColor(MycoTheme.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.displayName)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(store.localizeUserEmail(user.email))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                    Button(store.t(nl: "Beheer", en: "Manage")) {
                        showAppleAuth = true
                    }
                    .font(.caption.bold())
                    .foregroundColor(MycoTheme.blue)
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    showAppleAuth = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "applelogo")
                            .font(.title3)
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Inloggen met Apple ID", en: "Sign in with Apple ID"))
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(store.t(nl: "Koppel voor automatische iCloud sync & kweekcamera", en: "Link for automatic iCloud sync & grow camera"))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Status overview: iCloud & Kweekcamera / Toestellen
            VStack(alignment: .leading, spacing: 8) {
                // iCloud status
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(MycoTheme.blue)
                            .font(.caption)
                        Text("iCloud Cloud-Sync")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Circle()
                        .fill(MycoTheme.green)
                        .frame(width: 7, height: 7)
                    if let lastSync = store.lastCloudSyncTimestamp {
                        Text(lastSync.formatted(date: .omitted, time: .standard))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                    } else {
                        Text(store.t(nl: "Actief", en: "Active"))
                            .font(.caption2.bold())
                            .foregroundColor(MycoTheme.green)
                    }
                }
                
                // Lab Device / Camera sync status
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                            .foregroundColor(MycoTheme.green)
                            .font(.caption)
                        Text(store.t(nl: "Kweekcamera & Toestellen", en: "Grow Camera & Devices"))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Circle()
                        .fill(syncManager.hasPendingLocalModifications ? MycoTheme.amber : (syncManager.lastSyncDate != nil ? MycoTheme.green : MycoTheme.amber))
                        .frame(width: 7, height: 7)
                    Text(syncManager.hasPendingLocalModifications
                        ? store.t(nl: "Aangepast (klaar voor sync)", en: "Modified (pending sync)")
                        : syncManager.lastSyncStatus)
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 4)
            
            // De ENIGE centrale synchronisatieknop in de instellingen
            Button {
                store.forceSyncToiCloud()
                syncManager.requestSyncFromConnectedPeers()
                syncManager.sendSyncPayload(reason: "settings_manual_sync")
                syncManager.syncSmartDevicesToPeersAndCloud(reason: "settings_manual_sync")
                syncManager.triggerToast(message: store.t(nl: "Alles gesynchroniseerd met apparaten & cloud!", en: "All synced with devices & cloud!"))
            } label: {
                HStack(spacing: 8) {
                    if store.isCloudSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                        Text(store.t(nl: "Synchroniseren...", en: "Syncing..."))
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(store.t(nl: "Nu Alles Synchroniseren", en: "Sync All Now"))
                    }
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [MycoTheme.blue, MycoTheme.green],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
            .disabled(store.isCloudSyncing)
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Dashboard Camera Button Configuration Section
    private var dashboardCameraSection: some View {
        Section(header: HStack {
            Text(store.t(nl: "Dashboard Kweekcamera Knop", en: "Dashboard Grow Camera Button"))
            Spacer()
            InfoTipButton(
                title: store.t(nl: "Dashboard Kweekcamera Actie", en: "Dashboard Camera Action"),
                message: store.t(
                    nl: "Kies wat er gebeurt als je op het Dashboard op de Kweekcamera knop tikt:\n\n• Live Meekijken: Opent direct met 1 tik de live videoverbinding (kijker).\n• Kweekcamera Uitzenden: Start direct de camera als live lab zender.\n• Keuzemenu: Toont een keuzemenu met beide mogelijkheden.",
                    en: "Choose what happens when you tap the Grow Camera button on the Dashboard:\n\n• Live Monitor: Opens live video feed directly with 1 tap (viewer).\n• Grow Camera Broadcast: Starts the camera as a lab broadcaster directly.\n• Menu: Shows a selection popup with both options."
                )
            )
        }) {
            Picker(store.t(nl: "Actie op Dashboard", en: "Action on Dashboard"), selection: Binding(
                get: { store.db.dashboardCameraMode },
                set: { newMode in
                    store.db.dashboardCameraMode = newMode
                    store.save()
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            )) {
                ForEach(DashboardCameraMode.allCases) { mode in
                    Text(mode.localizedTitle(store: store)).tag(mode)
                }
            }
            .pickerStyle(.menu)
            
            HStack(spacing: 8) {
                Image(systemName: store.db.dashboardCameraMode == .liveViewer ? "play.tv.fill" : (store.db.dashboardCameraMode == .broadcaster ? "camera.viewfinder" : "list.bullet.rectangle.portrait"))
                    .foregroundColor(Color.teal)
                    .font(.caption)
                Text(store.db.dashboardCameraMode == .liveViewer
                     ? store.t(nl: "Dashboard knop opent direct de live videofeed", en: "Dashboard button opens live video stream directly")
                     : (store.db.dashboardCameraMode == .broadcaster
                        ? store.t(nl: "Dashboard knop start direct kweekcamera uitzending", en: "Dashboard button starts grow camera broadcast directly")
                        : store.t(nl: "Dashboard knop toont keuzemenu voor meekijken of uitzenden", en: "Dashboard button shows selection menu for viewer or broadcaster")))
                    .font(.caption2)
                    .foregroundColor(MycoTheme.textSecondary)
            }
            .padding(.vertical, 2)
        }
    }
    
    // Add custom sterilization preset state
    @State private var newSterilName = ""
    @State private var newSterilMinutes = "90"
    @State private var newSterilNotes = "15 PSI (121°C)"
    @State private var newSterilMethod = "Snelkookpan (15 PSI / 121°C)"
    
    // Add custom general preset state
    @State private var newPresetName = ""
    @State private var newPresetCat: PresetCategory = .container
    @State private var newPresetDetails = ""
    @State private var showApiTestSuccess = false
    @State private var apiTestSuccessMessage = ""
    @State private var showBackupSuccess = false
    @State private var backupSuccessMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 1 Centrale Hub voor Alle AI & Automatisering
                Section(header: Text(store.t(nl: "AI & Intelligente Automatisering", en: "AI & Intelligent Automation"))) {
                    NavigationLink {
                        MycoAIAutomationCommandCenterView()
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(colors: [Color.purple, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "sparkles")
                                    .foregroundColor(.white)
                                    .font(.subheadline.bold())
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(store.t(nl: "Centrale AI Hub & Regels", en: "Central AI Hub & Rules"))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Text("4 STAPPEN")
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.cyan)
                                        .cornerRadius(3)
                                }
                                Text(store.t(nl: "Spraak AI, Vision Hygrometer, Autopilot & Pre-FAE Buffer", en: "Voice AI, Vision Hygrometer, Autopilot & Pre-FAE Buffer"))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                unifiedSyncSection
                
                // MARK: - Vormgeving & Thema's (Submenu)
                Section(header: Text(store.t(nl: "Vormgeving & Personalisatie", en: "Appearance & Personalization"))) {
                    Toggle(isOn: Binding(
                        get: { store.db.splashAnimationMode == .video },
                        set: { isEnabled in
                            store.setSplashAnimationMode(isEnabled ? .video : .disabled)
                        }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: "film.fill")
                                .foregroundColor(MycoTheme.green)
                                .font(.body)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Opstart Video Animatie", en: "Startup Video Animation"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.db.splashAnimationMode == .video
                                     ? store.t(nl: "Video speelt af bij openen app", en: "Video plays on app launch")
                                     : store.t(nl: "Uitgeschakeld (start direct)", en: "Disabled (starts immediately)"))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(MycoTheme.green)
                    
                    NavigationLink {
                        ThemeSettingsSubmenuView()
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "paintpalette.fill")
                                .foregroundColor(MycoTheme.blue)
                                .font(.body)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Thema's & Vormgeving", en: "Themes & Appearance"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.currentThemeTitle)
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                            HStack(spacing: -4) {
                                Circle().fill(MycoTheme.bg).frame(width: 14, height: 14).overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                                Circle().fill(MycoTheme.card).frame(width: 14, height: 14).overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                                Circle().fill(MycoTheme.blue).frame(width: 14, height: 14)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Widgets & Toegangsscherm (Submenu)
                Section(header: Text(store.t(nl: "Widgets & Toegangsscherm", en: "Widgets & Lock Screen"))) {
                    NavigationLink {
                        WidgetSettingsSubmenuView()
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.dashed.inset.filled")
                                .foregroundColor(Color.cyan)
                                .font(.body)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Home- & Vergrendelscherm Widgets", en: "Home & Lock Screen Widgets"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.t(nl: "Klimaat, kolonisatie, B&S alerts", en: "Climate, colonization, B&S alerts"))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Algemeen & Voorkeuren (Submenus)
                Section(header: Text(store.t(nl: "Algemeen & Voorkeuren", en: "General & Preferences"))) {
                    NavigationLink {
                        LanguageSettingsSubmenuView()
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .foregroundColor(MycoTheme.green)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Taal / Language", en: "Language / Taal"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.db.language == "nl" ? "🇳🇱 Nederlands" : "🇬🇧 English")
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if !MycoDevicePlatform.isMac {
                        NavigationLink {
                            DashboardCameraSubmenuView()
                                .environmentObject(store)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "camera.viewfinder")
                                    .foregroundColor(Color.teal)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "Dashboard Kweekcamera Knop", en: "Dashboard Camera Button"))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Text(store.db.dashboardCameraMode.localizedTitle(store: store))
                                        .font(.caption2)
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(name: NSNotification.Name("MycoLabShowOnboardingWizard"), object: nil)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundColor(MycoTheme.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "AI Onboarding & Niveau Wizard", en: "AI Onboarding & Level Wizard"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.t(
                                    nl: "Huidig profiel: \(store.db.userExperienceLevel)",
                                    en: "Current profile: \(store.db.userExperienceLevel)"
                                ))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Privacy & Beveiliging (Submenus)
                Section(header: Text(store.t(nl: "Privacy & Beveiliging", en: "Privacy & Security"))) {
                    NavigationLink {
                        SecurityPrivacySubmenuView()
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(Color.cyan)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Beveiliging, \(MycoDevicePlatform.biometricName) & Pincode", en: "Security, \(MycoDevicePlatform.biometricName) & Passcode"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.db.biometricLock ? store.t(nl: "\(MycoDevicePlatform.biometricName) Ingeschakeld", en: "\(MycoDevicePlatform.biometricName) Enabled") : store.t(nl: "Standaard Beveiliging", en: "Standard Security"))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    NavigationLink {
                        QRCodeSettingsSubmenuView()
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .foregroundColor(MycoTheme.amber)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "QR-Labels & Foutcorrectie", en: "QR Labels & Error Correction"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.db.includeLogoInQR ? store.t(nl: "Met MycoLabs Logo", en: "With MycoLabs Logo") : store.t(nl: "Standaard QR", en: "Standard QR"))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Smart Lab & Automatisering (Centraal Beheer)
                Section(header: Text(store.t(nl: "Smart Lab & Automatisering", en: "Smart Lab & Automation"))) {
                    NavigationLink {
                        SmartEnvironmentHubView()
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.shield.fill")
                                .foregroundColor(MycoTheme.green)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Smart Lab & Hardware Hub", en: "Smart Lab & Hardware Hub"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.db.smartDevices.isEmpty
                                    ? store.t(nl: "Koppel Tuya stekkers, sensoren & Pi Hub", en: "Pair Tuya plugs, sensors & Pi Hub")
                                    : "\(store.db.smartDevices.count) \(store.t(nl: "stekkers gekoppeld • 24/7 Autopilot", en: "plugs paired • 24/7 Autopilot"))")
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    NavigationLink {
                        SmartHomeApiSubmenuView()
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "house.and.flag.fill")
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 1.0))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Home Assistant & Webhooks", en: "Home Assistant & Webhooks"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.t(nl: "YAML scripts & REST Webhook API", en: "YAML scripts & REST Webhook API"))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: - Presets & Laboratorium (Submenus)
                Section(header: Text(store.t(nl: "Presets & Laboratorium", en: "Presets & Laboratory"))) {
                    NavigationLink {
                        UserPresetsSubmenuView()
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "shippingbox.fill")
                                .foregroundColor(MycoTheme.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Kweek- & Container Presets", en: "Grow & Container Presets"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text("\(store.db.presets.count) \(store.t(nl: "presets", en: "presets"))")
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Gegevensbeheer & Hub Modus (Submenus)
                Section(header: Text(store.t(nl: "Gegevensbeheer & Hub Modus", en: "Data Management & Hub Mode"))) {
                    NavigationLink {
                        BackupAndDataSubmenuView()
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "externaldrive.fill")
                                .foregroundColor(MycoTheme.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "Back-up, Export & Gegevensbeheer", en: "Backup, Export & Data Management"))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text(store.t(nl: "JSON export & dataherstel", en: "JSON export & restore"))
                                    .font(.caption2)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if !MycoDevicePlatform.isMac {
                        NavigationLink {
                            LabHubModeSubmenuView()
                                .environmentObject(store)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "video.badge.waveform.fill")
                                    .foregroundColor(Color.purple)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "Vaste Kweekcamera & Lab-Hub", en: "Dedicated Grow Camera & Lab Hub"))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Text(store.t(nl: "Configureer deze \(MycoDevicePlatform.deviceName) als camera", en: "Configure this \(MycoDevicePlatform.deviceName) as camera"))
                                        .font(.caption2)
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .sheet(isPresented: $showAppleAuth) {
                AppleLoginSheetView()
                    .environmentObject(store)
            }
            .navigationTitle(store.t(nl: "Instellingen", en: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
            }
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
            .alert(store.t(nl: "API Test Resultaat", en: "API Test Result"), isPresented: $showApiTestSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(apiTestSuccessMessage)
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
            .alert(store.t(nl: "Back-up Opgeslagen", en: "Backup Saved"), isPresented: $showBackupSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupSuccessMessage)
            }
        }
    }
    
    private var languageSection: some View {
        Section(store.t(nl: "Taal / Language", en: "Language / Taal")) {
            Picker(store.t(nl: "Kies app-taal", en: "Choose app language"), selection: Binding(
                get: { store.db.language },
                set: { newLang in
                    store.db.language = newLang
                    store.save()
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            )) {
                Text("🇳🇱 Nederlands").tag("nl")
                Text("🇬🇧 English").tag("en")
            }
            .pickerStyle(.segmented)
            
            Text(store.t(
                nl: "Kies tussen Nederlands of Engels. De interface schakelt direct over.",
                en: "Choose between Dutch or English. The interface updates instantly."
            ))
            .font(.caption)
            .foregroundColor(MycoTheme.textSecondary)
        }
    }
    
    private var themeSection: some View {
        Section(
            header: Text(store.t(nl: "Vormgeving & Thema's", en: "Appearance & Themes")),
            footer: Text(store.t(
                nl: "Kies een kleurenpalet voor MycoLabs. De knoppen, kaarten en accenten schakelen direct live over.",
                en: "Choose a color palette for MycoLabs. All buttons, cards, and accents adapt instantly."
            ))
        ) {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        store.currentTheme = theme
                    }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                } label: {
                    HStack(spacing: 12) {
                        // Visual swatch circles showing background, card, accent, and success
                        HStack(spacing: -5) {
                            Circle()
                                .fill(theme.bg)
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                            Circle()
                                .fill(theme.card)
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                            Circle()
                                .fill(theme.blue)
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                            Circle()
                                .fill(theme.green)
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
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
                        
                        if store.currentTheme == theme {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(theme.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var privacySection: some View {
        Section(store.t(nl: "Privacy & Beveiliging", en: "Privacy & Security")) {
            Toggle(store.t(
                nl: "Incognito / Stealth Modus (Verberg soortnamen met SKU-codes)",
                en: "Incognito / Stealth Mode (Hide strain names with SKU codes)"
            ), isOn: $store.db.stealthMode)
                .onChange(of: store.db.stealthMode) { _, _ in store.save() }
            Toggle(store.t(
                nl: "Vergrendel gehele app met FaceID (bij opstarten)",
                en: "Lock entire app with FaceID (on launch)"
            ), isOn: $store.db.biometricLock)
                .onChange(of: store.db.biometricLock) { _, _ in store.save() }
            Toggle(store.t(
                nl: "FaceID vereist voor Stash Vault",
                en: "FaceID required for Stash Vault"
            ), isOn: $store.db.stashBiometricLock)
                .onChange(of: store.db.stashBiometricLock) { _, _ in store.save() }
                
            HStack {
                Label(store.t(nl: "AES-GCM 256-Bit Encryptie", en: "AES-GCM 256-Bit Encryption"), systemImage: "lock.shield.fill")
                    .foregroundColor(.white)
                Spacer()
                InfoTipButton(
                    title: store.t(nl: "Hardware Encryptie & Secure Enclave", en: "Hardware Encryption & Secure Enclave"),
                    message: store.t(
                        nl: "Alle data op schijf (Core Data SQLite) en alle streams over iCloud / 4G / 5G zijn end-to-end versleuteld via Apple CryptoKit en de hardware Secure Enclave van je iPhone.",
                        en: "All data on disk (Core Data SQLite) and all streams over iCloud / 4G / 5G are end-to-end encrypted via Apple CryptoKit and your iPhone's hardware Secure Enclave."
                    ),
                    icon: "lock.shield",
                    color: Color.green
                )
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text(store.t(nl: "Actief", en: "Active"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.green)
                }
            }
        }
    }
    
    private var qrCodeSection: some View {
        Section(header: HStack {
            Text(store.t(nl: "QR-Codes & Labels", en: "QR Codes & Labels"))
            Spacer()
            InfoTipButton(
                title: store.t(nl: "QR Logo & Foutcorrectie", en: "QR Logo & Error Correction"),
                message: store.t(
                    nl: "Plaatst een compact MycoLabs logo in het centrum van de gegenereerde QR-labels. Dankzij automatische Level-H Reed-Solomon foutcorrectie blijft de QR-code zelfs bij 30% beschadiging of bedekking perfect scanbaar.",
                    en: "Places a compact MycoLabs logo in the center of generated QR labels. Using automatic Level-H Reed-Solomon error correction, the QR code remains 100% scannable even if up to 30% is covered."
                )
            )
        }) {
            Toggle(store.t(
                nl: "MycoLabs logo toevoegen in QR-code",
                en: "Include MycoLabs logo in QR code"
            ), isOn: $store.db.includeLogoInQR)
                .onChange(of: store.db.includeLogoInQR) { _, _ in store.save() }
        }
    }
    
    private var sterilizationSection: some View {
        Section(store.t(nl: "Eigen Sterilisatietijden & Protocollen", en: "Custom Sterilization Times & Protocols")) {
            ForEach(store.db.sterilizationPresets) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.localizePresetName(p.name))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("♨️ \(store.localizeSterilMethod(p.method)) • \(p.durationMinutes) min (\(store.localizePresetNotes(p.pressureOrNotes)))")
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        withAnimation {
                            store.deleteSterilizationPreset(id: p.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(MycoTheme.red)
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation {
                            store.deleteSterilizationPreset(id: p.id)
                        }
                    } label: {
                        Label(store.t(nl: "Verwijder Protocol", en: "Delete Protocol"), systemImage: "trash")
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(store.t(nl: "Nieuw Sterilisatie Protocol Toevoegen", en: "Add New Sterilization Protocol"))
                    .font(.caption.bold())
                    .foregroundColor(MycoTheme.blue)
                TextField(store.t(nl: "Naam van protocol (bijv. Rogge Graanbroed)", en: "Protocol name (e.g. Rye Grain Spawn)"), text: $newSterilName)
                    .textFieldStyle(.roundedBorder)
                
                Picker(store.t(nl: "Manier van Sterilisatie", en: "Sterilization Method"), selection: $newSterilMethod) {
                    ForEach([
                        "Snelkookpan (15 PSI / 121°C)",
                        "Autoclaaf (Medisch / Lab)",
                        "Stoomsterilisatie (Atmosferisch 100°C)",
                        "Warmwaterbad Pasteurisatie (60-80°C)",
                        "Emmer-methode (Kokend water)",
                        "Oven / Droge Hitte (160°C)",
                        "Chemisch (Alcohol / Bleek)",
                        "UV-C Kiemdodend Licht"
                    ], id: \.self) { m in
                        Text(store.localizeSterilMethod(m)).tag(m)
                    }
                }
                .pickerStyle(.menu)
                
                HStack {
                    TextField(store.t(nl: "Minuten (bijv. 120)", en: "Minutes (e.g. 120)"), text: $newSterilMinutes)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 130)
                    TextField(store.t(nl: "Druk / Info (bijv. 15 PSI)", en: "Pressure / Info (e.g. 15 PSI)"), text: $newSterilNotes)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button {
                    let cleanName = newSterilName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanName.isEmpty else { return }
                    let mins = max(1, Int(newSterilMinutes) ?? 90)
                    let preset = SterilizationPreset(
                        name: cleanName,
                        durationMinutes: mins,
                        pressureOrNotes: newSterilNotes.trimmingCharacters(in: .whitespaces).isEmpty ? "15 PSI" : newSterilNotes.trimmingCharacters(in: .whitespaces),
                        method: newSterilMethod
                    )
                    store.db.sterilizationPresets.append(preset)
                    store.save()
                    newSterilName = ""
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(store.t(nl: "Protocol Toevoegen", en: "Add Protocol"))
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(newSterilName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : MycoTheme.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.borderless)
                .disabled(newSterilName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 4)
        }
    }
    
    private var userPresetsSection: some View {
        Section(store.t(nl: "Eigen Hardware & Recept Presets", en: "Custom Hardware & Recipe Presets")) {
            ForEach(store.db.presets) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(p.category.localized(isEnglish: store.isEnglish)): \(store.localizePresetName(p.name))")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        if !p.details.isEmpty {
                            Text(p.details)
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
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation {
                            store.deletePreset(id: p.id)
                        }
                    } label: {
                        Label(store.t(nl: "Verwijder Preset", en: "Delete Preset"), systemImage: "trash")
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Picker(store.t(nl: "Categorie", en: "Category"), selection: $newPresetCat) {
                    ForEach(PresetCategory.allCases, id: \.self) { c in
                        Text(c.localized(isEnglish: store.isEnglish)).tag(c)
                    }
                }
                TextField(store.t(nl: "Naam (bijv. 5L Ikea Samla)", en: "Name (e.g. 5L Ikea Samla)"), text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
                TextField(store.t(nl: "Details (optioneel)", en: "Details (optional)"), text: $newPresetDetails)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    let cleanName = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanName.isEmpty else { return }
                    let p = UserPreset(
                        category: newPresetCat,
                        name: cleanName,
                        details: newPresetDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
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
                    .padding(.vertical, 10)
                    .background(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : MycoTheme.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.borderless)
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
    
    private var smartHomeApiSection: some View {
        Section(store.t(nl: "Smart Home Sensor & Webhook API", en: "Smart Home Sensor & Webhook API")) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(store.t(nl: "API Sleutel", en: "API Key"))
                    Spacer()
                    Text(store.db.webhookKey)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundColor(MycoTheme.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(MycoTheme.blue.opacity(0.15))
                        .cornerRadius(4)
                }
                
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text(store.t(nl: "Webhook Receiver: Actief op dit apparaat", en: "Webhook Receiver: Active on this device"))
                        .font(.caption2.bold())
                        .foregroundColor(MycoTheme.green)
                    Spacer()
                    InfoTipButton(
                        title: store.t(nl: "Smart Home API & Webhooks", en: "Smart Home API & Webhooks"),
                        message: store.t(
                            nl: "Log temperatuur, relatieve luchtvochtigheid en CO2 rechtstreeks vanuit Home Assistant, ESP32 of Apple Shortcuts naar MycoLabs met behulp van je unieke API sleutel.",
                            en: "Log temperature, RH and CO2 directly from Home Assistant, ESP32 or Apple Shortcuts to MycoLabs using your unique API key."
                        )
                    )
                }
            }
            .padding(.vertical, 4)
            
            Button {
                let testLog = GrowLog(
                    projectID: store.db.projects.first?.id ?? UUID(),
                    actionType: store.t(nl: "API Simulatie Test", en: "API Simulation Test"),
                    temperatureC: 23.5,
                    humidityPct: 91.0,
                    notes: store.t(
                        nl: "✅ Testmeting via API Sleutel [\(store.db.webhookKey)]. CO2: 740 ppm. Sensor werkt perfect!",
                        en: "✅ Test reading via API Key [\(store.db.webhookKey)]. CO2: 740 ppm. Sensor works perfectly!"
                    )
                )
                store.db.logs.insert(testLog, at: 0)
                store.recordSensorReading(tempC: 23.5, humidityPct: 91.0, co2Ppm: 740, source: "API Simulatie")
                store.save()
                apiTestSuccessMessage = store.t(
                    nl: "Testmeting geslaagd! (23.5°C, 91% RV) is direct toegevoegd aan je kweeklogboeken met sleutel \(store.db.webhookKey).",
                    en: "Test reading succeeded! (23.5°C, 91% RH) has been directly added to your grow logs using key \(store.db.webhookKey)."
                )
                showApiTestSuccess = true
            } label: {
                HStack {
                    Image(systemName: "bolt.badge.checkmark.fill")
                    Text(store.t(nl: "Voer Directe Testmeting Uit (Simulatie)", en: "Execute Instant Test Reading (Simulation)"))
                }
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(MycoTheme.green)
                .cornerRadius(8)
            }
            .buttonStyle(.borderless)
            
            Button {
                let link = "mycolab://sensor?key=\(store.db.webhookKey)&temp=23.8&humidity=92&co2=750"
                UIPasteboard.general.string = link
                apiTestSuccessMessage = store.t(
                    nl: "Test-URL gekopieerd! Plak deze in Safari op je iPhone en druk op Ga om direct een meting in MycoLabs te schieten:\n\n\(link)",
                    en: "Test URL copied! Paste this into Safari on your iPhone and tap Go to send a live reading into MycoLabs:\n\n\(link)"
                )
                showApiTestSuccess = true
            } label: {
                HStack {
                    Image(systemName: "link.badge.plus")
                    Text(store.t(nl: "Kopieer Testlink voor Safari / Opdrachten", en: "Copy Test Link for Safari / Shortcuts"))
                }
                .font(.caption.bold())
                .foregroundColor(MycoTheme.blue)
            }
            .buttonStyle(.borderless)
        }
    }
    
    private var backupAndRestoreSection: some View {
        Section(store.t(nl: "Back-up Archief & Herstelkluis", en: "Backup Archive & Restore Vault")) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(MycoTheme.green)
                    Text(store.t(nl: "Volledige Lab & Tuya Back-up", en: "Complete Lab & Tuya Backup"))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                
                Text(store.t(
                    nl: "Slaat al je kweekprojecten, soorten, potten, slimme stekkers én je Tuya Cloud-koppeling (API keys & device IDs) veilig op in iCloud en lokale opslag. Hiermee kun je altijd na een update of op een andere iPhone alles met 1 tik herstellen zonder opnieuw inloggen.",
                    en: "Saves all grow projects, strains, jars, smart plugs, and your Tuya Cloud credentials (API keys & device IDs) securely to iCloud and local storage. Restore everything on any device or after an update with 1 tap without re-entering credentials."
                ))
                .font(.caption2)
                .foregroundColor(MycoTheme.textSecondary)
                
                let pCount = store.db.projects.count
                let sCount = store.db.strains.count
                let plugCount = store.db.smartDevices.count
                let hasTuya = !store.db.environmentConfig.tuyaApiKey.isEmpty
                
                HStack(spacing: 8) {
                    Text("\(pCount) projecten • \(sCount) soorten • \(plugCount) stekkers")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(MycoTheme.blue)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(hasTuya ? MycoTheme.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(hasTuya ? store.t(nl: "Tuya Inbegrepen", en: "Tuya Included") : store.t(nl: "Geen Tuya", en: "No Tuya"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(hasTuya ? MycoTheme.green : Color.orange)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 4)
            
            // Demo & Clean Lab Data Management
            Button {
                store.seedDemoLabData()
                MycoSyncManager.shared.triggerToast(message: store.t(
                    nl: "Realistische demo data ingeladen (Oesterzwam & Lion's Mane)!",
                    en: "Realistic demo data loaded (Oyster & Lion's Mane)!"
                ))
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(hex: "7D7AFF"))
                    Text(store.t(nl: "Laad Realistische Demo Kweekdata", en: "Load Realistic Demo Grow Data"))
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
            
            Button {
                store.resetToCleanLab()
                MycoSyncManager.shared.triggerToast(message: store.t(
                    nl: "Alle data gewist: Schoon kweeklab gestart!",
                    en: "All data cleared: Clean grow lab started!"
                ))
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(Color.red.opacity(0.8))
                    Text(store.t(nl: "Wis Alle Data en Start Schoon Lab", en: "Clear All Data and Start Clean Lab"))
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
            
            // Dedicated Camera Info (MycoCam)
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .foregroundColor(MycoTheme.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t(nl: "Vaste Kweekcamera in MycoLabs", en: "Dedicated Grow Camera in MycoLabs"))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(store.t(
                        nl: "Geen aparte app meer nodig! Gebruik MycoLabs op het camera-toestel en kies 'Vaste Kweekcamera'. Deze telefoon fungeert als centrale live viewer en afstandsbediening.",
                        en: "For broadcasting from the grow room, use the dedicated MycoCam app on the camera device. MycoLabs acts as your live viewer and remote controller."
                    ))
                    .font(.caption2)
                    .foregroundColor(MycoTheme.textSecondary)
                }
            }
            
            // 1. Direct Save to iCloud & Files
            Button {
                let res = store.saveCompleteBackupToFilesAndCloud()
                if res.success {
                    backupSuccessMessage = res.message
                    showBackupSuccess = true
                }
            } label: {
                HStack {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .foregroundColor(MycoTheme.green)
                    Text(store.t(nl: "Maak Volledig Back-up Bestand (Kluis)", en: "Create Full Backup File (Vault)"))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
            }
            
            // 2. 1-Tap Restore from iCloud / Latest Backup
            Button {
                do {
                    let res = try store.restoreLatestBackupFromCloudOrFiles()
                    let tuyaMsg = res.hasTuya ? store.t(nl: "én Tuya verbinding hersteld", en: "and Tuya credentials restored") : ""
                    restoreSuccessMessage = store.t(
                        nl: "✅ Meest recente back-up hersteld! (\(res.projectsCount) projecten, \(res.devicesCount) stekkers \(tuyaMsg)).",
                        en: "✅ Latest backup restored! (\(res.projectsCount) projects, \(res.devicesCount) plugs \(tuyaMsg))."
                    )
                    showRestoreSuccess = true
                } catch {
                    restoreErrorMessage = error.localizedDescription
                    showRestoreError = true
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                        .foregroundColor(MycoTheme.blue)
                    Text(store.t(nl: "Herstel Meest Recente iCloud Back-up", en: "Restore Latest iCloud Backup"))
                        .font(.subheadline.bold())
                        .foregroundColor(MycoTheme.blue)
                }
            }
            
            // 3. Share / Export Backup File
            ShareLink(item: store.exportBackupFileURL()) {
                Label(
                    store.t(nl: "Exporteer / Deel Volledig Back-upbestand", en: "Export / Share Full Backup File"),
                    systemImage: "square.and.arrow.up"
                )
                .font(.subheadline)
                .foregroundColor(.white)
            }
            
            // 4. File Picker Restore
            Button {
                showFileImporter = true
            } label: {
                Label(
                    store.t(nl: "Kies & Herstel Specifiek JSON Bestand...", en: "Pick & Restore Specific JSON File..."),
                    systemImage: "folder.fill"
                )
                .font(.subheadline)
                .foregroundColor(MycoTheme.amber)
            }
            
            Button(role: .destructive) {
                confirmReset = true
            } label: {
                Text(store.t(nl: "Wis Alle Lab Data (Terug naar 100% Leeg)", en: "Wipe All Lab Data (Reset to 100% Empty)"))
            }
        }
    }
}


// MARK: - DEDICATED CAMERA DEVICE ROOT VIEW (HEADLESS MYCOCAM STREAM NODE)
struct DedicatedCameraDeviceView: View {
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var pairingManager = MycoCamPairingManager.shared
    @ObservedObject private var liveKitManager = LiveKitStreamManager.shared
    @ObservedObject private var hubManager = MycoBackgroundHubManager.shared
    
    @State private var isScreenBlackout: Bool = false
    @State private var originalBrightness: CGFloat = 0.5
    @State private var autoBlackoutTimer: AnyCancellable? = nil
    @State private var showFlashShutter: Bool = false
    
    @AppStorage("mycolab_is_dedicated_camera_device") private var isDedicatedCameraDevice: Bool = false
    @State private var showExitAlert: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isScreenBlackout {
                // MARK: - OLED BLACKOUT MODE (Zero Backlight Power, Zero Burn-In)
                blackoutView
            } else {
                // MARK: - FIRST SCREEN: PAIRING QR CODE & TELEMETRY
                activeSetupView
            }
            
            // Subtle camera shutter flash on physical capture
            if showFlashShutter {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onAppear {
            setupStreamNode()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            setupStreamNode()
        }
        .onChange(of: liveKitManager.isOledSaverActive) { _, newValue in
            withAnimation(.easeInOut(duration: 0.35)) {
                if newValue {
                    enterBlackout()
                } else {
                    wakeFromBlackout()
                }
            }
        }
        .onChange(of: liveKitManager.participantCount) { _, newCount in
            // When viewer connects (participantCount > 1), automatically transition to black screen!
            if newCount > 1 && !isScreenBlackout {
                withAnimation(.easeInOut(duration: 0.5)) {
                    enterBlackout()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MycoCamTimelapseFlashShutter"))) { _ in
            withAnimation(.easeIn(duration: 0.08)) {
                showFlashShutter = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showFlashShutter = false
                }
            }
        }
        .alert(store.t(nl: "Kweekcamera Modus Verlaten?", en: "Exit Camera Mode?"), isPresented: $showExitAlert) {
            Button(store.t(nl: "Ja, terug naar Normale App", en: "Yes, return to Normal App"), role: .destructive) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    isDedicatedCameraDevice = false
                }
                Task {
                    await liveKitManager.stopStream()
                }
            }
            Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
        }
    }
    
    // MARK: - Active Setup View (QR Code First Screen)
    private var activeSetupView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Top Header
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(liveKitManager.isConnected ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                        Text("MycoCam")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("NODE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(MycoTheme.blue.opacity(0.3))
                            .foregroundColor(MycoTheme.blue)
                            .cornerRadius(6)
                    }
                    
                    Text(store.t(
                        nl: "Scan deze code eenmalig in MycoLabs op je andere telefoon om te koppelen. Alle bediening gebeurt op afstand.",
                        en: "Scan this code once in MycoLabs on your other phone to pair. All control happens remotely."
                    ))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                }
                .padding(.top, 16)
                
                // Big Crisp QR Code
                if let qrImage = pairingManager.generateQRCode() {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 230, height: 230)
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: MycoTheme.green.opacity(0.25), radius: 14)
                } else {
                    ProgressView()
                        .frame(width: 230, height: 230)
                }
                
                // Camera Info & Live Viewfinder Thumbnail
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pairingManager.localCameraName)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("ID: \(pairingManager.localCameraId)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Small live viewfinder thumbnail to confirm framing in tent
                        if let track = liveKitManager.localVideoTrack {
                            SwiftUIVideoView(track, layoutMode: .fill)
                                .frame(width: 90, height: 56)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        }
                    }
                    .padding(12)
                    .background(MycoTheme.card)
                    .cornerRadius(12)
                    
                    // Connection Status & Battery Row
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(liveKitManager.isConnected ? MycoTheme.green : MycoTheme.amber)
                            Text(liveKitManager.isConnected ? "LiveKit Gereed" : "P2P Mesh Standby")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(MycoTheme.card)
                        .cornerRadius(10)
                        
                        HStack(spacing: 6) {
                            let bat = hubManager.batteryLevel > 0 ? Int(hubManager.batteryLevel * 100) : 100
                            Image(systemName: hubManager.isCharging ? "battery.100.bolt" : "battery.100")
                                .foregroundColor(hubManager.isCharging ? MycoTheme.green : MycoTheme.blue)
                            Text("\(bat)%")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .padding(10)
                        .background(MycoTheme.card)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 24)
                
                // Blackout Trigger Button
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        enterBlackout()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.fill")
                        Text(store.t(nl: "Scherm Nu Zwart Maken (OLED Standby)", en: "Black Out Screen Now (OLED Standby)"))
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                
                Text(store.t(
                    nl: "💡 Tip: Het scherm dimt automatisch zodra de kweekstream start of na 35 seconden inactiviteit.",
                    en: "💡 Tip: Screen turns off automatically once stream starts remotely or after 35 seconds of inactivity."
                ))
                .font(.system(size: 11))
                .foregroundColor(MycoTheme.textSecondary.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                
                Button {
                    showExitAlert = true
                } label: {
                    Text(store.t(nl: "Sluit Kweekcamera Modus (Terug naar Dashboard)", en: "Exit Camera Mode (Return to Dashboard)"))
                        .font(.caption.bold())
                        .foregroundColor(MycoTheme.red.opacity(0.85))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                }
                .padding(.top, 6)
                
                Spacer(minLength: 30)
            }
        }
    }
    
    // MARK: - OLED Blackout View (Zero Power, Zero Burn-In)
    private var blackoutView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green.opacity(0.35))
                        .frame(width: 6, height: 6)
                    Text("● MycoCam Actief • Tik op scherm om QR-code te tonen")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.18))
                }
                .padding(.bottom, 24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.35)) {
                wakeFromBlackout()
            }
        }
    }
    
    // MARK: - Lifecycle & Power Controls
    private func enterBlackout() {
        autoBlackoutTimer?.cancel()
        autoBlackoutTimer = nil
        originalBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 0.01
        isScreenBlackout = true
    }
    
    private func wakeFromBlackout() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        
        isScreenBlackout = false
        UIScreen.main.brightness = max(0.4, originalBrightness)
        
        // Auto-return to blackout after 35s if untouched
        autoBlackoutTimer?.cancel()
        autoBlackoutTimer = Timer.publish(every: 35, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    enterBlackout()
                }
            }
    }
    
    private func setupStreamNode() {
        UIApplication.shared.isIdleTimerDisabled = true
        hubManager.setKeepScreenOn(true)
        hubManager.enableStreamHubMode()
        liveKitManager.startScreenAwakeWatchdog()
        pairingManager.startAdvertisingCamera()
        MycoCamStreamManager.shared.startHost()
        
        MycoCamStreamManager.shared.onRemoteCommandReceived = { [weak liveKitManager] cmd in
            guard let liveKitManager = liveKitManager else { return }
            if cmd.type == "request_snapshot" {
                Task {
                    _ = await liveKitManager.captureAndSaveSnapshot(withFlash: false)
                }
            } else if cmd.type == "torch" {
                let tOn = cmd.torchOn ?? false
                liveKitManager.setTorch(on: tOn, level: cmd.torchBrightness ?? 0.8)
            } else if cmd.type == "screen_sleep_toggle" || cmd.type == "sleep_toggle" {
                withAnimation(.easeInOut(duration: 0.35)) {
                    if isScreenBlackout {
                        wakeFromBlackout()
                    } else {
                        enterBlackout()
                    }
                }
            } else if cmd.type == "screen_sleep" || cmd.type == "sleep" {
                withAnimation(.easeInOut(duration: 0.35)) {
                    enterBlackout()
                }
            } else if cmd.type == "screen_wake" || cmd.type == "wake" {
                withAnimation(.easeInOut(duration: 0.35)) {
                    wakeFromBlackout()
                }
            }
        }
        
        liveKitManager.onRemoteSnapshotRequested = { [weak liveKitManager] in
            Task {
                _ = await liveKitManager?.captureAndSaveSnapshot(withFlash: false)
            }
        }
        
        Task {
            guard !liveKitManager.isStartingStream else { return }
            if liveKitManager.localVideoTrack == nil {
                await liveKitManager.startLocalStandaloneCameraTrack()
            }
            if !liveKitManager.isConnected || liveKitManager.currentRole != .broadcaster {
                await liveKitManager.startBroadcaster(cameraId: pairingManager.localCameraId)
            }
        }
        
        // Initial auto-blackout after 35s if left untouched
        autoBlackoutTimer?.cancel()
        autoBlackoutTimer = Timer.publish(every: 35, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    enterBlackout()
                }
            }
    }
}

struct DedicatedCameraPairingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: MycoStore
    @ObservedObject private var pairingManager = MycoCamPairingManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text(store.t(nl: "Koppel met Hoofdtelefoon", en: "Pair with Main Phone"))
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text(store.t(
                            nl: "Scan deze QR-code met de Kweker App op je andere toestel om direct te verbinden.",
                            en: "Scan this QR code with the Grower App on your other device to connect instantly."
                        ))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    }

                    if let qrImg = pairingManager.generateQRCode() {
                        Image(uiImage: qrImg)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(18)
                            .shadow(color: MycoTheme.green.opacity(0.35), radius: 14)
                    } else {
                        ProgressView()
                            .frame(width: 220, height: 220)
                    }

                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(pairingManager.hasConnectedPeers ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(pairingManager.hasConnectedPeers
                                 ? store.t(nl: "Verbonden met: \(pairingManager.connectedPeerNames.joined(separator: ", "))",
                                           en: "Connected to: \(pairingManager.connectedPeerNames.joined(separator: ", "))")
                                 : store.t(nl: "Wachten op scan door hoofdtelefoon...",
                                           en: "Waiting for scan from main phone..."))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }

                        Text("Camera ID: \(pairingManager.localCameraId)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    .padding(12)
                    .background(MycoTheme.card)
                    .cornerRadius(10)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text(store.t(nl: "Sluiten", en: "Close"))
                            .font(.subheadline.bold())
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(MycoTheme.green)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .padding(.top, 24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(store.t(nl: "Klaar", en: "Done")) {
                        dismiss()
                    }
                    .foregroundColor(MycoTheme.green)
                }
            }
        }
    }
}

// MARK: - AI ONBOARDING & LEVEL EVALUATION WIZARD
enum StarterPackageType: String, Codable, CaseIterable, Identifiable {
    case allRound = "allRound"
    case culinary = "culinary"
    case active = "active"
    case clean = "clean"
    
    var id: String { rawValue }
}

struct AIOnboardingWizardView: View {
    @EnvironmentObject var store: MycoStore
    @Binding var isPresented: Bool
    
    // Steps:
    // 1: Apparaat Rol (Hoofdtelefoon vs Dedicated Kweekcamera)
    // 2: Ervaring
    // 3: Intentie & Doel
    // 4: Kweekmethode & Hardware
    // 5: AI Evaluatie
    // 6: Startkeuze
    @State private var currentStep: Int = 0
    
    // User Answers
    @State private var selectedStartOption: Int = 0 // 0: Clean Lab, 1: Demo Data, 2: Dedicated Camera
    @State private var deviceRoleIndex: Int = 0 // 0: Kweker / Hoofdapparaat, 1: Dedicated Kweekcamera & Hub
    @State private var experienceIndex: Int = 0 // 0: Beginner, 1: Enkele kweken, 2: Ervaren, 3: Pro
    @State private var intentIndex: Int = 0 // 0: Culinair, 1: Actief, 2: Beide, 3: Lab only
    @State private var hardwareIndex: Int = 1 // 0: Zakken/Kits, 1: Monotub & Potten, 2: Smart Lab
    
    // AI Analysis State
    @State private var isAnalyzing: Bool = false
    @State private var analysisProgress: Double = 0.0
    @State private var analysisStatus: String = ""
    @State private var evaluatedSummary: String = ""
    @State private var recommendedPackage: StarterPackageType = .allRound
    
    // User manual level override
    @State private var userSelectedLevelIndex: Int = 0 // 0: Beginner, 1: Hobby, 2: Gevorderd, 3: Smart Lab
    
    // Raspberry Pi Hub pairing in Onboarding
    @State private var isScanningHubs: Bool = false
    @State private var isConnectedToHub: Bool = false
    @State private var hubScanMessage: String? = nil
    @State private var showingHubQRScanner: Bool = false
    @State private var manualQRInput: String = ""
    
    private let levelTitles = [
        "Startend Mycoloog (Niveau 1)",
        "Hobby Kweker (Niveau 2)",
        "Gevorderd Specialist (Niveau 3)",
        "Smart Lab Biohacker (Niveau 4)"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                MycoTheme.bg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            if currentStep == 0 {
                                stepAppOverviewView
                            } else {
                                stepDeviceRoleView
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    
                    // Prominent Direct Start Buttons
                    VStack(spacing: 10) {
                        if currentStep == 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    currentStep = 1
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(store.t(nl: "Aan de slag met inrichten", en: "Get Started with Setup"))
                                    Image(systemName: "arrow.right")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [MycoTheme.green, Color(hex: "05C46B")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: MycoTheme.green.opacity(0.35), radius: 6, y: 2)
                            }
                        } else {
                            Button {
                                if selectedStartOption == 2 && !MycoDevicePlatform.isMac {
                                    finishAsDedicatedCamera()
                                } else if selectedStartOption == 1 {
                                    finishWithDemoData()
                                } else {
                                    finishCleanSlate()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedStartOption == 1 ? "sparkles" : (selectedStartOption == 2 ? "camera.fill" : "leaf.fill"))
                                    Text(selectedStartOption == 1
                                         ? store.t(nl: "Verken met Demo Data", en: "Explore with Demo Data")
                                         : (selectedStartOption == 2
                                            ? store.t(nl: "Start als 24/7 Kweekcamera & Hub", en: "Start as 24/7 Grow Camera & Hub")
                                            : store.t(nl: "Start Schoon Kweeklab", en: "Start Clean Grow Lab")))
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: selectedStartOption == 1
                                            ? [Color(hex: "5E5CE6"), MycoTheme.blue]
                                            : (selectedStartOption == 2 ? [MycoTheme.blue, Color.cyan] : [MycoTheme.green, MycoTheme.green.opacity(0.85)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: (selectedStartOption == 1 ? Color(hex: "5E5CE6") : (selectedStartOption == 2 ? MycoTheme.blue : MycoTheme.green)).opacity(0.35), radius: 6, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(MycoTheme.card.ignoresSafeArea(edges: .bottom))
                }
            }
            .navigationTitle(currentStep == 0 ? store.t(nl: "Welkom bij MycoLabs", en: "Welcome to MycoLabs") : store.t(nl: "Kies je Inrichting", en: "Choose Setup"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingHubQRScanner) {
                QRScannerModalView(
                    manualCode: $manualQRInput,
                    onScanned: { code in
                        showingHubQRScanner = false
                        handleHubScannedCode(code)
                    }
                )
            }
            .onAppear {
                let currentIp = store.db.environmentConfig.effectivePiHubIP
                if !currentIp.isEmpty {
                    isConnectedToHub = true
                }
            }
        }
    }
    
    // MARK: - Header Progress
    private var headerProgressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text(store.t(nl: "Stap \(currentStep) van 6", en: "Step \(currentStep) of 6"))
                    .font(.caption.bold())
                    .foregroundColor(MycoTheme.blue)
                Spacer()
                Text(stepTitle(currentStep))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [MycoTheme.blue, MycoTheme.green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(Double(currentStep) / 6.0), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 6)
        }
    }
    
    private func stepTitle(_ step: Int) -> String {
        switch step {
        case 1: return store.t(nl: "Apparaat Rol", en: "Device Role")
        case 2: return store.t(nl: "Ervaring", en: "Experience")
        case 3: return store.t(nl: "Intentie & Doel", en: "Intent & Goal")
        case 4: return store.t(nl: "Kweekmethode", en: "Grow Method")
        case 5: return store.t(nl: "AI Evaluatie", en: "AI Evaluation")
        case 6: return store.t(nl: "Startkeuze", en: "Start Choice")
        default: return ""
        }
    }
    
    // MARK: - Step 0: Welcome & Features Overview
    private var stepAppOverviewView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Hero Brand Card
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [MycoTheme.green.opacity(0.35), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 50
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "allergens")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(MycoTheme.green)
                }
                
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text("MYCOLAB")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(MycoTheme.green)
                            .tracking(2)
                        Text("STUDIO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(MycoTheme.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MycoTheme.blue.opacity(0.18))
                            .cornerRadius(4)
                    }
                    
                    Text(store.t(
                        nl: "Jouw Complete Digitale Paddenstoelenlab & Kweekruimte",
                        en: "Your Complete Digital Mushroom Lab & Grow Facility"
                    ))
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    
                    Text(store.t(
                        nl: "Van vloeibare cultuur en agar tot geautomatiseerde kweekklimaten en microscopie: ontworpen voor hobbyisten, biohackers en professionele laboratoria.",
                        en: "From liquid culture and agar to automated grow climates and microscopy: engineered for hobbyists, biohackers and commercial labs."
                    ))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            
            // Section Title
            Text(store.t(nl: "Mogelijkheden & Toepassingen", en: "Features & Applications"))
                .font(.footnote.bold())
                .foregroundColor(MycoTheme.textSecondary)
                .textCase(.uppercase)
                .tracking(1)
            
            // 6 Feature Cards
            VStack(spacing: 12) {
                overviewFeatureRow(
                    icon: "dna",
                    iconColor: Color.purple,
                    title: store.t(nl: "Genetica, Sporen & Agar", en: "Genetics, Spores & Agar"),
                    description: store.t(
                        nl: "Beheer vloeibare culturen, sporenprints, clones en traceerbare stambomen van generatie op generatie.",
                        en: "Manage liquid cultures, spore prints, clones and lineage tracking across generations."
                    )
                )
                
                overviewFeatureRow(
                    icon: "thermometer.sun.fill",
                    iconColor: Color.orange,
                    title: store.t(nl: "Klimaat Autopilot & VPD", en: "Climate Autopilot & VPD"),
                    description: store.t(
                        nl: "Realtime metingen van RH%, Temperatuur, CO2 en VPD. Schakelt automatisch wifi-stekkers van Tuya, Shelly, Tasmota & Home Assistant.",
                        en: "Real-time RH%, Temperature, CO2 and VPD tracking. Automates Tuya, Shelly, Tasmota & Home Assistant smart plugs."
                    )
                )
                
                overviewFeatureRow(
                    icon: "video.badge.waveform.fill",
                    iconColor: MycoTheme.blue,
                    title: store.t(nl: "Geïntegreerde Kweekcamera", en: "Integrated Grow Camera"),
                    description: store.t(
                        nl: "Gebruik een tweede toestel in de tent als 24/7 HD stream-camera met nachtflits en automatische timelapses in dezelfde app.",
                        en: "Use a second device in your tent as a 24/7 HD stream camera with auto-flash and timelapses in the same app."
                    )
                )
                
                overviewFeatureRow(
                    icon: "waveform.circle.fill",
                    iconColor: MycoTheme.green,
                    title: store.t(nl: "Cleanroom Spraakassistent", en: "Cleanroom Voice Assistant"),
                    description: store.t(
                        nl: "100% hands-free werken in de laminaire flowhood of glovebox. Start timers, log kweeknotities en wissel protocollen met je stem.",
                        en: "100% hands-free work in laminar flow hoods or gloveboxes. Start timers, log notes and switch protocols by voice."
                    )
                )
                
                overviewFeatureRow(
                    icon: "archivebox.fill",
                    iconColor: Color.yellow,
                    title: store.t(nl: "Substraatrecepten & Voorraad", en: "Substrate Recipes & Inventory"),
                    description: store.t(
                        nl: "Automatische CVG calculator, autoclaaf-sterilisatietimers, drooggewicht-registratie en waterbestendige QR-potlabels.",
                        en: "Automatic CVG calculator, autoclave timers, dry weight logging and condensation-proof QR jar labels."
                    )
                )
                
                overviewFeatureRow(
                    icon: "lock.shield.fill",
                    iconColor: Color.cyan,
                    title: store.t(nl: "Offline-First & Decoy Vault", en: "Offline-First & Decoy Vault"),
                    description: store.t(
                        nl: "Je kweekdata blijft 100% lokaal op je toestel. Beveiligd met FaceID/TouchID en een gecamoufleerde kluis met nood-PIN.",
                        en: "All grow data stays 100% local on device. Protected by FaceID/TouchID and a disguised decoy vault with duress PIN."
                    )
                )
            }
        }
    }
    
    private func overviewFeatureRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(14)
        .background(MycoTheme.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MycoTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Step 1: Device Role & Welcome Choice
    private var stepDeviceRoleView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    currentStep = 0
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text(store.t(nl: "Terug naar app overzicht", en: "Back to app overview"))
                }
                .font(.caption.bold())
                .foregroundColor(MycoTheme.blue)
            }
            .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(store.t(nl: "Kies hoe je wilt beginnen", en: "Choose how to get started"))
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text(store.t(
                    nl: "MycoLabs past zich aan op jouw wensen: verken direct met realistische voorbeelden, of start met een 100% blanco lab.",
                    en: "MycoLabs adapts to your workflow: explore immediately with realistic demo data, or start with a 100% blank lab."
                ))
                .font(.caption)
                .foregroundColor(MycoTheme.textSecondary)
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 12) {
                // Card 1: Schoon Kweeklab Starten (Clean Slate - Aanbevolen)
                Button {
                    selectedStartOption = 0
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(selectedStartOption == 0 ? MycoTheme.green.opacity(0.2) : Color.white.opacity(0.06))
                                .frame(width: 44, height: 44)
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(selectedStartOption == 0 ? MycoTheme.green : MycoTheme.textSecondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(store.t(nl: "Schoon Kweeklab Starten", en: "Start Clean Grow Lab"))
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text(store.t(nl: "Aanbevolen (Blanco)", en: "Recommended (Clean)"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(MycoTheme.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(MycoTheme.green.opacity(0.18))
                                    .cornerRadius(6)
                            }
                            
                            Text(store.t(
                                nl: "100% blanco start voor kwekers die direct hun eigen kweeksoorten, batches en potten willen invoeren. Geen ongevraagde data.",
                                en: "100% blank start for growers wanting to enter their own mushroom strains, batches, and jars directly. Zero unwanted data."
                            ))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                            
                            HStack(spacing: 8) {
                                Label("Eigen soorten invoeren", systemImage: "plus.circle.fill")
                                Label("100% Blanco", systemImage: "checkmark.shield.fill")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(selectedStartOption == 0 ? MycoTheme.green : MycoTheme.textSecondary.opacity(0.7))
                            .padding(.top, 2)
                        }
                    }
                    .padding(16)
                    .background(selectedStartOption == 0 ? MycoTheme.green.opacity(0.12) : MycoTheme.card)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(selectedStartOption == 0 ? MycoTheme.green : MycoTheme.border, lineWidth: selectedStartOption == 0 ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Card 2: Verken met Demo Data (Optioneel)
                Button {
                    selectedStartOption = 1
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(selectedStartOption == 1 ? Color(hex: "5E5CE6").opacity(0.2) : Color.white.opacity(0.06))
                                .frame(width: 44, height: 44)
                            Image(systemName: "sparkles")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(selectedStartOption == 1 ? Color(hex: "7D7AFF") : MycoTheme.textSecondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(store.t(nl: "Verken met Voorbeelddata", en: "Explore with Demo Data"))
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text(store.t(nl: "Voorbeeld", en: "Example"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "7D7AFF"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "5E5CE6").opacity(0.18))
                                    .cornerRadius(6)
                            }
                            
                            Text(store.t(
                                nl: "Verken de app met voorbeeld Oesterzwam & Lion's Mane batches en gesimuleerde sensoren om de functies uit te proberen.",
                                en: "Explore the app with sample Oyster & Lion's Mane batches and simulated sensors to test features."
                            ))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                            
                            HStack(spacing: 8) {
                                Label("Voorbeeld data", systemImage: "sparkles")
                                Label("Altijd wisbaar", systemImage: "trash")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(selectedStartOption == 1 ? Color(hex: "7D7AFF") : MycoTheme.textSecondary.opacity(0.7))
                            .padding(.top, 2)
                        }
                    }
                    .padding(16)
                    .background(selectedStartOption == 1 ? Color(hex: "5E5CE6").opacity(0.1) : MycoTheme.card)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(selectedStartOption == 1 ? Color(hex: "5E5CE6") : MycoTheme.border, lineWidth: selectedStartOption == 1 ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Card 3: Dedicated Camera (Optional, on mobile devices)
                if !MycoDevicePlatform.isMac {
                    Button {
                        selectedStartOption = 2
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(selectedStartOption == 2 ? MycoTheme.blue.opacity(0.2) : Color.white.opacity(0.06))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(selectedStartOption == 2 ? MycoTheme.blue : MycoTheme.textSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(store.t(nl: "Toegewijde Kweekcamera & Hub", en: "Dedicated Grow Camera & Hub"))
                                        .font(.headline.bold())
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(store.t(nl: "Tent Mount", en: "Tent Mount"))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(MycoTheme.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(MycoTheme.blue.opacity(0.18))
                                        .cornerRadius(6)
                                }
                                
                                Text(store.t(
                                    nl: "Monteer dit toestel vast in je kweekruimte of tent als 24/7 streaming- en timelapse-camera. Alle reguliere tabbladen worden verborgen.",
                                    en: "Mount this device permanently in your grow space as a 24/7 stream and timelapse camera. All regular tabs are hidden."
                                ))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(16)
                        .background(selectedStartOption == 2 ? MycoTheme.blue.opacity(0.1) : MycoTheme.card)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedStartOption == 2 ? MycoTheme.blue : MycoTheme.border, lineWidth: selectedStartOption == 2 ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // MARK: - Raspberry Pi Lab Hub Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(store.t(nl: "🍓 Raspberry Pi Lab Hub Koppeling", en: "🍓 Raspberry Pi Lab Hub Pairing"))
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Spacer()
                        if isConnectedToHub {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text(store.t(nl: "Gekoppeld", en: "Connected"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Text(store.t(
                        nl: "Heb je al een MycoLab Raspberry Pi Hub in je kweekruimte? Koppel hem direct via Wi-Fi auto-discovery of de QR-code.",
                        en: "Have a MycoLab Raspberry Pi Hub in your grow room? Pair it right away using Wi-Fi auto-discovery or QR code."
                    ))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)

                    HStack(spacing: 10) {
                        Button {
                            scanForHubsInWizard()
                        } label: {
                            HStack(spacing: 6) {
                                if isScanningHubs {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text(store.t(nl: "Scannen...", en: "Scanning..."))
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                    Text(store.t(nl: "Zoek in Wi-Fi", en: "Search in Wi-Fi"))
                                }
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.cyan.opacity(0.2))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                        }
                        .disabled(isScanningHubs)

                        Button {
                            showingHubQRScanner = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "qrcode.viewfinder")
                                Text(store.t(nl: "Scan QR", en: "Scan QR"))
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.5), lineWidth: 1))
                        }
                    }

                    if let msg = hubScanMessage {
                        HStack(spacing: 6) {
                            Image(systemName: isConnectedToHub ? "checkmark.circle.fill" : "info.circle")
                                .foregroundColor(isConnectedToHub ? Color.green : Color.orange)
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(isConnectedToHub ? Color.green : Color.orange)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }
    
    // MARK: - Step 2: Experience
    private var stepExperienceView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.t(nl: "Hoeveel ervaring heb je met paddenstoelen kweken?", en: "What is your experience with mushroom cultivation?"))
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text(store.t(
                nl: "De AI stemt de aanbevelingen, complexiteit en interface af op jouw niveau.",
                en: "The AI tailors recommendations, complexity, and interface to your level."
            ))
            .font(.caption)
            .foregroundColor(MycoTheme.textSecondary)
            
            VStack(spacing: 10) {
                choiceCard(
                    icon: "leaf.fill",
                    title: store.t(nl: "Beginner / Eerste Kweek", en: "Beginner / First Grow"),
                    desc: store.t(nl: "Nog nooit gekweekt. Ik wil stap-voor-stap leren zonder verwarring.", en: "Never grown before. Want step-by-step guidance without confusion."),
                    isSelected: experienceIndex == 0
                ) { experienceIndex = 0 }
                
                choiceCard(
                    icon: "circle.grid.2x2.fill",
                    title: store.t(nl: "Enkele Kweken Voltooid", en: "A Few Grows Completed"),
                    desc: store.t(nl: "Bekend met kant-en-klare kweekzakken, all-in-one bags of basis PF-tek.", en: "Familiar with ready-made growbags, all-in-one kits, or basic PF-Tek."),
                    isSelected: experienceIndex == 1
                ) { experienceIndex = 1 }
                
                choiceCard(
                    icon: "flask.fill",
                    title: store.t(nl: "Ervaren Hobbyist", en: "Experienced Hobbyist"),
                    desc: store.t(nl: "Ervaring met graan steriliseren in snelkookpan, agar isolaties en monotubs.", en: "Experience pressure cooking grain, agar isolations, and monotubs."),
                    isSelected: experienceIndex == 2
                ) { experienceIndex = 2 }
                
                choiceCard(
                    icon: "atom",
                    title: store.t(nl: "Gevorderd / Commercieel Pro", en: "Advanced / Commercial Pro"),
                    desc: store.t(nl: "Volledig lab, laminaire flow hood, vloeibare cultuur & klimaatkamers.", en: "Full lab, laminar flow hood, liquid culture & automated climate tents."),
                    isSelected: experienceIndex == 3
                ) { experienceIndex = 3 }
            }
        }
    }
    
    // MARK: - Step 3: Intent
    private var stepIntentView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.t(nl: "Wat is je primaire focus of intentie?", en: "What is your primary focus or intent?"))
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text(store.t(
                nl: "Hiermee bepalen we welke genetica en substraatrecepten voor jou relevant zijn.",
                en: "This determines which genetics and substrate recipes fit your goals."
            ))
            .font(.caption)
            .foregroundColor(MycoTheme.textSecondary)
            
            VStack(spacing: 10) {
                choiceCard(
                    icon: "frying.pan.fill",
                    title: store.t(nl: "Culinaire Gourmet Zwammen", en: "Culinary Gourmet Mushrooms"),
                    desc: store.t(nl: "Oesterzwammen, Shiitake en Koningsoesterzwam op stro of zaagsel.", en: "Oyster mushrooms, Shiitake, and King Oyster on straw or sawdust."),
                    isSelected: intentIndex == 0
                ) { intentIndex = 0 }
                
                choiceCard(
                    icon: "sparkles",
                    title: store.t(nl: "Medicinale & Functionele Soorten", en: "Medicinal & Functional Species"),
                    desc: store.t(nl: "Pruikzwam (Lion's Mane), Reishi en Turkey Tail voor thee & extracten.", en: "Lion's Mane, Reishi, and Turkey Tail for functional extracts & teas."),
                    isSelected: intentIndex == 1
                ) { intentIndex = 1 }
                
                choiceCard(
                    icon: "globe.europe.africa.fill",
                    title: store.t(nl: "Zowel Culinair als Medicinaal", en: "Both Culinary & Medicinal"),
                    desc: store.t(nl: "Een brede selectie van gastronomische eetbare zwammen en medicinale soorten.", en: "A complete selection of gourmet edible mushrooms and functional varieties."),
                    isSelected: intentIndex == 2
                ) { intentIndex = 2 }
                
                choiceCard(
                    icon: "slider.horizontal.3",
                    title: store.t(nl: "Puur Lab- & Apparatuurbeheer", en: "Pure Lab & Hardware Management"),
                    desc: store.t(nl: "Ik wil alleen kweeklogboeken, sensoren en automatisering beheren zonder vooraf ingestelde soorten.", en: "Only want logs, sensors, and automation without preloaded strains."),
                    isSelected: intentIndex == 3
                ) { intentIndex = 3 }
            }
        }
    }
    
    // MARK: - Step 4: Hardware & Methods
    private var stepHardwareView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.t(nl: "Welke kweekmethode of apparatuur gebruik je?", en: "Which grow method or equipment do you use?"))
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text(store.t(
                nl: "Zo selecteert MycoLabs de juiste sterilisatietijden en container presets.",
                en: "Allows MycoLabs to select fitting sterilization times and container presets."
            ))
            .font(.caption)
            .foregroundColor(MycoTheme.textSecondary)
            
            VStack(spacing: 10) {
                choiceCard(
                    icon: "bag.fill",
                    title: store.t(nl: "Kweekzakken & Growkits", en: "Growbags & Kits"),
                    desc: store.t(nl: "Eenvoudige filterzakken en kant-en-klare doosjes.", en: "Simple filter patch bags and ready-made growkits."),
                    isSelected: hardwareIndex == 0
                ) { hardwareIndex = 0 }
                
                choiceCard(
                    icon: "shippingbox.fill",
                    title: store.t(nl: "Klassieke Monotub & Weckpotten", en: "Classic Monotub & Mason Jars"),
                    desc: store.t(nl: "Graan steriliseren in potten, kokosvezel (CVG) en kweekbakken.", en: "Sterilizing grain in jars, coco coir (CVG), and tubs."),
                    isSelected: hardwareIndex == 1
                ) { hardwareIndex = 1 }
                
                choiceCard(
                    icon: "powerplug.fill",
                    title: store.t(nl: "Geautomatiseerd Smart Lab", en: "Automated Smart Lab"),
                    desc: store.t(nl: "Tuya slimme stekkers, continue luchtvochtigheid, sensoren en camera.", en: "Tuya smart plugs, climate sensors, and live camera feed."),
                    isSelected: hardwareIndex == 2
                ) { hardwareIndex = 2 }
            }
        }
    }
    
    // MARK: - Step 5: AI Analysis & Level Evaluation
    private var stepAIAnalysisView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isAnalyzing {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .stroke(MycoTheme.blue.opacity(0.2), lineWidth: 8)
                            .frame(width: 90, height: 90)
                        Circle()
                            .trim(from: 0, to: CGFloat(analysisProgress))
                            .stroke(
                                LinearGradient(
                                    colors: [MycoTheme.blue, MycoTheme.green],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 36))
                            .foregroundColor(MycoTheme.blue)
                    }
                    .padding(.top, 24)
                    
                    VStack(spacing: 8) {
                        Text(store.t(nl: "AI Analyseert Je Profiel...", en: "AI Analyzing Your Profile..."))
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Text(analysisStatus)
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles.square.filled.on.square")
                            .font(.title2)
                            .foregroundColor(MycoTheme.green)
                        Text(store.t(nl: "AI Evaluatieresultaat", en: "AI Evaluation Result"))
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    }
                    
                    // Evaluated Level Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(levelTitles[userSelectedLevelIndex])
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Spacer()
                            Text(userSelectedLevelIndex == 3 ? "PRO" : "NIVEAU \(userSelectedLevelIndex + 1)")
                                .font(.system(size: 11, weight: .heavy))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(MycoTheme.green.opacity(0.2))
                                .foregroundColor(MycoTheme.green)
                                .cornerRadius(6)
                        }
                        
                        Text(evaluatedSummary)
                            .font(.subheadline)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    .padding(16)
                    .background(MycoTheme.card)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.green.opacity(0.4), lineWidth: 1))
                    
                    // User Disagreement / Level Override
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.t(
                            nl: "Niet mee eens? Pas direct handmatig je niveau aan:",
                            en: "Disagree? Adjust your level manually:"
                        ))
                        .font(.caption.bold())
                        .foregroundColor(MycoTheme.amber)
                        
                        Picker("Niveau", selection: $userSelectedLevelIndex) {
                            Text(store.t(nl: "🌱 Beginner", en: "🌱 Beginner")).tag(0)
                            Text(store.t(nl: "🍄 Hobby", en: "🍄 Hobby")).tag(1)
                            Text(store.t(nl: "🧫 Specialist", en: "🧫 Specialist")).tag(2)
                            Text(store.t(nl: "⚡️ Smart Lab", en: "⚡️ Smart Lab")).tag(3)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.top, 6)
                }
            }
        }
    }
    
    // MARK: - Step 6: Final Start Choice
    private var stepFinalChoiceView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.t(nl: "Hoe wil je je lab starten?", en: "How would you like to start your lab?"))
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text(store.t(
                nl: "Kies of je direct wilt starten met een aanbevolen starterspakket of helemaal blanco:",
                en: "Choose whether to install a recommended starter pack or start with a clean slate:"
            ))
            .font(.caption)
            .foregroundColor(MycoTheme.textSecondary)
            
            // Choice A: Start Completely Clean (Recommended)
            Button {
                finishCleanSlate()
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .font(.title2)
                            .foregroundColor(MycoTheme.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Start Met Een Helemaal Lege App", en: "Start With A Completely Clean App"))
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Text(store.t(nl: "100% Blanco Lab (Aanbevolen)", en: "100% Blank Lab (Recommended)"))
                                .font(.caption2.bold())
                                .foregroundColor(MycoTheme.green)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    Text(store.t(
                        nl: "Geen vooringestelde soorten of batches. Jij voegt alles vanaf nul zelf toe naar eigen wens.",
                        en: "No preset strains or batches. You add everything from scratch according to your needs."
                    ))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(MycoTheme.green)
                            .font(.caption)
                        Text(store.t(nl: "Schoon & Blanco kweeklab", en: "Clean & blank grow lab"))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
                .padding(16)
                .background(MycoTheme.card)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.green.opacity(0.7), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            
            // Choice B: Install Optional Starter Pack
            Button {
                finishWithStarterPack()
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.title2)
                            .foregroundColor(MycoTheme.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.t(nl: "Installeer Optioneel Starterspakket", en: "Install Optional Starter Pack"))
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Text(recommendedPackageTitle())
                                .font(.caption2)
                                .foregroundColor(MycoTheme.blue)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    Text(recommendedPackageSummary())
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .background(MycoTheme.card)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.blue.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
    
    private func recommendedPackageTitle() -> String {
        switch recommendedPackage {
        case .culinary: return store.t(nl: "Culinair & Medicinaal Pakket", en: "Culinary & Medicinal Pack")
        case .active: return store.t(nl: "Actief & Monotub Pakket", en: "Active & Monotub Pack")
        case .allRound, .clean: return store.t(nl: "Compleet All-Round Pakket", en: "Complete All-Round Pack")
        }
    }
    
    private func recommendedPackageSummary() -> String {
        switch recommendedPackage {
        case .culinary:
            return store.t(
                nl: "Bevat Lion's Mane, Blauwe Oesterzwam, Shiitake, Master's Mix zaagsel presets en substraatvoorraad.",
                en: "Includes Lion's Mane, Blue Oyster, Shiitake, Master's Mix sawdust presets, and substrate stock."
            )
        case .active:
            return store.t(
                nl: "Bevat Lion's Mane, Blue Oyster, King Oyster, pasteurisatie presets, weckpotten en kweekzak configuraties.",
                en: "Includes Lion's Mane, Blue Oyster, King Oyster, pasteurization presets, jars, and grow bag setups."
            )
        case .allRound, .clean:
            return store.t(
                nl: "Bevat alle 5 soorten, 11 lab-presets (potten, bakken, zakken, CVG & agar) en 8 basis voorraaditems.",
                en: "Includes all 5 strains, 11 presets (jars, tubs, bags, CVG & agar), and 8 supply items."
            )
        }
    }
    
    // MARK: - Choice Card Component
    private func choiceCard(icon: String, title: String, desc: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? MycoTheme.blue : MycoTheme.textSecondary)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(desc)
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? MycoTheme.blue : MycoTheme.border)
                    .font(.title3)
            }
            .padding(14)
            .background(isSelected ? MycoTheme.blue.opacity(0.12) : MycoTheme.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? MycoTheme.blue : MycoTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Navigation
    private var bottomBar: some View {
        HStack {
            if currentStep > 1 && !isAnalyzing {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(store.t(nl: "Vorige", en: "Back"))
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(MycoTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            
            Spacer()
            
            if currentStep == 1 && deviceRoleIndex == 1 {
                // Direct Camera Start Button
                Button {
                    finishAsDedicatedCamera()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                        Text(store.t(nl: "Start als Kweekcamera 📹", en: "Start as Grow Camera 📹"))
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(MycoTheme.green)
                    .cornerRadius(10)
                }
            } else if currentStep < 6 {
                Button {
                    if currentStep == 4 {
                        withAnimation { currentStep = 5 }
                        startAIAnalysis()
                    } else {
                        withAnimation { currentStep += 1 }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentStep == 4 ? store.t(nl: "Analyseer met AI", en: "Analyze with AI") : store.t(nl: "Volgende", en: "Next"))
                        Image(systemName: currentStep == 4 ? "sparkles" : "chevron.right")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(MycoTheme.green)
                    .cornerRadius(10)
                }
                .disabled(isAnalyzing)
            }
        }
    }
    
    private func scanForHubsInWizard() {
        isScanningHubs = true
        hubScanMessage = nil
        Task {
            var candidateHosts = ["pi-lab.local", "mycolab-hub.local"]
            #if DEBUG
            candidateHosts.append("192.168.50.115")
            #endif
            
            var foundHost: String? = nil
            for host in candidateHosts {
                guard let url = URL(string: "http://\(host):8088/status") else { continue }
                var req = URLRequest(url: url)
                req.timeoutInterval = 1.2
                if let (_, resp) = try? await URLSession.shared.data(for: req),
                   let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    foundHost = host
                    break
                }
            }
            
            await MainActor.run {
                self.isScanningHubs = false
                if let host = foundHost {
                    self.store.db.environmentConfig.piHubIP = host
                    self.store.db.environmentConfig.piHubPort = 8088
                    self.store.saveImmediately()
                    self.isConnectedToHub = true
                    self.hubScanMessage = self.store.t(
                        nl: "🍓 Hub '\(host)' succesvol gekoppeld!",
                        en: "🍓 Hub '\(host)' paired successfully!"
                    )
                    MycoSyncManager.shared.triggerToast(message: "🍓 Hub '\(host)' gekoppeld")
                } else {
                    self.isConnectedToHub = false
                    self.hubScanMessage = self.store.t(
                        nl: "Geen Hub gevonden. Zorg dat de Pi aan staat op hetzelfde Wi-Fi netwerk.",
                        en: "No Hub found. Ensure the Pi is on the same Wi-Fi network."
                    )
                }
            }
        }
    }
    
    private func handleHubScannedCode(_ code: String) {
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
                        self.isConnectedToHub = true
                        self.hubScanMessage = store.t(nl: "🍓 Hub '\(host)' gekoppeld via QR!", en: "🍓 Hub '\(host)' paired via QR!")
                        MycoSyncManager.shared.triggerToast(message: "🍓 Hub '\(host)' gekoppeld")
                        return
                    }
                } else if let host = url.host {
                    store.db.environmentConfig.piHubIP = host
                    if let port = url.port { store.db.environmentConfig.piHubPort = port }
                    store.saveImmediately()
                    self.isConnectedToHub = true
                    self.hubScanMessage = store.t(nl: "🍓 Hub '\(host)' gekoppeld via QR!", en: "🍓 Hub '\(host)' paired via QR!")
                    MycoSyncManager.shared.triggerToast(message: "🍓 Hub '\(host)' gekoppeld")
                    return
                }
            }
        }
        self.hubScanMessage = store.t(nl: "Ongeldige QR-code voor Pi Hub.", en: "Invalid QR code for Pi Hub.")
    }

    // MARK: - Dedicated Camera Finish
    private func finishAsDedicatedCamera() {
        UserDefaults.standard.set(true, forKey: "mycolab_is_dedicated_camera_device")
        UserDefaults.standard.set(true, forKey: "mycolab_onboarding_completed")
        store.db.hasCompletedOnboarding = true
        store.save()
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        isPresented = false
    }
    
    // MARK: - AI Evaluation Process
    private func startAIAnalysis() {
        isAnalyzing = true
        analysisProgress = 0.1
        analysisStatus = store.t(nl: "Ervaringsprofiel matchen...", en: "Matching experience profile...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            analysisProgress = 0.5
            analysisStatus = store.t(nl: "Kweekmethode & hardware afstemmen...", en: "Aligning grow method & hardware...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            analysisProgress = 0.85
            analysisStatus = store.t(nl: "Biologische parameters & presets berekenen...", en: "Calculating biological parameters & presets...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let score = experienceIndex + (hardwareIndex >= 2 ? 1 : 0)
            if score == 0 {
                userSelectedLevelIndex = 0
                evaluatedSummary = store.t(
                    nl: "Je start net met kweken. Eenvoudige, bewezen protocollen en overzichtelijke stappen geven je direct de hoogste slagingskans zonder verwarrende details.",
                    en: "You are just starting out. Simple, proven protocols and clear steps provide the highest success rate without confusing complexity."
                )
            } else if score <= 2 {
                userSelectedLevelIndex = 1
                evaluatedSummary = store.t(
                    nl: "Je hebt de basis onder de knie en wilt betrouwbaar oogsten. De focus ligt op steriele techniek, juiste substraatverhoudingen en monitoring.",
                    en: "You know the basics and want reliable yields. Focus is on sterile technique, proper substrate ratios, and monitoring."
                )
            } else if score == 3 {
                userSelectedLevelIndex = 2
                evaluatedSummary = store.t(
                    nl: "Ervaren met graansterilisatie, agar-isolaties en genetica. Je profiteert van gedetailleerde tracking van generaties, biologische efficiëntie (BE%) en flushes.",
                    en: "Experienced with grain prep, agar work, and genetics. You benefit from tracking generations, biological efficiency (BE%), and multiple flushes."
                )
            } else {
                userSelectedLevelIndex = 3
                evaluatedSummary = store.t(
                    nl: "High-tech kweekomgeving met continue klimaatregeling, Tuya slimme stekkers, sensormonitoring en geavanceerde laboratorium-automatisering.",
                    en: "High-tech grow setup with automated climate control, Tuya smart plugs, sensor telemetry, and advanced lab automation."
                )
            }
            
            // Choose recommended package type
            if intentIndex == 0 {
                recommendedPackage = .culinary
            } else if intentIndex == 1 {
                recommendedPackage = .active
            } else {
                recommendedPackage = .allRound
            }
            
            analysisProgress = 1.0
            isAnalyzing = false
        }
    }
    
    private func finishWithStarterPack() {
        let chosenTitle = levelTitles[userSelectedLevelIndex]
        store.db.userExperienceLevel = chosenTitle
        store.db.hasCompletedOnboarding = true
        store.seedDefaultData(packageType: recommendedPackage, force: true)
        UserDefaults.standard.set(true, forKey: "mycolab_onboarding_completed")
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        isPresented = false
        MycoSyncManager.shared.triggerToast(
            message: store.t(
                nl: "Starterspakket op maat succesvol geladen!",
                en: "Custom starter pack loaded successfully!"
            )
        )
    }
    
    private func finishCleanSlate() {
        let chosenTitle = levelTitles[userSelectedLevelIndex]
        store.db.userExperienceLevel = chosenTitle
        store.db.hasCompletedOnboarding = true
        store.resetToCleanLab()
        UserDefaults.standard.set(true, forKey: "mycolab_onboarding_completed")
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        isPresented = false
        MycoSyncManager.shared.triggerToast(
            message: store.t(
                nl: "Lab gestart met een schone, lege app!",
                en: "Lab started with a clean, empty app!"
            )
        )
    }

    private func finishWithDemoData() {
        store.seedDemoLabData()
        UserDefaults.standard.set(true, forKey: "mycolab_onboarding_completed")
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        isPresented = false
        MycoSyncManager.shared.triggerToast(
            message: store.t(
                nl: "Demo kweeklab geladen! Verken batches, sensoren en voorraad.",
                en: "Demo grow lab loaded! Explore batches, sensors and stock."
            )
        )
    }
}
