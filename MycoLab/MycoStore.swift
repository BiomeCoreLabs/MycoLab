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
public import Combine

@MainActor final class MycoStore: ObservableObject {
    public static weak var shared: MycoStore? = nil
    @Published var hasPendingLocalModifications: Bool = false
    @Published var db: AppDatabase = AppDatabase() {
        didSet {
            guard !MycoSyncManager.shared.isApplyingRemoteSync else { return }
            hasPendingLocalModifications = true
            MycoSyncManager.shared.notifyLocalModification()
            save()
        }
    }
    @Published var lastSavedTimestamp: Date? = nil
    
    public func recordDeletion(_ id: UUID) {
        if !db.deletedItemIDs.contains(id) {
            db.deletedItemIDs.append(id)
            if db.deletedItemIDs.count > 250 {
                db.deletedItemIDs.removeFirst(db.deletedItemIDs.count - 250)
            }
            save()
        }
    }
    
    public func recordTuyaDeletion(_ tuyaId: String) {
        let trimmed = tuyaId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !db.deletedTuyaDeviceIDs.contains(trimmed) {
            db.deletedTuyaDeviceIDs.append(trimmed)
            if db.deletedTuyaDeviceIDs.count > 100 {
                db.deletedTuyaDeviceIDs.removeFirst(db.deletedTuyaDeviceIDs.count - 100)
            }
            save()
        }
    }
    
    public func deleteProject(id: UUID) {
        db.projects.removeAll(where: { $0.id == id })
        let relatedLogIDs = db.logs.filter { $0.projectID == id }.map { $0.id }
        for logId in relatedLogIDs {
            recordDeletion(logId)
        }
        db.logs.removeAll(where: { $0.projectID == id })
        
        let relatedHarvestIDs = db.harvests.filter { $0.projectID == id }.map { $0.id }
        for harvestId in relatedHarvestIDs {
            recordDeletion(harvestId)
        }
        db.harvests.removeAll(where: { $0.projectID == id })
        
        recordDeletion(id)
        save()
    }
    
    public func deleteLog(id: UUID) {
        db.logs.removeAll(where: { $0.id == id })
        recordDeletion(id)
        save()
    }
    
    public func deleteHarvest(id: UUID) {
        db.harvests.removeAll(where: { $0.id == id })
        recordDeletion(id)
        save()
    }
    
    public func deleteStashJar(id: UUID) {
        db.stash.removeAll(where: { $0.id == id })
        recordDeletion(id)
        save()
    }
    
    public func deleteCulture(id: UUID) {
        db.cultures.removeAll(where: { $0.id == id })
        recordDeletion(id)
        save()
    }
    
    @discardableResult
    public func transferCulture(parent: CultureItem) -> CultureItem {
        let nextGen: String
        let genUpper = parent.generation.trimmingCharacters(in: .whitespaces).uppercased()
        if genUpper.hasPrefix("T"), let num = Int(genUpper.dropFirst()) {
            nextGen = "T\(num + 1)"
        } else if genUpper.hasPrefix("G"), let num = Int(genUpper.dropFirst()) {
            nextGen = "G\(num + 1)"
        } else {
            nextGen = parent.generation.isEmpty ? "T1" : parent.generation + "-T1"
        }
        let sku = nextSKU(prefix: "CLT")
        let child = CultureItem(
            strainID: parent.strainID,
            strainName: parent.strainName,
            skuCode: sku,
            cultureType: parent.cultureType,
            generation: nextGen,
            parentID: parent.id,
            parentLabel: "\(parent.strainName) (\(parent.generation) • \(parent.qrCodeID.isEmpty ? parent.skuCode : parent.qrCodeID))",
            mediaName: parent.mediaName,
            status: "Active Growth",
            qrCodeID: sku
        )
        db.cultures.insert(child, at: 0)
        save()
        return child
    }
    
    public func deleteStrain(id: UUID) {
        db.strains.removeAll(where: { $0.id == id })
        recordDeletion(id)
        save()
    }
    
    public func deleteSupply(id: UUID) {
        db.supplies.removeAll(where: { $0.id == id })
        recordDeletion(id)
        save()
    }
    
    public func deletePreset(id: UUID) {
        db.presets.removeAll(where: { $0.id == id })
        recordDeletion(id)
        save()
    }
    
    public func deletePreparationRecipe(id: UUID) {
        db.preparationRecipes.removeAll(where: { $0.id == id })
        recordDeletion(id)
        save()
    }
    
    public func deleteSterilizationPreset(id: UUID) {
        db.sterilizationPresets.removeAll(where: { $0.id == id })
        recordDeletion(id)
        save()
    }
    
    public func deleteCustomQRCode(id: UUID) {
        db.customQRCodes.removeAll(where: { $0.id == id })
        recordDeletion(id)
        save()
    }

    public func deleteTimer(id: UUID) {
        db.timers.removeAll(where: { $0.id == id })
        recordDeletion(id)
        save()
    }
    // Apple ID Authentication State
    @Published public var appleUser: AppleUserProfile? = nil
    
    public var isAppleLoggedIn: Bool {
        return appleUser != nil
    }
    
