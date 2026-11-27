import Combine
//
//  MycoTimelapseVideoExporter.swift
//  MycoLab
//
//  Renders a sequence of timelapse photos into a smooth, high-definition MP4 video
//  with hardware-accelerated H.264 encoding via AVFoundation.
//

import UIKit
import AVFoundation
import Photos
import SwiftUI

// MARK: - Native iOS Share Presenter (AirDrop, Bestanden, Foto's, Berichten)
@MainActor
public enum MycoSharePresenter {
    public static func presentShareSheet(
        items: [Any],
        sourceView: UIView? = nil,
        sourceRect: CGRect? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController, !presented.isBeingDismissed {
            topVC = presented
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Popover configuratie voor iPad en Mac Catalyst (voorkomt crashes)
        if let popover = activityVC.popoverPresentationController {
            if let src = sourceView {
                popover.sourceView = src
                popover.sourceRect = sourceRect ?? src.bounds
            } else {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }

        activityVC.completionWithItemsHandler = { _, _, _, _ in
            completion?()
        }

        topVC.present(activityVC, animated: true)
    }
}

// MARK: - Pi Hub Timelapse Video Model & API Response
public struct PiTimelapseItem: Identifiable, Codable, Hashable {
    public var id: String { filename }
    public let filename: String
    public let size_bytes: Int64
    public let size_mb: Double
    public let created_at: String
    public let download_url: String
}

public struct PiTimelapseListResponse: Codable {
    public let timelapses: [PiTimelapseItem]
    public let count: Int
    public let storage_dir: String?
}

@MainActor
public final class MycoTimelapseVideoExporter: ObservableObject {
    public static let shared = MycoTimelapseVideoExporter()

    @Published public var isExporting: Bool = false
    @Published public var progress: Double = 0.0
    @Published public var statusText: String = ""
    @Published public var exportedVideoURL: URL? = nil
    @Published public var errorMessage: String? = nil
    @Published public var showShareSheet: Bool = false
    @Published public var savedToPhotosSuccessfully: Bool = false
    @Published public var piTimelapses: [PiTimelapseItem] = []
    @Published public var isFetchingPiTimelapses: Bool = false
    @Published public var isUploadingToPi: Bool = false
    @Published public var isDownloadingFromPi: Bool = false
    @Published public var downloadingFilename: String? = nil
    @Published public var uploadSuccessMessage: String? = nil

    private init() {}

    /// Opent direct het vertrouwde iOS deelmenu voor het geëxporteerde videobestand
    public func openShareSheet() {
        guard let url = exportedVideoURL else { return }
        MycoSharePresenter.presentShareSheet(items: [url])
    }

    /// Exporteert een lijst van timelapse foto's naar een vloeiende MP4-video en toont direct het iOS deelmenu
    func exportVideo(
        photos: [TimelapsePhotoItem],
        fps: Int = 24,
        uploadToPi: Bool = true
    ) async -> URL? {
        // Filter alleen items die daadwerkelijk een geldige afbeelding hebben
        let validPairs: [(item: TimelapsePhotoItem, image: UIImage)] = photos
            .sorted(by: { $0.timestamp < $1.timestamp })
            .compactMap { photo in
                if let img = photo.loadImage() {
                    return (photo, img)
                }
                return nil
            }

        guard !validPairs.isEmpty else {
            self.errorMessage = "Geen geldige foto's gevonden om te exporteren."
            return nil
        }

        self.isExporting = true
        self.progress = 0.0
        self.statusText = "Foto's voorbereiden..."
        self.errorMessage = nil
        self.exportedVideoURL = nil
        self.savedToPhotosSuccessfully = false

        let firstImage = validPairs[0].image
        var targetWidth = Int(firstImage.size.width)
        var targetHeight = Int(firstImage.size.height)

        // Schaal naar Full HD (1920x1080) max voor snelle hardware-compressie
        if targetWidth > 1920 || targetHeight > 1080 {
            let scale = min(1920.0 / Double(targetWidth), 1080.0 / Double(targetHeight))
            targetWidth = Int(Double(targetWidth) * scale)
            targetHeight = Int(Double(targetHeight) * scale)
        }
        // Zorg voor even getallen (vereist door H.264 video codec)
        if targetWidth % 2 != 0 { targetWidth -= 1 }
        if targetHeight % 2 != 0 { targetHeight -= 1 }
        targetWidth = max(320, targetWidth)
        targetHeight = max(240, targetHeight)

        let dominantCamType: String = {
            let types = validPairs.map { $0.item.resolvedCameraType }
            if types.allSatisfy({ $0 == "telephoto" }) { return "Sensor_AI_Zoom" }
            if types.allSatisfy({ $0 == "ultraWide" }) { return "Tent_0.5x" }
            if types.allSatisfy({ $0 == "wide" }) { return "Kweek_1.0x" }
            return "MultiCam"
        }()
        let outputFileName = "MycoLab_Timelapse_\(dominantCamType)_\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(outputFileName)
        try? FileManager.default.removeItem(at: outputURL)

        do {
            let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: targetWidth,
                AVVideoHeightKey: targetHeight,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: targetWidth * targetHeight * 4,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]

            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            writerInput.expectsMediaDataInRealTime = false

            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: targetWidth,
                kCVPixelBufferHeightKey as String: targetHeight,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: writerInput,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )

            guard assetWriter.canAdd(writerInput) else {
                self.isExporting = false
                self.errorMessage = "Kan video-invoer niet initialiseren."
                return nil
            }
            assetWriter.add(writerInput)

            guard assetWriter.startWriting() else {
                self.isExporting = false
                self.errorMessage = assetWriter.error?.localizedDescription ?? "Starten van video encoder mislukt."
                return nil
            }

            assetWriter.startSession(atSourceTime: .zero)

            let totalPhotos = validPairs.count
            
            // Adaptieve framerate zodat kortere timelapses minimaal enkele seconden duren
            let framesPerPhoto: Int
            let effectiveFps: Int
            if totalPhotos <= 8 {
                effectiveFps = 6
                framesPerPhoto = 3
            } else if totalPhotos <= 20 {
                effectiveFps = 12
                framesPerPhoto = 2
            } else {
                effectiveFps = fps
                framesPerPhoto = 1
            }

            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(effectiveFps))
            var globalFrameIndex: Int = 0

            for (index, pair) in validPairs.enumerated() {
                self.statusText = "Frame \(index + 1) van \(totalPhotos) coderen..."
                self.progress = Double(index) / Double(totalPhotos)

                if let pixelBuffer = Self.newPixelBufferFrom(image: pair.image, width: targetWidth, height: targetHeight) {
                    for _ in 0..<framesPerPhoto {
                        var attempts = 0
                        while !writerInput.isReadyForMoreMediaData && attempts < 40 {
                            try? await Task.sleep(nanoseconds: 20_000_000)
                            attempts += 1
                        }

                        let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(globalFrameIndex))
                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        globalFrameIndex += 1
                    }
                }

                if index % 5 == 0 {
                    try? await Task.sleep(nanoseconds: 5_000_000)
                }
            }

