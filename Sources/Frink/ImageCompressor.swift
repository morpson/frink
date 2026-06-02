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
            await optimizePostProcess(output: output, options: options)
            return
        }

        // Static image compression
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "ImageCompressor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load image frame."])
        }

        let processedImage: CGImage
        if let maxPixelSize = options.maxPixelSize(for: image) {
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
            if options.stripMetadata {
                // Strip all metadata except orientation to prevent rotation issues
                if let orientation = sourceProperties[kCGImagePropertyOrientation] {
                    properties[kCGImagePropertyOrientation] = orientation
                }
            } else {
                for (key, val) in sourceProperties {
                    if key != kCGImagePropertyPixelWidth && key != kCGImagePropertyPixelHeight {
                        properties[key] = val
                    }
                }
            }
        }

        CGImageDestinationAddImage(destination, processedImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "ImageCompressor", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to write output image."])
        }

        await optimizePostProcess(output: output, options: options)
    }

    func convertImage(input: URL, output: URL, format: ImageFormat) async throws {
        var options = ImageCompressionOptions()
        options.format = format
        options.quality = 100
        options.resolutionLabel = "Original"
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
            if options.stripMetadata {
                // Preserve format-specific animation loop/metadata dictionaries
                let preserveKeys = [
                    kCGImagePropertyGIFDictionary,
                    kCGImagePropertyWebPDictionary,
                    kCGImagePropertyPNGDictionary
                ]
                for key in preserveKeys {
                    if let val = sourceContainerProps[key] {
                        containerProperties[key] = val
                    }
                }
            } else {
                containerProperties = sourceContainerProps
            }
        }

        CGImageDestinationSetProperties(destination, containerProperties as CFDictionary)

        for i in 0..<frameCount {
            guard let frameImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            
            let processedFrame: CGImage
            if let maxPixelSize = options.maxPixelSize(for: frameImage) {
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
                if options.stripMetadata {
                    // Strip except orientation and GIF/WebP frame properties (which contain delay times!)
                    let preserveKeys = [
                        kCGImagePropertyOrientation,
                        kCGImagePropertyGIFDictionary,
                        kCGImagePropertyWebPDictionary,
                        kCGImagePropertyPNGDictionary
                    ]
                    for key in preserveKeys {
                        if let val = sourceFrameProps[key] {
                            frameProperties[key] = val
                        }
                    }
                } else {
                    frameProperties = sourceFrameProps
                }
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

    // MARK: - Post-processing Optimization CLI Tools

    private func findExecutable(_ name: String) -> URL? {
        let paths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]
        let fileManager = FileManager.default
        for path in paths {
            if fileManager.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private func runOptimizer(executable: URL, arguments: [String]) async throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errString = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ImageCompressor.Optimizer", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Optimizer \(executable.lastPathComponent) failed: \(errString)"])
        }
    }

    private func optimizePostProcess(output: URL, options: ImageCompressionOptions) async {
        let pathExtension = output.pathExtension.lowercased()
        
        do {
            if pathExtension == "jpg" || pathExtension == "jpeg" {
                if let jpegoptim = findExecutable("jpegoptim") {
                    var args = ["--max=\(options.quality)"]
                    if options.stripMetadata {
                        args.append("--strip-all")
                    }
                    args.append(output.path)
                    try await runOptimizer(executable: jpegoptim, arguments: args)
                }
            } else if pathExtension == "png" {
                if let pngquant = findExecutable("pngquant") {
                    var args = ["--force", "--ext", ".png", "--quality", "0-\(options.quality)"]
                    if options.stripMetadata {
                        args.append("--strip")
                    }
                    args.append(output.path)
                    do {
                        try await runOptimizer(executable: pngquant, arguments: args)
                    } catch {
                        print("pngquant failed: \(error)")
                    }
                }
                
                if let oxipng = findExecutable("oxipng") {
                    var args = ["-o", "2"]
                    if options.stripMetadata {
                        args += ["--strip", "all"]
                    } else {
                        args += ["--strip", "none"]
                    }
                    args.append(output.path)
                    do {
                        try await runOptimizer(executable: oxipng, arguments: args)
                    } catch {
                        print("oxipng failed: \(error)")
                    }
                }
            } else if pathExtension == "gif" {
                if let gifsicle = findExecutable("gifsicle") {
                    var args = ["-O3", "--batch"]
                    if options.quality < 90 {
                        args.append("--lossy=\(options.quality)")
                    }
                    args.append(output.path)
                    do {
                        try await runOptimizer(executable: gifsicle, arguments: args)
                    } catch {
                        // If lossy optimization failed (unsupported), retry without --lossy
                        if options.quality < 90 {
                            let retryArgs = ["-O3", "--batch", output.path]
                            do {
                                try await runOptimizer(executable: gifsicle, arguments: retryArgs)
                            } catch {
                                print("gifsicle retry failed: \(error)")
                            }
                        } else {
                            print("gifsicle failed: \(error)")
                        }
                    }
                }
            }
        } catch {
            print("Post-processing optimization failed: \(error)")
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

extension ImageCompressionOptions {
    func maxPixelSize(for image: CGImage) -> Int? {
        let width = image.width
        let height = image.height
        let currentMax = max(width, height)

        let targetMax: Int
        if resolutionLabel == "Original" {
            return nil
        } else if resolutionLabel.hasSuffix("px") {
            let digits = resolutionLabel.prefix(while: { $0.isNumber })
            guard let val = Int(digits) else { return nil }
            targetMax = val
        } else {
            // Handle legacy/video suggestion strings
            switch resolutionLabel {
            case "720p": targetMax = 1280
            case "1080p": targetMax = 1920
            case "2K": targetMax = 2560
            case "4K": targetMax = 3840
            default: return nil
            }
        }

        // Only scale down (do not upscale)
        return currentMax > targetMax ? targetMax : nil
    }
}
