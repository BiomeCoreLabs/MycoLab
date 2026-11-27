//
//  ModernStashAndStockTabView.swift
//  MycoLab
//
//  Modern Living Stash & Stock Vault:
//  - Apple-grade Bento Telemetry for Dried Stash & Bio-Efficiency
//  - Biometric Face ID / Touch ID vault protection
//  - Living Stash Jars with quick culinary portion & stock steppers
//  - Lab Supplies tracking with low-stock alerts & consumption sheets
//  - 100% reversible: instant toggle to Classic Stash & Stock view
//

import SwiftUI
import LocalAuthentication
#if canImport(UIKit)
import UIKit
#endif

// MARK: - LIVING STASH JAR CARD
struct ModernStashJarCard: View {
    @EnvironmentObject var store: MycoStore
    let jar: StashJar
    let onEdit: () -> Void
    let onPrintQR: () -> Void
    let onDelete: () -> Void
    
    @State private var isGentlyPulsing = false
    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: Double = 0.7
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Glass Jar Icon + Strain + Storage Method + Grams
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(MycoTheme.green.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                        .scaleEffect(rippleScale)
                        .opacity(rippleOpacity)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [MycoTheme.green.opacity(isGentlyPulsing ? 0.35 : 0.15), Color.clear],
                                center: .center,
                                startRadius: 4,
                                endRadius: isGentlyPulsing ? 28 : 16
                            )
                        )
                        .frame(width: 48, height: 48)
                        .scaleEffect(isGentlyPulsing ? 1.12 : 0.94)
                    
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(MycoTheme.green)
                        .scaleEffect(isGentlyPulsing ? 1.06 : 0.94)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.displayTitle(name: jar.strainName, sku: jar.skuCode))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(jar.storageMethod)
                        .font(.system(size: 11))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f g", jar.availableDryGrams))
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(MycoTheme.green)
                    
                    Text(store.t(nl: "gedroogd", en: "dried"))
                        .font(.system(size: 9))
                        .foregroundColor(MycoTheme.textSecondary)
                }
            }
            
            Divider()
                .background(MycoTheme.border)
            
            // Stepper Quick-Actions (Portie, Recept, Toevoegen)
            HStack(spacing: 8) {
                // Portie aftrek: -0.5g
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    if let idx = store.db.stash.firstIndex(where: { $0.id == jar.id }) {
                        store.db.stash[idx].availableDryGrams = max(0, jar.availableDryGrams - 0.5)
                        store.save()
                    }
                } label: {
                    Text("- 0.5g")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(MycoTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                
                // Recept aftrek: -1.0g
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    if let idx = store.db.stash.firstIndex(where: { $0.id == jar.id }) {
                        store.db.stash[idx].availableDryGrams = max(0, jar.availableDryGrams - 1.0)
                        store.save()
                    }
                } label: {
                    Text("- 1.0g")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(MycoTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                
                // Replenish: +1.0g
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    if let idx = store.db.stash.firstIndex(where: { $0.id == jar.id }) {
                        store.db.stash[idx].availableDryGrams += 1.0
                        store.save()
                    }
                } label: {
                    Text("+ 1.0g")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(MycoTheme.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(MycoTheme.green.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(MycoTheme.green.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Edit Button
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MycoTheme.blue)
                        .padding(7)
                        .background(MycoTheme.blue.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // QR Label Print Button
                Button {
                    onPrintQR()
                } label: {
                    Image(systemName: "qrcode")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(MycoTheme.textSecondary)
                        .padding(7)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                // Delete
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(MycoTheme.red.opacity(0.8))
                        .padding(7)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
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
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isGentlyPulsing = true
            }
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
                rippleScale = 1.45
                rippleOpacity = 0.0
            }
        }
    }
}

// MARK: - QUICK SUPPLY ADJUST SHEET (SCAN QR -> +/- DIT OF DAT)
struct QuickSupplyAdjustSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    let item: LabSupplyItem
    
    // 0: Verbruiken / Gepakt (-), 1: Aanvullen / Gekocht (+)
    @State private var adjustMode: Int = 0 
    @State private var amountText: String = "1"
    @State private var note: String = ""
    
    private var isKg: Bool {
        item.unit.lowercased() == "kg" || item.unit.lowercased() == "kilo"
    }
    
    private var currentQuantity: Double {
        item.quantity
    }
    
    private var enteredAmount: Double {
        let clean = amountText.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(clean) ?? 0)
    }
    
    private var newQuantity: Double {
        if adjustMode == 0 {
            return max(0, currentQuantity - enteredAmount)
        } else {
            return currentQuantity + enteredAmount
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Item Header Tile
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(MycoTheme.blue.opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 20))
                                .foregroundColor(MycoTheme.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Text(item.category)
                                    .font(.caption)
                                    .foregroundColor(MycoTheme.textSecondary)
                                if !item.qrCodeID.isEmpty {
                                    Text("• \(item.qrCodeID)")
                                        .font(.caption.monospaced())
                                        .foregroundColor(MycoTheme.textSecondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(store.formatQuantity(currentQuantity, unit: item.unit))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(currentQuantity <= item.minThreshold ? MycoTheme.amber : MycoTheme.green)
                            Text(store.t(nl: "Huidige Voorraad", en: "Current Stock"))
                                .font(.caption2)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Mode Picker: Verbruik vs Aanvullen
                Section(header: Text(store.t(nl: "Wat wil je doen?", en: "What do you want to do?"))) {
                    Picker("", selection: $adjustMode) {
                        Text(store.t(nl: "➖ Verbruiken (Gepakt)", en: "➖ Deduct (Used)")).tag(0)
                        Text(store.t(nl: "➕ Aanvullen (Gekocht)", en: "➕ Replenish (Bought)")).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }
                
                // Amount Input & Quick Steppers
                Section(header: Text(store.t(nl: "Hoeveelheid (\(item.unit))", en: "Amount (\(item.unit))"))) {
                    HStack {
                        Button {
                            stepAdjust(-stepDefault)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        
                        TextField("1", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text(item.unit)
                            .font(.headline)
                            .foregroundColor(MycoTheme.textSecondary)
                            .frame(width: 50, alignment: .leading)
                        
                        Button {
                            stepAdjust(stepDefault)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(MycoTheme.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                    
                    // Quick Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickPills, id: \.self) { pill in
                                Button(pill) {
                                    amountText = pill.replacingOccurrences(of: item.unit, with: "").trimmingCharacters(in: .whitespaces)
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(amountText == pill.replacingOccurrences(of: item.unit, with: "").trimmingCharacters(in: .whitespaces) ? MycoTheme.blue.opacity(0.35) : Color.white.opacity(0.08))
                                .foregroundColor(amountText == pill.replacingOccurrences(of: item.unit, with: "").trimmingCharacters(in: .whitespaces) ? MycoTheme.blue : .white)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                // Calculation Preview
                Section(header: Text(store.t(nl: "Voorraad Voorvertoning", en: "Stock Preview"))) {
                    HStack {
                        Text(store.t(nl: "Nieuwe voorraad na wijziging:", en: "New stock after adjustment:"))
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        Text(store.formatQuantity(newQuantity, unit: item.unit))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(adjustMode == 0 ? (newQuantity <= item.minThreshold ? MycoTheme.amber : .white) : MycoTheme.green)
                    }
                    
                    TextField(store.t(nl: "Optionele notitie (bijv. gekocht bij Gamma / gebruikt voor batch)", en: "Optional note (e.g. bought at store / used for batch)"), text: $note)
                }
                
                // Confirm Button
                Section {
                    Button {
                        applyAdjustment()
                    } label: {
                        HStack {
                            Spacer()
                            Text(adjustMode == 0
                                 ? store.t(nl: "➖ \(amountText) \(item.unit) Afboeken", en: "➖ Deduct \(amountText) \(item.unit)")
                                 : store.t(nl: "➕ \(amountText) \(item.unit) Aanvullen", en: "➕ Add \(amountText) \(item.unit)"))
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(adjustMode == 0 ? Color.orange : MycoTheme.green)
                    .disabled(enteredAmount <= 0)
                }
            }
            .navigationTitle(adjustMode == 0 ? store.t(nl: "Voorraad Verbruiken", en: "Deduct Supply") : store.t(nl: "Voorraad Aanvullen", en: "Replenish Supply"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(nl: "Annuleren", en: "Cancel")) { dismiss() }
                        .foregroundColor(MycoTheme.textSecondary)
                }
            }
            .onAppear {
                if isKg {
                    amountText = "0.5"
                } else {
                    amountText = "1"
                }
            }
        }
    }
    
    private var stepDefault: Double {
        isKg ? 0.25 : 1.0
    }
    
    private var quickPills: [String] {
        if isKg {
            return ["0.25", "0.5", "1.0", "2.0", "5.0"]
        } else {
            return ["1", "2", "5", "10", "20"]
        }
    }
    
    private func stepAdjust(_ delta: Double) {
        let current = enteredAmount
        let updated = max(stepDefault, current + delta)
        if isKg {
            amountText = String(format: "%.2f", updated)
        } else {
            amountText = String(format: "%.0f", updated)
        }
    }
    
    private func applyAdjustment() {
        guard let idx = store.db.supplies.firstIndex(where: { $0.id == item.id }) else {
            dismiss()
            return
        }
        
        let delta = enteredAmount
        let prev = store.db.supplies[idx].quantity
        let finalVal: Double
        
        if adjustMode == 0 {
            finalVal = max(0, prev - delta)
            store.db.supplies[idx].quantity = finalVal
            store.db.supplies[idx].lastUpdated = Date()
            store.save()
            
            MycoSyncManager.shared.triggerToast(message: store.t(
                nl: "Afgeboekt: -\(store.formatQuantity(delta, unit: item.unit)) van \(item.name)",
                en: "Deducted: -\(store.formatQuantity(delta, unit: item.unit)) from \(item.name)"
            ))
        } else {
            finalVal = prev + delta
            store.db.supplies[idx].quantity = finalVal
            store.db.supplies[idx].lastUpdated = Date()
            store.save()
            
            MycoSyncManager.shared.triggerToast(message: store.t(
                nl: "Aangevuld: +\(store.formatQuantity(delta, unit: item.unit)) bij \(item.name)",
                en: "Replenished: +\(store.formatQuantity(delta, unit: item.unit)) to \(item.name)"
            ))
        }
        
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif
        dismiss()
    }
}

// MARK: - MODERN LAB SUPPLY CARD
struct ModernLabSupplyCard: View {
    @EnvironmentObject var store: MycoStore
    let item: LabSupplyItem
    let index: Int
    var onAdjust: () -> Void = {}
    var onEdit: () -> Void = {}
    let onDeduct: () -> Void
    let onDelete: () -> Void
    
    private var isKg: Bool { item.unit.lowercased() == "kg" }
    private var step: Double { isKg ? 0.25 : 1.0 }
    private var isLow: Bool { item.quantity <= item.minThreshold }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isLow ? MycoTheme.amber.opacity(0.2) : MycoTheme.blue.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: isLow ? "exclamationmark.triangle.fill" : "archivebox.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isLow ? MycoTheme.amber : MycoTheme.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        Text(item.category)
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                        if !item.qrCodeID.isEmpty {
                            Text("• \(item.qrCodeID)")
                                .font(.system(size: 10))
                                .foregroundColor(MycoTheme.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.formatQuantity(item.quantity, unit: item.unit))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isLow ? MycoTheme.amber : MycoTheme.green)
                    
                    if isLow {
                        Text(store.t(nl: "Bijna op!", en: "Low stock!"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(MycoTheme.amber)
                    }
                }
            }
            
            Divider()
                .background(MycoTheme.border)
            
            HStack(spacing: 8) {
                // Zakken & Verbruik deduct button
                Button {
                    onDeduct()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.and.arrow.backward.fill")
                            .font(.system(size: 10))
                        Text(store.t(nl: "Verbruik", en: "Deduct"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(MycoTheme.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Stepper: Minus
                Button(isKg ? "- 250g" : "- 1") {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    if index < store.db.supplies.count {
                        store.db.supplies[index].quantity = max(0, item.quantity - step)
                        store.save()
                    }
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(MycoTheme.border, lineWidth: 1))
                .buttonStyle(.plain)
                
                // Stepper: Plus
                Button(isKg ? "+ 250g" : "+ 1") {
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    if index < store.db.supplies.count {
                        store.db.supplies[index].quantity += step
                        store.save()
                    }
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(MycoTheme.border, lineWidth: 1))
                .buttonStyle(.plain)
                
                // Edit
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MycoTheme.blue)
                        .padding(6)
                        .background(MycoTheme.blue.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // Delete
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(MycoTheme.textSecondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(MycoTheme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
    }
}

// MARK: - MAIN MODERN STASH & STOCK TAB VIEW
struct ModernStashAndStockTabView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var subTab: Int = 0 // 0: Stash Vault, 1: Lab Voorraad
    @State private var showAddStash = false
    @State private var showAddSupply = false
    @State private var editingStashJar: StashJar? = nil
    @State private var editingSupplyItem: LabSupplyItem? = nil
    @State private var selectedSupplyForDeduction: LabSupplyItem? = nil
    @State private var adjustingSupplyItem: LabSupplyItem? = nil
    @State private var showSupplyQRScanner = false
    @State private var unknownScannedCode: String? = nil
    @State private var qrToPrint: [(title: String, subtitle: String, date: String, qr: String)]?
    @State private var isStashUnlocked = false
    @State private var activeExportURL: IdentifiableURL? = nil
    @State private var showSettings = false
    @State private var showCleanroomVoice = false
    
    private var isWideGrid: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }
    
    var totalDriedGrams: Double {
        store.db.stash.reduce(0) { $0 + $1.availableDryGrams }
    }
    
    var totalHarvestCount: Int {
        store.db.harvests.count
    }
    
    var totalWetHarvestedGrams: Double {
        store.db.harvests.reduce(0) { $0 + $1.wetWeightGrams }
    }
    
    var totalDryHarvestedGrams: Double {
        store.db.harvests.reduce(0) { $0 + $1.dryWeightGrams }
    }
    
    var overallBiologicalEfficiency: Double {
        var totalWet: Double = 0
        var totalDrySubstrate: Double = 0
        for project in store.db.projects where project.drySubstrateWeightGrams > 0 {
            let pWet = store.db.harvests.filter { $0.projectID == project.id }.reduce(0) { $0 + $1.wetWeightGrams }
            if pWet > 0 {
                totalWet += pWet
                totalDrySubstrate += project.drySubstrateWeightGrams
            }
        }
        guard totalDrySubstrate > 0 else { return 0 }
        return (totalWet / totalDrySubstrate) * 100.0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // MARK: - 1. Serene Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.db.stealthMode ? "Vault & Supply" : store.t(nl: "Oogst & Labvoorraad", en: "Harvest & Lab Supplies"))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(totalDriedGrams > 0 ? MycoTheme.green : MycoTheme.textSecondary)
                                        .frame(width: 6, height: 6)
                                    Text(String(format: "%.1f g voorraad", totalDriedGrams))
                                }
                                Text("•").foregroundColor(MycoTheme.textSecondary)
                                Text("\(store.db.supplies.count) " + store.t(nl: "labartikelen", en: "supplies"))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(MycoTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        if subTab == 1 {
                            Button {
                                showSupplyQRScanner = true
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.system(size: 13, weight: .bold))
                                    Text(store.t(nl: "Scan QR", en: "Scan QR"))
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(MycoTheme.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(MycoTheme.blue.opacity(0.12))
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(MycoTheme.blue.opacity(0.3), lineWidth: 1))
                            }
                        }
                        
                        Button {
                            if subTab == 0 {
                                showAddStash = true
                            } else {
                                showAddSupply = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text(subTab == 0 ? store.t(nl: "Pot", en: "Jar") : store.t(nl: "Voorraad", en: "Supply"))
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
                    
                    // MARK: - 2. Segment Switcher (Stash Vault vs Lab Voorraad)
                    HStack(spacing: 8) {
                        subTabPill(title: store.t(nl: "🍯 Oogstvoorraad", en: "🍯 Harvest Vault"), index: 0, count: store.db.stash.count)
                        subTabPill(title: store.t(nl: "📦 Lab Voorraad", en: "📦 Lab Supplies"), index: 1, count: store.db.supplies.count)
                        Spacer()
                    }
                    
                    // MARK: - 3. Content
                    if subTab == 0 {
                        if store.db.stashBiometricLock && !isStashUnlocked {
                            modernStashLockScreen
                        } else {
                            modernStashVaultSection
                        }
                    } else {
                        modernLabSuppliesSection
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
            .sheet(isPresented: $showCleanroomVoice) {
                CleanroomVoiceConsoleView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheetView()
                    .environmentObject(store)
            }
            .onAppear {
                if store.db.stashBiometricLock && !isStashUnlocked {
                    authenticateStash()
                }
            }
            .sheet(isPresented: $showAddStash) {
                AddStashJarSheet().environmentObject(store)
            }
            .sheet(isPresented: $showAddSupply) {
                AddLabSupplySheet().environmentObject(store)
            }
            .sheet(item: $selectedSupplyForDeduction) { item in
                DeductSupplySheet(item: item).environmentObject(store)
            }
            .sheet(item: Binding(
                get: { qrToPrint.map { BatchLabelsWrapper(labels: $0) } },
                set: { qrToPrint = $0?.labels }
            )) { wrapper in
                NavigationStack {
                    QRLabelStudioView(labels: wrapper.labels)
                }
            }
            .sheet(item: $activeExportURL) { item in
                ActivityViewWrapper(activityItems: [item.url])
            }
            .sheet(item: $editingStashJar) { jar in
                EditStashJarSheetView(jar: jar)
                    .environmentObject(store)
            }
            .sheet(item: $editingSupplyItem) { item in
                EditSupplySheetView(item: item)
                    .environmentObject(store)
            }
            .sheet(item: $adjustingSupplyItem) { item in
                QuickSupplyAdjustSheet(item: item)
                    .environmentObject(store)
            }
        }
    }
    
    private func subTabPill(title: String, index: Int, count: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                subTab = index
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: subTab == index ? .bold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(subTab == index ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(subTab == index ? .white : MycoTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(subTab == index ? MycoTheme.blue : MycoTheme.card)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(subTab == index ? MycoTheme.blue : MycoTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - MODERN STASH LOCK SCREEN
    private var modernStashLockScreen: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(MycoTheme.amber.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 38))
                    .foregroundColor(MycoTheme.amber)
            }
            
            VStack(spacing: 4) {
                Text(store.t(nl: "Oogstkluis Beveiligd", en: "Harvest Vault Secured"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(store.t(nl: "Je gedroogde oogst en voorraadpotten zijn beveiligd met biometrie.", en: "Your dried harvest and cured jars are secured with biometrics."))
                    .font(.system(size: 12))
                    .foregroundColor(MycoTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                authenticateStash()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "faceid")
                        .font(.system(size: 16, weight: .bold))
                    Text(store.t(nl: "Ontgrendel met Face ID / Touch ID", en: "Unlock with Face ID / Touch ID"))
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(MycoTheme.blue)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(MycoTheme.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(MycoTheme.border, lineWidth: 1))
    }
    
    private func authenticateStash() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: store.t(nl: "Ontgrendel je Oogst & Labkluis", en: "Unlock your Harvest & Lab Vault")) { success, _ in
                DispatchQueue.main.async {
                    self.isStashUnlocked = success
                }
            }
        } else {
            self.isStashUnlocked = true
        }
    }
    
    // MARK: - MODERN STASH VAULT SECTION
    private var modernStashVaultSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Bento Telemetry Summary
            HStack(spacing: 10) {
                // Total Dried Stash Card
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 12))
                            .foregroundColor(MycoTheme.green)
                        Text(store.t(nl: "Totale Oogst", en: "Total Harvest"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    Text(String(format: "%.2f g", totalDriedGrams))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(MycoTheme.green)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MycoTheme.card)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.green.opacity(0.3), lineWidth: 1))
                
                // Biological Efficiency Card
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12))
                            .foregroundColor(MycoTheme.blue)
                        Text(store.t(nl: "Bio-Efficiency", en: "Bio-Efficiency"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(MycoTheme.textSecondary)
                        Spacer()
                        
                        if !store.db.harvests.isEmpty {
                            Button {
                                let url = MycoReportExporter.generateAllHarvestsCSV(store: store)
                                activeExportURL = IdentifiableURL(url: url)
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 11))
                                    .foregroundColor(MycoTheme.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(String(format: "%.1f%%", overallBiologicalEfficiency))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(overallBiologicalEfficiency >= 100 ? MycoTheme.green : MycoTheme.blue)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MycoTheme.card)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
            }
            
            // Jars List or Empty State
            if store.db.stash.isEmpty {
                EmptyStateCard(
                    icon: "archivebox.fill",
                    title: store.t(nl: "Je Stash Vault is leeg", en: "Your Stash Vault is empty"),
                    message: store.t(nl: "Zodra je een oogst en droger-run invult bij een project wordt het droge gewicht hier automatisch bijgeteld, of voeg handmatig een voorraadpot toe.", en: "Once you log a harvest and dehydrator run, the dry weight is added here, or add a stash jar manually."),
                    buttonTitle: store.t(nl: "+ Handmatig Pot Toevoegen", en: "+ Add Stash Jar")
                ) {
                    showAddStash = true
                }
            } else if isWideGrid {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 12)], spacing: 12) {
                    ForEach(store.db.stash) { jar in
                        ModernStashJarCard(
                            jar: jar,
                            onEdit: { editingStashJar = jar },
                            onPrintQR: {
                                let title = store.displayTitle(name: jar.strainName, sku: jar.skuCode)
                                let subtitle = "\(String(format: "%.1f g", jar.availableDryGrams)) • \(jar.storageMethod)"
                                let dateStr = jar.lastUpdated.formatted(date: .numeric, time: .omitted)
                                let payload = jar.qrCodeID.isEmpty ? "MYCOLAB-STASH|\(jar.skuCode)|\(jar.strainName)|\(jar.availableDryGrams)g" : jar.qrCodeID
                                qrToPrint = [(title: title, subtitle: subtitle, date: dateStr, qr: payload)]
                            },
                            onDelete: {
                                withAnimation {
                                    store.deleteStashJar(id: jar.id)
                                }
                            }
                        )
                    }
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(store.db.stash) { jar in
                        ModernStashJarCard(
                            jar: jar,
                            onEdit: { editingStashJar = jar },
                            onPrintQR: {
                                let title = store.displayTitle(name: jar.strainName, sku: jar.skuCode)
                                let subtitle = "\(String(format: "%.1f g", jar.availableDryGrams)) • \(jar.storageMethod)"
                                let dateStr = jar.lastUpdated.formatted(date: .numeric, time: .omitted)
                                let payload = jar.qrCodeID.isEmpty ? "MYCOLAB-STASH|\(jar.skuCode)|\(jar.strainName)|\(jar.availableDryGrams)g" : jar.qrCodeID
                                qrToPrint = [(title: title, subtitle: subtitle, date: dateStr, qr: payload)]
                            },
                            onDelete: {
                                withAnimation {
                                    store.deleteStashJar(id: jar.id)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - MODERN LAB SUPPLIES SECTION
    private var modernLabSuppliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.db.supplies.isEmpty {
                EmptyStateCard(
                    icon: "shippingbox.fill",
                    title: store.t(nl: "Geen lab artikelen opgeslagen", en: "No lab supplies saved"),
                    message: store.t(nl: "Houd je voorraad graan, kokosvezel, agar en zakken bij. Ontvang meldingen zodra een artikel bijna op is.", en: "Track grain, coco coir, agar, and bags. Receive alerts when supplies run low."),
                    buttonTitle: store.t(nl: "+ Eerste Artikel Toevoegen", en: "+ Add First Supply")
                ) {
                    showAddSupply = true
                }
            } else if isWideGrid {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 10)], spacing: 10) {
                    ForEach(Array(store.db.supplies.enumerated()), id: \.element.id) { idx, item in
                        ModernLabSupplyCard(
                            item: item,
                            index: idx,
                            onAdjust: { adjustingSupplyItem = item },
                            onEdit: { editingSupplyItem = item },
                            onDeduct: { selectedSupplyForDeduction = item },
                            onDelete: {
                                withAnimation {
                                    store.deleteSupply(id: item.id)
                                }
                            }
                        )
                    }
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(store.db.supplies.enumerated()), id: \.element.id) { idx, item in
                        ModernLabSupplyCard(
                            item: item,
                            index: idx,
                            onAdjust: { adjustingSupplyItem = item },
                            onEdit: { editingSupplyItem = item },
                            onDeduct: { selectedSupplyForDeduction = item },
                            onDelete: {
                                withAnimation {
                                    store.deleteSupply(id: item.id)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    private func handleScannedCodeInStock(_ code: String) {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = store.db.supplies.first(where: {
            clean.localizedCaseInsensitiveContains($0.qrCodeID) || (!clean.isEmpty && $0.qrCodeID.localizedCaseInsensitiveContains(clean))
        }) {
            showSupplyQRScanner = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                adjustingSupplyItem = match
            }
        } else {
            showSupplyQRScanner = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                unknownScannedCode = clean
            }
        }
    }
}


// MARK: - EDIT STASH JAR SHEET VIEW
struct EditStashJarSheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss

    let jar: StashJar

    @State private var strainName: String
    @State private var storageMethod: String
    @State private var dryGramsText: String
    @State private var potencyMultiplier: Double
    @State private var showDeleteConfirm = false

    private let storageMethods = [
        "Luchtdichte Pot + Silica",
        "Vacuümzak Verzegeld",
        "Diepvries (-18°C)",
        "Donkere Koelkast (4°C)",
        "Honing / Blue Honey Conserve",
        "Anders / Zelf typen..."
    ]

    init(jar: StashJar) {
        self.jar = jar
        _strainName = State(initialValue: jar.strainName)
        _storageMethod = State(initialValue: jar.storageMethod)
        _dryGramsText = State(initialValue: String(format: "%.2f", jar.availableDryGrams))
        _potencyMultiplier = State(initialValue: jar.potencyMultiplier)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(store.t(nl: "Soort & Opslag", en: "Strain & Storage"))) {
                    TextField(store.t(nl: "Soort / Strain Naam", en: "Strain Name"), text: $strainName)
                    Picker(store.t(nl: "Opslagmethode", en: "Storage Method"), selection: $storageMethod) {
                        ForEach(storageMethods, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                }

                Section(header: Text(store.t(nl: "Gewicht & Potentie", en: "Weight & Potency"))) {
                    HStack {
                        Text(store.t(nl: "Beschikbaar Droog:", en: "Available Dry:"))
                        Spacer()
                        TextField("0.0", text: $dryGramsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(MycoTheme.green)
                        Text("gram")
                            .foregroundColor(MycoTheme.textSecondary)
                    }

                    CreativePotencySelectorView(potency: $potencyMultiplier)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text(store.t(nl: "Verwijder Deze Pot", en: "Delete This Jar"))
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Voorraad Pot Bewerken", en: "Edit Stash Jar"))
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
            .alert(store.t(nl: "Pot Verwijderen?", en: "Delete Jar?"), isPresented: $showDeleteConfirm) {
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
                Button(store.t(nl: "Verwijderen", en: "Delete"), role: .destructive) {
                    store.deleteStashJar(id: jar.id)
                    dismiss()
                }
            } message: {
                Text(store.t(nl: "Weet je zeker dat je deze voorraadpot wilt verwijderen?", en: "Are you sure you want to delete this stash jar?"))
            }
        }
    }

    private func saveChanges() {
        let clean = strainName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let cleanGrams = dryGramsText.replacingOccurrences(of: ",", with: ".")
        let grams = max(0, Double(cleanGrams) ?? jar.availableDryGrams)

        if let idx = store.db.stash.firstIndex(where: { $0.id == jar.id }) {
            store.db.stash[idx].strainName = clean
            store.db.stash[idx].storageMethod = storageMethod
            store.db.stash[idx].availableDryGrams = grams
            store.db.stash[idx].potencyMultiplier = potencyMultiplier
            store.db.stash[idx].lastUpdated = Date()
            store.save()
        }

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif

        MycoSyncManager.shared.triggerToast(message: store.t(
            nl: "✅ Voorraadpot succesvol bijgewerkt",
            en: "✅ Stash jar successfully updated"
        ))

        dismiss()
    }
}

// MARK: - EDIT SUPPLY SHEET VIEW
struct EditSupplySheetView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss

    let item: LabSupplyItem

    @State private var name: String
    @State private var category: String
    @State private var quantityText: String
    @State private var unit: String
    @State private var minThresholdText: String
    @State private var showDeleteConfirm = false

    private let categories = [
        "Graan & Broed",
        "Substraat & Bodem",
        "Agar & Petrischaal",
        "Vloeibare Cultuur",
        "Lab Veiligheid & Hygiëne",
        "Verpakking & Bewaring",
        "Apparatuur & Hardware"
    ]

    private let units = [
        "stuks",
        "kg",
        "gram",
        "liter",
        "ml",
        "zakken",
        "platen",
        "buizen",
        "rollen"
    ]

    init(item: LabSupplyItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _category = State(initialValue: item.category)
        _quantityText = State(initialValue: String(format: item.quantity.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", item.quantity))
        _unit = State(initialValue: item.unit)
        _minThresholdText = State(initialValue: String(format: item.minThreshold.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", item.minThreshold))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(store.t(nl: "Artikel & Categorie", en: "Item & Category"))) {
                    TextField(store.t(nl: "Naam artikel (bijv. Haverkorrels, MEA Poeder)", en: "Item name"), text: $name)
                    Picker(store.t(nl: "Categorie", en: "Category"), selection: $category) {
                        ForEach(categories, id: \.self) { c in
                            Text(store.localizeSupplyCategory(c)).tag(c)
                        }
                    }
                }

                Section(header: Text(store.t(nl: "Voorraad & Eenheid", en: "Stock & Unit"))) {
                    HStack {
                        Text(store.t(nl: "Huidige Voorraad:", en: "Current Stock:"))
                        Spacer()
                        TextField("0", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(MycoTheme.green)
                    }

                    Picker(store.t(nl: "Eenheid", en: "Unit"), selection: $unit) {
                        ForEach(units, id: \.self) { u in
                            Text(u).tag(u)
                        }
                    }

                    HStack {
                        Text(store.t(nl: "Waarschuwing bij minder dan:", en: "Alert when below:"))
                        Spacer()
                        TextField("1", text: $minThresholdText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(MycoTheme.amber)
                        Text(unit)
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text(store.t(nl: "Verwijder Artikel", en: "Delete Item"))
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MycoTheme.bg)
            .navigationTitle(store.t(nl: "Voorraad Item Bewerken", en: "Edit Supply Item"))
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
            .alert(store.t(nl: "Artikel Verwijderen?", en: "Delete Item?"), isPresented: $showDeleteConfirm) {
                Button(store.t(nl: "Annuleren", en: "Cancel"), role: .cancel) {}
                Button(store.t(nl: "Verwijderen", en: "Delete"), role: .destructive) {
                    store.deleteSupply(id: item.id)
                    dismiss()
                }
            } message: {
                Text(store.t(nl: "Weet je zeker dat je '\(item.name)' wilt verwijderen?", en: "Are you sure you want to delete '\(item.name)'?"))
            }
        }
    }

    private func saveChanges() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let cleanQty = quantityText.replacingOccurrences(of: ",", with: ".")
        let qty = max(0, Double(cleanQty) ?? item.quantity)

        let cleanThresh = minThresholdText.replacingOccurrences(of: ",", with: ".")
        let thresh = max(0, Double(cleanThresh) ?? item.minThreshold)

        if let idx = store.db.supplies.firstIndex(where: { $0.id == item.id }) {
            store.db.supplies[idx].name = clean
            store.db.supplies[idx].category = category
            store.db.supplies[idx].quantity = qty
            store.db.supplies[idx].unit = unit
            store.db.supplies[idx].minThreshold = thresh
            store.db.supplies[idx].lastUpdated = Date()
            store.save()
        }

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif

        MycoSyncManager.shared.triggerToast(message: store.t(
            nl: "✅ Voorraadartikel succesvol bijgewerkt",
            en: "✅ Supply item successfully updated"
        ))

        dismiss()
    }
}
