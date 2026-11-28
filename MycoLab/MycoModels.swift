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

// MARK: - MULTI-DEVICE PLATFORM DETECTION (IPHONE / IPAD / MACBOOK)
public enum MycoDevicePlatform {
    public static var isMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp
        #endif
    }

    @MainActor
    public static var isPad: Bool {
        !isMac && UIDevice.current.userInterfaceIdiom == .pad
    }

    @MainActor
    public static var isPhone: Bool {
        !isMac && UIDevice.current.userInterfaceIdiom == .phone
    }

    @MainActor
    public static var deviceName: String {
        if isMac { return "MacBook" }
        if isPad { return "iPad" }
        return "iPhone"
    }

    public static var biometricName: String {
        isMac ? "Touch ID" : "Face ID"
    }

    public static var biometricIcon: String {
        isMac ? "touchid" : "faceid"
    }

    // MARK: - Hardware Screen Dimensions & Adaptive Geometry
    @MainActor
    public static var screenBounds: CGRect {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window.bounds
        }
        return UIScreen.main.bounds
    }

    @MainActor
    public static var screenWidth: CGFloat {
        screenBounds.width
    }

    @MainActor
    public static var screenHeight: CGFloat {
        screenBounds.height
    }

    @MainActor
    public static var safeAreaInsets: UIEdgeInsets {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window.safeAreaInsets
        }
        return UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
    }

    /// Compact screen width (<= 380 pt): iPhone SE (1st, 2nd, 3rd gen), iPhone 12/13 mini, iPhone 6/7/8
    @MainActor
    public static var isCompactWidth: Bool {
        min(screenWidth, screenHeight) <= 380
    }

    /// Standard screen width (381...415 pt): iPhone 11/12/13/14/15/16 Pro, iPhone X/XS
    @MainActor
    public static var isStandardWidth: Bool {
        let w = min(screenWidth, screenHeight)
        return w > 380 && w <= 415
    }

    /// Large phone screen width (> 415 pt): iPhone Plus, Pro Max
    @MainActor
    public static var isLargePhone: Bool {
        let w = min(screenWidth, screenHeight)
        return w > 415 && isPhone
    }

    @MainActor
    public static var safeTopPadding: CGFloat {
        let inset = safeAreaInsets.top
        return inset > 0 ? max(inset, 44) : 44
    }

    @MainActor
    public static var safeBottomPadding: CGFloat {
        let inset = safeAreaInsets.bottom
        return inset > 0 ? max(inset, 20) : 20
    }
}


// MARK: - LIVE ACTIVITIES (ACTIVITYKIT & DYNAMIC ISLAND)
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
@available(iOS 16.1, *)
nonisolated struct LabLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var remainingSeconds: Int
        public var totalSeconds: Int
        public var phaseTitle: String
        public var pressureOrNotes: String
        public var isPaused: Bool
        
        public init(remainingSeconds: Int, totalSeconds: Int, phaseTitle: String, pressureOrNotes: String, isPaused: Bool = false) {
            self.remainingSeconds = remainingSeconds
            self.totalSeconds = totalSeconds
            self.phaseTitle = phaseTitle
            self.pressureOrNotes = pressureOrNotes
            self.isPaused = isPaused
        }
    }
    
    public var timerName: String
    public var category: String
    
    public init(timerName: String, category: String = "Sterilization") {
        self.timerName = timerName
        self.category = category
    }
}
#endif

// MARK: - 1. THEME & DESIGN SYSTEM
public enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case darkLab = "darkLab"
    case emerald = "emerald"
    case cyberMyco = "cyberMyco"
    case amberSpore = "amberSpore"
    case midnightPurple = "midnightPurple"
    case slateMinimal = "slateMinimal"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .darkLab: return "Dark Lab (Standaard)"
        case .emerald: return "Forest Emerald"
        case .cyberMyco: return "Cyber Myco (Neon)"
        case .amberSpore: return "Amber Spore"
        case .midnightPurple: return "Midnight Mycota"
        case .slateMinimal: return "Slate Minimal"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .darkLab: return "Cleanroom lab met donkergrijs en strak blauw"
        case .emerald: return "Natuurlijk diep bosgroen met jade en smaragd accenten"
        case .cyberMyco: return "Futuristisch diepblauw met fel neon cyaan"
        case .amberSpore: return "Warm gouden sporen en amber gloed"
        case .midnightPurple: return "Mystiek dieppaars met levendig magenta"
        case .slateMinimal: return "Modern minimalistisch grafiet met indigo"
        }
    }
    
    public var icon: String {
        switch self {
        case .darkLab: return "flask.fill"
        case .emerald: return "leaf.fill"
        case .cyberMyco: return "bolt.fill"
        case .amberSpore: return "flame.fill"
        case .midnightPurple: return "sparkles"
        case .slateMinimal: return "square.stack.3d.up.fill"
        }
    }
    
    public func localizedTitle(isEnglish: Bool) -> String {
        guard isEnglish else { return title }
        switch self {
        case .darkLab: return "Dark Lab (Default)"
        case .emerald: return "Forest Emerald"
        case .cyberMyco: return "Cyber Myco (Neon)"
        case .amberSpore: return "Amber Spore"
        case .midnightPurple: return "Midnight Mycota"
        case .slateMinimal: return "Slate Minimal"
        }
    }
    
    public func localizedSubtitle(isEnglish: Bool) -> String {
        guard isEnglish else { return subtitle }
        switch self {
        case .darkLab: return "Cleanroom lab with dark gray and sleek blue"
        case .emerald: return "Natural deep forest green with jade & emerald accents"
        case .cyberMyco: return "Futuristic deep blue with bright neon cyan"
        case .amberSpore: return "Warm golden spores and glowing amber"
        case .midnightPurple: return "Mystic deep purple with vivid magenta"
        case .slateMinimal: return "Modern minimalist graphite with indigo"
        }
    }

    public var bg: Color {
        switch self {
        case .darkLab: return Color(hex: "121417")
        case .emerald: return Color(hex: "091511")
        case .cyberMyco: return Color(hex: "080D1A")
        case .amberSpore: return Color(hex: "17120B")
        case .midnightPurple: return Color(hex: "130D1C")
        case .slateMinimal: return Color(hex: "13161C")
        }
    }

    public var card: Color {
        switch self {
        case .darkLab: return Color(hex: "1B1F24")
        case .emerald: return Color(hex: "11241C")
        case .cyberMyco: return Color(hex: "111B2C")
        case .amberSpore: return Color(hex: "241C12")
        case .midnightPurple: return Color(hex: "1D152C")
        case .slateMinimal: return Color(hex: "1E232C")
        }
    }

    public var border: Color {
        switch self {
        case .darkLab: return Color(hex: "2A2E35")
        case .emerald: return Color(hex: "1A3B2C")
        case .cyberMyco: return Color(hex: "1C2F4C")
        case .amberSpore: return Color(hex: "3A2B18")
        case .midnightPurple: return Color(hex: "34204A")
        case .slateMinimal: return Color(hex: "2D3546")
        }
    }

    public var blue: Color { // Primary Accent
        switch self {
        case .darkLab: return Color(hex: "3D7EAA")
        case .emerald: return Color(hex: "00B894")
        case .cyberMyco: return Color(hex: "00D2D3")
        case .amberSpore: return Color(hex: "E67E22")
        case .midnightPurple: return Color(hex: "A55EEA")
        case .slateMinimal: return Color(hex: "4D79FF")
        }
    }

    public var green: Color { // Success
        switch self {
        case .darkLab: return Color(hex: "00C853")
        case .emerald: return Color(hex: "2ECC71")
        case .cyberMyco: return Color(hex: "10AC84")
        case .amberSpore: return Color(hex: "27AE60")
        case .midnightPurple: return Color(hex: "2ECC71")
        case .slateMinimal: return Color(hex: "38D9A9")
        }
    }

    public var amber: Color { // Warning
        switch self {
        case .darkLab: return Color(hex: "FFB300")
        case .emerald: return Color(hex: "F39C12")
        case .cyberMyco: return Color(hex: "FF9F43")
        case .amberSpore: return Color(hex: "F1C40F")
        case .midnightPurple: return Color(hex: "F39C12")
        case .slateMinimal: return Color(hex: "FCC419")
        }
    }

    public var red: Color { // Danger
        switch self {
        case .darkLab: return Color(hex: "E53935")
        case .emerald: return Color(hex: "E74C3C")
        case .cyberMyco: return Color(hex: "EE5253")
        case .amberSpore: return Color(hex: "D35400")
        case .midnightPurple: return Color(hex: "FC5C65")
        case .slateMinimal: return Color(hex: "FF6B6B")
        }
    }

    public var textPrimary: Color { Color.white }

    public var textSecondary: Color {
        switch self {
        case .darkLab: return Color(hex: "8A94A6")
        case .emerald: return Color(hex: "8CA698")
        case .cyberMyco: return Color(hex: "7D96BA")
        case .amberSpore: return Color(hex: "A89987")
        case .midnightPurple: return Color(hex: "AA96C2")
        case .slateMinimal: return Color(hex: "8C96A8")
        }
    }
}

// MARK: - CUSTOM USER THEME
public struct CustomAppTheme: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var bgHex: String
    public var cardHex: String
    public var borderHex: String
    public var primaryAccentHex: String
    public var secondaryAccentHex: String
    public var textPrimaryHex: String
    public var textSecondaryHex: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        bgHex: String = "121417",
        cardHex: String = "1B1F24",
        borderHex: String = "2A2E35",
        primaryAccentHex: String = "3D7EAA",
        secondaryAccentHex: String = "00C853",
        textPrimaryHex: String = "F5F7FA",
        textSecondaryHex: String = "8A94A6"
    ) {
        self.id = id
        self.name = name
        self.bgHex = bgHex
        self.cardHex = cardHex
        self.borderHex = borderHex
        self.primaryAccentHex = primaryAccentHex
        self.secondaryAccentHex = secondaryAccentHex
        self.textPrimaryHex = textPrimaryHex
        self.textSecondaryHex = textSecondaryHex
    }
    
    public var bg: Color { Color(hex: bgHex) }
    public var card: Color { Color(hex: cardHex) }
    public var border: Color { Color(hex: borderHex) }
    public var blue: Color { Color(hex: primaryAccentHex) }
    public var green: Color { Color(hex: secondaryAccentHex) }
    public var textPrimary: Color { Color(hex: textPrimaryHex) }
    public var textSecondary: Color { Color(hex: textSecondaryHex) }
}

enum MycoTheme {
    static var currentTheme: AppTheme = .darkLab
    static var activeCustomTheme: CustomAppTheme? = nil

    static var bg: Color { activeCustomTheme?.bg ?? currentTheme.bg }
    static var card: Color { activeCustomTheme?.card ?? currentTheme.card }
    static var border: Color { activeCustomTheme?.border ?? currentTheme.border }
    static var blue: Color { activeCustomTheme?.blue ?? currentTheme.blue }
    static var green: Color { activeCustomTheme?.green ?? currentTheme.green }
    static var amber: Color { currentTheme.amber }
    static var red: Color { currentTheme.red }
    static var textPrimary: Color { activeCustomTheme?.textPrimary ?? currentTheme.textPrimary }
    static var textSecondary: Color { activeCustomTheme?.textSecondary ?? currentTheme.textSecondary }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    func toHexRGB() -> String {
        let uic = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uic.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        return String(format: "%02X%02X%02X", ri, gi, bi)
    }
}

// MARK: - 2. DATA MODELS (100% CODABLE & LOCAL PERSISTENCE)
enum GrowPhase: String, CaseIterable, Codable {
    case liquidCulture = "Liquid Culture"
    case agar = "Agar"
    case spawn = "Grain Spawn"
    case bulk = "Bulk Colonization"
    case fruiting = "Fruiting Phase"
    case flushing = "Flushing / Harvest"
    case archived = "Archived"
    case contaminated = "Contaminated"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "Liquid Culture": self = .liquidCulture
        case "Agar": self = .agar
        case "Grain Spawn": self = .spawn
        case "Bulk Colonization", "Bulk / Kolonisatie", "Bulk": self = .bulk
        case "Fruiting Phase", "Vruchtfase", "Fruiting": self = .fruiting
        case "Flushing / Harvest", "Flushing / Oogst", "Flushing": self = .flushing
        case "Archived", "Gearchiveerd": self = .archived
        case "Contaminated", "Besmet": self = .contaminated
        default: self = GrowPhase(rawValue: raw) ?? .bulk
        }
    }

    /// Only operational stages belong in the new-batch picker. Archive and
    /// contamination are outcomes, while harvesting follows fruiting.
    static let startableCases: [GrowPhase] = [.spawn, .bulk, .fruiting]
    
    var color: Color {
        switch self {
        case .liquidCulture, .agar, .spawn, .bulk: return MycoTheme.blue
        case .fruiting, .flushing: return MycoTheme.green
        case .archived: return MycoTheme.textSecondary
        case .contaminated: return MycoTheme.red
        }
    }
    
    func localized(isEnglish: Bool) -> String {
        rawValue
    }
}

