//
//  MycoImageHelper.swift
//  MycoLab
//
//  Provides image downscaling and compression utilities to prevent
//  excessive database bloat and memory pressure.
//

import UIKit

public enum MycoImageHelper {
    /// Resizes an image so that its longest edge is at most maxDimension,
    /// and compresses it as JPEG.
    public static func prepareForStorage(
        data: Data,
        maxDimension: CGFloat = 1200,
        compressionQuality: CGFloat = 0.6
    ) -> Data? {
        guard let source = UIImage(data: data) else { return nil }

        let size = source.size
        let maxSide = max(size.width, size.height)

        let targetImage: UIImage
        if maxSide > maxDimension {
            let scale = maxDimension / maxSide
            let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            targetImage = renderer.image { _ in
                source.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            targetImage = source
        }

        return targetImage.jpegData(compressionQuality: compressionQuality)
    }

    /// Prepares a UIImage directly for storage
    public static func prepareForStorage(
        image: UIImage,
        maxDimension: CGFloat = 1200,
        compressionQuality: CGFloat = 0.6
    ) -> Data? {
        let size = image.size
        let maxSide = max(size.width, size.height)

        let targetImage: UIImage
        if maxSide > maxDimension {
            let scale = maxDimension / maxSide
            let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            targetImage = image
        }

        return targetImage.jpegData(compressionQuality: compressionQuality)
    }
}