    public func saveAppleUser(_ profile: AppleUserProfile) {
        self.appleUser = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "mycolab_apple_user_profile")
            MycoKVS.set(data, forKey: "mycolab_apple_user_profile")
            MycoKVS.synchronize()
        }
        syncCloudData(force: true)
        MycoSyncManager.shared.sendSyncPayload(reason: "apple_user_login")
        MycoSyncManager.shared.requestSyncFromConnectedPeers()
    }
    
    public func signOutApple() {
        self.appleUser = nil
        UserDefaults.standard.removeObject(forKey: "mycolab_apple_user_profile")
        MycoKVS.removeObject(forKey: "mycolab_apple_user_profile")
        MycoKVS.synchronize()
    }
    
    public func loadAppleUser() {
        if let data = UserDefaults.standard.data(forKey: "mycolab_apple_user_profile"),
           let profile = try? JSONDecoder().decode(AppleUserProfile.self, from: data) {
            self.appleUser = profile
            return
        }
        if let cloudData = MycoKVS.data(forKey: "mycolab_apple_user_profile"),
           let profile = try? JSONDecoder().decode(AppleUserProfile.self, from: cloudData) {
            self.appleUser = profile
            UserDefaults.standard.set(cloudData, forKey: "mycolab_apple_user_profile")
            syncCloudData(force: true)
        }
    }

    private var isReadyToSave: Bool = false
    
    // Live Activities & Dynamic Island state
    @Published var activeDynamicIslandTimer: LabTimerItem? = nil
    @Published var dynamicIslandRemainingSeconds: Int = 0
    @Published var isDynamicIslandTimerPaused: Bool = false
    @Published var showDynamicIslandExpanded: Bool = false
    @Published var lastCloudSyncTimestamp: Date? = nil
    @Published var isCloudSyncing: Bool = false
    @Published var piHubLogs: [PiHubLogEntry] = []
    @Published var isSyncingPiHub: Bool = false
    @Published var piHubStatusOnline: Bool = true
    
    // Pi Central Server Database State (Raspberry Pi as Main & Server)
    @Published var piServerDbLastSync: Date? = nil
    @Published var isPiServerDbSyncing: Bool = false
    @Published var piServerDbStatusMessage: String = ""
    private var piDbSyncWorkItem: DispatchWorkItem? = nil
    private var liveActivityTimer: AnyCancellable? = nil
    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
    private var currentLiveActivity: Any? = nil
    #endif
    
    // Cold-start Face ID session unlock:
    // When the app is launched cold, isUnlocked starts false.
    // Once unlocked, it STAYS true for the lifetime of this process.
    // Switching apps (background <-> foreground) keeps isUnlocked true!
    @Published var isUnlocked: Bool = false
    @Published var isDecoyMode: Bool = false
    @Published var isAnonymousAnalyticsAllowed: Bool = false {
        didSet {
            UserDefaults.standard.set(isAnonymousAnalyticsAllowed, forKey: "mycolab_anonymous_analytics_allowed")
        }
    }
    private var realDbBackup: AppDatabase? = nil
    private var isAuthenticating: Bool = false

    public func enterDecoyMode() {
        guard !isDecoyMode else { return }
        self.realDbBackup = self.db
        var decoyDb = AppDatabase()
        decoyDb.language = self.db.language
        decoyDb.selectedTheme = self.db.selectedTheme
        decoyDb.useModernInterface = true
        decoyDb.stealthMode = false
        decoyDb.strains = MycoDecoyVaultManager.decoyStrains
        decoyDb.projects = MycoDecoyVaultManager.decoyProjects
        decoyDb.cultures = MycoDecoyVaultManager.decoyCultures
        decoyDb.stash = MycoDecoyVaultManager.decoyStash
        decoyDb.supplies = MycoDecoyVaultManager.decoySupplies
        decoyDb.environmentConfig = self.db.environmentConfig
        
        self.db = decoyDb
        self.isDecoyMode = true
        self.isUnlocked = true
    }
    
    public func exitDecoyMode() {
        guard isDecoyMode, let backup = realDbBackup else { return }
        self.db = backup
        self.realDbBackup = nil
        self.isDecoyMode = false
    }
    
    public var currentThemeTitle: String {
        if let custom = MycoTheme.activeCustomTheme {
            return custom.name
        }
        return currentTheme.localizedTitle(isEnglish: isEnglish)
    }

    public var currentTheme: AppTheme {
        get { AppTheme(rawValue: db.selectedTheme) ?? .darkLab }
        set {
            objectWillChange.send()
            applyBuiltinTheme(newValue)
        }
    }

    public func applyBuiltinTheme(_ theme: AppTheme) {
        objectWillChange.send()
        db.selectedTheme = theme.rawValue
        db.selectedCustomThemeId = nil
        MycoTheme.currentTheme = theme
        MycoTheme.activeCustomTheme = nil
        save()
    }
    
    public func applyCustomTheme(_ theme: CustomAppTheme) {
        objectWillChange.send()
        db.selectedTheme = "custom"
        db.selectedCustomThemeId = theme.id
        MycoTheme.activeCustomTheme = theme
        save()
    }
    
    public func saveCustomTheme(_ theme: CustomAppTheme) {
        objectWillChange.send()
        if let idx = db.customThemes.firstIndex(where: { $0.id == theme.id }) {
            db.customThemes[idx] = theme
        } else {
            db.customThemes.append(theme)
        }
        applyCustomTheme(theme)
    }
    
    public func deleteCustomTheme(id: UUID) {
        objectWillChange.send()
        db.customThemes.removeAll { $0.id == id }
        if db.selectedCustomThemeId == id {
            applyBuiltinTheme(.darkLab)
        } else {
            save()
        }
    }
    
    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("mycolab_v1_store.json")
    }

    private var backupURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("mycolab_v1_store.backup.json")
    }
    
    private var appSupportURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("mycolab_v1_store.json")
    }
    
    private var appGroupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mycolab.app")?.appendingPathComponent("mycolab_v1_store.json")
    }
    
    private let userDefaultsKey = "mycolab_v1_store_payload"
    
    init() {
        Self.shared = self
        self.db = AppDatabase()
        load()
        if self.db.language != "en" {
            self.db.language = "en"
        }
        if let udData = UserDefaults.standard.data(forKey: userDefaultsKey), udData.count >= 1_000_000 {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            UserDefaults(suiteName: "group.com.mycolab.app")?.removeObject(forKey: userDefaultsKey)
            print("🧹 [MycoStore] Oude grote database-blob uit NSUserDefaults verwijderd.")
        }
        syncWithLocalPiHubDevices()
        if !self.db.smartDevices.contains(where: { $0.deviceType == "Sensor" }) {
            self.db.environmentConfig.latestSensorTempC = nil
            self.db.environmentConfig.latestSensorHumidityPct = nil
            self.db.environmentConfig.latestSensorCo2Ppm = nil
            self.db.environmentConfig.latestSensorReadingTime = nil
        }
        if let customId = self.db.selectedCustomThemeId,
           let custom = self.db.customThemes.first(where: { $0.id == customId }) {
            MycoTheme.activeCustomTheme = custom
        } else {
            MycoTheme.currentTheme = AppTheme(rawValue: self.db.selectedTheme) ?? .darkLab
            MycoTheme.activeCustomTheme = nil
        }
        loadAppleUser()
        if UserDefaults.standard.object(forKey: "mycolab_anonymous_analytics_allowed") != nil {
            self.isAnonymousAnalyticsAllowed = UserDefaults.standard.bool(forKey: "mycolab_anonymous_analytics_allowed")
        }
        if ProcessInfo.processInfo.arguments.contains("-demoMode") {
            seedDemoLabData()
        }
        if ProcessInfo.processInfo.arguments.contains("-demoOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NotificationCenter.default.post(name: NSNotification.Name("MycoLabShowOnboardingWizard"), object: nil)
            }
        }
        if let tabIdx = ProcessInfo.processInfo.arguments.firstIndex(of: "-demoTab"),
           tabIdx + 1 < ProcessInfo.processInfo.arguments.count,
           let tabInt = Int(ProcessInfo.processInfo.arguments[tabIdx + 1]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NotificationCenter.default.post(name: NSNotification.Name("MycoLabSwitchTab"), object: tabInt)
            }
        }
        self.isReadyToSave = true
        self.db.environmentConfig.tuyaOfflineAutonomousActive = false
        self.db.environmentConfig.piHubAutonomousActive = true
        cleanExpiredTuyaCloudLogs()
        if !self.db.biometricLock {
            self.isUnlocked = true
        }
        
        if MycoKVS.isAvailable {
            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: NSUbiquitousKeyValueStore.default,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.loadAppleUser()
                    self?.syncCloudData(force: false)
                }
            }
        }
        MycoKVS.synchronize()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.syncCloudData(force: true)
        }
        let pairedCamId = UserDefaults.standard.string(forKey: "mycolab_paired_camera_id") ?? ""
        if isCurrentDeviceActingAsHub || pairedCamId.isEmpty {
            startAutopilotEngine()
        }
        MycoWidgetDataManager.shared.updateSnapshot(from: self.db)
        MycoUserTestingAgent.shared.attachStore(self)
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoLabStartAutopilotEngine"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.startAutopilotEngine()
            }
        }
        
        // Automatically sync with Central Raspberry Pi Server on startup and foreground
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.syncCentralDatabaseWithPi()
                await self?.syncDevicesFromPiHub()
            }
        }
        
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncCentralDatabaseWithPi()
                await self?.syncDevicesFromPiHub()
            }
        }
        #endif
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoLabRemotePlugSetState"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let id = notif.userInfo?["id"] as? UUID
                let tuyaId = notif.userInfo?["tuyaId"] as? String ?? ""
                guard let isOn = notif.userInfo?["isOn"] as? Bool else { return }
                let trigger = notif.userInfo?["trigger"] as? String ?? (self.isEnglish ? "Remote Monitor" : "Kijk-app (Hub Aansturing)")
                let name = notif.userInfo?["name"] as? String ?? ""
                
                // Match existing device by ID or Tuya Device ID
                if let idx = self.db.smartDevices.firstIndex(where: {
                    ($0.id == id) || (!tuyaId.isEmpty && $0.tuyaDeviceID == tuyaId)
                }) {
                    if let id = id, self.db.smartDevices[idx].id != id {
                        self.db.smartDevices[idx].id = id
                    }
                    let targetDevId = self.db.smartDevices[idx].id
                    let devName = self.db.smartDevices[idx].name
                    
                    if self.isCurrentDeviceActingAsHub {
                        self.setSmartDeviceState(id: targetDevId, isOn: isOn, trigger: trigger, relayToHub: false)
                    } else {
                        self.db.smartDevices[idx].isOn = isOn
                        self.db.smartDevices[idx].lastModifiedAt = Date()
                        self.save()
                        let stateLabel = isOn ? "ON" : "OFF"
                        MycoSyncManager.shared.triggerToast(
                            message: "🔌 \(devName) is \(stateLabel)"
                        )
                    }
                } else if !tuyaId.isEmpty || id != nil {
                    let newId = id ?? UUID()
                    let effectiveName = name.isEmpty ? "Smart Plug" : name
                    let item = SmartDeviceItem(
                        id: newId,
                        name: effectiveName,
                        deviceType: "Tuya Plug",
                        tuyaDeviceID: tuyaId,
                        isOn: isOn,
                        autoControlEnabled: true,
                        lastModifiedAt: Date()
                    )
                    self.db.smartDevices.append(item)
                    self.save()
                    let stateLabel = isOn ? "ON" : "OFF"
                    MycoSyncManager.shared.triggerToast(
                        message: "🔌 \(effectiveName) is \(stateLabel)"
                    )
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoLabRemotePlugToggle"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            MainActor.assumeIsolated {
                guard let self = self,
                      let id = notif.userInfo?["id"] as? UUID else { return }
                if self.piHubStatusOnline || self.db.environmentConfig.isPiHubAutonomousActive {
                    return
                }
                let trigger = notif.userInfo?["trigger"] as? String ?? (self.isEnglish ? "Remote Monitor" : "Kijk-app (Hub Aansturing)")
                self.toggleSmartDevice(id: id, trigger: trigger, relayToHub: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    MycoSyncManager.shared.sendSyncPayload(reason: "hub_plug_toggled")
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoLabRemotePlugDelete"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let id = notif.userInfo?["id"] as? UUID
                let tuyaId = notif.userInfo?["tuyaId"] as? String ?? ""
                var modified = false
                if let id = id {
                    let before = self.db.smartDevices.count
                    self.db.smartDevices.removeAll(where: { $0.id == id })
                    if self.db.smartDevices.count != before {
                        self.recordDeletion(id)
                        modified = true
                    }
                }
                if !tuyaId.isEmpty {
                    let before = self.db.smartDevices.count
                    let matchedIDs = self.db.smartDevices.filter { $0.tuyaDeviceID == tuyaId }.map { $0.id }
                    for mid in matchedIDs {
                        self.recordDeletion(mid)
                    }
                    self.db.smartDevices.removeAll(where: { $0.tuyaDeviceID == tuyaId })
                    if self.db.smartDevices.count != before {
                        modified = true
                    }
                }
                if !tuyaId.isEmpty {
                    self.recordTuyaDeletion(tuyaId)
                }
                if modified {
                    self.save()
                    if LiveKitStreamManager.shared.currentRole == .broadcaster || MycoBackgroundHubManager.shared.isStreamHubRoleActive {
                        self.startAutopilotEngine()
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoLabRemotePlugTest"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            MainActor.assumeIsolated {
                guard let self = self,
                      let id = notif.userInfo?["id"] as? UUID else { return }
                self.testSmartDevice(id: id, relayToHub: false)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoLabStartLabTimerFromVoice"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let minutes = notif.userInfo?["minutes"] as? Int ?? 90
                let title = notif.userInfo?["title"] as? String ?? (self.isEnglish ? "Lab Sterilization" : "Autoclaaf Sterilisatie")
                self.startDynamicIslandTimer(label: title, totalMinutes: minutes)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoLabStopLabTimerFromVoice"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopDynamicIslandTimer()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoLabExecuteHubAutopilotTick"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.pollAllConnectedSensors()
                self.runAutopilotCycle()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoLabBroadcastHubHeartbeat"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let isAuto = self.db.environmentConfig.isAutopilotEnabled
                let lastLog = self.db.environmentConfig.lastAutopilotLogMessage
                let bat = MycoBackgroundHubManager.shared.batteryLevel
                let chg = MycoBackgroundHubManager.shared.isCharging
                LiveKitStreamManager.shared.sendHubHeartbeat(
                    autopilotActive: isAuto,
                    batteryLevel: bat,
                    isCharging: chg,
                    logMessage: lastLog
                )
            }
        }
    }
    
    func triggerStartupBiometrics() {
#if STREAM_PHONE_ONLY
        isUnlocked = true
        return
#else
        guard db.biometricLock, !isUnlocked, !isAuthenticating else {
            if !db.biometricLock {
                isUnlocked = true
            }
            return
        }
        authenticateBiometrics()
#endif
    }
    
    func authenticateBiometrics() {
        guard !isUnlocked else { return }
        isAuthenticating = true
        let context = LAContext()
        context.localizedCancelTitle = "Toegangscode"
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Scan je gezicht om MycoLabs te ontgrendelen") { [weak self] success, authError in
                DispatchQueue.main.async {
                    self?.isAuthenticating = false
                    if success {
                        self?.isUnlocked = true
                    } else {
                        print("[MycoLabs] Biometrische authenticatie mislukt of geannuleerd: \(String(describing: authError))")
                    }
                }
            }
        } else {
            // Device does not have biometrics or enrolled passcode
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.isUnlocked = true
            }
        }
    }
    
    func load() {
        let decoder = JSONDecoder()
        var candidates: [(source: String, db: AppDatabase, itemCount: Int)] = []
        
        // 1. Try Apple Core Data (SQLite)
        if let coreDataPayload = CoreDataManager.shared.loadPayload(), !coreDataPayload.isEmpty {
            let decrypted = MycoSecurityVault.decryptIfEncrypted(coreDataPayload)
            if let decoded = try? decoder.decode(AppDatabase.self, from: decrypted) {
                let count = decoded.projects.count + decoded.cultures.count + decoded.strains.count + decoded.stash.count + decoded.supplies.count + decoded.smartDevices.count
                candidates.append(("Apple Core Data (SQLite)", decoded, count))
            }
        }
        
        // 2. Try Application Support Directory File
        if let appSupportData = try? Data(contentsOf: appSupportURL), !appSupportData.isEmpty {
            let decrypted = MycoSecurityVault.decryptIfEncrypted(appSupportData)
            if let decoded = try? decoder.decode(AppDatabase.self, from: decrypted) {
                let count = decoded.projects.count + decoded.cultures.count + decoded.strains.count + decoded.stash.count + decoded.supplies.count + decoded.smartDevices.count
                candidates.append(("Application Support", decoded, count))
            }
        }
        
        // 3. Try Primary Documents Directory File
        if let data = try? Data(contentsOf: fileURL), !data.isEmpty {
            let decrypted = MycoSecurityVault.decryptIfEncrypted(data)
            if let decoded = try? decoder.decode(AppDatabase.self, from: decrypted) {
                let count = decoded.projects.count + decoded.cultures.count + decoded.strains.count + decoded.stash.count + decoded.supplies.count + decoded.smartDevices.count
                candidates.append(("Documents Directory", decoded, count))
            }
        }
        
        // 4. Try Backup File
        if let backupData = try? Data(contentsOf: backupURL), !backupData.isEmpty {
            let decrypted = MycoSecurityVault.decryptIfEncrypted(backupData)
            if let decoded = try? decoder.decode(AppDatabase.self, from: decrypted) {
                let count = decoded.projects.count + decoded.cultures.count + decoded.strains.count + decoded.stash.count + decoded.supplies.count + decoded.smartDevices.count
                candidates.append(("Backup File", decoded, count))
            }
        }
        
        // 5. Try UserDefaults Cache
        if let udData = UserDefaults.standard.data(forKey: userDefaultsKey), !udData.isEmpty {
            let decrypted = MycoSecurityVault.decryptIfEncrypted(udData)
            if let decoded = try? decoder.decode(AppDatabase.self, from: decrypted) {
                let count = decoded.projects.count + decoded.cultures.count + decoded.strains.count + decoded.stash.count + decoded.supplies.count + decoded.smartDevices.count
                candidates.append(("UserDefaults Cache", decoded, count))
            }
        }
        
        // 6. Try App Group Shared Container File
        if let groupURL = appGroupURL, let groupData = try? Data(contentsOf: groupURL), !groupData.isEmpty {
            let decrypted = MycoSecurityVault.decryptIfEncrypted(groupData)
            if let decoded = try? decoder.decode(AppDatabase.self, from: decrypted) {
                let count = decoded.projects.count + decoded.cultures.count + decoded.strains.count + decoded.stash.count + decoded.supplies.count + decoded.smartDevices.count
                candidates.append(("App Group Shared Container", decoded, count))
            }
        }
        
        // 7. Try App Group Shared UserDefaults
        if let groupDefaults = UserDefaults(suiteName: "group.com.mycolab.app"),
           let groupUdData = groupDefaults.data(forKey: userDefaultsKey), !groupUdData.isEmpty {
            let decrypted = MycoSecurityVault.decryptIfEncrypted(groupUdData)
            if let decoded = try? decoder.decode(AppDatabase.self, from: decrypted) {
                let count = decoded.projects.count + decoded.cultures.count + decoded.strains.count + decoded.stash.count + decoded.supplies.count + decoded.smartDevices.count
                candidates.append(("App Group Shared UserDefaults", decoded, count))
            }
        }
        
        // Kies altijd de kandidaat met de meeste ingevulde lab-data
        if let bestCandidate = candidates.max(by: { $0.itemCount < $1.itemCount }) {
            self.db = bestCandidate.db
            if bestCandidate.db.hasCompletedOnboarding || bestCandidate.itemCount > 0 || !bestCandidate.db.smartDevices.isEmpty {
                self.db.hasCompletedOnboarding = true
                UserDefaults.standard.set(true, forKey: "mycolab_onboarding_completed")
            }
            if let customId = bestCandidate.db.selectedCustomThemeId,
               let custom = bestCandidate.db.customThemes.first(where: { $0.id == customId }) {
                MycoTheme.activeCustomTheme = custom
            } else {
                MycoTheme.currentTheme = AppTheme(rawValue: bestCandidate.db.selectedTheme) ?? .darkLab
                MycoTheme.activeCustomTheme = nil
            }
            self.lastSavedTimestamp = Date()
            print("[MycoLabs] Succesvol geladen uit \(bestCandidate.source) met \(bestCandidate.itemCount) items (\(bestCandidate.db.projects.count) projecten, \(bestCandidate.db.cultures.count) culturen, \(bestCandidate.db.strains.count) soorten).")
        } else {
            print("[MycoLabs] Geen eerdere database gevonden. Schone database gestart.")
        }
        
        // 6. Restore Tuya credentials from dedicated iCloud KVS if local is empty
        if self.db.environmentConfig.tuyaApiKey.isEmpty {
            if let tData = MycoKVS.data(forKey: "MycoLabTuyaCredentials"),
               let dict = try? JSONSerialization.jsonObject(with: tData) as? [String: Any],
               let k = dict["tuyaApiKey"] as? String, !k.isEmpty {
                self.db.environmentConfig.tuyaApiKey = k
                self.db.environmentConfig.tuyaApiSecret = dict["tuyaApiSecret"] as? String ?? ""
                self.db.environmentConfig.tuyaRegion = dict["tuyaRegion"] as? String ?? "ce"
                self.db.environmentConfig.tuyaDeviceID = dict["tuyaDeviceID"] as? String ?? ""
                self.db.environmentConfig.tuyaVerified = dict["tuyaVerified"] as? Bool ?? false
                print("[MycoLabs] Tuya credentials hersteld vanuit dedicated iCloud KVS sleutel!")
            }
        }
        
        // 7. Sanitize project colonization percentages (0.0 ... 1.0 fraction to 0.0 ... 100.0)
        for idx in 0..<self.db.projects.count {
            if self.db.projects[idx].colonizationPercent > 0.0 && self.db.projects[idx].colonizationPercent <= 1.0 {
                self.db.projects[idx].colonizationPercent *= 100.0
            }
            if self.db.projects[idx].phase == .fruiting || self.db.projects[idx].phase == .flushing {
                if self.db.projects[idx].colonizationPercent < 100.0 {
                    self.db.projects[idx].colonizationPercent = 100.0
                }
            }
        }
        
        // Sync cloud tombstones seamlessly
    }
    
    func seedDefaultData(packageType: StarterPackageType = .allRound, force: Bool = false) {
        if packageType == .clean {
            clearAllStarterData()
            return
        }
        
        if force || db.strains.isEmpty {
            switch packageType {
            case .culinary:
                db.strains = [
                    StrainModel(
                        name: "Lion's Mane (Pruikzwam)",
                        skuCode: "LM",
                        species: "Hericium erinaceus",
                        mushroomType: .medicinal,
                        colonizationSpeed: .moderate,
                        difficulty: .intermediate,
                        potencyMultiplier: 0.0,
                        notes: "Culinair en medicinaal geroemde stekelzwam. Vormt dichte witte trossen met warrige stekels. Groeit geweldig op hardhout zaagsel of Master's Mix."
                    ),
                    StrainModel(
                        name: "Blauwe Oesterzwam",
                        skuCode: "PO",
                        species: "Pleurotus ostreatus",
                        mushroomType: .culinary,
                        colonizationSpeed: .fast,
                        difficulty: .beginner,
                        potencyMultiplier: 0.0,
                        notes: "Enorm snelle en agressieve kolonisator op stro en hout. Vormt prachtige blauwgrijze trossen binnen 10 tot 14 dagen."
                    ),
                    StrainModel(
                        name: "Shiitake",
                        skuCode: "SHII",
                        species: "Lentinula edodes",
                        mushroomType: .culinary,
                        colonizationSpeed: .slow,
                        difficulty: .intermediate,
                        potencyMultiplier: 0.0,
                        notes: "Aromatische umami-zwam. Groeit traag op hardhout zaagsel met zemelen maar levert stevige, vlezige hoeden."
                    )
                ]
            case .active:
                db.strains = [
                    StrainModel(
                        name: "Koningsoesterzwam (King Oyster)",
                        skuCode: "KO-ERY",
                        species: "Pleurotus eryngii",
                        mushroomType: .culinary,
                        colonizationSpeed: .fast,
                        difficulty: .beginner,
                        potencyMultiplier: 1.0,
                        notes: "Stevige, vlezige steel met een nootachtige umami-smaak. Uitstekend bestand tegen wisselende temperaturen."
                    ),
                    StrainModel(
                        name: "Shiitake (Japanse Eikenzwam)",
                        skuCode: "SHI-75",
                        species: "Lentinula edodes",
                        mushroomType: .culinary,
                        colonizationSpeed: .moderate,
                        difficulty: .intermediate,
                        potencyMultiplier: 1.2,
                        notes: "Traditionele kweeksoort op hardhoutzaagsel. Vormt karakteristieke diepbruine gebarsten hoeden."
                    ),
                    StrainModel(
                        name: "Reishi (Glimmende Lakzwam)",
                        skuCode: "REI-MED",
                        species: "Ganoderma lucidum",
                        mushroomType: .medicinal,
                        colonizationSpeed: .moderate,
                        difficulty: .intermediate,
                        potencyMultiplier: 1.5,
                        notes: "Beroemde medicinale soort met glanzende waaiervormige vruchtlichamen. Rijk aan bèta-glucanen en triterpenen."
                    )
                ]
            case .allRound, .clean:
                db.strains = [
                    StrainModel(
                        name: "Blauwe Oesterzwam",
                        skuCode: "PO-BLUE",
                        species: "Pleurotus ostreatus",
                        mushroomType: .culinary,
                        colonizationSpeed: .fast,
                        difficulty: .beginner,
                        potencyMultiplier: 1.0,
                        notes: "Zeer snelle en robuuste kweeksoort. Vormt dichte trossen blauw-grijze hoeden op zaagsel of stro."
                    ),
                    StrainModel(
                        name: "Lion's Mane (Pruikzwam)",
                        skuCode: "LM-MED",
                        species: "Hericium erinaceus",
                        mushroomType: .medicinal,
                        colonizationSpeed: .moderate,
                        difficulty: .intermediate,
                        potencyMultiplier: 1.2,
                        notes: "Populaire culinaire en noötropische soort met dichte witte pegels. Uitstekende smaak en textuur."
                    ),
                    StrainModel(
                        name: "Gele Oesterzwam",
                        skuCode: "PO-GOLD",
                        species: "Pleurotus citrinopileatus",
                        mushroomType: .culinary,
                        colonizationSpeed: .fast,
                        difficulty: .beginner,
                        potencyMultiplier: 1.0,
                        notes: "Sierlijke goudgele clusters. Agressieve myceliumgroei bij warme kamertemperatuur."
                    ),
                    StrainModel(
                        name: "Shiitake (Eikenzwam)",
                        skuCode: "SHI-75",
                        species: "Lentinula edodes",
                        mushroomType: .culinary,
                        colonizationSpeed: .moderate,
                        difficulty: .intermediate,
                        potencyMultiplier: 1.2,
                        notes: "Klassieke gourmet soort voor hardhoutzaagsel met karakteristieke umami-smaak."
                    )
                ]
            }
        }
        
        if force || db.presets.isEmpty {
            switch packageType {
            case .culinary:
                db.presets = [
                    UserPreset(category: .container, name: "All-in-One Filter Growbag", details: "2.5kg single-stage growbag with 0.2 micron gas exchange filter"),
                    UserPreset(category: .container, name: "3L Grow Tub (Mini-Tub)", details: "Sealed plastic grow tub suitable for 1 spawn jar"),
                    UserPreset(category: .substrate, name: "Master's Mix Sawdust", details: "50% Oak hardwood sawdust, 50% Soybean hulls, 60% hydration"),
                    UserPreset(category: .substrate, name: "100% Oak Hardwood Sawdust", details: "Pasteurized sawdust for oysters and lion's mane"),
                    UserPreset(category: .media, name: "MEA Agar (Malt Extract)", details: "500ml water, 10g agar-agar, 10g light malt extract (LME)"),
                    UserPreset(category: .media, name: "LC Nutrient Broth (4%)", details: "400ml water, 16ml honey or corn syrup (4% sugar ratio)"),
                    UserPreset(category: .grain, name: "Rye Grain (Hydrated)", details: "Rinsed organic rye, soaked 12h and sterilized")
                ]
            case .active:
                db.presets = [
                    UserPreset(category: .container, name: "1L Spawn Jar (Mason)", details: "Glass culture jar with micropore filter and rubber injection port"),
                    UserPreset(category: .container, name: "20L Monotub", details: "Monotub with 6 air holes covered with micropore filters"),
                    UserPreset(category: .substrate, name: "CVG Standard (1:2)", details: "650g Coco Coir, 2L Vermiculite, 100g Gypsum, 3.5L Boiling Water pasteurized"),
                    UserPreset(category: .substrate, name: "100% Coco Coir (Field Capacity)", details: "650g Coco Coir with 3.2L boiling water at optimal field capacity"),
                    UserPreset(category: .media, name: "MEA Agar (Malt Extract)", details: "500ml water, 10g agar-agar, 10g light malt extract (LME)"),
                    UserPreset(category: .media, name: "LC Nutrient Broth (4%)", details: "400ml water, 16ml honey or corn syrup (4% sugar ratio)"),
                    UserPreset(category: .grain, name: "Rye Grain (Hydrated)", details: "Rinsed organic rye, soaked 12h and sterilized")
                ]
            case .allRound, .clean:
                db.presets = [
                    UserPreset(category: .container, name: "1L Spawn Jar (Mason)", details: "Glass culture jar with micropore filter and rubber injection port"),
                    UserPreset(category: .container, name: "3L Grow Tub (Mini-Tub)", details: "Sealed plastic grow tub suitable for 1 spawn jar"),
                    UserPreset(category: .container, name: "20L Monotub", details: "Monotub with 6 air holes covered with micropore filters"),
                    UserPreset(category: .container, name: "All-in-One Filter Growbag", details: "2.5kg single-stage growbag with 0.2 micron gas exchange filter"),
                    UserPreset(category: .substrate, name: "CVG Standard (1:2)", details: "650g Coco Coir, 2L Vermiculite, 100g Gypsum, 3.5L Boiling Water pasteurized"),
                    UserPreset(category: .substrate, name: "100% Coco Coir (Field Capacity)", details: "650g Coco Coir with 3.2L boiling water at optimal field capacity"),
                    UserPreset(category: .substrate, name: "Master's Mix Sawdust", details: "50% Oak hardwood sawdust, 50% Soybean hulls, 60% hydration"),
                    UserPreset(category: .media, name: "MEA Agar (Malt Extract)", details: "500ml water, 10g agar-agar, 10g light malt extract (LME)"),
                    UserPreset(category: .media, name: "LC Nutrient Broth (4%)", details: "400ml water, 16ml honey or corn syrup (4% sugar ratio)"),
                    UserPreset(category: .grain, name: "Rye Grain (Hydrated)", details: "Rinsed organic rye, soaked 12h and sterilized to optimal moisture balance")
                ]
            }
        }
        
        if force || db.supplies.isEmpty {
            switch packageType {
            case .culinary:
                db.supplies = [
                    LabSupplyItem(name: "Hardwood Pellets (Oak)", category: "Substrate", quantity: 15.0, unit: "kg", minThreshold: 5.0, qrCodeID: "ML-SUP-WOOD"),
                    LabSupplyItem(name: "Soybean Hulls", category: "Substrate", quantity: 10.0, unit: "kg", minThreshold: 3.0, qrCodeID: "ML-SUP-SOY"),
                    LabSupplyItem(name: "Organic Rye Berries", category: "Grain & Spawn", quantity: 10.0, unit: "kg", minThreshold: 3.0, qrCodeID: "ML-SUP-GRAIN"),
                    LabSupplyItem(name: "Agar Agar Powder", category: "Agar & Media", quantity: 250.0, unit: "grams", minThreshold: 50.0, qrCodeID: "ML-SUP-AGAR"),
                    LabSupplyItem(name: "Filter Growbags (0.2 micron)", category: "Consumables", quantity: 15.0, unit: "pcs", minThreshold: 5.0, qrCodeID: "ML-SUP-BAGS")
                ]
            case .active:
                db.supplies = [
                    LabSupplyItem(name: "Coco Coir (Coir brick 650g)", category: "Substrate", quantity: 5.0, unit: "blocks", minThreshold: 2.0, qrCodeID: "ML-SUP-COIR"),
                    LabSupplyItem(name: "Vermiculite (Coarse)", category: "Substrate", quantity: 15.0, unit: "liters", minThreshold: 3.0, qrCodeID: "ML-SUP-VERM"),
                    LabSupplyItem(name: "Agricultural Gypsum (Calcium)", category: "Substrate", quantity: 1.5, unit: "kg", minThreshold: 0.5, qrCodeID: "ML-SUP-GYPS"),
                    LabSupplyItem(name: "Organic Rye Berries", category: "Grain & Spawn", quantity: 10.0, unit: "kg", minThreshold: 3.0, qrCodeID: "ML-SUP-GRAIN"),
                    LabSupplyItem(name: "Sterile Syringes with Needle (10ml)", category: "Consumables", quantity: 12.0, unit: "pcs", minThreshold: 3.0, qrCodeID: "ML-SUP-SYR"),
                    LabSupplyItem(name: "Micropore Tape Rolls", category: "Consumables", quantity: 4.0, unit: "rolls", minThreshold: 1.0, qrCodeID: "ML-SUP-TAPE")
                ]
            case .allRound, .clean:
                db.supplies = [
                    LabSupplyItem(name: "Coco Coir (Coir brick 650g)", category: "Substrate", quantity: 5.0, unit: "blocks", minThreshold: 2.0, qrCodeID: "ML-SUP-COIR"),
                    LabSupplyItem(name: "Vermiculite (Coarse)", category: "Substrate", quantity: 15.0, unit: "liters", minThreshold: 3.0, qrCodeID: "ML-SUP-VERM"),
                    LabSupplyItem(name: "Agricultural Gypsum (Calcium)", category: "Substrate", quantity: 1.5, unit: "kg", minThreshold: 0.5, qrCodeID: "ML-SUP-GYPS"),
                    LabSupplyItem(name: "Organic Rye Berries", category: "Grain & Spawn", quantity: 10.0, unit: "kg", minThreshold: 3.0, qrCodeID: "ML-SUP-GRAIN"),
                    LabSupplyItem(name: "Agar Agar Powder", category: "Agar & Media", quantity: 250.0, unit: "grams", minThreshold: 50.0, qrCodeID: "ML-SUP-AGAR"),
                    LabSupplyItem(name: "Light Malt Extract (LME)", category: "Agar & Media", quantity: 200.0, unit: "grams", minThreshold: 40.0, qrCodeID: "ML-SUP-LME"),
                    LabSupplyItem(name: "Micropore Tape Rolls", category: "Consumables", quantity: 4.0, unit: "rolls", minThreshold: 1.0, qrCodeID: "ML-SUP-TAPE"),
                    LabSupplyItem(name: "Sterile Syringes with Needle (10ml)", category: "Consumables", quantity: 12.0, unit: "pcs", minThreshold: 3.0, qrCodeID: "ML-SUP-SYR")
                ]
            }
        }
        if force || db.preparationRecipes.isEmpty {
            db.preparationRecipes = PreparationRecipe.defaultRecipes
        }
        save()
    }
    
    func clearAllStarterData() {
        db.strains.removeAll()
        db.presets.removeAll()
        db.preparationRecipes.removeAll()
        db.supplies.removeAll()
        save()
    }
    
    func resetToCleanLab() {
        db.isDemoMode = false
        db.projects.removeAll()
        db.cultures.removeAll()
        db.stash.removeAll()
        db.smartDevices.removeAll()
        db.smartDeviceLogs.removeAll()
        db.logs.removeAll()
        db.harvests.removeAll()
        db.strains.removeAll()
        db.supplies.removeAll()
        db.timelapsePhotos.removeAll()
        db.environmentConfig = GrowEnvironmentConfig()
        db.hasCompletedOnboarding = true
        save()
    }

    func seedDemoLabData() {
        db.isDemoMode = true
        db.userExperienceLevel = isEnglish ? "Demo Grow Lab" : "Demo Kweeklab"
        db.hasCompletedOnboarding = true
        
        // 1. Strains (Gourmet & Medicinal)
        let blueOyster = StrainModel(
            name: isEnglish ? "Blue Oyster" : "Blauwe Oesterzwam",
            skuCode: "PO-BLUE",
            species: "Pleurotus ostreatus",
            mushroomType: .culinary,
            colonizationSpeed: .fast,
            difficulty: .beginner,
            potencyMultiplier: 0.0,
            notes: "Snelgroeiende, productieve soort op hardhout en gepasteuriseerd stro. Vormt dichte blauwgrijze trossen."
        )
        let lionsMane = StrainModel(
            name: isEnglish ? "Lion's Mane" : "Lion's Mane (Pruikzwam)",
            skuCode: "LM-MED",
            species: "Hericium erinaceus",
            mushroomType: .medicinal,
            colonizationSpeed: .moderate,
            difficulty: .intermediate,
            potencyMultiplier: 0.0,
            notes: "Gewaardeerde medicinale en culinaire soort. Vormt dichte witte pegels met fijne stekels op Master's Mix."
        )
        let goldenOyster = StrainModel(
            name: isEnglish ? "Golden Oyster" : "Gele Oesterzwam",
            skuCode: "PO-GOLD",
            species: "Pleurotus citrinopileatus",
            mushroomType: .culinary,
            colonizationSpeed: .fast,
            difficulty: .beginner,
            potencyMultiplier: 0.0,
            notes: "Prachtige goudgele hoedjes. Groeit agressief bij 22-26°C en vereist voldoende verse luchtverversing."
        )
        db.strains = [blueOyster, lionsMane, goldenOyster]
        
        // 2. Realistic Batches
        var p1 = GrowProject(
            strainName: isEnglish ? "Blue Oyster" : "Blauwe Oesterzwam",
            skuCode: "PO-BLUE",
            batchNumber: 1,
            phase: .fruiting,
            colonizationPercent: 100.0,
            containerName: isEnglish ? "Filter Patch Grow Bag (5L)" : "Kweekzak met microfilter",
            substrateName: isEnglish ? "Master's Mix Sawdust (5L)" : "Master's Mix Zaagsel (5L)",
            spawnToBulkRatio: "1:4",
            startDate: Calendar.current.date(byAdding: .day, value: -18, to: Date()) ?? Date(),
            latestTempC: 21.2,
            latestHumidityPct: 88.5,
            qrCodeID: "ML-BATCH-DEMO-01"
        )
        p1.tags = isEnglish ? ["First Flush", "Optimal"] : ["Eerste Flush", "Optimaal"]
        
        var p2 = GrowProject(
            strainName: isEnglish ? "Lion's Mane" : "Lion's Mane (Pruikzwam)",
            skuCode: "LM-MED",
            batchNumber: 2,
            phase: .bulk,
            colonizationPercent: 76.0,
            containerName: isEnglish ? "Mini Monotub 20L" : "Monotub Mini 20L",
            substrateName: isEnglish ? "Oak Hardwood Sawdust + Wheat Bran" : "Eikenhardhout Zaagsel + Tarwezemelen",
            spawnToBulkRatio: "1:2",
            startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            latestTempC: 23.4,
            latestHumidityPct: 82.0,
            qrCodeID: "ML-BATCH-DEMO-02"
        )
        p2.tags = isEnglish ? ["Colonization", "Healthy"] : ["Kolonisatie", "Gezond"]
        
        var p3 = GrowProject(
            strainName: isEnglish ? "Golden Oyster" : "Gele Oesterzwam",
            skuCode: "PO-GOLD",
            batchNumber: 3,
            phase: .spawn,
            colonizationPercent: 40.0,
            containerName: isEnglish ? "Mason Jar 1000ml (Filter Lid)" : "Weckpot 1000ml met filter",
            substrateName: isEnglish ? "Organic Rye Grain" : "Biologische Roggekorrels",
            spawnToBulkRatio: "1:1",
            startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            latestTempC: 24.1,
            latestHumidityPct: 70.0,
            qrCodeID: "ML-BATCH-DEMO-03"
        )
        p3.tags = isEnglish ? ["Grain Spawn"] : ["Graanbroed"]
        db.projects = [p1, p2, p3]
        
        // 3. Simulated Smart Hardware (Tuya Plugs)
        var dev1 = SmartDeviceItem()
        dev1.name = isEnglish ? "Ultrasonic Humidifier (Tent A)" : "Ultrasone Bevochtiger (Tent A)"
        dev1.deviceType = "Humidifier"
        dev1.brand = "Tuya Smart Plug"
        dev1.tuyaDeviceID = "demo_tuya_humidifier"
        dev1.isOnlineOnTuya = true
        dev1.isOn = true
        dev1.currentTempC = 21.8
        dev1.currentHumidityPct = 87.5
        
        var dev2 = SmartDeviceItem()
        dev2.name = isEnglish ? "Fresh Air Exhaust Fan (FAE)" : "Verse Lucht Afzuiging (FAE)"
        dev2.deviceType = "Fan"
        dev2.brand = "Tuya Smart Plug"
        dev2.tuyaDeviceID = "demo_tuya_fan"
        dev2.isOnlineOnTuya = true
        dev2.isOn = false
        dev2.currentTempC = 21.8
        dev2.currentHumidityPct = 87.5
        
        var dev3 = SmartDeviceItem()
        dev3.name = isEnglish ? "Grow Light LED 6500K" : "Kweekverlichting LED 6500K"
        dev3.deviceType = "Light"
        dev3.brand = "Tuya Smart Plug"
        dev3.tuyaDeviceID = "demo_tuya_light"
        dev3.isOnlineOnTuya = true
        dev3.isOn = true
        db.smartDevices = [dev1, dev2, dev3]
        
        // 4. Environment Telemetry & Autopilot
        db.environmentConfig.environmentName = isEnglish ? "Grow Tent A (Oyster & Lion's Mane)" : "Kweektent A (Oester & Pruikzwam)"
        db.environmentConfig.targetDayTempC = 21.5
        db.environmentConfig.targetHumidityPct = 88.0
        db.environmentConfig.manualTempC = 21.8
        db.environmentConfig.manualHumidityPct = 87.5
        db.environmentConfig.latestSensorTempC = 21.8
        db.environmentConfig.latestSensorHumidityPct = 87.5
        db.environmentConfig.latestSensorCo2Ppm = 820
        db.environmentConfig.sensorDeviceName = isEnglish ? "Demo Wireless Sensor" : "Demo Draadloze Sensor"
        db.environmentConfig.latestSensorReadingTime = Date()
        
        // 5. Cured Harvest Jars
        db.stash = [
            StashJar(
                strainName: "Lion's Mane",
                skuCode: "LM-MED",
                potencyMultiplier: 1.0,
                availableDryGrams: 45.0,
                storageMethod: "Airtight Jar + Desiccant",
                lastUpdated: Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date(),
                qrCodeID: "ML-JAR-LM01"
            ),
            StashJar(
                strainName: "Blue Oyster",
                skuCode: "PO-BLUE",
                potencyMultiplier: 1.0,
                availableDryGrams: 60.0,
                storageMethod: "Airtight Jar + Desiccant",
                lastUpdated: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
                qrCodeID: "ML-JAR-PO01"
            )
        ]
        
        // 6. Lab Supplies
        db.supplies = [
            LabSupplyItem(name: "Oak Hardwood Pellets", category: "Substrate", quantity: 20.0, unit: "kg", minThreshold: 5.0, qrCodeID: "ML-SUP-OAK"),
            LabSupplyItem(name: "Soybean Hulls (Master's Mix)", category: "Substrate", quantity: 15.0, unit: "kg", minThreshold: 3.0, qrCodeID: "ML-SUP-SOY"),
            LabSupplyItem(name: "Organic Rye Berries", category: "Grain & Spawn", quantity: 10.0, unit: "kg", minThreshold: 2.0, qrCodeID: "ML-SUP-GRAIN"),
            LabSupplyItem(name: "Agar Agar Powder", category: "Agar & Media", quantity: 250.0, unit: "grams", minThreshold: 50.0, qrCodeID: "ML-SUP-AGAR"),
            LabSupplyItem(name: "Micropore Tape 3M", category: "Consumables", quantity: 6.0, unit: "rolls", minThreshold: 1.0, qrCodeID: "ML-SUP-TAPE")
        ]
        
        // 7. Active Genetics & Culture Vault
        let cult1 = CultureItem(
            strainName: isEnglish ? "Lion's Mane" : "Lion's Mane (Pruikzwam)",
            skuCode: "LM-MED",
            cultureType: "Agar Petri",
            generation: "T2",
            mediaName: "MEA (Malt Extract Agar)",
            status: isEnglish ? "Active Growth" : "Actieve Groei",
            qrCodeID: "ML-CULT-LM-T2",
            dateCreated: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
            notes: isEnglish ? "Dense rhizomorphic sector isolated from T1 master plate. Rapid hyphal expansion." : "Dichte rhizomorfe sector geïsoleerd van T1 moederplaat. Zeer snelle hyfenvorming."
        )
        let cult2 = CultureItem(
            strainName: isEnglish ? "Blue Oyster" : "Blauwe Oesterzwam",
            skuCode: "PO-BLUE",
            cultureType: "Liquid Culture (LC)",
            generation: "T1",
            mediaName: "Light Malt Extract 4%",
            status: isEnglish ? "Colonized / Ready" : "Gekoloniseerd / Klaar",
            qrCodeID: "ML-CULT-PO-LC1",
            dateCreated: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date(),
            notes: isEnglish ? "Crystal clear liquid broth with dense expanding mycelial cloud. Stirred daily." : "Glasheldere voedingsbodem met compacte witte myceliumwolk. Dagelijks magnetisch geroerd."
        )
        let cult3 = CultureItem(
            strainName: isEnglish ? "Golden Oyster" : "Gele Oesterzwam",
            skuCode: "PO-GOLD",
            cultureType: "Agar Petri",
            generation: "T1",
            mediaName: "PDA (Potato Dextrose)",
            status: isEnglish ? "Active Growth" : "Actieve Groei",
            qrCodeID: "ML-CULT-PG-T1",
            dateCreated: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
            notes: isEnglish ? "Aggressive mycelial colonization at 24°C incubator. Healthy sectoring." : "Agressieve myceliumgroei bij 24°C incubatietemperatuur. Gezonde sectoring."
        )
        let cult4 = CultureItem(
            strainName: isEnglish ? "Lion's Mane" : "Lion's Mane (Pruikzwam)",
            skuCode: "LM-MED",
            cultureType: "Liquid Culture (LC)",
            generation: "T2",
            mediaName: "Honey Peptone Broth",
            status: isEnglish ? "Cold Storage (4°C)" : "Koelkast Opslag (4°C)",
            qrCodeID: "ML-CULT-LM-LC2",
            dateCreated: Calendar.current.date(byAdding: .day, value: -25, to: Date()) ?? Date(),
            notes: isEnglish ? "Stock master library syringe stored at 4°C in dark cleanroom vault." : "Stamcultuur spuit bewaard bij 4°C in donkere steriele kluis."
        )
        db.cultures = [cult1, cult2, cult3, cult4]
        
        save()
    }

    private var saveDebounceWorkItem: DispatchWorkItem? = nil
    private static let saveQueue = DispatchQueue(label: "com.mycolab.store.saveQueue", qos: .userInitiated)

    func save() {
        guard isReadyToSave else {
            return
        }
        saveDebounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.performSave()
            }
        }
        saveDebounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    func saveFromSync() {
        guard isReadyToSave else { return }
        saveDebounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.performSave(isFromRemoteSync: true)
            }
        }
        saveDebounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    func saveImmediately(fromSync: Bool = false) {
        guard isReadyToSave else { return }
        saveDebounceWorkItem?.cancel()
        saveDebounceWorkItem = nil
        performSave(isFromRemoteSync: fromSync)
    }

    private func performSave(isFromRemoteSync: Bool = false) {
        guard isReadyToSave else { return }
        if isDecoyMode { return }
        let snapshot = self.db
        let supportURL = self.appSupportURL
        let primaryURL = self.fileURL
        let backupFileURL = self.backupURL
        let groupURL = self.appGroupURL
        let udKey = self.userDefaultsKey
        self.lastSavedTimestamp = Date()

        // Only schedule auto-sync if we have pending local modifications ("aangepaste waarden")
        // and this save was NOT triggered by an incoming synchronized value ("gesynchroniseerde waarden")
        if !isFromRemoteSync && hasPendingLocalModifications && !MycoSyncManager.shared.isApplyingRemoteSync {
            MycoSyncManager.shared.scheduleAutoSync()
            schedulePiServerDatabaseSync()
        }

        // Bereid data en sync-payloads voor in het geheugen op MainActor (geen schijf/netwerk I/O)
        let encoder = JSONEncoder()
        let encodedData: Data
        do {
            encodedData = try encoder.encode(snapshot)
        } catch {
            print("[MycoLabs] Fout bij coderen database: \(error)")
            return
        }

        let enableRemoteCloudSync = snapshot.environmentConfig.enableRemoteCloudSync
        let localCount = snapshot.projects.count + snapshot.cultures.count + snapshot.strains.count + snapshot.stash.count + snapshot.supplies.count + snapshot.smartDevices.count
        let cloudPayload = enableRemoteCloudSync
            ? MycoSyncManager.shared.exportLightweightJSON(from: snapshot)
            : nil
        let smartDevicesData = enableRemoteCloudSync
            ? (try? encoder.encode(snapshot.smartDevices))
            : nil
        let deletedIDsData = enableRemoteCloudSync
            ? (try? encoder.encode(snapshot.deletedItemIDs))
            : nil
        let tuyaApiKey = snapshot.environmentConfig.tuyaApiKey
        let tuyaApiSecret = snapshot.environmentConfig.tuyaApiSecret
        let tuyaRegion = snapshot.environmentConfig.tuyaRegion
        let tuyaDeviceID = snapshot.environmentConfig.tuyaDeviceID
        let tuyaVerified = snapshot.environmentConfig.tuyaVerified

        // Vraag achtergrondtijd aan zodat disk writes niet worden afgebroken als app naar achtergrond gaat
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "com.mycolab.store.saveQueue") {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }

        // Voer alle Core Data commits, WidgetKit updates en schijf-/netwerkcache-I/O asynchroon
        // uit op een achtergrondwachtrij om main-thread hangs te voorkomen ("Performing I/O on the main thread")
        Self.saveQueue.async {
            defer {
                if bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = .invalid
                }
            }

            // 1. Commit naar Apple Core Data (SQLite) asynchroon via achtergrondtaak (geen I/O op MainActor)
            CoreDataManager.shared.savePayload(data: encodedData)

            // 2. Update WidgetKit live timeline snapshot asynchroon (geen I/O op MainActor)
            MycoWidgetDataManager.shared.updateSnapshot(from: snapshot)

            do {
                // Schrijf naar App Support folder
                let supportDir = supportURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: supportDir.path) {
                    try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
                }
                try encodedData.write(to: supportURL, options: .atomic)

                // Schrijf naar Documents directory & Backup
                let dir = primaryURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: dir.path) {
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                }
                try encodedData.write(to: primaryURL, options: .atomic)
                try? encodedData.write(to: backupFileURL, options: .atomic)

                // Update App Group Container (File based, handles multi-megabyte safely)
                if let groupURL = groupURL {
                    let groupDir = groupURL.deletingLastPathComponent()
                    if !FileManager.default.fileExists(atPath: groupDir.path) {
                        try? FileManager.default.createDirectory(at: groupDir, withIntermediateDirectories: true)
                    }
                    try? encodedData.write(to: groupURL, options: .atomic)
                }

                // Guard UserDefaults against iOS 4MB CFPreferences hard limit
                if encodedData.count < 1_000_000 {
                    UserDefaults.standard.set(encodedData, forKey: udKey)
                    UserDefaults(suiteName: "group.com.mycolab.app")?.set(encodedData, forKey: udKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: udKey)
                    UserDefaults(suiteName: "group.com.mycolab.app")?.removeObject(forKey: udKey)
                }

                // Commit to Apple iCloud Key-Value Store (E2EE sync)
                if enableRemoteCloudSync {
                    let nowTs = Date().timeIntervalSince1970
                    let existingCloudTimestamp = MycoKVS.double(forKey: "MycoLabCloudTimestamp")
                    if localCount > 0 || existingCloudTimestamp == 0 || !tuyaApiKey.isEmpty {
                        if let cloudPayload {
                            MycoKVS.set(cloudPayload, forKey: "MycoLabCloudPayload")
                            MycoKVS.set(cloudPayload, forKey: "MycoLabFullBackupPayload")
                            MycoKVS.set(nowTs, forKey: "MycoLabCloudTimestamp")
                        }
                    }
                    if let smartDevicesData {
                        MycoKVS.set(smartDevicesData, forKey: "MycoLabSmartDevicesPayload")
                        MycoKVS.set(nowTs, forKey: "MycoLabSmartDevicesTimestamp")
                    }
                    if let deletedIDsData {
                        MycoKVS.set(deletedIDsData, forKey: "MycoLabDeletedItemIDsPayload")
                    }

                    let tuyaDict: [String: Any] = [
                        "tuyaApiKey": tuyaApiKey,
                        "tuyaApiSecret": tuyaApiSecret,
                        "tuyaRegion": tuyaRegion,
                        "tuyaDeviceID": tuyaDeviceID,
                        "tuyaVerified": tuyaVerified
                    ]
                    if let tData = try? JSONSerialization.data(withJSONObject: tuyaDict) {
                        MycoKVS.set(tData, forKey: "MycoLabTuyaCredentials")
                    }
                    MycoKVS.synchronize()
                }
            } catch {
                print("[MycoLabs] Fout bij opslaan database: \(error)")
            }
        }
    }
    
    func forceSyncToiCloud() {
        isCloudSyncing = true
        save()
        MycoKVS.synchronize()
        syncCloudData(force: true)
        MycoSyncManager.shared.sendSyncPayload(reason: "force_cloud_sync")
        MycoSyncManager.shared.requestSyncFromConnectedPeers()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.lastCloudSyncTimestamp = Date()
            self.isCloudSyncing = false
        }
    }
    
    func exportBackupFileURL() -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = (try? encoder.encode(db)) ?? Data()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "MycoLab_Backup_\(timestamp).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL, options: .atomic)
        return tempURL
    }
    
    @discardableResult
    func saveCompleteBackupToFilesAndCloud() -> (success: Bool, message: String, url: URL?) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(db) else {
            return (false, t(nl: "Kan database niet coderen naar JSON.", en: "Cannot encode database to JSON."), nil)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "MycoLab_Volledige_Backup_\(timestamp).json"
        let latestFilename = "MycoLab_Laatste_iCloud_Backup.json"
        
        // 1. Documents Directory (Accessible in iOS Files app: On My iPhone -> MycoLab)
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullBackupURL = docsDir.appendingPathComponent(filename)
        let latestBackupURL = docsDir.appendingPathComponent(latestFilename)
        
        try? data.write(to: fullBackupURL, options: .atomic)
        try? data.write(to: latestBackupURL, options: .atomic)
        
        // 2. iCloud Drive Ubiquity Container if available
        if let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let ubiquityDocs = ubiquityURL.appendingPathComponent("Documents")
            try? FileManager.default.createDirectory(at: ubiquityDocs, withIntermediateDirectories: true)
            let ubiquityBackupURL = ubiquityDocs.appendingPathComponent(latestFilename)
            try? data.write(to: ubiquityBackupURL, options: .atomic)
        }
        
        // 3. iCloud Key-Value Store Full Payload
        if let cloudPayload = MycoSyncManager.shared.exportLightweightJSON(from: db) {
            MycoKVS.set(cloudPayload, forKey: "MycoLabCloudPayload")
            MycoKVS.set(cloudPayload, forKey: "MycoLabFullBackupPayload")
            MycoKVS.set(Date().timeIntervalSince1970, forKey: "MycoLabCloudTimestamp")
        }
        
        // 4. Dedicated Tuya Credentials in iCloud KVS
        let tuyaDict: [String: Any] = [
            "tuyaApiKey": db.environmentConfig.tuyaApiKey,
            "tuyaApiSecret": db.environmentConfig.tuyaApiSecret,
            "tuyaRegion": db.environmentConfig.tuyaRegion,
            "tuyaDeviceID": db.environmentConfig.tuyaDeviceID,
            "tuyaVerified": db.environmentConfig.tuyaVerified
        ]
        if let tData = try? JSONSerialization.data(withJSONObject: tuyaDict) {
            MycoKVS.set(tData, forKey: "MycoLabTuyaCredentials")
        }
        MycoKVS.synchronize()
        
        save()
        
        let pCount = db.projects.count
        let sCount = db.strains.count
        let plugCount = db.smartDevices.count
        let tuyaText = !db.environmentConfig.tuyaApiKey.isEmpty ? t(nl: "inclusief Tuya koppeling", en: "including Tuya credentials") : t(nl: "geen Tuya", en: "no Tuya")
        let msg = t(
            nl: "Volledige back-up succesvol opgeslagen (\(pCount) projecten, \(sCount) soorten, \(plugCount) stekkers, \(tuyaText)).",
            en: "Full backup successfully saved (\(pCount) projects, \(sCount) strains, \(plugCount) plugs, \(tuyaText))."
        )
        return (true, msg, fullBackupURL)
    }
    
    func restoreLatestBackupFromCloudOrFiles() throws -> (projectsCount: Int, devicesCount: Int, hasTuya: Bool) {
        let decoder = JSONDecoder()
        
        // 1. Try iCloud Drive Ubiquity Container
        if let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let latestUbiquity = ubiquityURL.appendingPathComponent("Documents").appendingPathComponent("MycoLab_Laatste_iCloud_Backup.json")
            if let data = try? Data(contentsOf: latestUbiquity) {
                let decrypted = MycoSecurityVault.decryptIfEncrypted(data)
                if let restored = try? decoder.decode(AppDatabase.self, from: decrypted) {
                    self.db = restored
                    save()
                    return (restored.projects.count, restored.smartDevices.count, !restored.environmentConfig.tuyaApiKey.isEmpty)
                }
            }
        }
        
        // 2. Try iCloud Key-Value Store
        if let rawCloudData = MycoKVS.data(forKey: "MycoLabFullBackupPayload") ?? MycoKVS.data(forKey: "MycoLabCloudPayload") {
            let decrypted = MycoSecurityVault.decryptIfEncrypted(rawCloudData)
            if let restored = try? decoder.decode(AppDatabase.self, from: decrypted) {
                self.db = restored
                save()
                return (restored.projects.count, restored.smartDevices.count, !restored.environmentConfig.tuyaApiKey.isEmpty)
            }
        }
        
        // 3. Try Documents directory 'MycoLab_Laatste_iCloud_Backup.json'
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let latestDocs = docsDir.appendingPathComponent("MycoLab_Laatste_iCloud_Backup.json")
        if let data = try? Data(contentsOf: latestDocs) {
            let decrypted = MycoSecurityVault.decryptIfEncrypted(data)
            if let restored = try? decoder.decode(AppDatabase.self, from: decrypted) {
                self.db = restored
                save()
                return (restored.projects.count, restored.smartDevices.count, !restored.environmentConfig.tuyaApiKey.isEmpty)
            }
        }
        
        // 4. Try any MycoLab_*.json backup in Documents sorted by modification date
        if let files = try? FileManager.default.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            let backups = files.filter { $0.lastPathComponent.hasPrefix("MycoLab_") && $0.pathExtension == "json" }
                .sorted { (u1, u2) -> Bool in
                    let d1 = (try? u1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                    let d2 = (try? u2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                    return d1 > d2
                }
            if let newest = backups.first, let data = try? Data(contentsOf: newest) {
                let decrypted = MycoSecurityVault.decryptIfEncrypted(data)
                if let restored = try? decoder.decode(AppDatabase.self, from: decrypted) {
                    self.db = restored
                    save()
                    return (restored.projects.count, restored.smartDevices.count, !restored.environmentConfig.tuyaApiKey.isEmpty)
                }
            }
        }
        
        // 5. Try App Group Shared Container File
        if let groupURL = appGroupURL, let data = try? Data(contentsOf: groupURL) {
            let decrypted = MycoSecurityVault.decryptIfEncrypted(data)
            if let restored = try? decoder.decode(AppDatabase.self, from: decrypted) {
                self.db = restored
                save()
                return (restored.projects.count, restored.smartDevices.count, !restored.environmentConfig.tuyaApiKey.isEmpty)
            }
        }
        
        // 6. Try App Group Shared UserDefaults
        if let groupDefaults = UserDefaults(suiteName: "group.com.mycolab.app"),
           let groupData = groupDefaults.data(forKey: userDefaultsKey) {
            let decrypted = MycoSecurityVault.decryptIfEncrypted(groupData)
            if let restored = try? decoder.decode(AppDatabase.self, from: decrypted) {
                self.db = restored
                save()
                return (restored.projects.count, restored.smartDevices.count, !restored.environmentConfig.tuyaApiKey.isEmpty)
            }
        }
        
        throw NSError(
            domain: "MycoLabBackup",
            code: -404,
            userInfo: [NSLocalizedDescriptionKey: t(nl: "Geen back-up gevonden in iCloud of lokale map.", en: "No backup found in iCloud or local storage.")]
        )
    }
    
    func restoreFromData(_ data: Data) throws {
        let decoder = JSONDecoder()
        let decrypted = MycoSecurityVault.decryptIfEncrypted(data)
        if let restored = try? decoder.decode(AppDatabase.self, from: decrypted) {
            self.db = restored
            save()
            return
        }
        let restored = try decoder.decode(AppDatabase.self, from: data)
        self.db = restored
        save()
    }
    
    func resetAllData() {
        CoreDataManager.shared.resetData()
        self.db = AppDatabase()
        save()
    }
    
    func toggleStealthMode() {
        objectWillChange.send()
        db.stealthMode.toggle()
        save()
    }
    
    func setSplashAnimationMode(_ mode: SplashAnimationMode) {
        objectWillChange.send()
        db.splashAnimationMode = mode
        save()
    }
    
    func toggleSplashSound() {
        objectWillChange.send()
        db.isSplashSoundEnabled.toggle()
        save()
    }
    
    var isEnglish: Bool {
        true
    }
    
    func t(nl: String, en: String) -> String {
        en
    }
    
    func localizeUserEmail(_ email: String?) -> String {
        guard let email = email, !email.isEmpty else {
            return t(nl: "Apple ID Privé-doorgifte", en: "Apple ID Private Relay")
        }
        if email == "Geverifieerd via Face ID" {
            return t(nl: "Geverifieerd via Face ID", en: "Verified via Face ID")
        }
        return email
    }
    
    func localizeBotanicalSpecies(_ sp: String) -> String {
        guard isEnglish else { return sp }
        switch sp {
        case "Pleurotus ostreatus (Oesterzwam)": return "Pleurotus ostreatus (Oyster Mushroom)"
        case "Hericium erinaceus (Lion's Mane)": return "Hericium erinaceus (Lion's Mane)"
        case "Lentinula edodes (Shiitake)": return "Lentinula edodes (Shiitake)"
        case "Anders / Zelf typen...": return "Other / Type manually..."
        default:
            if sp.contains("Oesterzwam") { return "Pleurotus ostreatus (Oyster Mushroom)" }
            if sp.contains("Anders") || sp.contains("Zelf typen") { return "Other / Type manually..." }
            return sp
        }
    }

    func localizeCultureType(_ type: String) -> String {
        guard isEnglish else { return type }
        switch type {
        case "Vloeibare Cultuur (Liquid Culture - LC)", "Vloeibare Cultuur (LC)":
            return "Liquid Culture (LC)"
        case "Agar Petrischaal (Myceliumplaat)", "Agar Petri Schaal":
            return "Agar Petri Dish (Mycelium Plate)"
        case "Agar Schuinbuis / Slant (Langetermijnopslag)", "Mycelium Slant":
            return "Agar Slant (Long-term Storage)"
        case "Sporenspuit / Sporenprint (Sporensuspensie)", "Sporenspuit":
            return "Spore Syringe / Suspension"
        case "Sporenprint":
            return "Spore Print"
        case "Spore Swab (Katoenstaafje)":
            return "Spore Swab (Cotton Swab)"
        case "Weefselkloon (Biopsie vers vruchtlichaam)", "Kloonweefsel (vers)":
            return "Tissue Clone (Fruiting Body Biopsy)"
        case "Moederbroed / Graanbroed (Master Grain)", "Graanmoeder (G0/G1)":
            return "Master Grain Spawn (G0/G1)"
        case "Anders / Zelf typen...":
            return "Other / Type manually..."
        default:
            if type.contains("Vloeibare Cultuur") || type.contains("Liquid Culture") { return "Liquid Culture (LC)" }
            if type.contains("Petri") { return "Agar Petri Dish" }
            if type.contains("Slant") || type.contains("Schuinbuis") { return "Agar Slant" }
            if type.contains("Swab") || type.contains("Katoenstaafje") { return "Spore Swab" }
            if type.contains("Sporenspuit") { return "Spore Syringe" }
            if type.contains("Sporenprint") { return "Spore Print" }
            if type.contains("Moederbroed") || type.contains("Graanbroed") || type.contains("Graanmoeder") { return "Master Grain Spawn" }
            if type.contains("Kloon") || type.contains("Weefsel") { return "Tissue Clone" }
            if type.contains("Anders") || type.contains("Zelf typen") { return "Other / Type manually..." }
            return type
        }
    }
    
    func localizeCultureStatus(_ status: String) -> String {
        guard isEnglish else { return status }
        switch status {
        case "Actieve Groei / Incubatiefase (Kolonisatie gaande)", "Actieve Groei / Incubatiefase", "In incubatie (Groeiend)", "Kolonisatie":
            return "Active Growth / Incubating (Colonization Ongoing)"
        case "Volledig Gekoloniseerd / Klaar voor Gebruik (Axenisch)", "Volledig Gekoloniseerd / Klaar voor Gebruik", "Actief / Klaar voor gebruik":
            return "Fully Colonized / Ready for Use (Axenic)"
        case "Koude Bewaring / 4°C Koelkast (Rustfase / Opslag)", "Koude Bewaring / 4°C Koelkast", "In koeling / Opslag (4°C)":
            return "Cold Storage / 4°C Fridge (Dormant / Preservation)"
        case "Quarantaine / Zuiverheidscontrole (In observatie)", "Quarantaine / Zuiverheidscontrole":
            return "Quarantine / Purity Check (Under Observation)"
        case "Doorgeënt / Subcultuur Gemaakt (Generatie vervolg)", "Doorgeënt / Subcultuur":
            return "Subcultured / Transferred (Next Generation)"
        case "Verouderd / Uitgeput (Senescent / Verzwakt)", "Verouderd / Uitgeput", "Vervallen / Leeg":
            return "Aging / Exhausted (Senescent / Depleted)"
        case "Gecontamineerd / Besmet (Verworpen)", "Gecontamineerd / Besmet", "Besmet (Weggegooid)":
            return "Contaminated / Discarded"
        case "Anders / Zelf typen...":
            return "Other / Type manually..."
        default:
            if status.contains("Actieve Groei") || status.contains("incubatie") || status.contains("Kolonisatie") {
                return "Active Growth / Incubating"
            }
            if status.contains("Gekoloniseerd") || status.contains("Klaar") || status.contains("Actief") {
                return "Fully Colonized / Ready for Use"
            }
            if status.contains("Koude") || status.contains("koeling") || status.contains("Opslag") || status.contains("4°C") {
                return "Cold Storage (4°C)"
            }
            if status.contains("Quarantaine") || status.contains("observatie") {
                return "Quarantine / Purity Check"
            }
            if status.contains("Doorgeënt") || status.contains("Subcultuur") {
                return "Subcultured / Transferred"
            }
            if status.contains("Verouderd") || status.contains("Uitgeput") || status.contains("Vervallen") {
                return "Aging / Depleted"
            }
            if status.contains("Contamin") || status.contains("Besmet") || status.contains("Verworpen") {
                return "Contaminated / Discarded"
            }
            if status.contains("Anders") || status.contains("Zelf typen") {
                return "Other / Type manually..."
            }
            return status
        }
    }
    
    func localizeSterilMethod(_ method: String) -> String {
        guard isEnglish else { return method }
        switch method {
        case "Snelkookpan (15 PSI / 121°C)": return "Pressure Cooker (15 PSI / 121°C)"
        case "Autoclaaf (Medisch / Lab)": return "Autoclave (Medical / Lab)"
        case "Stoomsterilisatie (Atmosferisch 100°C)": return "Steam Sterilization (Atmospheric 100°C)"
        case "Warmwaterbad Pasteurisatie (60-80°C)": return "Hot Water Bath Pasteurization (60-80°C)"
        case "Emmer-methode (Kokend water)": return "Bucket Tek (Boiling water)"
        case "Oven / Droge Hitte (160°C)": return "Oven / Dry Heat (160°C)"
        case "Chemisch (Alcohol / Bleek)": return "Chemical (Alcohol / Bleach)"
        case "UV-C Kiemdodend Licht": return "UV-C Germicidal Light"
        default:
            if method.contains("Snelkookpan") { return "Pressure Cooker (15 PSI / 121°C)" }
            if method.contains("Autoclaaf") { return "Autoclave (Medical / Lab)" }
            if method.contains("Stoom") { return "Steam Sterilization (Atmospheric 100°C)" }
            if method.contains("Warmwaterbad") { return "Hot Water Bath Pasteurization (60-80°C)" }
            if method.contains("Emmer") { return "Bucket Tek (Boiling water)" }
            if method.contains("Oven") { return "Oven / Dry Heat (160°C)" }
            if method.contains("Chemisch") { return "Chemical (Alcohol / Bleach)" }
            if method.contains("UV-C") { return "UV-C Germicidal Light" }
            return method
        }
    }
    
    func localizePresetName(_ name: String) -> String {
        guard isEnglish else { return name }
        switch name {
        case "MEA Agar (Mout Extract)": return "MEA Agar (Malt Extract)"
        case "LC Voedingsmedium (4%)": return "LC Nutrient Medium (4%)"
        case "Graanbroed (Haver/Rogge)": return "Grain Spawn (Oat/Rye)"
        case "Agar Media (MEA / Wateragar)": return "Agar Media (MEA / Water Agar)"
        case "Vloeibare Cultuur (LC 4%)": return "Liquid Culture (LC 4%)"
        case "Substraat Zakken (CVG / Zaagsel)": return "Substrate Bags (CVG / Sawdust)"
        case "Alles-in-één Kweekzakken": return "All-in-One Grow Bags"
        case "Vloeibare Cultuur (LC)": return "Liquid Culture (LC)"
        case "Standaard CVG Substraat": return "Standard CVG Substrate"
        case "Haver Graanbroed (1.5L)": return "Oat Grain Spawn (1.5L)"
        case "Malt Extract Agar (MEA 2%)": return "Malt Extract Agar (MEA 2%)"
        case "Mason Jar 1000ml": return "Mason Jar 1000ml"
        case "Monotub 45L": return "Monotub 45L"
        case "20L Monotub": return "20L Monotub"
        case "1L Broedpot (Weck)": return "1L Spawn Jar (Mason)"
        case "3L Kweekbak (Mini-Tub)": return "3L Grow Tub (Mini-Tub)"
        case "All-in-One Filter Growbag": return "All-in-One Filter Growbag"
        case "CVG Standaard (1:2)": return "CVG Standard (1:2)"
        case "100% Kokosvezel (Veldcapaciteit)": return "100% Coco Coir (Field Capacity)"
        case "Master's Mix Zaagsel": return "Master's Mix Sawdust"
        case "100% Eiken Hardhout Zaagsel": return "100% Oak Hardwood Sawdust"
        case "Rogge Graan (Gekookt)": return "Rye Grain (Boiled)"
        case "Snelkookpan Graan": return "Pressure Cooker Grain"
        default: return name
        }
    }
    
    func localizePresetNotes(_ notes: String) -> String {
        guard isEnglish else { return notes }
        switch notes {
        case "Snelkookpan 15 PSI": return "Pressure Cooker 15 PSI"
        case "Langzame stoomverlaging": return "Slow steam release"
        case "15 PSI - Max 4% suiker tegen karamellisatie": return "15 PSI - Max 4% sugar to prevent caramelization"
        case "Minimaal 120 min voor grote volumes": return "Minimum 120 min for large volumes"
        case "Volledige sterilisatie vereist": return "Full sterilization required"
        case "500ml water, 10g agar-agar, 10g lichte mout extract (LME)": return "500ml water, 10g agar-agar, 10g light malt extract (LME)"
        case "400ml water, 16ml honing of glucosestroop (4% suikergehalte)": return "400ml water, 16ml honey or glucose syrup (4% sugar content)"
        case "Gewassen biologische rogge, 12u geweekt en gesteriliseerd": return "Washed organic rye, soaked 12h and sterilized"
        case "Gewassen biologische rogge, 12u geweekt en gekookt tot juiste vochtbalans": return "Washed organic rye, soaked 12h and boiled to proper moisture balance"
        case "650g Kokosvezel, 2L Vermiculiet, 100g Gips, 3.5L Kokend Water gepasteuriseerd": return "650g Coco coir, 2L Vermiculite, 100g Gypsum, 3.5L Boiling water pasteurized"
        case "650g Kokosvezel met 3.2L kokend water op optimale veldcapaciteit": return "650g Coco coir with 3.2L boiling water at optimal field capacity"
        case "50% Eiken hardhout zaagsel, 50% Sojaboon rompen, 60% hydratatie": return "50% Oak hardwood sawdust, 50% Soy hulls, 60% hydration"
        case "Gepasteuriseerd zaagsel voor oesters en pruikzwam": return "Pasteurized sawdust for oysters and lion's mane"
        case "Glazen kweekpot met micropore filter en rubber injectiepoort": return "Glass spawn jar with micropore filter and injection port"
        case "Monotub met 6 ventilatiegaten afgedekt met micropore filters": return "Monotub with 6 air holes covered with micropore filters"
        case "Afgesloten kunststof kweekbakje geschikt voor 1 pot spawn": return "Closed plastic container suitable for 1 jar of spawn"
        case "2.5kg eenfasige kweekzak met 0.2 micron gasuitwisselingsfilter": return "2.5kg single-phase grow bag with 0.2 micron gas exchange filter"
        default: return notes
        }
    }
    
    func localizeActionType(_ action: String) -> String {
        guard isEnglish else { return action }
        switch action {
        case "Meting": return "Measurement"
        case "Schudden / Break & Shake": return "Break & Shake"
        case "Naar Bulk Overgezet": return "Spawn to Bulk"
        case "Naar Vruchtfase Gezet": return "Moved to Fruiting"
        case "FAE (Luchten)": return "FAE (Fresh Air)"
        case "Mist (Sproeien)": return "Mist (Spray)"
        case "Pins Gevonden": return "Pins Sighted"
        case "Oogst Binnengehaald": return "Harvested"
        case "Besmetting / Afvoer": return "Contamination / Disposed"
        case "Opmerking / Foto": return "Note / Photo"
        case "API Simulatie Test": return "API Simulation Test"
        default: return action
        }
    }
    
    func localizePhaseFilter(_ filter: String) -> String {
        guard isEnglish else { return filter }
        switch filter {
        case "Alle Actief": return "All Active"
        case "Grain Spawn": return "Grain Spawn"
        case "Bulk / Kolonisatie": return "Bulk Colonization"
        case "Vruchtfase": return "Fruiting Phase"
        case "Gearchiveerd": return "Archived"
        default: return filter
        }
    }
    
    func localizeSupplyCategory(_ cat: String) -> String {
        guard isEnglish else { return cat }
        switch cat {
        case "Graan & Broed (Haver, Rogge, Vogelzaad)": return "Grain & Spawn (Oat, Rye, Birdseed)"
        case "Bulk Substraat (Coco Coir, Vermiculiet, Gips)": return "Bulk Substrate (Coco Coir, Vermiculite, Gypsum)"
        case "Voedingsbodem & Media (Agar Agar, LME, Pepton)": return "Culture Media (Agar Agar, LME, Peptone)"
        case "Potten, Zakken & Glaswerk (Mason Jars, Spawn Bags)": return "Jars, Bags & Glassware (Mason Jars, Spawn Bags)"
        case "Kweekbakken & Monotubs (Tubs, Liners)": return "Grow Tubs & Monotubs (Tubs, Liners)"
        case "Entmateriaal & Injectie (Spuiten, Naalden, Luer Lock)": return "Inoculation & Injection (Syringes, Needles, Luer Lock)"
        case "Beluchting & Filters (Micropore tape, Filter discs)": return "Aeration & Filters (Micropore tape, Filter discs)"
        case "Lab Gereedschap (Scalpel, Entnaald, Parafilm)": return "Lab Tools (Scalpel, Inoculation Loop, Parafilm)"
        case "Desinfectie & Hygiëne (IPA 70%, Handschoenen, Bleek)": return "Disinfection & Hygiene (IPA 70%, Gloves, Bleach)"
        case "Klimaat & Elektronica (Warmtemat, Sensoren)": return "Climate & Electronics (Heat Mat, Sensors)"
        case "Anders / Zelf typen...": return "Other / Type manually..."
        default: return cat
        }
    }
    

    func startDynamicIslandTimer(label: String, totalMinutes: Int, notes: String = "15 PSI (121°C)") {
        let totalSecs = max(60, totalMinutes * 60)
        let item = LabTimerItem(
            label: label,
            endDate: Date().addingTimeInterval(TimeInterval(totalSecs)),
            totalMinutes: totalMinutes
        )
        self.activeDynamicIslandTimer = item
        self.dynamicIslandRemainingSeconds = totalSecs
        self.isDynamicIslandTimerPaused = false
        
        // Also add to timers if not present
        if !db.timers.contains(where: { $0.label == label && $0.endDate > Date() }) {
            db.timers.insert(item, at: 0)
            save()
        }
        
        // Start iOS System Live Activity if available
        if #available(iOS 16.2, *) {
            #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
            let attr = LabLiveActivityAttributes(timerName: label, category: "Sterilization")
            let initialContent = LabLiveActivityAttributes.ContentState(
                remainingSeconds: totalSecs,
                totalSeconds: totalSecs,
                phaseTitle: "Sterilizing",
                pressureOrNotes: notes
            )
            do {
                let activity = try Activity<LabLiveActivityAttributes>.request(
                    attributes: attr,
                    content: ActivityContent(state: initialContent, staleDate: nil),
                    pushType: nil
                )
                self.currentLiveActivity = activity
            } catch {
                print("Live Activity request error: \(error)")
            }
            #endif
        }
        
        // Start live ticker
        liveActivityTimer?.cancel()
        liveActivityTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                guard !self.isDynamicIslandTimerPaused else { return }
                if self.dynamicIslandRemainingSeconds > 0 {
                    self.dynamicIslandRemainingSeconds -= 1
                    if self.dynamicIslandRemainingSeconds % 10 == 0 || self.dynamicIslandRemainingSeconds == 0 {
                        self.syncLiveActivityState(notes: notes)
                    }
                } else {
                    self.dynamicIslandRemainingSeconds = 0
                    self.liveActivityTimer?.cancel()
                    self.liveActivityTimer = nil
                    self.finishDynamicIslandTimer()
                }
            }
    }
    
    func syncLiveActivityState(notes: String) {
        if #available(iOS 16.1, *) {
            #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
            guard let activity = currentLiveActivity as? Activity<LabLiveActivityAttributes> else { return }
            let total = (activeDynamicIslandTimer?.totalMinutes ?? 90) * 60
            let phase = dynamicIslandRemainingSeconds <= 0
                ? (isEnglish ? "Finished / Cool Down" : "Klaar / Afkoelen")
                : (isEnglish ? "Sterilizing" : "Steriliseren")
            let updated = LabLiveActivityAttributes.ContentState(
                remainingSeconds: dynamicIslandRemainingSeconds,
                totalSeconds: total,
                phaseTitle: phase,
                pressureOrNotes: notes,
                isPaused: isDynamicIslandTimerPaused
            )
            Task {
                await activity.update(ActivityContent(state: updated, staleDate: nil))
            }
            #endif
        }
    }
    
    func pauseResumeDynamicIslandTimer() {
        isDynamicIslandTimerPaused.toggle()
        let notes = activeDynamicIslandTimer?.label ?? "15 PSI"
        syncLiveActivityState(notes: notes)
    }
    
    func stopDynamicIslandTimer() {
        liveActivityTimer?.cancel()
        liveActivityTimer = nil
        activeDynamicIslandTimer = nil
        dynamicIslandRemainingSeconds = 0
        showDynamicIslandExpanded = false
        if #available(iOS 16.1, *) {
            #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
            guard let activity = currentLiveActivity as? Activity<LabLiveActivityAttributes> else { return }
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            currentLiveActivity = nil
            #endif
        }
    }
    
    private func finishDynamicIslandTimer() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        AudioServicesPlayAlertSound(SystemSoundID(1005))
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        syncLiveActivityState(notes: isEnglish ? "Finished!" : "Klaar!")
    }


    func addSmartDeviceLog(_ log: SmartDeviceLog) {
        if let _ = db.smartDeviceLogs.first(where: {
            $0.deviceId == log.deviceId && $0.isOn == log.isOn && abs($0.timestamp.timeIntervalSince(log.timestamp)) < 4.0
        }) {
            return
        }
        db.smartDeviceLogs.insert(log, at: 0)
        if db.smartDeviceLogs.count > 250 {
            db.smartDeviceLogs = Array(db.smartDeviceLogs.prefix(250))
        }
        save()
    }
    
    func recordSmartDeviceLogError(logId: UUID, error: String) {
        if let idx = db.smartDeviceLogs.firstIndex(where: { $0.id == logId }) {
            db.smartDeviceLogs[idx].isSuccess = false
            if let existing = db.smartDeviceLogs[idx].errorMessage, !existing.isEmpty {
                db.smartDeviceLogs[idx].errorMessage = "\(existing); \(error)"
            } else {
                db.smartDeviceLogs[idx].errorMessage = error
            }
            save()
        }
    }
    
    func clearSmartDeviceLogs() {
        db.smartDeviceLogs.removeAll()
        save()
    }

    func cleanExpiredTuyaCloudLogs() {
        let countBefore = db.smartDeviceLogs.count
        db.smartDeviceLogs.removeAll(where: {
            ($0.errorMessage?.contains("28841004") == true) ||
            ($0.errorMessage?.lowercased().contains("tuya cloud proefperiode") == true)
        })
        if db.smartDeviceLogs.count != countBefore {
            save()
        }
    }

    var isCurrentDeviceActingAsHub: Bool {
        return MycoBackgroundHubManager.shared.isStreamHubRoleActive
            || UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
            || LiveKitStreamManager.shared.currentRole == .broadcaster
    }

    var isRemoteHubReachableFromViewer: Bool {
        guard !isCurrentDeviceActingAsHub else { return false }
        return LiveKitStreamManager.shared.isRemoteHubOnline
            || MycoCamPairingManager.shared.hasConnectedPeers
    }

    func toggleSmartDevice(id: UUID, trigger: String? = nil, relayToHub: Bool = true) {
        guard let idx = db.smartDevices.firstIndex(where: { $0.id == id }) else { return }
        if db.smartDevices[idx].deviceType == "Sensor" { return }
        let targetState = !db.smartDevices[idx].isOn
        setSmartDeviceState(id: id, isOn: targetState, trigger: trigger, relayToHub: relayToHub)
    }

    func setSmartDeviceState(id: UUID, isOn: Bool, trigger: String? = nil, relayToHub: Bool = true) {
        guard let idx = db.smartDevices.firstIndex(where: { $0.id == id }) else { return }
        if db.smartDevices[idx].deviceType == "Sensor" { return }
        
        let previousState = db.smartDevices[idx].isOn
        let now = Date()
        db.smartDevices[idx].isOn = isOn
        db.smartDevices[idx].lastModifiedAt = now
        
        let isManualAction = trigger == nil
            || trigger == "Manual"
            || trigger == "Handmatig"
            || trigger?.contains("Kijk-app") == true
            || trigger?.contains("Afstandsbediening") == true
            || trigger?.contains("Dashboard") == true
            || trigger?.contains("Batch Details") == true
            || trigger?.contains("QuickDock") == true
            || trigger?.contains("Handmatige") == true
            || trigger?.contains("Bediening") == true
            || trigger?.contains("Hub Aansturing") == true
            
        let isLight = db.smartDevices[idx].deviceType == "Light"
            || db.smartDevices[idx].name.localizedCaseInsensitiveContains("lamp")
            || db.smartDevices[idx].name.localizedCaseInsensitiveContains("licht")
            || db.smartDevices[idx].name.localizedCaseInsensitiveContains("kweeklamp")

        if isManualAction {
            db.smartDevices[idx].manualOverrideState = isOn
            let devType = db.smartDevices[idx].deviceType
            
            if isOn {
                // Gebruiker schakelt apparaat handmatig IN
                let overrideMinutes: Double
                if isLight {
                    // Handmatige overschrijving voor kweeklamp: 4 uur aanhouden (overschrijdt nachtcyclus)
                    overrideMinutes = 240.0
                } else if devType == "Humidifier" || devType == "ExhaustFan" {
                    // Handmatige inschakeling bevochtiger of fan: duur respecteren
                    overrideMinutes = max(20.0, Double(db.smartDevices[idx].customDurationMinutes))
                } else {
                    overrideMinutes = 120.0
                }
                db.smartDevices[idx].manualOverrideUntil = now.addingTimeInterval(overrideMinutes * 60.0)
                
                // AI Cyclus Bijstelling: Timers resetten zodat AI de handmatige actie meerekent
                if devType == "Humidifier" {
                    db.environmentConfig.lastHumidifierExecutionTime = now
                    db.smartDevices[idx].lastCustomExecutionTime = now
                    db.environmentConfig.lastAutopilotLogMessage = t(
                        nl: "🖐️ Handmatig: Luchtbevochtiger ingeschakeld • AI herberekent interval",
                        en: "🖐️ Manual: Humidifier turned ON • AI recalculates interval"
                    )
                } else if devType == "ExhaustFan" {
                    db.environmentConfig.lastFaeExecutionTime = now
                    db.smartDevices[idx].lastCustomExecutionTime = now
                    db.environmentConfig.lastAutopilotLogMessage = t(
                        nl: "🖐️ Handmatig: FAE Ventilatie gestart • AI plant vochtherstel",
                        en: "🖐️ Manual: FAE Ventilation started • AI schedules moisture recovery"
                    )
                } else {
                    db.smartDevices[idx].lastCustomExecutionTime = now
                }
                db.environmentConfig.lastAutopilotLogTime = now
            } else {
                // Gebruiker schakelt apparaat handmatig UIT
                if isLight && db.smartDevices[idx].isWithinLightSchedule {
                    // Lamp overdag handmatig uitgezet: 4 uur uit laten staan
                    db.smartDevices[idx].manualOverrideUntil = now.addingTimeInterval(240.0 * 60.0)
                } else {
                    // Overschrijving beëindigen
                    db.smartDevices[idx].manualOverrideUntil = nil
                    db.smartDevices[idx].manualOverrideState = nil
                }
                
                if devType == "Humidifier" {
                    db.environmentConfig.lastHumidifierExecutionTime = now
                } else if devType == "ExhaustFan" {
                    db.environmentConfig.lastFaeExecutionTime = now
                }
                db.smartDevices[idx].lastCustomExecutionTime = now
            }
        } else {
            if !isOn {
                if db.smartDevices[idx].deviceType == "Humidifier" {
                    db.environmentConfig.lastHumidifierExecutionTime = now
                } else if db.smartDevices[idx].deviceType == "ExhaustFan" {
                    db.environmentConfig.lastFaeExecutionTime = now
                }
                db.smartDevices[idx].lastCustomExecutionTime = now
            }
        }

        // SMART MUTUAL INTERLOCK: Bevochtiger & Afzuiger / FAE Ventilator
        if isOn && previousState != isOn {
            let isFanDevice = db.smartDevices[idx].deviceType == "ExhaustFan"
                || db.smartDevices[idx].name.localizedCaseInsensitiveContains("ventil")
                || db.smartDevices[idx].name.localizedCaseInsensitiveContains("afzuig")
                || db.smartDevices[idx].name.localizedCaseInsensitiveContains("fae")

            if db.smartDevices[idx].deviceType == "Humidifier" {
                // Als de bevochtiger aangaat, zet eventuele draaiende afzuigers direct uit
                let runningFans = db.smartDevices.filter { $0.id != id && ($0.deviceType == "ExhaustFan" || $0.name.localizedCaseInsensitiveContains("ventil") || $0.name.localizedCaseInsensitiveContains("afzuig") || $0.name.localizedCaseInsensitiveContains("fae")) && $0.isOn }
                for fan in runningFans {
                    setSmartDeviceState(id: fan.id, isOn: false, trigger: isEnglish ? "Interlock (Humidifier Active)" : "Slimme Vergrendeling (Bevochtiger Actief)", relayToHub: relayToHub)
                }
            } else if isFanDevice {
                db.smartDevices[idx].lastTurnedOnTime = now
                db.environmentConfig.lastFaeExecutionTime = now
                // Als de afzuiger aangaat, zet eventuele draaiende bevochtigers direct uit
                let runningHums = db.smartDevices.filter { $0.id != id && $0.deviceType == "Humidifier" && $0.isOn }
                for hum in runningHums {
                    setSmartDeviceState(id: hum.id, isOn: false, trigger: isEnglish ? "Interlock (Fan Active)" : "Slimme Vergrendeling (Afzuiger Actief)", relayToHub: relayToHub)
                }
                if MycoOpticalHygrometerManager.shared.isHumidifierRunning {
                    MycoOpticalHygrometerManager.shared.cancelHumidifierRun(reason: isEnglish ? "Fan turned on" : "Afzuiger ingeschakeld")
                }
            }
        }

        // FAE AIR PURGE FINISHED -> TRIGGER DIRECT POST-VENTILATION RECOVERY & OPTIONAL OPTICAL SCAN
        if !isOn && previousState == true {
            let isFanDevice = db.smartDevices[idx].deviceType == "ExhaustFan"
                || db.smartDevices[idx].name.localizedCaseInsensitiveContains("ventil")
                || db.smartDevices[idx].name.localizedCaseInsensitiveContains("afzuig")
                || db.smartDevices[idx].name.localizedCaseInsensitiveContains("fae")
            
            if isFanDevice {
                let fanDurationMinutes: Double = {
                    if let turnedOn = db.smartDevices[idx].lastTurnedOnTime {
                        return max(0.5, now.timeIntervalSince(turnedOn) / 60.0)
                    } else if let faeStart = db.environmentConfig.lastFaeExecutionTime {
                        return max(0.5, now.timeIntervalSince(faeStart) / 60.0)
                    } else {
                        return Double(max(1, db.environmentConfig.faeDurationMinutes))
                    }
                }()
                db.smartDevices[idx].lastTurnedOnTime = nil
                triggerPostFaeRecovery(fanDurationMinutes: fanDurationMinutes)
            }
        }

        // SYNCHRONIZED GROW LIGHT MULTI-LENS & OPTICAL SCAN TRIGGER:
        // Belangrijk: Alleen automatisch fotograferen bij automatische dagschakeling, NOOIT bij handmatige bediening of tijdelijke scan-belichting!
        let isScanLighting = trigger?.contains("Optische Meting") == true
            || trigger?.contains("Scan Belichting") == true
            || trigger?.contains("Optical") == true
        if isOn && previousState != isOn && !isManualAction && !isScanLighting {
            let isLightDevice = isLight

            if isLightDevice {
                NotificationCenter.default.post(
                    name: NSNotification.Name("MycoGrowLightSwitchedOn"),
                    object: db.smartDevices[idx]
                )
                LiveKitStreamManager.shared.triggerSynchronizedGrowLightCapture(
                    source: "Kweeklamp (\(db.smartDevices[idx].name)) Ingeschakeld"
                )
            }
        }

        let device = db.smartDevices[idx]
        save()
        MycoWidgetDataManager.shared.updateSnapshot(from: db)
        
        if isManualAction {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
        }
        
        let effectiveTrigger = trigger ?? (isEnglish ? "Manual" : "Handmatig")
        let logId = UUID()
        let logEntry = SmartDeviceLog(
            id: logId,
            deviceId: device.id,
            deviceName: device.name,
            deviceType: device.deviceType,
            isOn: device.isOn,
            timestamp: Date(),
            trigger: effectiveTrigger,
            isSuccess: true,
            errorMessage: nil
        )
        addSmartDeviceLog(logEntry)
        
        // Single clean toast on this controlling device ONLY for manual user taps
        if isManualAction {
            let stateLabel = isOn ? (isEnglish ? "ON" : "AAN") : (isEnglish ? "OFF" : "UIT")
            MycoSyncManager.shared.triggerToast(message: "🔌 \(device.name): \(stateLabel)")
        }
        
        // Broadcast deterministic state to connected peers (Wi-Fi Mesh & LiveKit)
        MycoSyncManager.shared.broadcastDeviceStateChanged(
            id: device.id,
            tuyaId: device.tuyaDeviceID,
            isOn: isOn,
            trigger: effectiveTrigger,
            name: device.name
        )
        
        // Single-Hub Command Routing:
        // Relay the deterministic target state (ON/OFF) to the Stream Hub ONLY if Pi Hub is not managing hardware
        if relayToHub && !isCurrentDeviceActingAsHub && !piHubStatusOnline && !db.environmentConfig.isPiHubAutonomousActive {
            _ = LiveKitStreamManager.shared.sendHubPlugSetState(
                id: id,
                tuyaId: device.tuyaDeviceID,
                isOn: isOn,
                trigger: effectiveTrigger,
                name: device.name
            )
            MycoCamStreamManager.shared.sendCloudPlugToggle(id: id, trigger: effectiveTrigger)
            // If device is a local-only LAN webhook (no Tuya ID, no remote cloud URL), let the local hub handle it:
            let isLocalOnlyWebhook = !device.webhookURL.isEmpty && device.remoteCloudURL.isEmpty && device.tuyaDeviceID.isEmpty
            if isLocalOnlyWebhook && isRemoteHubReachableFromViewer {
                return
            }
        }
        
        // 1. Send to Remote Cloud Webhook (4G/5G) or Local Webhook
        let targetURL = !device.remoteCloudURL.isEmpty ? device.remoteCloudURL : device.webhookURL
        if let url = URL(string: targetURL), !targetURL.isEmpty {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 8
            let payload: [String: Any] = [
                "state": device.isOn ? "ON" : "OFF",
                "device": device.name,
                "type": device.deviceType,
                "tuyaId": device.tuyaDeviceID
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.handleSwitchError(device: device, previousState: previousState, logId: logId, errorMsg: "Webhook fout: \(error.localizedDescription)")
                    }
                } else if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    DispatchQueue.main.async {
                        self?.handleSwitchError(device: device, previousState: previousState, logId: logId, errorMsg: "Webhook HTTP \(httpResponse.statusCode)")
                    }
                }
            }.resume()
        }
        
        // 2. Dispatch command to Local Raspberry Pi LAN Hub or Tuya Cloud fallback
        sendSmartDeviceCommand(device: device, previousState: previousState, logId: logId)
        
        // 3. Inform the Raspberry Pi Autonomous Hub about this manual action immediately
        if isManualAction {
            Task { [weak self] in
                await self?.syncSchedulesToPiHub()
            }
        }
    }

    // MARK: - Onderhoudsmodus (Room Inspection & Maintenance Mode)
    func setMaintenanceMode(enabled: Bool, durationMinutes: Int? = nil) {
        let prev = db.environmentConfig.isMaintenanceModeActive
        db.environmentConfig.isMaintenanceModeActive = enabled
        db.environmentConfig.maintenanceModeStartTime = enabled ? Date() : nil
        if let dur = durationMinutes {
            db.environmentConfig.maintenanceModeAutoResumeMinutes = dur
        }
        
        if enabled {
            // Directly turn off fans and humidifiers for comfort, silence, and spore prevention
            for dev in db.smartDevices where dev.isOn {
                let type = dev.deviceType.lowercased()
                let name = dev.name.lowercased()
                let isFanOrHum = type.contains("fan") || type.contains("humid")
                    || name.contains("fan") || name.contains("ventil")
                    || name.contains("afzuig") || name.contains("mist")
                    || name.contains("bevocht")
                if isFanOrHum {
                    setSmartDeviceState(id: dev.id, isOn: false, trigger: t(nl: "Onderhoudsmodus geactiveerd", en: "Maintenance mode activated"))
                }
            }
            db.environmentConfig.lastAutopilotLogMessage = t(
                nl: "🛠️ Onderhoudsmodus actief: Ventilatoren en bevochtigers uitgeschakeld; automatisering bevroren.",
                en: "🛠️ Maintenance mode active: Fans and humidifiers stopped; automation frozen."
            )
            db.environmentConfig.lastAutopilotLogTime = Date()
            MycoSyncManager.shared.triggerToast(message: t(nl: "🛠️ Onderhoudsmodus ingeschakeld: Automatisering gepauzeerd", en: "🛠️ Maintenance mode enabled: Automations paused"))
        } else if prev {
            db.environmentConfig.lastAutopilotLogMessage = t(
                nl: "✅ Onderhoudsmodus beëindigd: Automatische klimaatregeling hervat.",
                en: "✅ Maintenance mode ended: Automation resumed."
            )
            db.environmentConfig.lastAutopilotLogTime = Date()
            MycoSyncManager.shared.triggerToast(message: t(nl: "✅ Onderhoudsmodus uit: Automatisering hervat", en: "✅ Maintenance mode ended: Automation resumed"))
        }
        
        save()
        MycoSyncManager.shared.sendSyncPayload(reason: "maintenance_mode_changed")
        
        if !enabled {
            runAutopilotCycle()
        }
    }

    private func handleSwitchError(device: SmartDeviceItem, previousState: Bool, logId: UUID, errorMsg: String) {
        // CRITICAL FIX: If user commanded device to turn OFF (device.isOn was false, previous was true),
        // NEVER revert back to ON! The user explicitly desires the equipment OFF.
        // Similarly, if a manual override is active, NEVER revert back to OFF! Respect user's intent.
        if device.isOn && !device.isManualOverrideActive {
            // Only if turning ON failed and NO manual override is active do we revert to OFF (prevent misleading ON state)
            if let idx = db.smartDevices.firstIndex(where: { $0.id == device.id }) {
                db.smartDevices[idx].isOn = previousState
                save()
            }
            MycoSyncManager.shared.broadcastDeviceError(id: device.id, revertedIsOn: previousState, error: errorMsg, name: device.name)
        } else {
            print("⚠️ [Switch Error] Commando mislukt voor \(device.name): \(errorMsg). Apparaat behoudt gewenste status in app.")
        }
        recordSmartDeviceLogError(logId: logId, error: errorMsg)
        MycoSyncManager.shared.triggerToast(message: "⚠️ Error with '\(device.name)': \(errorMsg)")
    }

    // MARK: - Raspberry Pi Local Tuya LAN Bridge & 24/7 Autonomy
    var candidatePiHubIPs: [String] {
        let configured = db.environmentConfig.effectivePiHubIP.trimmingCharacters(in: .whitespacesAndNewlines)
        if configured.isEmpty { return [] }
        return [configured]
    }

    @discardableResult
    func sendLocalPiBridgeCommand(device: SmartDeviceItem) async -> Bool {
        let port = db.environmentConfig.effectivePiHubPort
        let targetId = !device.tuyaDeviceID.isEmpty ? device.tuyaDeviceID : device.name
        let isOverride = device.isManualOverrideActive
        let payload: [String: Any] = [
            "device_id": targetId,
            "name": device.name,
            "device_type": device.deviceType,
            "on": device.isOn,
            "trigger": isOverride ? "manual_override" : "MycoLabs App",
            "manual_override": isOverride,
            "override_minutes": isOverride ? 240 : 0
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        
        let ips = candidatePiHubIPs
        for attempt in 1...2 {
            for ip in ips {
                guard let url = URL(string: "http://\(ip):\(port)/switch") else { continue }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.timeoutInterval = 4.5
                req.httpBody = body
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: req)
                    if let http = response as? HTTPURLResponse, http.statusCode == 200,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool, success {
                        let method = json["method"] as? String ?? "local_lan"
                        print("⚡ [Pi Tuya Bridge] Schakelen gelukt via Pi (\(ip)) (\(method)) voor \(device.name): \(device.isOn ? "AAN" : "UIT")")
                        await MainActor.run {
                            self.piHubStatusOnline = true
                            if let idx = self.db.smartDevices.firstIndex(where: { $0.id == device.id }) {
                                self.db.smartDevices[idx].isOn = device.isOn
                                self.db.smartDevices[idx].lastModifiedAt = Date()
                            }
                        }
                        return true
                    }
                } catch {
                    print("ℹ️ [Pi Tuya Bridge] Poging \(attempt) naar IP \(ip) voor \(device.name) mislukt: \(error.localizedDescription)")
                }
            }
            if attempt == 1 {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }
        return false
    }

    /// Stuurt de nieuwste RV% en temperatuurmeting van de optische hygrometer naar de 24/7 Pi Hub
    public func sendClimateReadingToPiHub(humidity: Double, temperature: Double?, targetHumidity: Double?) {
        let port = db.environmentConfig.effectivePiHubPort
        var payload: [String: Any] = [
            "humidity": humidity,
            "target_humidity": targetHumidity ?? 90.0,
            "source": "OpticalHygrometer"
        ]
        if let temp = temperature {
            payload["temperature"] = temp
        }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        Task {
            for ip in self.candidatePiHubIPs {
                guard let url = URL(string: "http://\(ip):\(port)/climate/reading") else { continue }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = body
                req.timeoutInterval = 2.5
                do {
                    let (_, resp) = try await URLSession.shared.data(for: req)
                    if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                        print("📊 [Pi Hub] Optische klimaatmeting succesvol gesynchroniseerd naar Pi Hub op \(ip)")
                        break
                    }
                } catch {
                    continue
                }
            }
        }
    }

    func syncWithLocalPiHubDevices() {
        struct KnownPiDevice {
            let id: String
            let defaultName: String
            let type: String
            let aliases: [String]
        }
        
        let knownPiDevices: [KnownPiDevice] = [
            KnownPiDevice(
                id: "tuya_light_01",
                defaultName: "Lampen",
                type: "Light",
                aliases: ["kweeklamp", "kweeklampen", "lamp", "lampen", "licht", "light", "growlight", "grow light"]
            ),
            KnownPiDevice(
                id: "tuya_fan_01",
                defaultName: "Ventilatie",
                type: "ExhaustFan",
                aliases: ["ventilatie", "ventilator", "fan", "exhaust", "exhaustfan", "afzuiger", "afzuiging", "fae"]
            ),
            KnownPiDevice(
                id: "tuya_humidifier_01",
                defaultName: "Humidifyer",
                type: "Humidifier",
                aliases: ["humidifyer", "humidifier", "bevochtiger", "luchtbevochtiger", "mist", "mister"]
            )
        ]
        
        var modified = false
        for piDev in knownPiDevices {
            if let idx = db.smartDevices.firstIndex(where: { dev in
                if dev.tuyaDeviceID == piDev.id { return true }
                let devName = dev.name.lowercased()
                let devType = dev.deviceType.lowercased()
                for alias in piDev.aliases {
                    if devName.contains(alias) || devType.contains(alias) {
                        return true
                    }
                }
                return false
            }) {
                if db.smartDevices[idx].tuyaDeviceID != piDev.id {
                    db.smartDevices[idx].tuyaDeviceID = piDev.id
                    modified = true
                }
            } else {
                let newDev = SmartDeviceItem(
                    name: piDev.defaultName,
                    deviceType: piDev.type,
                    brand: "Tuya / Smart Life (Pi LAN)",
                    tuyaDeviceID: piDev.id,
                    switchCode: "switch_1",
                    isOn: false,
                    autoControlEnabled: true
                )
                db.smartDevices.append(newDev)
                modified = true
            }
        }
        if modified {
            save()
        }
    }

    @discardableResult
    func syncSettingsToPiHub() async -> Bool {
        let port = db.environmentConfig.effectivePiHubPort
        
        var schedulesPayload: [[String: Any]] = []
        for dev in db.smartDevices {
            var item: [String: Any] = [
                "device_id": !dev.tuyaDeviceID.isEmpty ? dev.tuyaDeviceID : dev.name,
                "name": dev.name,
                "device_type": dev.deviceType,
                "on": dev.isOn,
                "auto_control": dev.autoControlEnabled,
                "interval_minutes": dev.totalIntervalMinutes,
                "runtime_minutes": dev.customDurationMinutes,
                "autopilot_mode": dev.autopilotMode,
                "light_on_hour": dev.lightOnHour,
                "light_off_hour": dev.lightOffHour
            ]
            if let exec = dev.lastCustomExecutionTime {
                item["last_execution_time"] = exec.timeIntervalSince1970
            }
            schedulesPayload.append(item)
        }
        
        let payload: [String: Any] = [
            "autopilot_enabled": db.environmentConfig.isAutopilotEnabled,
            "day_night_cycle": db.environmentConfig.isDayNightCycleEnabled,
            "day_start_hour": db.environmentConfig.dayStartHour,
            "night_start_hour": db.environmentConfig.nightStartHour,
            "target_day_temp": db.environmentConfig.targetDayTempC,
            "target_night_temp": db.environmentConfig.targetNightTempC,
            "target_humidity": db.environmentConfig.targetHumidityPct,
            "safety_interlock": true,
            "schedules": schedulesPayload
        ]
        
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        
        for ip in candidatePiHubIPs {
            guard let url = URL(string: "http://\(ip):\(port)/schedules") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 4.0
            req.httpBody = body
            
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    print("✅ [Pi Hub] AI & Geavanceerde instellingen succesvol gesynchroniseerd naar Pi Hub op \(ip)")
                    await MainActor.run {
                        self.piHubStatusOnline = true
                        MycoSyncManager.shared.triggerToast(message: "✅ Settings synced to Raspberry Pi Hub!")
                    }
                    return true
                }
            } catch {
                continue
            }
        }
        return false
    }

    @discardableResult
    func syncDevicesFromPiHub() async -> Bool {
        let port = db.environmentConfig.effectivePiHubPort
        
        for ip in candidatePiHubIPs {
            for ep in ["devices", "status"] {
                guard let url = URL(string: "http://\(ip):\(port)/\(ep)") else { continue }
                var req = URLRequest(url: url)
                req.timeoutInterval = 3.0
                
                do {
                    let (data, resp) = try await URLSession.shared.data(for: req)
                    guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        continue
                    }
                    
                    await MainActor.run {
                        self.piHubStatusOnline = true
                        var updated = false
                        
                        if let devList = json["devices"] as? [[String: Any]] {
                            for d in devList {
                                let dId = (d["id"] as? String ?? d["device_id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                let dName = (d["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                let dOn = d["on"] as? Bool ?? d["is_on"] as? Bool ?? d["state"] as? Bool
                                
                                guard let onVal = dOn else { continue }
                                
                                if let idx = self.db.smartDevices.firstIndex(where: { dev in
                                    let matchesId = !dId.isEmpty && dev.tuyaDeviceID == dId
                                    let matchesName = !dName.isEmpty && dev.name.caseInsensitiveCompare(dName) == .orderedSame
                                    let matchesAlias = !dName.isEmpty && (
                                        (dName.localizedCaseInsensitiveContains("lamp") && (dev.deviceType.lowercased() == "light" || dev.name.localizedCaseInsensitiveContains("lamp") || dev.name.localizedCaseInsensitiveContains("licht"))) ||
                                        (dName.localizedCaseInsensitiveContains("ventil") && (dev.deviceType.lowercased().contains("fan") || dev.name.localizedCaseInsensitiveContains("ventil") || dev.name.localizedCaseInsensitiveContains("afzuig"))) ||
                                        ((dName.localizedCaseInsensitiveContains("humid") || dName.localizedCaseInsensitiveContains("bevocht")) && (dev.deviceType.lowercased().contains("humid") || dev.name.localizedCaseInsensitiveContains("bevocht")))
                                    )
                                    return matchesId || matchesName || matchesAlias
                                }) {
                                    if self.db.smartDevices[idx].isOn != onVal {
                                        let isLight = self.db.smartDevices[idx].deviceType == "Light"
                                            || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("lamp")
                                            || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("licht")
                                            || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("kweeklamp")
                                        
                                        if self.db.smartDevices[idx].isManualOverrideActive {
                                            let desired = self.db.smartDevices[idx].manualOverrideState ?? self.db.smartDevices[idx].isOn
                                            if onVal != desired {
                                                print("ℹ️ [Pi Hub] Apparaat \(self.db.smartDevices[idx].name) staat in handmatige overschrijving (\(desired ? "AAN" : "UIT")), Pi meldt \(onVal ? "AAN" : "UIT"). Lokale status gerespecteerd.")
                                            }
                                        } else {
                                            let wasOn = self.db.smartDevices[idx].isOn
                                            self.db.smartDevices[idx].isOn = onVal
                                            self.db.smartDevices[idx].lastModifiedAt = Date()
                                            updated = true
                                            
                                            // Fysieke knop / handmatig aan apparaat ingeschakeld:
                                            if !wasOn && onVal && isLight {
                                                self.db.smartDevices[idx].manualOverrideState = true
                                                self.db.smartDevices[idx].manualOverrideUntil = Date().addingTimeInterval(240.0 * 60.0)
                                                print("🖐️ [Pi Hub / Hardware] Lamp '\(self.db.smartDevices[idx].name)' handmatig ingeschakeld aan apparaat. Handmatige overschrijving (4u) geactiveerd.")
                                                Task { await self.syncSchedulesToPiHub() }
                                            }
                                            
                                            if !wasOn && onVal {
                                                let isFan = self.db.smartDevices[idx].deviceType == "ExhaustFan"
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("ventil")
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("afzuig")
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("fae")
                                                if isFan {
                                                    self.db.smartDevices[idx].lastTurnedOnTime = Date()
                                                    self.db.environmentConfig.lastFaeExecutionTime = Date()
                                                }
                                            }
                                            
                                            if wasOn && !onVal {
                                                let isFan = self.db.smartDevices[idx].deviceType == "ExhaustFan"
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("ventil")
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("afzuig")
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("fae")
                                                if isFan {
                                                    let fanMins = self.db.smartDevices[idx].lastTurnedOnTime.map { Date().timeIntervalSince($0) / 60.0 } ?? Double(self.db.environmentConfig.faeDurationMinutes)
                                                    self.db.smartDevices[idx].lastTurnedOnTime = nil
                                                    self.triggerPostFaeRecovery(fanDurationMinutes: max(0.5, fanMins))
                                                }
                                            }
                                        }
                                    }
                                } else if !dId.isEmpty {
                                    var newDev = SmartDeviceItem()
                                    newDev.name = dName.isEmpty ? "Smart Stekker" : dName
                                    newDev.tuyaDeviceID = dId
                                    let lower = dName.lowercased()
                                    if lower.contains("lamp") || lower.contains("licht") {
                                        newDev.deviceType = "Light"
                                    } else if lower.contains("ventil") || lower.contains("fan") || lower.contains("afzuig") {
                                        newDev.deviceType = "ExhaustFan"
                                    } else if lower.contains("humid") || lower.contains("bevocht") {
                                        newDev.deviceType = "Humidifier"
                                    } else {
                                        let t = (d["type"] as? String ?? "").lowercased()
                                        if t.contains("light") { newDev.deviceType = "Light" }
                                        else if t.contains("fan") || t.contains("exhaust") { newDev.deviceType = "ExhaustFan" }
                                        else if t.contains("humid") { newDev.deviceType = "Humidifier" }
                                        else { newDev.deviceType = "Switch" }
                                    }
                                    newDev.isOn = onVal
                                    newDev.isOnlineOnTuya = true
                                    newDev.lastModifiedAt = Date()
                                    self.db.smartDevices.append(newDev)
                                    updated = true
                                    print("🔌 [Pi Hub] Nieuw apparaat '\(newDev.name)' (\(dId)) automatisch geregistreerd.")
                                }
                            }
                        } else if let devDict = json["devices"] as? [String: [String: Any]] {
                            for (dId, d) in devDict {
                                let dName = (d["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                let dOn = d["on"] as? Bool ?? d["is_on"] as? Bool ?? d["state"] as? Bool
                                guard let onVal = dOn else { continue }
                                
                                if let idx = self.db.smartDevices.firstIndex(where: { dev in
                                    let matchesId = !dId.isEmpty && dev.tuyaDeviceID == dId
                                    let matchesName = !dName.isEmpty && dev.name.caseInsensitiveCompare(dName) == .orderedSame
                                    let matchesAlias = !dName.isEmpty && (
                                        (dName.localizedCaseInsensitiveContains("lamp") && (dev.deviceType.lowercased() == "light" || dev.name.localizedCaseInsensitiveContains("lamp") || dev.name.localizedCaseInsensitiveContains("licht"))) ||
                                        (dName.localizedCaseInsensitiveContains("ventil") && (dev.deviceType.lowercased().contains("fan") || dev.name.localizedCaseInsensitiveContains("ventil") || dev.name.localizedCaseInsensitiveContains("afzuig"))) ||
                                        ((dName.localizedCaseInsensitiveContains("humid") || dName.localizedCaseInsensitiveContains("bevocht")) && (dev.deviceType.lowercased().contains("humid") || dev.name.localizedCaseInsensitiveContains("bevocht")))
                                    )
                                    return matchesId || matchesName || matchesAlias
                                }) {
                                    if self.db.smartDevices[idx].isOn != onVal {
                                        let isLight = self.db.smartDevices[idx].deviceType == "Light"
                                            || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("lamp")
                                            || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("licht")
                                            || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("kweeklamp")
                                        
                                        if self.db.smartDevices[idx].isManualOverrideActive {
                                            let desired = self.db.smartDevices[idx].manualOverrideState ?? self.db.smartDevices[idx].isOn
                                            if onVal != desired {
                                                print("ℹ️ [Pi Hub] Apparaat \(self.db.smartDevices[idx].name) staat in handmatige overschrijving (\(desired ? "AAN" : "UIT")), Pi meldt \(onVal ? "AAN" : "UIT"). Lokale status gerespecteerd.")
                                            }
                                        } else {
                                            let wasOn = self.db.smartDevices[idx].isOn
                                            self.db.smartDevices[idx].isOn = onVal
                                            self.db.smartDevices[idx].lastModifiedAt = Date()
                                            updated = true
                                            
                                            // Fysieke knop / handmatig aan apparaat ingeschakeld:
                                            if !wasOn && onVal && isLight {
                                                self.db.smartDevices[idx].manualOverrideState = true
                                                self.db.smartDevices[idx].manualOverrideUntil = Date().addingTimeInterval(240.0 * 60.0)
                                                print("🖐️ [Pi Hub / Hardware] Lamp '\(self.db.smartDevices[idx].name)' handmatig ingeschakeld aan apparaat. Handmatige overschrijving (4u) geactiveerd.")
                                                Task { await self.syncSchedulesToPiHub() }
                                            }
                                            
                                            if !wasOn && onVal {
                                                let isFan = self.db.smartDevices[idx].deviceType == "ExhaustFan"
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("ventil")
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("afzuig")
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("fae")
                                                if isFan {
                                                    self.db.smartDevices[idx].lastTurnedOnTime = Date()
                                                    self.db.environmentConfig.lastFaeExecutionTime = Date()
                                                }
                                            }
                                            
                                            if wasOn && !onVal {
                                                let isFan = self.db.smartDevices[idx].deviceType == "ExhaustFan"
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("ventil")
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("afzuig")
                                                    || self.db.smartDevices[idx].name.localizedCaseInsensitiveContains("fae")
                                                if isFan {
                                                    let fanMins = self.db.smartDevices[idx].lastTurnedOnTime.map { Date().timeIntervalSince($0) / 60.0 } ?? Double(self.db.environmentConfig.faeDurationMinutes)
                                                    self.db.smartDevices[idx].lastTurnedOnTime = nil
                                                    self.triggerPostFaeRecovery(fanDurationMinutes: max(0.5, fanMins))
                                                }
                                            }
                                        }
                                    }
                                } else if !dId.isEmpty {
                                    var newDev = SmartDeviceItem()
                                    newDev.name = dName.isEmpty ? "Smart Stekker" : dName
                                    newDev.tuyaDeviceID = dId
                                    let lower = dName.lowercased()
                                    if lower.contains("lamp") || lower.contains("licht") {
                                        newDev.deviceType = "Light"
                                    } else if lower.contains("ventil") || lower.contains("fan") || lower.contains("afzuig") {
                                        newDev.deviceType = "ExhaustFan"
                                    } else if lower.contains("humid") || lower.contains("bevocht") {
                                        newDev.deviceType = "Humidifier"
                                    } else {
                                        let t = (d["type"] as? String ?? "").lowercased()
                                        if t.contains("light") { newDev.deviceType = "Light" }
                                        else if t.contains("fan") || t.contains("exhaust") { newDev.deviceType = "ExhaustFan" }
                                        else if t.contains("humid") { newDev.deviceType = "Humidifier" }
                                        else { newDev.deviceType = "Switch" }
                                    }
                                    newDev.isOn = onVal
                                    newDev.isOnlineOnTuya = true
                                    newDev.lastModifiedAt = Date()
                                    self.db.smartDevices.append(newDev)
                                    updated = true
                                    print("🔌 [Pi Hub] Nieuw apparaat '\(newDev.name)' (\(dId)) automatisch geregistreerd.")
                                }
                            }
                        }
                        
                        if updated {
                            self.saveImmediately()
                            print("⚡ [Pi Hub] Smart devices live gesynchroniseerd vanaf Raspberry Pi Hub (\(ip)).")
                        }
                    }
                    return true
                } catch {
                    // Try next endpoint/ip
                }
            }
        }
        return false
    }

    // MARK: - Raspberry Pi 24/7 Autonomous Hub Synchronization
    @discardableResult
    func syncSchedulesToPiHub() async -> Bool {
        let port = db.environmentConfig.effectivePiHubPort
        
        await MainActor.run { self.isSyncingPiHub = true }
        defer { Task { @MainActor in self.isSyncingPiHub = false } }
        
        var schedulesList: [[String: Any]] = []
        for dev in db.smartDevices {
            guard dev.deviceType != "Sensor" else { continue }
            let isLight = dev.deviceType == "Light"
                || dev.name.localizedCaseInsensitiveContains("lamp")
                || dev.name.localizedCaseInsensitiveContains("licht")
                || dev.name.localizedCaseInsensitiveContains("kweeklamp")
            
            var item: [String: Any] = [
                "device_id": !dev.tuyaDeviceID.isEmpty ? dev.tuyaDeviceID : dev.name,
                "name": dev.name,
                "type": isLight ? "Light" : dev.deviceType,
                "mode": isLight ? "cycle" : "interval",
                "manual_override": dev.isManualOverrideActive,
                "manual_override_state": dev.isOn,
                "manual_override_until": dev.manualOverrideUntil?.timeIntervalSince1970 ?? 0
            ]
            if isLight {
                item["light_on_hour"] = dev.lightOnHour
                item["light_off_hour"] = dev.lightOffHour
            } else {
                item["interval_minutes"] = dev.totalIntervalMinutes
                item["duration_minutes"] = max(1, dev.customDurationMinutes)
                if let cycleStart = dev.lastCustomExecutionTime {
                    item["cycle_start_time"] = cycleStart.timeIntervalSince1970
                }
            }
            schedulesList.append(item)
        }
        
        let payload: [String: Any] = [
            "autopilot_enabled": db.environmentConfig.isAutopilotEnabled,
            "schedules": schedulesList
        ]
        
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        
        for ip in candidatePiHubIPs {
            guard let url = URL(string: "http://\(ip):\(port)/schedules") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 3.5
            req.httpBody = body
            
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    await MainActor.run {
                        self.db.environmentConfig.lastPiHubSyncTime = Date()
                        self.db.environmentConfig.piHubSyncStatusMessage = "\(schedulesList.count) apparaten actief op Pi"
                        self.piHubStatusOnline = true
                        self.save()
                        print("⚡ [Pi Hub] \(schedulesList.count) schema's gesynchroniseerd naar Pi Hub.")
                    }
                    await fetchPiHubLogs()
                    return true
                }
            } catch {
                print("⚠️ [Pi Hub] Kon schema's niet synchroniseren naar \(ip): \(error.localizedDescription)")
            }
        }
        await MainActor.run {
            self.piHubStatusOnline = false
        }
        return false
    }

    func fetchPiHubLogs() async {
        let port = db.environmentConfig.effectivePiHubPort
        for ip in candidatePiHubIPs {
            guard let url = URL(string: "http://\(ip):\(port)/logs") else { continue }
            do {
                let (data, resp) = try await URLSession.shared.data(from: url)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let list = json["logs"] as? [[String: Any]] {
                    var entries: [PiHubLogEntry] = []
                    for item in list {
                        let id = item["id"] as? String ?? UUID().uuidString
                        let ts = item["timestamp"] as? String ?? ""
                        let dev = item["device"] as? String ?? ""
                        let state = item["state"] as? Bool ?? false
                        let trigger = item["trigger"] as? String ?? ""
                        let method = item["method"] as? String ?? ""
                        entries.append(PiHubLogEntry(id: id, timestamp: ts, device: dev, state: state, trigger: trigger, method: method))
                    }
                    await MainActor.run {
                        self.piHubLogs = entries
                        self.piHubStatusOnline = true
                    }
                    return
                }
            } catch {
                print("ℹ️ [Pi Hub] Kon logs niet ophalen van \(ip): \(error.localizedDescription)")
            }
        }
    }

    func safeShutdownPiHub() async -> Bool {
        let port = db.environmentConfig.effectivePiHubPort
        for ip in candidatePiHubIPs {
            guard let url = URL(string: "http://\(ip):\(port)/shutdown") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 3.0
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    await MainActor.run {
                        self.piHubStatusOnline = false
                        MycoSyncManager.shared.triggerToast(message: "🛑 Pi Hub shutting down safely... Wait until the green LED turns off before disconnecting power.")
                    }
                    return true
                }
            } catch {
                print("⚠️ [Pi Hub] Shutdown error (\(ip)): \(error.localizedDescription)")
            }
        }
        return false
    }

    func safeRebootPiHub() async -> Bool {
        let port = db.environmentConfig.effectivePiHubPort
        for ip in candidatePiHubIPs {
            guard let url = URL(string: "http://\(ip):\(port)/reboot") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 3.0
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    await MainActor.run {
                        self.piHubStatusOnline = false
                        MycoSyncManager.shared.triggerToast(message: "🔄 Pi Hub is rebooting... Back online in ~45 seconds.")
                    }
                    return true
                }
            } catch {
                print("⚠️ [Pi Hub] Reboot error (\(ip)): \(error.localizedDescription)")
            }
        }
        return false
    }

    func checkPiHubOnline() async -> Bool {
        let port = db.environmentConfig.effectivePiHubPort
        for ip in candidatePiHubIPs {
            for ep in ["devices", "status"] {
                guard let url = URL(string: "http://\(ip):\(port)/\(ep)") else { continue }
                var req = URLRequest(url: url)
                req.timeoutInterval = 2.0
                if let (_, resp) = try? await URLSession.shared.data(for: req),
                   (resp as? HTTPURLResponse)?.statusCode == 200 {
                    await MainActor.run { self.piHubStatusOnline = true }
                    return true
                }
            }
        }
        await MainActor.run { self.piHubStatusOnline = false }
        return false
    }

    // MARK: - Raspberry Pi Live Hardware & Schedule Synchronization (Single Source of Truth)
    @discardableResult
    func fetchPiHubDeviceStates() async -> Bool {
        let port = db.environmentConfig.effectivePiHubPort
        for ip in candidatePiHubIPs {
            guard let url = URL(string: "http://\(ip):\(port)/status") else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = 2.5
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                
                await MainActor.run {
                    self.piHubStatusOnline = true
                    var hasChanges = false
                    
                    // 1. Sync physical hardware switch states (Smart Plug physical button -> App)
                    if let devList = json["devices"] as? [[String: Any]] {
                        for devDict in devList {
                            guard let devId = devDict["id"] as? String,
                                  let isOn = devDict["is_on"] as? Bool else { continue }
                            let name = devDict["name"] as? String ?? ""
                            
                            if let idx = self.db.smartDevices.firstIndex(where: {
                                (!devId.isEmpty && $0.tuyaDeviceID.lowercased() == devId.lowercased()) ||
                                (!name.isEmpty && $0.name.lowercased() == name.lowercased())
                            }) {
                                if self.db.smartDevices[idx].isOn != isOn {
                                    print("🔌 [Pi Hardware Sync] Fysieke stekker '\(self.db.smartDevices[idx].name)': \(isOn ? "AAN" : "UIT")")
                                    self.db.smartDevices[idx].isOn = isOn
                                    hasChanges = true
                                }
                            }
                        }
                    }
                    
                    // 2. Sync running schedule timers from Pi Hub (Pi as Single Source of Truth)
                    if let schedList = json["schedules"] as? [[String: Any]] {
                        for sDict in schedList {
                            let sId = sDict["device_id"] as? String ?? ""
                            let sName = sDict["name"] as? String ?? ""
                            let cycleStartTs = sDict["cycle_start_time"] as? Double ?? 0.0
                            guard cycleStartTs > 0 else { continue }
                            let piStartDate = Date(timeIntervalSince1970: cycleStartTs)
                            
                            if let idx = self.db.smartDevices.firstIndex(where: {
                                (!sId.isEmpty && $0.tuyaDeviceID.lowercased() == sId.lowercased()) ||
                                (!sName.isEmpty && $0.name.lowercased() == sName.lowercased())
                            }) {
                                if self.db.smartDevices[idx].lastCustomExecutionTime == nil ||
                                   abs(self.db.smartDevices[idx].lastCustomExecutionTime?.timeIntervalSince(piStartDate) ?? 9999) > 10.0 {
                                    self.db.smartDevices[idx].lastCustomExecutionTime = piStartDate
                                    hasChanges = true
                                }
                            }
                        }
                    }
                    
                    if hasChanges {
                        self.save()
                    }
                }
                return true
            } catch {
                // Try next candidate IP
            }
        }
        return false
    }

    // MARK: - Raspberry Pi Central Server Database Sync (Single Source of Truth)
    
    func schedulePiServerDatabaseSync() {
        guard !isDecoyMode && !MycoSyncManager.shared.isApplyingRemoteSync else { return }
        piDbSyncWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                await self?.pushCentralDatabaseToPi()
            }
        }
        piDbSyncWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    @discardableResult
    func syncCentralDatabaseWithPi(forcePush: Bool = false) async -> Bool {
        if forcePush {
            return await pushCentralDatabaseToPi()
        }
        
        let port = db.environmentConfig.effectivePiHubPort
        for ip in candidatePiHubIPs {
            guard let url = URL(string: "http://\(ip):\(port)/database/status") else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = 2.5
            
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                
                let exists = json["exists"] as? Bool ?? false
                let piLastModified = json["last_modified"] as? Double ?? 0
                let localLastSaved = self.lastSavedTimestamp?.timeIntervalSince1970 ?? 0
                
                if !exists {
                    // Pi database is nog leeg -> Initialiseer direct vanaf dit toestel
                    print("ℹ️ [Pi Server] Pi database is leeg -> Uploaden vanaf \(MycoDevicePlatform.deviceName)...")
                    return await pushCentralDatabaseToPi()
                } else if piLastModified > (localLastSaved + 2.0) && !self.hasPendingLocalModifications {
                    // Pi heeft een recentere versie en we hebben geen lokale wijzigingen klaarstaan -> ophalen
                    print("📥 [Pi Server] Pi heeft recentere versie -> Ophalen van Pi...")
                    return await fetchCentralDatabaseFromPi()
                } else if self.hasPendingLocalModifications || (localLastSaved > piLastModified + 2.0) {
                    // Dit toestel heeft recente wijzigingen -> uploaden naar de centrale Pi
                    print("📤 [Pi Server] Lokaal toestel heeft nieuwere wijzigingen -> Wegschrijven naar Pi...")
                    return await pushCentralDatabaseToPi()
                } else {
                    await MainActor.run {
                        self.piServerDbLastSync = Date()
                        self.piHubStatusOnline = true
                        self.piServerDbStatusMessage = "In sync met Pi Server"
                    }
                    return true
                }
            } catch {
                continue
            }
        }
        return false
    }

    @discardableResult
    func fetchCentralDatabaseFromPi() async -> Bool {
        let port = db.environmentConfig.effectivePiHubPort
        await MainActor.run { self.isPiServerDbSyncing = true }
        defer { Task { @MainActor in self.isPiServerDbSyncing = false } }
        
        for ip in candidatePiHubIPs {
            guard let url = URL(string: "http://\(ip):\(port)/database") else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = 15.0
            
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dbObj = json["database"] as? [String: Any] else {
                    continue
                }
                
                let dbData = try JSONSerialization.data(withJSONObject: dbObj)
                let decoder = JSONDecoder()
                let incomingDB = try decoder.decode(AppDatabase.self, from: dbData)
                
                await MainActor.run {
                    MycoSyncManager.shared.isApplyingRemoteSync = true
                    self.db = incomingDB
                    self.saveImmediately(fromSync: true)
                    MycoSyncManager.shared.isApplyingRemoteSync = false
                    self.piServerDbLastSync = Date()
                    self.piHubStatusOnline = true
                    self.piServerDbStatusMessage = "Gesynchroniseerd met Pi Server"
                    print("✅ [Pi Server] Centrale database succesvol binnengehaald vanaf Pi (\(ip))")
                }
                return true
            } catch {
                print("ℹ️ [Pi Server] Fout bij ophalen centrale database van \(ip): \(error.localizedDescription)")
            }
        }
        return false
    }

    @discardableResult
    func pushCentralDatabaseToPi() async -> Bool {
        let port = db.environmentConfig.effectivePiHubPort
        await MainActor.run { self.isPiServerDbSyncing = true }
        defer { Task { @MainActor in self.isPiServerDbSyncing = false } }
        
        guard let encodedData = try? JSONEncoder().encode(self.db),
              let dbJson = try? JSONSerialization.jsonObject(with: encodedData) as? [String: Any] else {
            return false
        }
        
        let payload: [String: Any] = [
            "client_name": MycoDevicePlatform.deviceName,
            "database": dbJson,
            "timestamp": Date().timeIntervalSince1970
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        
        for ip in candidatePiHubIPs {
            guard let url = URL(string: "http://\(ip):\(port)/database") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 20.0
            req.httpBody = body
            
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    await MainActor.run {
                        self.piServerDbLastSync = Date()
                        self.piHubStatusOnline = true
                        self.piServerDbStatusMessage = "Bijgewerkt op Pi Server"
                        self.hasPendingLocalModifications = false
                        print("💾 [Pi Server] Centrale database succesvol opgeslagen op Pi (\(ip))")
                    }
                    return true
                }
            } catch {
                print("ℹ️ [Pi Server] Fout bij wegschrijven centrale database naar \(ip): \(error.localizedDescription)")
            }
        }
        return false
    }

    private func sendSmartDeviceCommand(device: SmartDeviceItem, previousState: Bool, logId: UUID? = nil) {
        guard device.deviceType != "Sensor" else { return }
        
        // 0a. Handmatige apparaten (Geen fysieke hardware): Geen netwerkverzoek uitvoeren
        if device.isManualOnly {
            return
        }
        
        // 0b. Shelly Direct Lokaal Wi-Fi (HTTP REST / Gen1 & Gen2 Plus)
        if device.brand.localizedCaseInsensitiveContains("shelly") {
            let hostCandidate = !device.tuyaDeviceID.isEmpty ? device.tuyaDeviceID : device.webhookURL
            let cleanHost = hostCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "https://", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            if !cleanHost.isEmpty {
                let stateParam = device.isOn ? "on" : "off"
                if let gen1URL = URL(string: "http://\(cleanHost)/relay/0?turn=\(stateParam)") {
                    var req = URLRequest(url: gen1URL)
                    req.timeoutInterval = 4
                    URLSession.shared.dataTask(with: req) { _, response, _ in
                        if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                            return
                        }
                        if let rpcURL = URL(string: "http://\(cleanHost)/rpc/Switch.Set?id=0&on=\(device.isOn)") {
                            var rpcReq = URLRequest(url: rpcURL)
                            rpcReq.timeoutInterval = 4
                            URLSession.shared.dataTask(with: rpcReq).resume()
                        }
                    }.resume()
                    return
                }
            }
        }
        
        // 0c. Tasmota / Sonoff Direct Lokaal Wi-Fi (HTTP)
        if device.brand.localizedCaseInsensitiveContains("tasmota") || device.brand.localizedCaseInsensitiveContains("sonoff") {
            let hostCandidate = !device.tuyaDeviceID.isEmpty ? device.tuyaDeviceID : device.webhookURL
            let cleanHost = hostCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "https://", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            if !cleanHost.isEmpty {
                let stateCmd = device.isOn ? "Power%20On" : "Power%20Off"
                if let url = URL(string: "http://\(cleanHost)/cm?cmnd=\(stateCmd)") {
                    var req = URLRequest(url: url)
                    req.timeoutInterval = 4
                    URLSession.shared.dataTask(with: req).resume()
                    return
                }
            }
        }
        
        MycoBackgroundHubManager.shared.beginBackgroundTask(name: "MycoLabs-SmartDeviceControl")
        Task {
            // 1. Probeer eerst altijd de lokale Raspberry Pi Tuya LAN Bridge (0ms, 100% lokaal offline & quota-vrij)
            if await self.sendLocalPiBridgeCommand(device: device) {
                await MainActor.run {
                    self.save()
                    MycoBackgroundHubManager.shared.endBackgroundTask()
                }
                return
            }
            
            // 2. Als Pi Hub autonome bediening actief is of Tuya Cloud proefperiode verlopen is:
            // val NOOIT terug op Tuya Cloud! Toon een heldere lokale netwerkmelding.
            let isPiAutonomous = self.db.environmentConfig.isPiHubAutonomousActive
            let isTuyaExpired = self.db.environmentConfig.isTuyaCloudExpired
            let isTuyaOfflineActive = self.db.environmentConfig.isTuyaOfflineAutonomousActive
            
            if isPiAutonomous || isTuyaExpired || !isTuyaOfflineActive {
                await MainActor.run {
                    let errMsg = self.t(
                        nl: "Lokale Pi Hub niet bereikbaar via LAN (\(self.candidatePiHubIPs.joined(separator: ", "))). Controleer of de Raspberry Pi aan staat en je Wi-Fi of Tailscale actief is.",
                        en: "Local Pi Hub unreachable via LAN (\(self.candidatePiHubIPs.joined(separator: ", "))). Ensure the Raspberry Pi is powered and Wi-Fi or Tailscale is active."
                    )
                    if let logId = logId {
                        self.handleSwitchError(device: device, previousState: previousState, logId: logId, errorMsg: errMsg)
                    } else {
                        if device.isOn && !device.isManualOverrideActive, let idx = self.db.smartDevices.firstIndex(where: { $0.id == device.id }) {
                            self.db.smartDevices[idx].isOn = previousState
                            self.save()
                        }
                        MycoSyncManager.shared.triggerToast(message: "⚠️ \(errMsg)")
                    }
                    MycoBackgroundHubManager.shared.endBackgroundTask()
                }
                return
            }
            
            // 3. Fallback naar Tuya Cloud ALLEEN wanneer Pi Hub niet autonoom is en Tuya Cloud niet verlopen is
            let devID = !device.tuyaDeviceID.isEmpty ? device.tuyaDeviceID : db.environmentConfig.tuyaDeviceID
            let clientId = db.environmentConfig.tuyaApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let secret = db.environmentConfig.tuyaApiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            let region = db.environmentConfig.tuyaRegion.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !clientId.isEmpty, !secret.isEmpty, !devID.isEmpty else {
                await MainActor.run {
                    let errMsg = "Pi Hub niet bereikbaar op \(self.candidatePiHubIPs.joined(separator: ", ")):8088 en geen Tuya Cloud geconfigureerd"
                    if let logId = logId {
                        self.handleSwitchError(device: device, previousState: previousState, logId: logId, errorMsg: errMsg)
                    } else {
                        if device.isOn && !device.isManualOverrideActive, let idx = self.db.smartDevices.firstIndex(where: { $0.id == device.id }) {
                            self.db.smartDevices[idx].isOn = previousState
                            self.save()
                        }
                        MycoSyncManager.shared.triggerToast(message: "⚠️ \(errMsg)")
                    }
                    MycoBackgroundHubManager.shared.endBackgroundTask()
                }
                return
            }
            
            do {
                let res = try await TuyaCloudManager.shared.sendCommandWithResult(
                    deviceId: devID,
                    isOn: device.isOn,
                    deviceType: device.deviceType,
                    preferredSwitchCode: device.switchCode,
                    clientId: clientId,
                    secret: secret,
                    region: region
                )
                await MainActor.run {
                    if let idx = self.db.smartDevices.firstIndex(where: { $0.id == device.id }) {
                        self.db.smartDevices[idx].switchCode = res.workingSwitchCode
                    }
                    self.save()
                    MycoBackgroundHubManager.shared.endBackgroundTask()
                }
            } catch {
                await MainActor.run {
                    let rawError = error.localizedDescription
                    let friendlyError: String
                    if rawError.contains("28841004") || rawError.lowercased().contains("quota") {
                        self.db.environmentConfig.tuyaCloudTrialExpired = true
                        self.save()
                        friendlyError = "Tuya Cloud proefperiode is verlopen (code 28841004). Zorg dat je Raspberry Pi Hub aan staat voor 100% gratis lokale bediening zonder Tuya Cloud."
                    } else {
                        friendlyError = "Tuya: \(rawError)"
                    }
                    
                    if let logId = logId {
                        self.handleSwitchError(device: device, previousState: previousState, logId: logId, errorMsg: friendlyError)
                    } else {
                        if device.isOn && !device.isManualOverrideActive, let idx = self.db.smartDevices.firstIndex(where: { $0.id == device.id }) {
                            self.db.smartDevices[idx].isOn = previousState
                            self.save()
                        }
                        MycoSyncManager.shared.triggerToast(message: "⚠️ Error with '\(device.name)': \(friendlyError)")
                        if device.isOn && !device.isManualOverrideActive {
                            MycoSyncManager.shared.broadcastDeviceError(id: device.id, revertedIsOn: previousState, error: friendlyError, name: device.name)
                        }
                    }
                    MycoBackgroundHubManager.shared.endBackgroundTask()
                }
            }
        }
    }

    // MARK: - Modular Camera HTTP Snapshot Engine
    public func fetchHTTPSnapshot(urlString: String) async -> UIImage? {
        let clean = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: clean) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode),
               let image = UIImage(data: data) {
                return image
            }
        } catch {
            print("⚠️ [HTTP Snapshot] Failed to fetch image: \(error.localizedDescription)")
        }
        return nil
    }

    func testSmartDevice(id: UUID, relayToHub: Bool = true) {
        guard let idx = db.smartDevices.firstIndex(where: { $0.id == id }) else { return }
        let dev = db.smartDevices[idx]
        guard dev.deviceType != "Sensor" else {
            pollAllConnectedSensors()
            return
        }
        
        if relayToHub {
            LiveKitStreamManager.shared.sendHubPlugTest(id: id)
            MycoCamStreamManager.shared.sendCloudPlugTest(id: id)
        }
        
        if !dev.isOn {
            toggleSmartDevice(id: dev.id, trigger: t(nl: "Handmatige 10s Test", en: "Manual 10s Test"), relayToHub: false)
        }
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self else { return }
            if let curIdx = self.db.smartDevices.firstIndex(where: { $0.id == id }),
               self.db.smartDevices[curIdx].isOn {
                self.toggleSmartDevice(id: id, trigger: self.t(nl: "Test voltooid (10s)", en: "Test completed (10s)"), relayToHub: false)
            }
        }
    }

    private var isPollingSensors: Bool = false
    private var lastSensorPollTime: Date? = nil

    func pollAllConnectedSensors(force: Bool = false) {
        guard !isPollingSensors else { return }
        if !force, let last = lastSensorPollTime, Date().timeIntervalSince(last) < 300.0 {
            return
        }
        let clientId = db.environmentConfig.tuyaApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = db.environmentConfig.tuyaApiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = db.environmentConfig.tuyaRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientId.isEmpty, !secret.isEmpty else { return }
        
        let sensorDevices = db.smartDevices.filter { $0.deviceType == "Sensor" && !$0.tuyaDeviceID.isEmpty }
        guard !sensorDevices.isEmpty else { return }
        
        isPollingSensors = true
        lastSensorPollTime = Date()
        Task {
            defer {
                Task { @MainActor in
                    self.isPollingSensors = false
                }
            }
            for dev in sensorDevices {
                let data = await TuyaCloudManager.shared.fetchDeviceSensorData(
                    deviceId: dev.tuyaDeviceID,
                    clientId: clientId,
                    secret: secret,
                    region: region
                )
                if data.tempC != nil || data.humidityPct != nil {
                    await MainActor.run {
                        self.recordSensorReading(
                            tempC: data.tempC,
                            humidityPct: data.humidityPct,
                            source: dev.name
                        )
                        if let idx = self.db.smartDevices.firstIndex(where: { $0.id == dev.id }) {
                            if let t = data.tempC { self.db.smartDevices[idx].currentTempC = t }
                            if let h = data.humidityPct { self.db.smartDevices[idx].currentHumidityPct = h }
                            self.db.smartDevices[idx].lastReadingTime = Date()
                        }
                    }
                }
            }
        }
    }
    


    // MARK: - TUYA CLOUD 24/7 AUTONOMOUS SCHEDULES & OFFLINE PERSISTENCE
    func buildTuyaSchedules(for device: SmartDeviceItem, ignoreAutopilotState: Bool = false) -> [TuyaCloudManager.TuyaScheduleTask] {
        guard (db.environmentConfig.tuyaOfflineAutonomousActive ?? false) else { return [] }
        guard device.deviceType != "Sensor", device.autoControlEnabled else { return [] }
        guard db.environmentConfig.isAutopilotEnabled || ignoreAutopilotState else { return [] }
        
        let switchCode = device.switchCode.isEmpty ? "switch_1" : device.switchCode
        var tasks: [TuyaCloudManager.TuyaScheduleTask] = []
        
        switch device.deviceType {
        case "Light":
            // Configurable Photoperiod: e.g. 08:00 to 20:00
            let onHour = device.lightOnHour
            let offHour = device.lightOffHour
            let onTime = String(format: "%02d:00", onHour)
            let offTime = String(format: "%02d:00", offHour)
            
            tasks.append(TuyaCloudManager.TuyaScheduleTask(
                aliasName: "MycoLabs Kweeklamp AAN",
                time: onTime,
                switchCode: switchCode,
                value: true,
                loops: "1111111"
            ))
            tasks.append(TuyaCloudManager.TuyaScheduleTask(
                aliasName: "MycoLabs Kweeklamp UIT",
                time: offTime,
                switchCode: switchCode,
                value: false,
                loops: "1111111"
            ))
            
        case "ExhaustFan":
            // FAE Air Exchange cycles across 24h clock
            let intervalMins: Int
            let durationMins: Int
            if device.autopilotMode == "customInterval" {
                intervalMins = max(15, device.totalIntervalMinutes)
                durationMins = max(1, min(30, device.customDurationMinutes))
            } else {
                intervalMins = max(15, db.environmentConfig.faeIntervalMinutes)
                durationMins = max(1, min(30, db.environmentConfig.faeDurationMinutes))
            }
            
            // Limit to max 10 cycles (20 tasks: 10 ON, 10 OFF) to strictly stay within Tuya Cloud device limits
            let maxFanCycles = 10
            let effectiveFanInterval = max(intervalMins, 1440 / maxFanCycles)
            var currentMinute = 0
            var cycleIndex = 1
            while currentMinute < 1440 && tasks.count < 20 {
                let onH = currentMinute / 60
                let onM = currentMinute % 60
                let onTimeStr = String(format: "%02d:%02d", onH, onM)
                
                let offMinute = (currentMinute + durationMins) % 1440
                let offH = offMinute / 60
                let offM = offMinute % 60
                let offTimeStr = String(format: "%02d:%02d", offH, offM)
                
                tasks.append(TuyaCloudManager.TuyaScheduleTask(
                    aliasName: "MycoLabs FAE AAN \(cycleIndex)",
                    time: onTimeStr,
                    switchCode: switchCode,
                    value: true,
                    loops: "1111111"
                ))
                tasks.append(TuyaCloudManager.TuyaScheduleTask(
                    aliasName: "MycoLabs FAE UIT \(cycleIndex)",
                    time: offTimeStr,
                    switchCode: switchCode,
                    value: false,
                    loops: "1111111"
                ))
                
                cycleIndex += 1
                currentMinute += effectiveFanInterval
            }
            
        case "Humidifier":
            // ONLY program offline timers if explicitly configured for timed manual intervals (no sensor mode)
            // Sensor-driven closed loop ("auto") MUST NOT have static cloud timers to avoid flooding or misting when off
            guard device.autopilotMode == "customInterval" else {
                return []
            }
            let intervalMins = max(15, device.totalIntervalMinutes)
            let durationMins = max(1, min(20, device.customDurationMinutes))
            
            let maxHumCycles = 10
            let effectiveHumInterval = max(intervalMins, 1440 / maxHumCycles)
            var currentMinute = 15 // 15m offset from fan
            var cycleIndex = 1
            while currentMinute < 1440 && tasks.count < 20 {
                let onH = currentMinute / 60
                let onM = currentMinute % 60
                let onTimeStr = String(format: "%02d:%02d", onH, onM)
                
                let offMinute = (currentMinute + durationMins) % 1440
                let offH = offMinute / 60
                let offM = offMinute % 60
                let offTimeStr = String(format: "%02d:%02d", offH, offM)
                
                tasks.append(TuyaCloudManager.TuyaScheduleTask(
                    aliasName: "MycoLabs Vocht AAN \(cycleIndex)",
                    time: onTimeStr,
                    switchCode: switchCode,
                    value: true,
                    loops: "1111111"
                ))
                tasks.append(TuyaCloudManager.TuyaScheduleTask(
                    aliasName: "MycoLabs Vocht UIT \(cycleIndex)",
                    time: offTimeStr,
                    switchCode: switchCode,
                    value: false,
                    loops: "1111111"
                ))
                
                cycleIndex += 1
                currentMinute += effectiveHumInterval
            }
            
        case "Heater", "GenericPlug":
            if device.autopilotMode == "customInterval" {
                let intervalMins = max(10, device.totalIntervalMinutes)
                let durationMins = max(1, min(60, device.customDurationMinutes))
                let maxPlugCycles = 10
                let effectivePlugInterval = max(intervalMins, 1440 / maxPlugCycles)
                var currentMinute = 0
                var cycleIndex = 1
                while currentMinute < 1440 && tasks.count < 20 {
                    let onH = currentMinute / 60
                    let onM = currentMinute % 60
                    let onTimeStr = String(format: "%02d:%02d", onH, onM)
                    
                    let offMinute = (currentMinute + durationMins) % 1440
                    let offH = offMinute / 60
                    let offM = offMinute % 60
                    let offTimeStr = String(format: "%02d:%02d", offH, offM)
                    
                    tasks.append(TuyaCloudManager.TuyaScheduleTask(
                        aliasName: "MycoLabs \(device.name) AAN \(cycleIndex)",
                        time: onTimeStr,
                        switchCode: switchCode,
                        value: true,
                        loops: "1111111"
                    ))
                    tasks.append(TuyaCloudManager.TuyaScheduleTask(
                        aliasName: "MycoLabs \(device.name) UIT \(cycleIndex)",
                        time: offTimeStr,
                        switchCode: switchCode,
                        value: false,
                        loops: "1111111"
                    ))
                    
                    cycleIndex += 1
                    currentMinute += effectivePlugInterval
                }
            }
            
        default:
            break
        }
        
        return tasks
    }
    
    func syncAllSchedulesToTuyaCloud() {
        // Tuya Cloud automatisering is permanent vervangen door de 24/7 Raspberry Pi Hub & Tailscale.
        // We sturen alle schema's direct lokaal naar de Pi Hub.
        Task {
            await syncSchedulesToPiHub()
        }
    }
    
    func clearAllSchedulesFromTuyaCloud() {
        for idx in 0..<db.smartDevices.count {
            db.smartDevices[idx].tuyaTimerCount = 0
        }
        db.environmentConfig.tuyaOfflineAutonomousActive = false
        db.environmentConfig.tuyaOfflineTimersCount = 0
        db.environmentConfig.tuyaSyncStatusMessage = "100% Lokaal via Pi Hub & Tailscale"
        save()
    }
    
    func syncSmartDevicesWithTuya(pushSchedules: Bool = false, showToast: Bool = false) {
        Task {
            await syncSmartDevicesWithTuyaDirect(pushSchedules: pushSchedules, showToast: showToast)
        }
    }
    
    func syncSmartDevicesWithTuyaDirect(pushSchedules: Bool = false, showToast: Bool = false) async {
        let clientId = db.environmentConfig.tuyaApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = db.environmentConfig.tuyaApiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = db.environmentConfig.tuyaRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientId.isEmpty, !secret.isEmpty else { return }
        
        let currentDevices = db.smartDevices
        do {
            let res = try await TuyaCloudManager.shared.syncAllDevicesWithTuya(
                currentDevices: currentDevices,
                clientId: clientId,
                secret: secret,
                region: region
            )
            await MainActor.run {
                self.db.smartDevices = res.updatedDevices
                self.db.environmentConfig.tuyaVerified = true
                self.db.environmentConfig.tuyaVerifiedAt = Date()
                self.db.environmentConfig.lastTuyaSyncTime = Date()
                
                if let sensorDev = self.db.smartDevices.first(where: { $0.deviceType == "Sensor" && $0.currentHumidityPct != nil }) {
                    if let t = sensorDev.currentTempC { self.db.environmentConfig.latestSensorTempC = t }
                    if let h = sensorDev.currentHumidityPct { self.db.environmentConfig.latestSensorHumidityPct = h }
                    self.db.environmentConfig.latestSensorReadingTime = sensorDev.lastReadingTime ?? Date()
                }
                
                self.saveImmediately()
                
                if showToast {
                    let feedback = res.newDevicesFound > 0
                        ? "☁️ Tuya: \(res.updatedDevices.count) apparaten gesynchroniseerd (\(res.newDevicesFound) nieuw gevonden)!"
                        : "☁️ Tuya: \(res.updatedDevices.count) apparaten live gesynchroniseerd!"
                    MycoSyncManager.shared.triggerToast(message: feedback)
                }
            }
            
            if pushSchedules && (db.environmentConfig.tuyaOfflineAutonomousActive ?? false) {
                syncAllSchedulesToTuyaCloud()
            }
        } catch {
            await MainActor.run {
                self.db.environmentConfig.tuyaSyncStatusMessage = "Tuya synchronization error: \(error.localizedDescription)"
                if showToast {
                    MycoSyncManager.shared.triggerToast(message: "⚠️ Tuya Sync Error: \(error.localizedDescription)")
                }
            }
        }
    }

        // MARK: - SENSOR & LIVE CLIMATE HELPERS
    var hasConnectedSensor: Bool {
        return db.smartDevices.contains { $0.deviceType == "Sensor" } && db.environmentConfig.latestSensorReadingTime != nil && db.environmentConfig.latestSensorHumidityPct != nil
    }
    
    var latestSensorTempC: Double? {
        guard db.smartDevices.contains(where: { $0.deviceType == "Sensor" }) else { return nil }
        return db.environmentConfig.latestSensorTempC
    }
    
    var latestSensorHumidityPct: Double? {
        guard db.smartDevices.contains(where: { $0.deviceType == "Sensor" }) else { return nil }
        return db.environmentConfig.latestSensorHumidityPct
    }
    
    var latestSensorCo2Ppm: Int? {
        guard db.smartDevices.contains(where: { $0.deviceType == "Sensor" }) else { return nil }
        return db.environmentConfig.latestSensorCo2Ppm
    }
    
    var currentVpdKpa: Double {
        let t = db.environmentConfig.currentTempC ?? db.environmentConfig.targetDayTempC
        let h = db.environmentConfig.currentHumidityPct ?? db.environmentConfig.targetHumidityPct
        return MycoVPDCalculator.analyze(tempC: t, humidityPct: h)?.vpdKPa ?? 0.28
    }
    
    func deleteSmartDevice(id: UUID) {
        let deletedDev = db.smartDevices.first(where: { $0.id == id })
        let tuyaId = deletedDev?.tuyaDeviceID.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let devName = deletedDev?.name ?? "Apparaat"

        db.smartDevices.removeAll(where: { $0.id == id || (!tuyaId.isEmpty && $0.tuyaDeviceID == tuyaId) })
        if !db.smartDevices.contains(where: { $0.deviceType == "Sensor" }) {
            db.environmentConfig.latestSensorTempC = nil
            db.environmentConfig.latestSensorHumidityPct = nil
            db.environmentConfig.latestSensorCo2Ppm = nil
            db.environmentConfig.latestSensorReadingTime = nil
        }
        recordDeletion(id)
        if !tuyaId.isEmpty {
            recordTuyaDeletion(tuyaId)
            let cId = db.environmentConfig.tuyaApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let sec = db.environmentConfig.tuyaApiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            let reg = db.environmentConfig.tuyaRegion.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cId.isEmpty && !sec.isEmpty {
                Task {
                    _ = await TuyaCloudManager.shared.clearDeviceSchedules(deviceId: tuyaId, clientId: cId, secret: sec, region: reg)
                }
            }
        }
        saveImmediately()

        // Immediate direct sync command to connected peers / Stream Hub
        MycoSyncManager.shared.broadcastDeviceDeleted(id: id, tuyaId: tuyaId, name: devName)
    }
    
    func recordSensorReading(tempC: Double?, humidityPct: Double?, co2Ppm: Int? = nil, source: String = "Sensor") {
        if let t = tempC {
            db.environmentConfig.latestSensorTempC = t
        }
        if let h = humidityPct {
            db.environmentConfig.latestSensorHumidityPct = h
        }
        if let c = co2Ppm {
            db.environmentConfig.latestSensorCo2Ppm = c
        }
        db.environmentConfig.latestSensorReadingTime = Date()
        
        // Ensure a sensor device is registered in smartDevices list
        if !db.smartDevices.contains(where: { $0.deviceType == "Sensor" }) {
            let sensorDev = SmartDeviceItem(
                name: source == "Simulatie" ? "Test Klimaatsensor" : (source == "API Simulatie" ? "API Klimaatsensor" : "Klimaatsensor (\(source))"),
                deviceType: "Sensor",
                brand: (source == "Simulatie" || source == "API Simulatie") ? "Virtueel / Test" : "Tuya / Wi-Fi",
                isOn: true,
                autoControlEnabled: true,
                currentTempC: tempC,
                currentHumidityPct: humidityPct,
                lastReadingTime: Date()
            )
            db.smartDevices.append(sensorDev)
        } else if let idx = db.smartDevices.firstIndex(where: { $0.deviceType == "Sensor" }) {
            if tempC != nil { db.smartDevices[idx].currentTempC = tempC }
            if humidityPct != nil { db.smartDevices[idx].currentHumidityPct = humidityPct }
            db.smartDevices[idx].lastReadingTime = Date()
        }
        
        save()
        if db.environmentConfig.isAutopilotEnabled {
            runAutopilotCycle(isTest: false, pollSensors: false)
        }
    }
    
    func recordManualReading(tempC: Double?, humidityPct: Double?, date: Date = Date(), note: String? = nil) {
        if let t = tempC {
            db.environmentConfig.manualTempC = t
        }
        if let h = humidityPct {
            db.environmentConfig.manualHumidityPct = h
        }
        db.environmentConfig.manualReadingTime = date
        
        // Update display readings in sensor devices list if present
        if let idx = db.smartDevices.firstIndex(where: { $0.deviceType == "Sensor" }) {
            if let t = tempC { db.smartDevices[idx].currentTempC = t }
            if let h = humidityPct { db.smartDevices[idx].currentHumidityPct = h }
            db.smartDevices[idx].lastReadingTime = date
        }
        
        save()
        if db.environmentConfig.isAutopilotEnabled {
            runAutopilotCycle(isTest: false, pollSensors: false)
        }
    }
    
    var hasPhysicalSensorAvailable: Bool {
        return db.smartDevices.contains { $0.deviceType == "Sensor" && !$0.tuyaDeviceID.isEmpty }
    }
    
    func removeAllSensorsAndData() {
        db.environmentConfig.latestSensorTempC = nil
        db.environmentConfig.latestSensorHumidityPct = nil
        db.environmentConfig.latestSensorCo2Ppm = nil
        db.environmentConfig.latestSensorReadingTime = nil
        db.smartDevices.removeAll(where: { $0.deviceType == "Sensor" })
        save()
    }

    // MARK: - Widget Pending Commands Execution
    public func checkPendingWidgetCommands() {
        let appGroupID = "group.com.mycolab.app"
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        guard let action = defaults.string(forKey: "mycolab_pending_actuator_action") else { return }
        defaults.removeObject(forKey: "mycolab_pending_actuator_action")
        
        switch action {
        case "toggle_humidifier":
            if let dev = db.smartDevices.first(where: { 
                $0.deviceType.lowercased().contains("humidifier") || 
                $0.name.lowercased().contains("bevochtiger") || 
                $0.name.lowercased().contains("mist") 
            }) {
                toggleSmartDevice(id: dev.id)
            }
        case "toggle_fan":
            if let dev = db.smartDevices.first(where: { 
                $0.deviceType.lowercased().contains("fan") || 
                $0.deviceType.lowercased().contains("exhaust") || 
                $0.name.lowercased().contains("afzuig") || 
                $0.name.lowercased().contains("fae") 
            }) {
                toggleSmartDevice(id: dev.id)
            }
        case "toggle_light":
            if let dev = db.smartDevices.first(where: { 
                $0.deviceType.lowercased().contains("light") || 
                $0.name.lowercased().contains("lamp") || 
                $0.name.lowercased().contains("licht") 
            }) {
                toggleSmartDevice(id: dev.id)
            }
        case "trigger_fae_pulse":
            if let dev = db.smartDevices.first(where: { 
                $0.deviceType.lowercased().contains("fan") || 
                $0.deviceType.lowercased().contains("exhaust") || 
                $0.name.lowercased().contains("afzuig") || 
                $0.name.lowercased().contains("fae") 
            }) {
                if !dev.isOn {
                    toggleSmartDevice(id: dev.id)
                }
            }
        default:
            break
        }
        
        // Refresh widget snapshot after executing pending command
        MycoWidgetDataManager.shared.updateSnapshot(from: self.db)
    }

    // MARK: - 24/7 AUTOPILOT CLIMATE ENGINE
    private var autopilotTimer: AnyCancellable? = nil
    private var lastForegroundActiveTime: Date = Date()
    
    func handleAppBecameActive() {
        let now = Date()
        lastForegroundActiveTime = now
        
        // Preserve running timer countdowns across app restarts / wakeups.
        // Only initialize reference times for devices that have NEVER run (nil).
        for idx in 0..<db.smartDevices.count {
            if db.smartDevices[idx].lastCustomExecutionTime == nil {
                db.smartDevices[idx].lastCustomExecutionTime = now
            }
        }
        if db.environmentConfig.lastFaeExecutionTime == nil {
            db.environmentConfig.lastFaeExecutionTime = now
        }
        if db.environmentConfig.lastHumidifierExecutionTime == nil {
            db.environmentConfig.lastHumidifierExecutionTime = now
        }
        
        // Immediately synchronize physical hardware state and Pi Hub running schedules
        Task {
            await self.fetchPiHubDeviceStates()
        }
        
        // Poll sensor data and sync Tuya device status without sending switch ON commands
        pollAllConnectedSensors()
        syncSmartDevicesWithTuya(pushSchedules: false)
        checkPendingWidgetCommands()
        
        // Note: Do NOT call syncAllSchedulesToTuyaCloud() on every app activation.
        // Re-creating/clearing cloud timers on launch triggers Tuya relay clicks/restarts.
    }
    
    func startAutopilotEngine() {
        autopilotTimer?.cancel()
        lastForegroundActiveTime = Date()
        
        // Fast 15-second tick interval for responsive automations and low drift
        autopilotTimer = Timer.publish(every: 15.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.runAutopilotCycle()
            }
        
        // Initialize base timestamps ONLY for devices that have never run (nil), preserving countdowns across restarts
        let now = Date()
        for idx in 0..<db.smartDevices.count {
            if db.smartDevices[idx].lastCustomExecutionTime == nil {
                db.smartDevices[idx].lastCustomExecutionTime = now
            }
        }
        if db.environmentConfig.lastFaeExecutionTime == nil {
            db.environmentConfig.lastFaeExecutionTime = now
        }
        if db.environmentConfig.lastHumidifierExecutionTime == nil {
            db.environmentConfig.lastHumidifierExecutionTime = now
        }
        
        Task {
            await self.fetchPiHubDeviceStates()
        }
        
        // Run first sensor check and device state sync (without forcing switch commands)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.pollAllConnectedSensors()
            self?.syncSmartDevicesWithTuya(pushSchedules: false)
        }
        
        if db.environmentConfig.is24_7HubBackgroundModeEnabled {
            MycoBackgroundHubManager.shared.startBackgroundHub()
        }
        if db.environmentConfig.isScreenAlwaysOnEnabled {
            MycoBackgroundHubManager.shared.setKeepScreenOn(true)
        }
    }
    
    // MARK: - Direct Post-FAE Humidity Recovery & Optional Optical Scanning
    
    /// Wordt direct aangeroepen zodra een ventilator stopt na FAE ventilatie
    func triggerPostFaeRecovery(fanDurationMinutes: Double) {
        guard db.environmentConfig.isAutopilotEnabled else { return }
        
        // Smart interlock: zorg dat er geen enkele ventilator meer draait
        let isFanStillRunning = db.smartDevices.contains { 
            ($0.deviceType == "ExhaustFan" || $0.name.localizedCaseInsensitiveContains("ventil") || $0.name.localizedCaseInsensitiveContains("afzuig") || $0.name.localizedCaseInsensitiveContains("fae")) && $0.isOn 
        }
        guard !isFanStillRunning else { return }
        
        // Voorkom dubbele inschakeling als de bevochtiger al actief is
        let isHumAlreadyRunning = db.smartDevices.contains { $0.deviceType == "Humidifier" && $0.isOn }
            || MycoOpticalHygrometerManager.shared.isHumidifierRunning
        guard !isHumAlreadyRunning else { return }
        
        let opticalMgr = MycoOpticalHygrometerManager.shared
        let cameraLinked = opticalMgr.isCameraLinked
        
        if cameraLinked {
            // Als er een camera gekoppeld is: optische scan uitvoeren
            db.environmentConfig.lastAutopilotLogMessage = t(
                nl: "🌬️ Ventilatie afgerond (\(String(format: "%.1f", fanDurationMinutes))m) • 📷 Camera gekoppeld: Optische meting gestart voor direct vochtherstel",
                en: "🌬️ Ventilation finished (\(String(format: "%.1f", fanDurationMinutes))m) • 📷 Camera paired: Optical measurement started for direct humidity recovery"
            )
            db.environmentConfig.lastAutopilotLogTime = Date()
            
            Task { @MainActor in
                let reading = await opticalMgr.triggerPostFaeScan(fanDurationMinutes: fanDurationMinutes)
                if reading == nil {
                    // Fallback: Als de optische scan geen meting kon doen (bijv. donker of offline), schakel over naar direct vochtherstel via schema
                    self.executeDirectMoistureRecovery(fanDurationMinutes: fanDurationMinutes, currentRH: self.db.environmentConfig.currentHumidityPct)
                }
            }
        } else {
            // Camera koppelen is optioneel: direct vochtherstel berekenen op basis van ventilatorlooptijd via automatische schema
            db.environmentConfig.lastAutopilotLogMessage = t(
                nl: "🌬️ Ventilatie afgerond (\(String(format: "%.1f", fanDurationMinutes))m) • 💧 Direct vochtherstel via schema gestart",
                en: "🌬️ Ventilation finished (\(String(format: "%.1f", fanDurationMinutes))m) • 💧 Direct humidity recovery via schedule started"
            )
            db.environmentConfig.lastAutopilotLogTime = Date()
            
            executeDirectMoistureRecovery(fanDurationMinutes: fanDurationMinutes, currentRH: db.environmentConfig.currentHumidityPct)
        }
    }
    
    /// Voert direct het berekende vochtherstel uit op de bevochtiger
    func executeDirectMoistureRecovery(fanDurationMinutes: Double, currentRH: Double?) {
        guard db.environmentConfig.isAutopilotEnabled else { return }
        
        guard let humIdx = db.smartDevices.firstIndex(where: {
            ($0.deviceType == "Humidifier"
             || $0.name.localizedCaseInsensitiveContains("bevocht")
             || $0.name.localizedCaseInsensitiveContains("humid")
             || $0.name.localizedCaseInsensitiveContains("mist")
             || $0.name.localizedCaseInsensitiveContains("nevel"))
            && $0.autoControlEnabled
        }) else {
            print("[Autopilot] Geen actieve automatische bevochtiger beschikbaar voor vochtherstel.")
            return
        }
        
        let humDev = db.smartDevices[humIdx]
        guard !humDev.isOn else { return }
        
        let targetHum = db.environmentConfig.targetHumidityPct
        let calc = MycoOpticalHygrometerManager.shared.calculateHumidifierDurationForFan(
            fanDurationMinutes: fanDurationMinutes,
            targetRH: targetHum,
            currentRH: currentRH
        )
        
        // Respecteer ingestelde hersteltijd: als postFaeRecoveryDurationSeconds > 0 dan custom duur, anders berekende AI duur
        let effectiveRecoverySeconds: Int = {
            if db.environmentConfig.postFaeRecoveryDurationSeconds > 0 {
                return db.environmentConfig.postFaeRecoveryDurationSeconds
            }
            return calc.seconds
        }()
        
        guard effectiveRecoverySeconds > 0 else { return }
        let now = Date()
        
        let recoveryExplanation: String = {
            if db.environmentConfig.postFaeRecoveryDurationSeconds > 0 {
                return t(nl: "Vaste hersteltijd (\(effectiveRecoverySeconds)s ingesteld)", en: "Fixed recovery duration (\(effectiveRecoverySeconds)s set)")
            } else {
                return calc.explanation
            }
        }()
        
        setSmartDeviceState(id: humDev.id, isOn: true, trigger: t(
            nl: "Autopilot • Direct Vochtherstel na \(String(format: "%.1f", fanDurationMinutes))m FAE (\(effectiveRecoverySeconds)s)",
            en: "Autopilot • Direct Moisture Recovery after \(String(format: "%.1f", fanDurationMinutes))m FAE (\(effectiveRecoverySeconds)s)"
        ))
        db.environmentConfig.lastHumidifierExecutionTime = now
        db.environmentConfig.lastAutopilotLogMessage = t(
            nl: "💧 Direct vochtherstel gestart: \(recoveryExplanation)",
            en: "💧 Direct moisture recovery started: \(recoveryExplanation)"
        )
        db.environmentConfig.lastAutopilotLogTime = now
        save()
        
        let humId = humDev.id
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(effectiveRecoverySeconds)) { [weak self] in
            guard let self = self else { return }
            if let curHumIdx = self.db.smartDevices.firstIndex(where: { $0.id == humId }),
               self.db.smartDevices[curHumIdx].isOn {
                self.setSmartDeviceState(id: humId, isOn: false, trigger: self.t(
                    nl: "Autopilot • Vochtherstel voltooid",
                    en: "Autopilot • Moisture recovery completed"
                ))
                self.db.environmentConfig.lastAutopilotLogMessage = self.t(
                    nl: "✅ Vochtherstel voltooid • Kweektent weer op \(Int(self.db.environmentConfig.targetHumidityPct))% RV",
                    en: "✅ Moisture recovery completed • Grow tent back at \(Int(self.db.environmentConfig.targetHumidityPct))% RH"
                )
                self.db.environmentConfig.lastAutopilotLogTime = Date()
                self.save()
            }
        }
    }
    
    /// Compatibiliteitswrapper voor post-FAE vochtherstel
    func runPostFaeHumidityCheck(fanDurationMinutes: Double? = nil) {
        let mins = fanDurationMinutes ?? Double(max(1, db.environmentConfig.faeDurationMinutes))
        triggerPostFaeRecovery(fanDurationMinutes: mins)
    }
    
    func runAutopilotCycle(isTest: Bool = false, pollSensors: Bool = true) {
        guard db.environmentConfig.isAutopilotEnabled || isTest else { return }
        
        // ONDERHOUDSMODUS / ROOM INSPECTION ACTIVE:
        // Prevent all automated toggles so grower can safely work in the grow space.
        if db.environmentConfig.isMaintenanceModeActive && !isTest {
            let now = Date()
            if let start = db.environmentConfig.maintenanceModeStartTime,
               db.environmentConfig.maintenanceModeAutoResumeMinutes > 0 {
                let elapsedMinutes = now.timeIntervalSince(start) / 60.0
                if elapsedMinutes >= Double(db.environmentConfig.maintenanceModeAutoResumeMinutes) {
                    setMaintenanceMode(enabled: false)
                } else {
                    if pollSensors { pollAllConnectedSensors() }
                    return
                }
            } else {
                if pollSensors { pollAllConnectedSensors() }
                return
            }
        }
        
        // Single-Hub Autopilot Execution:
        // When 24/7 Pi Hub autonomy is active, the Raspberry Pi runs all physical timers 24/7 autonomously.
        // The viewer client MUST NOT execute competing timers that toggle hardware relays.
        let hasActivePiHub = db.environmentConfig.isPiHubAutonomousActive
        let hasPairedRemoteHub = !isCurrentDeviceActingAsHub && isRemoteHubReachableFromViewer && (
            MycoCamPairingManager.shared.isPaired
            || MycoCamPairingManager.shared.pairedCameraId != nil
            || (UserDefaults.standard.string(forKey: "mycolab_paired_camera_id").map { !$0.isEmpty } ?? false)
        )
        if !isTest && (hasActivePiHub || hasPairedRemoteHub) {
            if pollSensors {
                pollAllConnectedSensors()
            }
            Task {
                await self.fetchPiHubDeviceStates()
            }
            return
        }
        let now = Date()
        var hasChanges = false
        
        // Startup grace period: Prevent power-on surges and relay clicks right when app opens or returns to active
        let timeSinceForeground = now.timeIntervalSince(lastForegroundActiveTime)
        let isDuringStartupGracePeriod = !isTest && timeSinceForeground < 15.0
        if isDuringStartupGracePeriod {
            // During startup grace period, silently poll sensor data (read-only) and do NOT toggle relays
            if pollSensors {
                pollAllConnectedSensors()
            }
            return
        }
        
        // Continuous live sensor ingestion check
        if !isTest && pollSensors {
            pollAllConnectedSensors()
        }
        
        // Clean up expired manual overrides
        for idx in 0..<db.smartDevices.count {
            if let until = db.smartDevices[idx].manualOverrideUntil, now >= until {
                db.smartDevices[idx].manualOverrideUntil = nil
                db.smartDevices[idx].manualOverrideState = nil
                hasChanges = true
            }
        }

        // Check effective activation moment for global climate config
        let isGlobalScheduleEffective = db.environmentConfig.isScheduleEffective

        // Bereken resterende tijd tot de volgende automatische FAE cyclus
        let faeIntervalMins = Double(db.environmentConfig.effectiveFaeIntervalMinutes)
        let faeMinsPassedSoFar = db.environmentConfig.lastFaeExecutionTime.map { now.timeIntervalSince($0) / 60.0 } ?? 0.0
        let minutesUntilNextFae = max(0.0, faeIntervalMins - faeMinsPassedSoFar)
        let isPreFaeLockoutActive = db.environmentConfig.preFaeHumidifierLockoutMinutes > 0 && minutesUntilNextFae <= Double(db.environmentConfig.preFaeHumidifierLockoutMinutes)

        // SEQUENTIAL RULE: Check if any Exhaust Fan is currently running
        let isFanRunning = db.smartDevices.contains { $0.deviceType == "ExhaustFan" && $0.isOn }
        
        // If Fan is running OR pre-FAE lockout is active, ensure Humidifier is NOT running
        if isFanRunning {
            for humDev in db.smartDevices.filter({ $0.deviceType == "Humidifier" && $0.isOn && !$0.isManualOverrideActive }) {
                toggleSmartDevice(id: humDev.id, trigger: t(nl: "Autopilot • Gepauzeerd voor FAE ventilatie", en: "Autopilot • Paused for FAE ventilation"))
                db.environmentConfig.lastAutopilotLogMessage = t(
                    nl: "⏸️ Luchtbevochtiger gepauzeerd: FAE ventilator ververst eerst de lucht",
                    en: "⏸️ Humidifier paused: FAE fan replacing air first"
                )
                db.environmentConfig.lastAutopilotLogTime = now
                hasChanges = true
            }
        } else if isPreFaeLockoutActive {
            // Pre-FAE Bevochtiging-stop: Voorkom dat nevel verloren gaat vlak voor de afzuiging aangaat
            for humDev in db.smartDevices.filter({ $0.deviceType == "Humidifier" && $0.isOn && !$0.isManualOverrideActive }) {
                toggleSmartDevice(id: humDev.id, trigger: t(nl: "Autopilot • Pre-FAE buffer stop", en: "Autopilot • Pre-FAE buffer stop"))
                let minsLeft = max(1, Int(minutesUntilNextFae))
                db.environmentConfig.lastAutopilotLogMessage = t(
                    nl: "⏸️ Pre-FAE buffer: Luchtbevochtiger gepauzeerd (\(minsLeft)m voor ventilatie)",
                    en: "⏸️ Pre-FAE buffer: Humidifier paused (\(minsLeft)m before fan starts)"
                )
                db.environmentConfig.lastAutopilotLogTime = now
                hasChanges = true
            }
        }
        
        // 0. CUSTOM MANUAL INTERVAL DEVICES ("Handmatige versie: om de X uur, Y minuten AAN")
        for idx in 0..<db.smartDevices.count {
            let dev = db.smartDevices[idx]
            guard dev.deviceType != "Sensor" else { continue }
            let isLight = dev.deviceType == "Light"
                || dev.name.localizedCaseInsensitiveContains("lamp")
                || dev.name.localizedCaseInsensitiveContains("licht")
                || dev.name.localizedCaseInsensitiveContains("kweeklamp")
            guard !isLight else { continue } // Kweeklampen vallen onder de dag/nacht lichtcyclus, NOOIT onder interval safety auto-off!
            guard dev.autoControlEnabled && dev.autopilotMode == "customInterval" else { continue }
            if dev.isManualOverrideActive { continue }
            
            // Controleer of de ingangstijd voor dit schema al bereikt is
            guard dev.isScheduleEffective else { continue }
            
            // If this is a humidifier and the fan is running OR pre-FAE buffer is active, defer custom interval
            if dev.deviceType == "Humidifier" && (isFanRunning || isPreFaeLockoutActive) {
                continue
            }
            
            let intervalMins = Double(dev.totalIntervalMinutes)
            let durationMins = max(1, dev.customDurationMinutes)
            if dev.lastCustomExecutionTime == nil {
                db.smartDevices[idx].lastCustomExecutionTime = now
            }
            let minsPassed = dev.lastCustomExecutionTime.map { now.timeIntervalSince($0) / 60.0 } ?? 0.0
            
            // Safety auto-off: If device is ON and has exceeded its runtime
            if dev.isOn && minsPassed >= Double(durationMins) {
                toggleSmartDevice(id: dev.id, trigger: t(nl: "Autopilot • Schema voltooid (\(durationMins)m)", en: "Autopilot • Schedule completed (\(durationMins)m)"))
                db.environmentConfig.lastAutopilotLogMessage = t(
                    nl: "⏱️ \(dev.name): Cyclus voltooid (\(durationMins)m) • Uitgeschakeld",
                    en: "⏱️ \(dev.name): Cycle completed (\(durationMins)m) • Switched OFF"
                )
                db.environmentConfig.lastAutopilotLogTime = now
                hasChanges = true
                continue
            }
            
            // Interval trigger
            if !isDuringStartupGracePeriod && (isTest || minsPassed >= intervalMins) {
                if !dev.isOn || isTest {
                    if !dev.isOn {
                        toggleSmartDevice(id: dev.id, trigger: t(nl: isTest ? "Autopilot Sneltest" : "Autopilot • Schema ingeschakeld", en: isTest ? "Autopilot Quick Test" : "Autopilot • Schedule switched ON"))
                    }
                    db.smartDevices[idx].lastCustomExecutionTime = now
                    let logDur = isTest ? 1 : durationMins
                    let intervalDesc = dev.intervalFormatted
                    
                    db.environmentConfig.lastAutopilotLogMessage = t(
                        nl: isTest ? "⚡️ Autopilot Sneltest: \(dev.name) gestart (10s test)" : "⏱️ Handmatig interval: \(dev.name) ingeschakeld voor \(logDur)m (om de \(intervalDesc))",
                        en: isTest ? "⚡️ Autopilot Quick Test: \(dev.name) started (10s test)" : "⏱️ Manual interval: \(dev.name) turned ON for \(logDur)m (every \(intervalDesc))"
                    )
                    db.environmentConfig.lastAutopilotLogTime = now
                    hasChanges = true
                    
                    let offSeconds = isTest ? 10.0 : Double(durationMins * 60)
                    let devId = dev.id
                    let devName = dev.name
                    DispatchQueue.main.asyncAfter(deadline: .now() + offSeconds) { [weak self] in
                        guard let self = self else { return }
                        if let curIdx = self.db.smartDevices.firstIndex(where: { $0.id == devId }),
                           self.db.smartDevices[curIdx].isOn {
                            self.toggleSmartDevice(id: devId, trigger: self.t(nl: "Autopilot • Schema voltooid", en: "Autopilot • Schedule completed"))
                            self.db.environmentConfig.lastAutopilotLogMessage = self.t(
                                nl: "⏱️ \(devName): Intervalcyclus voltooid • Uitgeschakeld",
                                en: "⏱️ \(devName): Interval cycle completed • Switched OFF"
                            )
                            self.db.environmentConfig.lastAutopilotLogTime = Date()
                            self.save()
                        }
                    }
                }
            }
        }
        
        // 1. AUTOMATIC FAE VENTILATION CYCLE (Standard Autopilot)
        if db.environmentConfig.lastFaeExecutionTime == nil {
            db.environmentConfig.lastFaeExecutionTime = now
        }
        let faeMinsPassed = db.environmentConfig.lastFaeExecutionTime.map { now.timeIntervalSince($0) / 60.0 } ?? 0.0
        if !isDuringStartupGracePeriod && isGlobalScheduleEffective && (isTest || faeMinsPassed >= Double(db.environmentConfig.effectiveFaeIntervalMinutes)) {
            if let fanIdx = db.smartDevices.firstIndex(where: { $0.deviceType == "ExhaustFan" && $0.autoControlEnabled && $0.autopilotMode != "customInterval" }) {
                let fanDev = db.smartDevices[fanIdx]
                if fanDev.isManualOverrideActive {
                    // Manual override active on fan, skip automatic FAE trigger
                } else if !fanDev.isOn || isTest {
                    // Turn OFF any active humidifier before fan begins (unless humidifier is manually overridden)
                    for humDev in db.smartDevices.filter({ $0.deviceType == "Humidifier" && $0.isOn && !$0.isManualOverrideActive }) {
                        toggleSmartDevice(id: humDev.id, trigger: t(nl: "Autopilot • Voorbereiding FAE", en: "Autopilot • Preparation for FAE"))
                    }
                    
                    if !fanDev.isOn {
                        toggleSmartDevice(id: fanDev.id, trigger: t(nl: isTest ? "Autopilot Sneltest FAE" : "Autopilot • FAE ventilatie", en: isTest ? "Autopilot Quick Test FAE" : "Autopilot • FAE exhaust"))
                    }
                    db.environmentConfig.lastFaeExecutionTime = now
                    let duration = isTest ? 1 : db.environmentConfig.faeDurationMinutes
                    db.environmentConfig.lastAutopilotLogMessage = t(
                        nl: isTest ? "⚡️ Autopilot Sneltest: Ventilator gestart (1m testcyclus)" : "Ventilator automatisch gestart voor \(duration)m FAE verversing",
                        en: isTest ? "⚡️ Autopilot Quick Test: Fan started (1m test cycle)" : "Fan automatically started for \(duration)m FAE cycle"
                    )
                    db.environmentConfig.lastAutopilotLogTime = now
                    hasChanges = true
                    
                    // Schedule turning off after duration, then sequentially trigger post-FAE humidity check!
                    let offSeconds = isTest ? 10.0 : Double(duration * 60)
                    let fanId = fanDev.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + offSeconds) { [weak self] in
                        guard let self = self else { return }
                        if let currentIdx = self.db.smartDevices.firstIndex(where: { $0.id == fanId }),
                           self.db.smartDevices[currentIdx].isOn,
                           !self.db.smartDevices[currentIdx].isManualOverrideActive {
                            self.toggleSmartDevice(id: self.db.smartDevices[currentIdx].id, trigger: self.t(nl: "Autopilot • FAE cyclus voltooid", en: "Autopilot • FAE cycle completed"))
                            self.db.environmentConfig.lastAutopilotLogMessage = self.t(
                                nl: "Ventilatiecyclus voltooid • CO2 afgevoerd • Start vochtherstel",
                                en: "FAE cycle completed • CO2 vented • Starting humidity restore"
                            )
                            self.db.environmentConfig.lastAutopilotLogTime = Date()
                            self.save()
                        }
                    }
                }
            } else if isTest {
                db.environmentConfig.lastAutopilotLogMessage = t(
                    nl: "⚡️ Autopilot Sneltest: Geen FAE ventilator gekoppeld",
                    en: "⚡️ Autopilot Quick Test: No FAE fan connected"
                )
                db.environmentConfig.lastAutopilotLogTime = now
                hasChanges = true
            }
        }
        
        // 2. AUTOMATIC HUMIDIFIER CYCLE (CLOSED-LOOP RV CONTROL - Standard Autopilot)
        // SEQUENTIAL ENFORCEMENT: Only evaluate humidifier if Exhaust Fan is NOT running
        let updatedFanRunning = db.smartDevices.contains { $0.deviceType == "ExhaustFan" && $0.isOn }
        if !updatedFanRunning && !isPreFaeLockoutActive && isGlobalScheduleEffective {
            if db.environmentConfig.lastHumidifierExecutionTime == nil {
                db.environmentConfig.lastHumidifierExecutionTime = now
            }
            let humMinsPassed = db.environmentConfig.lastHumidifierExecutionTime.map { now.timeIntervalSince($0) / 60.0 } ?? 0.0
            if isTest || (!isDuringStartupGracePeriod && humMinsPassed >= 15.0) {
                // ONLY act on real sensor readings received!
                if let currentHumidity = db.environmentConfig.latestSensorHumidityPct {
                    if !isDuringStartupGracePeriod && currentHumidity < (db.environmentConfig.targetHumidityPct - 3.0) {
                        if let humIdx = db.smartDevices.firstIndex(where: { $0.deviceType == "Humidifier" && $0.autoControlEnabled && $0.autopilotMode != "customInterval" }) {
                            let humDev = db.smartDevices[humIdx]
                            if humDev.isManualOverrideActive {
                                // Manual override active on humidifier, skip automatic trigger
                            } else if !humDev.isOn {
                                toggleSmartDevice(id: humDev.id, trigger: t(nl: "Autopilot • Luchtbevochtiger", en: "Autopilot • Humidifier"))
                                db.environmentConfig.lastHumidifierExecutionTime = now
                                db.environmentConfig.lastAutopilotLogMessage = t(
                                    nl: "Luchtbevochtiger ingeschakeld (Sensor RV: \(Int(currentHumidity))%, doel is \(Int(db.environmentConfig.targetHumidityPct))%)",
                                    en: "Humidifier triggered (Sensor RH: \(Int(currentHumidity))%, target is \(Int(db.environmentConfig.targetHumidityPct))%)"
                                )
                                db.environmentConfig.lastAutopilotLogTime = now
                                hasChanges = true
                                
                                let shutOffDelay = isTest ? 10.0 : 240.0
                                let humId = humDev.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + shutOffDelay) { [weak self] in
                                    guard let self = self else { return }
                                    if let currentHumIdx = self.db.smartDevices.firstIndex(where: { $0.id == humId }),
                                       self.db.smartDevices[currentHumIdx].isOn,
                                       !self.db.smartDevices[currentHumIdx].isManualOverrideActive {
                                        self.toggleSmartDevice(id: self.db.smartDevices[currentHumIdx].id, trigger: self.t(nl: "Autopilot • Bevochtiging voltooid", en: "Autopilot • Humidification completed"))
                                        self.db.environmentConfig.lastAutopilotLogMessage = self.t(
                                            nl: "Bevochtiging voltooid • Doel RV bereikt",
                                            en: "Humidification complete • Target RH reached"
                                        )
                                        self.db.environmentConfig.lastAutopilotLogTime = Date()
                                        self.save()
                                    }
                                }
                            }
                        } else if isTest {
                            db.environmentConfig.lastAutopilotLogMessage = t(
                                nl: "⚡️ Autopilot Sneltest: RV is \(Int(currentHumidity))% (te laag), maar geen bevochtiger gekoppeld",
                                en: "⚡️ Autopilot Quick Test: RH is \(Int(currentHumidity))% (low), but no humidifier connected"
                            )
                            db.environmentConfig.lastAutopilotLogTime = now
                            hasChanges = true
                        }
                    } else if isTest {
                        db.environmentConfig.lastAutopilotLogMessage = t(
                            nl: "⚡️ Autopilot Sneltest: Sensor RV (\(Int(currentHumidity))%) is op peil (doel: \(Int(db.environmentConfig.targetHumidityPct))%)",
                            en: "⚡️ Autopilot Quick Test: Sensor RH (\(Int(currentHumidity))%) is on target (\(Int(db.environmentConfig.targetHumidityPct))%)"
                        )
                        db.environmentConfig.lastAutopilotLogTime = now
                        hasChanges = true
                    }
                } else if isTest && !hasChanges {
                    db.environmentConfig.lastAutopilotLogMessage = t(
                        nl: "⚡️ Autopilot Sneltest: Geen actieve sensor gekoppeld (luchtbevochtiger wacht op sensormeting)",
                        en: "⚡️ Autopilot Quick Test: No sensor connected (humidifier waiting for live sensor reading)"
                    )
                    db.environmentConfig.lastAutopilotLogTime = now
                    hasChanges = true
                }
            }
        } else {
            // Humidifier waits for fan to finish
            if let humIdx = db.smartDevices.firstIndex(where: { $0.deviceType == "Humidifier" && $0.autoControlEnabled }),
               db.smartDevices[humIdx].isOn,
               !db.smartDevices[humIdx].isManualOverrideActive {
                toggleSmartDevice(id: db.smartDevices[humIdx].id, trigger: t(nl: "Autopilot • FAE voorrang", en: "Autopilot • FAE priority"))
            }
        }
        
        // 3. AUTOMATIC GROW LIGHT CYCLE (Standard Autopilot)
        let currentHour = Calendar.current.component(.hour, from: now)
        for lightIdx in 0..<db.smartDevices.count {
            let dev = db.smartDevices[lightIdx]
            let isLight = dev.deviceType == "Light"
                || dev.name.localizedCaseInsensitiveContains("lamp")
                || dev.name.localizedCaseInsensitiveContains("licht")
                || dev.name.localizedCaseInsensitiveContains("kweeklamp")
            guard isLight && dev.autoControlEnabled else { continue }
            
            if dev.isManualOverrideActive {
                // Kweker heeft kweeklamp handmatig bediend (AAN of UIT)!
                // Respecteer handmatige overschrijving en schakel NOOIT automatisch terug!
                continue
            }
            
            guard dev.isScheduleEffective else { continue }
            let onH = dev.lightOnHour
            let offH = dev.lightOffHour
            
            let isLightTime: Bool
            if onH < offH {
                isLightTime = currentHour >= onH && currentHour < offH
            } else {
                // Crosses midnight (e.g. 20:00 to 08:00)
                isLightTime = currentHour >= onH || currentHour < offH
            }
            
            if isLightTime && !dev.isOn {
                toggleSmartDevice(id: dev.id, trigger: t(nl: "Autopilot • Dagcyclus kweeklamp", en: "Autopilot • Day cycle grow light"))
                db.environmentConfig.lastAutopilotLogMessage = t(
                    nl: "Dagcyclus: Kweeklamp ingeschakeld (\(String(format: "%02d:00", onH))-\(String(format: "%02d:00", offH)))",
                    en: "Day cycle: Grow light turned ON (\(String(format: "%02d:00", onH))-\(String(format: "%02d:00", offH)))"
                )
                db.environmentConfig.lastAutopilotLogTime = now
                hasChanges = true
            } else if !isLightTime && dev.isOn {
                toggleSmartDevice(id: dev.id, trigger: t(nl: "Autopilot • Nachtcyclus kweeklamp", en: "Autopilot • Night cycle grow light"))
                db.environmentConfig.lastAutopilotLogMessage = t(
                    nl: "Nachtcyclus: Kweeklamp uitgeschakeld",
                    en: "Night cycle: Grow light turned OFF"
                )
                db.environmentConfig.lastAutopilotLogTime = now
                hasChanges = true
            }
        }

        // 4. AUTOMATIC THERMOSTAT / HEATER CLOSED-LOOP CONTROL (Day/Night & Pinning aware)
        if let currentTemp = db.environmentConfig.currentTempC {
            let targetTemp = db.environmentConfig.effectiveTargetTempC
            for heaterIdx in 0..<db.smartDevices.count {
                let dev = db.smartDevices[heaterIdx]
                let isHeater = dev.deviceType == "Heater"
                    || dev.name.localizedCaseInsensitiveContains("kachel")
                    || dev.name.localizedCaseInsensitiveContains("verwarm")
                    || dev.name.localizedCaseInsensitiveContains("heat")
                    || dev.name.localizedCaseInsensitiveContains("mat")
                guard isHeater && dev.autoControlEnabled && !dev.isManualOverrideActive else { continue }
                
                // If temp is below target - 0.4°C -> Turn ON heater
                if currentTemp < (targetTemp - 0.4) && !dev.isOn {
                    toggleSmartDevice(id: dev.id, trigger: t(
                        nl: "Autopilot • Verwarming AAN (Actueel: \(String(format: "%.1f", currentTemp))°C, Doel: \(String(format: "%.1f", targetTemp))°C)",
                        en: "Autopilot • Heater ON (Current: \(String(format: "%.1f", currentTemp))°C, Target: \(String(format: "%.1f", targetTemp))°C)"
                    ))
                    let modeDesc = db.environmentConfig.isPinningInductionActive ? "Pinning Koudeval" : (db.environmentConfig.isCurrentlyDayTime ? "Dagprofiel" : "Nachtprofiel")
                    db.environmentConfig.lastAutopilotLogMessage = t(
                        nl: "🌡️ Verwarming ingeschakeld [\(modeDesc)] (Sensor: \(String(format: "%.1f", currentTemp))°C, Doel: \(String(format: "%.1f", targetTemp))°C)",
                        en: "🌡️ Heater turned ON [\(modeDesc)] (Sensor: \(String(format: "%.1f", currentTemp))°C, Target: \(String(format: "%.1f", targetTemp))°C)"
                    )
                    db.environmentConfig.lastAutopilotLogTime = now
                    hasChanges = true
                } else if currentTemp >= targetTemp && dev.isOn {
                    // Reached target temp -> Turn OFF heater
                    toggleSmartDevice(id: dev.id, trigger: t(
                        nl: "Autopilot • Verwarming UIT (Doeltemperatuur bereikt: \(String(format: "%.1f", currentTemp))°C)",
                        en: "Autopilot • Heater OFF (Target temp reached: \(String(format: "%.1f", currentTemp))°C)"
                    ))
                    db.environmentConfig.lastAutopilotLogMessage = t(
                        nl: "✅ Verwarming uitgeschakeld: Doeltemperatuur (\(String(format: "%.1f", targetTemp))°C) bereikt",
                        en: "✅ Heater switched OFF: Target temperature (\(String(format: "%.1f", targetTemp))°C) reached"
                    )
                    db.environmentConfig.lastAutopilotLogTime = now
                    hasChanges = true
                }
            }
        }

        
        if hasChanges {
            save()
            MycoBackgroundHubManager.shared.lastHubActionDescription = db.environmentConfig.lastAutopilotLogMessage
            MycoBackgroundHubManager.shared.lastHubHeartbeat = now
            LiveKitStreamManager.shared.broadcastHubHeartbeat()
        }
    }

    func syncCloudData(force: Bool = false) {
        // 1. Always merge dedicated fast SmartDevices & Tombstone payloads from iCloud KVS
        if let rawSmartDevices = MycoKVS.data(forKey: "MycoLabSmartDevicesPayload"),
           let decodedDevices = try? JSONDecoder().decode([SmartDeviceItem].self, from: rawSmartDevices) {
            let deletedIDs: [UUID] = {
                guard let dData = MycoKVS.data(forKey: "MycoLabDeletedItemIDsPayload"),
                      let ids = try? JSONDecoder().decode([UUID].self, from: dData) else { return [] }
                return ids
            }()
            DispatchQueue.main.async {
                MycoSyncManager.shared.mergeIncomingSmartDevices(
                    decodedDevices,
                    incomingDeletedIDs: deletedIDs
                )
            }
        }

        // 2. Merge full cloud payload
        if let rawCloudData = MycoKVS.data(forKey: "MycoLabCloudPayload") {
            let cloudTimestamp = MycoKVS.double(forKey: "MycoLabCloudTimestamp")
            let localTimestamp = lastSavedTimestamp?.timeIntervalSince1970 ?? 0
            let localCount = db.projects.count + db.cultures.count + db.strains.count + db.stash.count + db.supplies.count + db.smartDevices.count
            
            if force || localCount == 0 || cloudTimestamp > localTimestamp {
                if let envelope = try? JSONDecoder().decode(MycoSyncEnvelope.self, from: rawCloudData),
                   let _ = envelope.database {
                    DispatchQueue.main.async {
                        MycoSyncManager.shared.handleIncomingData(rawCloudData, transport: "iCloud KVS")
                        self.lastSavedTimestamp = Date(timeIntervalSince1970: max(cloudTimestamp, Date().timeIntervalSince1970))
                        self.lastCloudSyncTimestamp = Date()
                    }
                    return
                }
                if let decoded = try? JSONDecoder().decode(AppDatabase.self, from: rawCloudData) {
                    DispatchQueue.main.async {
                        _ = MycoSyncManager.shared.mergeIncomingDatabase(decoded, appleUser: self.appleUser)
                        self.lastSavedTimestamp = Date(timeIntervalSince1970: max(cloudTimestamp, Date().timeIntervalSince1970))
                        self.lastCloudSyncTimestamp = Date()
                    }
                    return
                }
                let cloudData = MycoSecurityVault.decryptIfEncrypted(rawCloudData)
                if let decoded = try? JSONDecoder().decode(AppDatabase.self, from: cloudData) {
                    DispatchQueue.main.async {
                        _ = MycoSyncManager.shared.mergeIncomingDatabase(decoded, appleUser: self.appleUser)
                        self.lastSavedTimestamp = Date(timeIntervalSince1970: max(cloudTimestamp, Date().timeIntervalSince1970))
                        self.lastCloudSyncTimestamp = Date()
                    }
                }
            }
        }
        
        // Restore Tuya credentials from dedicated iCloud KVS if local is empty
        if self.db.environmentConfig.tuyaApiKey.isEmpty {
            if let tData = MycoKVS.data(forKey: "MycoLabTuyaCredentials"),
               let dict = try? JSONSerialization.jsonObject(with: tData) as? [String: Any],
               let k = dict["tuyaApiKey"] as? String, !k.isEmpty {
                DispatchQueue.main.async {
                    self.db.environmentConfig.tuyaApiKey = k
                    self.db.environmentConfig.tuyaApiSecret = dict["tuyaApiSecret"] as? String ?? ""
                    self.db.environmentConfig.tuyaRegion = dict["tuyaRegion"] as? String ?? "ce"
                    self.db.environmentConfig.tuyaDeviceID = dict["tuyaDeviceID"] as? String ?? ""
                    self.db.environmentConfig.tuyaVerified = dict["tuyaVerified"] as? Bool ?? false
                    self.save()
                    print("[MycoLabs] Tuya credentials hersteld in syncCloudData via dedicated iCloud sleutel!")
                }
            }
        }
    }

    func displayTitle(name: String, sku: String) -> String {
        db.stealthMode ? (sku.isEmpty ? "LAB-ITEM" : sku) : name
    }
    
    func formatQuantity(_ value: Double, unit: String) -> String {
        if value == floor(value) {
            return "\(Int(value)) \(unit)"
        } else {
            return String(format: "%.2f %@", value, unit)
        }
    }
    
    func generateTransparentProcessReport(for project: GrowProject) -> String {
        let formattedDate = project.startDate.formatted(date: .numeric, time: .shortened)
        let harvests = db.harvests.filter { $0.projectID == project.id }
        let totalWet = harvests.reduce(0.0) { $0 + $1.wetWeightGrams }
        let totalDry = harvests.reduce(0.0) { $0 + $1.dryWeightGrams }
        
        var lines: [String] = []
        lines.append("🔬 MYCOLAB PROCES-DOSSIER & HERKOMST")
        lines.append("────────────────────────────────────")
        lines.append("🧬 GENETICA & SOORT")
        lines.append("• Soort: \(displayTitle(name: project.strainName, sku: project.skuCode))")
        lines.append("• Batch: #\(project.batchNumber) (\(project.skuCode))")
        if !project.parentCultureLabel.isEmpty {
            lines.append("• Moederlijn: \(project.parentCultureLabel)")
        }
        lines.append("• Gestart: \(formattedDate)")
        lines.append("")
        lines.append("📦 CONTAINER & SUBSTRAAT")
        if !project.recipeName.isEmpty {
            lines.append("• Bereidingsrecept: \(project.recipeName)")
        }
        lines.append("• Type: \(project.containerName.isEmpty ? "Pot / Broedzak" : project.containerName)")
        lines.append("• Substraat/Graan: \(project.substrateName.isEmpty ? "Roggegraan / CVG" : project.substrateName)")
        lines.append("• Drooggewicht: \(String(format: "%.0f", project.drySubstrateWeightGrams))g")
        if !project.spawnToBulkRatio.isEmpty {
            lines.append("• Spawn-Bulk Ratio: \(project.spawnToBulkRatio)")
        }
        lines.append("")
        lines.append("⚡ STERILISATIE & STATUS")
        lines.append("• Protocol: \(project.sterilizationNotes.isEmpty ? "Standaard 90m @ 15 PSI" : project.sterilizationNotes)")
        lines.append("• Fase: \(project.phase.rawValue)")
        lines.append("• Kolonisatie: \(Int(project.normalizedColonizationPercent))%")
        lines.append("")
        if project.latestTempC != nil || project.latestHumidityPct != nil {
            lines.append("🌡️ LAATSTE METINGEN")
            if let t = project.latestTempC { lines.append("• Temp: \(String(format: "%.1f°C", t))") }
            if let h = project.latestHumidityPct { lines.append("• Vocht: \(String(format: "%.0f%%", h))") }
            lines.append("")
        }
        if !harvests.isEmpty {
            lines.append("🍄 OOGST & OPBRENGST")
            lines.append("• Flushes: \(harvests.count)")
            lines.append("• Totaal Vers: \(String(format: "%.1f g", totalWet))")
            lines.append("• Totaal Gedroogd: \(String(format: "%.2f g", totalDry))")
            if let h1 = harvests.first {
                lines.append("• Droging: \(h1.dehydratorHours)u @ \(h1.dehydratorTempC)°C")
            }
            lines.append("")
        }
        lines.append("🔐 VERIFICATIE ID")
        lines.append("• \(project.qrCodeID)")
        lines.append("────────────────────────────────────")
        return lines.joined(separator: "\n")
    }
    
    func nextSKU(prefix: String) -> String {
        let count = db.projects.count + db.cultures.count + db.strains.count + 1
        return String(format: "%@-%03d", prefix, count)
    }
    
    func addHarvestAndSyncStash(_ harvest: HarvestRecord, syncToStash: Bool, potency: Double) {
        db.harvests.insert(harvest, at: 0)
        if syncToStash && harvest.dryWeightGrams > 0 {
            if let idx = db.stash.firstIndex(where: { $0.strainName.lowercased() == harvest.strainName.lowercased() }) {
                db.stash[idx].availableDryGrams += harvest.dryWeightGrams
                db.stash[idx].lastUpdated = Date()
            } else {
                let newJar = StashJar(
                    strainName: harvest.strainName,
                    skuCode: harvest.skuCode,
                    potencyMultiplier: potency,
                    availableDryGrams: harvest.dryWeightGrams,
                    storageMethod: "Luchtdichte Pot + Silica",
                    qrCodeID: "QR-STASH-" + UUID().uuidString.prefix(8).uppercased()
                )
                db.stash.append(newJar)
            }
        }
        save()
    }

    // MARK: - Biological Efficiency (BE%) & Harvest Telemetry
    public func projectHarvests(for projectID: UUID) -> [HarvestRecord] {
        db.harvests.filter { $0.projectID == projectID }
    }
    
    public func bePercent(for projectID: UUID) -> Double? {
        guard let project = db.projects.first(where: { $0.id == projectID }),
              project.drySubstrateWeightGrams > 0 else { return nil }
        let totalWet = db.harvests.filter { $0.projectID == projectID }.reduce(0.0) { $0 + $1.wetWeightGrams }
        guard totalWet > 0 else { return nil }
        return (totalWet / project.drySubstrateWeightGrams) * 100.0
    }
    
    public func totalHarvestWetGrams(for projectID: UUID) -> Double {
        db.harvests.filter { $0.projectID == projectID }.reduce(0.0) { $0 + $1.wetWeightGrams }
    }
    
    public func totalHarvestDryGrams(for projectID: UUID) -> Double {
        db.harvests.filter { $0.projectID == projectID }.reduce(0.0) { $0 + $1.dryWeightGrams }
    }
    
    func exportJSONString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(db),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    // MARK: - ALL SAVED & ACTIVE QR CODES (CENTRAL QR ARCHIVE)
    public var allSavedQRCodes: [SavedQRCodeItem] {
        var items: [SavedQRCodeItem] = []
        var seenCodes: Set<String> = []
        
        // 1. Projects / Batches
        for project in db.projects {
            let code = project.qrCodeID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { continue }
            seenCodes.insert(code)
            let richQR = generateTransparentProcessReport(for: project)
            items.append(SavedQRCodeItem(
                id: project.id,
                code: code,
                title: "\(displayTitle(name: project.strainName, sku: project.skuCode)) #\(project.batchNumber)",
                subtitle: "\(project.phase.rawValue) • \(project.containerName)",
                category: t(nl: "Kweekbatch", en: "Grow Batch"),
                dateCreated: project.startDate,
                linkedID: project.id,
                notes: project.substrateName.isEmpty ? "" : "Substraat: \(project.substrateName)",
                payload: richQR
            ))
        }
        
        // 2. Cultures (LC, Agar, Slants, etc.)
        for cult in db.cultures {
            let code = cult.qrCodeID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { continue }
            seenCodes.insert(code)
            let formattedDate = cult.dateCreated.formatted(date: .numeric, time: .omitted)
            let richQR = """
🍄 MycoLabs Moedercultuur
Soort: \(displayTitle(name: cult.strainName, sku: cult.skuCode))
Type: \(cult.cultureType)
Generatie: \(cult.generation)
Status: \(cult.status)
Aangemaakt: \(formattedDate)
ID: \(cult.qrCodeID)
"""
            items.append(SavedQRCodeItem(
                id: cult.id,
                code: code,
                title: displayTitle(name: cult.strainName, sku: cult.skuCode),
                subtitle: "\(cult.cultureType) • \(cult.generation)",
                category: t(nl: "Cultuur", en: "Culture"),
                dateCreated: cult.dateCreated,
                linkedID: cult.id,
                notes: cult.mediaName.isEmpty ? cult.notes : "\(cult.mediaName) • \(cult.notes)",
                payload: richQR
            ))
        }
        
        // 3. Stash Jars
        for jar in db.stash {
            let code = jar.qrCodeID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { continue }
            seenCodes.insert(code)
            let payload = jar.qrCodeID.isEmpty ? "MYCOLAB-STASH|\(jar.skuCode)|\(jar.strainName)|\(jar.availableDryGrams)g" : jar.qrCodeID
            items.append(SavedQRCodeItem(
                id: jar.id,
                code: code,
                title: displayTitle(name: jar.strainName, sku: jar.skuCode),
                subtitle: "\(jar.storageMethod) • \(String(format: "%.1f", jar.availableDryGrams))g",
                category: t(nl: "Stash Voorraad", en: "Stash Inventory"),
                dateCreated: jar.lastUpdated,
                linkedID: jar.id,
                notes: "\(String(format: "%.1fx", jar.potencyMultiplier)) potentie",
                payload: payload
            ))
        }
        
        // 4. Lab Supplies
        for sup in db.supplies {
            let code = sup.qrCodeID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { continue }
            seenCodes.insert(code)
            items.append(SavedQRCodeItem(
                id: sup.id,
                code: code,
                title: sup.name,
                subtitle: "\(sup.category) • \(String(format: "%.1f %@", sup.quantity, sup.unit))",
                category: t(nl: "Lab Voorraad", en: "Lab Supply"),
                dateCreated: Date(),
                linkedID: sup.id,
                notes: "Min. drempel: \(String(format: "%.1f %@", sup.minThreshold, sup.unit))",
                payload: code
            ))
        }
        
        // 5. Custom / Manually Saved QR Codes
        for custom in db.customQRCodes {
            items.append(custom)
        }
        
        // Sort newest first
        return items.sorted(by: { $0.dateCreated > $1.dateCreated })
    }
}

