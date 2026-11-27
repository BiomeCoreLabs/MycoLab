//
//  MycoDecoyVaultManager.swift
//  MycoLab
//
//  Duress & Decoy Vault Management:
//  - Displays a benign, culinary mushroom profile (Oyster / Lion's Mane / Shiitake)
//  - Activated when entering the Decoy PIN (default: "9999") on the lock screen
//  - 100% isolates and hides sensitive strains, real logs, and entheogenic stash
//  - InfoTipButton integration for stealth configuration guidance
//

import Foundation
import SwiftUI

enum MycoDecoyVaultManager {
    static let defaultDecoyPin = "9999"
    
    // MARK: - Safe Culinary Mock Data
    static var decoyStrains: [StrainModel] {
        [
            StrainModel(
                name: "Pleurotus ostreatus (Grijze Oesterzwam)",
                skuCode: "OEST-01",
                species: "Pleurotus ostreatus",
                mushroomType: .culinary,
                colonizationSpeed: .fast,
                difficulty: .beginner,
                potencyMultiplier: 1.0,
                notes: "Culinaire gourmet paddenstoel, zeer agressieve kolonisator."
            ),
            StrainModel(
                name: "Hericium erinaceus (Lion's Mane / Pruikzwam)",
                skuCode: "LION-01",
                species: "Hericium erinaceus",
                mushroomType: .medicinal,
                colonizationSpeed: .moderate,
                difficulty: .intermediate,
                potencyMultiplier: 1.0,
                notes: "Gourmet en noötropische culinaire soort met koraalachtige textuur."
            ),
            StrainModel(
                name: "Lentinula edodes (Shiitake)",
                skuCode: "SHII-01",
                species: "Lentinula edodes",
                mushroomType: .culinary,
                colonizationSpeed: .slow,
                difficulty: .intermediate,
                potencyMultiplier: 1.0,
                notes: "Rijke umami smaak, vereist bruiningsfase voor inductie."
            )
        ]
    }
    
    static var decoyProjects: [GrowProject] {
        [
            GrowProject(
                strainName: "Pleurotus ostreatus",
                skuCode: "OEST-01",
                batchNumber: 101,
                phase: .fruiting,
                colonizationPercent: 100.0,
                containerName: "Monotub Fruiting Tent",
                substrateName: "Tarwestro & Koffiedik",
                latestTempC: 20.2,
                latestHumidityPct: 91.0,
                qrCodeID: "QR-DEC-101"
            ),
            GrowProject(
                strainName: "Hericium erinaceus",
                skuCode: "LION-01",
                batchNumber: 102,
                phase: .bulk,
                colonizationPercent: 70.0,
                containerName: "Filterpatch Kweekzak",
                substrateName: "Master's Mix Hardhout",
                latestTempC: 21.5,
                latestHumidityPct: 82.0,
                qrCodeID: "QR-DEC-102"
            )
        ]
    }
    
    static var decoyCultures: [CultureItem] {
        [
            CultureItem(
                strainName: "Pleurotus ostreatus",
                skuCode: "OEST-01",
                cultureType: "Liquid Culture (LC)",
                generation: "T1 (Master)",
                status: "Klaar voor Gebruik",
                qrCodeID: "CULT-DEC-01",
                notes: "4% mout/honing oplossing. Zeer heldere vloeistof met dichte myceliumwolk."
            ),
            CultureItem(
                strainName: "Hericium erinaceus",
                skuCode: "LION-01",
                cultureType: "Agar Petri Schaal",
                generation: "T2",
                status: "Actieve Groei",
                qrCodeID: "CULT-DEC-02",
                notes: "MEA-medium. Mooie zuivere randgroei."
            )
        ]
    }
    
    static var decoyStash: [StashJar] {
        [
            StashJar(
                strainName: "Gedroogde Oesterzwammen",
                skuCode: "OEST-01",
                potencyMultiplier: 0.0,
                availableDryGrams: 145.0,
                storageMethod: "Keukenkast Voorraad",
                qrCodeID: "STASH-DEC-01"
            )
        ]
    }
    
    static var decoySupplies: [LabSupplyItem] {
        [
            LabSupplyItem(
                name: "Tarwestro Pellets",
                category: "Substraat",
                quantity: 15.0,
                unit: "kg",
                minThreshold: 5.0,
                qrCodeID: "SUP-DEC-01"
            ),
            LabSupplyItem(
                name: "Hele Roggekorrels",
                category: "Graan",
                quantity: 20.0,
                unit: "kg",
                minThreshold: 5.0,
                qrCodeID: "SUP-DEC-02"
            )
        ]
    }
}
