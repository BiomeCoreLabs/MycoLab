//
//  ModernGeneticsLineageGraphView.swift
//  MycoLab
//
//  Interactive Genetic Lineage Graph & Senescence Tracker:
//  - Real database lineage: Spores (G0) -> Agar (G1-G2) -> Master LC (G2-G3) -> Subcultures (G4+) -> Grow Batches
//  - Interactive Node Inspector: Gen details, Senescence warning, Parent & Child transfers, Batches
//  - One-tap Active Operations: Next Gen Transfer (T+1), Start Grow Batch, Print QR Label, Edit
//  - Clear Empty States with contextual CTA (No fake dummy nodes)
//

import SwiftUI

enum LineageStage: Int, CaseIterable, Identifiable {
    case origin = 0
    case agar = 1
    case liquidCulture = 2
    case subcultures = 3
    case batches = 4
    
    var id: Int { rawValue }
    
    func title(isEnglish: Bool) -> String {
        switch self {
        case .origin: return isEnglish ? "1. Spores & Origin" : "1. Sporen & Oorsprong"
        case .agar: return isEnglish ? "2. Agar Isolaties" : "2. Agar Isolaties"
        case .liquidCulture: return isEnglish ? "3. Master LC & Broed" : "3. Master LC & Broed"
        case .subcultures: return isEnglish ? "4. Doorgeënte Lijnen" : "4. Doorgeënte Lijnen"
        case .batches: return isEnglish ? "5. Kweek Batches" : "5. Kweek Batches"
        }
    }
    
    func subtitle(isEnglish: Bool) -> String {
        switch self {
        case .origin: return "Generatie G0"
        case .agar: return "Generatie G1 - G2"
        case .liquidCulture: return "Generatie G2 - G3"
        case .subcultures: return isEnglish ? "Gen G4+ (Senescence Alert)" : "Gen G4+ (Let op)"
        case .batches: return isEnglish ? "Spawn & Fruiting Tubs" : "Broed & Vruchtvorming"
        }
    }
    
    var color: Color {
        switch self {
        case .origin: return Color.purple
        case .agar: return MycoTheme.blue
        case .liquidCulture: return MycoTheme.green
        case .subcultures: return MycoTheme.amber
        case .batches: return Color.cyan
        }
    }
}

struct ModernGeneticsLineageGraphView: View {
    @EnvironmentObject var store: MycoStore
    
    @State private var selectedStrainFilter: String = "Alle Soorten"
    @State private var inspectingCulture: CultureItem? = nil
    @State private var inspectingProject: GrowProject? = nil
    
    // Sheets
    @State private var showAddCultureSheet: Bool = false
    @State private var cultureToTransfer: CultureItem? = nil
    @State private var cultureForBatch: CultureItem? = nil
    @State private var editingCultureItem: CultureItem? = nil
    @State private var labelItemToPrint: CultureItem? = nil
    
    private var availableStrains: [String] {
        var set = Set<String>()
        for c in store.db.cultures where !c.strainName.isEmpty {
            set.insert(c.strainName)
        }
        for s in store.db.strains where !s.name.isEmpty {
            set.insert(s.name)
        }
        var list = ["Alle Soorten"]
        list.append(contentsOf: set.sorted())
        return list
    }
    
    private var filteredCultures: [CultureItem] {
        if selectedStrainFilter == "Alle Soorten" {
            return store.db.cultures
        }
        return store.db.cultures.filter { $0.strainName.caseInsensitiveCompare(selectedStrainFilter) == .orderedSame }
    }
    
    private var filteredProjects: [GrowProject] {
        let active = store.db.projects.filter { !$0.isArchived }
        if selectedStrainFilter == "Alle Soorten" {
            return active
        }
        return active.filter { $0.strainName.caseInsensitiveCompare(selectedStrainFilter) == .orderedSame }
    }
    