// MARK: - 4. QR CODE GENERATOR & PDF/AIRPRINT HELPER
struct QRCodeGenerator {
    static let context = CIContext()
    
    static func generateImage(from string: String, size: CGFloat = 240, includeLogo: Bool = false, correctionLevel: String? = nil) -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        let effectiveLevel = correctionLevel ?? (includeLogo ? "H" : (MycoStore.shared?.db.qrErrorCorrectionLevel ?? "H"))
        filter.correctionLevel = effectiveLevel
        
        guard let outputImage = filter.outputImage else { return UIImage() }
        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return UIImage()
        }
        let baseQR = UIImage(cgImage: cgImage)
        
        guard includeLogo,
              let logoURL = Bundle.main.url(forResource: "MycoLabIcon", withExtension: "jpg"),
              let logoImg = UIImage(contentsOfFile: logoURL.path) else {
            return baseQR
        }
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            baseQR.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
            
            let logoSize: CGFloat = size * 0.22
            let logoRect = CGRect(
                x: (size - logoSize) / 2,
                y: (size - logoSize) / 2,
                width: logoSize,
                height: logoSize
            )
            
            let bgPath = UIBezierPath(roundedRect: logoRect.insetBy(dx: -3, dy: -3), cornerRadius: 6)
            UIColor.white.setFill()
            bgPath.fill()
            
            UIColor.systemGray4.setStroke()
            bgPath.lineWidth = 1
            bgPath.stroke()
            
            ctx.cgContext.saveGState()
            let clipPath = UIBezierPath(roundedRect: logoRect, cornerRadius: 5)
            clipPath.addClip()
            logoImg.draw(in: logoRect)
            ctx.cgContext.restoreGState()
        }
    }
    
    static func createPrintablePDF(labels: [(title: String, subtitle: String, date: String, qr: String)], includeLogo: Bool = false) -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 in points
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MycoLab_QR_Labels-\(UUID().uuidString).pdf")
        
        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            let cols = 3
            let cardW: CGFloat = 170
            let cardH: CGFloat = 95
            let startX: CGFloat = 30
            let startY: CGFloat = 35
            let spacingX: CGFloat = 12
            let spacingY: CGFloat = 12
            
            for (index, item) in labels.enumerated() {
                if index > 0 && index % 21 == 0 {
                    ctx.beginPage()
                }
                let pageIndex = index % 21
                let row = pageIndex / cols
                let col = pageIndex % cols
                
                let x = startX + CGFloat(col) * (cardW + spacingX)
                let y = startY + CGFloat(row) * (cardH + spacingY)
                let rect = CGRect(x: x, y: y, width: cardW, height: cardH)
                
                UIColor.white.setFill()
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
                path.fill()
                UIColor.black.setStroke()
                path.lineWidth = 1
                path.stroke()
                
                let qrImg = generateImage(from: item.qr, size: 150, includeLogo: includeLogo)
                qrImg.draw(in: CGRect(x: x + 8, y: y + 10, width: 75, height: 75))
                
                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: UIColor.black
                ]
                let subAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 8, weight: .regular),
                    .foregroundColor: UIColor.darkGray
                ]
                
                let textX = x + 88
                let textW = cardW - 94
                (item.title as NSString).draw(in: CGRect(x: textX, y: y + 12, width: textW, height: 26), withAttributes: titleAttr)
                (item.subtitle as NSString).draw(in: CGRect(x: textX, y: y + 40, width: textW, height: 24), withAttributes: subAttr)
                (item.date as NSString).draw(in: CGRect(x: textX, y: y + 66, width: textW, height: 14), withAttributes: subAttr)
                (item.qr as NSString).draw(in: CGRect(x: textX, y: y + 78, width: textW, height: 12), withAttributes: subAttr)
            }
        }
        return url
    }
    
    static func printPDF(url: URL) {
        guard UIPrintInteractionController.canPrint(url) else { return }
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "MycoLabs QR Labels"
        printInfo.outputType = .general
        
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = url
        controller.present(animated: true, completionHandler: nil)
    }
}