enum PresetCategory: String, CaseIterable, Codable {
    case container = "Container / Jar / Tub"
    case substrate = "Substrate Recipe"
    case media = "Agar / LC Media"
    case grain = "Grain Type"
    case sterilization = "Sterilization Protocol"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "Container / Jar / Tub", "Container / Pot / Tub": self = .container
        case "Substrate Recipe", "Substraat Recept": self = .substrate
        case "Agar / LC Media": self = .media
        case "Grain Type", "Graansoort": self = .grain
        case "Sterilization Protocol", "Sterilisatie Protocol": self = .sterilization
        default: self = PresetCategory(rawValue: raw) ?? .container
        }
    }
    
    func localized(isEnglish: Bool) -> String {
        rawValue
    }
}

struct UserPreset: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var category: PresetCategory = .container
    var name: String = ""
    var details: String = ""
    
    init(id: UUID = UUID(), category: PresetCategory = .container, name: String, details: String = "") {
        self.id = id
        self.category = category
        self.name = name
        self.details = details
    }
    
    enum CodingKeys: String, CodingKey {
        case id, category, name, details
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.category = try container.decodeIfPresent(PresetCategory.self, forKey: .category) ?? .container
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
    }
}

public enum MushroomApplicationType: String, CaseIterable, Codable, Hashable {
    case culinary = "Gourmet / Culinary"
    case medicinal = "Medicinal"
    case active = "Active / Microscopy"
    case other = "Other"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "Gourmet / Culinary", "Gourmet / Culinair", "Gourmet": self = .culinary
        case "Medicinal", "Medicinaal": self = .medicinal
        case "Active / Microscopy", "Actief / Microscopie", "Active": self = .active
        case "Other", "Overig": self = .other
        default: self = MushroomApplicationType(rawValue: raw) ?? .culinary
        }
    }
    
    public var icon: String {
        switch self {
        case .culinary: return "fork.knife"
        case .medicinal: return "cross.case.fill"
        case .active: return "sparkles"
        case .other: return "leaf.fill"
        }
    }
    
    public var shortLabelNL: String {
        shortLabelEN
    }
    
    public var shortLabelEN: String {
        switch self {
        case .culinary: return "Gourmet"
        case .medicinal: return "Medicinal"
        case .active: return "Active"
        case .other: return "Other"
        }
    }
    
    public func localized(isEnglish: Bool) -> String {
        rawValue
    }
    
    public func shortLabel(isEnglish: Bool) -> String {
        shortLabelEN
    }
}

public enum ColonizationSpeed: String, CaseIterable, Codable, Hashable {
    case fast = "Fast"
    case moderate = "Moderate"
    case slow = "Slow"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "Fast", "Snel": self = .fast
        case "Moderate", "Gemiddeld": self = .moderate
        case "Slow", "Langzaam": self = .slow
        default: self = ColonizationSpeed(rawValue: raw) ?? .moderate
        }
    }
    
    public var icon: String {
        switch self {
        case .fast: return "bolt.fill"
        case .moderate: return "gauge.medium"
        case .slow: return "hourglass"
        }
    }
    
    public func localized(isEnglish: Bool) -> String {
        rawValue
    }
}

public enum CultivationDifficulty: String, CaseIterable, Codable, Hashable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case expert = "Advanced"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "Beginner": self = .beginner
        case "Intermediate", "Gemiddeld": self = .intermediate
        case "Advanced", "Gevorderd": self = .expert
        default: self = CultivationDifficulty(rawValue: raw) ?? .beginner
        }
    }
    
    public var stars: String {
        switch self {
        case .beginner: return "★☆☆"
        case .intermediate: return "★★☆"
        case .expert: return "★★★"
        }
    }
    
    public func localized(isEnglish: Bool) -> String {
        rawValue
    }
}

struct StrainModel: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var skuCode: String = ""
    var species: String = "Pleurotus ostreatus (Oyster Mushroom)"
    var mushroomType: MushroomApplicationType = .culinary
    var colonizationSpeed: ColonizationSpeed = .moderate
    var difficulty: CultivationDifficulty = .beginner
    var potencyMultiplier: Double = 1.0
    var notes: String = ""
    var dateCreated: Date = Date()
    var lastModifiedAt: Date? = nil
    
    init(
        id: UUID = UUID(),
        name: String,
        skuCode: String,
        species: String = "Pleurotus ostreatus (Oyster Mushroom)",
        mushroomType: MushroomApplicationType? = nil,
        colonizationSpeed: ColonizationSpeed? = nil,
        difficulty: CultivationDifficulty? = nil,
        potencyMultiplier: Double = 1.0,
        notes: String = "",
        dateCreated: Date = Date(),
        lastModifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.skuCode = skuCode
        self.species = species
        self.mushroomType = mushroomType ?? StrainModel.defaultType(for: species)
        self.colonizationSpeed = colonizationSpeed ?? StrainModel.defaultSpeed(for: species)
        self.difficulty = difficulty ?? StrainModel.defaultDifficulty(for: species)
        self.potencyMultiplier = potencyMultiplier
        self.notes = notes
        self.dateCreated = dateCreated
        self.lastModifiedAt = lastModifiedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, skuCode, species, mushroomType, colonizationSpeed, difficulty, potencyMultiplier, notes, dateCreated, lastModifiedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.skuCode = try container.decodeIfPresent(String.self, forKey: .skuCode) ?? ""
        let decodedSpecies = try container.decodeIfPresent(String.self, forKey: .species) ?? "Pleurotus ostreatus (Oyster Mushroom)"
        self.species = decodedSpecies
        self.mushroomType = try container.decodeIfPresent(MushroomApplicationType.self, forKey: .mushroomType) ?? StrainModel.defaultType(for: decodedSpecies)
        self.colonizationSpeed = try container.decodeIfPresent(ColonizationSpeed.self, forKey: .colonizationSpeed) ?? StrainModel.defaultSpeed(for: decodedSpecies)
        self.difficulty = try container.decodeIfPresent(CultivationDifficulty.self, forKey: .difficulty) ?? StrainModel.defaultDifficulty(for: decodedSpecies)
        self.potencyMultiplier = try container.decodeIfPresent(Double.self, forKey: .potencyMultiplier) ?? 1.0
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.dateCreated = try container.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        self.lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt)
    }
    
    public static func defaultType(for species: String) -> MushroomApplicationType {
        let lower = species.lowercased()
        if lower.contains("pleurotus") || lower.contains("oester") || lower.contains("oyster") || lower.contains("lentinula") || lower.contains("shiitake") {
            return .culinary
        }
        if lower.contains("hericium") || lower.contains("lion") || lower.contains("pruik") || lower.contains("reishi") || lower.contains("ganoderma") || lower.contains("cordyceps") {
            return .medicinal
        }
        return .culinary
    }
    
    public static func defaultSpeed(for species: String) -> ColonizationSpeed {
        let lower = species.lowercased()
        if lower.contains("pleurotus") || lower.contains("oester") || lower.contains("oyster") {
            return .fast
        }
        if lower.contains("cordyceps") || lower.contains("reishi") {
            return .slow
        }
        return .moderate
    }
    
    public static func defaultDifficulty(for species: String) -> CultivationDifficulty {
        let lower = species.lowercased()
        if lower.contains("pleurotus") || lower.contains("oester") || lower.contains("oyster") {
            return .beginner
        }
        if lower.contains("cordyceps") {
            return .expert
        }
        return .intermediate
    }
    
    public static let commonSpecies: [String] = [
        "Pleurotus ostreatus (Blue Oyster)",
        "Pleurotus eryngii (King Oyster)",
        "Pleurotus citrinopileatus (Golden Oyster)",
        "Hericium erinaceus (Lion's Mane)",
        "Lentinula edodes (Shiitake)",
        "Cordyceps militaris",
        "Ganoderma lucidum (Reishi)",
        "Agrocybe aegerita (Pioppino)",
        "Other / Custom Entry..."
    ]
}

// MARK: - PREPARATION RECIPE & INGREDIENT MODELS
struct RecipeIngredient: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var amountPerBatch: Double = 0.0
    var unit: String = "gram"
    var linkedSupplyID: UUID? = nil
    
    init(id: UUID = UUID(), name: String = "", amountPerBatch: Double = 0.0, unit: String = "gram", linkedSupplyID: UUID? = nil) {
        self.id = id
        self.name = name
        self.amountPerBatch = amountPerBatch
        self.unit = unit
        self.linkedSupplyID = linkedSupplyID
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, amountPerBatch, unit, linkedSupplyID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.amountPerBatch = try container.decodeIfPresent(Double.self, forKey: .amountPerBatch) ?? 0.0
        self.unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? "gram"
        self.linkedSupplyID = try container.decodeIfPresent(UUID.self, forKey: .linkedSupplyID)
    }
}

struct PreparationRecipe: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = "Substrate"
    var targetPhase: GrowPhase = .spawn
    var containerName: String = ""
    var substrateName: String = ""
    var spawnToBulkRatio: String = "1:2"
    var drySubstrateWeightGrams: Double = 0.0
    var sterilizationNotes: String = ""
    var preparationInstructions: String = ""
    var ingredients: [RecipeIngredient] = []
    var dateCreated: Date = Date()
    var lastModifiedAt: Date? = nil
    
    init(
        id: UUID = UUID(),
        name: String = "",
        category: String = "Substrate",
        targetPhase: GrowPhase = .spawn,
        containerName: String = "",
        substrateName: String = "",
        spawnToBulkRatio: String = "1:2",
        drySubstrateWeightGrams: Double = 0.0,
        sterilizationNotes: String = "",
        preparationInstructions: String = "",
        ingredients: [RecipeIngredient] = [],
        dateCreated: Date = Date(),
        lastModifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.targetPhase = targetPhase
        self.containerName = containerName
        self.substrateName = substrateName
        self.spawnToBulkRatio = spawnToBulkRatio
        self.drySubstrateWeightGrams = drySubstrateWeightGrams
        self.sterilizationNotes = sterilizationNotes
        self.preparationInstructions = preparationInstructions
        self.ingredients = ingredients
        self.dateCreated = dateCreated
        self.lastModifiedAt = lastModifiedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, targetPhase, containerName, substrateName
        case spawnToBulkRatio, drySubstrateWeightGrams, sterilizationNotes
        case preparationInstructions, ingredients, dateCreated, lastModifiedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Substrate"
        self.targetPhase = try container.decodeIfPresent(GrowPhase.self, forKey: .targetPhase) ?? .spawn
        self.containerName = try container.decodeIfPresent(String.self, forKey: .containerName) ?? ""
        self.substrateName = try container.decodeIfPresent(String.self, forKey: .substrateName) ?? ""
        self.spawnToBulkRatio = try container.decodeIfPresent(String.self, forKey: .spawnToBulkRatio) ?? "1:2"
        self.drySubstrateWeightGrams = try container.decodeIfPresent(Double.self, forKey: .drySubstrateWeightGrams) ?? 0.0
        self.sterilizationNotes = try container.decodeIfPresent(String.self, forKey: .sterilizationNotes) ?? ""
        self.preparationInstructions = try container.decodeIfPresent(String.self, forKey: .preparationInstructions) ?? ""
        self.ingredients = try container.decodeIfPresent([RecipeIngredient].self, forKey: .ingredients) ?? []
        self.dateCreated = try container.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        self.lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt)
    }
    
    static var defaultRecipes: [PreparationRecipe] {
        [
            PreparationRecipe(
                name: "CVG Substrate (Monotub 1:2)",
                category: "Substrate",
                targetPhase: .fruiting,
                containerName: "20L Monotub",
                substrateName: "CVG Standard (1:2)",
                spawnToBulkRatio: "1:2",
                drySubstrateWeightGrams: 650.0,
                sterilizationNotes: "Bucket pasteurization: Add 3.5L boiling water, let cool 4 hours with sealed lid.",
                preparationInstructions: "1. Place coco coir brick and vermiculite in a clean heat-resistant bucket.\n2. Add gypsum.\n3. Pour 3.5L boiling water over it.\n4. Seal immediately and insulate with towels for 2-4 hours to reach field capacity.",
                ingredients: [
                    RecipeIngredient(name: "Coco Coir (Coir brick 650g)", amountPerBatch: 650.0, unit: "gram (1 blok)"),
                    RecipeIngredient(name: "Vermiculite (Coarse)", amountPerBatch: 200.0, unit: "gram (ca. 2.0L / ~8 koppen)"),
                    RecipeIngredient(name: "Agricultural Gypsum (Calcium)", amountPerBatch: 100.0, unit: "gram (ca. 4 el)"),
                    RecipeIngredient(name: "Boiling Water", amountPerBatch: 3500.0, unit: "ml (3.5L)")
                ]
            ),
            PreparationRecipe(
                name: "Whole Grain Spawn (1L Jar)",
                category: "Grain & Spawn",
                targetPhase: .spawn,
                containerName: "1L Spawn Jar (Mason)",
                substrateName: "Organic Rye Berries",
                spawnToBulkRatio: "1:1",
                drySubstrateWeightGrams: 350.0,
                sterilizationNotes: "90 minutes at 15 PSI (121°C) in pressure cooker.",
                preparationInstructions: "1. Soak grain 12 hours in water with a pinch of gypsum.\n2. Simmer 10 minutes until tender.\n3. Steam off thoroughly on towel until dry to touch.\n4. Fill jars with filter lids and autoclave.",
                ingredients: [
                    RecipeIngredient(name: "Organic Rye Berries", amountPerBatch: 350.0, unit: "grams"),
                    RecipeIngredient(name: "Water", amountPerBatch: 250.0, unit: "ml"),
                    RecipeIngredient(name: "Agricultural Gypsum (Calcium)", amountPerBatch: 5.0, unit: "grams")
                ]
            ),
            PreparationRecipe(
                name: "Malt Extract Agar (MEA - 500ml)",
                category: "Agar & Media",
                targetPhase: .agar,
                containerName: "Petri Dish 90mm",
                substrateName: "MEA Agar (Malt Extract)",
                spawnToBulkRatio: "N/A",
                drySubstrateWeightGrams: 20.0,
                sterilizationNotes: "45 minutes at 15 PSI (121°C) autoclave.",
                preparationInstructions: "1. Mix 10g agar powder and 10g light malt extract in 500ml warm water.\n2. Stir thoroughly until dissolved.\n3. Autoclave in media bottle with loose cap.\n4. Pour into sterile petri dishes at ~48°C.",
                ingredients: [
                    RecipeIngredient(name: "Agar Agar Powder", amountPerBatch: 10.0, unit: "grams"),
                    RecipeIngredient(name: "Light Malt Extract (LME)", amountPerBatch: 10.0, unit: "grams"),
                    RecipeIngredient(name: "Distilled Water", amountPerBatch: 500.0, unit: "ml")
                ]
            ),
            PreparationRecipe(
                name: "Master's Mix Sawdust (Growbag)",
                category: "Substrate",
                targetPhase: .fruiting,
                containerName: "All-in-One Filter Growbag",
                substrateName: "Master's Mix Sawdust",
                spawnToBulkRatio: "1:3",
                drySubstrateWeightGrams: 900.0,
                sterilizationNotes: "150 minutes at 15 PSI (121°C) in pressure cooker.",
                preparationInstructions: "1. Thoroughly mix 450g oak hardwood pellets and 450g soybean hulls dry.\n2. Add 1.4L warm water to hydrate to 60% moisture content.\n3. Transfer into filter growbag and sterilize 2.5 hours.",
                ingredients: [
                    RecipeIngredient(name: "Hardwood Pellets (Oak)", amountPerBatch: 450.0, unit: "grams"),
                    RecipeIngredient(name: "Soybean Hulls", amountPerBatch: 450.0, unit: "grams"),
                    RecipeIngredient(name: "Water", amountPerBatch: 1400.0, unit: "ml")
                ]
            )
        ]
    }
}