    private func parseGenNumber(_ genStr: String) -> Int {
        let clean = genStr.replacingOccurrences(of: "T", with: "").replacingOccurrences(of: "G", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(clean) ?? 1
    }
    
    // Stage 1: Sporen / Oorsprong (G0 / T0 / Clones / Swabs)
    private var originCultures: [CultureItem] {
        filteredCultures.filter { c in
            let t = c.cultureType.lowercased()
            let g = c.generation.uppercased()
            return t.contains("spoor") || t.contains("spore") || t.contains("print") || t.contains("swab") || t.contains("kloon") || t.contains("clone") || g == "G0" || g == "T0"
        }
    }
    
    // Stage 2: Agar Isolaties (G1 - G2)
    private var agarCultures: [CultureItem] {
        filteredCultures.filter { c in
            let t = c.cultureType.lowercased()
            let g = parseGenNumber(c.generation)
            let isAgar = t.contains("agar") || t.contains("petri") || t.contains("plaat") || t.contains("slant") || t.contains("schuin")
            return isAgar && g <= 2 && !originCultures.contains(where: { $0.id == c.id })
        }
    }
    
    // Stage 3: Liquid Culture Masters & Broed (G2 - G3)
    private var liquidCultureNodes: [CultureItem] {
        filteredCultures.filter { c in
            let t = c.cultureType.lowercased()
            let g = parseGenNumber(c.generation)
            let isLC = t.contains("lc") || t.contains("liquid") || t.contains("vloeibaar") || t.contains("broed") || t.contains("spawn")
            return isLC && g <= 3 && !originCultures.contains(where: { $0.id == c.id }) && !agarCultures.contains(where: { $0.id == c.id })
        }
    }
    
    // Stage 4: Subcultures & Senescentie (G4+)
    private var subculturesNodes: [CultureItem] {
        filteredCultures.filter { c in
            let g = parseGenNumber(c.generation)
            let isHighGen = g >= 4
            let isNotClassified = !originCultures.contains(where: { $0.id == c.id }) && !agarCultures.contains(where: { $0.id == c.id }) && !liquidCultureNodes.contains(where: { $0.id == c.id })
            return isHighGen || isNotClassified
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // 1. Header Bar with Strain Filter & Stats
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(store.t(nl: "Interactieve Stamboom Explorer", en: "Interactive Lineage Explorer"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        InfoTipButton(
                            title: store.t(nl: "Genetische Stamboom & Senescentie", en: "Genetic Lineage & Senescence"),
                            message: store.t(
                                nl: "Deze stamboom toont de echte afstammingslijn van je mycelium (van spoor tot kweekbatch). Bij elke overenting telt de generatie (G) op. Vanaf generatie 4 treedt senescentie op (celveroudering door telomeerverkorting). Tik op een cultuur om een nieuwe overenting (T+1) of batch te starten.",
                                en: "This lineage tracks actual genetic transfers from spore to fruiting tub. Transfers increment generation (G). Above generation 4, cellular senescence can slow growth. Tap any culture to transfer (T+1) or spawn a batch."
                            )
                        )
                    }
                    
                    Text(store.t(
                        nl: "\(filteredCultures.count) geregistreerde culturen • \(filteredProjects.count) actieve batches",
                        en: "\(filteredCultures.count) recorded cultures • \(filteredProjects.count) active batches"
                    ))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                }
                
                Spacer()
                
                // Strain Filter Menu
                if availableStrains.count > 1 {
                    Menu {
                        ForEach(availableStrains, id: \.self) { strain in
                            Button {
                                withAnimation {
                                    selectedStrainFilter = strain
                                }
                            } label: {
                                HStack {
                                    Text(strain)
                                    if selectedStrainFilter == strain {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedStrainFilter)
                                .font(.system(size: 11, weight: .bold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(MycoTheme.blue)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(MycoTheme.blue.opacity(0.12))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // 2. Main Visual Canvas or Clean Empty State
            if filteredCultures.isEmpty && filteredProjects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 32))
                        .foregroundColor(MycoTheme.green.opacity(0.8))
                        .padding(.top, 8)
                    
                    Text(store.t(
                        nl: "Nog geen stamboom voor \(selectedStrainFilter)",
                        en: "No lineage recorded for \(selectedStrainFilter)"
                    ))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    
                    Text(store.t(
                        nl: "Bouw de genetische stamboom op door een eerste sporenprint, agarplaat of vloeibare cultuur toe te voegen.",
                        en: "Build the genetic tree by adding a first spore print, agar plate, or liquid culture."
                    ))
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    
                    Button {
                        showAddCultureSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text(store.t(nl: "Eerste Cultuur Toevoegen", en: "Add First Culture"))
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(MycoTheme.green)
                        .cornerRadius(10)
                    }
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(Color(hex: "0E1218"))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(MycoTheme.border, lineWidth: 1))
            } else {
                // Interactive Horizontal Multi-Stage Canvas
                ScrollView([.horizontal], showsIndicators: true) {
                    HStack(alignment: .top, spacing: 14) {
                        
                        // Stage 1: Sporen & Oorsprong (G0)
                        stageColumn(
                            stage: .origin,
                            cultures: originCultures,
                            projects: []
                        )
                        
                        stageArrow
                        
                        // Stage 2: Agar Isolaties (G1-G2)
                        stageColumn(
                            stage: .agar,
                            cultures: agarCultures,
                            projects: []
                        )
                        
                        stageArrow
                        
                        // Stage 3: Master LC & Broed (G2-G3)
                        stageColumn(
                            stage: .liquidCulture,
                            cultures: liquidCultureNodes,
                            projects: []
                        )
                        
                        stageArrow
                        
                        // Stage 4: Doorgeënte Lijnen (G4+)
                        stageColumn(
                            stage: .subcultures,
                            cultures: subculturesNodes,
                            projects: []
                        )
                        
                        stageArrow
                        
                        // Stage 5: Kweek Batches
                        stageColumn(
                            stage: .batches,
                            cultures: [],
                            projects: filteredProjects
                        )
                    }
                    .padding(14)
                    .background(Color(hex: "0E1218"))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(MycoTheme.border, lineWidth: 1))
                }
            }
        }
        .sheet(item: $inspectingCulture) { cult in
            CultureNodeInspectorSheet(
                culture: cult,
                onTransfer: { c in
                    let child = store.transferCulture(parent: c)
                    inspectingCulture = nil
                    #if canImport(UIKit)
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    #endif
                    MycoSyncManager.shared.triggerToast(message: store.t(
                        nl: "✅ Overenting gelukt: \(child.generation) aangemaakt!",
                        en: "✅ Transfer created: \(child.generation)!"
                    ))
                },
                onStartBatch: { c in
                    cultureForBatch = c
                    inspectingCulture = nil
                },
                onPrintQR: { c in
                    labelItemToPrint = c
                    inspectingCulture = nil
                },
                onEdit: { c in
                    editingCultureItem = c
                    inspectingCulture = nil
                }
            )
            .environmentObject(store)
        }
        .sheet(item: $inspectingProject) { proj in
            ProjectNodeInspectorSheet(project: proj)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAddCultureSheet) {
            AddCultureSheetView(initialStrainName: selectedStrainFilter == "Alle Soorten" ? "" : selectedStrainFilter)
                .environmentObject(store)
        }
        .sheet(item: $cultureForBatch) { cult in
            NavigationStack {
                CreateBatchSheetView(
                    initialStrainName: cult.strainName,
                    initialParentCultureLabel: "\(cult.strainName) (\(cult.generation) • \(cult.qrCodeID.isEmpty ? cult.skuCode : cult.qrCodeID))"
                )
                .environmentObject(store)
            }
        }
        .sheet(item: $labelItemToPrint) { cult in
            NavigationStack {
                let formattedDate = cult.dateCreated.formatted(date: .numeric, time: .omitted)
                let richQR = """
🍄 MycoLabs Moedercultuur
Soort: \(store.displayTitle(name: cult.strainName, sku: cult.skuCode))
Type: \(cult.cultureType)
Generatie: \(cult.generation)
Status: \(cult.status)
Aangemaakt: \(formattedDate)
ID: \(cult.qrCodeID.isEmpty ? cult.skuCode : cult.qrCodeID)
"""
                QRLabelStudioView(labels: [(
                    title: store.displayTitle(name: cult.strainName, sku: cult.skuCode),
                    subtitle: "\(cult.cultureType) • \(cult.generation)",
                    date: formattedDate,
                    qr: richQR
                )])
                .environmentObject(store)
            }
        }
        .sheet(item: $editingCultureItem) { cult in
            EditCultureSheetView(item: cult)
                .environmentObject(store)
        }
    }
    
    private var stageArrow: some View {
        VStack {
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(MycoTheme.textSecondary.opacity(0.4))
            Spacer()
        }
        .frame(width: 12)
    }
    
    private func stageColumn(
        stage: LineageStage,
        cultures: [CultureItem],
        projects: [GrowProject]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stage.title(isEnglish: store.isEnglish))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text(stage.subtitle(isEnglish: store.isEnglish))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(stage.color)
            }
            .padding(.bottom, 2)
            
            if cultures.isEmpty && projects.isEmpty {
                VStack(spacing: 4) {
                    Text(store.t(nl: "Geen items in deze fase", en: "No items in this stage"))
                        .font(.system(size: 10))
                        .foregroundColor(MycoTheme.textSecondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(width: 165, height: 60)
                .background(Color.white.opacity(0.02))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
            } else {
                ForEach(cultures) { cult in
                    cultureNodeCard(cult: cult, stageColor: stage.color)
                }
                ForEach(projects) { proj in
                    projectNodeCard(proj: proj)
                }
            }
        }
        .frame(width: 175)
    }
    
    private func cultureNodeCard(cult: CultureItem, stageColor: Color) -> some View {
        let isSelected = inspectingCulture?.id == cult.id
        let genNum = parseGenNumber(cult.generation)
        let isSenescent = genNum >= 4
        let childCount = store.db.cultures.filter { $0.parentID == cult.id }.count
        
        let typeIcon: String = {
            let t = cult.cultureType.lowercased()
            if t.contains("spoor") || t.contains("print") { return "allergens" }
            if t.contains("agar") || t.contains("petri") { return "circle.hexagongrid.fill" }
            if t.contains("lc") || t.contains("vloeibaar") { return "drop.fill" }
            if t.contains("slant") { return "testtube.2" }
            if t.contains("kloon") { return "leaf.arrow.triangle.circlepath" }
            return "leaf.fill"
        }()
        
        return Button {
            inspectingCulture = cult
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: typeIcon)
                        .foregroundColor(isSenescent ? MycoTheme.amber : stageColor)
                        .font(.system(size: 12, weight: .bold))
                    
                    Spacer()
                    
                    Text(cult.generation.isEmpty ? "G0" : cult.generation)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(isSenescent ? MycoTheme.amber : MycoTheme.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background((isSenescent ? MycoTheme.amber : MycoTheme.blue).opacity(0.16))
                        .cornerRadius(4)
                }
                
                Text(cult.strainName.isEmpty ? store.t(nl: "Onbekende Soort", en: "Unknown Strain") : cult.strainName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(cult.mediaName.isEmpty ? cult.cultureType : cult.mediaName)
                    .font(.system(size: 9))
                    .foregroundColor(MycoTheme.textSecondary)
                    .lineLimit(1)
                
                if childCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 8))
                        Text(store.t(nl: "\(childCount) overenting(en)", en: "\(childCount) transfer(s)"))
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundColor(MycoTheme.green)
                    .padding(.top, 1)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? stageColor.opacity(0.18) : Color(hex: "151A22"))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? stageColor : (isSenescent ? MycoTheme.amber.opacity(0.5) : MycoTheme.border), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func projectNodeCard(proj: GrowProject) -> some View {
        let isSelected = inspectingProject?.id == proj.id
        return Button {
            inspectingProject = proj
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(Color.cyan)
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text("Batch #\(proj.batchNumber)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.cyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.16))
                        .cornerRadius(4)
                }
                
                Text(proj.strainName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(proj.phase.localized(isEnglish: store.isEnglish))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(MycoTheme.green)
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(MycoTheme.textSecondary)
                    
                    Text("\(Int(proj.colonizationPercent))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.cyan.opacity(0.18) : Color(hex: "151A22"))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.cyan : MycoTheme.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CULTURE NODE INSPECTOR SHEET
struct CultureNodeInspectorSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    let culture: CultureItem
    let onTransfer: (CultureItem) -> Void
    let onStartBatch: (CultureItem) -> Void
    let onPrintQR: (CultureItem) -> Void
    let onEdit: (CultureItem) -> Void
    
    private var genNum: Int {
        let clean = culture.generation.replacingOccurrences(of: "T", with: "").replacingOccurrences(of: "G", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(clean) ?? 1
    }
    
    private var isSenescent: Bool { genNum >= 4 }
    
    private var childTransfers: [CultureItem] {
        store.db.cultures.filter { $0.parentID == culture.id }
    }
    
    private var connectedBatches: [GrowProject] {
        store.db.projects.filter { $0.parentCultureID == culture.id || (!culture.strainName.isEmpty && $0.strainName.caseInsensitiveCompare(culture.strainName) == .orderedSame) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 1. Culture Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(culture.strainName.isEmpty ? "Cultuur" : culture.strainName)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("\(culture.cultureType) • \(culture.skuCode.isEmpty ? culture.qrCodeID : culture.skuCode)")
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text(culture.generation)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(isSenescent ? MycoTheme.amber : MycoTheme.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((isSenescent ? MycoTheme.amber : MycoTheme.blue).opacity(0.18))
                                .cornerRadius(6)
                        }
                        
                        Divider().background(Color.white.opacity(0.08))
                        
                        HStack(spacing: 12) {
                            if !culture.mediaName.isEmpty {
                                Label(culture.mediaName, systemImage: "drop.fill")
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                            Label(culture.status, systemImage: "waveform.path.ecg")
                                .font(.caption)
                                .foregroundColor(MycoTheme.green)
                        }
                    }
                    .padding(14)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
                    
                    // 2. Senescence & Vitality Status
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: isSenescent ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                                .foregroundColor(isSenescent ? MycoTheme.amber : MycoTheme.green)
                            Text(isSenescent ? store.t(nl: "Senescentie Alert (Generatie G\(genNum))", en: "Senescence Alert (Generation G\(genNum))") : store.t(nl: "Optimale Vitaliteit (Generatie G\(genNum))", en: "Optimal Vitality (Generation G\(genNum))"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isSenescent ? MycoTheme.amber : MycoTheme.green)
                        }
                        
                        Text(isSenescent
                             ? store.t(
                                nl: "Mycelium zit op generatie G\(genNum). Na 4 of 5 overentingen treedt senescentie op (verkorting van telomeren en genetische drift). Aanbevolen: herstart van een cryo-master of verse sporenkieming.",
                                en: "Culture is at generation G\(genNum). Above G4, senescence and genetic drift occur. Recommended: restart from a frozen master or fresh spores."
                             )
                             : store.t(
                                nl: "Jonge, vitale cultuurlijn met sterke kolonisatie en hoge enzymatische activiteit.",
                                en: "Vigorous young culture line with high enzymatic activity and fast colonization."
                             ))
                        .font(.caption)
                        .foregroundColor(MycoTheme.textSecondary)
                    }
                    .padding(12)
                    .background((isSenescent ? MycoTheme.amber : MycoTheme.green).opacity(0.08))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke((isSenescent ? MycoTheme.amber : MycoTheme.green).opacity(0.25), lineWidth: 1))
                    
                    // 3. Mother Lineage & Child Transfers
                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.t(nl: "Afstammingslijn & Overentingen", en: "Lineage & Subcultures"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        
                        if !culture.parentLabel.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.turn.left.up")
                                    .foregroundColor(MycoTheme.blue)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(store.t(nl: "Moedercultuur:", en: "Mother Culture:"))
                                        .font(.system(size: 10))
                                        .foregroundColor(MycoTheme.textSecondary)
                                    Text(culture.parentLabel)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                        }
                        
                        if childTransfers.isEmpty {
                            Text(store.t(nl: "Nog geen dochteroverentingen gemaakt van deze cultuur.", en: "No subcultures made from this culture yet."))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(childTransfers) { child in
                                    HStack {
                                        Image(systemName: "arrow.turn.down.right")
                                            .foregroundColor(MycoTheme.green)
                                            .font(.caption)
                                        Text(child.strainName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(child.generation)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(MycoTheme.blue)
                                    }
                                    .padding(8)
                                    .background(Color.white.opacity(0.03))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(MycoTheme.card)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
                    
                    // 4. Action Buttons
                    VStack(spacing: 10) {
                        Button {
                            onTransfer(culture)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.branch")
                                Text(store.t(nl: "Nieuwe Overenting Maken (T+1)", en: "Create Next Transfer (T+1)"))
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(MycoTheme.blue)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        HStack(spacing: 10) {
                            Button {
                                onStartBatch(culture)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus.circle.fill")
                                    Text(store.t(nl: "Start Batch", en: "Start Batch"))
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(MycoTheme.green)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                onPrintQR(culture)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "qrcode")
                                    Text(store.t(nl: "Print QR", en: "Print QR"))
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                onEdit(culture)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "pencil")
                                    Text(store.t(nl: "Bewerken", en: "Edit"))
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(MycoTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Cultuur Stamboom Detail", en: "Culture Lineage Detail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t(nl: "Gereed", en: "Done")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - PROJECT NODE INSPECTOR SHEET
struct ProjectNodeInspectorSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    let project: GrowProject
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(project.strainName)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text("Batch #\(project.batchNumber)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.18))
                            .cornerRadius(6)
                    }
                    
                    Text("\(project.phase.localized(isEnglish: store.isEnglish)) • \(Int(project.colonizationPercent))% gekoloniseerd")
                        .font(.caption)
                        .foregroundColor(MycoTheme.green)
                }
                .padding(14)
                .background(MycoTheme.card)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 8) {
                    if !project.containerName.isEmpty {
                        HStack {
                            Text(store.t(nl: "Container:", en: "Container:"))
                                .foregroundColor(MycoTheme.textSecondary)
                            Spacer()
                            Text(project.containerName).foregroundColor(.white)
                        }
                    }
                    if !project.substrateName.isEmpty {
                        HStack {
                            Text(store.t(nl: "Substraat:", en: "Substrate:"))
                                .foregroundColor(MycoTheme.textSecondary)
                            Spacer()
                            Text(project.substrateName).foregroundColor(.white)
                        }
                    }
                    if !project.parentCultureLabel.isEmpty {
                        HStack {
                            Text(store.t(nl: "Moedercultuur:", en: "Mother Culture:"))
                                .foregroundColor(MycoTheme.textSecondary)
                            Spacer()
                            Text(project.parentCultureLabel).foregroundColor(MycoTheme.blue)
                        }
                    }
                }
                .font(.system(size: 12))
                .padding(14)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding(16)
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Batch Stamboom Link", en: "Batch Lineage Link"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t(nl: "Sluiten", en: "Close")) { dismiss() }
                }
            }
        }
    }
}
