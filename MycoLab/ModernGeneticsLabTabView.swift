//
//  ModernGeneticsLabTabView.swift
//  MycoLab
//
//  Modern Living Genetics & Cultures Lab:
//  - Serene Apple-grade layout for Agar, Liquid Cultures, Spores & Strains
//  - Living Petri Dish indicators with ambient mycelial glow
//  - Genetic lineage badges (T0 -> T1 -> T2 -> Master LC)
//  - Instant T+1 transfer action & QR label print sheet
//  - 100% reversible: instant fallback to Classic Genetics Lab
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - LIVING PETRI DISH ICON
struct LivingPetriDishIcon: View {
    let cultureType: String
    let status: String
    
    @State private var isBreathing = false
    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: Double = 0.7
    
    private var isContam: Bool {
        status.lowercased().contains("besmet") || status.lowercased().contains("gecontamineerd") || status.lowercased().contains("contam")
    }
    
    private var isFridge: Bool {
        status.lowercased().contains("koelkast") || status.lowercased().contains("koude") || status.lowercased().contains("cold")
    }
    
    private var isReady: Bool {
        status.lowercased().contains("gekoloniseerd") || status.lowercased().contains("klaar") || status.lowercased().contains("ready")
    }
    
    private var statusColor: Color {
        if isContam { return MycoTheme.red }
        if isFridge { return MycoTheme.blue }
        if isReady { return MycoTheme.green }
        return MycoTheme.amber
    }
    
    private var iconName: String {
        let t = cultureType.lowercased()
        if t.contains("agar") || t.contains("petri") { return "circle.hexagongrid.fill" }
        if t.contains("vloeibaar") || t.contains("lc") || t.contains("liquid") { return "drop.fill" }
        if t.contains("spoor") || t.contains("spore") { return "allergens" }
        if t.contains("slant") { return "testtube.2" }
        if t.contains("kloon") || t.contains("clone") { return "leaf.fill" }
        return "flask.fill"
    }
    
    var body: some View {
        ZStack {
            // Radiating living spore ripple
            Circle()
                .stroke(statusColor.opacity(0.4), lineWidth: 1.5)
                .frame(width: 44, height: 44)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
            
            // Ambient Petri Bio-Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [statusColor.opacity(isBreathing ? 0.45 : 0.15), Color.clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: isBreathing ? 34 : 20
                    )
                )
                .frame(width: 56, height: 56)
                .scaleEffect(isBreathing ? 1.12 : 0.92)
            
            // Outer Petri Ring
            Circle()
                .stroke(statusColor.opacity(0.5), lineWidth: 2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.04)))
            
            // Inner symbol
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(statusColor)
                .scaleEffect(isBreathing ? 1.06 : 0.94)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
                rippleScale = 1.4
                rippleOpacity = 0.0
            }
        }
    }
}

// MARK: - MODERN CULTURE CARD
struct ModernCultureCard: View {
    @EnvironmentObject var store: MycoStore
    let item: CultureItem
    let onEdit: () -> Void
    let onTransfer: () -> Void
    let onShowLabel: () -> Void
    let onDelete: () -> Void
    
    private var isContam: Bool {
        item.status.lowercased().contains("besmet") || item.status.lowercased().contains("gecontamineerd") || item.status.lowercased().contains("contam")
    }
    
    private var isFridge: Bool {
        item.status.lowercased().contains("koelkast") || item.status.lowercased().contains("koude") || item.status.lowercased().contains("cold")
    }
    
    private var isReady: Bool {
        item.status.lowercased().contains("gekoloniseerd") || item.status.lowercased().contains("klaar") || item.status.lowercased().contains("ready")
    }
    