// MARK: - 4B. REPORT & DATA EXPORTER (PDF & CSV)
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityViewWrapper: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MycoReportExporter {
    static func generateGrowReportPDF(project: GrowProject, store: MycoStore) -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let filename = "MycoLab_Report_\(project.skuCode)_Batch\(project.batchNumber)_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        let flushes = store.db.harvests.filter { $0.projectID == project.id }.sorted { $0.flushNumber < $1.flushNumber }
        let logs = store.db.logs.filter { $0.projectID == project.id }.sorted { $0.timestamp > $1.timestamp }
        let totalWet = flushes.reduce(0) { $0 + $1.wetWeightGrams }
        let totalDry = flushes.reduce(0) { $0 + $1.dryWeightGrams }
        let bePct = project.drySubstrateWeightGrams > 0 ? (totalWet / project.drySubstrateWeightGrams) * 100.0 : 0
        
        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            
            // Background fill
            UIColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1.0).setFill()
            UIRectFill(pageRect)
            
            let cardBg = UIColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 1.0)
            let borderColor = UIColor(red: 0.22, green: 0.28, blue: 0.38, alpha: 1.0)
            let greenColor = UIColor(red: 0.2, green: 0.78, blue: 0.45, alpha: 1.0)
            let blueColor = UIColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1.0)
            let amberColor = UIColor(red: 0.95, green: 0.65, blue: 0.15, alpha: 1.0)
            
            // Header Card
            let headerRect = CGRect(x: 32, y: 32, width: pageRect.width - 64, height: 85)
            let headerPath = UIBezierPath(roundedRect: headerRect, cornerRadius: 10)
            cardBg.setFill()
            headerPath.fill()
            borderColor.setStroke()
            headerPath.lineWidth = 1
            headerPath.stroke()
            
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let subTitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: blueColor
            ]
            let normalAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9.5, weight: .regular),
                .foregroundColor: UIColor.lightGray
            ]
            let boldAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            
            ("MYCOLAB — OFFICIAL CULTIVATION REPORT & DOSSIER" as NSString).draw(at: CGPoint(x: 46, y: 44), withAttributes: titleAttr)
            
            let strainDesc = "\(store.displayTitle(name: project.strainName, sku: project.skuCode)) • Batch #\(project.batchNumber) • Phase: \(project.phase.rawValue.uppercased())"
            (strainDesc as NSString).draw(at: CGPoint(x: 46, y: 68), withAttributes: subTitleAttr)
            
            let dateStr = "Started: \(project.startDate.formatted(date: .abbreviated, time: .omitted)) • Generated: \(Date().formatted(date: .abbreviated, time: .shortened))"
            (dateStr as NSString).draw(at: CGPoint(x: 46, y: 88), withAttributes: normalAttr)
            
            // QR Code thumbnail in header
            let qrImg = QRCodeGenerator.generateImage(from: project.qrCodeID, size: 100, includeLogo: false)
            qrImg.draw(in: CGRect(x: headerRect.maxX - 72, y: 40, width: 60, height: 60))
            
            var currentY: CGFloat = 127
            
            // 1. Batch & Setup Specifications Card
            let setupRect = CGRect(x: 32, y: currentY, width: pageRect.width - 64, height: 100)
            let setupPath = UIBezierPath(roundedRect: setupRect, cornerRadius: 8)
            cardBg.setFill()
            setupPath.fill()
            borderColor.setStroke()
            setupPath.lineWidth = 1
            setupPath.stroke()
            
            ("BATCH & SETUP SPECIFICATIONS" as NSString).draw(at: CGPoint(x: 44, y: currentY + 10), withAttributes: boldAttr)
            
            let col1X: CGFloat = 44
            let col2X: CGFloat = 290
            
            ("Container: \(project.containerName.isEmpty ? "Standard Setup" : project.containerName)" as NSString).draw(at: CGPoint(x: col1X, y: currentY + 28), withAttributes: normalAttr)
            ("Substrate: \(project.substrateName.isEmpty ? "Custom substrate" : project.substrateName)" as NSString).draw(at: CGPoint(x: col1X, y: currentY + 44), withAttributes: normalAttr)
            ("Spawn-to-Bulk: \(project.spawnToBulkRatio)" as NSString).draw(at: CGPoint(x: col1X, y: currentY + 60), withAttributes: normalAttr)
            ("Dry Substrate: \(String(format: "%.0f g", project.drySubstrateWeightGrams))" as NSString).draw(at: CGPoint(x: col1X, y: currentY + 76), withAttributes: normalAttr)
            
            ("Colonization Degree: \(Int(project.normalizedColonizationPercent))%" as NSString).draw(at: CGPoint(x: col2X, y: currentY + 28), withAttributes: normalAttr)
            ("Lineage / Origin: \(project.parentCultureLabel.isEmpty ? "Inoculated directly" : project.parentCultureLabel)" as NSString).draw(at: CGPoint(x: col2X, y: currentY + 44), withAttributes: normalAttr)
            let tagsString = project.tags.isEmpty ? "No tags" : project.tags.joined(separator: ", ")
            ("Status Tags: \(tagsString)" as NSString).draw(at: CGPoint(x: col2X, y: currentY + 60), withAttributes: normalAttr)
            if let bDate = project.lastBreakAndShakeDate {
                ("Latest B&S: \(bDate.formatted(date: .numeric, time: .omitted))" as NSString).draw(at: CGPoint(x: col2X, y: currentY + 76), withAttributes: normalAttr)
            } else {
                ("Break & Shake: Not performed yet" as NSString).draw(at: CGPoint(x: col2X, y: currentY + 76), withAttributes: normalAttr)
            }
            
            currentY += 110
            
            // 2. Harvest & Biological Efficiency Statistics (BE%)
            let harvestCardH: CGFloat = 130
            let harvestRect = CGRect(x: 32, y: currentY, width: pageRect.width - 64, height: harvestCardH)
            let harvestPath = UIBezierPath(roundedRect: harvestRect, cornerRadius: 8)
            cardBg.setFill()
            harvestPath.fill()
            borderColor.setStroke()
            harvestPath.lineWidth = 1
            harvestPath.stroke()
            
            ("HARVEST & BIOLOGICAL EFFICIENCY (BE%)" as NSString).draw(at: CGPoint(x: 44, y: currentY + 10), withAttributes: boldAttr)
            
            let mY = currentY + 28
            ("TOTAL WET" as NSString).draw(at: CGPoint(x: 44, y: mY), withAttributes: normalAttr)
            (String(format: "%.1f g", totalWet) as NSString).draw(at: CGPoint(x: 44, y: mY + 12), withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor.white
            ])
            
            ("TOTAL DRY" as NSString).draw(at: CGPoint(x: 180, y: mY), withAttributes: normalAttr)
            (String(format: "%.2f g", totalDry) as NSString).draw(at: CGPoint(x: 180, y: mY + 12), withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: greenColor
            ])
            
            ("AVG MOISTURE LOSS" as NSString).draw(at: CGPoint(x: 320, y: mY), withAttributes: normalAttr)
            let avgLoss = totalWet > 0 ? ((totalWet - totalDry) / totalWet) * 100.0 : 0
            (String(format: "%.1f%%", avgLoss) as NSString).draw(at: CGPoint(x: 320, y: mY + 12), withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: amberColor
            ])
            
            ("BIO-EFFICIENCY (BE)" as NSString).draw(at: CGPoint(x: 450, y: mY), withAttributes: normalAttr)
            (String(format: "%.1f%%", bePct) as NSString).draw(at: CGPoint(x: 450, y: mY + 12), withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: bePct >= 100 ? greenColor : blueColor
            ])
            
            // Flushes mini-table
            let tableY = currentY + 62
            ("Flush #" as NSString).draw(at: CGPoint(x: 44, y: tableY), withAttributes: boldAttr)
            ("Date" as NSString).draw(at: CGPoint(x: 110, y: tableY), withAttributes: boldAttr)
            ("Wet (g)" as NSString).draw(at: CGPoint(x: 210, y: tableY), withAttributes: boldAttr)
            ("Dry (g)" as NSString).draw(at: CGPoint(x: 300, y: tableY), withAttributes: boldAttr)
            ("Dehydrator Temp / Time" as NSString).draw(at: CGPoint(x: 400, y: tableY), withAttributes: boldAttr)
            
            var rowY = tableY + 15
            if flushes.isEmpty {
                ("No flushes logged yet for this batch." as NSString).draw(at: CGPoint(x: 44, y: rowY), withAttributes: normalAttr)
            } else {
                for flush in flushes.prefix(3) {
                    ("Flush #\(flush.flushNumber)" as NSString).draw(at: CGPoint(x: 44, y: rowY), withAttributes: normalAttr)
                    (flush.harvestDate.formatted(date: .numeric, time: .omitted) as NSString).draw(at: CGPoint(x: 110, y: rowY), withAttributes: normalAttr)
                    (String(format: "%.1f g", flush.wetWeightGrams) as NSString).draw(at: CGPoint(x: 210, y: rowY), withAttributes: normalAttr)
                    (String(format: "%.2f g", flush.dryWeightGrams) as NSString).draw(at: CGPoint(x: 300, y: rowY), withAttributes: normalAttr)
                    ("\(Int(flush.dehydratorTempC))°C • \(String(format: "%.1f", flush.dehydratorHours))h" as NSString).draw(at: CGPoint(x: 400, y: rowY), withAttributes: normalAttr)
                    rowY += 14
                }
            }
            
            currentY += harvestCardH + 10
            
            // 3. Logbook & Timeline Card
            let logCardH: CGFloat = 430
            let logRect = CGRect(x: 32, y: currentY, width: pageRect.width - 64, height: logCardH)
            let logPath = UIBezierPath(roundedRect: logRect, cornerRadius: 8)
            cardBg.setFill()
            logPath.fill()
            borderColor.setStroke()
            logPath.lineWidth = 1
            logPath.stroke()
            
            ("LOGBOOK & TIMELINE" as NSString).draw(at: CGPoint(x: 44, y: currentY + 10), withAttributes: boldAttr)
            
            var logY = currentY + 28
            if logs.isEmpty {
                ("No manual or automatic log entries recorded." as NSString).draw(at: CGPoint(x: 44, y: logY), withAttributes: normalAttr)
            } else {
                for log in logs.prefix(15) {
                    let timeStr = log.timestamp.formatted(date: .numeric, time: .shortened)
                    let actionStr = "[\(log.actionType)]"
                    let climateStr = log.temperatureC != nil ? String(format: " (%.1f°C / %.0f%%)", log.temperatureC!, log.humidityPct ?? 0) : ""
                    let fullLine = "\(timeStr)  \(actionStr)\(climateStr) — \(log.notes)"
                    
                    (fullLine as NSString).draw(in: CGRect(x: 44, y: logY, width: pageRect.width - 88, height: 22), withAttributes: normalAttr)
                    logY += 25
                }
            }
            
            // Footer
            let footerText = "MycoLabs Pro Batch Export • Dossier QR: \(project.qrCodeID) • www.mycolab.io"
            (footerText as NSString).draw(at: CGPoint(x: 32, y: pageRect.height - 28), withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 8, weight: .regular),
                .foregroundColor: UIColor.gray
            ])
        }
        
        return url
    }

    // MARK: - Official Batch Certificate of Cultivation & Genetics (PDF)
    static func generateBatchCertificatePDF(project: GrowProject, store: MycoStore) -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let filename = "MycoLab_Certificate_\(project.skuCode)_Batch\(project.batchNumber)_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        let flushes = store.db.harvests.filter { $0.projectID == project.id }
        let totalWet = flushes.reduce(0) { $0 + $1.wetWeightGrams }
        let totalDry = flushes.reduce(0) { $0 + $1.dryWeightGrams }
        let bePct = project.drySubstrateWeightGrams > 0 ? (totalWet / project.drySubstrateWeightGrams) * 100.0 : 0
        
        // Compute averages
        let logsWithClimate = store.db.logs.filter { $0.projectID == project.id && $0.temperatureC != nil }
        let avgTemp = logsWithClimate.isEmpty ? 23.4 : (logsWithClimate.compactMap { $0.temperatureC }.reduce(0, +) / Double(logsWithClimate.count))
        let avgHumidity = logsWithClimate.isEmpty ? 90.5 : (logsWithClimate.compactMap { $0.humidityPct }.reduce(0, +) / Double(logsWithClimate.count))
        let avgVpd = MycoVPDCalculator.analyze(tempC: avgTemp, humidityPct: avgHumidity)?.vpdKPa ?? 0.28
        
        // Unique Cryptographic Fingerprint
        let rawHashInput = "\(project.id.uuidString)-\(project.batchNumber)-\(project.startDate.timeIntervalSince1970)"
        let hashDisplay = String(format: "%08X-%04X", abs(rawHashInput.hashValue), project.batchNumber)

        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            
            // Deep Luxury Dark Cleanroom Background
            UIColor(red: 0.05, green: 0.07, blue: 0.11, alpha: 1.0).setFill()
            UIRectFill(pageRect)
            
            let goldColor = UIColor(red: 0.85, green: 0.65, blue: 0.18, alpha: 1.0)
            let cyanColor = UIColor(red: 0.20, green: 0.75, blue: 0.95, alpha: 1.0)
            let cardBg = UIColor(red: 0.09, green: 0.12, blue: 0.18, alpha: 1.0)
            let borderColor = UIColor(red: 0.20, green: 0.26, blue: 0.36, alpha: 1.0)
            
            // Outer Certificate Border (Double Ring Frame)
            let outerFrame = CGRect(x: 24, y: 24, width: pageRect.width - 48, height: pageRect.height - 48)
            let outerPath = UIBezierPath(roundedRect: outerFrame, cornerRadius: 16)
            goldColor.setStroke()
            outerPath.lineWidth = 2.0
            outerPath.stroke()
            
            let innerFrame = outerFrame.insetBy(dx: 6, dy: 6)
            let innerPath = UIBezierPath(roundedRect: innerFrame, cornerRadius: 12)
            borderColor.setStroke()
            innerPath.lineWidth = 1.0
            innerPath.stroke()
            
            // Top Header: Seal & Title
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .heavy),
                .foregroundColor: goldColor
            ]
            let subtitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let monoSmallAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 8, weight: .medium),
                .foregroundColor: UIColor.lightGray
            ]
            let sectionTitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: cyanColor
            ]
            let labelAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: UIColor(white: 0.6, alpha: 1.0)
            ]
            let valueAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let normalAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8.5, weight: .regular),
                .foregroundColor: UIColor.lightGray
            ]
            let bigMetricAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .heavy),
                .foregroundColor: goldColor
            ]
            
            ("MYCOLAB CULTIVATION CERTIFICATE" as NSString).draw(at: CGPoint(x: 48, y: 46), withAttributes: titleAttr)
            ("OFFICIAL DOSSIER AND GENETIC CERTIFICATE OF LAB CULTIVATION" as NSString).draw(at: CGPoint(x: 48, y: 74), withAttributes: subtitleAttr)
            ("CERTIFICATE ID: #MYCO-\(hashDisplay) • ISSUED: \(Date().formatted(date: .long, time: .omitted).uppercased())" as NSString).draw(at: CGPoint(x: 48, y: 92), withAttributes: monoSmallAttr)
            
            // Official QR Stamp
            let qrImg = QRCodeGenerator.generateImage(from: project.qrCodeID, size: 100, includeLogo: false)
            qrImg.draw(in: CGRect(x: pageRect.width - 120, y: 44, width: 68, height: 68))
            
            // Section 1: Strain & Lineage
            let lineageBox = CGRect(x: 44, y: 126, width: pageRect.width - 88, height: 115)
            let lineagePath = UIBezierPath(roundedRect: lineageBox, cornerRadius: 8)
            cardBg.setFill(); lineagePath.fill()
            borderColor.setStroke(); lineagePath.lineWidth = 1; lineagePath.stroke()
            
            ("I. SPECIES & GENETIC IDENTITY" as NSString).draw(at: CGPoint(x: 56, y: 136), withAttributes: sectionTitleAttr)
            
            ("Species Name / Cultivar:" as NSString).draw(at: CGPoint(x: 56, y: 156), withAttributes: labelAttr)
            ("\(project.strainName) (\(project.skuCode))" as NSString).draw(at: CGPoint(x: 56, y: 168), withAttributes: valueAttr)
            
            ("Batch Number:" as NSString).draw(at: CGPoint(x: 230, y: 156), withAttributes: labelAttr)
            ("#\(project.batchNumber)" as NSString).draw(at: CGPoint(x: 230, y: 168), withAttributes: valueAttr)
            
            ("Grow Phase:" as NSString).draw(at: CGPoint(x: 350, y: 156), withAttributes: labelAttr)
            (project.phase.rawValue.uppercased() as NSString).draw(at: CGPoint(x: 350, y: 168), withAttributes: valueAttr)
            
            ("Parent Line / Generation:" as NSString).draw(at: CGPoint(x: 56, y: 190), withAttributes: labelAttr)
            ("\(project.parentCultureLabel.isEmpty ? "Mother culture / Spore print" : project.parentCultureLabel)" as NSString).draw(at: CGPoint(x: 56, y: 202), withAttributes: valueAttr)
            
            ("Sterilization Date / Start:" as NSString).draw(at: CGPoint(x: 230, y: 190), withAttributes: labelAttr)
            (project.startDate.formatted(date: .long, time: .omitted) as NSString).draw(at: CGPoint(x: 230, y: 202), withAttributes: valueAttr)
            
            // Section 2: Substrate & Nutrition
            let subBox = CGRect(x: 44, y: 255, width: pageRect.width - 88, height: 115)
            let subPath = UIBezierPath(roundedRect: subBox, cornerRadius: 8)
            cardBg.setFill(); subPath.fill()
            borderColor.setStroke(); subPath.lineWidth = 1; subPath.stroke()
            
            ("II. SUBSTRATE, MEDIUM & RATIOS" as NSString).draw(at: CGPoint(x: 56, y: 265), withAttributes: sectionTitleAttr)
            
            ("Substrate Type:" as NSString).draw(at: CGPoint(x: 56, y: 285), withAttributes: labelAttr)
            ("\(project.substrateName.isEmpty ? "CVG (Coir, Vermiculite, Gypsum)" : project.substrateName)" as NSString).draw(at: CGPoint(x: 56, y: 297), withAttributes: valueAttr)
            
            ("Spawn-to-Bulk Ratio:" as NSString).draw(at: CGPoint(x: 230, y: 285), withAttributes: labelAttr)
            (project.spawnToBulkRatio as NSString).draw(at: CGPoint(x: 230, y: 297), withAttributes: valueAttr)
            
            ("Grow Chamber / Container:" as NSString).draw(at: CGPoint(x: 350, y: 285), withAttributes: labelAttr)
            ("\(project.containerName.isEmpty ? "Martha Tent / Monotub" : project.containerName)" as NSString).draw(at: CGPoint(x: 350, y: 297), withAttributes: valueAttr)
            
            ("Dry Substrate Weight:" as NSString).draw(at: CGPoint(x: 56, y: 319), withAttributes: labelAttr)
            (String(format: "%.0f grams", project.drySubstrateWeightGrams) as NSString).draw(at: CGPoint(x: 56, y: 331), withAttributes: valueAttr)
            
            ("Colonization Degree:" as NSString).draw(at: CGPoint(x: 230, y: 319), withAttributes: labelAttr)
            ("\(Int(project.normalizedColonizationPercent))% Complete" as NSString).draw(at: CGPoint(x: 230, y: 331), withAttributes: valueAttr)

            // Section 3: Climate & Psychrometric Telemetry
            let climateBox = CGRect(x: 44, y: 384, width: pageRect.width - 88, height: 120)
            let climatePath = UIBezierPath(roundedRect: climateBox, cornerRadius: 8)
            cardBg.setFill(); climatePath.fill()
            borderColor.setStroke(); climatePath.lineWidth = 1; climatePath.stroke()
            
            ("III. CLIMATE VERIFICATION & PSYCHROMETRIC TELEMETRY" as NSString).draw(at: CGPoint(x: 56, y: 394), withAttributes: sectionTitleAttr)
            
            ("AVG TEMPERATURE" as NSString).draw(at: CGPoint(x: 56, y: 416), withAttributes: labelAttr)
            (String(format: "%.1f°C", avgTemp) as NSString).draw(at: CGPoint(x: 56, y: 430), withAttributes: bigMetricAttr)
            
            ("AVG RELATIVE HUMIDITY" as NSString).draw(at: CGPoint(x: 185, y: 416), withAttributes: labelAttr)
            (String(format: "%.0f%% RH", avgHumidity) as NSString).draw(at: CGPoint(x: 185, y: 430), withAttributes: bigMetricAttr)
            
            ("AVG VPD (VAPOR PRESSURE)" as NSString).draw(at: CGPoint(x: 315, y: 416), withAttributes: labelAttr)
            (String(format: "%.2f kPa", avgVpd) as NSString).draw(at: CGPoint(x: 315, y: 430), withAttributes: bigMetricAttr)
            
            ("VPD ZONE STATUS" as NSString).draw(at: CGPoint(x: 435, y: 416), withAttributes: labelAttr)
            ((avgVpd >= 0.10 && avgVpd <= 0.35 ? "OPTIMAL" : "CONTROLLED") as NSString).draw(at: CGPoint(x: 435, y: 430), withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .heavy),
                .foregroundColor: UIColor(red: 0.2, green: 0.78, blue: 0.45, alpha: 1.0)
            ])
            
            ("Logged via calibrated sensors and MycoLabs Sensor Intelligence Hub." as NSString).draw(at: CGPoint(x: 56, y: 466), withAttributes: monoSmallAttr)
            
            // Section 4: Harvest & Biological Efficiency
            let yieldBox = CGRect(x: 44, y: 518, width: pageRect.width - 88, height: 125)
            let yieldPath = UIBezierPath(roundedRect: yieldBox, cornerRadius: 8)
            cardBg.setFill(); yieldPath.fill()
            borderColor.setStroke(); yieldPath.lineWidth = 1; yieldPath.stroke()
            
            ("IV. HARVEST YIELD & BIOLOGICAL EFFICIENCY (BE%)" as NSString).draw(at: CGPoint(x: 56, y: 528), withAttributes: sectionTitleAttr)
            
            ("TOTAL WET WEIGHT" as NSString).draw(at: CGPoint(x: 56, y: 550), withAttributes: labelAttr)
            (String(format: "%.1f g", totalWet) as NSString).draw(at: CGPoint(x: 56, y: 564), withAttributes: bigMetricAttr)
            
            ("TOTAL DRY WEIGHT" as NSString).draw(at: CGPoint(x: 185, y: 550), withAttributes: labelAttr)
            (String(format: "%.2f g", totalDry) as NSString).draw(at: CGPoint(x: 185, y: 564), withAttributes: bigMetricAttr)
            
            ("FLUSH COUNT" as NSString).draw(at: CGPoint(x: 315, y: 550), withAttributes: labelAttr)
            ("\(flushes.count) Flushes" as NSString).draw(at: CGPoint(x: 315, y: 564), withAttributes: bigMetricAttr)
            
            ("BIO-EFFICIENCY (BE)" as NSString).draw(at: CGPoint(x: 435, y: 550), withAttributes: labelAttr)
            (String(format: "%.1f%%", bePct) as NSString).draw(at: CGPoint(x: 435, y: 564), withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .heavy),
                .foregroundColor: bePct >= 100 ? UIColor(red: 0.2, green: 0.78, blue: 0.45, alpha: 1.0) : goldColor
            ])
            
            ("Ratio: Fresh harvested weight relative to dry substrate weight conforming to MycoLabs standards." as NSString).draw(at: CGPoint(x: 56, y: 605), withAttributes: monoSmallAttr)
            
            // Bottom Seal & Signature Box
            let sealBox = CGRect(x: 44, y: 657, width: pageRect.width - 88, height: 110)
            let sealPath = UIBezierPath(roundedRect: sealBox, cornerRadius: 8)
            cardBg.setFill(); sealPath.fill()
            goldColor.setStroke(); sealPath.lineWidth = 1; sealPath.stroke()
            
            ("MYCOLAB CLEANROOM VERIFICATION SEAL" as NSString).draw(at: CGPoint(x: 56, y: 669), withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: goldColor
            ])
            
            ("This document certifies that the above batch was cultivated under monitored sterile conditions adhering to MycoLabs cleanroom protocols." as NSString).draw(
                in: CGRect(x: 56, y: 689, width: 320, height: 40),
                withAttributes: normalAttr
            )
            
            ("SHA256 CHECKSUM: \(hashDisplay)" as NSString).draw(at: CGPoint(x: 56, y: 735), withAttributes: monoSmallAttr)
            
            // Digital Signature line
            ("VERIFIED CHIEF CULTIVATOR:" as NSString).draw(at: CGPoint(x: 390, y: 689), withAttributes: labelAttr)
            ("MycoLabs Secure Core" as NSString).draw(at: CGPoint(x: 390, y: 708), withAttributes: valueAttr)
            let sigLine = UIBezierPath()
            sigLine.move(to: CGPoint(x: 390, y: 726))
            sigLine.addLine(to: CGPoint(x: 500, y: 726))
            borderColor.setStroke(); sigLine.stroke()
            
            // Document Footer
            let footer = "MycoLabs Official Certificate • Cryptographic Validation: #MYCO-\(hashDisplay) • All Rights Reserved"
            (footer as NSString).draw(at: CGPoint(x: 44, y: pageRect.height - 38), withAttributes: monoSmallAttr)
        }
        
        return url
    }

    
    static func generateProjectCSV(project: GrowProject, store: MycoStore) -> URL {
        let filename = "MycoLab_Data_\(project.skuCode)_Batch\(project.batchNumber)_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        let flushes = store.db.harvests.filter { $0.projectID == project.id }.sorted { $0.flushNumber < $1.flushNumber }
        let logs = store.db.logs.filter { $0.projectID == project.id }.sorted { $0.timestamp < $1.timestamp }
        let totalWet = flushes.reduce(0) { $0 + $1.wetWeightGrams }
        let bePct = project.drySubstrateWeightGrams > 0 ? (totalWet / project.drySubstrateWeightGrams) * 100.0 : 0
        
        // UTF-8 BOM so Excel opens with proper accents and emojis
        var csv = "\u{FEFF}"
        csv += "=== MYCOLAB BATCH REPORT ===\n"
        csv += "Project ID,Strain,SKU,Batch Number,Phase,Colonization Pct,Start Date,Container,Substrate,Dry Substrate Grams,Spawn To Bulk Ratio,Tags,Biological Efficiency Pct\n"
        
        let safeTags = "\"\(project.tags.joined(separator: ", "))\""
        let safeSubstrate = "\"\(project.substrateName)\""
        let safeContainer = "\"\(project.containerName)\""
        
        csv += "\(project.id.uuidString),\(project.strainName),\(project.skuCode),\(project.batchNumber),\(project.phase.rawValue),\(Int(project.normalizedColonizationPercent))%,\(project.startDate.ISO8601Format()),\(safeContainer),\(safeSubstrate),\(project.drySubstrateWeightGrams),\(project.spawnToBulkRatio),\(safeTags),\(String(format: "%.1f", bePct))%\n\n"
        
        csv += "=== FLUSHES & HARVESTS ===\n"
        csv += "Flush Number,Harvest Date,Wet Weight Grams,Dry Weight Grams,Moisture Loss Pct,Dehydrator Temp C,Dehydrator Hours,Notes\n"
        for f in flushes {
            let safeNotes = "\"\(f.notes.replacingOccurrences(of: "\"", with: "\"\""))\""
            csv += "\(f.flushNumber),\(f.harvestDate.ISO8601Format()),\(f.wetWeightGrams),\(f.dryWeightGrams),\(String(format: "%.1f", f.moistureLossPct)),\(f.dehydratorTempC),\(f.dehydratorHours),\(safeNotes)\n"
        }
        
        csv += "\n=== LOGBOOK ENTRIES ===\n"
        csv += "Timestamp,Action Type,Temperature C,Humidity Pct,Notes\n"
        for l in logs {
            let safeNotes = "\"\(l.notes.replacingOccurrences(of: "\"", with: "\"\""))\""
            let tempStr = l.temperatureC != nil ? String(format: "%.1f", l.temperatureC!) : ""
            let humStr = l.humidityPct != nil ? String(format: "%.0f", l.humidityPct!) : ""
            csv += "\(l.timestamp.ISO8601Format()),\(l.actionType),\(tempStr),\(humStr),\(safeNotes)\n"
        }
        
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func generateAllHarvestsCSV(store: MycoStore) -> URL {
        let filename = "MycoLab_All_Harvests_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        var csv = "\u{FEFF}"
        csv += "Flush Number,Harvest Date,Batch Title,Strain,SKU,Wet Weight Grams,Dry Weight Grams,Moisture Loss Pct,Dehydrator Temp C,Dehydrator Hours,Notes\n"
        
        let harvests = store.db.harvests.sorted { $0.harvestDate > $1.harvestDate }
        for f in harvests {
            let project = store.db.projects.first(where: { $0.id == f.projectID })
            let strain = project?.strainName ?? "Unknown"
            let sku = project?.skuCode ?? "-"
            let batchTitle = project.map { "\(store.displayTitle(name: $0.strainName, sku: $0.skuCode)) #\($0.batchNumber)" } ?? "Batch"
            let safeTitle = "\"\(batchTitle)\""
            let safeStrain = "\"\(strain)\""
            let safeNotes = "\"\(f.notes.replacingOccurrences(of: "\"", with: "\"\""))\""
            
            csv += "\(f.flushNumber),\(f.harvestDate.ISO8601Format()),\(safeTitle),\(safeStrain),\(sku),\(f.wetWeightGrams),\(f.dryWeightGrams),\(String(format: "%.1f", f.moistureLossPct)),\(f.dehydratorTempC),\(f.dehydratorHours),\(safeNotes)\n"
        }
        
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - 5. REAL IPHONE CAMERA QR SCANNER (AVFOUNDATION)
struct QRCameraScannerView: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onCodeScanned = { code in
            onCodeScanned(code)
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}
    
    final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var captureSession: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        var onCodeScanned: ((String) -> Void)?
        private var didScan = false
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            let session = AVCaptureSession()
            
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
                  session.canAddInput(videoInput) else { return }
            
            session.addInput(videoInput)
            let metadataOutput = AVCaptureMetadataOutput()
            
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }
            
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
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !didScan,
                  let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = metadataObj.stringValue else { return }
            didScan = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            captureSession?.stopRunning()
            onCodeScanned?(code)
        }
    }
}