            self.statusText = "Video afronden en wegschrijven..."
            self.progress = 0.95

            writerInput.markAsFinished()
            await withCheckedContinuation { continuation in
                assetWriter.finishWriting {
                    continuation.resume()
                }
            }

            if assetWriter.status == .completed {
                self.progress = 1.0
                self.statusText = "Klaar! \(totalPhotos) frames geëxporteerd."
                self.exportedVideoURL = outputURL
                self.isExporting = false
                self.showShareSheet = true

                // Upload video automatisch naar Raspberry Pi USB opslag
                // Sla de voltooide MP4 video direct op in het speciale 'MycoLab' album in de Foto's app
                _ = await self.saveVideoToCameraRoll(url: outputURL)

                if uploadToPi {
                    Task {
                        _ = await self.uploadVideoToPi(url: outputURL)
                    }
                }

                // Open direct het vertrouwde iOS Deelmenu (AirDrop, Opslaan in Foto's/Bestanden, etc.)
                MycoSharePresenter.presentShareSheet(items: [outputURL])
                return outputURL
            } else {
                self.isExporting = false
                self.errorMessage = assetWriter.error?.localizedDescription ?? "Coderen van video mislukt."
                return nil
            }
        } catch {
            self.isExporting = false
            self.errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Slaat de zojuist geëxporteerde MP4 video direct op in het speciale 'MycoLab' album in de Foto's app van de gebruiker.
    public func saveVideoToCameraRoll(url: URL) async -> Bool {
        let success = await MycoPhotoLibraryHelper.saveVideoToAlbum(url: url)
        if success {
            self.savedToPhotosSuccessfully = true
            self.statusText = "MP4 video opgeslagen in album 'MycoLabs'!"
            return true
        } else {
            self.errorMessage = "Geen toegang tot Foto's galerij verleend of opslaan mislukt."
            return false
        }
    }

    /// Helper om een UIImage om te zetten naar een CVPixelBuffer voor AVAssetWriter.
    private static func newPixelBufferFrom(image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer? = nil
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        // Schaal en teken de afbeelding gecentreerd in het kader
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            UIGraphicsPushContext(context)
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            UIGraphicsPopContext()
        }

        return buffer
    }

    // MARK: - Raspberry Pi Hub Timelapse Video Sync & Storage
    
    /// Uploadt een complete geexporteerde MP4 timelapse video rechtstreeks naar de Raspberry Pi Hub USB opslag
    public func uploadVideoToPi(url: URL) async -> Bool {
        guard let store = MycoStore.shared else { return false }
        let ip = store.db.environmentConfig.effectivePiHubIP
        let port = store.db.environmentConfig.effectivePiHubPort
        guard !ip.isEmpty else {
            print("[MycoTimelapseVideoExporter] Pi Hub IP niet geconfigureerd.")
            return false
        }
        
        guard let endpoint = URL(string: "http://\(ip):\(port)/timelapse/upload") else { return false }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        do {
            let fileData = try Data(contentsOf: url)
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(url.lastPathComponent)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            self.isUploadingToPi = true
            self.statusText = "Opslaan op Pi Hub USB (\(String(format: "%.1f", Double(fileData.count) / (1024 * 1024))) MB)..."
            
            let (_, response) = try await URLSession.shared.upload(for: request, from: body)
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                self.isUploadingToPi = false
                self.uploadSuccessMessage = "Video succesvol bewaard op Pi Hub USB!"
                self.statusText = "Bewaard op Pi Hub!"
                await fetchPiTimelapses()
                return true
            } else {
                self.isUploadingToPi = false
                let code = (response as? HTTPURLResponse)?.statusCode ?? 500
                self.errorMessage = "Pi Hub opslag fout (HTTP \(code))"
                return false
            }
        } catch {
            self.isUploadingToPi = false
            self.errorMessage = "Uploaden naar Pi mislukt: \(error.localizedDescription)"
            return false
        }
    }

    /// Haalt de lijst van alle voltooide MP4 timelapse video's op die bewaard zijn op de Raspberry Pi Hub
    public func fetchPiTimelapses() async {
        guard let store = MycoStore.shared else { return }
        let ip = store.db.environmentConfig.effectivePiHubIP
        let port = store.db.environmentConfig.effectivePiHubPort
        guard !ip.isEmpty, let endpoint = URL(string: "http://\(ip):\(port)/timelapse/list") else { return }
        
        self.isFetchingPiTimelapses = true
        defer { self.isFetchingPiTimelapses = false }
        
        do {
            var req = URLRequest(url: endpoint)
            req.timeoutInterval = 8
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return }
            let result = try JSONDecoder().decode(PiTimelapseListResponse.self, from: data)
            self.piTimelapses = result.timelapses
        } catch {
            print("[MycoTimelapseVideoExporter] Fout bij ophalen Pi timelapses: \(error.localizedDescription)")
        }
    }

    /// Downloadt een timelapse video van de Pi Hub rechtstreeks naar de iPhone Foto's galerij en opent het deelmenu
    public func downloadAndSaveToPhotos(item: PiTimelapseItem) async -> Bool {
        guard let store = MycoStore.shared else { return false }
        let ip = store.db.environmentConfig.effectivePiHubIP
        let port = store.db.environmentConfig.effectivePiHubPort
        guard let url = URL(string: "http://\(ip):\(port)\(item.download_url)") else { return false }
        
        self.isDownloadingFromPi = true
        self.downloadingFilename = item.filename
        self.statusText = "Downloaden van Pi Hub (\(item.size_mb) MB)..."
        defer {
            self.isDownloadingFromPi = false
            self.downloadingFilename = nil
        }
        
        do {
            let (tempLocalURL, _) = try await URLSession.shared.download(from: url)
            let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(item.filename)
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: tempLocalURL, to: destURL)
            
            let saved = await saveVideoToCameraRoll(url: destURL)
            self.exportedVideoURL = destURL
            MycoSharePresenter.presentShareSheet(items: [destURL])
            return saved
        } catch {
            self.errorMessage = "Downloaden van Pi mislukt: \(error.localizedDescription)"
            return false
        }
    }

    /// Verwijdert een timelapse video permanent van de Pi Hub
    public func deletePiTimelapse(filename: String) async -> Bool {
        guard let store = MycoStore.shared else { return false }
        let ip = store.db.environmentConfig.effectivePiHubIP
        let port = store.db.environmentConfig.effectivePiHubPort
        guard !ip.isEmpty, let url = URL(string: "http://\(ip):\(port)/timelapse/\(filename)") else { return false }
        
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                await fetchPiTimelapses()
                return true
            }
            return false
        } catch {
            return false
        }
    }
}

