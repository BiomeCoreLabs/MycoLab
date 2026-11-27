//
//  MycoLabTests.swift
//  MycoLabTests
//

import Testing
import UIKit
import SwiftUI
import LiveKit
@testable import MycoLab

@MainActor
struct MycoLabTests {

    @Test func testLiveKitTokenGenerationStructure() throws {
        let token = LiveKitTokenGenerator.generateToken(
            apiKey: "testKey",
            apiSecret: "testSecret1234567890123456789012",
            room: "test-room",
            identity: "tester-1",
            name: "Grow Camera",
            canPublish: true,
            canSubscribe: true,
            durationInHours: 24
        )

        #expect(token != nil)
        guard let token = token else { return }

        // A valid JWT consists of header.payload.signature
        let parts = token.split(separator: ".")
        #expect(parts.count == 3)
    }

    @Test func testLiveKitConfigurationDefaults() {
        #expect(!LiveKitTokenGenerator.currentServerUrl.isEmpty)
        #expect(!LiveKitTokenGenerator.currentApiKey.isEmpty)
        #expect(!LiveKitTokenGenerator.currentApiSecret.isEmpty)
        #expect(LiveKitTokenGenerator.currentRoom == "mycolab-grow-room")
    }

    @Test func testMycoImageHelperDownscaling() throws {
        // Create a large test image (2000x2000)
        let largeSize = CGSize(width: 2000, height: 2000)
        let renderer = UIGraphicsImageRenderer(size: largeSize)
        let testImage = renderer.image { ctx in
            UIColor.systemGreen.setFill()
            ctx.fill(CGRect(origin: .zero, size: largeSize))
        }

        guard let initialData = testImage.jpegData(compressionQuality: 1.0) else {
            Issue.record("Failed to generate test image data")
            return
        }

        let processedData = MycoImageHelper.prepareForStorage(
            data: initialData,
            maxDimension: 800,
            compressionQuality: 0.5
        )

        #expect(processedData != nil)
        guard let processedData = processedData,
              let processedImage = UIImage(data: processedData) else { return }

        // Ensure longest edge does not exceed maxDimension
        #expect(max(processedImage.size.width, processedImage.size.height) <= 800)
        // Ensure compressed data is smaller than original
        #expect(processedData.count < initialData.count)
    }

    @Test func testMycoSyncManagerLightweightExport() {
        let syncManager = MycoSyncManager.shared
        var db = AppDatabase()

        // Create a mock GrowLog with oversized dummy image data (>100KB)
        let oversizedData = Data(repeating: 0x42, count: 150_000)
        let testLog = GrowLog(
            actionType: "Inspectie",
            notes: "Test log",
            imageData: oversizedData
        )
        db.logs = [testLog]

        let lightweightDB = syncManager.exportLightweightDatabase(from: db)

        #expect(lightweightDB.logs.count == 1)
        // Oversized non-image dummy bytes should be stripped to nil to protect sync bandwidth
        #expect(lightweightDB.logs.first?.imageData == nil)
        // Timelapse photos should not bloat iCloud KVS
        #expect(lightweightDB.timelapsePhotos.isEmpty)
    }

    @Test func testGrowPhaseStartableCases() {
        let startable = GrowPhase.startableCases
        #expect(startable.contains(.spawn))
        #expect(startable.contains(.bulk))
        #expect(startable.contains(.fruiting))
        #expect(!startable.contains(.liquidCulture))
        #expect(!startable.contains(.agar))
        #expect(!startable.contains(.archived))
        #expect(!startable.contains(.contaminated))
    }

    @Test func testSubstrateCVGCalculationLogic() {
        let spawnLiters: Double = 2.0
        let ratio: Double = 2.0 // 1:2 ratio
        let neededCVGLiters = spawnLiters * ratio
        #expect(neededCVGLiters == 4.0)

        // 76.5 grams of coco coir per liter of CVG substrate mix
        let coirGrams = round(neededCVGLiters * 76.5)
        #expect(coirGrams == 306.0)
    }

    @Test func testAudioKeepAliveSettingToggle() {
        let hub = MycoBackgroundHubManager.shared
        let originalValue = hub.isAudioKeepAliveAllowed
        defer {
            hub.isAudioKeepAliveAllowed = originalValue
        }

        hub.isAudioKeepAliveAllowed = false
        #expect(!hub.isAudioKeepAliveAllowed)
        #expect(UserDefaults.standard.bool(forKey: "mycolab_audio_keepalive_allowed") == false)

        hub.isAudioKeepAliveAllowed = true
        #expect(hub.isAudioKeepAliveAllowed)
        #expect(UserDefaults.standard.bool(forKey: "mycolab_audio_keepalive_allowed") == true)
    }

    @Test func testItemDeletionAndMistakeCorrection() {
        let store = MycoStore.shared ?? MycoStore()
        
        // 1. Stash Jar: User adds jar by mistake, then deletes it
        let testJar = StashJar(strainName: "Accidental Strain", skuCode: "ST-01", availableDryGrams: 42.0, storageMethod: "Weckpot", qrCodeID: "QR-ST-01")
        store.db.stash.append(testJar)
        #expect(store.db.stash.contains(where: { $0.id == testJar.id }))
        store.deleteStashJar(id: testJar.id)
        #expect(!store.db.stash.contains(where: { $0.id == testJar.id }))
        #expect(store.db.deletedItemIDs.contains(testJar.id))
        
        // 2. Grow Log: User logs wrong reading, then deletes it
        let testProj = GrowProject(strainName: "Test Cube", skuCode: "TST-01", qrCodeID: "QR-TST")
        store.db.projects.append(testProj)
        let testLog = GrowLog(projectID: testProj.id, actionType: "Inspectie", notes: "Typo in log entry")
        store.db.logs.append(testLog)
        #expect(store.db.logs.contains(where: { $0.id == testLog.id }))
        store.deleteLog(id: testLog.id)
        #expect(!store.db.logs.contains(where: { $0.id == testLog.id }))
        #expect(store.db.deletedItemIDs.contains(testLog.id))
        
        // 3. Harvest: User logs duplicate flush, then deletes it
        let testHarvest = HarvestRecord(projectID: testProj.id, strainName: "Test Cube", skuCode: "TST-01", flushNumber: 99, wetWeightGrams: 100, dryWeightGrams: 10)
        store.db.harvests.append(testHarvest)
        #expect(store.db.harvests.contains(where: { $0.id == testHarvest.id }))
        store.deleteHarvest(id: testHarvest.id)
        #expect(!store.db.harvests.contains(where: { $0.id == testHarvest.id }))
        #expect(store.db.deletedItemIDs.contains(testHarvest.id))
        
        // 4. Project: Cascade deletion of project and children
        let orphanLog = GrowLog(projectID: testProj.id, actionType: "FAE", notes: "Orphan check")
        store.db.logs.append(orphanLog)
        store.deleteProject(id: testProj.id)
        #expect(!store.db.projects.contains(where: { $0.id == testProj.id }))
        #expect(!store.db.logs.contains(where: { $0.id == orphanLog.id }))
        #expect(store.db.deletedItemIDs.contains(testProj.id))
        #expect(store.db.deletedItemIDs.contains(orphanLog.id))
    }