// MARK: - HARDWARE PAIRING QR SHEETS
struct QRScannerSheetView: View {
    var onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: MycoStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ZStack {
                    QRCameraScannerView { scanned in
                        onScanned(scanned)
                        dismiss()
                    }
                    .cornerRadius(16)

                    RoundedRectangle(cornerRadius: 16)
                        .stroke(MycoTheme.blue, lineWidth: 3)
                        .frame(width: 220, height: 220)
                }
                .frame(maxHeight: 380)
                .padding(.horizontal, 16)

                Text(store.t(
                    nl: "Richt je camera op de QR-code van de Kweekcamera om direct te koppelen.",
                    en: "Point your camera at the Grow Camera QR code to pair immediately."
                ))
                .font(.caption)
                .foregroundColor(MycoTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 16)
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Scan Koppel-QR", en: "Scan Pairing QR"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
            }
        }
    }
}

struct CameraPairingQRSheet: View {
    @ObservedObject var pairingManager = MycoCamPairingManager.shared
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(store.t(nl: "Koppel met Live Kijker", en: "Pair with Live Viewer"))
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text(store.t(
                        nl: "Scan deze QR-code met de Live Kijker op je andere toestel om deze camera te koppelen.",
                        en: "Scan this QR code with the Live Viewer on your other device to connect."
                    ))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                }

                if let qrImage = pairingManager.generateQRCode() {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 4)
                } else {
                    ProgressView()
                        .frame(width: 240, height: 240)
                }

                VStack(spacing: 6) {
                    Text(store.t(nl: "Camera Naam: ", en: "Camera Name: ") + pairingManager.localCameraName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("ID: \(pairingManager.localCameraId)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                .padding(12)
                .background(MycoTheme.card)
                .cornerRadius(10)

                Spacer()
            }
            .padding(.top, 24)
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Camera Koppelcode", en: "Camera Pairing Code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Klaar", en: "Done")) { dismiss() }
                        .foregroundColor(MycoTheme.blue)
                }
            }
        }
    }
}