    private var statusColor: Color {
        if isContam { return MycoTheme.red }
        if isFridge { return MycoTheme.blue }
        if isReady { return MycoTheme.green }
        return MycoTheme.amber
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Living Petri Ring + Title + Generation + Status Pill
            HStack(alignment: .top, spacing: 12) {
                LivingPetriDishIcon(cultureType: item.cultureType, status: item.status)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.displayTitle(name: item.strainName, sku: item.skuCode))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        // Generation badge
                        Text(item.generation)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(MycoTheme.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MycoTheme.blue.opacity(0.18))
                            .cornerRadius(5)
                        
                        Text(store.localizeCultureType(item.cultureType))
                            .font(.system(size: 11))
                            .foregroundColor(MycoTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Status pill
                Text(store.localizeCultureStatus(item.status))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.14))
                    .cornerRadius(6)
            }
            
            // Lineage & Media details
            if !item.mediaName.isEmpty || !item.parentLabel.isEmpty {
                HStack(spacing: 8) {
                    if !item.mediaName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "flask.fill")
                                .font(.system(size: 9))
                                .foregroundColor(MycoTheme.textSecondary)
                            Text(store.localizePresetName(item.mediaName))
                                .font(.system(size: 11))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    
                    if !item.parentLabel.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 9))
                                .foregroundColor(MycoTheme.amber)
                            Text(item.parentLabel)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(MycoTheme.amber)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.system(size: 11))
                    .foregroundColor(MycoTheme.textSecondary.opacity(0.9))
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }
            
            Divider()
                .background(MycoTheme.border)
            
            // Action Bar: 1-Tap Transfer, Label, Edit & 3-dots Menu
            HStack(spacing: 8) {
                // Transfer button
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    onTransfer()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.branch")
                            .font(.system(size: 11, weight: .bold))
                        Text(store.t(nl: "Transfer (T+1)", en: "Transfer (T+1)"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MycoTheme.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Label & QR button
                Button {
                    onShowLabel()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 11))
                        Text(store.t(nl: "Label", en: "Label"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(MycoTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Direct Edit button
                Button {
                    onEdit()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                        Text(store.t(nl: "Bewerk", en: "Edit"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(MycoTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 3-dots Full Management Menu
                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label(store.t(nl: "Bewerk Cultuur Details", en: "Edit Culture Details"), systemImage: "pencil")
                    }

                    Divider()

                    Menu(store.t(nl: "Wijzig Status", en: "Change Status")) {
                        ForEach([
                            "Actieve Groei / Incubatiefase",
                            "Volledig Gekoloniseerd / Klaar voor Gebruik",
                            "Koude Bewaring / 4°C Koelkast",
                            "Quarantaine / Zuiverheidscontrole",
                            "Doorgeënt / Subcultuur",
                            "Verouderd / Uitgeput",
                            "Gecontamineerd / Besmet"
                        ], id: \.self) { s in
                            Button {
                                if let idx = store.db.cultures.firstIndex(where: { $0.id == item.id }) {
                                    store.db.cultures[idx].status = s
                                    store.db.cultures[idx].lastModifiedAt = Date()
                                    store.save()
                                }
                            } label: {
                                HStack {
                                    Text(store.localizeCultureStatus(s))
                                    if item.status == s {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        onShowLabel()
                    } label: {
                        Label(store.t(nl: "Print / Deel QR Label", en: "Print / Share QR Label"), systemImage: "qrcode")
                    }

                    Button {
                        onTransfer()
                    } label: {
                        Label(store.t(nl: "Nieuwe Subcultuur (T+1)", en: "New Subculture (T+1)"), systemImage: "arrow.branch")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(store.t(nl: "Verwijder Cultuur", en: "Delete Culture"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(MycoTheme.textSecondary)
                        .padding(4)
                }
            }
        }
        .padding(14)
        .background(MycoTheme.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
    }
}

// MARK: - MODERN STRAIN CARD
struct ModernStrainCard: View {
    @EnvironmentObject var store: MycoStore
    let strain: StrainModel
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var typeColor: Color {
        switch strain.mushroomType {
        case .culinary: return MycoTheme.green
        case .medicinal: return MycoTheme.blue
        case .active: return MycoTheme.amber
        case .other: return MycoTheme.textSecondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: strain.mushroomType.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(typeColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(store.displayTitle(name: strain.name, sku: strain.skuCode))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Toepassing / Categorie badge
                    HStack(spacing: 3) {
                        Image(systemName: strain.mushroomType.icon)
                            .font(.system(size: 8))
                        Text(strain.mushroomType.shortLabel(isEnglish: store.isEnglish))
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(typeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.16))
                    .cornerRadius(4)
                    
                    // Alleen voor actieve soorten: optionele sterkte indicatie
                    if strain.mushroomType == .active && strain.potencyMultiplier > 0 {
                        Text(String(format: "%.1fx", strain.potencyMultiplier))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(MycoTheme.amber.opacity(0.9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(MycoTheme.amber.opacity(0.12))
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 6) {
                    Text(strain.species)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundColor(MycoTheme.textSecondary)
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(MycoTheme.textSecondary.opacity(0.4))
                    
                    // Kolonisatiesnelheid
                    HStack(spacing: 2) {
                        Image(systemName: strain.colonizationSpeed.icon)
                            .font(.system(size: 8))
                        Text(strain.colonizationSpeed.localized(isEnglish: store.isEnglish))
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(MycoTheme.textSecondary)
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(MycoTheme.textSecondary.opacity(0.4))
                    
                    // Moeilijkheidsgraad
                    HStack(spacing: 2) {
                        Text(strain.difficulty.stars)
                            .font(.system(size: 7))
                            .foregroundColor(MycoTheme.amber)
                        Text(strain.difficulty.localized(isEnglish: store.isEnglish))
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(MycoTheme.textSecondary)
                }
                
                if !strain.notes.isEmpty {
                    Text(strain.notes)
                        .font(.system(size: 10))
                        .foregroundColor(MycoTheme.textSecondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MycoTheme.blue)
                    .padding(6)
                    .background(MycoTheme.blue.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(MycoTheme.textSecondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(MycoTheme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
    }
}

// MARK: - MODERN GENETICS LAB TAB VIEW
struct ModernGeneticsLabTabView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedFilter = "Alle Culturen"
    @State private var showAddCulture = false
    @State private var showAddStrain = false
    @State private var selectedLabelItem: CultureItem? = nil
    @State private var editingCultureItem: CultureItem? = nil
    @State private var editingStrainItem: StrainModel? = nil
    @State private var showSettings = false
    @State private var showCleanroomVoice = false
    
    private let filterOptions = [
        "Alle Culturen",
        "Stamboom Explorer",
        "Liquid Culture (LC)",
        "Agar Petri",
        "Sporen",
        "Soorten Bibliotheek"
    ]
    
    private var isWideGrid: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }
    
    var filteredCultures: [CultureItem] {
        store.db.cultures.filter { item in
            if selectedFilter == "Alle Culturen" { return true }
            let t = item.cultureType.lowercased()
            if selectedFilter == "Liquid Culture (LC)" {
                return t.contains("vloeibaar") || t.contains("lc") || t.contains("liquid")
            }
            if selectedFilter == "Agar Petri" {
                return t.contains("agar") || t.contains("petri") || t.contains("slant")
            }
            if selectedFilter == "Sporen" {
                return t.contains("spoor") || t.contains("spore") || t.contains("swab")
            }
            return true
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // MARK: - 1. Serene Genetics Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.db.stealthMode ? "Genetics Bank" : store.t(nl: "Genetica & Culturen", en: "Genetics & Cultures"))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(store.db.cultures.isEmpty ? MycoTheme.textSecondary : MycoTheme.green)
                                    .frame(width: 6, height: 6)
                                Text(store.t(
                                    nl: "\(store.db.cultures.count) actieve culturen • \(store.db.strains.count) soorten",
                                    en: "\(store.db.cultures.count) active cultures • \(store.db.strains.count) strains"
                                ))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        // + Cultuur / Soort Button
                        Button {
                            if selectedFilter == "Soorten Bibliotheek" {
                                showAddStrain = true
                            } else {
                                showAddCulture = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text(selectedFilter == "Soorten Bibliotheek" ? store.t(nl: "Soort", en: "Strain") : store.t(nl: "Cultuur", en: "Culture"))
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [MycoTheme.blue, MycoTheme.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(20)
                            .shadow(color: MycoTheme.blue.opacity(0.35), radius: 6, x: 0, y: 2)
                        }
                    }
                    .padding(.top, 4)
                    
                    // MARK: - 2. Filter Chips Scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filterOptions, id: \.self) { opt in
                                let isSelected = selectedFilter == opt
                                let count: Int = {
                                    if opt == "Alle Culturen" { return store.db.cultures.count }
                                    if opt == "Liquid Culture (LC)" {
                                        return store.db.cultures.filter {
                                            let t = $0.cultureType.lowercased()
                                            return t.contains("vloeibaar") || t.contains("lc") || t.contains("liquid")
                                        }.count
                                    }
                                    if opt == "Agar Petri" {
                                        return store.db.cultures.filter {
                                            let t = $0.cultureType.lowercased()
                                            return t.contains("agar") || t.contains("petri") || t.contains("slant")
                                        }.count
                                    }
                                    if opt == "Sporen" {
                                        return store.db.cultures.filter {
                                            let t = $0.cultureType.lowercased()
                                            return t.contains("spoor") || t.contains("spore") || t.contains("swab")
                                        }.count
                                    }
                                    if opt == "Soorten Bibliotheek" { return store.db.strains.count }
                                    return 0
                                }()
                                
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        selectedFilter = opt
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(opt)
                                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                        if count > 0 {
                                            Text("\(count)")
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .foregroundColor(isSelected ? .white : MycoTheme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? MycoTheme.blue : MycoTheme.card)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(isSelected ? MycoTheme.blue : MycoTheme.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // MARK: - 3. Content: Cultures or Strains
                    if selectedFilter == "Stamboom Explorer" {
                        ModernGeneticsLineageGraphView()
                    } else if selectedFilter == "Soorten Bibliotheek" {
                        if store.db.strains.isEmpty {
                            EmptyStateCard(
                                icon: "leaf.fill",
                                title: store.t(nl: "Geen soorten opgeslagen", en: "No strains saved"),
                                message: store.t(nl: "Voeg hier jouw paddenstoelensoorten toe om ze overal in het lab te kunnen selecteren.", en: "Add your mushroom strains here to select them anywhere in the lab."),
                                buttonTitle: store.t(nl: "+ Eerste Soort Toevoegen", en: "+ Add First Strain")
                            ) {
                                showAddStrain = true
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(store.db.strains) { strain in
                                    ModernStrainCard(
                                        strain: strain,
                                        onEdit: { editingStrainItem = strain },
                                        onDelete: {
                                            withAnimation {
                                                store.db.strains.removeAll { $0.id == strain.id }
                                                store.save()
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    } else {
                        if filteredCultures.isEmpty {
                            EmptyStateCard(
                                icon: "allergens",
                                title: store.t(nl: "Geen culturen gevonden", en: "No cultures found"),
                                message: store.t(nl: "Voeg je eerste vloeibare cultuur (LC) of agar-plaat (T0, T1) toe om je genetica vast te leggen.", en: "Add your first liquid culture (LC) or agar plate (T0, T1) to track your genetics."),
                                buttonTitle: store.t(nl: "+ Eerste Cultuur Toevoegen", en: "+ Add First Culture")
                            ) {
                                showAddCulture = true
                            }
                        } else if isWideGrid {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 350), spacing: 14)], spacing: 14) {
                                ForEach(filteredCultures) { item in
                                    ModernCultureCard(
                                        item: item,
                                        onEdit: { editingCultureItem = item },
                                        onTransfer: { transferCulture(item) },
                                        onShowLabel: { selectedLabelItem = item },
                                        onDelete: {
                                            withAnimation {
                                                store.deleteCulture(id: item.id)
                                            }
                                        }
                                    )
                                }
                            }
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredCultures) { item in
                                    ModernCultureCard(
                                        item: item,
                                        onEdit: { editingCultureItem = item },
                                        onTransfer: { transferCulture(item) },
                                        onShowLabel: { selectedLabelItem = item },
                                        onDelete: {
                                            withAnimation {
                                                store.deleteCulture(id: item.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(16)
                .padding(.bottom, 60)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showCleanroomVoice = true
                        } label: {
                            Image(systemName: "waveform.and.mic")
                                .font(.system(size: 16))
                                .foregroundColor(Color.cyan)
                        }
                        .accessibilityLabel("Cleanroom Voice Assistant")
                        
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheetView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showCleanroomVoice) {
                CleanroomVoiceConsoleView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showAddCulture) {
                AddCultureSheetView().environmentObject(store)
            }
            .sheet(isPresented: $showAddStrain) {
                AddStrainSheetView().environmentObject(store)
            }
            .sheet(item: $selectedLabelItem) { cult in
                NavigationStack {
                    let formattedDate = cult.dateCreated.formatted(date: .numeric, time: .omitted)
                    let richQR = """
🍄 MycoLabs Moedercultuur
Soort: \(store.displayTitle(name: cult.strainName, sku: cult.skuCode))
Type: \(cult.cultureType)
Generatie: \(cult.generation)
Status: \(cult.status)
Aangemaakt: \(formattedDate)
ID: \(cult.qrCodeID)
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
            .sheet(item: $editingStrainItem) { strain in
                EditStrainSheetView(strain: strain)
                    .environmentObject(store)
            }
        }
    }
    
    private func transferCulture(_ parent: CultureItem) {
        let nextGen: String
        if parent.generation.uppercased().hasPrefix("T"),
           let num = Int(parent.generation.dropFirst()) {
            nextGen = "T\(num + 1)"
        } else {
            nextGen = parent.generation + "-T1"
        }
        let sku = store.nextSKU(prefix: "CLT")
        let child = CultureItem(
            strainName: parent.strainName,
            skuCode: sku,
            cultureType: parent.cultureType,
            generation: nextGen,
            parentID: parent.id,
            parentLabel: "\(parent.strainName) (\(parent.generation) • \(parent.qrCodeID))",
            mediaName: parent.mediaName,
            status: "Kolonisatie",
            qrCodeID: "QR-\(sku)-\(Int.random(in: 100...999))",
            notes: "Automatische transfer van \(parent.qrCodeID)"
        )
        withAnimation {
            store.db.cultures.insert(child, at: 0)
            store.save()
        }
    }
}


// MARK: - EDIT CULTURE SHEET VIEW
struct EditCultureSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss

    let item: CultureItem

    @State private var strainName: String
    @State private var cultureType: String
    @State private var customCultureType: String = ""
    @State private var generation: String
    @State private var mediaName: String
    @State private var parentLabel: String
    @State private var status: String
    @State private var customStatus: String = ""
    @State private var dateCreated: Date
    @State private var notes: String
    @State private var showDeleteConfirm = false

    private let standardTypes = [
        "Vloeibare Cultuur (Liquid Culture - LC)",
        "Agar Petrischaal (Myceliumplaat)",
        "Agar Schuinbuis / Slant (Langetermijnopslag)",
        "Sporenspuit / Sporenprint (Sporensuspensie)",
        "Spore Swab (Katoenstaafje)",
        "Weefselkloon (Biopsie vers vruchtlichaam)",
        "Moederbroed / Graanbroed (Master Grain)",
        "Anders / Zelf typen..."
    ]

    private let standardStatuses = [
        "Actieve Groei / Incubatiefase",
        "Volledig Gekoloniseerd / Klaar voor Gebruik",
        "Koude Bewaring / 4°C Koelkast",
        "Quarantaine / Zuiverheidscontrole",
        "Doorgeënt / Subcultuur",
        "Verouderd / Uitgeput",
        "Gecontamineerd / Besmet",
        "Anders / Zelf typen..."
    ]

    init(item: CultureItem) {
        self.item = item
        _strainName = State(initialValue: item.strainName)
        
        if [
            "Vloeibare Cultuur (Liquid Culture - LC)",
            "Agar Petrischaal (Myceliumplaat)",
            "Agar Schuinbuis / Slant (Langetermijnopslag)",
            "Sporenspuit / Sporenprint (Sporensuspensie)",
            "Spore Swab (Katoenstaafje)",
            "Weefselkloon (Biopsie vers vruchtlichaam)",
            "Moederbroed / Graanbroed (Master Grain)"
        ].contains(where: { $0.caseInsensitiveCompare(item.cultureType) == .orderedSame }) {
            _cultureType = State(initialValue: item.cultureType)
            _customCultureType = State(initialValue: "")
        } else {
            _cultureType = State(initialValue: "Anders / Zelf typen...")
            _customCultureType = State(initialValue: item.cultureType)
        }
        
        _generation = State(initialValue: item.generation)
        _mediaName = State(initialValue: item.mediaName)
        _parentLabel = State(initialValue: item.parentLabel)
        
        if [
            "Actieve Groei / Incubatiefase",
            "Volledig Gekoloniseerd / Klaar voor Gebruik",
            "Koude Bewaring / 4°C Koelkast",
            "Quarantaine / Zuiverheidscontrole",
            "Doorgeënt / Subcultuur",
            "Verouderd / Uitgeput",
            "Gecontamineerd / Besmet"
        ].contains(where: { $0.caseInsensitiveCompare(item.status) == .orderedSame }) {
            _status = State(initialValue: item.status)
            _customStatus = State(initialValue: "")
        } else {
            _status = State(initialValue: "Anders / Zelf typen...")
            _customStatus = State(initialValue: item.status)
        }
        
        _dateCreated = State(initialValue: item.dateCreated)
        _notes = State(initialValue: item.notes)
    }

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
                // Section 1: Genetica & Soort
                Section(header: Text(store.t(nl: "Genetica & Soort", en: "Genetics & Strain"))) {
                    if !store.db.strains.isEmpty {
                        Picker(store.t(nl: "Kies uit geregistreerde soorten", en: "Choose from saved strains"), selection: $strainName) {
                            Text(store.t(nl: "Handmatig typen hieronder...", en: "Type manually below...")).tag("")
                            ForEach(store.db.strains) { s in
                                Text(s.name).tag(s.name)
                            }
                        }
                    }
                    TextField(store.t(nl: "Naam van Soort / Strain", en: "Strain Name"), text: $strainName)
                    
                    HStack {
                        Text(store.t(nl: "SKU Code & Label ID", en: "SKU Code & Label ID"))
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        Text(item.skuCode.isEmpty ? "CLT" : item.skuCode)
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(MycoTheme.blue)
                    }
                }

                // Section 2: Type Cultuur & Generatie
                Section(header: Text(store.t(nl: "Type Cultuur & Generatie", en: "Culture Type & Generation"))) {
                    Picker(store.t(nl: "Type Cultuur", en: "Culture Type"), selection: $cultureType) {
                        ForEach(standardTypes, id: \.self) { t in
                            Text(store.localizeCultureType(t)).tag(t)
                        }
                    }
                    if cultureType == "Anders / Zelf typen..." {
                        TextField(store.t(nl: "Typ eigen type cultuur (bijv. Slant, Moederkloon)", en: "Type custom culture type"), text: $customCultureType)
                    }

                    TextField(store.t(nl: "Generatie Code (bijv. T0, T1, LC-1)", en: "Generation Code (e.g. T0, T1, LC-1)"), text: $generation)

                    // Snelle generatie kiezers
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(["T0", "T1", "T2", "T3", "LC-1", "LC-2", "G1", "Clone-1"], id: \.self) { genChip in
                                Button {
                                    generation = genChip
                                } label: {
                                    Text(genChip)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(generation == genChip ? MycoTheme.blue : Color.white.opacity(0.08))
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Section 3: Voedingsbodem & Moederlijn
                Section(header: Text(store.t(nl: "Voedingsbodem & Moederlijn", en: "Growth Medium & Lineage"))) {
                    let mediaPresets = store.db.presets.filter { $0.category == .media }
                    if !mediaPresets.isEmpty {
                        Picker(store.t(nl: "Kies Media Preset", en: "Choose Media Preset"), selection: $mediaName) {
                            Text(store.t(nl: "Handmatig typen...", en: "Type manually...")).tag("")
                            ForEach(mediaPresets) { p in
                                Text(store.localizePresetName(p.name)).tag(p.name)
                            }
                        }
                    }
                    TextField(store.t(nl: "Voedingsbodem / Media (bijv. MEA + Pepton)", en: "Growth Medium (e.g. MEA + Peptone)"), text: $mediaName)

                    // Parent Lineage
                    let otherCultures = store.db.cultures.filter { $0.id != item.id }
                    if !otherCultures.isEmpty {
                        Picker(store.t(nl: "Kies Moederbron / Parent", en: "Select Parent Source"), selection: $parentLabel) {
                            Text(store.t(nl: "Handmatig / Geen", en: "Manual / None")).tag("")
                            ForEach(otherCultures) { c in
                                Text("\(c.generation) \(c.strainName) (\(c.skuCode))").tag("\(c.generation)-\(c.skuCode)")
                            }
                        }
                    }
                    TextField(store.t(nl: "Moederlijn Label (bijv. T0-GT-01)", en: "Parent Label"), text: $parentLabel)
                }

                // Section 4: Status & Datum
                Section(header: Text(store.t(nl: "Status & Inoculatiedatum", en: "Status & Inoculation Date"))) {
                    Picker(store.t(nl: "Status", en: "Status"), selection: $status) {
                        ForEach(standardStatuses, id: \.self) { s in
                            Text(store.localizeCultureStatus(s)).tag(s)
                        }
                    }
                    if status == "Anders / Zelf typen..." {
                        TextField(store.t(nl: "Typ eigen status...", en: "Type custom status..."), text: $customStatus)
                    }

                    DatePicker(
                        store.t(nl: "Aangemaakt / Geënt op", en: "Created / Inoculated on"),
                        selection: $dateCreated,
                        displayedComponents: [.date]
                    )
                }

                // Section 5: Notities & Observaties
                Section(header: Text(store.t(nl: "Notities & Observaties", en: "Notes & Observations"))) {
                    TextField(
                        store.t(nl: "Typ observaties (bijv. rizomorfe groei, geur, sectoring)...", en: "Notes on growth, sectoring, smell..."),
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                }

                // Section 6: Gevarenzone
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text(store.t(nl: "Verwijder Deze Cultuur", en: "Delete This Culture"))
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Cultuur Bewerken", en: "Edit Culture"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(nl: "Annuleren", en: "Cancel")) {
                        dismiss()
                    }
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
            .alert(store.t(nl: "Cultuur Verwijderen?", en: "Delete Culture?"), isPresented: $showDeleteConfirm) {
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
                Button(store.t(nl: "Verwijderen", en: "Delete"), role: .destructive) {
                    store.deleteCulture(id: item.id)
                    dismiss()
                }
            } message: {
                Text(store.t(
                    nl: "Weet je zeker dat je '\(item.strainName)' wilt verwijderen? Dit kan niet ongedaan worden gemaakt.",
                    en: "Are you sure you want to delete '\(item.strainName)'? This cannot be undone."
                ))
            }
        }
    }

    private func saveChanges() {
        let cleanStrain = strainName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanStrain.isEmpty else { return }

        if let idx = store.db.cultures.firstIndex(where: { $0.id == item.id }) {
            store.db.cultures[idx].strainName = cleanStrain
            store.db.cultures[idx].cultureType = effectiveCultureType
            store.db.cultures[idx].generation = generation.trimmingCharacters(in: .whitespaces)
            store.db.cultures[idx].mediaName = mediaName.trimmingCharacters(in: .whitespaces)
            store.db.cultures[idx].parentLabel = parentLabel.trimmingCharacters(in: .whitespaces)
            store.db.cultures[idx].status = effectiveStatus
            store.db.cultures[idx].dateCreated = dateCreated
            store.db.cultures[idx].notes = notes
            store.db.cultures[idx].lastModifiedAt = Date()
            store.save()

            if !store.db.strains.contains(where: { $0.name.caseInsensitiveCompare(cleanStrain) == .orderedSame }) {
                let newStrain = StrainModel(
                    name: cleanStrain,
                    skuCode: store.nextSKU(prefix: "STR"),
                    species: "Pleurotus ostreatus (Oesterzwam)",
                    potencyMultiplier: 1.0,
                    notes: "Automatisch toegevoegd vanuit bewerkte cultuur"
                )
                store.db.strains.append(newStrain)
                store.save()
            }
        }

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif

        MycoSyncManager.shared.triggerToast(message: store.t(
            nl: "✅ Cultuur succesvol bijgewerkt",
            en: "✅ Culture successfully updated"
        ))

        dismiss()
    }
}

// MARK: - EDIT STRAIN SHEET VIEW
struct EditStrainSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss

    let strain: StrainModel

    @State private var name: String
    @State private var species: String
    @State private var customSpecies: String = ""
    @State private var mushroomType: MushroomApplicationType
    @State private var colonizationSpeed: ColonizationSpeed
    @State private var difficulty: CultivationDifficulty
    @State private var potencyMultiplier: Double
    @State private var notes: String
    @State private var showDeleteConfirm = false

    private var commonSpecies: [String] { StrainModel.commonSpecies }

    init(strain: StrainModel) {
        self.strain = strain
        _name = State(initialValue: strain.name)
        if StrainModel.commonSpecies.filter({ $0 != "Anders / Zelf typen..." }).contains(where: { $0.caseInsensitiveCompare(strain.species) == .orderedSame }) {
            _species = State(initialValue: strain.species)
            _customSpecies = State(initialValue: "")
        } else {
            _species = State(initialValue: "Anders / Zelf typen...")
            _customSpecies = State(initialValue: strain.species)
        }
        _mushroomType = State(initialValue: strain.mushroomType)
        _colonizationSpeed = State(initialValue: strain.colonizationSpeed)
        _difficulty = State(initialValue: strain.difficulty)
        _potencyMultiplier = State(initialValue: strain.potencyMultiplier)
        _notes = State(initialValue: strain.notes)
    }

    var effectiveSpecies: String {
        species == "Anders / Zelf typen..."
            ? (customSpecies.trimmingCharacters(in: .whitespaces).isEmpty ? store.t(nl: "Onbekende soort", en: "Unknown species") : customSpecies)
            : species
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(store.t(nl: "Soort & Naam", en: "Strain & Name"))) {
                    TextField(store.t(nl: "Naam van Soort / Strain", en: "Strain Name"), text: $name)
                    Picker(store.t(nl: "Botanische Soort", en: "Botanical Species"), selection: $species) {
                        ForEach(commonSpecies, id: \.self) { sp in
                            Text(store.localizeBotanicalSpecies(sp)).tag(sp)
                        }
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

                Section(header: Text(store.t(nl: "Kweekkenmerken & Toepassing", en: "Cultivation & Application"))) {
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
                    Section(header: Text(store.t(nl: "Potentie & Sterkte (Actief)", en: "Potency & Strength (Active)"))) {
                        CreativePotencySelectorView(potency: $potencyMultiplier)
                    }
                }

                Section(header: Text(store.t(nl: "Notities & Kenmerken", en: "Notes & Characteristics"))) {
                    TextField(store.t(nl: "Notities & Kenmerken", en: "Notes & Characteristics"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text(store.t(nl: "Verwijder Soort", en: "Delete Strain"))
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Soort Bewerken", en: "Edit Strain"))
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
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert(store.t(nl: "Soort Verwijderen?", en: "Delete Strain?"), isPresented: $showDeleteConfirm) {
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
                Button(store.t(nl: "Verwijderen", en: "Delete"), role: .destructive) {
                    store.db.strains.removeAll { $0.id == strain.id }
                    store.save()
                    dismiss()
                }
            } message: {
                Text(store.t(nl: "Weet je zeker dat je '\(strain.name)' wilt verwijderen?", en: "Are you sure you want to delete '\(strain.name)'?"))
            }
        }
    }

    private func saveChanges() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        if let idx = store.db.strains.firstIndex(where: { $0.id == strain.id }) {
            store.db.strains[idx].name = clean
            store.db.strains[idx].species = effectiveSpecies
            store.db.strains[idx].mushroomType = mushroomType
            store.db.strains[idx].colonizationSpeed = colonizationSpeed
            store.db.strains[idx].difficulty = difficulty
            store.db.strains[idx].potencyMultiplier = (mushroomType == .active) ? potencyMultiplier : 0.0
            store.db.strains[idx].notes = notes
            store.db.strains[idx].lastModifiedAt = Date()
            store.save()
        }

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif

        MycoSyncManager.shared.triggerToast(message: store.t(
            nl: "✅ Soort succesvol bijgewerkt",
            en: "✅ Strain successfully updated"
        ))

        dismiss()
    }
}
