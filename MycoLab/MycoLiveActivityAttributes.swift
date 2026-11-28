//
//  MycoLiveActivityAttributes.swift
//  MycoLab
//
//  Shared ActivityKit attributes for Dynamic Island & Lock Screen Live Activities.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
nonisolated public struct MycoLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var tempC: Double
        public var humidityPct: Double
        public var vpdKpa: Double
        public var statusSummary: String
        public var activeDeviceSummary: String
        public var timerTitle: String?
        public var timerEndDate: Date?
        
        public init(
            tempC: Double = 23.5,
            humidityPct: Double = 90.0,
            vpdKpa: Double = 0.28,
            statusSummary: String = "Optimaal Kweekklimaat",
            activeDeviceSummary: String = "Apparaten Standby",
            timerTitle: String? = nil,
            timerEndDate: Date? = nil
        ) {
            self.tempC = tempC
            self.humidityPct = humidityPct
            self.vpdKpa = vpdKpa
            self.statusSummary = statusSummary
            self.activeDeviceSummary = activeDeviceSummary
            self.timerTitle = timerTitle
            self.timerEndDate = timerEndDate
        }
    }

    public var batchName: String
    public var phaseName: String
    public var dayCount: Int

    public init(batchName: String, phaseName: String, dayCount: Int) {
        self.batchName = batchName
        self.phaseName = phaseName
        self.dayCount = dayCount
    }
}
#else
public struct MycoLiveActivityAttributes: Codable, Hashable {
    public struct ContentState: Codable, Hashable {
        public var tempC: Double
        public var humidityPct: Double
        public var vpdKpa: Double
        public var statusSummary: String
        public var activeDeviceSummary: String
        public var timerTitle: String?
        public var timerEndDate: Date?
        
        public init(
            tempC: Double = 23.5,
            humidityPct: Double = 90.0,
            vpdKpa: Double = 0.28,
            statusSummary: String = "Optimaal Kweekklimaat",
            activeDeviceSummary: String = "Apparaten Standby",
            timerTitle: String? = nil,
            timerEndDate: Date? = nil
        ) {
            self.tempC = tempC
            self.humidityPct = humidityPct
            self.vpdKpa = vpdKpa
            self.statusSummary = statusSummary
            self.activeDeviceSummary = activeDeviceSummary
            self.timerTitle = timerTitle
            self.timerEndDate = timerEndDate
        }
    }

    public var batchName: String
    public var phaseName: String
    public var dayCount: Int

    public init(batchName: String, phaseName: String, dayCount: Int) {
        self.batchName = batchName
        self.phaseName = phaseName
        self.dayCount = dayCount
    }
}
#endif