// MARK: - Dedicated MycoLab Photo Library Album Helper
public enum MycoPhotoLibraryHelper {
    public static let albumName = "MycoLabs"

    /// Zoekt het 'MycoLab' album op of maakt dit veilig aan in de iOS Foto's app
    public static func getOrCreateAlbum() async -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        if let first = collections.firstObject {
            return first
        }

        var albumPlaceholder: PHObjectPlaceholder?
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
                albumPlaceholder = createRequest.placeholderForCreatedAssetCollection
            }
        } catch {
            print("[MycoPhotoLibraryHelper] Kon album niet aanmaken: \(error)")
            return nil
        }

        if let placeholder = albumPlaceholder {
            let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
            return fetchResult.firstObject
        }
        return nil
    }

    /// Slaat een MP4 timelapse videobestand op in het 'MycoLab' album in de Foto's app
    public static func saveVideoToAlbum(url: URL) async -> Bool {
        let auth = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard auth == .authorized || auth == .limited else {
            print("[MycoPhotoLibraryHelper] Toegang tot Foto's geweigerd: \(auth)")
            return false
        }

        let album = await getOrCreateAlbum()

        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url),
                      let placeholder = assetRequest.placeholderForCreatedAsset else { return }
                if let targetAlbum = album {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: targetAlbum)
                    albumChangeRequest?.addAssets([placeholder] as NSArray)
                }
            }
            return true
        } catch {
            print("[MycoPhotoLibraryHelper] Fout bij opslaan MP4 video: \(error)")
            return false
        }
    }

    /// Slaat een afbeelding op in het 'MycoLab' album (alleen bij expliciete handmatige export)
    public static func saveImageToAlbum(_ image: UIImage) async -> Bool {
        let auth = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard auth == .authorized || auth == .limited else {
            print("[MycoPhotoLibraryHelper] Toegang tot Foto's geweigerd: \(auth)")
            return false
        }

        let album = await getOrCreateAlbum()

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let assetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                guard let placeholder = assetRequest.placeholderForCreatedAsset else { return }
                if let targetAlbum = album {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: targetAlbum)
                    albumChangeRequest?.addAssets([placeholder] as NSArray)
                }
            }
            return true
        } catch {
            print("[MycoPhotoLibraryHelper] Fout bij opslaan foto: \(error)")
            return false
        }
    }
}