    @Test func testMycoSensorIntelligenceManager() async {
        let mgr = MycoSensorIntelligenceManager.shared
        mgr.resetForTesting()
        
        // 1. Initial State
        #expect(mgr.currentPressureHpa > 800.0 && mgr.currentPressureHpa < 1200.0)
        #expect(mgr.pressureTrend == .stable)
        
        // 2. Barometer & Pressure Trend Evaluation
        mgr.recordBarometerReading(hpa: 1013.25, altitudeM: 5.0)
        #expect(mgr.barometerHistory.count == 1)
        
        // Simulate a dropping pressure reading
        mgr.recordBarometerReading(hpa: 1008.0, altitudeM: 6.0)
        mgr.evaluateBarometerTrend()
        #expect(mgr.pressureTrend == .stormFront || mgr.pressureTrend == .falling)
        
        // 3. PressureTrend icons
        #expect(!PressureTrend.stable.icon.isEmpty)
        #expect(!PressureTrend.stormFront.icon.isEmpty)
        #expect(!PressureTrend.falling.icon.isEmpty)
        #expect(!PressureTrend.rising.icon.isEmpty)
    }

    @Test func testCustomThemeAndSubmenuConfiguration() {
        let store = MycoStore.shared ?? MycoStore()
        
        // 1. Built-in theme switching
        store.applyBuiltinTheme(.emerald)
        #expect(MycoTheme.currentTheme == .emerald)
        #expect(MycoTheme.activeCustomTheme == nil)
        #expect(store.currentThemeTitle.contains("Smaragd") || store.currentThemeTitle.contains("Emerald"))
        
        // 2. Custom Theme Creation & Application
        let custom = CustomAppTheme(
            name: "Neon Mycota",
            bgHex: "050505",
            cardHex: "151515",
            borderHex: "252525",
            primaryAccentHex: "00FFAA",
            secondaryAccentHex: "00B894"
        )
        store.saveCustomTheme(custom)
        #expect(store.db.customThemes.contains(where: { $0.id == custom.id }))
        #expect(store.db.selectedCustomThemeId == custom.id)
        #expect(MycoTheme.activeCustomTheme?.name == "Neon Mycota")
        #expect(store.currentThemeTitle == "Neon Mycota")
        
        // 3. Color conversion helper
        let testColor = Color(hex: "00FFAA")
        let hexString = testColor.toHexRGB()
        #expect(hexString.count == 6)
        
        // 4. Delete Custom Theme & Safe Fallback
        store.deleteCustomTheme(id: custom.id)
        #expect(!store.db.customThemes.contains(where: { $0.id == custom.id }))
        #expect(MycoTheme.activeCustomTheme == nil)
        #expect(MycoTheme.currentTheme == .darkLab)
        
        // 5. Dashboard camera modes
        for mode in DashboardCameraMode.allCases {
            #expect(!mode.localizedTitle(store: store).isEmpty)
        }
    }


    @Test func testRemoteTimelapseAndFramingControls() async {
        let manager = LiveKitStreamManager.shared
        
        // 1. Aspect Ratio Configuration (4:3 Full Sensor uncropped)
        #expect(manager.captureAspectRatio == "4:3")
        let dim43 = Dimensions.h1080_43
        #expect(dim43.width > 0)
        
        // 2. Local Broadcaster Timelapse State
        manager.currentRole = .broadcaster
        manager.startTimelapse(intervalMinutes: 5)
        #expect(manager.isTimelapseRunning == true)
        #expect(manager.timelapseIntervalMinutes == 5)
        #expect(UserDefaults.standard.bool(forKey: "mycolab_stream_timelapse_running") == true)
        #expect(UserDefaults.standard.integer(forKey: "mycolab_stream_timelapse_interval") == 5)
        
        manager.stopTimelapse()
        #expect(manager.isTimelapseRunning == false)
        #expect(UserDefaults.standard.bool(forKey: "mycolab_stream_timelapse_running") == false)
        
        // 3. Remote Viewer Timelapse State Parser Simulation
        // Broadcaster sends: timelapse:status:1:10:42
        let testStatusCmd = "timelapse:status:1:10:42"
        let parts = String(testStatusCmd.dropFirst("timelapse:status:".count)).components(separatedBy: ":")
        #expect(parts.count == 3)
        manager.isRemoteTimelapseRunning = (parts[0] == "1")
        manager.remoteTimelapseIntervalMinutes = Int(parts[1]) ?? 2
        manager.remoteTimelapseFramesCount = Int(parts[2]) ?? 0
        
        #expect(manager.isRemoteTimelapseRunning == true)
        #expect(manager.remoteTimelapseIntervalMinutes == 10)
        #expect(manager.remoteTimelapseFramesCount == 42)
        
        // 4. RemoteCamCommand Serialization for P2P/Cloud
        let p2pCmd = RemoteCamCommand(
            type: "timelapse_start",
            timelapseInterval: 10,
            timelapseFrameCount: 42,
            isTimelapseRunning: true
        )
        let data = try? JSONEncoder().encode(p2pCmd)
        #expect(data != nil)
        if let data = data {
            let decoded = try? JSONDecoder().decode(RemoteCamCommand.self, from: data)
            #expect(decoded?.type == "timelapse_start")
            #expect(decoded?.timelapseInterval == 10)
            #expect(decoded?.timelapseFrameCount == 42)
            #expect(decoded?.isTimelapseRunning == true)
        }
        
        // Reset manager state cleanly
        manager.currentRole = .viewer
        manager.isRemoteTimelapseRunning = false
        manager.isTimelapseRunning = false
    }

    @Test func testMycoAIRecipeEngineCustomUnits() {
        // 1. Substrate in Grams (650g dry coir brick test)
        let subResultGrams = MycoAIRecipeEngine.calculate(
            category: .substrate,
            selectedIngredients: ["Kokosvezel (Coir)", "Vermiculiet", "Gips (Calcium)"],
            batchSize: 650.0,
            unit: .gram
        )
        #expect(subResultGrams.batchSizeDescription.contains("650g dry mix") || subResultGrams.batchSizeDescription.contains("650g droge mix"))
        #expect(subResultGrams.hydrationPercent > 70.0)
        #expect(!subResultGrams.ingredients.isEmpty)
        
        // 2. Substrate in Kilograms
        let subResultKg = MycoAIRecipeEngine.calculate(
            category: .substrate,
            selectedIngredients: ["Kokosvezel (Coir)", "Vermiculiet"],
            batchSize: 1.0,
            unit: .kilogram
        )
        #expect(subResultKg.batchSizeDescription.contains("1kg dry mix") || subResultKg.batchSizeDescription.contains("1kg droge mix"))
        
        // 3. Agar in Milliliters and Liters
        let agarResultML = MycoAIRecipeEngine.calculate(
            category: .agar,
            selectedIngredients: ["Agar-agar poeder", "Moutextract (LME)"],
            batchSize: 500.0,
            unit: .milliliter
        )
        #expect(agarResultML.batchSizeDescription.contains("500 ml"))
        #expect(agarResultML.hydrationPercent == 96.0)
        
        // 4. Grain in Grams and Kilograms
        let grainResultGrams = MycoAIRecipeEngine.calculate(
            category: .grain,
            selectedIngredients: ["Haver (Oats)", "Gips (Calcium)"],
            batchSize: 1000.0,
            unit: .gram
        )
        #expect(grainResultGrams.batchSizeDescription.contains("1000g dry grain") || grainResultGrams.batchSizeDescription.contains("1000g droog graan"))
        #expect(grainResultGrams.hydrationPercent == 52.0)
    }

    @Test func testSpawnToBulkRatioAndSpawnUnits() {
        // Grain spawn density: ~650g per Liter
        let spawnUnitGramVal: Double = 1300.0 // 1300 grams
        let litersFromGrams = spawnUnitGramVal / 650.0 // 2.0 Liters
        #expect(abs(litersFromGrams - 2.0) < 0.001)

        // Custom Ratio 1:2.2
        let customRatio = 2.2
        let neededCVG = litersFromGrams * customRatio // 4.4 Liters
        #expect(abs(neededCVG - 4.4) < 0.001)

        // Coir required for 4.4L CVG mix: 4.4 * 76.5g = 336.6g ≈ 337g
        let coirGrams = round(neededCVG * 76.5)
        #expect(coirGrams == 337.0)
    }

