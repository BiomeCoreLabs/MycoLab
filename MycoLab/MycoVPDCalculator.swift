//
//  MycoVPDCalculator.swift
//  MycoLab
//
//  Psychrometric calculation engine for Mushroom Cultivation:
//  - VPD (Vapor Pressure Deficit) in kiloPascals (kPa)
//  - Dew Point (°C) via Magnus-Tetens approximation
//  - Mycological Growth Zone Classification & Targeted Advice
//

import Foundation
import SwiftUI

public struct VPDAnalysisResult: Sendable {
    public let vpdKPa: Double
    public let dewPointC: Double
    public let saturationVaporPressureKPa: Double
    public let actualVaporPressureKPa: Double
    public let zone: MycoVPDZone
    public let titleNL: String
    public let titleEN: String
    public let summaryNL: String
    public let summaryEN: String
    public let detailedAdviceNL: String
    public let detailedAdviceEN: String
    public let color: Color
    public let icon: String
}

public enum MycoVPDZone: String, Sendable {
    case saturatedOrCondensing // < 0.10 kPa
    case idealFruiting         // 0.10 ... 0.35 kPa
    case incubationAndGrowth   // 0.35 ... 0.60 kPa
    case criticallyDry         // > 0.60 kPa
}

public enum MycoVPDCalculator {
    /// Computes full psychrometric profile from Temperature (°C) and Relative Humidity (% RV)
    public static func analyze(tempC: Double?, humidityPct: Double?, environment: String = "growTent") -> VPDAnalysisResult? {
        guard let t = tempC, let rh = humidityPct, t > -10.0, t < 50.0, rh >= 5.0, rh <= 100.0 else {
            return nil
        }
        
        // 1. Saturation Vapor Pressure (VP_sat) using Tetens equation (in kPa)
        // VP_sat = 0.61078 * exp((17.27 * T) / (T + 237.3))
        let vpSat = 0.61078 * exp((17.27 * t) / (t + 237.3))
        
        // 2. Actual Vapor Pressure (VP_act) in kPa
        let clampedRH = min(max(rh, 5.0), 100.0)
        let vpAct = vpSat * (clampedRH / 100.0)
        
        // 3. Vapor Pressure Deficit (VPD) in kPa
        let vpd = max(0.0, vpSat - vpAct)
        
        // 4. Dew Point via Magnus formula
        let alpha = ((17.27 * t) / (t + 237.3)) + log(clampedRH / 100.0)
        let dewPoint = (237.3 * alpha) / (17.27 - alpha)
        
        let zone: MycoVPDZone
        let titleNL: String
        let titleEN: String
        let summaryNL: String
        let summaryEN: String
        let detailedAdviceNL: String
        let detailedAdviceEN: String
        let color: Color
        let icon: String
        
        let isTent = (environment == "growTent" || environment == "tent" || environment == "Marthakast / Monotub Tent")
        
        if vpd < 0.10 {
            zone = .saturatedOrCondensing
            if isTent {
                titleNL = "Ideaal Tentklimaat (Actieve Nevel)"
                titleEN = "Ideal Tent Climate (Active Fog)"
                summaryNL = "Hoge tent-RV met actieve FAE • Uitstekende hydratatie"
                summaryEN = "High tent RH with active FAE • Optimal hydration"
                detailedAdviceNL = "VPD is \(String(format: "%.2f", vpd)) kPa bij een RV van \(Int(clampedRH))%. In een kweektent met afzuiging (FAE) is een lage VPD normaal en gewenst voor soorten zoals Oesterzwammen, Lion's Mane en Shiitake. De actieve luchtstroom van de afzuigventilator zorgt voor gezonde kinetische verdamping en voorkomt dat condenswater stilstaat op de hoeden."
                detailedAdviceEN = "VPD is \(String(format: "%.2f", vpd)) kPa at \(Int(clampedRH))% RH. In a grow tent with active FAE, low VPD is standard and beneficial for species like Oyster, Lion's Mane, and Shiitake. Continuous air exchange ensures healthy kinetic evaporation while keeping caps moist."
                color = MycoTheme.green
                icon = "cloud.fog.fill"
            } else {
                titleNL = "Verzadigd / Condensatie (Bakkweek)"
                titleEN = "Saturated / Condensing (Tub)"
                summaryNL = "Geen verdamping • Risico op bacteriële vlekken"
                summaryEN = "Zero evaporation • Risk of bacterial blotch"
                detailedAdviceNL = "VPD is lager dan 0.10 kPa. De lucht in de bak kan vrijwel geen water meer opnemen. Er vindt nauwelijks evaporatie plaats vanaf het mycelium, waardoor pinhead-inductie vertraagt. Verhoog de FAE-ventilatie of zet het deksel op een kiertje."
                detailedAdviceEN = "VPD is under 0.10 kPa. Tub air is fully saturated. Increase fresh air exchange (FAE) or crack the tub lid."
                color = Color.cyan
                icon = "drop.degreesign.fill"
            }
        } else if vpd <= 0.35 {
            zone = .idealFruiting
            titleNL = "Ideale Fruiting Zone"
            titleEN = "Ideal Fruiting Zone"
            summaryNL = "Optimale verdamping • Perfect voor pinheads & paddestoelen"
            summaryEN = "Optimal evaporation • Perfect for pins & flushes"
            detailedAdviceNL = "VPD ligt in de gouden mycologische zone (0.10 - 0.35 kPa). Er is precies voldoende evaporatiedruk om voedingsstoffen naar de vruchtlichamen te transporteren en pinheads te triggeren, zonder dat het substraat uitdroogt. Behoud deze balans!"
            detailedAdviceEN = "VPD is in the golden mycological zone (0.10 - 0.35 kPa). There is balanced evaporative pull to trigger pinheads and transport nutrients without dehydrating substrate or caps. Keep this state steady!"
            color = MycoTheme.green
            icon = "checkmark.seal.fill"
        } else if vpd <= 0.60 {
            zone = .incubationAndGrowth
            titleNL = "Incubatie / Milde Verdamping"
            titleEN = "Incubation / Mild Evaporation"
            summaryNL = "Prima voor afgesloten potten & zakken, te droog voor open pinnen"
            summaryEN = "Good for sealed spawn & jars, too dry for open pinning"
            detailedAdviceNL = "VPD ligt tussen 0.35 en 0.60 kPa. Dit is prima tijdens de incubatie van gesloten spawn-potten of zolang de bak nog dicht gekoloniseerd wordt. Voor een open fruiting tub droogt de toplaag te snel uit. Verhoog de luchtvochtigheid naar 90-95%."
            detailedAdviceEN = "VPD is between 0.35 and 0.60 kPa. Safe for sealed grain spawn or colonization jars. For open fruiting tubs, surface moisture will deplete too fast. Increase humidity to 90-95%."
            color = MycoTheme.amber
            icon = "exclamationmark.triangle.fill"
        } else {
            zone = .criticallyDry
            titleNL = "Kritiek Droog"
            titleEN = "Critically Dry"
            summaryNL = "Hoge uitdroging • Abortgevaar voor primordia"
            summaryEN = "High dehydration • High risk of aborts"
            detailedAdviceNL = "VPD is hoger dan 0.60 kPa. De lucht onttrekt te agressief water aan het mycelium en de caps. Pins zullen verdrogen en aborteren. Bevochtig direct de bak of tent en controleer de werking van de Tuya bevochtiger."
            detailedAdviceEN = "VPD is above 0.60 kPa. Ambient air is aggressively pulling water out of the mycelium. Primordia will abort and caps will crack. Mist or turn on your humidifier immediately."
            color = MycoTheme.red
            icon = "flame.fill"
        }
        
        return VPDAnalysisResult(
            vpdKPa: vpd,
            dewPointC: dewPoint,
            saturationVaporPressureKPa: vpSat,
            actualVaporPressureKPa: vpAct,
            zone: zone,
            titleNL: titleNL,
            titleEN: titleEN,
            summaryNL: summaryNL,
            summaryEN: summaryEN,
            detailedAdviceNL: detailedAdviceNL,
            detailedAdviceEN: detailedAdviceEN,
            color: color,
            icon: icon
        )
    }
}