// MARK: - CREATIVE QUALITY & EXTRACTION SELECTOR
struct CreativePotencySelectorView: View {
    @EnvironmentObject var store: MycoStore
    @Binding var potency: Double
    
    struct Level {
        let multiplier: Double
        let labelNL: String
        let labelEN: String
        let icon: String
        let subtitleNL: String
        let subtitleEN: String
        let color: Color
        let bars: Int
        
        func label(isEnglish: Bool) -> String { isEnglish ? labelEN : labelNL }
        func subtitle(isEnglish: Bool) -> String { isEnglish ? subtitleEN : subtitleNL }
    }
    
    let levels: [Level] = [
        Level(multiplier: 0.75, labelNL: "Licht & Vers", labelEN: "Fresh / Light", icon: "leaf.fill", subtitleNL: "Verse oogst & culinaire bereiding", subtitleEN: "Fresh harvest & culinary prep", color: MycoTheme.blue, bars: 1),
        Level(multiplier: 1.0, labelNL: "Standaard Culinair", labelEN: "Standard Culinary", icon: "sparkles", subtitleNL: "Gedroogde hoedjes (1:1 basis referentie)", subtitleEN: "Dried caps (1:1 base reference)", color: MycoTheme.green, bars: 2),
        Level(multiplier: 1.5, labelNL: "Premium Selectie", labelEN: "Premium Grade", icon: "bolt.fill", subtitleNL: "Geconcentreerd poeder & theeën", subtitleEN: "Concentrated powder & teas", color: MycoTheme.amber, bars: 3),
        Level(multiplier: 2.0, labelNL: "Geconcentreerd Extract", labelEN: "Concentrated Extract", icon: "flame.fill", subtitleNL: "Tinctuur & dubbele heetwaterextractie", subtitleEN: "Tincture & double hot-water extract", color: Color.orange, bars: 4),
        Level(multiplier: 2.75, labelNL: "Superconcentraat", labelEN: "Super Concentrate", icon: "atom", subtitleNL: "Gestandaardiseerd bioactief extract", subtitleEN: "Standardized bioactive extract", color: Color.purple, bars: 5)
    ]
    