struct CultureItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var strainID: UUID?
    var strainName: String = ""
    var skuCode: String = ""
    var cultureType: String = "Liquid Culture (LC)"
    var generation: String = "T0"
    var parentID: UUID?
    var parentLabel: String = ""
    var mediaName: String = ""
    var status: String = "Active Growth"
    var qrCodeID: String = ""
    var dateCreated: Date = Date()
    var notes: String = ""
    var lastModifiedAt: Date? = nil
    
    init(id: UUID = UUID(), strainID: UUID? = nil, strainName: String, skuCode: String, cultureType: String, generation: String = "T0", parentID: UUID? = nil, parentLabel: String = "", mediaName: String = "", status: String, qrCodeID: String, dateCreated: Date = Date(), notes: String = "", lastModifiedAt: Date? = nil) {
        self.id = id
        self.strainID = strainID
        self.strainName = strainName
        self.skuCode = skuCode
        self.cultureType = cultureType
        self.generation = generation
        self.parentID = parentID
        self.parentLabel = parentLabel
        self.mediaName = mediaName
        self.status = status
        self.qrCodeID = qrCodeID
        self.dateCreated = dateCreated
        self.notes = notes
        self.lastModifiedAt = lastModifiedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, strainID, strainName, skuCode, cultureType, generation, parentID, parentLabel, mediaName, status, qrCodeID, dateCreated, notes, lastModifiedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.strainID = try container.decodeIfPresent(UUID.self, forKey: .strainID)
        self.strainName = try container.decodeIfPresent(String.self, forKey: .strainName) ?? ""
        self.skuCode = try container.decodeIfPresent(String.self, forKey: .skuCode) ?? ""
        self.cultureType = try container.decodeIfPresent(String.self, forKey: .cultureType) ?? "Liquid Culture (LC)"
        self.generation = try container.decodeIfPresent(String.self, forKey: .generation) ?? "T0"
        self.parentID = try container.decodeIfPresent(UUID.self, forKey: .parentID)
        self.parentLabel = try container.decodeIfPresent(String.self, forKey: .parentLabel) ?? ""
        self.mediaName = try container.decodeIfPresent(String.self, forKey: .mediaName) ?? ""
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "Active Growth"
        self.qrCodeID = try container.decodeIfPresent(String.self, forKey: .qrCodeID) ?? ""
        self.dateCreated = try container.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt)
    }
}

struct GrowProject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var strainID: UUID?
    var strainName: String = ""
    var skuCode: String = ""
    var batchNumber: Int = 1
    var phase: GrowPhase = .spawn
    var colonizationPercent: Double = 0.0
    var containerName: String = ""
    var substrateName: String = ""
    var spawnToBulkRatio: String = "1:2"
    var drySubstrateWeightGrams: Double = 0.0
    var sterilizationNotes: String = ""
    var parentCultureID: UUID?
    var parentCultureLabel: String = ""
    var startDate: Date = Date()
    var latestTempC: Double?
    var latestHumidityPct: Double?
    var qrCodeID: String = ""
    var isArchived: Bool = false
    var tags: [String] = []
    var lastBreakAndShakeDate: Date? = nil
    var lastModifiedAt: Date? = nil
    var recipeID: UUID? = nil
    var recipeName: String = ""
    
    /// Always returns the colonization percentage as a number between 0.0 and 100.0
    var normalizedColonizationPercent: Double {
        if colonizationPercent > 0.0 && colonizationPercent <= 1.0 {
            return colonizationPercent * 100.0
        }
        return min(max(colonizationPercent, 0.0), 100.0)
    }
    
    init(id: UUID = UUID(), strainID: UUID? = nil, strainName: String, skuCode: String, batchNumber: Int = 1, phase: GrowPhase = .spawn, colonizationPercent: Double = 0.0, containerName: String = "", substrateName: String = "", spawnToBulkRatio: String = "1:2", drySubstrateWeightGrams: Double = 0.0, sterilizationNotes: String = "", parentCultureID: UUID? = nil, parentCultureLabel: String = "", startDate: Date = Date(), latestTempC: Double? = nil, latestHumidityPct: Double? = nil, qrCodeID: String, isArchived: Bool = false, tags: [String] = [], lastBreakAndShakeDate: Date? = nil, lastModifiedAt: Date? = nil, recipeID: UUID? = nil, recipeName: String = "") {
        self.id = id
        self.strainID = strainID
        self.strainName = strainName
        self.skuCode = skuCode
        self.batchNumber = batchNumber
        self.phase = phase
        self.colonizationPercent = colonizationPercent
        self.containerName = containerName
        self.substrateName = substrateName
        self.spawnToBulkRatio = spawnToBulkRatio
        self.drySubstrateWeightGrams = drySubstrateWeightGrams
        self.sterilizationNotes = sterilizationNotes
        self.parentCultureID = parentCultureID
        self.parentCultureLabel = parentCultureLabel
        self.startDate = startDate
        self.latestTempC = latestTempC
        self.latestHumidityPct = latestHumidityPct
        self.qrCodeID = qrCodeID
        self.isArchived = isArchived
        self.tags = tags
        self.lastBreakAndShakeDate = lastBreakAndShakeDate
        self.lastModifiedAt = lastModifiedAt
        self.recipeID = recipeID
        self.recipeName = recipeName
    }
    
    enum CodingKeys: String, CodingKey {
        case id, strainID, strainName, skuCode, batchNumber, phase, colonizationPercent
        case containerName, substrateName, spawnToBulkRatio, drySubstrateWeightGrams
        case sterilizationNotes, parentCultureID, parentCultureLabel, startDate
        case latestTempC, latestHumidityPct, qrCodeID, isArchived
        case tags, lastBreakAndShakeDate, lastModifiedAt, recipeID, recipeName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.strainID = try container.decodeIfPresent(UUID.self, forKey: .strainID)
        self.strainName = try container.decodeIfPresent(String.self, forKey: .strainName) ?? ""
        self.skuCode = try container.decodeIfPresent(String.self, forKey: .skuCode) ?? ""
        self.batchNumber = try container.decodeIfPresent(Int.self, forKey: .batchNumber) ?? 1
        self.phase = try container.decodeIfPresent(GrowPhase.self, forKey: .phase) ?? .spawn
        self.colonizationPercent = try container.decodeIfPresent(Double.self, forKey: .colonizationPercent) ?? 0.0
        self.containerName = try container.decodeIfPresent(String.self, forKey: .containerName) ?? ""
        self.substrateName = try container.decodeIfPresent(String.self, forKey: .substrateName) ?? ""
        self.spawnToBulkRatio = try container.decodeIfPresent(String.self, forKey: .spawnToBulkRatio) ?? "1:2"
        self.drySubstrateWeightGrams = try container.decodeIfPresent(Double.self, forKey: .drySubstrateWeightGrams) ?? 0.0
        self.sterilizationNotes = try container.decodeIfPresent(String.self, forKey: .sterilizationNotes) ?? ""
        self.parentCultureID = try container.decodeIfPresent(UUID.self, forKey: .parentCultureID)
        self.parentCultureLabel = try container.decodeIfPresent(String.self, forKey: .parentCultureLabel) ?? ""
        self.startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        self.latestTempC = try container.decodeIfPresent(Double.self, forKey: .latestTempC)
        self.latestHumidityPct = try container.decodeIfPresent(Double.self, forKey: .latestHumidityPct)
        self.qrCodeID = try container.decodeIfPresent(String.self, forKey: .qrCodeID) ?? ""
        self.isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.lastBreakAndShakeDate = try container.decodeIfPresent(Date.self, forKey: .lastBreakAndShakeDate)
        self.lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt)
        self.recipeID = try container.decodeIfPresent(UUID.self, forKey: .recipeID)
        self.recipeName = try container.decodeIfPresent(String.self, forKey: .recipeName) ?? ""
    }
}

struct GrowLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var projectID: UUID = UUID()
    var timestamp: Date = Date()
    var actionType: String = ""
    var temperatureC: Double?
    var humidityPct: Double?
    var notes: String = ""
    var imageData: Data?
    
    init(id: UUID = UUID(), projectID: UUID = UUID(), timestamp: Date = Date(), actionType: String, temperatureC: Double? = nil, humidityPct: Double? = nil, notes: String = "", imageData: Data? = nil) {
        self.id = id
        self.projectID = projectID
        self.timestamp = timestamp
        self.actionType = actionType
        self.temperatureC = temperatureC
        self.humidityPct = humidityPct
        self.notes = notes
        self.imageData = imageData
    }
    
    enum CodingKeys: String, CodingKey {
        case id, projectID, timestamp, actionType, temperatureC, humidityPct, notes, imageData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID) ?? UUID()
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        self.actionType = try container.decodeIfPresent(String.self, forKey: .actionType) ?? ""
        self.temperatureC = try container.decodeIfPresent(Double.self, forKey: .temperatureC)
        self.humidityPct = try container.decodeIfPresent(Double.self, forKey: .humidityPct)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
    }
}

struct HarvestRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var projectID: UUID = UUID()
    var strainName: String = ""
    var skuCode: String = ""
    var flushNumber: Int = 1
    var harvestDate: Date = Date()
    var wetWeightGrams: Double = 0.0
    var dehydratorTempC: Double = 50.0
    var dehydratorHours: Double = 12.0
    var dryWeightGrams: Double = 0.0
    var notes: String = ""
    
    init(id: UUID = UUID(), projectID: UUID = UUID(), strainName: String, skuCode: String, flushNumber: Int = 1, harvestDate: Date = Date(), wetWeightGrams: Double = 0.0, dehydratorTempC: Double = 50.0, dehydratorHours: Double = 12.0, dryWeightGrams: Double = 0.0, notes: String = "") {
        self.id = id
        self.projectID = projectID
        self.strainName = strainName
        self.skuCode = skuCode
        self.flushNumber = flushNumber
        self.harvestDate = harvestDate
        self.wetWeightGrams = wetWeightGrams
        self.dehydratorTempC = dehydratorTempC
        self.dehydratorHours = dehydratorHours
        self.dryWeightGrams = dryWeightGrams
        self.notes = notes
    }
    
    var moistureLossPct: Double {
        guard wetWeightGrams > 0, dryWeightGrams > 0, wetWeightGrams >= dryWeightGrams else { return 0 }
        return ((wetWeightGrams - dryWeightGrams) / wetWeightGrams) * 100.0
    }
    
    enum CodingKeys: String, CodingKey {
        case id, projectID, strainName, skuCode, flushNumber, harvestDate, wetWeightGrams, dehydratorTempC, dehydratorHours, dryWeightGrams, notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID) ?? UUID()
        self.strainName = try container.decodeIfPresent(String.self, forKey: .strainName) ?? ""
        self.skuCode = try container.decodeIfPresent(String.self, forKey: .skuCode) ?? ""
        self.flushNumber = try container.decodeIfPresent(Int.self, forKey: .flushNumber) ?? 1
        self.harvestDate = try container.decodeIfPresent(Date.self, forKey: .harvestDate) ?? Date()
        self.wetWeightGrams = try container.decodeIfPresent(Double.self, forKey: .wetWeightGrams) ?? 0.0
        self.dehydratorTempC = try container.decodeIfPresent(Double.self, forKey: .dehydratorTempC) ?? 50.0
        self.dehydratorHours = try container.decodeIfPresent(Double.self, forKey: .dehydratorHours) ?? 12.0
        self.dryWeightGrams = try container.decodeIfPresent(Double.self, forKey: .dryWeightGrams) ?? 0.0
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