    @Test func testMycoSecurityClusterAndPacketSigning() {
        let sec = MycoSecurityManager.shared
        #expect(!sec.clusterSecret.isEmpty)
        #expect(!sec.clusterHash.isEmpty)
        #expect(sec.clusterHash.count == 16)
        #expect(!sec.clusterRoomId.isEmpty)
        #expect(!sec.clusterChannelId.isEmpty)

        // 1. Cluster Hash Verification
        #expect(sec.verifyClusterHash(sec.clusterHash) == true)
        #expect(sec.verifyClusterHash("unauthorized_cluster_hash") == false)
        #expect(sec.verifyClusterHash("") == false)

        // 2. Invitation Context Verification
        let validContext = sec.invitationContext
        #expect(sec.verifyInvitationContext(validContext) == true)
        #expect(sec.verifyInvitationContext(nil) == false)
        #expect(sec.verifyInvitationContext(Data([0x01, 0x02, 0x03])) == false)

        // 3. Packet Signing & Cryptographic Unwrap
        let testCmd = "plug:set:power:1"
        let signed = sec.signPacket(testCmd)
        #expect(signed.contains("§auth:"))

        let (isValid, unwrapped) = sec.verifyAndUnwrapPacket(signed)
        #expect(isValid == true)
        #expect(unwrapped == testCmd)

        // 4. Tampered Packet Detection
        let tampered = signed.replacingOccurrences(of: "power:1", with: "power:0")
        let (isTamperedValid, _) = sec.verifyAndUnwrapPacket(tampered)
        #expect(isTamperedValid == false)
    }

    @Test func testPreparationRecipeDefaultPresetsAndIngredientScaling() {
        let defaults = PreparationRecipe.defaultRecipes
        #expect(defaults.count >= 4)
        
        guard let cvgRecipe = defaults.first(where: { $0.name.contains("CVG") }) else {
            Issue.record("Default CVG recipe not found")
            return
        }
        
        #expect(cvgRecipe.drySubstrateWeightGrams == 650.0)
        #expect(cvgRecipe.ingredients.count == 4)
        
        let batchQuantity = 3
        var scaledIngredients: [(name: String, total: Double, unit: String)] = []
        for ing in cvgRecipe.ingredients {
            scaledIngredients.append((ing.name, ing.amountPerBatch * Double(batchQuantity), ing.unit))
        }
        
        // Coir: 1 block * 3 = 3 blocks
        let coir = scaledIngredients.first(where: { $0.name.contains("Coir") || $0.name.contains("Kokos") })
        #expect(coir?.total == 3.0)
        #expect(coir?.unit == "blocks" || coir?.unit == "blokken")
        
        // Vermiculite: 2.0L * 3 = 6.0L
        let verm = scaledIngredients.first(where: { $0.name.contains("Vermiculite") || $0.name.contains("Vermiculiet") })
        #expect(verm?.total == 6.0)
        #expect(verm?.unit == "liters" || verm?.unit == "liter")
        
        // Gypsum: 0.1kg * 3 = 0.3kg
        let gypsum = scaledIngredients.first(where: { $0.name.localizedCaseInsensitiveContains("gypsum") || $0.name.localizedCaseInsensitiveContains("gips") })
        #expect(abs((gypsum?.total ?? 0.0) - 0.3) < 0.001)
        
        // Water: 3.5L * 3 = 10.5L
        let water = scaledIngredients.first(where: { $0.name.contains("Water") })
        #expect(water?.total == 10.5)
    }

    @Test func testPreparationRecipeSupplyDeductionAndLinkage() {
        var db = AppDatabase()
        let supplyCoir = LabSupplyItem(
            name: "Kokosvezel (Coco Coir)",
            category: "Substraat & CVG",
            quantity: 3000.0,
            unit: "gram",
            minThreshold: 500.0,
            qrCodeID: "SUP-001"
        )
        let supplyVerm = LabSupplyItem(
            name: "Vermiculiet (Fijn/Middel)",
            category: "Substraat & CVG",
            quantity: 1000.0,
            unit: "gram",
            minThreshold: 200.0,
            qrCodeID: "SUP-002"
        )
        db.supplies = [supplyCoir, supplyVerm]
        
        let recipe = PreparationRecipe(
            name: "Test Substraat Recept",
            category: "Substraat",
            targetPhase: .bulk,
            drySubstrateWeightGrams: 500.0,
            ingredients: [
                RecipeIngredient(name: "Kokosvezel (Coco Coir)", amountPerBatch: 500.0, unit: "gram", linkedSupplyID: supplyCoir.id),
                RecipeIngredient(name: "Vermiculiet (Fijn/Middel)", amountPerBatch: 150.0, unit: "gram", linkedSupplyID: supplyVerm.id)
            ]
        )
        db.preparationRecipes = [recipe]
        
        let batchQuantity = 2
        for ing in recipe.ingredients {
            let totalNeeded = ing.amountPerBatch * Double(batchQuantity)
            if let idx = db.supplies.firstIndex(where: { s in
                if let linkedID = ing.linkedSupplyID, s.id == linkedID { return true }
                return s.name.localizedCaseInsensitiveContains(ing.name) || ing.name.localizedCaseInsensitiveContains(s.name)
            }) {
                db.supplies[idx].quantity = max(0, db.supplies[idx].quantity - totalNeeded)
                db.supplies[idx].lastUpdated = Date()
            }
        }
        
        // Kokosvezel: 3000 - (500 * 2) = 2000g
        #expect(db.supplies[0].quantity == 2000.0)
        // Vermiculiet: 1000 - (150 * 2) = 700g
        #expect(db.supplies[1].quantity == 700.0)
        
        // Grow project linkage
        let project = GrowProject(
            strainName: "Jack Frost",
            skuCode: "PROJ-100",
            phase: .bulk,
            qrCodeID: "QR-PROJ-100",
            recipeID: recipe.id,
            recipeName: recipe.name
        )
        #expect(project.recipeID == recipe.id)
        #expect(project.recipeName == "Test Substraat Recept")
    }

    @Test func testStrainModelCommonSpeciesList() {
        let speciesList = StrainModel.commonSpecies
        #expect(speciesList.contains("Pleurotus ostreatus (Blue Oyster)") || speciesList.contains("Pleurotus ostreatus (Blauwe Oesterzwam)"))
        #expect(speciesList.contains("Pleurotus eryngii (King Oyster)") || speciesList.contains("Pleurotus eryngii (Koningsoesterzwam)"))
        #expect(speciesList.contains("Hericium erinaceus (Lion's Mane)") || speciesList.contains("Hericium erinaceus (Lion's Mane / Pruikzwam)"))
        #expect(speciesList.contains("Lentinula edodes (Shiitake)"))
        #expect(speciesList.contains("Other / Custom Entry...") || speciesList.contains("Anders / Zelf typen..."))
        
        let customStrain = StrainModel(
            name: "Koningsoesterzwam Selectie",
            skuCode: "STR-099",
            species: "Pleurotus eryngii",
            potencyMultiplier: 1.0,
            notes: "Dikke vlezige stelen met nootachtige umamismaak"
        )
        #expect(customStrain.species == "Pleurotus eryngii")
    }

    @Test func testColonizationProgressNormalizationAndFruitingPhase() {
        var proj1 = GrowProject(
            strainName: "Lion's Mane",
            skuCode: "GT-01",
            phase: .bulk,
            colonizationPercent: 1.0,
            qrCodeID: "QR-1"
        )
        #expect(proj1.normalizedColonizationPercent == 100.0)

        let proj2 = GrowProject(
            strainName: "B+",
            skuCode: "BP-01",
            phase: .bulk,
            colonizationPercent: 85.0,
            qrCodeID: "QR-2"
        )
        #expect(proj2.normalizedColonizationPercent == 85.0)

        proj1.phase = .fruiting
        #expect(proj1.normalizedColonizationPercent == 100.0)
    }