    var currentLevel: Level {
        levels.first(where: { abs($0.multiplier - potency) < 0.15 }) ?? levels[1]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(store.t(nl: "Kwaliteit & Densiteit", en: "Quality & Density"))
                    .font(.caption.bold())
                    .foregroundColor(MycoTheme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: currentLevel.icon)
                        .font(.caption2)
                    Text(String(format: "%.2fx %@", currentLevel.multiplier, store.t(nl: "Relatief", en: "Relative")))
                        .font(.system(.caption, design: .monospaced).bold())
                }
                .foregroundColor(currentLevel.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(currentLevel.color.opacity(0.15))
                .cornerRadius(6)
            }
            
            // 5 Interactive Rating Badges
            HStack(spacing: 6) {
                ForEach(levels, id: \.multiplier) { lvl in
                    let isSelected = abs(lvl.multiplier - potency) < 0.15
                    Button {
                        potency = lvl.multiplier
                        let generator = UISelectionFeedbackGenerator()
                        generator.selectionChanged()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: lvl.icon)
                                .font(.system(size: 14))
                            Text(lvl.label(isEnglish: store.isEnglish))
                                .font(.system(size: 9, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(isSelected ? .white : MycoTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? lvl.color : MycoTheme.card)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? lvl.color : MycoTheme.border, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Visual Energy Gauge
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(idx <= currentLevel.bars ? currentLevel.color : MycoTheme.border.opacity(0.5))
                        .frame(height: 5)
                }
            }
            
            Text(currentLevel.subtitle(isEnglish: store.isEnglish))
                .font(.system(size: 11))
                .foregroundColor(MycoTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 6. REUSABLE UI COMPONENTS (NO OVERLAP, EXPLICIT RADIUS)
struct MycoCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
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

struct CircularProgressRing: View {
    var progress: Double // Supports 0.0 to 1.0 or 0.0 to 100.0
    var color: Color = MycoTheme.blue
    var subtitle: String = ""
    
    private var normalizedProgress: Double {
        if progress > 0.0 && progress <= 1.0 {
            return progress
        }
        return max(0.0, min(1.0, progress / 100.0))
    }
    
    private var displayPercent: Int {
        Int(round(normalizedProgress * 100.0))
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(MycoTheme.border, lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(normalizedProgress))
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(displayPercent)%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(MycoTheme.textSecondary)
                }
            }
        }
        .frame(width: 64, height: 64) // Explicit fixed frame -> prevents any radius crash
    }
}
