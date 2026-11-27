//
//  ClassicLabViews.swift
//  MycoLab
//
//  Original Classic Tab Views retained for 100% reversible fallback:
//  - DashboardTabView
//  - GeneticsLabTabView
//  - StashAndStockTabView
//  - ToolsAndPresetsTabView
//  - MycoAIRecipeEngine
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
public import Combine

// MARK: - DASHBOARD TIMER ROW VIEW (STOPS AT ZERO & DOES NOT COUNT UP)

// MARK: - SHARED MODALS & SHEETS FOR MODERN LAB TABS

struct ScannedDossierWrapper: Identifiable {
    let id = UUID()
    let text: String
}

struct BatchLabelsWrapper: Identifiable {
    let id = UUID()
    let labels: [(title: String, subtitle: String, date: String, qr: String)]
}


struct CreateBatchSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var strainName: String = ""
    @State private var species: String = ""
    @State private var customSpecies: String = ""
    @State private var selectedPhase: GrowPhase = .spawn
    @State private var batchQuantity: Int = 1
    @State private var selectedRecipeID: UUID? = nil
    @State private var containerName: String = ""
    @State private var substrateName: String = ""
    @State private var spawnToBulkRatio: String = ""
    @State private var drySubstrateWeight: String = ""
    @State private var sterilizationNotes: String = ""
    @State private var parentCultureLabel: String = ""
    
    // Auto Stock Deduction
    @State private var autoDeductRecipeIngredients: Bool = true
    @State private var autoDeductSupply: Bool = false
    @State private var selectedSupplyID: UUID? = nil
    @State private var deductAmountPerBatch: Double = 1.0

    @State private var showAddRecipeSheet: Bool = false
    @State private var activeLabels: BatchLabelsWrapper?
    
    init(
        initialSubstrateName: String = "",
        initialDryWeight: String = "",
        initialStrainName: String = "",
        initialParentCultureLabel: String = "",
        initialRecipeID: UUID? = nil
    ) {
        _substrateName = State(initialValue: initialSubstrateName)
        _drySubstrateWeight = State(initialValue: initialDryWeight)
        _strainName = State(initialValue: initialStrainName)
        _parentCultureLabel = State(initialValue: initialParentCultureLabel)
        _selectedRecipeID = State(initialValue: initialRecipeID)
    }
    
    private func typeColor(_ type: MushroomApplicationType) -> Color {
        switch type {
        case .culinary: return MycoTheme.green
        case .medicinal: return MycoTheme.blue
        case .active: return MycoTheme.amber
        case .other: return MycoTheme.textSecondary
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(store.t(nl: "1. Genetica & Paddenstoelensoort", en: "1. Genetics & Mushroom Species")) {
                    if !store.db.strains.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button {
                                    strainName = ""
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle")
                                        Text(store.t(nl: "Handmatig", en: "Manual"))
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(strainName.isEmpty ? .white : MycoTheme.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(strainName.isEmpty ? MycoTheme.blue : Color.white.opacity(0.06))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                
                                ForEach(store.db.strains) { s in
                                    let isSelected = strainName.caseInsensitiveCompare(s.name) == .orderedSame
                                    Button {
                                        strainName = s.name
                                        species = s.species
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: s.mushroomType.icon)
                                                .font(.system(size: 10))
                                                .foregroundColor(typeColor(s.mushroomType))
                                            Text(s.name)
                                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                            Text("• \(s.species)")
                                                .font(.system(size: 9))
                                                .italic()
                                                .foregroundColor(isSelected ? .white.opacity(0.8) : MycoTheme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        .foregroundColor(isSelected ? .white : MycoTheme.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? typeColor(s.mushroomType).opacity(0.3) : Color.white.opacity(0.06))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isSelected ? typeColor(s.mushroomType) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    if let matched = store.db.strains.first(where: { $0.name.caseInsensitiveCompare(strainName) == .orderedSame }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(typeColor(matched.mushroomType).opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: matched.mushroomType.icon)
                                    .foregroundColor(typeColor(matched.mushroomType))
                                    .font(.system(size: 20, weight: .bold))
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(matched.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(matched.mushroomType.shortLabel(isEnglish: store.isEnglish))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(typeColor(matched.mushroomType))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(typeColor(matched.mushroomType).opacity(0.18))
                                        .cornerRadius(4)
                                }
                                
                                Text(matched.species)
                                    .font(.system(size: 12))
                                    .italic()
                                    .foregroundColor(MycoTheme.textSecondary)
                                
                                HStack(spacing: 8) {
                                    Label(matched.colonizationSpeed.localized(isEnglish: store.isEnglish), systemImage: matched.colonizationSpeed.icon)
                                        .font(.system(size: 10))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    
                                    Text("•").foregroundColor(MycoTheme.textSecondary.opacity(0.4))
                                    
                                    Label(matched.difficulty.localized(isEnglish: store.isEnglish), systemImage: "sparkles")
                                        .font(.system(size: 10))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(store.t(nl: "Wijzig", en: "Change")) {
                                strainName = ""
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(MycoTheme.blue)
                        }
                        .padding(10)
                        .background(typeColor(matched.mushroomType).opacity(0.08))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(typeColor(matched.mushroomType).opacity(0.25), lineWidth: 1))
                    } else {
                        TextField(store.t(nl: "Naam van soort / strain (bijv. Golden Teacher)", en: "Strain Name"), text: $strainName)
                        
                        Picker(store.t(nl: "Botanische Soort", en: "Botanical Species"), selection: $species) {
                            Text(store.t(nl: "Kies botanische soort...", en: "Choose botanical species...")).tag("")
                            ForEach(StrainModel.commonSpecies, id: \.self) { sp in
                                Text(store.localizeBotanicalSpecies(sp)).tag(sp)
                            }
                        }
                        if species == "Anders / Zelf typen..." {
                            TextField(store.t(nl: "Typ eigen botanische soort...", en: "Type custom botanical species..."), text: $customSpecies)
                        }
                    }
                    
                    if !store.db.cultures.isEmpty {
                        Picker(store.t(nl: "Koppel aan Moedercultuur (Optioneel)", en: "Link to Mother Culture (Optional)"), selection: $parentCultureLabel) {
                            Text(store.t(nl: "Geen koppeling", en: "No link")).tag("")
                            ForEach(store.db.cultures) { c in
                                Text("\(c.strainName) (\(c.generation) • \(c.qrCodeID.isEmpty ? c.skuCode : c.qrCodeID))").tag("\(c.strainName) \(c.generation)")
                            }
                        }
                    }
                }
                
                Section(store.t(nl: "2. Fase & Aantal Potten/Bakken tegelijk", en: "2. Phase & Number of Jars/Tubs")) {
                    Picker(store.t(nl: "Startfase", en: "Starting Phase"), selection: $selectedPhase) {
                        ForEach(GrowPhase.startableCases, id: \.self) { phase in
                            Text(phase.localized(isEnglish: store.isEnglish)).tag(phase)
                        }
                    }
                    HStack {
                        Stepper(store.t(nl: "Aantal tegelijk maken: \(batchQuantity)", en: "Create at once: \(batchQuantity)"), value: $batchQuantity, in: 1...24)
                        InfoTipButton(
                            title: store.t(nl: "Batch Reeks Generatie", en: "Batch Series Generation"),
                            message: store.t(
                                nl: "Wanneer je meer dan 1 batch kiest, maakt MycoLabs automatisch batch #1 t/m #\(batchQuantity) aan. Elke batch krijgt direct een eigen, unieke QR-code die je kunt scannen of printen.",
                                en: "When selecting more than 1 batch, MycoLabs automatically creates batches #1 through #\(batchQuantity). Each batch gets a unique QR code ready for scanning or printing."
                            )
                        )
                    }
                }
                
                Section(header: HStack {
                    Text(store.t(nl: "3. Bereidingsrecept & Ingrediënten", en: "3. Preparation Recipe & Ingredients"))
                    Spacer()
                    Button {
                        showAddRecipeSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text(store.t(nl: "Nieuw Recept", en: "New Recipe"))
                        }
                        .font(.caption.bold())
                        .foregroundColor(MycoTheme.blue)
                    }
                }) {
                    Picker(store.t(nl: "Kies Bereidingsrecept", en: "Choose Preparation Recipe"), selection: $selectedRecipeID) {
                        Text(store.t(nl: "Geen / Handmatige invoer", en: "None / Manual entry")).tag(UUID?.none)
                        ForEach(store.db.preparationRecipes) { r in
                            Text("\(r.name) (\(r.category))").tag(UUID?.some(r.id))
                        }
                    }
                    .onChange(of: selectedRecipeID) { _, newID in
                        guard let id = newID, let r = store.db.preparationRecipes.first(where: { $0.id == id }) else { return }
                        selectedPhase = r.targetPhase
                        if !r.containerName.isEmpty { containerName = r.containerName }
                        if !r.substrateName.isEmpty { substrateName = r.substrateName }
                        if !r.spawnToBulkRatio.isEmpty { spawnToBulkRatio = r.spawnToBulkRatio }
                        if r.drySubstrateWeightGrams > 0 {
                            drySubstrateWeight = String(format: "%.0f", r.drySubstrateWeightGrams)
                        }
                        if !r.sterilizationNotes.isEmpty {
                            sterilizationNotes = r.sterilizationNotes
                        }
                    }
                    
                    if let selId = selectedRecipeID, let recipe = store.db.preparationRecipes.first(where: { $0.id == selId }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(recipe.name, systemImage: "fork.knife.circle.fill")
                                    .font(.subheadline.bold())
                                    .foregroundColor(MycoTheme.green)
                                Spacer()
                                Text(recipe.category)
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(MycoTheme.green.opacity(0.2))
                                    .foregroundColor(MycoTheme.green)
                                    .cornerRadius(4)
                            }
                            
                            if !recipe.preparationInstructions.isEmpty {
                                Text(recipe.preparationInstructions)
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                    .lineLimit(3)
                            }
                            
                            if !recipe.ingredients.isEmpty {
                                Divider()
                                
                                HStack {
                                    Text(store.t(
                                        nl: "Berekende ingrediënten (\(batchQuantity)x batch):",
                                        en: "Calculated ingredients (\(batchQuantity)x batch):"
                                    ))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    Spacer()
                                    Text(store.t(nl: "Totaal gewicht/volume", en: "Total amount"))
                                        .font(.caption2)
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                
                                ForEach(recipe.ingredients) { ing in
                                    let scaledAmount = ing.amountPerBatch * Double(batchQuantity)
                                    HStack {
                                        Text("• \(ing.name)")
                                            .font(.caption)
                                            .foregroundColor(MycoTheme.textSecondary)
                                        Spacer()
                                        Text("\(String(format: scaledAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", scaledAmount)) \(ing.unit)")
                                            .font(.system(.caption, design: .monospaced).bold())
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(store.t(nl: "4. Hardware, Substraat & Sterilisatie", en: "4. Hardware, Substrate & Sterilization")) {
                    let containers = store.db.presets.filter { $0.category == .container }
                    if !containers.isEmpty {
                        Picker(store.t(nl: "Kies Container Preset", en: "Choose Container Preset"), selection: $containerName) {
                            Text(store.t(nl: "Handmatig...", en: "Manual...")).tag("")
                            ForEach(containers) { p in Text(store.localizePresetName(p.name)).tag(p.name) }
                        }
                    }
                    TextField(store.t(nl: "Container (bijv. 1L Pot, Monotub, Growbag)", en: "Container (e.g. 1L Jar, Monotub, Grow Bag)"), text: $containerName)
                    
                    let substrates = store.db.presets.filter { $0.category == .substrate || $0.category == .grain }
                    if !substrates.isEmpty {
                        Picker(store.t(nl: "Kies Substraat/Graan Preset", en: "Choose Substrate/Grain Preset"), selection: $substrateName) {
                            Text(store.t(nl: "Handmatig / Zelf typen...", en: "Manual / Type custom...")).tag("")
                            ForEach(substrates) { p in Text(store.localizePresetName(p.name)).tag(p.name) }
                        }
                    }
                    TextField(store.t(nl: "Substraat / Graan / Media", en: "Substrate / Grain / Media"), text: $substrateName)
                    TextField(store.t(nl: "Ratio (bijv. 1:2)", en: "Ratio (e.g. 1:2)"), text: $spawnToBulkRatio)
                    HStack {
                        TextField(store.t(nl: "Droog substraatgewicht in gram (bijv. 650)", en: "Dry substrate weight in grams (e.g. 650)"), text: $drySubstrateWeight)
                            .keyboardType(.decimalPad)
                        InfoTipButton(
                            title: store.t(nl: "Biologische Efficiëntie (BE%)", en: "Biological Efficiency (BE%)"),
                            message: store.t(
                                nl: "BE% meet het kweekrendement: (vers oogstgewicht in gram / droog substraatgewicht in gram) × 100%. Vul hier het droge startgewicht in van bijv. je coir of graan.",
                                en: "BE% measures harvest efficiency: (fresh yield weight in grams / dry substrate weight in grams) × 100%. Enter the initial dry weight of e.g. coir or grain."
                            )
                        )
                    }
                    
                    let sterilizations = store.db.sterilizationPresets
                    if !sterilizations.isEmpty {
                        Picker(store.t(nl: "Kies Sterilisatie Preset", en: "Choose Sterilization Preset"), selection: $sterilizationNotes) {
                            Text(store.t(nl: "Handmatig / Geen", en: "Manual / None")).tag("")
                            ForEach(sterilizations) { s in
                                Text("\(s.name) (\(s.durationMinutes)m - \(s.pressureOrNotes))").tag("\(s.name): \(s.durationMinutes)m @ \(s.pressureOrNotes)")
                            }
                        }
                    }
                    TextField(store.t(nl: "Sterilisatie / Pasteurisatie Protocol", en: "Sterilization Protocol"), text: $sterilizationNotes)
                }
                
                Section(store.t(nl: "5. Voorraad Afboeken (Optioneel)", en: "5. Stock Deduction (Optional)")) {
                    if let selId = selectedRecipeID, let recipe = store.db.preparationRecipes.first(where: { $0.id == selId }), !recipe.ingredients.isEmpty {
                        Toggle(store.t(
                            nl: "Recept-ingrediënten automatisch afboeken (\(batchQuantity)x)",
                            en: "Auto-deduct recipe ingredients (\(batchQuantity)x)"
                        ), isOn: $autoDeductRecipeIngredients)
                        
                        if autoDeductRecipeIngredients {
                            ForEach(recipe.ingredients) { ing in
                                let totalDeduct = ing.amountPerBatch * Double(batchQuantity)
                                let matchingSupply = store.db.supplies.first(where: {
                                    if let lId = ing.linkedSupplyID, $0.id == lId { return true }
                                    return $0.name.localizedCaseInsensitiveContains(ing.name) || ing.name.localizedCaseInsensitiveContains($0.name)
                                })
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ing.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                        if let sup = matchingSupply {
                                            Text(store.t(
                                                nl: "Voorraad: \(String(format: "%.1f", sup.quantity)) \(sup.unit)",
                                                en: "In stock: \(String(format: "%.1f", sup.quantity)) \(sup.unit)"
                                            ))
                                            .font(.caption2)
                                            .foregroundColor(sup.quantity < totalDeduct ? MycoTheme.red : MycoTheme.textSecondary)
                                        } else {
                                            Text(store.t(nl: "Niet gekoppeld aan labvoorraad", en: "Not matched in lab stock"))
                                                .font(.caption2)
                                                .foregroundColor(MycoTheme.amber)
                                        }
                                    }
                                    Spacer()
                                    Text("-\(String(format: totalDeduct.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", totalDeduct)) \(ing.unit)")
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundColor(matchingSupply.map { $0.quantity < totalDeduct ? MycoTheme.red : MycoTheme.amber } ?? MycoTheme.textSecondary)
                                }
                            }
                        }
                    } else {
                        Toggle(store.t(nl: "Automatisch van labvoorraad afboeken", en: "Automatically deduct from lab stock"), isOn: $autoDeductSupply)
                        if autoDeductSupply && !store.db.supplies.isEmpty {
                            Picker(store.t(nl: "Kies Grondstof", en: "Choose Supply Item"), selection: $selectedSupplyID) {
                                Text(store.t(nl: "Selecteer voorraad...", en: "Select item...")).tag(UUID?.none)
                                ForEach(store.db.supplies) { item in
                                    Text("\(item.name) (Huidig: \(String(format: "%.1f", item.quantity)) \(item.unit))").tag(UUID?.some(item.id))
                                }
                            }
                            if let selId = selectedSupplyID, let item = store.db.supplies.first(where: { $0.id == selId }) {
                                HStack {
                                    Text(store.t(nl: "Aantal per pot/bak:", en: "Amount per jar/tub:"))
                                    Spacer()
                                    TextField("1.0", value: $deductAmountPerBatch, format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                    Text(item.unit)
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                let totalDeduct = deductAmountPerBatch * Double(batchQuantity)
                                HStack {
                                    Text(store.t(nl: "Totale afboeking (\(batchQuantity)x):", en: "Total deduction (\(batchQuantity)x):"))
                                        .font(.caption)
                                        .foregroundColor(MycoTheme.textSecondary)
                                    Spacer()
                                    Text("-\(String(format: "%.1f", totalDeduct)) \(item.unit)")
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundColor(item.quantity < totalDeduct ? MycoTheme.red : MycoTheme.amber)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        createBatches()
                    } label: {
                        Text(store.t(nl: "Maak \(batchQuantity) Batch(es) & Genereer QR-Labels", en: "Create \(batchQuantity) Batch(es) & Generate QR Labels"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .listRowBackground(strainName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : MycoTheme.blue)
                    .disabled(strainName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Nieuwe Batch", en: "New Batch"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                }
            }
            .sheet(isPresented: $showAddRecipeSheet) {
                AddPreparationRecipeSheetView()
                    .environmentObject(store)
            }
            .sheet(item: $activeLabels, onDismiss: { dismiss() }) { wrapper in
                NavigationStack {
                    QRLabelStudioView(labels: wrapper.labels)
                }
            }
            .onAppear {
                if let recID = selectedRecipeID, let r = store.db.preparationRecipes.first(where: { $0.id == recID }) {
                    selectedPhase = r.targetPhase
                    if !r.containerName.isEmpty { containerName = r.containerName }
                    if !r.substrateName.isEmpty { substrateName = r.substrateName }
                    if !r.spawnToBulkRatio.isEmpty { spawnToBulkRatio = r.spawnToBulkRatio }
                    if r.drySubstrateWeightGrams > 0 {
                        drySubstrateWeight = String(format: "%.0f", r.drySubstrateWeightGrams)
                    }
                    if !r.sterilizationNotes.isEmpty {
                        sterilizationNotes = r.sterilizationNotes
                    }
                }
                if !strainName.isEmpty, let s = store.db.strains.first(where: { $0.name.caseInsensitiveCompare(strainName) == .orderedSame }) {
                    species = s.species
                }
            }
        }
    }
    
    private func createBatches() {
        let cleanStrain = strainName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanStrain.isEmpty else { return }
        
        let effectiveSpecies: String
        if species.isEmpty {
            effectiveSpecies = "Psilocybe cubensis"
        } else if species == "Anders / Zelf typen..." {
            let trimmed = customSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
            effectiveSpecies = trimmed.isEmpty ? "Eigen Soort" : trimmed
        } else {
            effectiveSpecies = species
        }
        
        // Save to user strains automatically if new
        if !store.db.strains.contains(where: { $0.name.caseInsensitiveCompare(cleanStrain) == .orderedSame }) {
            store.db.strains.append(
                StrainModel(
                    name: cleanStrain,
                    skuCode: store.nextSKU(prefix: "STR"),
                    species: effectiveSpecies,
                    potencyMultiplier: 1.0,
                    notes: ""
                )
            )
        }
        
        let selectedRecipe = store.db.preparationRecipes.first(where: { $0.id == selectedRecipeID })
        let recipeName = selectedRecipe?.name ?? ""
        
        let existingCount = store.db.projects.filter { $0.strainName.lowercased() == cleanStrain.lowercased() }.count
        var generated: [(title: String, subtitle: String, date: String, qr: String)] = []
        
        let formattedDate = Date().formatted(date: .numeric, time: .omitted)
        for i in 1...batchQuantity {
            let batchNum = existingCount + i
            let sku = String(format: "ML-%03d", store.db.projects.count + 1)
            let qrID = "QR-\(sku)-\(Int.random(in: 100...999))"
            let newProj = GrowProject(
                strainName: cleanStrain,
                skuCode: sku,
                batchNumber: batchNum,
                phase: selectedPhase,
                colonizationPercent: 0.0,
                containerName: containerName,
                substrateName: substrateName,
                spawnToBulkRatio: spawnToBulkRatio.trimmingCharacters(in: .whitespaces).isEmpty ? "1:2" : spawnToBulkRatio.trimmingCharacters(in: .whitespaces),
                drySubstrateWeightGrams: Double(drySubstrateWeight.replacingOccurrences(of: ",", with: ".")) ?? 650.0,
                sterilizationNotes: sterilizationNotes,
                parentCultureLabel: parentCultureLabel,
                qrCodeID: qrID,
                recipeID: selectedRecipeID,
                recipeName: recipeName
            )
            store.db.projects.insert(newProj, at: 0)
            
            let richQRText = store.generateTransparentProcessReport(for: newProj)
            generated.append((
                title: "\(store.displayTitle(name: cleanStrain, sku: sku)) #\(batchNum)",
                subtitle: "\(selectedPhase.rawValue) • \(containerName.isEmpty ? "Pot/Tub" : containerName)",
                date: formattedDate,
                qr: richQRText
            ))
        }
        
        if autoDeductRecipeIngredients, let recipe = selectedRecipe, !recipe.ingredients.isEmpty {
            var deductedCount = 0
            for ing in recipe.ingredients {
                let totalDeduct = ing.amountPerBatch * Double(batchQuantity)
                if let sIdx = store.db.supplies.firstIndex(where: {
                    if let lId = ing.linkedSupplyID, $0.id == lId { return true }
                    return $0.name.localizedCaseInsensitiveContains(ing.name) || ing.name.localizedCaseInsensitiveContains($0.name)
                }) {
                    store.db.supplies[sIdx].quantity = max(0, store.db.supplies[sIdx].quantity - totalDeduct)
                    deductedCount += 1
                }
            }
            if deductedCount > 0 {
                MycoSyncManager.shared.triggerToast(
                    message: store.t(
                        nl: "✅ \(deductedCount) ingrediënten van '\(recipe.name)' afgeboekt (\(batchQuantity)x)",
                        en: "✅ Deducted \(deductedCount) ingredients for '\(recipe.name)' (\(batchQuantity)x)"
                    )
                )
            }
        } else if autoDeductSupply, let selId = selectedSupplyID,
           let sIdx = store.db.supplies.firstIndex(where: { $0.id == selId }) {
            let totalDeduct = deductAmountPerBatch * Double(batchQuantity)
            store.db.supplies[sIdx].quantity = max(0, store.db.supplies[sIdx].quantity - totalDeduct)
            MycoSyncManager.shared.triggerToast(
                message: store.t(
                    nl: "\(String(format: "%.1f", totalDeduct)) \(store.db.supplies[sIdx].unit) afgeboekt van \(store.db.supplies[sIdx].name)",
                    en: "Deducted \(String(format: "%.1f", totalDeduct)) \(store.db.supplies[sIdx].unit) from \(store.db.supplies[sIdx].name)"
                )
            )
        }
        store.save()
        activeLabels = BatchLabelsWrapper(labels: generated)
    }
}

// MARK: - 10. PROJECT DETAIL WORKSPACE (TIMELINE, GENETICS, SETUP, FLUSHES)
struct ProjectDetailView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    
    @State private var selectedSection = 0
    @State private var showAddLog = false
    @State private var showAddHarvest = false
    @State private var showEditProject = false
    @State private var editingLog: GrowLog? = nil
    @State private var editingHarvest: HarvestRecord? = nil
    @State private var showQRLabel = false
    @State private var showArchiveConfirmation = false
    @State private var showLinkParentSheet = false
    @State private var activeExportURL: IdentifiableURL? = nil
    
    private var projectIndex: Int? {
        store.db.projects.firstIndex(where: { $0.id == projectID })
    }
    
    var body: some View {
        Group {
            if let idx = projectIndex {
                let project = store.db.projects[idx]
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Top Status & Progress Card
                        MycoCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 14) {
                                    CircularProgressRing(
                                        progress: project.normalizedColonizationPercent,
                                        color: project.phase.color,
                                        subtitle: project.skuCode
                                    )
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("\(store.displayTitle(name: project.strainName, sku: project.skuCode)) #\(project.batchNumber)")
                                            .font(.title3.bold())
                                            .foregroundColor(.white)
                                        Picker(store.t(nl: "Fase", en: "Phase"), selection: $store.db.projects[idx].phase) {
                                            ForEach(GrowPhase.allCases, id: \.self) { phase in
                                                Text(phase.localized(isEnglish: store.isEnglish)).tag(phase)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(MycoTheme.blue)
                                        .onChange(of: store.db.projects[idx].phase) { _, newPhase in
                                            if newPhase == .fruiting || newPhase == .flushing {
                                                store.db.projects[idx].colonizationPercent = 100.0
                                            }
                                            store.save()
                                        }
                                    }
                                    Spacer()
                                }
                                
                                // Cumulative Biological Efficiency (BE%) summary if harvests exist
                                if let be = store.bePercent(for: project.id), be > 0 {
                                    let flushesCount = store.projectHarvests(for: project.id).count
                                    let totalWet = store.totalHarvestWetGrams(for: project.id)
                                    let totalDry = store.totalHarvestDryGrams(for: project.id)
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "chart.line.uptrend.xyaxis")
                                                    .foregroundColor(be >= 100 ? MycoTheme.green : (be >= 70 ? MycoTheme.amber : MycoTheme.blue))
                                                Text(String(format: "%.1f%% BE", be))
                                                    .font(.system(.subheadline, design: .monospaced).bold())
                                                    .foregroundColor(.white)
                                                Text(be >= 100 ? "🏆 Master Yield" : (be >= 70 ? "⚡ Hoge Opbrengst" : "🌱 Stabiel"))
                                                    .font(.caption2.bold())
                                                    .foregroundColor(be >= 100 ? MycoTheme.green : (be >= 70 ? MycoTheme.amber : MycoTheme.blue))
                                            }
                                            Text("\(flushesCount) \(flushesCount == 1 ? "flush" : "flushes") • \(String(format: "%.0fg vers / %.1fg droog", totalWet, totalDry))")
                                                .font(.caption2)
                                                .foregroundColor(MycoTheme.textSecondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(8)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(8)
                                }

                                // Colonization / Progress Section
                                if project.phase == .fruiting || project.phase == .flushing {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(MycoTheme.green)
                                        Text(store.t(nl: "Kolonisatie 100% Voltooid", en: "Colonization 100% Complete"))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(project.phase.localized(isEnglish: store.isEnglish))
                                            .font(.caption.bold())
                                            .foregroundColor(project.phase.color)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(project.phase.color.opacity(0.15))
                                            .cornerRadius(6)
                                    }
                                    .padding(.vertical, 4)
                                } else {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(store.t(nl: "Kolonisatie / Voortgang", en: "Colonization / Progress"))
                                                .font(.caption)
                                                .foregroundColor(MycoTheme.textSecondary)
                                            Spacer()
                                            Text("\(Int(round(project.normalizedColonizationPercent)))%")
                                                .font(.system(.caption, design: .monospaced).bold())
                                                .foregroundColor(.white)
                                        }
                                        Slider(
                                            value: Binding(
                                                get: {
                                                    project.normalizedColonizationPercent
                                                },
                                                set: { newVal in
                                                    store.db.projects[idx].colonizationPercent = newVal
                                                    store.save()
                                                }
                                            ),
                                            in: 0...100,
                                            step: 5
                                        )
                                        .tint(MycoTheme.blue)
                                        
                                        // Quick phase advancement button when reaching 100%
                                        if project.normalizedColonizationPercent >= 100.0 {
                                            if project.phase == .spawn {
                                                Button {
                                                    withAnimation {
                                                        store.db.projects[idx].phase = .bulk
                                                        store.db.projects[idx].colonizationPercent = 0.0
                                                        store.save()
                                                    }
                                                } label: {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "arrow.right.circle.fill")
                                                        Text(store.t(nl: "Broed 100% gekoloniseerd ➔ Zet over naar Bulk (S2B)", en: "Spawn 100% colonized ➔ Transfer to Bulk"))
                                                            .fontWeight(.semibold)
                                                    }
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(MycoTheme.green)
                                                    .cornerRadius(8)
                                                }
                                                .padding(.top, 2)
                                            } else if project.phase == .bulk {
                                                Button {
                                                    withAnimation {
                                                        store.db.projects[idx].phase = .fruiting
                                                        store.db.projects[idx].colonizationPercent = 100.0
                                                        store.save()
                                                    }
                                                } label: {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "sparkles")
                                                        Text(store.t(nl: "Substraat 100% gekoloniseerd ➔ Start Vruchtfase", en: "Substrate 100% colonized ➔ Start Fruiting"))
                                                            .fontWeight(.semibold)
                                                    }
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(MycoTheme.green)
                                                    .cornerRadius(8)
                                                }
                                                .padding(.top, 2)
                                            }
                                        }
                                    }
                                }
                                
                                // Status Tags Chips
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(store.t(nl: "Status Tags:", en: "Status Tags:"))
                                            .font(.caption2.bold())
                                            .foregroundColor(MycoTheme.textSecondary)
                                        Spacer()
                                        if let bDate = project.lastBreakAndShakeDate {
                                            Text("🫨 B&S: \(bDate.formatted(date: .numeric, time: .omitted))")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(MycoTheme.amber)
                                        }
                                    }
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            let availableChips = [
                                                "🫨 B&S Uitgevoerd",
                                                "🌱 Pins Gespot",
                                                "🍄 Flush 1",
                                                "🍄 Flush 2",
                                                "🍄 Flush 3",
                                                "⚠️ Quarantaine",
                                                "🔬 Kloon Kandidaat",
                                                "⭐ Favoriet"
                                            ]
                                            ForEach(availableChips, id: \.self) { chip in
                                                let isSelected = project.tags.contains(chip)
                                                Button {
                                                    withAnimation {
                                                        if isSelected {
                                                            store.db.projects[idx].tags.removeAll { $0 == chip }
                                                        } else {
                                                            store.db.projects[idx].tags.append(chip)
                                                        }
                                                        store.save()
                                                        MycoSyncManager.shared.sendSyncPayload(reason: "tags_updated")
                                                    }
                                                } label: {
                                                    Text(chip)
                                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(
                                                            isSelected ?
                                                                (chip.contains("Quarantaine") ? MycoTheme.red.opacity(0.3) :
                                                                 chip.contains("B&S") ? MycoTheme.amber.opacity(0.3) :
                                                                 MycoTheme.blue.opacity(0.3))
                                                                : MycoTheme.bg
                                                        )
                                                        .foregroundColor(
                                                            isSelected ? .white : MycoTheme.textSecondary
                                                        )
                                                        .cornerRadius(6)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 6)
                                                                .stroke(
                                                                    isSelected ?
                                                                        (chip.contains("Quarantaine") ? MycoTheme.red :
                                                                         chip.contains("B&S") ? MycoTheme.amber :
                                                                         MycoTheme.blue)
                                                                        : MycoTheme.border,
                                                                    lineWidth: 1
                                                                )
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                                
                                // Quick Actions Row
                                HStack(spacing: 8) {
                                    quickButton(icon: "plus.bubble.fill", label: store.t(nl: "+ Log", en: "+ Log")) {
                                        showAddLog = true
                                    }
                                    quickButton(icon: "waveform.path.ecg", label: store.t(nl: "🫨 B&S", en: "🫨 B&S")) {
                                        handleBreakAndShake(for: project, index: idx)
                                    }
                                    quickButton(icon: "sparkles", label: store.t(nl: "🌱 Pins", en: "🌱 Pins")) {
                                        handlePinsSpotted(for: project, index: idx)
                                    }
                                    quickButton(icon: "leaf.fill", label: store.t(nl: "+ Oogst", en: "+ Harvest")) {
                                        showAddHarvest = true
                                    }
                                }
                            }
                        }
                        
                        // Segmented Control
                        Picker("Sectie", selection: $selectedSection) {
                            Text(store.t(nl: "Tijdlijn", en: "Timeline")).tag(0)
                            Text(store.t(nl: "Oogst & Droog", en: "Harvest & Dry")).tag(1)
                            Text(store.t(nl: "Setup & Info", en: "Setup & Info")).tag(2)
                            Text(store.t(nl: "Lab Apparatuur", en: "Lab Equipment")).tag(3)
                        }
                        .pickerStyle(.segmented)
                        
                        if selectedSection == 0 {
                            timelineSection(for: project)
                        } else if selectedSection == 1 {
                            harvestSection(for: project)
                        } else if selectedSection == 2 {
                            setupAndLineageSection(for: project, index: idx)
                        } else {
                            labEquipmentSection(for: project)
                        }
                    }
                    .padding(16)
                }
                .background(MycoTheme.bg)
                .navigationTitle("\(store.displayTitle(name: project.strainName, sku: project.skuCode)) #\(project.batchNumber)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            Button {
                                showQRLabel = true
                            } label: {
                                Image(systemName: "qrcode")
                                    .foregroundColor(MycoTheme.blue)
                            }
                            Menu {
                                Button {
                                    showEditProject = true
                                } label: {
                                    Label(store.t(nl: "Bewerk Batch Setup", en: "Edit Batch Setup"), systemImage: "pencil")
                                }

                                Divider()

                                Button {
                                    exportReportPDF(project: project)
                                } label: {
                                    Label(store.t(nl: "Deel PDF Kweekrapport", en: "Share PDF Grow Report"), systemImage: "doc.text.fill")
                                }
                                
                                Button {
                                    exportCertificatePDF(project: project)
                                } label: {
                                    Label(store.t(nl: "Deel Batch Certificaat (PDF)", en: "Share Batch Certificate (PDF)"), systemImage: "checkmark.seal.fill")
                                }
                                
                                Button {
                                    exportReportCSV(project: project)
                                } label: {
                                    Label(store.t(nl: "Exporteer CSV Gegevens", en: "Export CSV Data"), systemImage: "tablecells.badge.ellipsis")
                                }
                                
                                Divider()
                                
                                Button {
                                    withAnimation {
                                        store.db.projects[idx].isArchived.toggle()
                                        store.save()
                                    }
                                } label: {
                                    Label(
                                        project.isArchived ? store.t(nl: "Zet terug naar Actief", en: "Restore to Active") : store.t(nl: "Archiveer Batch", en: "Archive Batch"),
                                        systemImage: project.isArchived ? "tray.and.arrow.up" : "archivebox"
                                    )
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    withAnimation {
                                        store.deleteProject(id: project.id)
                                        dismiss()
                                    }
                                } label: {
                                    Label(store.t(nl: "Verwijder Batch", en: "Delete Batch"), systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showAddLog) {
                    AddLogSheetView(projectID: project.id)
                        .environmentObject(store)
                }
                .sheet(isPresented: $showAddHarvest) {
                    AddHarvestSheetView(project: project)
                        .environmentObject(store)
                }
                .sheet(isPresented: $showQRLabel) {
                    NavigationStack {
                        let formattedDate = project.startDate.formatted(date: .numeric, time: .omitted)
                        let richQR = store.generateTransparentProcessReport(for: project)
                        QRLabelStudioView(labels: [(
                            title: "\(store.displayTitle(name: project.strainName, sku: project.skuCode)) #\(project.batchNumber)",
                            subtitle: "\(project.phase.rawValue) • \(project.containerName)",
                            date: formattedDate,
                            qr: richQR
                        )])
                        .environmentObject(store)
                    }
                }
                .sheet(item: $activeExportURL) { item in
                    ActivityViewWrapper(activityItems: [item.url])
                }
                .sheet(isPresented: $showLinkParentSheet) {
                    LinkParentCultureSheetView(projectID: project.id)
                        .environmentObject(store)
                }
                .sheet(isPresented: $showEditProject) {
                    EditProjectSheetView(project: project)
                        .environmentObject(store)
                }
                .sheet(item: $editingLog) { log in
                    EditGrowLogSheetView(log: log)
                        .environmentObject(store)
                }
                .sheet(item: $editingHarvest) { harvest in
                    EditHarvestRecordSheetView(harvest: harvest)
                        .environmentObject(store)
                }

            } else {
                Text("Batch niet gevonden")
                    .foregroundColor(.white)
            }
        }
    }
    
    private func quickButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(MycoTheme.bg)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(MycoTheme.border, lineWidth: 1))
        }
    }
    
    private func quickLogAction(_ action: String, for project: GrowProject) {
        let log = GrowLog(
            projectID: project.id,
            actionType: action,
            temperatureC: project.latestTempC,
            humidityPct: project.latestHumidityPct,
            notes: "Snel gelogd vanaf projectkaart."
        )
        store.db.logs.insert(log, at: 0)
        store.save()
    }
    
    private func handleBreakAndShake(for project: GrowProject, index: Int) {
        store.db.projects[index].lastBreakAndShakeDate = Date()
        if !store.db.projects[index].tags.contains("🫨 B&S Uitgevoerd") {
            store.db.projects[index].tags.append("🫨 B&S Uitgevoerd")
        }
        let pct = Int(round(project.normalizedColonizationPercent))
        let log = GrowLog(
            projectID: project.id,
            actionType: "Break & Shake",
            temperatureC: project.latestTempC,
            humidityPct: project.latestHumidityPct,
            notes: store.t(nl: "🫨 Break & Shake handmatig uitgevoerd bij \(pct)% kolonisatie. Graan/substraat losgeschud voor versnelde en uniforme doorgroei.", en: "🫨 Break & Shake manually performed at \(pct)% colonization. Loosened grain/substrate for accelerated and uniform growth.")
        )
        store.db.logs.insert(log, at: 0)
        store.save()
        MycoSyncManager.shared.sendSyncPayload(reason: "break_and_shake")
    }
    
    private func handlePinsSpotted(for project: GrowProject, index: Int) {
        store.db.projects[index].phase = .fruiting
        store.db.projects[index].colonizationPercent = 100.0
        if !store.db.projects[index].tags.contains("🌱 Pins Gespot") {
            store.db.projects[index].tags.append("🌱 Pins Gespot")
        }
        let log = GrowLog(
            projectID: project.id,
            actionType: "Pins Gespot",
            temperatureC: project.latestTempC,
            humidityPct: project.latestHumidityPct,
            notes: store.t(nl: "🌱 Eerste primordia / pinnen waargenomen! Kweekfase omgezet naar Vruchtvorming.", en: "🌱 First primordia / pins observed! Grow phase switched to Fruiting.")
        )
        store.db.logs.insert(log, at: 0)
        store.save()
        MycoSyncManager.shared.sendSyncPayload(reason: "pins_spotted")
    }
    
    private func exportReportPDF(project: GrowProject) {
        let url = MycoReportExporter.generateGrowReportPDF(project: project, store: store)
        activeExportURL = IdentifiableURL(url: url)
    }
    
    private func exportCertificatePDF(project: GrowProject) {
        let url = MycoReportExporter.generateBatchCertificatePDF(project: project, store: store)
        activeExportURL = IdentifiableURL(url: url)
    }
    
    private func exportReportCSV(project: GrowProject) {
        let url = MycoReportExporter.generateProjectCSV(project: project, store: store)
        activeExportURL = IdentifiableURL(url: url)
    }
    
    private func getAncestors(for project: GrowProject) -> [CultureItem] {
        var ancestors: [CultureItem] = []
        var curParentID = project.parentCultureID
        var visited = Set<UUID>()
        while let pID = curParentID, !visited.contains(pID), let culture = store.db.cultures.first(where: { $0.id == pID }) {
            visited.insert(pID)
            ancestors.insert(culture, at: 0)
            curParentID = culture.parentID
            if ancestors.count > 12 { break }
        }
        return ancestors
    }
    
    @ViewBuilder
    private func lineageNodeView(icon: String, badge: String, title: String, subtitle: String, status: String, isCurrent: Bool, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(badge)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.18))
                        .foregroundColor(color)
                        .cornerRadius(4)
                }
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(MycoTheme.textSecondary)
                    .lineLimit(1)
                
                if !status.isEmpty {
                    Text(status)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(isCurrent ? MycoTheme.blue : MycoTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .background(isCurrent ? MycoTheme.card.opacity(0.9) : MycoTheme.bg)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrent ? color : MycoTheme.border, lineWidth: isCurrent ? 1.5 : 1)
        )
    }

    @ViewBuilder
    private func lineageConnectorView() -> some View {
        VStack(spacing: 1) {
            Rectangle()
                .fill(MycoTheme.border)
                .frame(width: 2, height: 12)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(MycoTheme.textSecondary)
            Rectangle()
                .fill(MycoTheme.border)
                .frame(width: 2, height: 4)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Section 3: Lab Equipment & Climate Controls
    @ViewBuilder
    private func labEquipmentSection(for project: GrowProject) -> some View {
        VStack(spacing: 14) {
            // Live Climate Monitor Card
            MycoCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "fan.and.light.ceiling.fill")
                            .foregroundColor(MycoTheme.blue)
                        Text(store.t(nl: "Lab Klimaat & Sensoren", en: "Lab Climate & Sensors"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        if store.db.environmentConfig.isAutopilotEnabled {
                            HStack(spacing: 4) {
                                Circle().fill(MycoTheme.green).frame(width: 8, height: 8)
                                Text(store.t(nl: "Autopilot Actief", en: "Autopilot Active"))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(MycoTheme.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(MycoTheme.green.opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        // Temp
                        VStack(spacing: 4) {
                            Text(store.t(nl: "Temperatuur", en: "Temperature"))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                            HStack(spacing: 2) {
                                Image(systemName: "thermometer.medium")
                                    .foregroundColor(MycoTheme.amber)
                                if let temp = store.latestSensorTempC {
                                    Text(String(format: "%.1f°C", temp))
                                        .font(.system(.subheadline, design: .monospaced).bold())
                                        .foregroundColor(.white)
                                } else {
                                    Text("--.-°C")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        
                        // Humidity
                        VStack(spacing: 4) {
                            Text(store.t(nl: "Luchtvochtigheid", en: "Humidity"))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                    .foregroundColor(MycoTheme.blue)
                                if let hum = store.latestSensorHumidityPct {
                                    Text(String(format: "%.0f%% RV", hum))
                                        .font(.system(.subheadline, design: .monospaced).bold())
                                        .foregroundColor(.white)
                                } else {
                                    Text("--% RV")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        
                        // CO2
                        VStack(spacing: 4) {
                            Text("CO₂ Waarde")
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                            HStack(spacing: 2) {
                                Image(systemName: "wind")
                                    .foregroundColor(.cyan)
                                if let co2 = store.latestSensorCo2Ppm {
                                    Text("\(co2) ppm")
                                        .font(.system(.subheadline, design: .monospaced).bold())
                                        .foregroundColor(.white)
                                } else {
                                    Text("-- ppm")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Smart Devices Card (Centraal Beheer in Smart Lab Hub)
            MycoCard {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(MycoTheme.green.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(MycoTheme.green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t(nl: "Smart Hardware & Klimaat", en: "Smart Hardware & Climate"))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text(store.t(
                            nl: "\(store.db.smartDevices.count) apparaten gekoppeld • 24/7 Autopilot actief",
                            en: "\(store.db.smartDevices.count) devices paired • 24/7 Autopilot active"
                        ))
                        .font(.caption2)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    Spacer()
                    NavigationLink {
                        SmartEnvironmentHubView()
                            .environmentObject(store)
                    } label: {
                        Text(store.t(nl: "Naar Hub", en: "To Hub"))
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(MycoTheme.blue.opacity(0.15))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timelineSection(for project: GrowProject) -> some View {
        let projectLogs = store.db.logs.filter { $0.projectID == project.id }
        if projectLogs.isEmpty {
            EmptyStateCard(
                icon: "camera.Macro",
                title: store.t(nl: "Nog geen logboek-items", en: "No log entries yet"),
                message: store.t(nl: "Voeg foto's, temperaturen, luchtvochtigheid of FAE-acties toe om de groei bij te houden.", en: "Add photos, temperatures, humidity, or FAE actions to track growth."),
                buttonTitle: store.t(nl: "+ Eerste Log Toevoegen", en: "+ Add First Log")
            ) {
                showAddLog = true
            }
        } else {
            ForEach(projectLogs) { log in
                MycoCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(store.localizeActionType(log.actionType))
                                .font(.subheadline.bold())
                                .foregroundColor(MycoTheme.blue)
                            Spacer()
                            Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(MycoTheme.textSecondary)
                            
                            Button {
                                editingLog = log
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.blue)
                                    .padding(.leading, 6)
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                withAnimation {
                                    store.deleteLog(id: log.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.red)
                                    .padding(.leading, 6)
                            }
                            .buttonStyle(.plain)
                        }
                        if log.temperatureC != nil || log.humidityPct != nil {
                            HStack(spacing: 14) {
                                if let t = log.temperatureC {
                                    Text(String(format: "Temp: %.1f°C", t))
                                }
                                if let h = log.humidityPct {
                                    Text(String(format: "RV: %.0f%%", h))
                                }
                            }
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(MycoTheme.green)
                        }
                        if !log.notes.isEmpty {
                            Text(log.notes)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        if let data = log.imageData, let uiImg = UIImage(data: data) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                                .frame(maxHeight: 200)
                                .clipped()
                                .cornerRadius(8)
                        }
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation {
                            store.deleteLog(id: log.id)
                        }
                    } label: {
                        Label(store.t(nl: "Verwijder Logboek-item", en: "Delete Log Entry"), systemImage: "trash")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func harvestSection(for project: GrowProject) -> some View {
        let flushes = store.db.harvests.filter { $0.projectID == project.id }.sorted { $0.flushNumber < $1.flushNumber }
        let totalWet = flushes.reduce(0) { $0 + $1.wetWeightGrams }
        let totalDry = flushes.reduce(0) { $0 + $1.dryWeightGrams }
        let bePct = project.drySubstrateWeightGrams > 0 ? (totalWet / project.drySubstrateWeightGrams) * 100.0 : 0
        
        MycoCard {
            HStack {
                VStack(alignment: .leading) {
                    Text(store.t(nl: "Totaal Nat", en: "Total Wet"))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                    Text(String(format: "%.1f g", totalWet))
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text(store.t(nl: "Totaal Droog", en: "Total Dry"))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                    Text(String(format: "%.2f g", totalDry))
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(MycoTheme.green)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text(store.t(nl: "Bio Efficiency", en: "Bio Efficiency"))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                    Text(String(format: "%.1f%%", bePct))
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(MycoTheme.blue)
                }
            }
        }
        
        Button {
            showAddHarvest = true
        } label: {
            Text(store.t(nl: "+ Nieuwe Flush & Droger Run Loggen", en: "+ Log New Flush & Dryer Run"))
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(MycoTheme.green)
                .cornerRadius(10)
        }
        
        ForEach(flushes) { flush in
            MycoCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Flush #\(flush.flushNumber)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text(flush.harvestDate.formatted(date: .numeric, time: .omitted))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(MycoTheme.textSecondary)
                        
                        Button {
                            editingHarvest = flush
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(MycoTheme.blue)
                                .padding(.leading, 6)
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            withAnimation {
                                store.deleteHarvest(id: flush.id)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(MycoTheme.red)
                                .padding(.leading, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 16) {
                        Text(String(format: store.t(nl: "Nat: %.1fg", en: "Wet: %.1fg"), flush.wetWeightGrams))
                        Text(String(format: store.t(nl: "Droog: %.2fg", en: "Dry: %.2fg"), flush.dryWeightGrams))
                            .foregroundColor(MycoTheme.green)
                        Text(String(format: store.t(nl: "Verlies: %.1f%%", en: "Loss: %.1f%%"), flush.moistureLossPct))
                            .foregroundColor(MycoTheme.amber)
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    
                    Text(String(format: store.t(nl: "Voedseldroger — temperatuur: %.0f °C • droogtijd: %.1f uur", en: "Dehydrator — temperature: %.0f °C • drying time: %.1f hrs"), flush.dehydratorTempC, flush.dehydratorHours))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(MycoTheme.textSecondary)
                }
            }
            .contextMenu {
                Button(role: .destructive) {
                    withAnimation {
                        store.deleteHarvest(id: flush.id)
                    }
                } label: {
                    Label(store.t(nl: "Verwijder Flush", en: "Delete Flush"), systemImage: "trash")
                }
            }
        }
    }
    
    @ViewBuilder
    private func setupAndLineageSection(for project: GrowProject, index: Int) -> some View {
        VStack(spacing: 16) {
            // 1. Interactive Visual Lineage Tree Card
            MycoCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .foregroundColor(MycoTheme.blue)
                        Text(store.t(nl: "Visuele Stamboom (Lineage)", en: "Visual Lineage Tree"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            showLinkParentSheet = true
                        } label: {
                            Text(project.parentCultureID == nil ? store.t(nl: "+ Koppel Ouder", en: "+ Link Parent") : store.t(nl: "Wijzig Ouder", en: "Change Parent"))
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(MycoTheme.blue.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                    
                    Divider().background(MycoTheme.border)
                    
                    // Tree Nodes
                    VStack(spacing: 0) {
                        let ancestors = getAncestors(for: project)
                        if ancestors.isEmpty && project.parentCultureID == nil && project.parentCultureLabel.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(MycoTheme.amber)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t(nl: "Direct Gestart (Geen Moedercultuur)", en: "Started Directly (No Parent)"))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Text(store.t(nl: "Deze batch is handmatig gestart zonder gekoppelde cultuur.", en: "This batch was started manually without a linked culture."))
                                        .font(.caption2)
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(MycoTheme.bg)
                            .cornerRadius(8)
                            
                            lineageConnectorView()
                        } else {
                            ForEach(ancestors) { cult in
                                lineageNodeView(
                                    icon: cult.cultureType.lowercased().contains("lc") || cult.cultureType.lowercased().contains("liquid") ? "drop.fill" : (cult.cultureType.lowercased().contains("agar") ? "circle.circle.fill" : "allergens"),
                                    badge: cult.generation,
                                    title: cult.strainName,
                                    subtitle: "\(cult.cultureType) • \(cult.mediaName.isEmpty ? "Standaard media" : cult.mediaName)",
                                    status: cult.status,
                                    isCurrent: false,
                                    color: MycoTheme.blue
                                )
                                
                                lineageConnectorView()
                            }
                            
                            if ancestors.isEmpty && !project.parentCultureLabel.isEmpty {
                                lineageNodeView(
                                    icon: "allergens",
                                    badge: "Ouder",
                                    title: project.parentCultureLabel,
                                    subtitle: store.t(nl: "Geregistreerde Herkomst", en: "Registered Origin"),
                                    status: "Referentie",
                                    isCurrent: false,
                                    color: MycoTheme.amber
                                )
                                
                                lineageConnectorView()
                            }
                        }
                        
                        // Current Batch Node (highlighted)
                        lineageNodeView(
                            icon: "leaf.fill",
                            badge: "Batch #\(project.batchNumber)",
                            title: "\(store.displayTitle(name: project.strainName, sku: project.skuCode))",
                            subtitle: "\(project.phase.rawValue) • \(project.containerName) (\(Int(project.normalizedColonizationPercent))% kolonisatie)",
                            status: project.tags.isEmpty ? "Actieve Kweekbatch" : project.tags.joined(separator: " • "),
                            isCurrent: true,
                            color: project.phase.color
                        )
                        
                        // Flushes of this batch
                        let flushes = store.db.harvests.filter { $0.projectID == project.id }.sorted { $0.flushNumber < $1.flushNumber }
                        if !flushes.isEmpty {
                            lineageConnectorView()
                            
                            ForEach(flushes) { f in
                                lineageNodeView(
                                    icon: "sparkles",
                                    badge: "Flush #\(f.flushNumber)",
                                    title: String(format: "%.1f g nat / %.2f g droog", f.wetWeightGrams, f.dryWeightGrams),
                                    subtitle: "\(f.harvestDate.formatted(date: .numeric, time: .omitted)) • \(String(format: "%.1f%%", f.moistureLossPct)) vochtverlies",
                                    status: "Oogst Voltooid",
                                    isCurrent: false,
                                    color: MycoTheme.green
                                )
                                
                                if f.id != flushes.last?.id {
                                    lineageConnectorView()
                                }
                            }
                        }
                    }
                }
            }
            
            // 2. Export & Share Dossier Card
            MycoCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .foregroundColor(MycoTheme.green)
                        Text(store.t(nl: "Kweekrapport Exporteren & Delen", en: "Export & Share Grow Report"))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Text(store.t(nl: "Deel een officieel MycoLabs kweekrapport met complete tijdlijn, oogststatistieken, bio-efficiency en parameters via PDF of CSV.", en: "Share an official MycoLabs grow report with complete timeline, harvest statistics, bio-efficiency, and parameters via PDF or CSV."))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                        
                    HStack(spacing: 12) {
                        Button {
                            exportReportPDF(project: project)
                        } label: {
                            Label(store.t(nl: "Deel PDF Dossier", en: "Share PDF Report"), systemImage: "doc.text.fill")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(MycoTheme.blue)
                                .cornerRadius(8)
                        }
                        
                        Button {
                            exportReportCSV(project: project)
                        } label: {
                            Label(store.t(nl: "Exporteer CSV", en: "Export CSV"), systemImage: "tablecells.badge.ellipsis")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(MycoTheme.bg)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(MycoTheme.border, lineWidth: 1))
                        }
                    }
                }
            }
            
            // 3. Batch Setup & Specifications
            MycoCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(store.t(nl: "Setup Specificaties", en: "Setup Specifications"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            showEditProject = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                Text(store.t(nl: "Bewerk", en: "Edit"))
                            }
                            .font(.caption.bold())
                            .foregroundColor(MycoTheme.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(MycoTheme.blue.opacity(0.15))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack {
                        Text(store.t(nl: "Container:", en: "Container:"))
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        Text(project.containerName.isEmpty ? "-" : store.localizePresetName(project.containerName))
                            .foregroundColor(.white)
                    }
                    HStack {
                        Text(store.t(nl: "Substraat / Graan:", en: "Substrate / Grain:"))
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        Text(project.substrateName.isEmpty ? "-" : store.localizePresetName(project.substrateName))
                            .foregroundColor(.white)
                    }
                    HStack {
                        Text(store.t(nl: "Droog Substraatgewicht:", en: "Dry Substrate Weight:"))
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        Text(String(format: "%.0f g", project.drySubstrateWeightGrams))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(MycoTheme.green)
                    }
                    HStack {
                        Text(store.t(nl: "Spawn-to-Bulk Ratio:", en: "Spawn-to-Bulk Ratio:"))
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        Text(project.spawnToBulkRatio)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    HStack {
                        Text(store.t(nl: "Sterilisatie:", en: "Sterilization:"))
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        Text(project.sterilizationNotes.isEmpty ? "-" : store.localizePresetNotes(project.sterilizationNotes))
                            .foregroundColor(.white)
                    }
                    HStack {
                        Text(store.t(nl: "Unieke QR-ID:", en: "Unique QR ID:"))
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        Text(project.qrCodeID)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(MycoTheme.blue)
                    }
                }
                .font(.subheadline)
            }
            
            // 4. Delete Project Button
            Button(role: .destructive) {
                withAnimation {
                    store.deleteProject(id: project.id)
                    dismiss()
                }
            } label: {
                Text(store.t(nl: "Verwijder Batch Permanent", en: "Delete Batch Permanently"))
                    .font(.subheadline.bold())
                    .foregroundColor(MycoTheme.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MycoTheme.card)
                    .cornerRadius(10)
            }
        }
    }
}

// MARK: - 10B. LINK PARENT CULTURE SHEET
struct LinkParentCultureSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    
    var body: some View {
        NavigationStack {
            List {
                if let project = store.db.projects.first(where: { $0.id == projectID }),
                   project.parentCultureID != nil {
                    Section {
                        Button(role: .destructive) {
                            if let idx = store.db.projects.firstIndex(where: { $0.id == projectID }) {
                                store.db.projects[idx].parentCultureID = nil
                                store.db.projects[idx].parentCultureLabel = ""
                                store.save()
                                MycoSyncManager.shared.sendSyncPayload(reason: "unlink_culture")
                            }
                            dismiss()
                        } label: {
                            Label(store.t(nl: "Koppeling met ouder verbreken", en: "Unlink parent culture"), systemImage: "link.badge.plus")
                                .foregroundColor(MycoTheme.red)
                        }
                    }
                }
                
                Section(header: Text(store.t(nl: "Selecteer Moedercultuur / Inoculant", en: "Select Mother Culture / Inoculant"))) {
                    if store.db.cultures.isEmpty {
                        Text(store.t(nl: "Geen culturen gevonden in je bibliotheek.", en: "No cultures found in your library."))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    } else {
                        ForEach(store.db.cultures) { culture in
                            Button {
                                if let idx = store.db.projects.firstIndex(where: { $0.id == projectID }) {
                                    store.db.projects[idx].parentCultureID = culture.id
                                    store.db.projects[idx].parentCultureLabel = "\(culture.strainName) (\(culture.generation) • \(culture.qrCodeID))"
                                    store.save()
                                    MycoSyncManager.shared.sendSyncPayload(reason: "link_culture")
                                }
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: culture.cultureType.lowercased().contains("lc") ? "drop.fill" : "circle.circle.fill")
                                        .foregroundColor(MycoTheme.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(culture.strainName)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("\(culture.cultureType) • \(culture.mediaName.isEmpty ? "Geen media" : culture.mediaName)")
                                            .font(.caption)
                                            .foregroundColor(MycoTheme.textSecondary)
                                    }
                                    Spacer()
                                    Text(culture.generation)
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundColor(MycoTheme.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(MycoTheme.blue.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Koppel Ouder Cultuur", en: "Link Mother Culture"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(nl: "Sluit", en: "Close")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - 11. ADD LOG & ADD HARVEST SHEETS
struct AddLogSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    
    @State private var actionType = "Omgevingscheck / Notitie"
    @State private var customAction = ""
    @State private var tempString = "23.0"
    @State private var humidityString = "88"
    @State private var notes = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    private let actions = [
        "Omgevingscheck / Notitie",
        "Inoculatie",
        "Break & Shake (Schudden)",
        "Spawn naar Bulk Substraat",
        "FAE (Ventileren)",
        "Mist (Bevochtigen)",
        "Eerste Pins Zichtbaar",
        "Dunking / Hydratatie",
        "Contaminatie Gevonden",
        "Anders / Zelf typen..."
    ]
    
    var effectiveAction: String {
        actionType == "Anders / Zelf typen..."
            ? (customAction.trimmingCharacters(in: .whitespaces).isEmpty ? "Aangepaste Actie" : customAction)
            : actionType
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(store.t(nl: "Actie", en: "Action")) {
                    Picker(store.t(nl: "Type Actie", en: "Action Type"), selection: $actionType) {
                        ForEach(actions, id: \.self) { a in Text(store.localizeActionType(a)).tag(a) }
                    }
                    if actionType == "Anders / Zelf typen..." {
                        TextField(store.t(nl: "Typ jouw eigen actie / gebeurtenis...", en: "Type your own action / event..."), text: $customAction)
                    }
                }
                Section(store.t(nl: "Omgevingsdata (Optioneel)", en: "Environmental Data (Optional)")) {
                    TextField(store.t(nl: "Temperatuur (°C)", en: "Temperature (°C)"), text: $tempString)
                        .keyboardType(.decimalPad)
                    TextField(store.t(nl: "Luchtvochtigheid (%)", en: "Humidity (%)"), text: $humidityString)
                        .keyboardType(.decimalPad)
                }
                Section(store.t(nl: "Notities & Foto", en: "Notes & Photo")) {
                    TextField(store.t(nl: "Typ je observatie...", en: "Type your observation..."), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(
                            MainActor.assumeIsolated {
                                selectedImageData == nil ? store.t(nl: "Kies Foto uit Bibliotheek", en: "Choose Photo from Library") : store.t(nl: "Foto Geselecteerd ✓", en: "Photo Selected ✓")
                            },
                            systemImage: "photo.on.rectangle"
                        )
                    }
                }
                Section {
                    Button(store.t(nl: "Logboek Opslaan", en: "Save Log")) {
                        saveLog()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(MycoTheme.blue)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Log Toevoegen", en: "Add Log"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuleer") { dismiss() }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImageData = MycoImageHelper.prepareForStorage(data: data) ?? data
                    }
                }
            }
        }
    }
    
    private func saveLog() {
        let t = Double(tempString.replacingOccurrences(of: ",", with: "."))
        let h = Double(humidityString.replacingOccurrences(of: ",", with: "."))
        
        let log = GrowLog(
            projectID: projectID,
            actionType: effectiveAction,
            temperatureC: t,
            humidityPct: h,
            notes: notes,
            imageData: selectedImageData
        )
        store.db.logs.insert(log, at: 0)
        
        if let idx = store.db.projects.firstIndex(where: { $0.id == projectID }) {
            if let t = t { store.db.projects[idx].latestTempC = t }
            if let h = h { store.db.projects[idx].latestHumidityPct = h }
            if actionType == "Contaminatie Gevonden" {
                store.db.projects[idx].phase = .contaminated
            }
        }
        store.save()
        dismiss()
    }
}

struct AddHarvestSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    let project: GrowProject
    
    @State private var flushNumber: Int = 1
    @State private var wetWeightString: String = ""
    @State private var dehydratorTempString: String = ""
    @State private var dehydratorHoursString: String = ""
    @State private var dryWeightString: String = ""
    @State private var moistureRatioPercent: Double = 91.0
    @State private var substrateDryGramsString: String = ""
    @State private var syncToStash: Bool = true
    @State private var notes: String = ""
    
    var wetVal: Double { Double(wetWeightString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var dryVal: Double { Double(dryWeightString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(store.t(nl: "1. Oogst & Flush (Nat-naar-Droog Calculator)", en: "1. Harvest & Flush (Wet-to-Dry Calculator)")) {
                    Stepper(store.t(nl: "Flush Nummer: #\(flushNumber)", en: "Flush Number: #\(flushNumber)"), value: $flushNumber, in: 1...15)
                    
                    HStack {
                        Text(store.t(nl: "Nat Gewicht vers:", en: "Fresh Wet Weight:"))
                        Spacer()
                        TextField(store.t(nl: "bijv. 250", en: "e.g. 250"), text: $wetWeightString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("gram")
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.t(nl: "Vochtpercentage Preset (Myco-norm: 90-92% water):", en: "Moisture Preset (Myco standard: 90-92% water):"))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                        Picker(store.t(nl: "Vochtverlies", en: "Moisture Loss"), selection: $moistureRatioPercent) {
                            Text("90%").tag(90.0)
                            Text("91% (Norm)").tag(91.0)
                            Text("92%").tag(92.0)
                            Text("93%").tag(93.0)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 2)
                    
                    if wetVal > 0 {
                        let estimatedDry = wetVal * (1.0 - (moistureRatioPercent / 100.0))
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "✨ Geschat drooggewicht (~\(Int(moistureRatioPercent))% vocht):", en: "✨ Estimated dry weight (~\(Int(moistureRatioPercent))% water):"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.green)
                                Text(String(format: "%.1f gram cracker-dry", estimatedDry))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Button {
                                dryWeightString = String(format: "%.1f", estimatedDry)
                            } label: {
                                Text(store.t(nl: "Overnemen", en: "Use Value"))
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(MycoTheme.green.opacity(0.2))
                                    .foregroundColor(MycoTheme.green)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    } else if dryVal > 0 {
                        let estimatedWet = dryVal / (1.0 - (moistureRatioPercent / 100.0))
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t(nl: "✨ Geschat vers geoogst:", en: "✨ Estimated fresh harvest:"))
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.amber)
                                Text(String(format: "%.1f gram vers", estimatedWet))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Button {
                                wetWeightString = String(format: "%.1f", estimatedWet)
                            } label: {
                                Text(store.t(nl: "Overnemen", en: "Use Value"))
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(MycoTheme.amber.opacity(0.2))
                                    .foregroundColor(MycoTheme.amber)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section {
                    LabeledContent(store.t(nl: "Droger Temperatuur", en: "Dehydrator Temperature")) {
                        HStack(spacing: 4) {
                            TextField(store.t(nl: "bijv. 55", en: "e.g. 55"), text: $dehydratorTempString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Text("°C")
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    
                    LabeledContent(store.t(nl: "Droogtijd", en: "Drying Time")) {
                        HStack(spacing: 4) {
                            TextField(store.t(nl: "bijv. 12", en: "e.g. 12"), text: $dehydratorHoursString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Text(store.t(nl: "uur", en: "hrs"))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.t(nl: "Richtlijnen volgens mycology literatuur:", en: "Guidelines according to mycology literature:"))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Text(store.t(nl: "• Temperatuur: 45 °C - 55 °C is optimaal. Boven de 60 °C oxideren en degraderen actieve bestanddelen door overmatige hitte.\n• Droogtijd: 8 - 14 uur (gemiddeld 12 uur) tot 'cracker-dry' (de stelen breken direct met een duidelijke knak zonder mee te buigen).", en: "• Temperature: 45°C - 55°C is optimal. Above 60°C active compounds oxidize and degrade.\n• Drying time: 8 - 14 hours (average 12 hours) until 'cracker-dry' (stems snap cleanly without bending)."))
                            .font(.caption)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                    
                    LabeledContent(store.t(nl: "Uiteindelijk Cracker-Dry Gewicht", en: "Final Cracker-Dry Weight")) {
                        HStack(spacing: 4) {
                            TextField(store.t(nl: "bijv. 22.5", en: "e.g. 22.5"), text: $dryWeightString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 85)
                            Text(store.t(nl: "gram", en: "grams"))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                } header: {
                    Text(store.t(nl: "2. Voedseldroger (Dehydrator) Log", en: "2. Dehydrator Log"))
                }
                
                Section(store.t(nl: "3. Biological Efficiency (BE%)", en: "3. Biological Efficiency (BE%)")) {
                    HStack {
                        Text(store.t(nl: "Droog Substraat / Graangewicht:", en: "Dry Substrate / Grain:"))
                        Spacer()
                        TextField(store.t(nl: "bijv. 650", en: "e.g. 650"), text: $substrateDryGramsString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("g")
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    let subWeight = Double(substrateDryGramsString.replacingOccurrences(of: ",", with: ".")) ?? project.drySubstrateWeightGrams
                    if subWeight > 0 && wetVal > 0 {
                        let be = (wetVal / subWeight) * 100.0
                        HStack {
                            Text(store.t(nl: "Deze Flush BE Opbrengst:", en: "This Flush BE Yield:"))
                            Spacer()
                            Text(String(format: "%.1f%% BE", be))
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundColor(be >= 100 ? MycoTheme.green : MycoTheme.blue)
                        }
                        Text(store.t(nl: "100% BE betekent 1 kg verse oogst per 1 kg droog substraat.", en: "100% BE means 1 kg fresh harvest per 1 kg dry substrate."))
                            .font(.caption2)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }
                
                if wetVal > 0 && dryVal > 0 {
                    Section(store.t(nl: "Live Berekening", en: "Live Calculation")) {
                        let loss = ((wetVal - dryVal) / wetVal) * 100.0
                        HStack {
                            Text(store.t(nl: "Vochtverlies:", en: "Moisture Loss:"))
                            Spacer()
                            Text(String(format: "%.1f%% (%.1f g water)", loss, wetVal - dryVal))
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(MycoTheme.amber)
                        }
                    }
                }
                Section(store.t(nl: "Voorraad Synchronisatie", en: "Inventory Synchronization")) {
                    Toggle(store.t(nl: "Tel droog gewicht automatisch op in Stash Vault", en: "Automatically add dry weight to Stash Vault"), isOn: $syncToStash)
                }
                Section {
                    Button(store.t(nl: "Oogst Opslaan", en: "Save Harvest")) {
                        if let subWeight = Double(substrateDryGramsString.replacingOccurrences(of: ",", with: ".")), subWeight > 0 {
                            if let pIdx = store.db.projects.firstIndex(where: { $0.id == project.id }) {
                                store.db.projects[pIdx].drySubstrateWeightGrams = subWeight
                                store.save()
                            }
                        }
                        let record = HarvestRecord(
                            projectID: project.id,
                            strainName: project.strainName,
                            skuCode: project.skuCode,
                            flushNumber: flushNumber,
                            wetWeightGrams: wetVal,
                            dehydratorTempC: Double(dehydratorTempString) ?? 55,
                            dehydratorHours: Double(dehydratorHoursString) ?? 12,
                            dryWeightGrams: dryVal,
                            notes: notes
                        )
                        store.addHarvestAndSyncStash(record, syncToStash: syncToStash, potency: 1.0)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(MycoTheme.green)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Oogst & Droger", en: "Harvest & Dehydrator"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                }
            }
            .onAppear {
                if project.drySubstrateWeightGrams > 0 {
                    substrateDryGramsString = String(format: "%.0f", project.drySubstrateWeightGrams)
                }
            }
        }
    }
}

// MARK: - 12. TAB 2: CULTURES & GENETICS LAB (AGAR, LC, TRANSFERS & QR)
struct AddStrainSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var species = "Pleurotus ostreatus (Oesterzwam)"
    @State private var customSpecies = ""
    @State private var mushroomType: MushroomApplicationType = .culinary
    @State private var colonizationSpeed: ColonizationSpeed = .moderate
    @State private var difficulty: CultivationDifficulty = .beginner
    @State private var potencyMultiplier = 1.0
    @State private var notes = ""
    
    private var commonSpecies: [String] { StrainModel.commonSpecies }
    
    var effectiveSpecies: String {
        species == "Anders / Zelf typen..."
            ? (customSpecies.trimmingCharacters(in: .whitespaces).isEmpty ? store.t(nl: "Onbekende soort", en: "Unknown species") : customSpecies)
            : species
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(store.t(nl: "Soort & Naam", en: "Strain & Name")) {
                    TextField(store.t(nl: "Naam van Soort / Strain (bijv. Lion's Mane)", en: "Strain name (e.g. Lion's Mane)"), text: $name)
                    Picker(store.t(nl: "Botanische Soort", en: "Botanical Species"), selection: $species) {
                        ForEach(commonSpecies, id: \.self) { sp in Text(store.localizeBotanicalSpecies(sp)).tag(sp) }
                    }
                    .onChange(of: species) { _, newSpecies in
                        if newSpecies != "Anders / Zelf typen..." {
                            mushroomType = StrainModel.defaultType(for: newSpecies)
                            colonizationSpeed = StrainModel.defaultSpeed(for: newSpecies)
                            difficulty = StrainModel.defaultDifficulty(for: newSpecies)
                        }
                    }
                    
                    if species == "Anders / Zelf typen..." {
                        TextField(store.t(nl: "Typ eigen soort...", en: "Type custom species..."), text: $customSpecies)
                    }
                }
                
                Section(store.t(nl: "Kweekkenmerken & Toepassing", en: "Cultivation & Application")) {
                    Picker(store.t(nl: "Type Paddenstoel", en: "Mushroom Type"), selection: $mushroomType) {
                        ForEach(MushroomApplicationType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.localized(isEnglish: store.isEnglish))
                            }
                            .tag(type)
                        }
                    }
                    
                    Picker(store.t(nl: "Kolonisatiesnelheid", en: "Colonization Speed"), selection: $colonizationSpeed) {
                        ForEach(ColonizationSpeed.allCases, id: \.self) { speed in
                            HStack {
                                Image(systemName: speed.icon)
                                Text(speed.localized(isEnglish: store.isEnglish))
                            }
                            .tag(speed)
                        }
                    }
                    
                    Picker(store.t(nl: "Moeilijkheidsgraad", en: "Difficulty"), selection: $difficulty) {
                        ForEach(CultivationDifficulty.allCases, id: \.self) { diff in
                            Text("\(diff.stars) \(diff.localized(isEnglish: store.isEnglish))").tag(diff)
                        }
                    }
                }
                
                if mushroomType == .active {
                    Section(store.t(nl: "Potentie & Sterkte (Actief)", en: "Potency & Strength (Active)")) {
                        CreativePotencySelectorView(potency: $potencyMultiplier)
                    }
                }
                
                Section(store.t(nl: "Notities", en: "Notes")) {
                    TextField(store.t(nl: "Notities (bijv. snelle kolonisator, dichte flushes)", en: "Notes (e.g. fast colonizer, dense flushes)"), text: $notes, axis: .vertical)
                }
                
                Section {
                    Button(store.t(nl: "Soort Opslaan in Bibliotheek", en: "Save Strain to Library")) {
                        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanName.isEmpty else { return }
                        let sku = store.nextSKU(prefix: "STR")
                        let model = StrainModel(
                            name: cleanName,
                            skuCode: sku,
                            species: effectiveSpecies,
                            mushroomType: mushroomType,
                            colonizationSpeed: colonizationSpeed,
                            difficulty: difficulty,
                            potencyMultiplier: (mushroomType == .active) ? potencyMultiplier : 0.0,
                            notes: notes
                        )
                        store.db.strains.append(model)
                        store.save()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(name.isEmpty ? Color.gray : MycoTheme.blue)
                    .disabled(name.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Soort Toevoegen", en: "Add Strain"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                }
            }
        }
    }
}

struct AddCultureSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var strainName = ""
    
    init(initialStrainName: String = "") {
        _strainName = State(initialValue: initialStrainName)
    }
    @State private var species: String = "Pleurotus ostreatus (Oesterzwam)"
    @State private var customSpecies: String = ""
    @State private var cultureType = "Vloeibare Cultuur (LC)"
    @State private var customCultureType = ""
    @State private var generation = "LC-1"
    @State private var mediaName = ""
    @State private var status = "Kolonisatie"
    @State private var customStatus = ""
    @State private var notes = ""
    
    private let types = [
        "Vloeibare Cultuur (Liquid Culture - LC)",
        "Agar Petrischaal (Myceliumplaat)",
        "Agar Schuinbuis / Slant (Langetermijnopslag)",
        "Sporenspuit / Sporenprint (Sporensuspensie)",
        "Spore Swab (Katoenstaafje)",
        "Weefselkloon (Biopsie vers vruchtlichaam)",
        "Moederbroed / Graanbroed (Master Grain)",
        "Anders / Zelf typen..."
    ]
    private let statuses = [
        "Actieve Groei / Incubatiefase (Kolonisatie gaande)",
        "Volledig Gekoloniseerd / Klaar voor Gebruik (Axenisch)",
        "Koude Bewaring / 4°C Koelkast (Rustfase / Opslag)",
        "Quarantaine / Zuiverheidscontrole (In observatie)",
        "Doorgeënt / Subcultuur Gemaakt (Generatie vervolg)",
        "Verouderd / Uitgeput (Senescent / Verzwakt)",
        "Gecontamineerd / Besmet (Verworpen)",
        "Anders / Zelf typen..."
    ]
    
    var effectiveCultureType: String {
        cultureType == "Anders / Zelf typen..."
            ? (customCultureType.trimmingCharacters(in: .whitespaces).isEmpty ? store.t(nl: "Eigen Cultuur", en: "Custom Culture") : customCultureType)
            : cultureType
    }
    
    var effectiveStatus: String {
        status == "Anders / Zelf typen..."
            ? (customStatus.trimmingCharacters(in: .whitespaces).isEmpty ? store.t(nl: "Aangepast", en: "Custom") : customStatus)
            : status
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(store.t(nl: "Genetica & Soort", en: "Genetics & Strain")) {
                    if !store.db.strains.isEmpty {
                        Picker(store.t(nl: "Kies uit jouw soorten", en: "Choose from your strains"), selection: $strainName) {
                            Text(store.t(nl: "Typ handmatig hieronder...", en: "Type manually below...")).tag("")
                            ForEach(store.db.strains) { s in
                                Text(s.name).tag(s.name)
                            }
                        }
                    }
                    TextField(store.t(nl: "Naam van Soort / Strain", en: "Strain Name"), text: $strainName)
                    
                    let cleanStrain = strainName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let isNewStrain = !cleanStrain.isEmpty && !store.db.strains.contains(where: { $0.name.caseInsensitiveCompare(cleanStrain) == .orderedSame })
                    if isNewStrain {
                        Picker(store.t(nl: "Botanische Soort (voor nieuwe strain)", en: "Botanical Species (for new strain)"), selection: $species) {
                            ForEach(StrainModel.commonSpecies, id: \.self) { sp in
                                Text(store.localizeBotanicalSpecies(sp)).tag(sp)
                            }
                        }
                        if species == "Anders / Zelf typen..." {
                            TextField(store.t(nl: "Typ eigen botanische soort...", en: "Type custom botanical species..."), text: $customSpecies)
                        }
                    }
                }
                
                Section(store.t(nl: "Type Cultuur & Generatie", en: "Culture Type & Generation")) {
                    Picker(store.t(nl: "Type Cultuur", en: "Culture Type"), selection: $cultureType) {
                        ForEach(types, id: \.self) { t in Text(store.localizeCultureType(t)).tag(t) }
                    }
                    if cultureType == "Anders / Zelf typen..." {
                        TextField(store.t(nl: "Typ eigen type cultuur (bijv. Spore Swab, Slant, Broed)", en: "Type custom culture type (e.g. Spore Swab, Slant, Spawn)"), text: $customCultureType)
                    }
                    TextField(store.t(nl: "Generatie Code (bijv. T0, T1, LC-1)", en: "Generation Code (e.g. T0, T1, LC-1)"), text: $generation)
                }
                
                Section(store.t(nl: "Voedingsbodem & Status", en: "Growth Medium & Status")) {
                    let mediaPresets = store.db.presets.filter { $0.category == .media }
                    if !mediaPresets.isEmpty {
                        Picker(store.t(nl: "Kies Media Preset", en: "Choose Media Preset"), selection: $mediaName) {
                            Text(store.t(nl: "Handmatig / Zelf typen...", en: "Manual / Type custom...")).tag("")
                            ForEach(mediaPresets) { p in Text(store.localizePresetName(p.name)).tag(p.name) }
                        }
                    }
                    TextField(store.t(nl: "Voedingsbodem / Media (bijv. LME + Pepton)", en: "Growth Medium / Media (e.g. LME + Peptone)"), text: $mediaName)
                    
                    Picker(store.t(nl: "Status", en: "Status"), selection: $status) {
                        ForEach(statuses, id: \.self) { s in Text(store.localizeCultureStatus(s)).tag(s) }
                    }
                    if status == "Anders / Zelf typen..." {
                        TextField(store.t(nl: "Typ eigen status (bijv. Wacht op test)", en: "Type custom status (e.g. Awaiting test)"), text: $customStatus)
                    }
                    TextField(store.t(nl: "Optionele notities", en: "Optional notes"), text: $notes)
                }
                
                Section {
                    Button(store.t(nl: "Cultuur Opslaan & Genereer QR", en: "Save Culture & Generate QR")) {
                        let sku = store.nextSKU(prefix: "CLT")
                        let newCult = CultureItem(
                            strainName: strainName,
                            skuCode: sku,
                            cultureType: effectiveCultureType,
                            generation: generation,
                            parentLabel: "",
                            mediaName: mediaName,
                            status: effectiveStatus,
                            qrCodeID: "QR-\(sku)-\(Int.random(in: 100...999))",
                            notes: notes
                        )
                        store.db.cultures.insert(newCult, at: 0)
                        
                        let cleanStrain = strainName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleanStrain.isEmpty && !store.db.strains.contains(where: { $0.name.caseInsensitiveCompare(cleanStrain) == .orderedSame }) {
                            let effectiveSpecies: String
                            if species == "Anders / Zelf typen..." {
                                let trimmed = customSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
                                effectiveSpecies = trimmed.isEmpty ? "Eigen Soort" : trimmed
                            } else {
                                effectiveSpecies = species
                            }
                            store.db.strains.append(StrainModel(name: cleanStrain, skuCode: sku, species: effectiveSpecies, potencyMultiplier: 1.0, notes: ""))
                        }
                        store.save()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(strainName.isEmpty ? Color.gray : MycoTheme.blue)
                    .disabled(strainName.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Nieuwe Cultuur", en: "New Culture"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - 13. TAB 3: STASH VAULT & LAB INVENTORY
struct AddStashJarSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @State private var strainName = ""
    @State private var dryGrams = ""
    @State private var potency = 1.0
    @State private var storageMethod = "Mason Jar + Silica"
    @State private var customStorage = ""
    
    private let storageMethods = [
        "Mason Jar + Silica",
        "Vacuüm geseald + Silica",
        "Mylar Zak + Zuurstofabsorbeerder",
        "Diepvries (-20°C) luchtdicht",
        "Anders / Zelf typen..."
    ]
    
    var effectiveStorage: String {
        storageMethod == "Anders / Zelf typen..."
            ? (customStorage.trimmingCharacters(in: .whitespaces).isEmpty ? "Eigen Bewaarwijze" : customStorage)
            : storageMethod
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(store.t(nl: "Soort & Gewicht", en: "Strain & Weight")) {
                    if !store.db.strains.isEmpty {
                        Picker(store.t(nl: "Kies uit jouw soorten", en: "Choose from your strains"), selection: $strainName) {
                            Text(store.t(nl: "Typ handmatig hieronder...", en: "Type manually below...")).tag("")
                            ForEach(store.db.strains) { s in Text(s.name).tag(s.name) }
                        }
                    }
                    TextField(store.t(nl: "Naam van Soort (bijv. Lion's Mane)", en: "Strain name (e.g. Lion's Mane)"), text: $strainName)
                    TextField(store.t(nl: "Droog Gewicht (gram)", en: "Dry Weight (grams)"), text: $dryGrams)
                        .keyboardType(.decimalPad)
                }
                
                Section(store.t(nl: "Potentie & Kwaliteit", en: "Potency & Quality")) {
                    CreativePotencySelectorView(potency: $potency)
                }
                
                Section(store.t(nl: "Bewaarwijze", en: "Storage Method")) {
                    Picker(store.t(nl: "Methode", en: "Method"), selection: $storageMethod) {
                        ForEach(storageMethods, id: \.self) { m in Text(m).tag(m) }
                    }
                    if storageMethod == "Anders / Zelf typen..." {
                        TextField(store.t(nl: "Typ eigen bewaarwijze...", en: "Type custom storage method..."), text: $customStorage)
                    }
                }
                
                Section {
                    Button(store.t(nl: "Pot Opslaan in Voorraad", en: "Save Jar to Stash")) {
                        let sku = store.nextSKU(prefix: "JAR")
                        let jar = StashJar(
                            strainName: strainName,
                            skuCode: sku,
                            potencyMultiplier: potency,
                            availableDryGrams: Double(dryGrams.replacingOccurrences(of: ",", with: ".")) ?? 0,
                            storageMethod: effectiveStorage,
                            qrCodeID: "QR-\(sku)-\(Int.random(in: 100...999))"
                        )
                        store.db.stash.append(jar)
                        store.save()
                        dismiss()
                    }
                    .disabled(strainName.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Voorraadpot Toevoegen", en: "Add Stash Jar"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() } }
            }
        }
    }
}

struct AddLabSupplySheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "Substraat & Graan"
    @State private var customCategory = ""
    @State private var quantity = "1"
    @State private var unit = "stuks"
    @State private var customUnit = ""
    @State private var minThreshold = "1"
    
    private let categories = [
        "Graan & Broed (Haver, Rogge, Vogelzaad)",
        "Bulk Substraat (Coco Coir, Vermiculiet, Gips)",
        "Voedingsbodem & Media (Agar Agar, LME, Pepton)",
        "Potten, Zakken & Glaswerk (Mason Jars, Spawn Bags)",
        "Kweekbakken & Monotubs (Tubs, Liners)",
        "Entmateriaal & Injectie (Spuiten, Naalden, Luer Lock)",
        "Beluchting & Filters (Micropore tape, Filter discs)",
        "Lab Gereedschap (Scalpel, Entnaald, Parafilm)",
        "Desinfectie & Hygiëne (IPA 70%, Handschoenen, Bleek)",
        "Klimaat & Elektronica (Warmtemat, Sensoren)",
        "Anders / Zelf typen..."
    ]
    private let units = ["stuks", "gram", "kg", "ml", "L", "Anders / Zelf typen..."]
    
    var effectiveCategory: String {
        category == "Anders / Zelf typen..."
            ? (customCategory.trimmingCharacters(in: .whitespaces).isEmpty ? "Diversen" : customCategory)
            : category
    }
    
    var effectiveUnit: String {
        unit == "Anders / Zelf typen..."
            ? (customUnit.trimmingCharacters(in: .whitespaces).isEmpty ? "eenheid" : customUnit)
            : unit
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(store.t(nl: "Item & Categorie", en: "Item & Category")) {
                    TextField(store.t(nl: "Item Naam (bijv. Haverkorrels, MEA poeder)", en: "Item Name (e.g. Oat grain, MEA powder)"), text: $name)
                    Picker(store.t(nl: "Categorie", en: "Category"), selection: $category) {
                        ForEach(categories, id: \.self) { c in Text(store.localizeSupplyCategory(c)).tag(c) }
                    }
                    if category == "Anders / Zelf typen..." {
                        TextField(store.t(nl: "Typ eigen categorie...", en: "Type custom category..."), text: $customCategory)
                    }
                }
                
                Section(store.t(nl: "Voorraad & Eenheid", en: "Inventory & Unit")) {
                    TextField(store.t(nl: "Hoeveelheid", en: "Quantity"), text: $quantity).keyboardType(.decimalPad)
                    Picker(store.t(nl: "Eenheid", en: "Unit"), selection: $unit) {
                        ForEach(units, id: \.self) { u in Text(u).tag(u) }
                    }
                    if unit == "Anders / Zelf typen..." {
                        TextField(store.t(nl: "Typ eigen eenheid...", en: "Type custom unit..."), text: $customUnit)
                    }
                    TextField(store.t(nl: "Waarschuwingsdrempel (Alert bij minder dan)", en: "Warning threshold (Alert below)"), text: $minThreshold).keyboardType(.decimalPad)
                }
                
                Section {
                    Button(store.t(nl: "Opslaan in Voorraad", en: "Save to Stock")) {
                        let item = LabSupplyItem(
                            name: name,
                            category: effectiveCategory,
                            quantity: Double(quantity) ?? 1,
                            unit: effectiveUnit,
                            minThreshold: Double(minThreshold) ?? 0,
                            qrCodeID: "QR-SUP-\(Int.random(in: 1000...9999))"
                        )
                        store.db.supplies.append(item)
                        store.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Lab Item Toevoegen", en: "Add Lab Item"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() } }
            }
        }
    }
}

// MARK: - VOORRAAD VERWERKEN & ZAKKEN MAKEN SHEET
struct DeductSupplySheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    let item: LabSupplyItem
    
    @State private var mode: Int = 0 // 0: Zakken/Porties Maken, 1: Snel Verbruik, 2: Aanvullen
    
    // Mode 0: Zakken / Porties
    @State private var portionMode: Int = 0 // 0: Gelijke Gewichten, 1: Verschillende Gewichten
    @State private var equalCount: Int = 3
    @State private var equalWeightGramsText: String = "400"
    
    // Verschillende zakken gewichten
    @State private var customBags: [Double] = [500, 400, 350]
    @State private var newBagWeightText: String = "400"
    
    // Batch creatie optie
    @State private var createBatches: Bool = true
    @State private var selectedStrain: String = ""
    @State private var containerName: String = "Broedzak met filter"
    @State private var sterilizationProtocol: String = "Graanpotten & Zakken (90m @ 15 PSI)"
    
    // Mode 1: Snel verbruik
    @State private var quickDeductAmountText: String = ""
    
    // Mode 2: Aanvullen
    @State private var replenishAmountText: String = ""
    
    @State private var activeLabels: BatchLabelsWrapper?
    
    var isKg: Bool {
        item.unit.lowercased() == "kg" || item.unit.lowercased() == "kilo"
    }
    
    var isGram: Bool {
        item.unit.lowercased() == "g" || item.unit.lowercased() == "gram"
    }
    
    var isPieces: Bool {
        item.unit.lowercased() == "stuks" || item.unit.lowercased() == "stuk" || item.unit.lowercased() == "zakken"
    }
    
    var totalGramsCalculated: Double {
        if isPieces {
            return 0
        }
        if portionMode == 0 {
            let perBag = Double(equalWeightGramsText.replacingOccurrences(of: ",", with: ".")) ?? 0
            return Double(equalCount) * perBag
        } else {
            return customBags.reduce(0, +)
        }
    }
    
    var totalDeductionInItemUnit: Double {
        if isKg {
            return totalGramsCalculated / 1000.0
        } else if isGram {
            return totalGramsCalculated
        } else if isPieces {
            return Double(portionMode == 0 ? equalCount : customBags.count)
        } else {
            return totalGramsCalculated / 1000.0
        }
    }
    
    var resultingStock: Double {
        max(0, item.quantity - totalDeductionInItemUnit)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Header & Info
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(item.category) • Huidige voorraad: \(store.formatQuantity(item.quantity, unit: item.unit))")
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        Spacer()
                    }
                    
                    Picker(store.t(nl: "Actie", en: "Action"), selection: $mode) {
                        Text(store.t(nl: "🎒 Zakken Maken", en: "🎒 Make Bags")).tag(0)
                        Text(store.t(nl: "⚡ Snel Verbruik", en: "⚡ Quick Deduct")).tag(1)
                        Text(store.t(nl: "➕ Aanvullen", en: "➕ Restock")).tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }
                
                if mode == 0 {
                    // TAB 1: ZAKKEN / PORTIES MAKEN
                    Section(store.t(nl: "Portie Verdeling (Gelijk of Verschillende Gewichten)", en: "Portion Distribution (Equal or Custom Weights)")) {
                        if !isPieces {
                            Picker(store.t(nl: "Type Verdeling", en: "Distribution Type"), selection: $portionMode) {
                                Text(store.t(nl: "Gelijke Zakken", en: "Equal Bags")).tag(0)
                                Text(store.t(nl: "Verschillende Gewichten", en: "Custom Weights")).tag(1)
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        if portionMode == 0 || isPieces {
                            Stepper(store.t(nl: "Aantal Zakken / Porties: \(equalCount)", en: "Number of Bags / Portions: \(equalCount)"), value: $equalCount, in: 1...50)
                            
                            if !isPieces {
                                HStack {
                                    Text(store.t(nl: "Gewicht per zak:", en: "Weight per bag:"))
                                    Spacer()
                                    TextField("400", text: $equalWeightGramsText)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                    Text(store.t(nl: "gram", en: "grams"))
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(["250", "350", "400", "500", "750", "1000"], id: \.self) { preset in
                                            Button("\(preset)g") {
                                                equalWeightGramsText = preset
                                            }
                                            .font(.caption.bold())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(equalWeightGramsText == preset ? MycoTheme.blue : MycoTheme.card)
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                        } else {
                            // Verschillende gewichten per zak
                            ForEach(Array(customBags.enumerated()), id: \.offset) { idx, w in
                                HStack {
                                    Text(store.t(nl: "Zak #\(idx + 1)", en: "Bag #\(idx + 1)"))
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text("\(String(format: "%.0f", w)) gram")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(MycoTheme.green)
                                    Button(role: .destructive) {
                                        customBags.remove(at: idx)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            
                            HStack {
                                TextField(store.t(nl: "Gewicht in gram", en: "Weight in grams"), text: $newBagWeightText)
                                    .keyboardType(.decimalPad)
                                Button(store.t(nl: "+ Extra Zak Toevoegen", en: "+ Add Another Bag")) {
                                    if let val = Double(newBagWeightText.replacingOccurrences(of: ",", with: ".")), val > 0 {
                                        customBags.append(val)
                                    }
                                }
                                .font(.caption.bold())
                                .foregroundColor(MycoTheme.blue)
                            }
                        }
                    }
                    
                    Section(store.t(nl: "Totaal Berekend Verbruik", en: "Total Calculated Usage")) {
                        if !isPieces {
                            HStack {
                                Text(store.t(nl: "Totaal Gewicht:", en: "Total Weight:"))
                                Spacer()
                                Text("\(String(format: "%.0f", totalGramsCalculated)) gram (\(String(format: "%.2f", totalDeductionInItemUnit)) \(item.unit))")
                                    .font(.system(.subheadline, design: .monospaced).bold())
                                    .foregroundColor(MycoTheme.amber)
                            }
                        } else {
                            HStack {
                                Text(store.t(nl: "Aantal Af te Boeken:", en: "Quantity to Deduct:"))
                                Spacer()
                                Text("\(Int(totalDeductionInItemUnit)) \(item.unit)")
                                    .font(.system(.subheadline, design: .monospaced).bold())
                                    .foregroundColor(MycoTheme.amber)
                            }
                        }
                        
                        HStack {
                            Text(store.t(nl: "Resterende Voorraad:", en: "Remaining Stock:"))
                            Spacer()
                            Text(store.formatQuantity(resultingStock, unit: item.unit))
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(resultingStock > 0 ? MycoTheme.green : .red)
                        }
                    }
                    
                    Section(store.t(nl: "Direct Omzetten naar Kweekbatches & QR-Codes", en: "Directly Convert to Grow Batches & QR Codes")) {
                        Toggle(store.t(nl: "Maak direct kweekbatches aan in Dashboard", en: "Directly create grow batches in Dashboard"), isOn: $createBatches)
                        
                        if createBatches {
                            if !store.db.strains.isEmpty {
                                Picker(store.t(nl: "Kies Soort / Strain", en: "Choose Strain"), selection: $selectedStrain) {
                                    Text(store.t(nl: "Kies soort...", en: "Choose strain...")).tag("")
                                    ForEach(store.db.strains) { s in Text(s.name).tag(s.name) }
                                }
                            }
                            if selectedStrain.isEmpty {
                                TextField(store.t(nl: "Typ naam van soort (bijv. Lion's Mane)", en: "Type strain name (e.g. Lion's Mane)"), text: $selectedStrain)
                            }
                            
                            let isAllInOne = item.name.lowercased().contains("alles") || item.name.lowercased().contains("all-in-one")
                            TextField(store.t(nl: "Container type", en: "Container type"), text: $containerName)
                            
                            Text(isAllInOne ? store.t(nl: "Wordt aangemaakt als Alles-in-één kweekbatch met volledige proces-QR.", en: "Will be created as All-in-one grow batch with full process QR.") : store.t(nl: "Elke zak krijgt een eigen unieke traceerbare QR-code met het exacte gewicht van die specifieke zak.", en: "Each bag gets its own unique traceable QR code with the exact weight of that specific bag."))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    
                    Section {
                        Button {
                            processBagsDeduction()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text(createBatches ? store.t(nl: "Boek Af & Maak \(portionMode == 0 ? equalCount : customBags.count) Kweekbatches", en: "Deduct & Create \(portionMode == 0 ? equalCount : customBags.count) Grow Batches") : store.t(nl: "Boek \(String(format: "%.2f", totalDeductionInItemUnit)) \(item.unit) Af", en: "Deduct \(String(format: "%.2f", totalDeductionInItemUnit)) \(item.unit)"))
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(MycoTheme.blue)
                        .disabled(totalDeductionInItemUnit <= 0 || (createBatches && selectedStrain.trimmingCharacters(in: .whitespaces).isEmpty))
                    }
                } else if mode == 1 {
                    // TAB 2: SNEL VERBRUIK
                    Section(store.t(nl: "Snel Afboeken", en: "Quick Deduct")) {
                        TextField(store.t(nl: "Hoeveelheid afboeken in \(item.unit) (bijv. 0.4 of 250)", en: "Amount to deduct in \(item.unit) (e.g. 0.4 or 250)"), text: $quickDeductAmountText)
                            .keyboardType(.decimalPad)
                        
                        if isKg {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach([("100g", "0.1"), ("250g", "0.25"), ("500g", "0.5"), ("1.0 kg", "1.0")], id: \.0) { lbl, val in
                                        Button("- \(lbl)") {
                                            quickDeductAmountText = val
                                        }
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(MycoTheme.card)
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                    }
                                }
                            }
                        } else if isPieces {
                            HStack(spacing: 8) {
                                ForEach([1, 2, 3, 5], id: \.self) { count in
                                    Button("- \(count)") {
                                        quickDeductAmountText = "\(count)"
                                    }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(MycoTheme.card)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    Section {
                        Button(store.t(nl: "Boek Af van Voorraad", en: "Deduct from Stock")) {
                            let clean = quickDeductAmountText.replacingOccurrences(of: ",", with: ".")
                            if let val = Double(clean), val > 0 {
                                if let idx = store.db.supplies.firstIndex(where: { $0.id == item.id }) {
                                    store.db.supplies[idx].quantity = max(0, store.db.supplies[idx].quantity - val)
                                    // updated
                                    store.save()
                                }
                                dismiss()
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(MycoTheme.blue)
                    }
                } else {
                    // TAB 3: AANVULLEN
                    Section(store.t(nl: "Voorraad Aanvullen", en: "Restock Inventory")) {
                        TextField(store.t(nl: "Aantal \(item.unit) toevoegen", en: "Amount of \(item.unit) to add"), text: $replenishAmountText)
                            .keyboardType(.decimalPad)
                    }
                    
                    Section {
                        Button(store.t(nl: "Voorraad Ophogen", en: "Add to Stock")) {
                            let clean = replenishAmountText.replacingOccurrences(of: ",", with: ".")
                            if let val = Double(clean), val > 0 {
                                if let idx = store.db.supplies.firstIndex(where: { $0.id == item.id }) {
                                    store.db.supplies[idx].quantity += val
                                    // updated
                                    store.save()
                                }
                                dismiss()
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(MycoTheme.green)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Voorraad Verwerken", en: "Process Stock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Annuleer", en: "Cancel")) { dismiss() }
                }
            }
            .sheet(item: $activeLabels, onDismiss: { dismiss() }) { wrapper in
                NavigationStack {
                    QRLabelStudioView(labels: wrapper.labels)
                }
            }
        }
    }
    
    private func processBagsDeduction() {
        if let idx = store.db.supplies.firstIndex(where: { $0.id == item.id }) {
            store.db.supplies[idx].quantity = max(0, store.db.supplies[idx].quantity - totalDeductionInItemUnit)
            // updated
        }
        
        if createBatches {
            let cleanStrain = selectedStrain.trimmingCharacters(in: .whitespacesAndNewlines)
            if !store.db.strains.contains(where: { $0.name.lowercased() == cleanStrain.lowercased() }) {
                store.db.strains.append(
                    StrainModel(
                        name: cleanStrain,
                        skuCode: store.nextSKU(prefix: "STR"),
                        species: "Eigen Soort",
                        potencyMultiplier: 1.0,
                        notes: ""
                    )
                )
            }
            
            let bagWeightsList: [Double] = (portionMode == 0 || isPieces)
                ? Array(repeating: Double(equalWeightGramsText.replacingOccurrences(of: ",", with: ".")) ?? 400.0, count: equalCount)
                : customBags
            
            let existingCount = store.db.projects.filter { $0.strainName.lowercased() == cleanStrain.lowercased() }.count
            var generatedLabels: [(title: String, subtitle: String, date: String, qr: String)] = []
            let isAllInOne = item.name.lowercased().contains("alles") || item.name.lowercased().contains("all-in-one")
            let formattedDate = Date().formatted(date: .numeric, time: .omitted)
            
            for (index, weight) in bagWeightsList.enumerated() {
                let batchNum = existingCount + index + 1
                let sku = String(format: "ML-%03d", store.db.projects.count + 1)
                let qrID = "QR-\(sku)-\(Int.random(in: 100...999))"
                
                let newProj = GrowProject(
                    strainName: cleanStrain,
                    skuCode: sku,
                    batchNumber: batchNum,
                    phase: isAllInOne ? .bulk : .spawn,
                    colonizationPercent: 0.0,
                    containerName: containerName.isEmpty ? (isAllInOne ? "Alles-in-één Zak" : "Broedzak") : containerName,
                    substrateName: item.name,
                    spawnToBulkRatio: isAllInOne ? "1:2 (Alles-in-één)" : "100% Graan",
                    drySubstrateWeightGrams: isPieces ? 1000 : weight,
                    sterilizationNotes: sterilizationProtocol,
                    parentCultureLabel: "",
                    qrCodeID: qrID
                )
                store.db.projects.insert(newProj, at: 0)
                
                let report = store.generateTransparentProcessReport(for: newProj)
                generatedLabels.append((
                    title: "\(store.displayTitle(name: cleanStrain, sku: sku)) #\(batchNum)",
                    subtitle: "\(newProj.phase.rawValue) • \(String(format: "%.0f", newProj.drySubstrateWeightGrams))g",
                    date: formattedDate,
                    qr: report
                ))
            }
            
            store.save()
            activeLabels = BatchLabelsWrapper(labels: generatedLabels)
        } else {
            store.save()
            dismiss()
        }
    }
}

// MARK: - SCANNED PROCES-DOSSIER WEERGAVE
struct ScannedDossierSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let rawText: String
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36))
                            .foregroundColor(MycoTheme.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Geverifieerd MycoLabs Procesdossier")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Volledige herkomst en laboratorium-parameters")
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MycoTheme.card)
                    .cornerRadius(12)
                    
                    MycoCard {
                        Text(rawText)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.white)
                            .lineSpacing(4)
                    }
                }
                .padding(16)
            }
            .background(MycoTheme.bg)
            .navigationTitle("Lab Dossier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klaar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    ShareLink(item: rawText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}


// MARK: - DEDICATED LIVE TIMER ROW
struct LabTimerRowView: View {
    @EnvironmentObject var store: MycoStore
    let timerItem: LabTimerItem
    var onRemove: () -> Void
    
    @State private var remainingSeconds: Int = 0
    @State private var timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State private var hasAlerted = false
    
    var isDone: Bool {
        remainingSeconds <= 0
    }
    
    var formattedRemaining: String {
        if isDone {
            return "00:00:00"
        }
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var progress: Double {
        let totalSecs = Double(max(1, timerItem.totalMinutes * 60))
        let elapsed = totalSecs - Double(remainingSeconds)
        return min(1.0, max(0.0, elapsed / totalSecs))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timerItem.label)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text("\(timerItem.totalMinutes) minuten totaal")
                        .font(.system(size: 10))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                Spacer()
                
                if isDone {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(MycoTheme.green)
                        Text("AFGELOPEN!")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundColor(MycoTheme.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MycoTheme.green.opacity(0.18))
                    .cornerRadius(6)
                } else {
                    Text(formattedRemaining)
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .foregroundColor(MycoTheme.amber)
                }
                
                Button {
                    store.startDynamicIslandTimer(label: timerItem.label, totalMinutes: timerItem.totalMinutes)
                } label: {
                    Image(systemName: "livephoto")
                        .font(.title3)
                        .foregroundColor(MycoTheme.blue)
                }
                .buttonStyle(.borderless)
                
                Button(action: onRemove) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(isDone ? MycoTheme.green : MycoTheme.red)
                }
            }
            
            ProgressView(value: progress)
                .tint(isDone ? MycoTheme.green : MycoTheme.amber)
        }
        .padding(10)
        .background(isDone ? MycoTheme.green.opacity(0.12) : MycoTheme.card)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isDone ? MycoTheme.green.opacity(0.7) : MycoTheme.border, lineWidth: 1)
        )
        .onAppear {
            updateRemaining()
        }
        .onReceive(timer) { _ in
            updateRemaining()
        }
    }
    
    private func updateRemaining() {
        let diff = Int(timerItem.endDate.timeIntervalSinceNow)
        remainingSeconds = max(0, diff)
        if remainingSeconds == 0 && !hasAlerted {
            hasAlerted = true
            // Play alert sound & haptic vibration
            AudioServicesPlayAlertSound(SystemSoundID(1005))
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

// MARK: - 13B. AI MYCOLOGY RECIPE & INGREDIENT RATIO PROPORTION ENGINE
struct AIRecipeIngredient: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var amountFormatted: String
    var percentage: Double
    var roleDescription: String
}

struct AIRecipeResult {
    var title: String
    var category: PresetCategory
    var batchSizeDescription: String
    var ingredients: [AIRecipeIngredient]
    var waterFormatted: String
    var hydrationPercent: Double
    var aiExplanationNl: String
    var aiExplanationEn: String
    var sterilizationGuideNl: String
    var sterilizationGuideEn: String
    var safetyNotesNl: String
    var safetyNotesEn: String
}

struct MycoAIRecipeEngine {
    enum RecipeCategory: String, CaseIterable, Identifiable {
        case substrate = "Substraat & Bulk"
        case agar = "Agar Voedingsbodem"
        case liquidCulture = "Vloeibare Cultuur (LC)"
        case grain = "Graanbroed (Spawn)"
        case hardwood = "Hardhout / Masters Mix"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .substrate: return "drop.triangle.fill"
            case .agar: return "circle.hexagongrid.fill"
            case .liquidCulture: return "flask.fill"
            case .grain: return "leaf.fill"
            case .hardwood: return "tree.fill"
            }
        }
        
        var presetCategory: PresetCategory {
            switch self {
            case .substrate, .hardwood: return .substrate
            case .agar, .liquidCulture: return .media
            case .grain: return .grain
            }
        }
        
        public var defaultRecipeUnit: RecipeUnit {
            switch self {
            case .substrate: return .liter
            case .hardwood: return .kilogram
            case .agar, .liquidCulture: return .milliliter
            case .grain: return .kilogram
            }
        }
        
        public var supportedUnits: [RecipeUnit] {
            switch self {
            case .substrate, .hardwood, .grain:
                return [.liter, .gram, .kilogram]
            case .agar, .liquidCulture:
                return [.milliliter, .liter, .gram, .kilogram]
            }
        }
        
        var defaultUnit: String {
            return defaultRecipeUnit.rawValue
        }
        
        var defaultBatchSize: Double {
            switch self {
            case .substrate: return 10.0
            case .agar: return 500.0
            case .liquidCulture: return 500.0
            case .grain: return 2.0
            case .hardwood: return 5.0
            }
        }
        
        var suggestedIngredients: [String] {
            switch self {
            case .substrate:
                return ["Kokosvezel (Coir)", "Vermiculiet", "Gips (Calcium)", "Koffiedik", "Paardenmest", "Wormencompost", "Stro", "Kalk"]
            case .agar:
                return ["Agar-agar poeder", "Moutextract (LME)", "Dextrose / Glucose", "Aardappelvlokken (PDA)", "Pepton", "Gistextract", "Actieve Kool"]
            case .liquidCulture:
                return ["Water", "Honing", "Moutextract (LME)", "Karo Maisstroop", "Dextrose", "Pepton"]
            case .grain:
                return ["Haver (Oats)", "Rogge (Rye)", "Tarwe (Wheat)", "Popcorn", "Vogelzaad (WBS)", "Gips (Calcium)", "Koffiedik"]
            case .hardwood:
                return ["Hardhout Zaagsel", "Sojadoppen (Soy Hulls)", "Tarwezemelen", "Gips (Calcium)"]
            }
        }
    }
    
    public enum RecipeUnit: String, CaseIterable, Identifiable {
        case liter = "L"
        case gram = "g"
        case kilogram = "kg"
        case milliliter = "ml"
        
        public var id: String { rawValue }
        
        public func localizedName(store: MycoStore) -> String {
            switch self {
            case .liter: return store.t(nl: "Liter (L)", en: "Liter (L)")
            case .gram: return store.t(nl: "Gram (g)", en: "Grams (g)")
            case .kilogram: return store.t(nl: "Kilo (kg)", en: "Kilogram (kg)")
            case .milliliter: return store.t(nl: "Milliliter (ml)", en: "Milliliter (ml)")
            }
        }
    }
    
    private static func formatBatch(_ value: Double) -> String {
        return (value.truncatingRemainder(dividingBy: 1) == 0) ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
    
    static func calculate(
        category: RecipeCategory,
        selectedIngredients: [String],
        batchSize: Double,
        unit: RecipeUnit = .liter
    ) -> AIRecipeResult {
        let ingredientsToUse = selectedIngredients.isEmpty ? [category.suggestedIngredients[0]] : selectedIngredients
        
        switch category {
        case .substrate:
            let liters: Double
            switch unit {
            case .liter:
                liters = max(0.2, batchSize)
            case .gram:
                liters = max(0.5, batchSize / 76.5)
            case .kilogram:
                liters = max(1.0, (batchSize * 1000.0) / 76.5)
            case .milliliter:
                liters = max(0.2, batchSize / 1000.0)
            }
            return calculateSubstrate(ingredients: ingredientsToUse, liters: liters, inputBatchSize: batchSize, inputUnit: unit)
        case .agar:
            let volumeML: Double
            switch unit {
            case .milliliter: volumeML = max(50.0, batchSize)
            case .liter: volumeML = max(50.0, batchSize * 1000.0)
            case .gram: volumeML = max(50.0, batchSize)
            case .kilogram: volumeML = max(50.0, batchSize * 1000.0)
            }
            return calculateAgar(ingredients: ingredientsToUse, volumeML: volumeML, inputBatchSize: batchSize, inputUnit: unit)
        case .liquidCulture:
            let volumeML: Double
            switch unit {
            case .milliliter: volumeML = max(50.0, batchSize)
            case .liter: volumeML = max(50.0, batchSize * 1000.0)
            case .gram: volumeML = max(50.0, batchSize)
            case .kilogram: volumeML = max(50.0, batchSize * 1000.0)
            }
            return calculateLC(ingredients: ingredientsToUse, volumeML: volumeML, inputBatchSize: batchSize, inputUnit: unit)
        case .grain:
            let dryKg: Double
            switch unit {
            case .kilogram: dryKg = max(0.1, batchSize)
            case .gram: dryKg = max(0.1, batchSize / 1000.0)
            case .liter: dryKg = max(0.1, batchSize * 0.8)
            case .milliliter: dryKg = max(0.1, (batchSize / 1000.0) * 0.8)
            }
            return calculateGrain(ingredients: ingredientsToUse, dryKg: dryKg, inputBatchSize: batchSize, inputUnit: unit)
        case .hardwood:
            let dryKg: Double
            switch unit {
            case .kilogram: dryKg = max(0.1, batchSize)
            case .gram: dryKg = max(0.1, batchSize / 1000.0)
            case .liter: dryKg = max(0.1, batchSize * 0.6)
            case .milliliter: dryKg = max(0.1, (batchSize / 1000.0) * 0.6)
            }
            return calculateHardwood(ingredients: ingredientsToUse, dryKg: dryKg, inputBatchSize: batchSize, inputUnit: unit)
        }
    }
    
    private static func calculateSubstrate(
        ingredients: [String],
        liters: Double,
        inputBatchSize: Double? = nil,
        inputUnit: RecipeUnit? = nil
    ) -> AIRecipeResult {
        let totalDryMassGrams: Double
        if let unit = inputUnit, let b = inputBatchSize, unit == .gram {
            totalDryMassGrams = max(50.0, b)
        } else if let unit = inputUnit, let b = inputBatchSize, unit == .kilogram {
            totalDryMassGrams = max(50.0, b * 1000.0)
        } else {
            totalDryMassGrams = max(50.0, liters * 76.5)
        }
        var items: [AIRecipeIngredient] = []
        var totalWaterML: Double = 0.0
        
        var remainingShare = 1.0
        var shares: [String: Double] = [:]
        
        for ing in ingredients {
            let lower = ing.lowercased()
            if lower.contains("gips") || lower.contains("kalk") || lower.contains("calcium") {
                shares[ing] = 0.04
                remainingShare -= 0.04
            } else if lower.contains("koffie") || lower.contains("coffee") {
                shares[ing] = 0.05
                remainingShare -= 0.05
            } else if lower.contains("vermiculi") {
                shares[ing] = 0.18
                remainingShare -= 0.18
            } else if lower.contains("mest") || lower.contains("compost") {
                shares[ing] = 0.20
                remainingShare -= 0.20
            } else if lower.contains("stro") {
                shares[ing] = 0.25
                remainingShare -= 0.25
            }
        }
        
        let unassigned = ingredients.filter { shares[$0] == nil }
        let perBaseShare = unassigned.isEmpty ? 0.0 : max(0.1, remainingShare / Double(unassigned.count))
        for ing in unassigned {
            shares[ing] = perBaseShare
        }
        
        let sumShares = shares.values.reduce(0, +)
        for (ing, share) in shares {
            let normShare = sumShares > 0 ? (share / sumShares) : (1.0 / Double(ingredients.count))
            let grams = totalDryMassGrams * normShare
            let lower = ing.lowercased()
            
            let waterFactor: Double
            let role: String
            if lower.contains("kokos") || lower.contains("coir") {
                waterFactor = 5.0
                role = "Basissubstraat & lignine (wateropname x5.0)"
            } else if lower.contains("vermiculi") {
                waterFactor = 4.0
                role = "Vochtretentie & beluchtingsstructuur (wateropname x4.0)"
            } else if lower.contains("gips") || lower.contains("kalk") || lower.contains("calcium") {
                waterFactor = 0.0
                role = "Calcium & zwavel bron; buffert pH naar 6.8 - 7.2"
            } else if lower.contains("koffie") {
                waterFactor = 1.8
                role = "Stikstof & lipidensupplement (veilig gedoseerd <=5%)"
            } else if lower.contains("mest") || lower.contains("compost") {
                waterFactor = 2.5
                role = "Organische microbiële & stikstofrijke voeding"
            } else if lower.contains("stro") {
                waterFactor = 2.8
                role = "Cellulose vezelstructuur voor snelle kolonisatie"
            } else {
                waterFactor = 2.5
                role = "Aangepast substraat component"
            }
            
            totalWaterML += grams * waterFactor
            let formattedAmount: String
            if lower.contains("vermiculi") {
                let vLiters = grams / 100.0
                let vCups = vLiters * 4.2
                formattedAmount = String(format: "%.0f g (ca. %.1fL / ~%.0f koppen)", grams, vLiters, vCups)
            } else if lower.contains("gips") || lower.contains("kalk") || lower.contains("calcium") {
                let tablespoons = grams / 25.0
                formattedAmount = String(format: "%.0f g (ca. %.1f el)", grams, max(0.5, tablespoons))
            } else if lower.contains("kokos") || lower.contains("coir") {
                let bricks = grams / 650.0
                formattedAmount = String(format: "%.0f g (ca. %.1f blok)", grams, bricks)
            } else {
                formattedAmount = String(format: "%.0f g", grams)
            }
            items.append(AIRecipeIngredient(
                name: ing,
                amountFormatted: formattedAmount,
                percentage: normShare * 100.0,
                roleDescription: role
            ))
        }
        
        let waterLiters = totalWaterML / 1000.0
        let hydrationPct = (totalWaterML / (totalWaterML + totalDryMassGrams)) * 100.0
        
        let batchDesc: String = {
            if let b = inputBatchSize, let u = inputUnit {
                let bStr = formatBatch(b)
                switch u {
                case .gram:
                    return "\(bStr)g dry mix (≈ \(String(format: "%.1f", liters))L final volume)"
                case .kilogram:
                    return "\(bStr)kg dry mix (≈ \(String(format: "%.1f", liters))L final volume)"
                case .liter:
                    return "\(bStr) Liter final volume (≈ \(Int(totalDryMassGrams))g dry mix)"
                case .milliliter:
                    return "\(bStr)ml volume"
                }
            }
            return "\(String(format: "%.1f", liters)) Liter final volume"
        }()
        let titleDesc: String = {
            if let b = inputBatchSize, let u = inputUnit {
                return "AI Substrate Mix (\(formatBatch(b)) \(u.rawValue))"
            }
            return "AI Substrate Mix (\(String(format: "%.1f", liters))L)"
        }()
        
        let explNl = "AI Balans: Voor \(titleDesc) (\(String(format: "%.1f", liters))L bulksubstraat) is een droge mix van \(Int(totalDryMassGrams))g berekend. De verhouding tussen koolstofrijke vezels en stikstofsupplementen is optimaal gebalanceerd. Het berekende water brengt het mengsel precies op veldcapaciteit (bij hard knijpen slechts 2-3 druppels water)."
        let explEn = "AI Balance: For \(titleDesc) (\(String(format: "%.1f", liters))L bulk substrate), a dry mix of \(Int(totalDryMassGrams))g is calculated. Carbon fibers and nitrogen supplements are strictly balanced. The calculated water yields exact field capacity (only 2-3 drops when squeezed hard)."
        
        let pasteurNl = "Bereiding & Pasteurisatie: Meng alle droge ingrediënten goed door elkaar. Voeg \(String(format: "%.2f", waterLiters))L KOKEND water toe (Bucket-tek) en sluit direct luchtdicht af in een geïsoleerde emmer of koelbox. Laat 4-6 uur rusten tot afgekoeld onder 25°C. Of steriliseer 90 min op 15 PSI (121°C) in een snelkookpan."
        let pasteurEn = "Preparation & Pasteurization: Mix all dry ingredients thoroughly. Add \(String(format: "%.2f", waterLiters))L of BOILING water (Bucket-tek) and seal immediately in an insulated bucket or cooler. Let rest 4-6 hours until cooled below 25°C. Or pressure cook 90 mins at 15 PSI (121°C)."
        
        return AIRecipeResult(
            title: titleDesc,
            category: .substrate,
            batchSizeDescription: batchDesc,
            ingredients: items,
            waterFormatted: String(format: "%.0f ml (%.2f L) kokend water", totalWaterML, waterLiters),
            hydrationPercent: hydrationPct,
            aiExplanationNl: explNl,
            aiExplanationEn: explEn,
            sterilizationGuideNl: pasteurNl,
            sterilizationGuideEn: pasteurEn,
            safetyNotesNl: "Voeg nooit meer dan 5-8% koffiedik of stikstofsupplementen toe om Trichoderma-besmetting te voorkomen. Laat altijd volledig afkoelen voor het enten!",
            safetyNotesEn: "Never exceed 5-8% coffee grounds or nitrogen supplements to prevent Trichoderma contamination. Always let cool completely before inoculating!"
        )
    }
    
    private static func calculateAgar(
        ingredients: [String],
        volumeML: Double,
        inputBatchSize: Double? = nil,
        inputUnit: RecipeUnit? = nil
    ) -> AIRecipeResult {
        var items: [AIRecipeIngredient] = []
        let factor = volumeML / 1000.0
        
        let sugars = ingredients.filter { ing in
            let l = ing.lowercased()
            return l.contains("mout") || l.contains("lme") || l.contains("dextrose") || l.contains("glucose") || l.contains("aardappel") || l.contains("pda") || l.contains("suiker")
        }
        let totalSugarGrams = 20.0 * factor
        let perSugarGrams = sugars.isEmpty ? 0.0 : (totalSugarGrams / Double(sugars.count))
        
        for ing in ingredients {
            let l = ing.lowercased()
            if l.contains("agar") {
                let g = 20.0 * factor
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.1f g", g),
                    percentage: 2.0,
                    roleDescription: "Geleermiddel (2.0% concentratie voor optimale stevigheid)"
                ))
            } else if sugars.contains(ing) {
                let pct = 2.0 / Double(max(1, sugars.count))
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.1f g", perSugarGrams),
                    percentage: pct,
                    roleDescription: "Koolhydraten & voeding (max 2% om myceliumstress te vermijden)"
                ))
            } else if l.contains("pepton") {
                let g = 1.0 * factor
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.2f g", g),
                    percentage: 0.1,
                    roleDescription: "Organisch stikstof & aminozuren booster (0.1%)"
                ))
            } else if l.contains("gist") {
                let g = 1.0 * factor
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.2f g", g),
                    percentage: 0.1,
                    roleDescription: "Vitamine B-complex en sporenelementen (0.1%)"
                ))
            } else if l.contains("kool") || l.contains("charcoal") {
                let g = 2.0 * factor
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.2f g", g),
                    percentage: 0.2,
                    roleDescription: "Actieve kool: neutraliseert toxines & biedt hoog visueel contrast"
                ))
            } else {
                let g = 1.5 * factor
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.2f g", g),
                    percentage: 0.15,
                    roleDescription: "Aanvullend voedingsadditief"
                ))
            }
        }
        
        let titleDesc: String = {
            if let b = inputBatchSize, let u = inputUnit {
                return "AI Agar Media (\(formatBatch(b)) \(u.rawValue))"
            }
            return "AI Agar Media (\(Int(volumeML))ml)"
        }()
        let batchDesc: String = {
            if let b = inputBatchSize, let u = inputUnit {
                return "\(formatBatch(b)) \(u.rawValue) agar solution (~15-20 petri dishes per 500ml)"
            }
            return "\(Int(volumeML)) ml agar solution (~15-20 petri dishes)"
        }()
        
        let explNl = "AI Balans: Voor \(titleDesc) (\(Int(volumeML))ml agar-oplossing) is een 2% agar en 2% suikerverhouding berekend. Deze verhouding bootst een natuurlijke voedingsbodem na zonder overmatige osmotische druk, wat zorgt voor snelle en rhizomorfe myceliumgroei."
        let explEn = "AI Balance: For \(titleDesc) (\(Int(volumeML))ml agar solution), a balanced 2% agar and 2% nutrient profile is formulated. This provides fast rhizomorphic growth without osmotic stress."
        
        let sterNl = "Sterilisatie: 45 minuten op 15 PSI (121°C). Laat de snelkookpan daarna natuurlijk afkoelen tot nul druk. Niet handmatig ontluchten om overkoken te voorkomen. Giet de petrischalen bij 45-50°C in een still air box of vóór een flow hood."
        let sterEn = "Sterilization: 45 minutes at 15 PSI (121°C). Allow natural depressurization to prevent boil-over. Pour plates at 45-50°C in a still air box or flow hood."
        
        return AIRecipeResult(
            title: titleDesc,
            category: .media,
            batchSizeDescription: batchDesc,
            ingredients: items,
            waterFormatted: "\(Int(volumeML)) ml gedestilleerd / kraanwater",
            hydrationPercent: 96.0,
            aiExplanationNl: explNl,
            aiExplanationEn: explEn,
            sterilizationGuideNl: sterNl,
            sterilizationGuideEn: sterEn,
            safetyNotesNl: "Gebruik nooit meer dan 2.5% suiker bij agar, omdat te veel suiker leidt tot zacht/plakkerig mycelium en bacteriële groei bevordert.",
            safetyNotesEn: "Never exceed 2.5% sugar in agar, as excess sugar causes weak fluffy mycelium and invites bacterial issues."
        )
    }
    
    private static func calculateLC(
        ingredients: [String],
        volumeML: Double,
        inputBatchSize: Double? = nil,
        inputUnit: RecipeUnit? = nil
    ) -> AIRecipeResult {
        var items: [AIRecipeIngredient] = []
        let factor = volumeML / 1000.0
        
        let sugars = ingredients.filter { ing in
            let l = ing.lowercased()
            return l.contains("honing") || l.contains("mout") || l.contains("lme") || l.contains("karo") || l.contains("mais") || l.contains("dextrose") || l.contains("suiker")
        }
        
        let targetTotalSugarGrams = 38.0 * factor
        let perSugarGrams = sugars.isEmpty ? (40.0 * factor) : (targetTotalSugarGrams / Double(sugars.count))
        
        for ing in ingredients {
            let l = ing.lowercased()
            if l.contains("water") {
                continue
            } else if sugars.contains(ing) {
                let pct = 3.8 / Double(max(1, sugars.count))
                let role = l.contains("honing") ? "Zuivere honing (antibacterieel & natuurlijke enzymen)" : (l.contains("karo") ? "Maisstroop (kraakheldere LC met minimale troebeling)" : "Koolhydratenbron (max 4% totaal suikergehalte)")
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.1f g", perSugarGrams),
                    percentage: pct,
                    roleDescription: role
                ))
            } else if l.contains("pepton") {
                let g = 1.0 * factor
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.2f g", g),
                    percentage: 0.1,
                    roleDescription: "Pepton aminozuren: stimuleert dichte, wolkachtige myceliumgroei"
                ))
            } else {
                let g = 1.0 * factor
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.2f g", g),
                    percentage: 0.1,
                    roleDescription: "Aanvullend nutriënt"
                ))
            }
        }
        
        let titleDesc: String = {
            if let b = inputBatchSize, let u = inputUnit {
                return "AI Vloeibare Cultuur (\(formatBatch(b)) \(u.rawValue))"
            }
            return "AI Vloeibare Cultuur (\(Int(volumeML))ml)"
        }()
        let batchDesc: String = {
            if let b = inputBatchSize, let u = inputUnit {
                return "\(formatBatch(b)) \(u.rawValue) nutrient solution"
            }
            return "\(Int(volumeML)) ml nutrient solution"
        }()
        
        let explNl = "AI Beveiliging: Bij vloeibare cultuur (LC) is het suikerpercentage strikt afgesteld op 3.8%. Hogere suikerpercentages (boven 4%) veroorzaken karamellisatie (schadelijke HMF verbindingen) tijdens het steriliseren en belemmeren zuurstofopname van het mycelium."
        let explEn = "AI Safety: For liquid culture, the sugar level is strictly capped at 3.8%. Sugar levels above 4% cause caramelization (harmful HMF compounds) in the pressure cooker and inhibit oxygen uptake."
        
        let sterNl = "Sterilisatie: 30-35 minuten op 15 PSI (121°C). Niet langer om karamellisatie te voorkomen. Voeg een magnetische roervlo of een glazen knikker toe voor beluchting en het breken van mycelium."
        let sterEn = "Sterilization: 30-35 minutes at 15 PSI (121°C). Do not overcook to avoid caramelization. Add a magnetic stir bar or glass marble to break mycelium."
        
        return AIRecipeResult(
            title: titleDesc,
            category: .media,
            batchSizeDescription: batchDesc,
            ingredients: items,
            waterFormatted: "\(Int(volumeML)) ml gedestilleerd water",
            hydrationPercent: 96.0,
            aiExplanationNl: explNl,
            aiExplanationEn: explEn,
            sterilizationGuideNl: sterNl,
            sterilizationGuideEn: sterEn,
            safetyNotesNl: "Laat de LC-pot volledig afkoelen tot kamertemperatuur (minimaal 8-12 uur) voordat je ent met sporen of agar!",
            safetyNotesEn: "Allow the LC jar to cool completely to room temperature (at least 8-12 hours) before inoculating!"
        )
    }
    
    private static func calculateGrain(
        ingredients: [String],
        dryKg: Double,
        inputBatchSize: Double? = nil,
        inputUnit: RecipeUnit? = nil
    ) -> AIRecipeResult {
        var items: [AIRecipeIngredient] = []
        let dryGrams = dryKg * 1000.0
        
        let grains = ingredients.filter { ing in
            let l = ing.lowercased()
            return l.contains("haver") || l.contains("oat") || l.contains("rogge") || l.contains("rye") || l.contains("tarwe") || l.contains("wheat") || l.contains("popcorn") || l.contains("vogel") || l.contains("wbs") || l.contains("graan")
        }
        
        let perGrainGrams = grains.isEmpty ? dryGrams : (dryGrams / Double(grains.count))
        for ing in ingredients {
            let l = ing.lowercased()
            if grains.contains(ing) {
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.0f g (%.2f kg)", perGrainGrams, perGrainGrams / 1000.0),
                    percentage: 100.0 / Double(max(1, grains.count)),
                    roleDescription: "Graanbroed basis: vezel- en zetmeelrijke voedingsbron"
                ))
            } else if l.contains("gips") || l.contains("kalk") || l.contains("calcium") {
                let g = dryGrams * 0.015
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.1f g", g),
                    percentage: 1.5,
                    roleDescription: "Gips: voorkomt plakkerige korrels en levert calcium en zwavel"
                ))
            } else if l.contains("koffie") {
                let g = dryGrams * 0.02
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.1f g", g),
                    percentage: 2.0,
                    roleDescription: "Koffiedik/koffie: stikstofbooster voor snellere hyfenspreiding"
                ))
            } else {
                let g = dryGrams * 0.02
                items.append(AIRecipeIngredient(
                    name: ing,
                    amountFormatted: String(format: "%.1f g", g),
                    percentage: 2.0,
                    roleDescription: "Graansupplement"
                ))
            }
        }
        
        let waterML = dryGrams * 0.85
        let totalWetKg = (dryGrams + waterML) / 1000.0
        
        let titleDesc: String = {
            if let b = inputBatchSize, let u = inputUnit {
                return "AI Graanbroed Hydratatie (\(formatBatch(b)) \(u.rawValue))"
            }
            return "AI Graanbroed Hydratatie (\(String(format: "%.1f", dryKg))kg)"
        }()
        let batchDesc: String = {
            if let b = inputBatchSize, let u = inputUnit {
                let bStr = formatBatch(b)
                switch u {
                case .gram:
                    return "\(bStr)g droog graan (~\(String(format: "%.2f", totalWetKg)) kg gehydrateerd)"
                case .liter:
                    return "\(bStr)L graan (~\(String(format: "%.2f", dryKg)) kg droog / ~\(String(format: "%.2f", totalWetKg)) kg gehydrateerd)"
                case .kilogram:
                    return "\(bStr) kg droog graan (~\(String(format: "%.2f", totalWetKg)) kg gehydrateerd)"
                case .milliliter:
                    return "\(bStr)ml grain"
                }
            }
            return "\(String(format: "%.1f", dryKg)) kg dry grain (≈ \(String(format: "%.1f", totalWetKg)) kg hydrated)"
        }()
        
        let explNl = "AI Balans: Voor \(titleDesc) (\(String(format: "%.1f", dryKg))kg droog graan) is \(Int(waterML))ml hydratatiewater berekend om precies 50-53% intern vochtgehalte te bereiken. Het toegevoegde gips (1.5%) vormt een micro-coating die voorkomt dat graankorrels na het steriliseren aan elkaar klonteren."
        let explEn = "AI Balance: For \(titleDesc) (\(String(format: "%.1f", dryKg))kg dry grain), \(Int(waterML))ml water is calculated to hit 50-53% internal hydration. Gypsum (1.5%) prevents clumping."
        
        let sterNl = "Bereiding & Sterilisatie: Week het graan 12-24 uur (optioneel met koffie). Kook 10-15 minuten tot de korrels zacht zijn maar niet openspringen. Droog de buitenkant grondig op handdoeken tot de buitenkant droog aanvoelt. Doe in filterzakken of potten met filterdeksel. Steriliseer 90-120 minuten op 15 PSI (121°C)."
        let sterEn = "Preparation: Soak grain 12-24 hrs. Simmer 10-15 mins until hydrated without bursting. Dry exterior on towels. Pressure cook 90-120 mins at 15 PSI (121°C)."
        
        return AIRecipeResult(
            title: titleDesc,
            category: .grain,
            batchSizeDescription: batchDesc,
            ingredients: items,
            waterFormatted: String(format: "%.0f ml (%.2f L) water", waterML, waterML / 1000.0),
            hydrationPercent: 52.0,
            aiExplanationNl: explNl,
            aiExplanationEn: explEn,
            sterilizationGuideNl: sterNl,
            sterilizationGuideEn: sterEn,
            safetyNotesNl: "Zorg dat de buitenkant van het graan handdroog is voordat het in de potten gaat. Natte korrelbuitenkanten trekken bacteriële besmetting aan!",
            safetyNotesEn: "Ensure the grain exterior is towel-dry before filling jars. Wet outer hulls invite bacterial wet-spot issues!"
        )
    }
    
    private static func calculateHardwood(
        ingredients: [String],
        dryKg: Double,
        inputBatchSize: Double? = nil,
        inputUnit: RecipeUnit? = nil
    ) -> AIRecipeResult {
        var items: [AIRecipeIngredient] = []
        let dryGrams = dryKg * 1000.0
        
        let sawdustGrams = dryGrams * 0.49
        let soyGrams = dryGrams * 0.49
        let gypsumGrams = dryGrams * 0.02
        let waterML = dryGrams * 1.4
        
        items.append(AIRecipeIngredient(
            name: "Hardhout Zaagsel (Eik / Beuk)",
            amountFormatted: String(format: "%.0f g (%.2f kg)", sawdustGrams, sawdustGrams / 1000.0),
            percentage: 49.0,
            roleDescription: "Primaire lignine & cellulose basis voor houtafbrekers"
        ))
        
        items.append(AIRecipeIngredient(
            name: "Sojadoppen (Soy Hulls)",
            amountFormatted: String(format: "%.0f g (%.2f kg)", soyGrams, soyGrams / 1000.0),
            percentage: 49.0,
            roleDescription: "Stikstof- en vezelrijk supplement (Masters Mix 50:50 voor maximale opbrengst)"
        ))
        
        items.append(AIRecipeIngredient(
            name: "Gips (Calcium)",
            amountFormatted: String(format: "%.0f g", gypsumGrams),
            percentage: 2.0,
            roleDescription: "pH buffer en structuurverbeteraar"
        ))
        
        let titleDesc: String = {
            if let b = inputBatchSize, let u = inputUnit {
                return "AI Masters Mix Houtsubstraat (\(formatBatch(b)) \(u.rawValue))"
            }
            return "AI Masters Mix Houtsubstraat (\(String(format: "%.1f", dryKg))kg)"
        }()
        let batchDesc: String = {
            if let b = inputBatchSize, let u = inputUnit {
                let bStr = formatBatch(b)
                switch u {
                case .gram:
                    return "\(bStr)g droge mix (~\(String(format: "%.2f", (dryGrams + waterML) / 1000.0)) kg substraatblok)"
                case .liter:
                    return "\(bStr)L houtsubstraat (~\(String(format: "%.2f", dryKg)) kg droog / ~\(String(format: "%.2f", (dryGrams + waterML) / 1000.0)) kg blok)"
                case .kilogram:
                    return "\(bStr) kg droge mix (~\(String(format: "%.1f", (dryGrams + waterML) / 1000.0)) kg substraatblok)"
                case .milliliter:
                    return "\(bStr)ml wood substrate"
                }
            }
            return "\(String(format: "%.1f", dryKg)) kg dry mix (≈ \(String(format: "%.1f", (dryGrams + waterML) / 1000.0)) kg substrate block)"
        }()
        
        let explNl = "AI Balans: Authentieke Masters Mix formule (\(titleDesc)): 50% eiken/beukenzaagsel en 50% sojadoppen. Dit biedt de perfecte koolstof-stikstofverhouding (C:N) voor lignine-etende soorten zoals Lion's Mane, Reishi en Oesterzwammen."
        let explEn = "AI Balance: Authentic Masters Mix formulation (\(titleDesc)): 50% hardwood sawdust and 50% soy hulls with 60% hydration for wood-loving gourmets."
        
        let sterNl = "Sterilisatie: Hardhoutblokken met sojadoppen MOETEN gesteriliseerd worden in de snelkookpan op 15 PSI (121°C) gedurende 120-150 minuten. Pasteurisatie volstaat niet vanwege het hoge stikstofgehalte van de sojadoppen."
        let sterEn = "Sterilization: Masters mix blocks MUST be pressure cooked at 15 PSI for 120-150 mins. Pasteurization is insufficient due to soy protein content."
        
        return AIRecipeResult(
            title: titleDesc,
            category: .substrate,
            batchSizeDescription: batchDesc,
            ingredients: items,
            waterFormatted: String(format: "%.0f ml (%.2f L) water", waterML, waterML / 1000.0),
            hydrationPercent: 60.0,
            aiExplanationNl: explNl,
            aiExplanationEn: explEn,
            sterilizationGuideNl: sterNl,
            sterilizationGuideEn: sterEn,
            safetyNotesNl: "Gebruik altijd autoclaafzakken met 0.2 of 0.5 micron ademend filter voor houtsubstraatblokken!",
            safetyNotesEn: "Always use autoclave grow bags with 0.2 or 0.5 micron filter patches for hardwood blocks!"
        )
    }
}


// MARK: - 14. TAB 4: CALCULATORS, TIMERS, CONTAMINATION & PRESETS HUB
struct EditProjectSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss

    let project: GrowProject

    @State private var strainName: String
    @State private var batchNumber: Int
    @State private var phase: GrowPhase
    @State private var colonizationPercent: Double
    @State private var containerName: String
    @State private var substrateName: String
    @State private var spawnToBulkRatio: String
    @State private var drySubstrateWeightGramsText: String
    @State private var sterilizationNotes: String
    @State private var startDate: Date
    @State private var tags: [String]
    @State private var showDeleteConfirm = false

    private let availableStandardTags = [
        "🫨 B&S Uitgevoerd",
        "🌱 Pins Gespot",
        "🍄 Flush 1",
        "🍄 Flush 2",
        "🍄 Flush 3",
        "⚠️ Quarantaine",
        "🔬 Kloon Kandidaat",
        "⭐ Favoriet"
    ]

    init(project: GrowProject) {
        self.project = project
        _strainName = State(initialValue: project.strainName)
        _batchNumber = State(initialValue: project.batchNumber)
        _phase = State(initialValue: project.phase)
        _colonizationPercent = State(initialValue: project.colonizationPercent)
        _containerName = State(initialValue: project.containerName)
        _substrateName = State(initialValue: project.substrateName)
        _spawnToBulkRatio = State(initialValue: project.spawnToBulkRatio)
        _drySubstrateWeightGramsText = State(initialValue: project.drySubstrateWeightGrams > 0 ? String(format: "%.0f", project.drySubstrateWeightGrams) : "")
        _sterilizationNotes = State(initialValue: project.sterilizationNotes)
        _startDate = State(initialValue: project.startDate)
        _tags = State(initialValue: project.tags)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Soort & Batch
                Section(header: Text(store.t(nl: "Soort & Batchnummer", en: "Strain & Batch Number"))) {
                    if !store.db.strains.isEmpty {
                        Picker(store.t(nl: "Kies uit soorten", en: "Choose from strains"), selection: $strainName) {
                            Text(store.t(nl: "Handmatig typen...", en: "Type manually...")).tag("")
                            ForEach(store.db.strains) { s in
                                Text(s.name).tag(s.name)
                            }
                        }
                    }
                    TextField(store.t(nl: "Soortnaam (bijv. Lion's Mane)", en: "Strain Name (e.g. Lion's Mane)"), text: $strainName)

                    Stepper("\(store.t(nl: "Batch #", en: "Batch #"))\(batchNumber)", value: $batchNumber, in: 1...999)
                }

                // Section 2: Fase & Voortgang
                Section(header: Text(store.t(nl: "Fase & Kolonisatie", en: "Phase & Colonization"))) {
                    Picker(store.t(nl: "Kweekfase", en: "Grow Phase"), selection: $phase) {
                        ForEach(GrowPhase.allCases, id: \.self) { p in
                            Text(p.localized(isEnglish: store.isEnglish)).tag(p)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(store.t(nl: "Voortgang Kolonisatie:", en: "Colonization Progress:"))
                            Spacer()
                            Text("\(Int(colonizationPercent * 100))%")
                                .font(.system(.body, design: .monospaced).bold())
                                .foregroundColor(phase.color)
                        }
                        Slider(value: $colonizationPercent, in: 0...1, step: 0.05)
                            .tint(phase.color)
                    }

                    DatePicker(
                        store.t(nl: "Startdatum Batch", en: "Batch Start Date"),
                        selection: $startDate,
                        displayedComponents: [.date]
                    )
                }

                // Section 3: Hardware & Substraat Setup
                Section(header: Text(store.t(nl: "Setup Specificaties", en: "Setup Specifications"))) {
                    let containers = store.db.presets.filter { $0.category == .container }
                    if !containers.isEmpty {
                        Picker(store.t(nl: "Container Preset", en: "Container Preset"), selection: $containerName) {
                            Text(store.t(nl: "Handmatig...", en: "Manual...")).tag("")
                            ForEach(containers) { c in
                                Text(store.localizePresetName(c.name)).tag(c.name)
                            }
                        }
                    }
                    TextField(store.t(nl: "Container (bijv. Monotub 45L)", en: "Container (e.g. Monotub 45L)"), text: $containerName)

                    let substrates = store.db.presets.filter { $0.category == .substrate || $0.category == .grain }
                    if !substrates.isEmpty {
                        Picker(store.t(nl: "Substraat Preset", en: "Substrate Preset"), selection: $substrateName) {
                            Text(store.t(nl: "Handmatig...", en: "Manual...")).tag("")
                            ForEach(substrates) { s in
                                Text(store.localizePresetName(s.name)).tag(s.name)
                            }
                        }
                    }
                    TextField(store.t(nl: "Substraat (bijv. CVG 100% Coco Coir)", en: "Substrate"), text: $substrateName)

                    Picker(store.t(nl: "Spawn-to-Bulk Ratio", en: "Spawn-to-Bulk Ratio"), selection: $spawnToBulkRatio) {
                        ForEach(["1:1", "1:1.5", "1:2", "1:2.5", "1:3", "1:4", "1:5"], id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }

                    HStack {
                        Text(store.t(nl: "Droog Substraat:", en: "Dry Substrate:"))
                        Spacer()
                        TextField(store.t(nl: "bijv. 650", en: "e.g. 650"), text: $drySubstrateWeightGramsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(MycoTheme.green)
                        Text("gram")
                            .foregroundColor(MycoTheme.textSecondary)
                    }

                    TextField(store.t(nl: "Sterilisatie Notities (bijv. 90 min @ 15 PSI)", en: "Sterilization Notes"), text: $sterilizationNotes)
                }

                // Section 4: Tags & Status Labels
                Section(header: Text(store.t(nl: "Status Tags", en: "Status Tags"))) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(availableStandardTags, id: \.self) { tag in
                                let isSelected = tags.contains(tag)
                                Button {
                                    if isSelected {
                                        tags.removeAll { $0 == tag }
                                    } else {
                                        tags.append(tag)
                                    }
                                } label: {
                                    Text(tag)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isSelected ? MycoTheme.blue : Color.white.opacity(0.08))
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Danger zone
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text(store.t(nl: "Verwijder Deze Batch", en: "Delete This Batch"))
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Batch Bewerken", en: "Edit Batch"))
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
                    .disabled(strainName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert(store.t(nl: "Batch Verwijderen?", en: "Delete Batch?"), isPresented: $showDeleteConfirm) {
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
                Button(store.t(nl: "Verwijderen", en: "Delete"), role: .destructive) {
                    store.deleteProject(id: project.id)
                    dismiss()
                }
            } message: {
                Text(store.t(nl: "Weet je zeker dat je deze batch permanent wilt wissen?", en: "Are you sure you want to delete this batch?"))
            }
        }
    }

    private func saveChanges() {
        let cleanStrain = strainName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanStrain.isEmpty else { return }

        let cleanGrams = drySubstrateWeightGramsText.replacingOccurrences(of: ",", with: ".")
        let grams = max(0, Double(cleanGrams) ?? project.drySubstrateWeightGrams)

        if let idx = store.db.projects.firstIndex(where: { $0.id == project.id }) {
            store.db.projects[idx].strainName = cleanStrain
            store.db.projects[idx].batchNumber = batchNumber
            store.db.projects[idx].phase = phase
            store.db.projects[idx].colonizationPercent = colonizationPercent
            store.db.projects[idx].startDate = startDate
            store.db.projects[idx].containerName = containerName.trimmingCharacters(in: .whitespaces)
            store.db.projects[idx].substrateName = substrateName.trimmingCharacters(in: .whitespaces)
            store.db.projects[idx].spawnToBulkRatio = spawnToBulkRatio
            store.db.projects[idx].drySubstrateWeightGrams = grams
            store.db.projects[idx].sterilizationNotes = sterilizationNotes.trimmingCharacters(in: .whitespaces)
            store.db.projects[idx].tags = tags
            store.db.projects[idx].lastModifiedAt = Date()
            store.save()
            MycoSyncManager.shared.sendSyncPayload(reason: "project_edited")
        }

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif

        MycoSyncManager.shared.triggerToast(message: store.t(
            nl: "✅ Batch succesvol bijgewerkt",
            en: "✅ Batch successfully updated"
        ))

        dismiss()
    }
}

// MARK: - EDIT HARVEST RECORD SHEET VIEW
struct EditHarvestRecordSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss

    let harvest: HarvestRecord

    @State private var flushNumber: Int
    @State private var harvestDate: Date
    @State private var wetWeightText: String
    @State private var dryWeightText: String
    @State private var dehydratorTempText: String
    @State private var dehydratorHoursText: String
    @State private var notes: String
    @State private var showDeleteConfirm = false

    init(harvest: HarvestRecord) {
        self.harvest = harvest
        _flushNumber = State(initialValue: harvest.flushNumber)
        _harvestDate = State(initialValue: harvest.harvestDate)
        _wetWeightText = State(initialValue: String(format: "%.1f", harvest.wetWeightGrams))
        _dryWeightText = State(initialValue: String(format: "%.2f", harvest.dryWeightGrams))
        _dehydratorTempText = State(initialValue: String(format: "%.0f", harvest.dehydratorTempC))
        _dehydratorHoursText = State(initialValue: String(format: "%.1f", harvest.dehydratorHours))
        _notes = State(initialValue: harvest.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(store.t(nl: "Flush & Oogstdatum", en: "Flush & Harvest Date"))) {
                    Stepper("\(store.t(nl: "Flush #", en: "Flush #"))\(flushNumber)", value: $flushNumber, in: 1...20)
                    DatePicker(store.t(nl: "Oogstdatum", en: "Harvest Date"), selection: $harvestDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section(header: Text(store.t(nl: "Gewichten", en: "Weights"))) {
                    HStack {
                        Text(store.t(nl: "Nat Geoogst:", en: "Fresh Wet:"))
                        Spacer()
                        TextField(store.t(nl: "bijv. 250", en: "e.g. 250"), text: $wetWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced).bold())
                        Text("gram")
                            .foregroundColor(MycoTheme.textSecondary)
                    }

                    HStack {
                        Text(store.t(nl: "Cracker-Dry Droog:", en: "Cracker-Dry:"))
                        Spacer()
                        TextField(store.t(nl: "bijv. 22.5", en: "e.g. 22.5"), text: $dryWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(MycoTheme.green)
                        Text("gram")
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }

                Section(header: Text(store.t(nl: "Voedseldroger Parameters", en: "Dehydrator Parameters"))) {
                    HStack {
                        Text(store.t(nl: "Temperatuur:", en: "Temperature:"))
                        Spacer()
                        TextField(store.t(nl: "bijv. 55", en: "e.g. 55"), text: $dehydratorTempText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("°C")
                            .foregroundColor(MycoTheme.textSecondary)
                    }

                    HStack {
                        Text(store.t(nl: "Droogtijd:", en: "Drying Time:"))
                        Spacer()
                        TextField(store.t(nl: "bijv. 12", en: "e.g. 12"), text: $dehydratorHoursText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text(store.t(nl: "uur", en: "hrs"))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }

                Section(header: Text(store.t(nl: "Notities & Kwaliteit", en: "Notes & Quality"))) {
                    TextField(store.t(nl: "Notities over dichtheid, formaat, hoedjes...", en: "Notes on caps, density, size..."), text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text(store.t(nl: "Verwijder Deze Oogst", en: "Delete This Harvest"))
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Oogst / Flush Bewerken", en: "Edit Harvest / Flush"))
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
                }
            }
            .alert(store.t(nl: "Oogst Verwijderen?", en: "Delete Harvest?"), isPresented: $showDeleteConfirm) {
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
                Button(store.t(nl: "Verwijderen", en: "Delete"), role: .destructive) {
                    store.deleteHarvest(id: harvest.id)
                    dismiss()
                }
            } message: {
                Text(store.t(nl: "Weet je zeker dat je deze flush wilt verwijderen?", en: "Are you sure you want to delete this flush?"))
            }
        }
    }

    private func saveChanges() {
        let wet = max(0, Double(wetWeightText.replacingOccurrences(of: ",", with: ".")) ?? harvest.wetWeightGrams)
        let dry = max(0, Double(dryWeightText.replacingOccurrences(of: ",", with: ".")) ?? harvest.dryWeightGrams)
        let temp = max(0, Double(dehydratorTempText.replacingOccurrences(of: ",", with: ".")) ?? harvest.dehydratorTempC)
        let hours = max(0, Double(dehydratorHoursText.replacingOccurrences(of: ",", with: ".")) ?? harvest.dehydratorHours)

        if let idx = store.db.harvests.firstIndex(where: { $0.id == harvest.id }) {
            store.db.harvests[idx].flushNumber = flushNumber
            store.db.harvests[idx].harvestDate = harvestDate
            store.db.harvests[idx].wetWeightGrams = wet
            store.db.harvests[idx].dryWeightGrams = dry
            store.db.harvests[idx].dehydratorTempC = temp
            store.db.harvests[idx].dehydratorHours = hours
            store.db.harvests[idx].notes = notes
            store.save()
            MycoSyncManager.shared.sendSyncPayload(reason: "harvest_edited")
        }

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif

        MycoSyncManager.shared.triggerToast(message: store.t(
            nl: "✅ Flush succesvol bijgewerkt",
            en: "✅ Flush successfully updated"
        ))

        dismiss()
    }
}

// MARK: - EDIT GROW LOG SHEET VIEW
struct EditGrowLogSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss

    let log: GrowLog

    @State private var actionType: String
    @State private var timestamp: Date
    @State private var tempText: String
    @State private var humidityText: String
    @State private var notes: String
    @State private var showDeleteConfirm = false

    private let standardActions = [
        "Omgevingscheck / Notitie",
        "🫨 Break and Shake",
        "🌱 Pins Gespot",
        "🍄 Primordia Waargenomen",
        "💧 Bevochtiging / Nevelen",
        "🌬️ FAE / Ventilatie",
        "⚠️ Quarantaine / Check",
        "Inoculatie / Enting",
        "Substraat Pasteurisatie",
        "Anders / Zelf typen..."
    ]

    init(log: GrowLog) {
        self.log = log
        _actionType = State(initialValue: log.actionType)
        _timestamp = State(initialValue: log.timestamp)
        _tempText = State(initialValue: log.temperatureC != nil ? String(format: "%.1f", log.temperatureC!) : "")
        _humidityText = State(initialValue: log.humidityPct != nil ? String(format: "%.0f", log.humidityPct!) : "")
        _notes = State(initialValue: log.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(store.t(nl: "Actie & Tijdstip", en: "Action & Time"))) {
                    Picker(store.t(nl: "Type Actie", en: "Action Type"), selection: $actionType) {
                        ForEach(standardActions, id: \.self) { a in
                            Text(store.localizeActionType(a)).tag(a)
                        }
                    }
                    DatePicker(store.t(nl: "Tijdstip", en: "Timestamp"), selection: $timestamp)
                }

                Section(header: Text(store.t(nl: "Klimaat Metingen", en: "Climate Readings"))) {
                    HStack {
                        Text(store.t(nl: "Temperatuur:", en: "Temperature:"))
                        Spacer()
                        TextField("23.0", text: $tempText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("°C")
                            .foregroundColor(MycoTheme.textSecondary)
                    }

                    HStack {
                        Text(store.t(nl: "Luchtvochtigheid:", en: "Humidity:"))
                        Spacer()
                        TextField("90", text: $humidityText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%")
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }

                Section(header: Text(store.t(nl: "Notities & Observaties", en: "Notes & Observations"))) {
                    TextField(store.t(nl: "Typ observaties...", en: "Type observations..."), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text(store.t(nl: "Verwijder Logboek Regel", en: "Delete Log Entry"))
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Log Bewerken", en: "Edit Log"))
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
                }
            }
            .alert(store.t(nl: "Log Verwijderen?", en: "Delete Log?"), isPresented: $showDeleteConfirm) {
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
                Button(store.t(nl: "Verwijderen", en: "Delete"), role: .destructive) {
                    store.deleteLog(id: log.id)
                    dismiss()
                }
            } message: {
                Text(store.t(nl: "Weet je zeker dat je deze log wilt verwijderen?", en: "Are you sure you want to delete this log?"))
            }
        }
    }

    private func saveChanges() {
        let temp = Double(tempText.replacingOccurrences(of: ",", with: "."))
        let hum = Double(humidityText.replacingOccurrences(of: ",", with: "."))

        if let idx = store.db.logs.firstIndex(where: { $0.id == log.id }) {
            store.db.logs[idx].actionType = actionType
            store.db.logs[idx].timestamp = timestamp
            store.db.logs[idx].temperatureC = temp
            store.db.logs[idx].humidityPct = hum
            store.db.logs[idx].notes = notes
            store.save()
            MycoSyncManager.shared.sendSyncPayload(reason: "log_edited")
        }

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif

        MycoSyncManager.shared.triggerToast(message: store.t(
            nl: "✅ Logboek succesvol bijgewerkt",
            en: "✅ Log successfully updated"
        ))

        dismiss()
    }
}