struct StashJar: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var strainName: String = ""
    var skuCode: String = ""
    var potencyMultiplier: Double = 1.0
    var availableDryGrams: Double = 0.0
    var storageMethod: String = "Airtight Jar + Silica"
    var lastUpdated: Date = Date()
    var qrCodeID: String = ""
    
    init(id: UUID = UUID(), strainName: String, skuCode: String, potencyMultiplier: Double = 1.0, availableDryGrams: Double = 0.0, storageMethod: String = "Airtight Jar + Silica", lastUpdated: Date = Date(), qrCodeID: String) {
        self.id = id
        self.strainName = strainName
        self.skuCode = skuCode
        self.potencyMultiplier = potencyMultiplier
        self.availableDryGrams = availableDryGrams
        self.storageMethod = storageMethod
        self.lastUpdated = lastUpdated
        self.qrCodeID = qrCodeID
    }
    
    enum CodingKeys: String, CodingKey {
        case id, strainName, skuCode, potencyMultiplier, availableDryGrams, storageMethod, lastUpdated, qrCodeID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.strainName = try container.decodeIfPresent(String.self, forKey: .strainName) ?? ""
        self.skuCode = try container.decodeIfPresent(String.self, forKey: .skuCode) ?? ""
        self.potencyMultiplier = try container.decodeIfPresent(Double.self, forKey: .potencyMultiplier) ?? 1.0
        self.availableDryGrams = try container.decodeIfPresent(Double.self, forKey: .availableDryGrams) ?? 0.0
        self.storageMethod = try container.decodeIfPresent(String.self, forKey: .storageMethod) ?? "Airtight Jar + Silica"
        self.lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
        self.qrCodeID = try container.decodeIfPresent(String.self, forKey: .qrCodeID) ?? ""
    }
}

struct LabSupplyItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = "Grain & Spawn"
    var quantity: Double = 0.0
    var unit: String = "pcs"
    var minThreshold: Double = 1.0
    var qrCodeID: String = ""
    var lastUpdated: Date = Date()
    
    init(id: UUID = UUID(), name: String, category: String, quantity: Double, unit: String, minThreshold: Double = 1.0, qrCodeID: String, lastUpdated: Date = Date()) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.minThreshold = minThreshold
        self.qrCodeID = qrCodeID
        self.lastUpdated = lastUpdated
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, quantity, unit, minThreshold, qrCodeID, lastUpdated
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Grain & Spawn"
        self.quantity = try container.decodeIfPresent(Double.self, forKey: .quantity) ?? 0.0
        self.unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? "pcs"
        self.minThreshold = try container.decodeIfPresent(Double.self, forKey: .minThreshold) ?? 1.0
        self.qrCodeID = try container.decodeIfPresent(String.self, forKey: .qrCodeID) ?? ""
        self.lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
    }
}

// MARK: - SAVED QR CODE ARCHIVE MODEL
struct SavedQRCodeItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var code: String = ""
    var title: String = ""
    var subtitle: String = ""
    var category: String = "General"
    var dateCreated: Date = Date()
    var linkedID: UUID? = nil
    var notes: String = ""
    var payload: String = ""
    
    init(
        id: UUID = UUID(),
        code: String,
        title: String,
        subtitle: String = "",
        category: String = "General",
        dateCreated: Date = Date(),
        linkedID: UUID? = nil,
        notes: String = "",
        payload: String = ""
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.dateCreated = dateCreated
        self.linkedID = linkedID
        self.notes = notes
        self.payload = payload.isEmpty ? code : payload
    }
    
    enum CodingKeys: String, CodingKey {
        case id, code, title, subtitle, category, dateCreated, linkedID, notes, payload
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? "General"
        self.dateCreated = try container.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        self.linkedID = try container.decodeIfPresent(UUID.self, forKey: .linkedID)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.payload = try container.decodeIfPresent(String.self, forKey: .payload) ?? ""
        if self.payload.isEmpty {
            self.payload = self.code
        }
    }
}

struct LabTimerItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var label: String = ""
    var endDate: Date = Date()
    var totalMinutes: Int = 0
    
    init(id: UUID = UUID(), label: String, endDate: Date, totalMinutes: Int) {
        self.id = id
        self.label = label
        self.endDate = endDate
        self.totalMinutes = totalMinutes
    }
    
    enum CodingKeys: String, CodingKey {
        case id, label, endDate, totalMinutes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        self.endDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? Date()
        self.totalMinutes = try container.decodeIfPresent(Int.self, forKey: .totalMinutes) ?? 0
    }
}

struct SterilizationPreset: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var durationMinutes: Int
    var pressureOrNotes: String
    var method: String = "Pressure Cooker (15 PSI / 121°C)"
    
    init(id: UUID = UUID(), name: String, durationMinutes: Int, pressureOrNotes: String, method: String = "Pressure Cooker (15 PSI / 121°C)") {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
        self.pressureOrNotes = pressureOrNotes
        self.method = method
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, durationMinutes, pressureOrNotes, method
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        self.pressureOrNotes = try container.decodeIfPresent(String.self, forKey: .pressureOrNotes) ?? ""
        self.method = try container.decodeIfPresent(String.self, forKey: .method) ?? "Pressure Cooker (15 PSI / 121°C)"
    }
}


struct SmartDeviceItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = "Humidifier" { didSet { lastModifiedAt = Date() } }
    var deviceType: String = "Humidifier" { didSet { lastModifiedAt = Date() } }
    var brand: String = "Tuya / Smart Life" { didSet { lastModifiedAt = Date() } }
    var webhookURL: String = "" { didSet { lastModifiedAt = Date() } }
    var remoteCloudURL: String = "" { didSet { lastModifiedAt = Date() } }
    var tuyaDeviceID: String = "" { didSet { lastModifiedAt = Date() } }
    var switchCode: String = "switch_1" { didSet { lastModifiedAt = Date() } }
    var isOn: Bool = false { didSet { lastModifiedAt = Date() } }
    var autoControlEnabled: Bool = true { didSet { lastModifiedAt = Date() } }
    var currentTempC: Double? = nil
    var currentHumidityPct: Double? = nil
    var lastReadingTime: Date? = nil
    
    // Autopilot Mode & Manual Interval Settings
    var autopilotMode: String = "auto" { didSet { lastModifiedAt = Date() } }
    var customIntervalHours: Int = 3 { didSet { lastModifiedAt = Date() } }
    var customIntervalMinutes: Int = 0 { didSet { lastModifiedAt = Date() } }
    var customDurationMinutes: Int = 5 { didSet { lastModifiedAt = Date() } }
    var lastCustomExecutionTime: Date? = nil
    var lastTurnedOnTime: Date? = nil
    var tuyaTimerCount: Int = 0 { didSet { lastModifiedAt = Date() } }
    var isOnlineOnTuya: Bool = true { didSet { lastModifiedAt = Date() } }
    var lightOnHour: Int = 8 { didSet { lastModifiedAt = Date() } }
    var lightOffHour: Int = 20 { didSet { lastModifiedAt = Date() } }
    var lastModifiedAt: Date = Date()
    
    // Ingangstijdstip / Effective Start Moment (Schema pas actief vanaf deze datum/tijd)
    var scheduleEffectiveFrom: Date? = nil { didSet { lastModifiedAt = Date() } }
    
    public var isScheduleEffective: Bool {
        guard let start = scheduleEffectiveFrom else { return true }
        return Date() >= start
    }
    
    // Handmatige Overschrijving over Autopilot/Schema's
    var manualOverrideUntil: Date? = nil { didSet { lastModifiedAt = Date() } }
    var manualOverrideState: Bool? = nil { didSet { lastModifiedAt = Date() } }
    
    public var isManualOverrideActive: Bool {
        guard let until = manualOverrideUntil else { return false }
        return Date() < until
    }
    
    var totalIntervalMinutes: Int {
        let total = (customIntervalHours * 60) + customIntervalMinutes
        return max(1, total)
    }
    
    var intervalFormatted: String {
        if customIntervalHours > 0 && customIntervalMinutes > 0 {
            return "\(customIntervalHours)h \(customIntervalMinutes)m"
        } else if customIntervalHours > 0 {
            return "\(customIntervalHours)h"
        } else {
            return "\(customIntervalMinutes)m"
        }
    }
    
    public var isWithinLightSchedule: Bool {
        guard deviceType == "Light" && autoControlEnabled else { return false }
        let currentHour = Calendar.current.component(.hour, from: Date())
        if lightOnHour < lightOffHour {
            return currentHour >= lightOnHour && currentHour < lightOffHour
        } else {
            // Crosses midnight (e.g. 20:00 to 08:00) or 24h
            return currentHour >= lightOnHour || currentHour < lightOffHour
        }
    }
    
    public var isManualOnly: Bool {
        brand.localizedCaseInsensitiveContains("manual") || brand.localizedCaseInsensitiveContains("handmatig")
    }
    
    public static let supportedProtocols: [(id: String, nameNl: String, nameEn: String, icon: String, hintNl: String, hintEn: String)] = [
        ("Tuya / Smart Life", "Tuya / Smart Life", "Tuya / Smart Life", "bolt.fill", "Standard Tuya / Smart Life plugs via Cloud & Pi Hub", "Standard Tuya / Smart Life plugs via Cloud & Pi Hub"),
        ("Shelly (Local Wi-Fi)", "Shelly (Local Wi-Fi)", "Shelly (Local Wi-Fi)", "flame.fill", "100% local over Wi-Fi with direct HTTP REST API (no cloud)", "100% local over Wi-Fi with direct HTTP REST API (no cloud)"),
        ("Tasmota / Sonoff", "Tasmota / Sonoff (HTTP)", "Tasmota / Sonoff (HTTP)", "network", "Open-source wifi firmware via local HTTP command", "Open-source wifi firmware via local HTTP command"),
        ("Home Assistant / Webhook", "Home Assistant / Webhook", "Home Assistant / Webhook", "arrow.triangle.swap", "Custom URL / Webhook trigger", "Custom URL / Webhook trigger"),
        ("Manual / Reminder Only", "Manual (Reminders Only)", "Manual (Reminders Only)", "hand.raised.fill", "No hardware required: MycoLabs reminds you when to mist or fan", "No hardware required: MycoLabs reminds you when to mist or fan")
    ]
    
    static func icon(for type: String) -> String {
        switch type {
        case "Humidifier": return "drop.fill"
        case "ExhaustFan": return "wind"
        case "Sensor": return "thermometer.medium"
        case "Heater": return "flame.fill"
        case "Light": return "lightbulb.fill"
        default: return "powerplug.fill"
        }
    }
    
    static func label(for type: String, isDutch: Bool = false) -> String {
        switch type {
        case "Humidifier": return "Humidifier"
        case "ExhaustFan": return "Exhaust Fan (FAE)"
        case "Sensor": return "Climate Sensor"
        case "Heater": return "Heat Mat"
        case "Light": return "Grow Light"
        default: return "Smart Plug"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, deviceType, brand, webhookURL, remoteCloudURL, tuyaDeviceID, switchCode
        case isOn, autoControlEnabled, currentTempC, currentHumidityPct, lastReadingTime
        case autopilotMode, customIntervalHours, customIntervalMinutes, customDurationMinutes, lastCustomExecutionTime, lastTurnedOnTime
        case tuyaTimerCount, isOnlineOnTuya, lastModifiedAt
        case lightOnHour, lightOffHour
        case manualOverrideUntil, manualOverrideState
        case scheduleEffectiveFrom
    }
    
    init(id: UUID = UUID(),
         name: String = "Humidifier",
         deviceType: String = "Humidifier",
         brand: String = "Tuya / Smart Life",
         webhookURL: String = "",
         remoteCloudURL: String = "",
         tuyaDeviceID: String = "",
         switchCode: String = "switch_1",
         isOn: Bool = false,
         autoControlEnabled: Bool = true,
         currentTempC: Double? = nil,
         currentHumidityPct: Double? = nil,
         lastReadingTime: Date? = nil,
         autopilotMode: String = "auto",
         customIntervalHours: Int = 3,
         customIntervalMinutes: Int = 0,
         customDurationMinutes: Int = 5,
         lastCustomExecutionTime: Date? = nil,
         lastTurnedOnTime: Date? = nil,
         tuyaTimerCount: Int = 0,
         isOnlineOnTuya: Bool = true,
         lightOnHour: Int = 8,
         lightOffHour: Int = 20,
         lastModifiedAt: Date = Date(),
         manualOverrideUntil: Date? = nil,
         manualOverrideState: Bool? = nil,
         scheduleEffectiveFrom: Date? = nil) {
        self.id = id
        self.name = name
        self.deviceType = deviceType
        self.brand = brand
        self.webhookURL = webhookURL
        self.remoteCloudURL = remoteCloudURL
        self.tuyaDeviceID = tuyaDeviceID
        self.switchCode = switchCode
        self.isOn = isOn
        self.autoControlEnabled = autoControlEnabled
        self.currentTempC = currentTempC
        self.currentHumidityPct = currentHumidityPct
        self.lastReadingTime = lastReadingTime
        self.autopilotMode = autopilotMode
        self.customIntervalHours = customIntervalHours
        self.customIntervalMinutes = customIntervalMinutes
        self.customDurationMinutes = customDurationMinutes
        self.lastCustomExecutionTime = lastCustomExecutionTime
        self.lastTurnedOnTime = lastTurnedOnTime
        self.tuyaTimerCount = tuyaTimerCount
        self.isOnlineOnTuya = isOnlineOnTuya
        self.lightOnHour = lightOnHour
        self.lightOffHour = lightOffHour
        self.lastModifiedAt = lastModifiedAt
        self.manualOverrideUntil = manualOverrideUntil
        self.manualOverrideState = manualOverrideState
        self.scheduleEffectiveFrom = scheduleEffectiveFrom
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Device"
        self.deviceType = try c.decodeIfPresent(String.self, forKey: .deviceType) ?? "GenericPlug"
        self.brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? "Tuya / Smart Life"
        self.webhookURL = try c.decodeIfPresent(String.self, forKey: .webhookURL) ?? ""
        self.remoteCloudURL = try c.decodeIfPresent(String.self, forKey: .remoteCloudURL) ?? ""
        self.tuyaDeviceID = try c.decodeIfPresent(String.self, forKey: .tuyaDeviceID) ?? ""
        self.switchCode = try c.decodeIfPresent(String.self, forKey: .switchCode) ?? "switch_1"
        self.isOn = try c.decodeIfPresent(Bool.self, forKey: .isOn) ?? false
        self.autoControlEnabled = try c.decodeIfPresent(Bool.self, forKey: .autoControlEnabled) ?? true
        self.currentTempC = try c.decodeIfPresent(Double.self, forKey: .currentTempC)
        self.currentHumidityPct = try c.decodeIfPresent(Double.self, forKey: .currentHumidityPct)
        self.lastReadingTime = try c.decodeIfPresent(Date.self, forKey: .lastReadingTime)
        self.autopilotMode = try c.decodeIfPresent(String.self, forKey: .autopilotMode) ?? "auto"
        self.customIntervalHours = try c.decodeIfPresent(Int.self, forKey: .customIntervalHours) ?? 3
        self.customIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .customIntervalMinutes) ?? 0
        self.customDurationMinutes = try c.decodeIfPresent(Int.self, forKey: .customDurationMinutes) ?? 5
        self.lastCustomExecutionTime = try c.decodeIfPresent(Date.self, forKey: .lastCustomExecutionTime)
        self.lastTurnedOnTime = try c.decodeIfPresent(Date.self, forKey: .lastTurnedOnTime)
        self.tuyaTimerCount = try c.decodeIfPresent(Int.self, forKey: .tuyaTimerCount) ?? 0
        self.isOnlineOnTuya = try c.decodeIfPresent(Bool.self, forKey: .isOnlineOnTuya) ?? true
        self.lightOnHour = try c.decodeIfPresent(Int.self, forKey: .lightOnHour) ?? 8
        self.lightOffHour = try c.decodeIfPresent(Int.self, forKey: .lightOffHour) ?? 20
        self.lastModifiedAt = try c.decodeIfPresent(Date.self, forKey: .lastModifiedAt) ?? Date(timeIntervalSince1970: 0)
        self.manualOverrideUntil = try c.decodeIfPresent(Date.self, forKey: .manualOverrideUntil)
        self.manualOverrideState = try c.decodeIfPresent(Bool.self, forKey: .manualOverrideState)
        self.scheduleEffectiveFrom = try c.decodeIfPresent(Date.self, forKey: .scheduleEffectiveFrom)
    }

    mutating func applySynchronized(from incoming: SmartDeviceItem) {
        self.id = incoming.id
        self.name = incoming.name
        self.deviceType = incoming.deviceType
        self.brand = incoming.brand
        self.webhookURL = incoming.webhookURL
        self.remoteCloudURL = incoming.remoteCloudURL
        self.tuyaDeviceID = incoming.tuyaDeviceID
        self.switchCode = incoming.switchCode
        self.isOn = incoming.isOn
        self.autoControlEnabled = incoming.autoControlEnabled
        self.autopilotMode = incoming.autopilotMode
        self.customIntervalHours = incoming.customIntervalHours
        self.customIntervalMinutes = incoming.customIntervalMinutes
        self.customDurationMinutes = incoming.customDurationMinutes
        if let t = incoming.currentTempC { self.currentTempC = t }
        if let h = incoming.currentHumidityPct { self.currentHumidityPct = h }
        if let lr = incoming.lastReadingTime { self.lastReadingTime = lr }
        if let lc = incoming.lastCustomExecutionTime { self.lastCustomExecutionTime = lc }
        if let lto = incoming.lastTurnedOnTime { self.lastTurnedOnTime = lto }
        self.tuyaTimerCount = incoming.tuyaTimerCount
        self.isOnlineOnTuya = incoming.isOnlineOnTuya
        self.lightOnHour = incoming.lightOnHour
        self.lightOffHour = incoming.lightOffHour
        self.lastModifiedAt = incoming.lastModifiedAt
        if let mou = incoming.manualOverrideUntil { self.manualOverrideUntil = mou }
        if let mos = incoming.manualOverrideState { self.manualOverrideState = mos }
        if let sef = incoming.scheduleEffectiveFrom { self.scheduleEffectiveFrom = sef }
    }

    func isLocallyModified(relativeTo lastSync: Date?) -> Bool {
        guard let lastSync = lastSync else { return false }
        return lastModifiedAt > lastSync
    }
}