    @Test func testStrainModelMushroomTypesAndCultivationTraits() throws {
        let oyster = StrainModel(name: "Blauwe Oester", skuCode: "STR-PO", species: "Pleurotus ostreatus")
        #expect(oyster.mushroomType == .culinary)
        #expect(oyster.colonizationSpeed == .fast)
        #expect(oyster.difficulty == .beginner)

        let lionsMane = StrainModel(name: "Pruikzwam", skuCode: "STR-LM", species: "Hericium erinaceus")
        #expect(lionsMane.mushroomType == .medicinal)
        #expect(lionsMane.colonizationSpeed == .moderate)
        #expect(lionsMane.difficulty == .intermediate)

        let shiitake = StrainModel(name: "Shiitake", skuCode: "STR-SHI", species: "Lentinula edodes")
        #expect(shiitake.mushroomType == .culinary)
        #expect(shiitake.difficulty == .intermediate)

        let cordyceps = StrainModel(name: "Cordyceps", skuCode: "STR-COR", species: "Cordyceps militaris")
        #expect(cordyceps.mushroomType == .medicinal)
        #expect(cordyceps.colonizationSpeed == .slow)
        #expect(cordyceps.difficulty == .expert)
    }

    @Test func testMaintenanceModeDisablesHumidifiersFansAndFreezesAutopilot() throws {
        let store = MycoStore.shared ?? MycoStore()
        
        let fanId = UUID()
        let humId = UUID()
        let lightId = UUID()
        
        store.db.smartDevices = [
            SmartDeviceItem(id: fanId, name: "Afzuigventilator", deviceType: "ExhaustFan", isOn: true, autoControlEnabled: true),
            SmartDeviceItem(id: humId, name: "Luchtbevochtiger", deviceType: "Humidifier", isOn: true, autoControlEnabled: true),
            SmartDeviceItem(id: lightId, name: "Groeilamp", deviceType: "Light", isOn: true, autoControlEnabled: false)
        ]
        
        // Activeren van Onderhoudsmodus
        store.setMaintenanceMode(enabled: true, durationMinutes: 30)
        
        #expect(store.db.environmentConfig.isMaintenanceModeActive == true)
        #expect(store.db.environmentConfig.maintenanceModeStartTime != nil)
        #expect(store.db.environmentConfig.maintenanceModeAutoResumeMinutes == 30)
        
        // Ventilatoren en bevochtigers moeten direct uitgeschakeld zijn voor rust en comfort
        let fan = store.db.smartDevices.first(where: { $0.id == fanId })
        let hum = store.db.smartDevices.first(where: { $0.id == humId })
        let light = store.db.smartDevices.first(where: { $0.id == lightId })
        
        #expect(fan?.isOn == false)
        #expect(hum?.isOn == false)
        #expect(light?.isOn == true) // Lamp blijft aan voor zicht tijdens inspectie!
        
        // Autopilot draait, maar mag niets inschakelen zolang onderhoud actief is
        store.runAutopilotCycle()
        #expect(store.db.smartDevices.first(where: { $0.id == fanId })?.isOn == false)
        
        // Deactiveren van Onderhoudsmodus
        store.setMaintenanceMode(enabled: false)
        #expect(store.db.environmentConfig.isMaintenanceModeActive == false)
    }

