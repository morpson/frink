import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

final class ImageCompressor {
    static let shared = ImageCompressor()

    private init() {}

    func compressImage(input: URL, output: URL, options: ImageCompressionOptions) async throws {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil) else {
            throw NSError(domain: "ImageCompressor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read source image."])
        }

        let format = options.format
        let uti = format.uti
        let frameCount = CGImageSourceGetCount(source)

        // If it's a multi-frame image (like animated GIF) and options.preserveAnimation is enabled
        if frameCount > 1 && options.preserveAnimation && (uti == UTType.gif.identifier || uti == UTType.webP.identifier) {
            try compressAnimatedImage(source: source, output: output, uti: uti, options: options)
            return
        }

        // Static image compression
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "ImageCompressor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load image frame."])
        }

        let processedImage: CGImage
        if let maxPixelSize = options.resolution.maxPixelSize(for: image) {
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
                throw NSError(domain: "ImageCompressor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to resize image."])
            }
            processedImage = thumbnail
        } else {
            processedImage = image
        }

        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, uti as CFString, 1, nil) else {
            throw NSError(domain: "ImageCompressor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination."])
        }

        var properties: [CFString: Any] = [:]
        if format.supportsQuality {
            properties[kCGImageDestinationLossyCompressionQuality] = Double(options.quality) / 100.0
        }

        // Copy source metadata if possible
        if let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            for (key, val) in sourceProperties {
                if key != kCGImagePropertyPixelWidth && key != kCGImagePropertyPixelHeight {
                    properties[key] = val
                }
            }
        }

        CGImageDestinationAddImage(destination, processedImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "ImageCompressor", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to write output image."])
        }
    }

    func convertImage(input: URL, output: URL, format: ImageFormat) async throws {
        var options = ImageCompressionOptions()
        options.format = format
        options.quality = 100
        options.resolution = .original
        options.preserveAnimation = true
        try await compressImage(input: input, output: output, options: options)
    }

    private func compressAnimatedImage(source: CGImageSource, output: URL, uti: String, options: ImageCompressionOptions) throws {
        let frameCount = CGImageSourceGetCount(source)
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, uti as CFString, frameCount, nil) else {
            throw NSError(domain: "ImageCompressor", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to create animated image destination."])
        }

        var containerProperties: [CFString: Any] = [:]
        if let sourceContainerProps = CGImageSourceCopyProperties(source, nil) as? [CFString: Any] {
            containerProperties = sourceContainerProps
        }

        CGImageDestinationSetProperties(destination, containerProperties as CFDictionary)

        for i in 0..<frameCount {
            guard let frameImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            
            let processedFrame: CGImage
            if let maxPixelSize = options.resolution.maxPixelSize(for: frameImage) {
                let thumbnailOptions: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]
                if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, i, thumbnailOptions as CFDictionary) {
                    processedFrame = thumbnail
                } else {
                    processedFrame = frameImage
                }
            } else {
                processedFrame = frameImage
            }

            var frameProperties: [CFString: Any] = [:]
            if let sourceFrameProps = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any] {
                frameProperties = sourceFrameProps
            }

            if options.format.supportsQuality {
                frameProperties[kCGImageDestinationLossyCompressionQuality] = Double(options.quality) / 100.0
            }

            CGImageDestinationAddImage(destination, processedFrame, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "ImageCompressor", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to write animated output image."])
        }
    }
}

private extension ImageFormat {
    var uti: String {
        switch self {
        case .jpeg: return UTType.jpeg.identifier
        case .png: return UTType.png.identifier
        case .webp: return UTType.webP.identifier
        case .heic: return UTType.heic.identifier
        case .avif: return "public.avif"
        case .gif: return UTType.gif.identifier
        }
    }

    var supportsQuality: Bool {
        switch self {
        case .jpeg, .webp, .heic, .avif: return true
        case .png, .gif: return false
        }
    }
}

private extension OutputResolution {
    func maxPixelSize(for image: CGImage) -> Int? {
        let width = image.width
        let height = image.height
        let currentMax = max(width, height)

        switch self {
        case .original: return nil
        case .p720: return currentMax > 1280 ? 1280 : nil
        case .p1080: return currentMax > 1920 ? 1920 : nil
        case .p2k: return currentMax > 2560 ? 2560 : nil
        case .p4k: return currentMax > 3840 ? 3840 : nil
        }
    }
}