// MARK: - SMART DEVICE ACTIVITY & ERROR LOG
struct SmartDeviceLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var deviceId: UUID?
    var deviceName: String
    var deviceType: String
    var isOn: Bool // true: ON, false: OFF
    var timestamp: Date = Date()
    var trigger: String = "Manual"
    var isSuccess: Bool = true
    var errorMessage: String? = nil
    
    init(id: UUID = UUID(),
         deviceId: UUID? = nil,
         deviceName: String,
         deviceType: String,
         isOn: Bool,
         timestamp: Date = Date(),
         trigger: String = "Manual",
         isSuccess: Bool = true,
         errorMessage: String? = nil) {
        self.id = id
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.isOn = isOn
        self.timestamp = timestamp
        self.trigger = trigger
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
    }
    
    enum CodingKeys: String, CodingKey {
        case id, deviceId, deviceName, deviceType, isOn, timestamp, trigger, isSuccess, errorMessage
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.deviceId = try c.decodeIfPresent(UUID.self, forKey: .deviceId)
        self.deviceName = try c.decodeIfPresent(String.self, forKey: .deviceName) ?? "Device"
        self.deviceType = try c.decodeIfPresent(String.self, forKey: .deviceType) ?? "GenericPlug"
        self.isOn = try c.decodeIfPresent(Bool.self, forKey: .isOn) ?? false
        self.timestamp = try c.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        self.trigger = try c.decodeIfPresent(String.self, forKey: .trigger) ?? "Manual"
        self.isSuccess = try c.decodeIfPresent(Bool.self, forKey: .isSuccess) ?? true
        self.errorMessage = try c.decodeIfPresent(String.self, forKey: .errorMessage)
    }
}

// MARK: - MODULAR CAMERA SOURCE TYPES & CAPABILITIES
public enum CameraSourceType: String, Codable, CaseIterable, Sendable {
    case liveKit = "livekit"
    case rtsp = "rtsp"
    case httpSnapshot = "snapshot"
    case none = "none"
    
    public var displayNameNl: String {
        switch self {
        case .liveKit: return "iPhone Kweekcamera (LiveKit WebRTC)"
        case .rtsp: return "RTSP IP-Camera (Tapo, Reolink, Wyze)"
        case .httpSnapshot: return "HTTP Snapshot (ESP32-CAM, Pi Cam)"
        case .none: return "Geen Camera (Handmatige Foto's)"
        }
    }
    
    public var displayNameEn: String {
        switch self {
        case .liveKit: return "iPhone Grow Camera (LiveKit WebRTC)"
        case .rtsp: return "RTSP IP Camera (Tapo, Reolink, Wyze)"
        case .httpSnapshot: return "HTTP Snapshot (ESP32-CAM, Pi Cam)"
        case .none: return "No Camera (Manual Photos Only)"
        }
    }
}

public struct CameraCapabilities: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    public static let liveStream        = CameraCapabilities(rawValue: 1 << 0)
    public static let periodicSnapshot  = CameraCapabilities(rawValue: 1 << 1)
    public static let torchControl       = CameraCapabilities(rawValue: 1 << 2)
    public static let lensSelection      = CameraCapabilities(rawValue: 1 << 3)
    public static let opticalAnalysis    = CameraCapabilities(rawValue: 1 << 4)
    public static let twoWayAudio        = CameraCapabilities(rawValue: 1 << 5)
    public static let screenSleepControl = CameraCapabilities(rawValue: 1 << 6)
    
    public static let liveKitHub: CameraCapabilities = [
        .liveStream, .periodicSnapshot, .torchControl, .lensSelection, .opticalAnalysis, .twoWayAudio, .screenSleepControl
    ]
    
    public static let rtspCamera: CameraCapabilities = [
        .liveStream, .periodicSnapshot, .opticalAnalysis
    ]
    
    public static let httpSnapshot: CameraCapabilities = [
        .periodicSnapshot, .opticalAnalysis
    ]
    
    public static let none: CameraCapabilities = []
    
    public var hasScreen: Bool {
        contains(.screenSleepControl)
    }
    
    public static func capabilities(for sourceType: CameraSourceType) -> CameraCapabilities {
        switch sourceType {
        case .liveKit: return .liveKitHub
        case .rtsp: return .rtspCamera
        case .httpSnapshot: return .httpSnapshot
        case .none: return .none
        }
    }
}

// MARK: - RASPBERRY PI LAB HUB MODELS
public struct PiHubLogEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: String = UUID().uuidString
    public var timestamp: String
    public var device: String
    public var state: Bool
    public var trigger: String
    public var method: String

    public init(id: String = UUID().uuidString, timestamp: String, device: String, state: Bool, trigger: String, method: String) {
        self.id = id
        self.timestamp = timestamp
        self.device = device
        self.state = state
        self.trigger = trigger
        self.method = method
    }
}

struct GrowEnvironmentConfig: Codable, Hashable {
    var environmentName: String = "Martha Tent / Monotub Chamber" { didSet { lastModifiedAt = Date() } }
    var growChamberType: String = "growTent" { didSet { lastModifiedAt = Date() } } // "growTent" or "monotub"
    var targetDayTempC: Double = 23.5 { didSet { lastModifiedAt = Date() } }
    var targetNightTempC: Double = 19.5 { didSet { lastModifiedAt = Date() } }
    var isDayNightCycleEnabled: Bool = true { didSet { lastModifiedAt = Date() } }
    var dayStartHour: Int = 7 { didSet { lastModifiedAt = Date() } }
    var nightStartHour: Int = 21 { didSet { lastModifiedAt = Date() } }
    var isPinningInductionActive: Bool = false { didSet { lastModifiedAt = Date() } }
    var pinningTargetTempC: Double = 18.5 { didSet { lastModifiedAt = Date() } }
    
    var isCurrentlyDayTime: Bool {
        let currentHour = Calendar.current.component(.hour, from: Date())
        if dayStartHour < nightStartHour {
            return currentHour >= dayStartHour && currentHour < nightStartHour
        } else {
            return currentHour >= dayStartHour || currentHour < nightStartHour
        }
    }
    
    var effectiveTargetTempC: Double {
        if isPinningInductionActive {
            return pinningTargetTempC
        }
        if isDayNightCycleEnabled {
            return isCurrentlyDayTime ? targetDayTempC : targetNightTempC
        }
        return targetDayTempC
    }
    