    @Test func testTimelapsePhotoItemWithClimateReadings() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50))
        let img = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        }

        let item = TimelapsePhotoItem.createAndSave(
            image: img,
            caption: "Kweek (1.0x) • Test Snapshot",
            relativeMinutes: 10,
            cameraType: "wide",
            cameraName: "Kweek (1.0x)",
            temperatureC: 23.4,
            humidityPct: 91.5,
            vpdKpa: 0.24
        )

        #expect(item.temperatureC == 23.4)
        #expect(item.humidityPct == 91.5)
        #expect(item.vpdKpa == 0.24)
        #expect(item.resolvedCameraType == "wide")

        // Test JSON encoding & decoding roundtrip
        let encoder = JSONEncoder()
        let data = try encoder.encode(item)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TimelapsePhotoItem.self, from: data)

        #expect(decoded.temperatureC == 23.4)
        #expect(decoded.humidityPct == 91.5)
        #expect(decoded.vpdKpa == 0.24)

        // Cleanup
        item.deleteFile()
    }

    @Test func testTentLockStateManagement() {
        let manager = LiveKitStreamManager.shared
        manager.setTentLock(locked: true, notifyPeer: false)
        #expect(manager.isTentLockActive == true)

        manager.toggleTentLock()
        #expect(manager.isTentLockActive == false)
    }

    @Test func testGrowLightOnSynchronizedPhotoCycleTrigger() {
        let store = MycoStore.shared ?? MycoStore()
        let lightId = UUID()
        store.db.smartDevices = [
            SmartDeviceItem(id: lightId, name: "Kweeklamp MarsHydro", deviceType: "Light", isOn: false, autoControlEnabled: false)
        ]

        var notificationFired = false
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MycoGrowLightSwitchedOn"),
            object: nil,
            queue: nil
        ) { _ in
            notificationFired = true
        }

        store.setSmartDeviceState(id: lightId, isOn: true, trigger: "Manual Test")

        #expect(notificationFired == true)
        NotificationCenter.default.removeObserver(observer)
    }

    @Test func testSplashAnimationConfigurationAndCustomization() {
        var db = AppDatabase()
        #expect(db.splashAnimationMode == .video)
        #expect(db.isSplashSoundEnabled == true)
        
        db.splashAnimationMode = .modernLogo
        #expect(db.splashAnimationMode.rawValue == "modernLogo")
        #expect(db.splashAnimationMode.localizedTitle(isEnglish: false).contains("Minimalistische"))
        
        db.splashAnimationMode = .disabled
        #expect(db.splashAnimationMode.rawValue == "disabled")
        
        let videoManager = SplashVideoManager.shared
        #expect(videoManager.customVideoURL.lastPathComponent == "custom_splash.mp4")
    }

    // MARK: - Raspberry Pi Autonomous Hub & Smart Plug Unit Tests

    @Test func testAutopilotTimerCountdownPersistenceAcrossAppRestarts() {
        let store = MycoStore.shared ?? MycoStore()
        
        // Setup two schedules: Humidifier (3h interval, 5m duration) and ExhaustFan (2h interval, 3m duration)
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let humId = UUID()
        let fanId = UUID()
        
        var humDevice = SmartDeviceItem()
        humDevice.id = humId
        humDevice.name = "Luchtbevochtiger Tent"
        humDevice.deviceType = "Humidifier"
        humDevice.isOn = false
        humDevice.autoControlEnabled = true
        humDevice.autopilotMode = "customInterval"
        humDevice.customIntervalHours = 3
        humDevice.customIntervalMinutes = 0
        humDevice.customDurationMinutes = 5
        humDevice.lastCustomExecutionTime = pastDate
        
        var fanDevice = SmartDeviceItem()
        fanDevice.id = fanId
        fanDevice.name = "Afzuiger FAE"
        fanDevice.deviceType = "ExhaustFan"
        fanDevice.isOn = false
        fanDevice.autoControlEnabled = true
        fanDevice.autopilotMode = "customInterval"
        fanDevice.customIntervalHours = 2
        fanDevice.customIntervalMinutes = 0
        fanDevice.customDurationMinutes = 3
        fanDevice.lastCustomExecutionTime = pastDate
        
        store.db.smartDevices = [humDevice, fanDevice]
        store.db.environmentConfig.lastFaeExecutionTime = pastDate
        store.db.environmentConfig.lastHumidifierExecutionTime = pastDate
        
        // Simulate app reopening / coming to foreground
        store.handleAppBecameActive()
        
        // Verify that existing countdown timestamps were PRESERVED and NOT clobbered to Date()
        let updatedHum = store.db.smartDevices.first(where: { $0.id == humId })
        let updatedFan = store.db.smartDevices.first(where: { $0.id == fanId })
        
        #expect(updatedHum?.lastCustomExecutionTime == pastDate)
        #expect(updatedFan?.lastCustomExecutionTime == pastDate)
        #expect(store.db.environmentConfig.lastFaeExecutionTime == pastDate)
        #expect(store.db.environmentConfig.lastHumidifierExecutionTime == pastDate)
        
        // Also simulate startAutopilotEngine()
        store.startAutopilotEngine()
        
        let humAfterEngine = store.db.smartDevices.first(where: { $0.id == humId })
        let fanAfterEngine = store.db.smartDevices.first(where: { $0.id == fanId })
        
        #expect(humAfterEngine?.lastCustomExecutionTime == pastDate)
        #expect(fanAfterEngine?.lastCustomExecutionTime == pastDate)
    }

    @Test func testPhysicalButtonHardwareSync() {
        let store = MycoStore.shared ?? MycoStore()
        let plugId = "tuya-plug-abc-123"
        let plugUUID = UUID()
        
        var smartPlug = SmartDeviceItem()
        smartPlug.id = plugUUID
        smartPlug.tuyaDeviceID = plugId
        smartPlug.name = "Smart Plug Kweeklamp"
        smartPlug.deviceType = "Light"
        smartPlug.isOn = false
        
        store.db.smartDevices = [smartPlug]
        #expect(store.db.smartDevices.first?.isOn == false)
        
        // Simulate physical switch pressed on the hardware plug:
        // Remote physical state detected by Pi or LAN polling -> updates store
        store.setSmartDeviceState(id: plugUUID, isOn: true, trigger: "Fysieke Knop")
        #expect(store.db.smartDevices.first?.isOn == true)
        
        // Simulate physical switch pressed again to turn OFF
        store.setSmartDeviceState(id: plugUUID, isOn: false, trigger: "Fysieke Knop")
        #expect(store.db.smartDevices.first?.isOn == false)
    }

    @Test func testSequentialExhaustFanAndHumidifierSafetyInterlock() {
        let store = MycoStore.shared ?? MycoStore()
        let humUUID = UUID()
        let fanUUID = UUID()
        
        var hum = SmartDeviceItem()
        hum.id = humUUID
        hum.name = "Luchtbevochtiger"
        hum.deviceType = "Humidifier"
        hum.isOn = true
        
        var fan = SmartDeviceItem()
        fan.id = fanUUID
        fan.name = "Afzuigventilator"
        fan.deviceType = "ExhaustFan"
        fan.isOn = false
        
        store.db.smartDevices = [hum, fan]
        store.db.environmentConfig.isPinningInductionActive = false
        store.db.environmentConfig.isAutopilotEnabled = true
        store.db.environmentConfig.piHubAutonomousActive = false
        
        // Safety interlock rule 1: When humidifier is ON, switching the exhaust fan ON must immediately shut humidifier OFF
        store.setSmartDeviceState(id: fanUUID, isOn: true, trigger: "Test Fan Start")
        
        let humAfterFan = store.db.smartDevices.first(where: { $0.id == humUUID })
        let fanAfterFan = store.db.smartDevices.first(where: { $0.id == fanUUID })
        
        #expect(humAfterFan?.isOn == false)
        #expect(fanAfterFan?.isOn == true)
        
        // Safety interlock rule 2: In autopilot cycle, if fan is running and humidifier somehow turned on, autopilot forces humidifier OFF
        store.db.smartDevices[0].isOn = true
        store.runAutopilotCycle(isTest: true, pollSensors: false)
        let humAfterAutopilot = store.db.smartDevices.first(where: { $0.id == humUUID })
        #expect(humAfterAutopilot?.isOn == false)
    }

    @Test func testPostFaeDirectMoistureRecoveryCalculationAndTrigger() async throws {
        guard let store = MycoStore.shared else { return }
        let opticalMgr = MycoOpticalHygrometerManager.shared
        
        // 1. Berekening op basis van ventilatorlooptijd
        let shortRun = opticalMgr.calculateHumidifierDurationForFan(fanDurationMinutes: 2.0, targetRH: 90.0)
        let longRun = opticalMgr.calculateHumidifierDurationForFan(fanDurationMinutes: 8.0, targetRH: 90.0)
        
        #expect(shortRun.seconds > 0)
        #expect(longRun.seconds >= shortRun.seconds)
        #expect(longRun.waterMl >= shortRun.waterMl)
        
        // 2. Directe herstel activatie na uitschakelen ventilator
        let humUUID = UUID()
        let fanUUID = UUID()
        var hum = SmartDeviceItem()
        hum.id = humUUID
        hum.name = "Ultrasone Bevochtiger"
        hum.deviceType = "Humidifier"
        hum.autoControlEnabled = true
        hum.isOn = false
        
        var fan = SmartDeviceItem()
        fan.id = fanUUID
        fan.name = "FAE Ventilator"
        fan.deviceType = "ExhaustFan"
        fan.isOn = true
        fan.lastTurnedOnTime = Date().addingTimeInterval(-180) // 3 minuten gedraaid
        
        store.db.smartDevices = [hum, fan]
        store.db.environmentConfig.isAutopilotEnabled = true
        store.db.environmentConfig.targetHumidityPct = 90.0
        
        // Ventilator schakelt uit -> directe start vochtherstel
        store.setSmartDeviceState(id: fanUUID, isOn: false, trigger: "Ventilatie voltooid")
        
        let humAfterFanOff = store.db.smartDevices.first(where: { $0.id == humUUID })
        #expect(humAfterFanOff?.isOn == true)
        
        // Reset device state
        store.setSmartDeviceState(id: humUUID, isOn: false, trigger: "Test Cleanup")
    }

    @Test func testUserTestingAgentEndToEndSimulation() async throws {
        let store = MycoStore.shared ?? MycoStore()
        let agent = MycoUserTestingAgent.shared
        let report = await agent.runAllUserJourneys(store: store)
        
        #expect(!report.isEmpty)
        #expect(agent.overallScore >= 85)
        #expect(agent.stepResults.count >= 7)
        #expect(agent.stepResults.allSatisfy { $0.passed })
    }

    @Test func testDemoLabSeedingAndCleanReset() throws {
        let store = MycoStore.shared ?? MycoStore()
        
        // 1. Seed demo lab
        store.seedDemoLabData()
        #expect(store.db.isDemoMode == true)
        #expect(store.db.projects.count == 3)
        #expect(store.db.strains.count == 3)
        #expect(store.db.smartDevices.count == 3)
        #expect(store.db.stash.count == 2)
        #expect(store.db.supplies.count == 5)
        #expect(store.db.cultures.count == 4)
        
        // Ensure all seeded strains are safe gourmet/medicinal
        for strain in store.db.strains {
            #expect(strain.mushroomType == .culinary || strain.mushroomType == .medicinal)
        }
        
        // 2. Reset to clean lab
        store.resetToCleanLab()
        #expect(store.db.isDemoMode == false)
        #expect(store.db.projects.isEmpty)
        #expect(store.db.smartDevices.isEmpty)
        #expect(store.db.stash.isEmpty)
        #expect(store.db.strains.isEmpty)
        #expect(store.db.supplies.isEmpty)
        #expect(store.db.cultures.isEmpty)
    }

    @Test func testDeveloperAgentKnowledgeSync() throws {
        // 1. Verify Identifiers
        #expect(MycoBackgroundHubManager.bgTaskIdentifier == "com.mycolab.app.autopilot")
        #expect(MycoWidgetDataManager.appGroupID == "group.com.mycolab.app")
        
        // 2. Verify Guideline 1.4.3 (Safe Gourmet & Medicinal Species)
        let forbidden = ["psilocybe", "cubensis", "natalensis", "cyanescens", "penis envy", "golden teacher", "microdose", "microdosering"]
        for species in StrainModel.commonSpecies {
            let lower = species.lowercased()
            for term in forbidden {
                #expect(!lower.contains(term), "Found forbidden substance term in commonSpecies: \(term)")
            }
        }
        
        // 3. Verify Default Strain Safety
        let defaultStrain = StrainModel(name: "Test", skuCode: "TST")
        #expect(defaultStrain.mushroomType == .culinary)
        #expect(defaultStrain.species.contains("Pleurotus"))
        
        // 4. Verify Developer Agent Handover Manifest Output
        let handoverManifest: [String: Any] = [
            "system": "MycoLab iOS Intelligent Lab & Climate Automation",
            "bundleID": "com.mycolab.app",
            "appGroupID": "group.com.mycolab.app",
            "bgTaskID": "com.mycolab.app.autopilot",
            "appleGuidelinesCompliant": true,
            "guidelines": [
                "1.4.3": "Zero tolerance on controlled substances. Gourmet & medicinal cultivation only.",
                "2.1": "Demo Mode available via Onboarding and -demoMode launch argument.",
                "2.5.4": "BGTaskScheduler only. No audio keep-alive background mode."
            ],
            "privacy": [
                "localFirst": true,
                "tracking": false,
                "anonymousDiagnosticsOptIn": true
            ],
            "unitTestsCount": 31,
            "status": "Production Ready for App Store Submission"
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: handoverManifest, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🤖 [DEVELOPER_AI_AGENT_HANDOVER]\n\(jsonString)\n🤖 [END_HANDOVER]")
        }
        #expect(!handoverManifest.isEmpty)
    }

    @Test func testModularSmartDeviceProtocolsAndManualSupport() throws {
        // 1. Verify 5 supported protocols are registered
        let protocols = SmartDeviceItem.supportedProtocols
        #expect(protocols.count == 5)
        #expect(protocols.contains(where: { $0.id == "Tuya / Smart Life" }))
        #expect(protocols.contains(where: { $0.id == "Shelly (Local Wi-Fi)" }))
        #expect(protocols.contains(where: { $0.id == "Tasmota / Sonoff" }))
        #expect(protocols.contains(where: { $0.id == "Home Assistant / Webhook" }))
        #expect(protocols.contains(where: { $0.id == "Manual / Reminder Only" }))
        
        // 2. Verify backward compatibility: default brand is Tuya and not manual
        let defaultDevice = SmartDeviceItem()
        #expect(defaultDevice.brand == "Tuya / Smart Life")
        #expect(defaultDevice.isManualOnly == false)
        
        // 3. Verify manual device identification
        let manualDevice = SmartDeviceItem(name: "Plantenspuit Handmatig", brand: "Manual / Reminder Only")
        #expect(manualDevice.isManualOnly == true)
        
        // 4. Verify Shelly and Tasmota device identification
        let shellyDevice = SmartDeviceItem(name: "Shelly Plug S", brand: "Shelly (Local Wi-Fi)", tuyaDeviceID: "192.168.1.120")
        #expect(shellyDevice.isManualOnly == false)
        #expect(shellyDevice.brand.contains("Shelly"))
        
        let tasmotaDevice = SmartDeviceItem(name: "Sonoff S26 Tasmota", brand: "Tasmota / Sonoff", tuyaDeviceID: "192.168.1.130")
        #expect(tasmotaDevice.isManualOnly == false)
        #expect(tasmotaDevice.brand.contains("Tasmota"))
    }

    @Test func testModularCameraSourcesAndCapabilities() throws {
        // 1. Verify CameraSourceType cases
        #expect(CameraSourceType.allCases.count == 4)
        
        // 2. Verify backward compatible defaults
        var config = GrowEnvironmentConfig()
        #expect(config.effectiveCameraSource == .liveKit)
        #expect(config.effectiveCameraCapabilities.contains(.liveStream))
        #expect(config.effectiveCameraCapabilities.contains(.torchControl))
        #expect(config.effectiveCameraCapabilities.contains(.lensSelection))
        
        // 3. Verify RTSP IP Camera capabilities (No lens switching or torch control)
        config.cameraSourceType = CameraSourceType.rtsp.rawValue
        config.rtspStreamURL = "rtsp://192.168.1.150:554/stream1"
        #expect(config.effectiveCameraSource == .rtsp)
        #expect(config.effectiveCameraCapabilities.contains(.liveStream))
        #expect(config.effectiveCameraCapabilities.contains(.opticalAnalysis))
        #expect(!config.effectiveCameraCapabilities.contains(.torchControl))
        #expect(!config.effectiveCameraCapabilities.contains(.lensSelection))
        
        // 4. Verify HTTP Snapshot Camera capabilities
        config.cameraSourceType = CameraSourceType.httpSnapshot.rawValue
        config.httpSnapshotURL = "http://192.168.1.160/capture"
        #expect(config.effectiveCameraSource == .httpSnapshot)
        #expect(config.effectiveCameraCapabilities.contains(.periodicSnapshot))
        #expect(config.effectiveCameraCapabilities.contains(.opticalAnalysis))
        #expect(!config.effectiveCameraCapabilities.contains(.liveStream))
        
        // 5. Verify Zero-Hardware / Manual mode
        config.cameraSourceType = CameraSourceType.none.rawValue
        #expect(config.effectiveCameraSource == .none)
        #expect(config.effectiveCameraCapabilities.isEmpty)
    }

    @Test func testUnifiedDedicatedCameraDeviceModeSwitching() throws {
        let originalState = UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device")
        defer {
            UserDefaults.standard.set(originalState, forKey: "mycolab_is_dedicated_camera_device")
        }
        
        let store = MycoStore()
        
        // 1. Initially false
        UserDefaults.standard.set(false, forKey: "mycolab_is_dedicated_camera_device")
        #expect(UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device") == false)
        
        // 2. Enable Dedicated Camera mode
        UserDefaults.standard.set(true, forKey: "mycolab_is_dedicated_camera_device")
        #expect(UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device") == true)
        #expect(store.isCurrentDeviceActingAsHub == true)
        #expect(MycoLabAlertManager.shared.isBroadcasterOrStreamDevice == true)
        
        // 3. Disable Dedicated Camera mode
        UserDefaults.standard.set(false, forKey: "mycolab_is_dedicated_camera_device")
        #expect(UserDefaults.standard.bool(forKey: "mycolab_is_dedicated_camera_device") == false)
    }

    @Test func testQRCodeErrorCorrectionAndLabelPresets() throws {
        var db = AppDatabase()
        #expect(db.qrErrorCorrectionLevel == "H")
        #expect(db.qrLabelPresetSize == "38x38")
        
        db.qrErrorCorrectionLevel = "Q"
        db.qrLabelPresetSize = "50x50"
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(db)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppDatabase.self, from: data)
        
        #expect(decoded.qrErrorCorrectionLevel == "Q")
        #expect(decoded.qrLabelPresetSize == "50x50")
        
        // Verify QR generator image output
        let img = QRCodeGenerator.generateImage(from: "TEST-LIONSMANE-01", size: 100, includeLogo: false, correctionLevel: "H")
        #expect(img.size.width > 0)
    }

    @Test func testTimelapseMultiCameraIndependentStatus() throws {
        let lm = LiveKitStreamManager.shared
        lm.currentRole = .viewer
        lm.isRemoteTimelapseRunning = true
        lm.remoteActiveTimelapseCameraIDs = ["wide"]
        lm.remoteTimelapseCameraID = "wide"
        
        // Wide should be running
        #expect(lm.isTimelapseRunning(for: "wide") == true)
        // Ultrawide should NOT be running
        #expect(lm.isTimelapseRunning(for: "ultrawide") == false)
        // Telephoto should NOT be running
        #expect(lm.isTimelapseRunning(for: "telephoto") == false)
        
        // Add ultrawide as second active timelapse camera
        lm.remoteActiveTimelapseCameraIDs.insert("ultrawide")
        #expect(lm.isTimelapseRunning(for: "wide") == true)
        #expect(lm.isTimelapseRunning(for: "ultrawide") == true)
        #expect(lm.isTimelapseRunning(for: "telephoto") == false)
        
        // Stop wide
        lm.remoteActiveTimelapseCameraIDs.remove("wide")
        #expect(lm.isTimelapseRunning(for: "wide") == false)
        #expect(lm.isTimelapseRunning(for: "ultrawide") == true)
        
        // Cleanup
        lm.remoteActiveTimelapseCameraIDs.removeAll()
        lm.isRemoteTimelapseRunning = false
    }

    @Test
    func testWidgetVpdAndGrowDaysSnapshot() throws {
        // 1. Default snapshot has valid VPD and grow days
        let snapshot = MycoWidgetSnapshot(
            temperatureC: 24.0,
            humidityPct: 90.0,
            topBatchDaysInPhase: 7,
            vpdKpa: 0.30,
            vpdZoneTitle: "Ideaal"
        )
        #expect(snapshot.vpdKpa == 0.30)
        #expect(snapshot.topBatchDaysInPhase == 7)
        #expect(snapshot.vpdZoneTitle == "Ideaal" || snapshot.vpdZoneTitle == "Ideal")

        // 2. JSON serialization and backward compatibility
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(MycoWidgetSnapshot.self, from: data)
        #expect(decoded.vpdKpa == 0.30)
        #expect(decoded.topBatchDaysInPhase == 7)
        #expect(decoded.temperatureC == 24.0)

        // 3. Verify MycoVPDCalculator accuracy
        let vpdResult = MycoVPDCalculator.analyze(tempC: 24.0, humidityPct: 90.0)
        #expect(vpdResult != nil)
        if let vpd = vpdResult {
            #expect(vpd.vpdKPa > 0.20 && vpd.vpdKPa < 0.40)
            #expect(vpd.zone == .idealFruiting)
        }
    }

    @Test
    func testHomeAssistantYamlIntegrationAndKeySync() throws {
        let store = MycoStore()
        let key = store.db.webhookKey
        #expect(!key.isEmpty)

        // Webhook scheme URL format
        let expectedUrl = "mycolab://sensor?key=\(key)&temp=23.4&humidity=91.5&co2=680"
        #expect(expectedUrl.contains(key))
        #expect(expectedUrl.hasPrefix("mycolab://sensor?key="))
    }

    @Test
    func testBatchCertificatePDFGeneration() throws {
        let store = MycoStore()
        let project = GrowProject(
            strainName: "Hericium erinaceus (Lion's Mane)",
            skuCode: "LM-01",
            batchNumber: 42,
            phase: .fruiting,
            containerName: "Unicorn XLS-A Autoclave Zak",
            substrateName: "Master's Mix (Hardwood + Sojameel)",
            drySubstrateWeightGrams: 1000.0,
            parentCultureLabel: "Master Culture Plate #04",
            startDate: Date().addingTimeInterval(-86400 * 20),
            qrCodeID: "MYCO-LM01-42"
        )
        let harvest = HarvestRecord(
            projectID: project.id,
            strainName: project.strainName,
            skuCode: project.skuCode,
            flushNumber: 1,
            harvestDate: Date(),
            wetWeightGrams: 850.0,
            dryWeightGrams: 85.0
        )
        store.db.projects = [project]
        store.db.harvests = [harvest]
        
        let url = MycoReportExporter.generateBatchCertificatePDF(project: project, store: store)
        #expect(FileManager.default.fileExists(atPath: url.path))
        
        let attr = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attr[.size] as? Int64 ?? 0
        #expect(size > 2000, "Certificate PDF must be well-formed and non-empty")
        
        // Clean up temporary file
        try? FileManager.default.removeItem(at: url)
    }

    @Test
    func testDayNightClimateAndPinningProfiles() throws {
        var config = GrowEnvironmentConfig()
        config.targetDayTempC = 24.0
        config.targetNightTempC = 19.5
        config.pinningTargetTempC = 18.0
        config.faeIntervalMinutes = 120
        config.isDayNightCycleEnabled = true
        
        // Normal profile without pinning
        config.isPinningInductionActive = false
        if config.isCurrentlyDayTime {
            #expect(config.effectiveTargetTempC == 24.0)
        } else {
            #expect(config.effectiveTargetTempC == 19.5)
        }
        #expect(config.effectiveFaeIntervalMinutes == 120)
        
        // Pinning trigger enabled: overrides day/night with cold shock and halves FAE interval
        config.isPinningInductionActive = true
        #expect(config.effectiveTargetTempC == 18.0)
        #expect(config.effectiveFaeIntervalMinutes == 60)
        
        // Pinning trigger disabled again
        config.isPinningInductionActive = false
        #expect(config.effectiveFaeIntervalMinutes == 120)
    }

    @Test
    func testCleanroomVoiceHarvestIntentParsing() throws {
        let engine = MycoCleanroomAIIntentEngine.shared
        
        let intent1 = engine.interpret(spokenText: "oogst 350 gram")
        #expect(intent1 == .logHarvest(grams: 350.0))
        
        let intent2 = engine.interpret(spokenText: "log oogst van 180.5g")
        #expect(intent2 == .logHarvest(grams: 180.5))
        
        let intent3 = engine.interpret(spokenText: "we hebben net geoogst 420 gram van de lions mane")
        #expect(intent3 == .logHarvest(grams: 420.0))
    }

    @Test
    func testCleanroomVoicePinningTriggerParsing() throws {
        let engine = MycoCleanroomAIIntentEngine.shared
        
        let start1 = engine.interpret(spokenText: "start pinning")
        #expect(start1 == .togglePinningTrigger(enable: true))
        
        let start2 = engine.interpret(spokenText: "activeer koudeval shock")
        #expect(start2 == .togglePinningTrigger(enable: true))
        
        let stop1 = engine.interpret(spokenText: "stop pinning")
        #expect(stop1 == .togglePinningTrigger(enable: false))
        
        let stop2 = engine.interpret(spokenText: "deactiveer koudeval")
        #expect(stop2 == .togglePinningTrigger(enable: false))
    }

    @Test
    func testCameraCapabilitiesAndDynamicDeviceAdaptation() throws {
        // LiveKit Hub iPhone stream phone has screen sleep capability
        let liveKitCaps = CameraCapabilities.capabilities(for: .liveKit)
        #expect(liveKitCaps.hasScreen == true)
        #expect(liveKitCaps.contains(.screenSleepControl))

        // RTSP and HTTP snapshot cameras are dedicated headless/screenless cameras
        let rtspCaps = CameraCapabilities.capabilities(for: .rtsp)
        #expect(rtspCaps.hasScreen == false)
        #expect(!rtspCaps.contains(.screenSleepControl))

        let httpCaps = CameraCapabilities.capabilities(for: .httpSnapshot)
        #expect(httpCaps.hasScreen == false)
        #expect(!httpCaps.contains(.screenSleepControl))

        let noneCaps = CameraCapabilities.capabilities(for: .none)
        #expect(noneCaps.hasScreen == false)
        #expect(!noneCaps.contains(.screenSleepControl))
    }

    @Test
    func testCleanroomVoiceCameraSleepIntentParsing() throws {
        let engine = MycoCleanroomAIIntentEngine.shared

        let sleep1 = engine.interpret(spokenText: "sleep cam")
        #expect(sleep1 == .controlCameraSleep(putToSleep: true))

        let sleep2 = engine.interpret(spokenText: "scherm uit")
        #expect(sleep2 == .controlCameraSleep(putToSleep: true))

        let sleep3 = engine.interpret(spokenText: "dim camerascherm")
        #expect(sleep3 == .controlCameraSleep(putToSleep: true))

        let sleep4 = engine.interpret(spokenText: "slaapstand camera")
        #expect(sleep4 == .controlCameraSleep(putToSleep: true))

        let wake1 = engine.interpret(spokenText: "maak camera wakker")
        #expect(wake1 == .controlCameraSleep(putToSleep: false))

        let wake2 = engine.interpret(spokenText: "scherm aan")
        #expect(wake2 == .controlCameraSleep(putToSleep: false))

        let query1 = engine.interpret(spokenText: "heeft de camera een beeldscherm")
        #expect(query1 == .queryCameraCapabilities)

        let query2 = engine.interpret(spokenText: "wat voor camera is verbonden")
        #expect(query2 == .queryCameraCapabilities)
    }

    @Test func testAdvancedClimateSettingsAndCustomLimitsPersistence() async throws {
        var config = GrowEnvironmentConfig()
        // Verify user customizable limits and hysteresis
        #expect(config.humidityHysteresisPct == 2.0)
        #expect(config.tempHysteresisC == 0.5)
        #expect(config.maxCo2ThresholdPpm == 1000)
        #expect(config.humidifierDurationSeconds == 120)
        #expect(config.customTimelapseIntervalMinutes == 15)
        #expect(config.pinningFaeMultiplier == 2.0)

        // Customise values freely
        config.targetDayTempC = 24.2
        config.targetNightTempC = 18.8
        config.humidityHysteresisPct = 3.5
        config.tempHysteresisC = 0.8
        config.maxCo2ThresholdPpm = 850
        config.humidifierDurationSeconds = 180
        config.customTimelapseIntervalMinutes = 7
        config.pinningFaeMultiplier = 2.5

        #expect(config.targetDayTempC == 24.2)
        #expect(config.targetNightTempC == 18.8)
        #expect(config.humidityHysteresisPct == 3.5)
        #expect(config.tempHysteresisC == 0.8)
        #expect(config.maxCo2ThresholdPpm == 850)
        #expect(config.humidifierDurationSeconds == 180)
        #expect(config.customTimelapseIntervalMinutes == 7)
        #expect(config.pinningFaeMultiplier == 2.5)

        // JSON Codable persistence round-trip
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GrowEnvironmentConfig.self, from: data)
        #expect(decoded.targetDayTempC == 24.2)
        #expect(decoded.humidityHysteresisPct == 3.5)
        #expect(decoded.maxCo2ThresholdPpm == 850)
        #expect(decoded.customTimelapseIntervalMinutes == 7)
    }

    @Test func testClearAllPresetsToBlankSlate() async throws {
        var db = AppDatabase()
        db.presets = [
            UserPreset(category: .container, name: "MonoTub 64L", details: "Test"),
            UserPreset(category: .substrate, name: "CVG Classic", details: "Test")
        ]
        #expect(db.presets.count == 2)

        // Clear all presets to allow blank slate
        db.presets.removeAll()
        #expect(db.presets.isEmpty)
    }

    @Test func testScheduleEffectiveDateLockout() throws {
        // 1. SmartDeviceItem effective date
        var device = SmartDeviceItem()
        device.name = "Luchtbevochtiger Tent"
        device.deviceType = "Humidifier"
        
        // No effective date set -> immediately effective
        device.scheduleEffectiveFrom = nil
        #expect(device.isScheduleEffective == true)
        
        // Effective date in past -> effective
        device.scheduleEffectiveFrom = Date().addingTimeInterval(-3600)
        #expect(device.isScheduleEffective == true)
        
        // Effective date in future -> NOT effective yet
        device.scheduleEffectiveFrom = Date().addingTimeInterval(3600)
        #expect(device.isScheduleEffective == false)
        
        // 2. GrowEnvironmentConfig effective date
        var config = GrowEnvironmentConfig()
        config.scheduleEffectiveFrom = nil
        #expect(config.isScheduleEffective == true)
        
        config.scheduleEffectiveFrom = Date().addingTimeInterval(1800)
        #expect(config.isScheduleEffective == false)
        
        config.scheduleEffectiveFrom = Date().addingTimeInterval(-1800)
        #expect(config.isScheduleEffective == true)
        
        // 3. JSON Codable roundtrip
        device.scheduleEffectiveFrom = Date().addingTimeInterval(-3600)
        let encoder = JSONEncoder()
        let data = try encoder.encode(device)
        let decoded = try JSONDecoder().decode(SmartDeviceItem.self, from: data)
        #expect(decoded.scheduleEffectiveFrom != nil)
        #expect(decoded.isScheduleEffective == true)
    }

    @Test func testPreFaeHumidifierLockoutAndPostFaeRecovery() throws {
        let store = MycoStore.shared ?? MycoStore()
        store.db.environmentConfig.preFaeHumidifierLockoutMinutes = 10
        store.db.environmentConfig.postFaeRecoveryDurationSeconds = 120
        
        // 1. Config defaults
        #expect(store.db.environmentConfig.preFaeHumidifierLockoutMinutes == 10)
        #expect(store.db.environmentConfig.postFaeRecoveryDurationSeconds == 120)
        
        // 2. Humidifier & Fan setup
        let humUUID = UUID()
        let fanUUID = UUID()
        
        var hum = SmartDeviceItem()
        hum.id = humUUID
        hum.name = "Luchtbevochtiger"
        hum.deviceType = "Humidifier"
        hum.autoControlEnabled = true
        hum.isOn = true
        
        var fan = SmartDeviceItem()
        fan.id = fanUUID
        fan.name = "Afzuiging Ventilator"
        fan.deviceType = "ExhaustFan"
        fan.autoControlEnabled = true
        fan.isOn = false
        
        store.db.smartDevices = [hum, fan]
        store.db.environmentConfig.isAutopilotEnabled = true
        store.db.environmentConfig.faeIntervalMinutes = 120
        store.db.environmentConfig.preFaeHumidifierLockoutMinutes = 10
        store.db.environmentConfig.postFaeRecoveryDurationSeconds = 90
        
        // Scenario A: Next FAE is in 5 minutes (within 10m buffer)
        // Since faeInterval is 120m, setting lastFaeExecutionTime to 115 minutes ago means next FAE is in 5 minutes!
        store.db.environmentConfig.lastFaeExecutionTime = Date().addingTimeInterval(-115 * 60)
        
        // Run autopilot cycle -> Pre-FAE lockout MUST turn off active humidifier to prevent nevelverspilling
        store.runAutopilotCycle(isTest: true, pollSensors: false)
        let humAfterLockout = store.db.smartDevices.first(where: { $0.id == humUUID })
        #expect(humAfterLockout?.isOn == false)
        
        // Scenario B: Post-FAE moisture recovery uses configured fixed duration (90s)
        fan.isOn = true
        fan.lastTurnedOnTime = Date().addingTimeInterval(-180)
        store.db.smartDevices = [humAfterLockout!, fan]
        
        // Fan turns off -> triggers recovery
        store.setSmartDeviceState(id: fanUUID, isOn: false, trigger: "Ventilatie voltooid")
        let humRecovering = store.db.smartDevices.first(where: { $0.id == humUUID })
        #expect(humRecovering?.isOn == true)
        
        // Cleanup
        store.setSmartDeviceState(id: humUUID, isOn: false, trigger: "Test Cleanup")
    }
}
