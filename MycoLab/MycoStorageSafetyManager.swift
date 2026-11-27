//
//  MycoStorageSafetyManager.swift
//  MycoLab
//
//  Created for 24/7 Tripod Camera Flash Memory & Storage Protection.
//  Prevents disk saturation from thousands of timelapse frames.
//

import Foundation
import UIKit
import Combine

@MainActor
public final class MycoStorageSafetyManager: ObservableObject {
    public static let shared = MycoStorageSafetyManager()
    
    @Published public var freeDiskSpaceBytes: Int64 = 0
    @Published public var totalDiskSpaceBytes: Int64 = 0
    @Published public var timelapsePhotosStorageBytes: Int64 = 0
    @Published public var timelapsePhotosCount: Int = 0
    @Published public var isLowStorage: Bool = false      // < 2.5 GB free
    @Published public var isCriticalStorage: Bool = false // < 1.0 GB free
    @Published public var storageAlertMessage: String? = nil
    
    private var monitorTimer: AnyCancellable? = nil
    
    private init() {
        refreshStorageMetrics()
        startPeriodicMonitoring()
    }
    
    public func startPeriodicMonitoring() {
        monitorTimer?.cancel()
        monitorTimer = Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshStorageMetrics()
            }
    }
    
    public func refreshStorageMetrics() {
        let (freeBytes, totalBytes) = Self.calculateDeviceStorage()
        self.freeDiskSpaceBytes = freeBytes
        self.totalDiskSpaceBytes = totalBytes
        
        let (photoBytes, photoCount) = Self.calculateTimelapseFolderUsage()
        self.timelapsePhotosStorageBytes = photoBytes
        self.timelapsePhotosCount = photoCount
        
        let freeGB = Double(freeBytes) / 1_073_741_824.0
        self.isLowStorage = freeGB < 2.5
        self.isCriticalStorage = freeGB < 1.0
        
        if self.isCriticalStorage {
            self.storageAlertMessage = "🚨 Kritiek: Nog maar \(String(format: "%.1f", freeGB)) GB opslag vrij op de iPhone! Timelapse gepauzeerd om iOS vastlopen te voorkomen."
        } else if self.isLowStorage {
            self.storageAlertMessage = "⚠️ Weinig opslagruimte: \(String(format: "%.1f", freeGB)) GB vrij. Overweeg timelapse foto's op te ruimen."
        } else {
            self.storageAlertMessage = nil
        }
    }
    
    public var recommendedJpegCompressionQuality: CGFloat {
        if isCriticalStorage { return 0.55 }
        if isLowStorage { return 0.70 }
        return 0.82
    }
    
    public static func calculateDeviceStorage() -> (free: Int64, total: Int64) {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            let total = Int64(values.volumeTotalCapacity ?? 0)
            return (free, total)
        } catch {
            return (0, 0)
        }
    }
    
    public static func calculateTimelapseFolderUsage() -> (bytes: Int64, count: Int) {
        let dir = TimelapsePhotoItem.storageDirectoryURL
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) else {
            return (0, 0)
        }
        var totalBytes: Int64 = 0
        var count = 0
        for file in files {
            let ext = file.pathExtension.lowercased()
            if ext == "jpg" || ext == "jpeg" {
                count += 1
                if let vals = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = vals.fileSize {
                    totalBytes += Int64(size)
                }
            }
        }
        return (totalBytes, count)
    }
    
    public func clearAllRawTimelapsePhotos() -> (deletedCount: Int, freedBytes: Int64) {
        let dir = TimelapsePhotoItem.storageDirectoryURL
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) else {
            return (0, 0)
        }
        var freed: Int64 = 0
        var count = 0
        for file in files {
            let ext = file.pathExtension.lowercased()
            if ext == "jpg" || ext == "jpeg" {
                if let vals = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = vals.fileSize {
                    freed += Int64(size)
                }
                try? FileManager.default.removeItem(at: file)
                count += 1
            }
        }
        refreshStorageMetrics()
        return (count, freed)
    }
    
    public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