    var effectiveFaeIntervalMinutes: Int {
        if isPinningInductionActive {
            return max(30, faeIntervalMinutes / 2)
        }
        return faeIntervalMinutes
    }
    var targetHumidityPct: Double = 90.0 { didSet { lastModifiedAt = Date() } }
    var faeIntervalMinutes: Int = 180 { didSet { lastModifiedAt = Date() } }
    var faeDurationMinutes: Int = 5 { didSet { lastModifiedAt = Date() } }
    var lightHoursPerDay: Int = 12 { didSet { lastModifiedAt = Date() } }
    
    // Advanced User Configurable Climate & Automation Limits (Free custom configuration)
    var humidityHysteresisPct: Double = 2.0 { didSet { lastModifiedAt = Date() } }
    var tempHysteresisC: Double = 0.5 { didSet { lastModifiedAt = Date() } }
    var maxCo2ThresholdPpm: Int = 1000 { didSet { lastModifiedAt = Date() } }
    var humidifierDurationSeconds: Int = 120 { didSet { lastModifiedAt = Date() } }
    var customTimelapseIntervalMinutes: Int = 15 { didSet { lastModifiedAt = Date() } }
    var pinningFaeMultiplier: Double = 2.0 { didSet { lastModifiedAt = Date() } }
    
    // Pre-FAE Bevochtiging-stop (Lead Time Lockout Vóór Afzuiging in minuten, bijv. 10 of 15m)
    var preFaeHumidifierLockoutMinutes: Int = 10 { didSet { lastModifiedAt = Date() } }
    
    // Instelbare Post-FAE Vochtigheid Hersteltijd (Duur van de bevochtiger na afzuiging in seconden; 0 = Smart AI Dynamisch)
    var postFaeRecoveryDurationSeconds: Int = 120 { didSet { lastModifiedAt = Date() } }
    
    // Ingangstijdstip / Effective Start Moment voor het algemene klimaatschema
    var scheduleEffectiveFrom: Date? = nil { didSet { lastModifiedAt = Date() } }
    
    public var isScheduleEffective: Bool {
        guard let start = scheduleEffectiveFrom else { return true }
        return Date() >= start
    }
    var tuyaApiKey: String = "" { didSet { lastModifiedAt = Date() } }
    var tuyaApiSecret: String = "" { didSet { lastModifiedAt = Date() } }
    var tuyaDeviceID: String = "" { didSet { lastModifiedAt = Date() } }
    var tuyaRegion: String = "ce" { didSet { lastModifiedAt = Date() } }
    var tuyaVerified: Bool = false { didSet { lastModifiedAt = Date() } }
    var tuyaVerifiedAt: Date? = nil
    var remoteCameraStreamURL: String = ""
    var enableRemoteCloudSync: Bool = true
    var isBroadcastingCloudCam: Bool = false
    var lastRemoteSnapshotBase64: String = ""
    var lastRemoteSnapshotTime: Date? = nil
    var remoteTorchRequested: Bool = false
    
    // Camera Stream Hub Battery & Power State
    var cameraBatteryLevel: Float? = nil
    var cameraIsCharging: Bool = false
    var cameraBatteryLastUpdated: Date? = nil
    
    // Modular Camera Source Configuration (LiveKit, RTSP, HTTP Snapshot, Manual)
    var cameraSourceType: String? = "livekit" { didSet { lastModifiedAt = Date() } }
    var rtspStreamURL: String? = "" { didSet { lastModifiedAt = Date() } }
    var httpSnapshotURL: String? = "" { didSet { lastModifiedAt = Date() } }
    
    var effectiveCameraSource: CameraSourceType {
        CameraSourceType(rawValue: cameraSourceType ?? "livekit") ?? .liveKit
    }
    
    var effectiveRtspURL: String {
        (rtspStreamURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var effectiveSnapshotURL: String {
        (httpSnapshotURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var effectiveCameraCapabilities: CameraCapabilities {
        CameraCapabilities.capabilities(for: effectiveCameraSource)
    }
    
    // Live Sensor Readings (nil when no sensor connected or no data received yet!)
    var latestSensorTempC: Double? = nil
    var latestSensorHumidityPct: Double? = nil
    var latestSensorCo2Ppm: Int? = nil
    var latestSensorReadingTime: Date? = nil
    var sensorDeviceName: String? = nil
    
    // Manual Climate Measurements
    var manualTempC: Double? = nil { didSet { lastModifiedAt = Date() } }
    var manualHumidityPct: Double? = nil { didSet { lastModifiedAt = Date() } }
    var manualReadingTime: Date? = nil { didSet { lastModifiedAt = Date() } }
    
    var currentTempC: Double? {
        if let mTime = manualReadingTime, let mVal = manualTempC {
            if let sTime = latestSensorReadingTime, let sVal = latestSensorTempC {
                return mTime >= sTime ? mVal : sVal
            }
            return mVal
        }
        return latestSensorTempC
    }
    var currentHumidityPct: Double? {
        if let mTime = manualReadingTime, let mVal = manualHumidityPct {
            if let sTime = latestSensorReadingTime, let sVal = latestSensorHumidityPct {
                return mTime >= sTime ? mVal : sVal
            }
            return mVal
        }
        return latestSensorHumidityPct
    }
    var currentReadingTime: Date? {
        if let mTime = manualReadingTime {
            if let sTime = latestSensorReadingTime {
                return mTime >= sTime ? mTime : sTime
            }
            return mTime
        }
        return latestSensorReadingTime
    }
    var isManualReading: Bool {
        if let mTime = manualReadingTime, (manualTempC != nil || manualHumidityPct != nil) {
            if let sTime = latestSensorReadingTime {
                return mTime >= sTime
            }
            return true
        }
        return false
    }
    var hasActiveSensor: Bool {
        if let sTime = latestSensorReadingTime, (latestSensorTempC != nil || latestSensorHumidityPct != nil) {
            if let mTime = manualReadingTime {
                return sTime > mTime
            }
            return true
        }
        return false
    }
    
    // Autopilot 24/7 Automation Engine
    var isAutopilotEnabled: Bool = true { didSet { lastModifiedAt = Date() } }
    var isMaintenanceModeActive: Bool = false { didSet { lastModifiedAt = Date() } }
    var maintenanceModeStartTime: Date? = nil { didSet { lastModifiedAt = Date() } }
    var maintenanceModeAutoResumeMinutes: Int = 30 { didSet { lastModifiedAt = Date() } }
    var is24_7HubBackgroundModeEnabled: Bool = true { didSet { lastModifiedAt = Date() } }
    var isScreenAlwaysOnEnabled: Bool = false
    var autoCaptureTimelapseOnLaunch: Bool = false
    var autoCloudBroadcastOnLaunch: Bool = false
    var autoDimScreenSaver: Bool = false
    var lastFaeExecutionTime: Date? = nil
    var lastHumidifierExecutionTime: Date? = nil
    var lastAutopilotLogMessage: String = "Autopilot active and vigilant"
    var lastAutopilotLogTime: Date? = nil
    var lastModifiedAt: Date? = nil
    
    // Grow Space Dimensions & AI Airflow Calculation
    var spacePreset: String = "Martha Tent" { didSet { lastModifiedAt = Date() } }
    var roomLengthCm: Double = 120.0 { didSet { lastModifiedAt = Date() } }
    var roomWidthCm: Double = 60.0 { didSet { lastModifiedAt = Date() } }
    var roomHeightCm: Double = 150.0 { didSet { lastModifiedAt = Date() } }
    var fanCapacityM3H: Double = 100.0 { didSet { lastModifiedAt = Date() } }
    var humidifierOutputMlH: Double = 300.0 { didSet { lastModifiedAt = Date() } }
    var aiDailyWaterUsageMl: Double = 480.0 { didSet { lastModifiedAt = Date() } }
    var isAiClimateModelApplied: Bool = true { didSet { lastModifiedAt = Date() } }
    
    // Alert Push Thresholds & Remote Notifier
    var enableRemoteAlertNotifications: Bool = true { didSet { lastModifiedAt = Date() } }
    var minHumidityAlertThresholdPct: Double = 80.0 { didSet { lastModifiedAt = Date() } }
    var maxHumidityAlertThresholdPct: Double = 98.0 { didSet { lastModifiedAt = Date() } }
    var minTempAlertThresholdC: Double = 18.0 { didSet { lastModifiedAt = Date() } }
    var maxTempAlertThresholdC: Double = 27.5 { didSet { lastModifiedAt = Date() } }
    var minBatteryAlertThresholdPct: Int = 15 { didSet { lastModifiedAt = Date() } }
    
        // Raspberry Pi Lab Hub 24/7 Autonomy
    var piHubIP: String? = "192.168.50.115" { didSet { lastModifiedAt = Date() } }
    var piHubPort: Int? = 8088 { didSet { lastModifiedAt = Date() } }
    var piHubAutonomousActive: Bool? = true { didSet { lastModifiedAt = Date() } }
    var lastPiHubSyncTime: Date? = nil
    var piHubSyncStatusMessage: String? = ""
    
    var effectivePiHubIP: String {
        let ip = (piHubIP ?? "192.168.50.115").trimmingCharacters(in: .whitespacesAndNewlines)
        if ip.isEmpty || ip == "192.168.1.100" {
            return "192.168.50.115"
        }
        return ip
    }
    
    var effectivePiHubPort: Int {
        let p = piHubPort ?? 8088
        return p > 0 ? p : 8088
    }
    
    var isPiHubAutonomousActive: Bool {
        piHubAutonomousActive ?? true
    }
    
    // Tuya Cloud Offline Autonomous Execution & Cloud Sync
    var lastTuyaSyncTime: Date? = nil
    var tuyaOfflineAutonomousActive: Bool? = false
    var tuyaOfflineTimersCount: Int? = 0
    var tuyaSyncStatusMessage: String? = ""
    var tuyaCloudTrialExpired: Bool? = false { didSet { lastModifiedAt = Date() } }
    
    var isTuyaOfflineAutonomousActive: Bool {
        tuyaOfflineAutonomousActive ?? false
    }
    
    var isTuyaCloudExpired: Bool {
        tuyaCloudTrialExpired ?? false
    }
    
    var offlineTimersCount: Int {
        tuyaOfflineTimersCount ?? 0
    }
    
    var roomVolumeM3: Double {
        return max(0.01, (roomLengthCm * roomWidthCm * roomHeightCm) / 1_000_000.0)
    }
    
    var roomVolumeLiters: Double {
        return roomVolumeM3 * 1000.0
    }

    mutating func applySynchronized(from incoming: GrowEnvironmentConfig) {
        if !incoming.environmentName.isEmpty { self.environmentName = incoming.environmentName }
        if incoming.targetDayTempC > 0 { self.targetDayTempC = incoming.targetDayTempC }
        if incoming.targetNightTempC > 0 { self.targetNightTempC = incoming.targetNightTempC }
        self.isDayNightCycleEnabled = incoming.isDayNightCycleEnabled
        if incoming.dayStartHour >= 0 { self.dayStartHour = incoming.dayStartHour }
        if incoming.nightStartHour >= 0 { self.nightStartHour = incoming.nightStartHour }
        self.isPinningInductionActive = incoming.isPinningInductionActive
        if incoming.pinningTargetTempC > 0 { self.pinningTargetTempC = incoming.pinningTargetTempC }
        if incoming.targetHumidityPct > 0 { self.targetHumidityPct = incoming.targetHumidityPct }
        if incoming.faeIntervalMinutes > 0 { self.faeIntervalMinutes = incoming.faeIntervalMinutes }
        if incoming.faeDurationMinutes > 0 { self.faeDurationMinutes = incoming.faeDurationMinutes }
        if incoming.lightHoursPerDay > 0 { self.lightHoursPerDay = incoming.lightHoursPerDay }
                if let ip = incoming.piHubIP, !ip.isEmpty { self.piHubIP = ip }
        if let port = incoming.piHubPort, port > 0 { self.piHubPort = port }
        if let autoActive = incoming.piHubAutonomousActive { self.piHubAutonomousActive = autoActive }
        if let syncTime = incoming.lastPiHubSyncTime { self.lastPiHubSyncTime = syncTime }
        if let msg = incoming.piHubSyncStatusMessage, !msg.isEmpty { self.piHubSyncStatusMessage = msg }
        if !incoming.tuyaApiKey.isEmpty {
            self.tuyaApiKey = incoming.tuyaApiKey
            self.tuyaApiSecret = incoming.tuyaApiSecret
            self.tuyaRegion = incoming.tuyaRegion
            self.tuyaDeviceID = incoming.tuyaDeviceID
            self.tuyaVerified = incoming.tuyaVerified
            self.tuyaVerifiedAt = incoming.tuyaVerifiedAt
        }
        self.isAutopilotEnabled = incoming.isAutopilotEnabled
        self.isMaintenanceModeActive = incoming.isMaintenanceModeActive
        self.maintenanceModeStartTime = incoming.maintenanceModeStartTime
        self.maintenanceModeAutoResumeMinutes = incoming.maintenanceModeAutoResumeMinutes
        self.is24_7HubBackgroundModeEnabled = incoming.is24_7HubBackgroundModeEnabled
        if !incoming.spacePreset.isEmpty { self.spacePreset = incoming.spacePreset }
        if incoming.roomLengthCm > 0 { self.roomLengthCm = incoming.roomLengthCm }
        if incoming.roomWidthCm > 0 { self.roomWidthCm = incoming.roomWidthCm }
        if incoming.roomHeightCm > 0 { self.roomHeightCm = incoming.roomHeightCm }
        if incoming.fanCapacityM3H > 0 { self.fanCapacityM3H = incoming.fanCapacityM3H }
        if incoming.humidifierOutputMlH > 0 { self.humidifierOutputMlH = incoming.humidifierOutputMlH }
        if incoming.aiDailyWaterUsageMl > 0 { self.aiDailyWaterUsageMl = incoming.aiDailyWaterUsageMl }
        self.isAiClimateModelApplied = incoming.isAiClimateModelApplied
        if let mt = incoming.manualTempC { self.manualTempC = mt }
        if let mh = incoming.manualHumidityPct { self.manualHumidityPct = mh }
        if let mr = incoming.manualReadingTime { self.manualReadingTime = mr }
        if let incomingSyncTime = incoming.lastTuyaSyncTime {
            if self.lastTuyaSyncTime == nil || incomingSyncTime > self.lastTuyaSyncTime! {
                self.lastTuyaSyncTime = incomingSyncTime
                self.tuyaOfflineAutonomousActive = incoming.tuyaOfflineAutonomousActive
                self.tuyaOfflineTimersCount = incoming.tuyaOfflineTimersCount
                self.tuyaSyncStatusMessage = incoming.tuyaSyncStatusMessage
            }
        }
        if let expired = incoming.tuyaCloudTrialExpired {
            self.tuyaCloudTrialExpired = expired
        }
        if incoming.preFaeHumidifierLockoutMinutes >= 0 { self.preFaeHumidifierLockoutMinutes = incoming.preFaeHumidifierLockoutMinutes }
        if incoming.postFaeRecoveryDurationSeconds >= 0 { self.postFaeRecoveryDurationSeconds = incoming.postFaeRecoveryDurationSeconds }
        if let sef = incoming.scheduleEffectiveFrom { self.scheduleEffectiveFrom = sef }
        self.lastModifiedAt = incoming.lastModifiedAt
    }

    func isLocallyModified(relativeTo lastSync: Date?) -> Bool {
        guard let lastSync = lastSync, let lastMod = lastModifiedAt else { return false }
        return lastMod > lastSync
    }
}

// MARK: - LAB ALERT MODELS
public enum LabAlertSeverity: String, Codable {
    case info = "info"
    case warning = "warning"
    case critical = "critical"
    
    public var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

public enum LabAlertCategory: String, Codable {
    case lowHumidity = "lowHumidity"
    case highHumidity = "highHumidity"
    case lowTemperature = "lowTemperature"
    case highTemperature = "highTemperature"
    case lowBattery = "lowBattery"
    case cameraOffline = "cameraOffline"
    case storageCritical = "storageCritical"
    
    public var titleEn: String {
        switch self {
        case .lowHumidity: return "Humidity Too Low"
        case .highHumidity: return "Humidity Too High"
        case .lowTemperature: return "Temperature Too Low"
        case .highTemperature: return "Temperature Too High"
        case .lowBattery: return "Camera Battery Critical"
        case .cameraOffline: return "Grow Camera Offline"
        case .storageCritical: return "Storage Space Critical"
        }
    }
    
    public var titleNl: String {
        titleEn
    }
}

public struct LabAlertRecord: Identifiable, Codable, Hashable {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var severity: LabAlertSeverity = .warning
    public var category: LabAlertCategory = .lowHumidity
    public var title: String = ""
    public var message: String = ""
    public var currentValue: Double? = nil
    public var thresholdValue: Double? = nil
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), severity: LabAlertSeverity = .warning, category: LabAlertCategory = .lowHumidity, title: String = "", message: String = "", currentValue: Double? = nil, thresholdValue: Double? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.severity = severity
        self.category = category
        self.title = title
        self.message = message
        self.currentValue = currentValue
        self.thresholdValue = thresholdValue
    }
}

public final class TimelapseImageCache: @unchecked Sendable {
    public static let shared = TimelapseImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 150
        cache.totalCostLimit = 120 * 1024 * 1024 // 120 MB
    }
    
    public func get(id: UUID) -> UIImage? {
        cache.object(forKey: id.uuidString as NSString)
    }
    
    public func set(_ image: UIImage, id: UUID) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: id.uuidString as NSString, cost: cost)
    }
    
    public func remove(id: UUID) {
        cache.removeObject(forKey: id.uuidString as NSString)
    }
    
    public func clear() {
        cache.removeAllObjects()
    }
}

struct TimelapsePhotoItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var caption: String = ""
    var relativeMinutes: Int = 0
    var isLiDAR: Bool = false
    var imageData: Data? = nil
    var filename: String? = nil
    var cameraType: String? = nil // "wide" (1.0x Kweek), "ultraWide" (0.5x Tent), "telephoto" (Zoom AI Sensor)
    var cameraName: String? = nil // e.g. "Kweek (1.0x)", "Tent (0.5x)", "Sensor AI (Zoom)"
    var temperatureC: Double? = nil
    var humidityPct: Double? = nil
    var vpdKpa: Double? = nil

    static var storageDirectoryURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TimelapsePhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    var resolvedCameraType: String {
        if let type = cameraType, !type.isEmpty {
            return type
        }
        let lower = caption.lowercased()
        if lower.contains("ultra") || lower.contains("0.5x") || lower.contains("tent") {
            return "ultraWide"
        }
        if lower.contains("tele") || lower.contains("zoom") || lower.contains("sensor") || lower.contains("vocht") || lower.contains("ai") {
            return "telephoto"
        }
        if isLiDAR || lower.contains("lidar") || lower.contains("diepte") {
            return "lidar"
        }
        return "wide"
    }

    var cameraDisplayName: String {
        if let name = cameraName, !name.isEmpty {
            return name
        }
        switch resolvedCameraType {
        case "ultraWide":
            return "Tent (0.5x)"
        case "telephoto":
            return "Sensor AI (Zoom)"
        default:
            return "Grow (1.0x)"
        }
    }

    var localFileURL: URL? {
        if let filename = filename, !filename.isEmpty {
            let clean = URL(fileURLWithPath: filename).lastPathComponent
            let url = Self.storageDirectoryURL.appendingPathComponent(clean)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    var hasPhotoData: Bool {
        if imageData != nil { return true }
        if let filename = filename, !filename.isEmpty {
            let clean = URL(fileURLWithPath: filename).lastPathComponent
            let fileURL = Self.storageDirectoryURL.appendingPathComponent(clean)
            if FileManager.default.fileExists(atPath: fileURL.path) { return true }
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(clean)
            if FileManager.default.fileExists(atPath: docsURL.path) { return true }
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(clean)
            if FileManager.default.fileExists(atPath: tmpURL.path) { return true }
        }
        return false
    }

    func loadImage() -> UIImage? {
        if let cached = TimelapseImageCache.shared.get(id: id) {
            return cached
        }
        var loadedImage: UIImage? = nil
        if let filename = filename, !filename.isEmpty {
            let clean = URL(fileURLWithPath: filename).lastPathComponent
            let fileURL = Self.storageDirectoryURL.appendingPathComponent(clean)
            if let data = try? Data(contentsOf: fileURL), let img = UIImage(data: data) {
                loadedImage = img
            } else {
                let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(clean)
                if let data = try? Data(contentsOf: docsURL), let img = UIImage(data: data) {
                    loadedImage = img
                } else {
                    let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(clean)
                    if let data = try? Data(contentsOf: tmpURL), let img = UIImage(data: data) {
                        loadedImage = img
                    }
                }
            }
        }
        if loadedImage == nil, let data = imageData, let img = UIImage(data: data) {
            // Self-healing: persisteren naar schijf zodat het bestand lokaal beschikbaar is
            let fn = filename ?? "\(id.uuidString).jpg"
            let clean = URL(fileURLWithPath: fn).lastPathComponent
            let fileURL = Self.storageDirectoryURL.appendingPathComponent(clean)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try? data.write(to: fileURL)
            }
            loadedImage = img
        }
        if let img = loadedImage {
            TimelapseImageCache.shared.set(img, id: id)
        }
        return loadedImage
    }

    static func createAndSave(
        image: UIImage,
        caption: String,
        relativeMinutes: Int = 0,
        cameraType: String? = nil,
        cameraName: String? = nil,
        temperatureC: Double? = nil,
        humidityPct: Double? = nil,
        vpdKpa: Double? = nil
    ) -> TimelapsePhotoItem {
        let id = UUID()
        let filename = "\(id.uuidString).jpg"
        let fileURL = Self.storageDirectoryURL.appendingPathComponent(filename)
        // Originele maximale kwaliteit JPEG (1.0 - 100% Lossless) voor offline archief op schijf
        let highResJpeg = image.jpegData(compressionQuality: 1.0)
        if let data = highResJpeg {
            try? data.write(to: fileURL)
        }
        // Exporteer direct naar gedeelde App Group container voor widget weergave
        if let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mycolab.app") {
            let widgetSnapURL = groupContainer.appendingPathComponent("latest_chamber_snapshot.jpg")
            if let groupData = image.jpegData(compressionQuality: 0.82) {
                try? groupData.write(to: widgetSnapURL, options: .atomic)
            }
        }
        
        // Compacte preview data (< 40KB) die moeiteloos syncet via iCloud KVS en Multipeer P2P
        let previewData = MycoImageHelper.prepareForStorage(image: image, maxDimension: 640, compressionQuality: 0.65) ?? highResJpeg
        
        return TimelapsePhotoItem(
            id: id,
            timestamp: Date(),
            caption: caption,
            relativeMinutes: relativeMinutes,
            isLiDAR: false,
            imageData: previewData,
            filename: filename,
            cameraType: cameraType,
            cameraName: cameraName,
            temperatureC: temperatureC,
            humidityPct: humidityPct,
            vpdKpa: vpdKpa
        )
    }

    func deleteFile() {
        TimelapseImageCache.shared.remove(id: id)
        if let filename = filename, !filename.isEmpty {
            let clean = URL(fileURLWithPath: filename).lastPathComponent
            let fileURL = Self.storageDirectoryURL.appendingPathComponent(clean)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}

enum DashboardCameraMode: String, CaseIterable, Codable, Identifiable {
    case liveViewer = "liveViewer"      // Direct naar live feed meekijken
    case broadcaster = "broadcaster"    // Direct naar kweekcamera uitzenden
    case menu = "menu"                  // Keuzemenu (beide opties)

    var id: String { rawValue }

    func localizedTitle(store: MycoStore) -> String {
        switch self {
        case .liveViewer:
            return store.t(nl: "Live Meekijken (Directe feed)", en: "Live Monitor (Direct stream)")
        case .broadcaster:
            return store.t(nl: "Kweekcamera (Lab Uitzenden)", en: "Grow Camera (Lab Broadcast)")
        case .menu:
            return store.t(nl: "Keuzemenu (Kijker & Uitzender)", en: "Selection Menu (Both options)")
        }
    }
}

// MARK: - Splash & Startup Animation Mode
public enum SplashAnimationMode: String, Codable, CaseIterable, Identifiable {
    case video = "video"
    case modernLogo = "modernLogo"
    case disabled = "disabled"
    
    public var id: String { rawValue }
    
    public func localizedTitle(isEnglish: Bool) -> String {
        switch self {
        case .video:
            return isEnglish ? "Video Animation (animycolab.mp4)" : "Video Animatie (animycolab.mp4)"
        case .modernLogo:
            return isEnglish ? "Minimalist Logo Pulse" : "Minimalistische Logo Puls"
        case .disabled:
            return isEnglish ? "Direct to Dashboard (Disabled)" : "Direct naar Dashboard (Uitgeschakeld)"
        }
    }
    
    public var icon: String {
        switch self {
        case .video: return "play.rectangle.fill"
        case .modernLogo: return "sparkles"
        case .disabled: return "bolt.slash.fill"
        }
    }
    
    public func subtitle(isEnglish: Bool) -> String {
        switch self {
        case .video:
            return isEnglish ? "Plays the intro video on startup with tap-to-skip" : "Speelt de introductievideo af bij het opstarten met tik-om-over-te-slaan"
        case .modernLogo:
            return isEnglish ? "Sleek glowing badge animation (~1.8s)" : "Strakke oplichtende logo-animatie (~1.8s)"
        case .disabled:
            return isEnglish ? "Skips splash directly to dashboard" : "Slaat de intro over en opent direct het dashboard"
        }
    }
}

struct AppDatabase: Codable {
    var language: String = "en"
    var selectedTheme: String = "darkLab"
    var customThemes: [CustomAppTheme] = []
    var selectedCustomThemeId: UUID? = nil
    var stealthMode: Bool = false
    var biometricLock: Bool = false
    var stashBiometricLock: Bool = false
    var includeLogoInQR: Bool = false
    var qrErrorCorrectionLevel: String = "H"
    var qrLabelPresetSize: String = "38x38"
    var decoyPin: String = "9999"
    var isDecoyPinEnabled: Bool = false
    var masterPin: String = "1234"
    var dashboardCameraMode: DashboardCameraMode = .liveViewer
    var webhookKey: String = "ML-" + UUID().uuidString.prefix(8).uppercased()
    var strains: [StrainModel] = []
    var presets: [UserPreset] = []
    var preparationRecipes: [PreparationRecipe] = PreparationRecipe.defaultRecipes
    var sterilizationPresets: [SterilizationPreset] = [
        SterilizationPreset(name: "Pressure Cooker Grain", durationMinutes: 90, pressureOrNotes: "15 PSI (121°C)"),
        SterilizationPreset(name: "Agar Media (MEA)", durationMinutes: 45, pressureOrNotes: "15 PSI (121°C)"),
        SterilizationPreset(name: "Liquid Culture (LC)", durationMinutes: 30, pressureOrNotes: "15 PSI (121°C)"),
        SterilizationPreset(name: "CVG Pasteurization", durationMinutes: 120, pressureOrNotes: "Bucket Tek / Boiling water"),
        SterilizationPreset(name: "Hardwood Sawdust Substrate", durationMinutes: 150, pressureOrNotes: "15 PSI (121°C)")
    ]
    var cultures: [CultureItem] = []
    var projects: [GrowProject] = []
    var logs: [GrowLog] = []
    var harvests: [HarvestRecord] = []
    var stash: [StashJar] = []
    var supplies: [LabSupplyItem] = []
    var timers: [LabTimerItem] = []
    var smartDevices: [SmartDeviceItem] = []
    var smartDeviceLogs: [SmartDeviceLog] = []
    var environmentConfig: GrowEnvironmentConfig = GrowEnvironmentConfig()
    var timelapsePhotos: [TimelapsePhotoItem] = []
    var customQRCodes: [SavedQRCodeItem] = []
    var deletedItemIDs: [UUID] = []
    var deletedTuyaDeviceIDs: [String] = []
    var userExperienceLevel: String = "Not set"
    var hasCompletedOnboarding: Bool = false
    var isDemoMode: Bool = false
    var useModernInterface: Bool = true
    var alertHistory: [LabAlertRecord] = []
    var splashAnimationMode: SplashAnimationMode = .video
    var isSplashSoundEnabled: Bool = true

    init() {}

    enum CodingKeys: String, CodingKey {
        case language, selectedTheme, customThemes, selectedCustomThemeId
        case stealthMode, biometricLock, stashBiometricLock, includeLogoInQR, qrErrorCorrectionLevel, qrLabelPresetSize, decoyPin, isDecoyPinEnabled, masterPin
        case dashboardCameraMode
        case webhookKey, strains, presets, preparationRecipes, sterilizationPresets, cultures
        case projects, logs, harvests, stash, supplies, timers
        case smartDevices, smartDeviceLogs, environmentConfig, timelapsePhotos, customQRCodes
        case deletedItemIDs, deletedTuyaDeviceIDs
        case userExperienceLevel, hasCompletedOnboarding, isDemoMode, useModernInterface, alertHistory
        case splashAnimationMode, isSplashSoundEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.language = try container.decodeIfPresent(String.self, forKey: .language) ?? "en"
        self.selectedTheme = try container.decodeIfPresent(String.self, forKey: .selectedTheme) ?? "darkLab"
        self.customThemes = try container.decodeIfPresent([CustomAppTheme].self, forKey: .customThemes) ?? []
        self.selectedCustomThemeId = try container.decodeIfPresent(UUID.self, forKey: .selectedCustomThemeId)
        self.stealthMode = try container.decodeIfPresent(Bool.self, forKey: .stealthMode) ?? false
        self.biometricLock = try container.decodeIfPresent(Bool.self, forKey: .biometricLock) ?? false
        self.stashBiometricLock = try container.decodeIfPresent(Bool.self, forKey: .stashBiometricLock) ?? false
        self.includeLogoInQR = try container.decodeIfPresent(Bool.self, forKey: .includeLogoInQR) ?? false
        self.qrErrorCorrectionLevel = try container.decodeIfPresent(String.self, forKey: .qrErrorCorrectionLevel) ?? "H"
        self.qrLabelPresetSize = try container.decodeIfPresent(String.self, forKey: .qrLabelPresetSize) ?? "38x38"
        self.decoyPin = try container.decodeIfPresent(String.self, forKey: .decoyPin) ?? "9999"
        self.isDecoyPinEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDecoyPinEnabled) ?? false
        self.masterPin = try container.decodeIfPresent(String.self, forKey: .masterPin) ?? "1234"
        self.dashboardCameraMode = try container.decodeIfPresent(DashboardCameraMode.self, forKey: .dashboardCameraMode) ?? .liveViewer
        self.webhookKey = try container.decodeIfPresent(String.self, forKey: .webhookKey) ?? ("ML-" + UUID().uuidString.prefix(8).uppercased())
        self.strains = try container.decodeIfPresent([StrainModel].self, forKey: .strains) ?? []
        self.presets = try container.decodeIfPresent([UserPreset].self, forKey: .presets) ?? []
        self.preparationRecipes = try container.decodeIfPresent([PreparationRecipe].self, forKey: .preparationRecipes) ?? PreparationRecipe.defaultRecipes
        self.sterilizationPresets = try container.decodeIfPresent([SterilizationPreset].self, forKey: .sterilizationPresets) ?? [
            SterilizationPreset(name: "Pressure Cooker Grain", durationMinutes: 90, pressureOrNotes: "15 PSI (121°C)"),
            SterilizationPreset(name: "Agar Media (MEA)", durationMinutes: 45, pressureOrNotes: "15 PSI (121°C)"),
            SterilizationPreset(name: "Liquid Culture (LC)", durationMinutes: 30, pressureOrNotes: "15 PSI (121°C)"),
            SterilizationPreset(name: "CVG Pasteurization", durationMinutes: 120, pressureOrNotes: "Bucket Tek / Boiling water"),
            SterilizationPreset(name: "Hardwood Sawdust Substrate", durationMinutes: 150, pressureOrNotes: "15 PSI (121°C)")
        ]
        self.cultures = try container.decodeIfPresent([CultureItem].self, forKey: .cultures) ?? []
        self.projects = try container.decodeIfPresent([GrowProject].self, forKey: .projects) ?? []
        self.logs = try container.decodeIfPresent([GrowLog].self, forKey: .logs) ?? []
        self.harvests = try container.decodeIfPresent([HarvestRecord].self, forKey: .harvests) ?? []
        self.stash = try container.decodeIfPresent([StashJar].self, forKey: .stash) ?? []
        self.supplies = try container.decodeIfPresent([LabSupplyItem].self, forKey: .supplies) ?? []
        self.timers = try container.decodeIfPresent([LabTimerItem].self, forKey: .timers) ?? []
        self.smartDevices = try container.decodeIfPresent([SmartDeviceItem].self, forKey: .smartDevices) ?? []
        self.smartDeviceLogs = try container.decodeIfPresent([SmartDeviceLog].self, forKey: .smartDeviceLogs) ?? []
        self.environmentConfig = try container.decodeIfPresent(GrowEnvironmentConfig.self, forKey: .environmentConfig) ?? GrowEnvironmentConfig()
        self.timelapsePhotos = try container.decodeIfPresent([TimelapsePhotoItem].self, forKey: .timelapsePhotos) ?? []
        self.customQRCodes = try container.decodeIfPresent([SavedQRCodeItem].self, forKey: .customQRCodes) ?? []
        self.deletedItemIDs = try container.decodeIfPresent([UUID].self, forKey: .deletedItemIDs) ?? []
        self.deletedTuyaDeviceIDs = try container.decodeIfPresent([String].self, forKey: .deletedTuyaDeviceIDs) ?? []
        self.userExperienceLevel = try container.decodeIfPresent(String.self, forKey: .userExperienceLevel) ?? "Niet ingesteld"
        self.hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        self.isDemoMode = try container.decodeIfPresent(Bool.self, forKey: .isDemoMode) ?? false
        self.useModernInterface = try container.decodeIfPresent(Bool.self, forKey: .useModernInterface) ?? true
        self.alertHistory = try container.decodeIfPresent([LabAlertRecord].self, forKey: .alertHistory) ?? []
        self.splashAnimationMode = try container.decodeIfPresent(SplashAnimationMode.self, forKey: .splashAnimationMode) ?? .video
        self.isSplashSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSplashSoundEnabled) ?? true
    }
}


// MARK: - HARDWARE-BACKED AES-GCM 256-BIT ENCRYPTION VAULT
enum MycoSecurityVault {
    private static let keychainKeyTag = "com.mycolab.hardware.masterkey.v1"
    
    static func getOrCreateMasterKey() -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKeyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let keyData = item as? Data {
            return SymmetricKey(data: keyData)
        }
        
        let newKey = SymmetricKey(size: .bits256)
        let rawData = newKey.withUnsafeBytes { Data($0) }
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKeyTag,
            kSecValueData as String: rawData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
        return newKey
    }
    
    static func encrypt(_ plaintext: Data) throws -> Data {
        let key = getOrCreateMasterKey()
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "MycoLabSecurity", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to combine sealed box"])
        }
        return combined
    }
    
    static func decrypt(_ ciphertext: Data) throws -> Data {
        let key = getOrCreateMasterKey()
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    static func decryptIfEncrypted(_ data: Data) -> Data {
        if let decrypted = try? decrypt(data) {
            return decrypted
        }
        return data
    }
}


// MARK: - APPLE CORE DATA PERSISTENT STACK (SQLITE)
final class CoreDataManager: @unchecked Sendable {
    static let shared = CoreDataManager()
    let container: NSPersistentContainer
    
    init() {
        let model = NSManagedObjectModel()
        
        let entity = NSEntityDescription()
        entity.name = "MycoLabRecord"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let payloadAttr = NSAttributeDescription()
        payloadAttr.name = "payload"
        payloadAttr.attributeType = .binaryDataAttributeType
        payloadAttr.isOptional = false
        payloadAttr.allowsExternalBinaryDataStorage = true
        
        let updatedAtAttr = NSAttributeDescription()
        updatedAtAttr.name = "updatedAt"
        updatedAtAttr.attributeType = .dateAttributeType
        updatedAtAttr.isOptional = false
        
        entity.properties = [idAttr, payloadAttr, updatedAtAttr]
        model.entities = [entity]
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        let sqliteURL = appSupport.appendingPathComponent("MycoLabCoreData.sqlite")
        
        let description = NSPersistentStoreDescription(url: sqliteURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        container = NSPersistentContainer(name: "MycoLabCoreDataModel", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { desc, error in
            if let error = error {
                print("[MycoLabs CoreData] Fout bij laden Core Data store: \(error)")
            } else {
                print("[MycoLabs CoreData] SQLite store succesvol geladen op: \(desc.url?.path ?? "")")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func savePayload(id: String = "primary_database", data: Data) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "MycoLabRecord")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            
            do {
                let results = try context.fetch(fetchRequest)
                let record: NSManagedObject
                if let existing = results.first {
                    record = existing
                } else {
                    guard let entityDesc = self.container.managedObjectModel.entitiesByName["MycoLabRecord"] else { return }
                    record = NSManagedObject(entity: entityDesc, insertInto: context)
                    record.setValue(id, forKey: "id")
                }
                record.setValue(data, forKey: "payload")
                record.setValue(Date(), forKey: "updatedAt")
                
                context.processPendingChanges()
                if context.hasChanges {
                    try context.save()
                    print("[MycoLabs CoreData] Succesvol opgeslagen in Core Data SQLite (\(data.count) bytes).")
                }
            } catch {
                print("[MycoLabs CoreData] Fout bij opslaan in Core Data: \(error)")
            }
        }
    }
    
    func loadPayload(id: String = "primary_database") -> Data? {
        let context = container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "MycoLabRecord")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let record = results.first, let payload = record.value(forKey: "payload") as? Data {
                print("[MycoLabs CoreData] Succesvol \(payload.count) bytes geladen uit Core Data SQLite.")
                return payload
            }
        } catch {
            print("[MycoLabs CoreData] Fout bij ophalen uit Core Data: \(error)")
        }
        return nil
    }
    
    func resetData(id: String = "primary_database") {
        let context = container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "MycoLabRecord")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let results = try context.fetch(fetchRequest)
            for obj in results {
                context.delete(obj)
            }
            if context.hasChanges {
                try context.save()
                print("[MycoLabs CoreData] Core Data records gewist.")
            }
        } catch {
            print("[MycoLabs CoreData] Fout bij wissen Core Data: \(error)")
        }
    }
}

// MARK: - 3. CENTRAL STORE (PERMANENT STORAGE & COLD-START BIOMETRICS)
@MainActor

// MARK: - APPLE ID USER PROFILE MODEL
public struct AppleUserProfile: Codable, Equatable, Hashable {
    public var userIdentifier: String
    public var givenName: String?
    public var familyName: String?
    public var email: String?
    public var loginDate: Date = Date()
    
    public var displayName: String {
        let full = [givenName, familyName].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if !full.isEmpty { return full }
        if let email = email, !email.isEmpty { return email }
        return "MycoLabs Cultivator"
    }
}

