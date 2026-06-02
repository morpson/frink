import Foundation

struct MediaProgress {
    var percent: Double
    var eta: TimeInterval?
    var message: String
}

enum FFmpegError: LocalizedError {
    case executableNotFound
    case failed(status: Int32, output: String)
    case outputLargerThanInput(inputBytes: Int64, outputBytes: Int64)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "FFmpeg was not found. Install it with Homebrew or bundle it with Frink."
        case let .failed(status, output):
            return "FFmpeg exited with status \(status): \(output)"
        case let .outputLargerThanInput(inputBytes, outputBytes):
            return "Compressed output was larger than the original (\(outputBytes) bytes vs \(inputBytes) bytes)."
        }
    }
}

final class FFmpegManager {
    static let shared = FFmpegManager()

    private let executableURL: URL?

    private init() {
        executableURL = FFmpegManager.findExecutable()
    }

    func run(
        _ job: FFmpegJob,
        progressHandler: ((MediaProgress) -> Void)? = nil
    ) async throws -> String {
        guard let executableURL else {
            throw FFmpegError.executableNotFound
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = job.arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        let parser = FFmpegProgressParser(duration: job.expectedDuration)
        let outputBuffer = LockedOutputBuffer()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            guard let chunk = String(data: handle.availableData, encoding: .utf8), !chunk.isEmpty else { return }
            outputBuffer.append(chunk)
            if let progress = parser.parse(chunk) {
                progressHandler?(progress)
            }
        }

        try process.run()
        process.waitUntilExit()
        outputPipe.fileHandleForReading.readabilityHandler = nil
        let collectedOutput = outputBuffer.value

        if process.terminationStatus != 0 {
            throw FFmpegError.failed(status: process.terminationStatus, output: collectedOutput)
        }

        if job.keepOriginalIfOutputIsLarger {
            try preserveOriginalWhenOutputIsLarger(input: job.inputURL, output: job.outputURL)
        }

        return collectedOutput
    }

    func compressVideo(input: URL, output: URL, options: VideoCompressionOptions) async throws {
        _ = try await run(.videoCompression(input: input, output: output, options: options))
    }

    func convertVideo(input: URL, output: URL, options: VideoConversionOptions) async throws {
        _ = try await run(.videoConversion(input: input, output: output, options: options))
    }

    func convertVideoToAnimation(input: URL, output: URL, options: AnimationOptions) async throws {
        _ = try await run(.videoAnimation(input: input, output: output, options: options))
    }

    func extractAudio(input: URL, output: URL, format: AudioFormat) async throws {
        _ = try await run(.extractAudio(input: input, output: output, format: format))
    }

    func compressImage(input: URL, output: URL, options: ImageCompressionOptions) async throws {
        try await ImageCompressor.shared.compressImage(input: input, output: output, options: options)
    }

    func convertImage(input: URL, output: URL, format: ImageFormat) async throws {
        try await ImageCompressor.shared.convertImage(input: input, output: output, format: format)
    }

    func compressAudio(input: URL, output: URL, options: AudioCompressionOptions) async throws {
        _ = try await run(.audioCompression(input: input, output: output, options: options))
    }

    func convertAudio(input: URL, output: URL, format: AudioFormat) async throws {
        _ = try await run(.audioConversion(input: input, output: output, format: format))
    }

    func applyAudioEffects(input: URL, output: URL, effects: [AudioFilter]) async throws {
        _ = try await run(.audioEffects(input: input, output: output, effects: effects))
    }

    func applyAudioEffectsToVideo(input: URL, output: URL, effects: [AudioFilter]) async throws {
        _ = try await run(.videoAudioEffects(input: input, output: output, effects: effects))
    }

    private func preserveOriginalWhenOutputIsLarger(input: URL, output: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: input.path), fileManager.fileExists(atPath: output.path) else { return }

        let inputBytes = try fileManager.attributesOfItem(atPath: input.path)[.size] as? Int64 ?? 0
        let outputBytes = try fileManager.attributesOfItem(atPath: output.path)[.size] as? Int64 ?? 0
        if outputBytes > inputBytes {
            try? fileManager.removeItem(at: output)
            throw FFmpegError.outputLargerThanInput(inputBytes: inputBytes, outputBytes: outputBytes)
        }
    }

    private static func findExecutable() -> URL? {
        if let bundledURL = Bundle.main.url(forResource: "ffmpeg", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundledURL.path) {
            return bundledURL
        }

        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}

struct FFmpegJob {
    let inputURL: URL
    let outputURL: URL
    let arguments: [String]
    let expectedDuration: TimeInterval?
    let keepOriginalIfOutputIsLarger: Bool

    static func videoCompression(input: URL, output: URL, options: VideoCompressionOptions, expectedDuration: TimeInterval? = nil) -> FFmpegJob {
        var args = ["-y", "-hide_banner", "-i", input.path]

        var filters: [String] = []
        if let scaleFilter = options.resolution.scaleFilter {
            filters.append(scaleFilter)
        }
        if let frameRate = options.frameRate {
            filters.append("fps=fps=\(frameRate)")
        }
        if !filters.isEmpty {
            args += ["-vf", filters.joined(separator: ",")]
        }

        let encoder = options.codec.encoderName
        args += ["-c:v", encoder]

        if encoder.contains("videotoolbox") {
            args += [
                "-b:v", "\(options.bitrateKbps)k",
                "-maxrate", "\(options.bitrateKbps)k",
                "-allow_sw", "1"
            ]
        } else {
            args += [
                "-b:v", "\(options.bitrateKbps)k",
                "-maxrate", "\(options.bitrateKbps)k",
                "-bufsize", "\(options.bitrateKbps * 2)k"
            ]
        }

        args += [
            "-c:a", "copy",
            "-movflags", "+faststart",
            output.path
        ]

        return FFmpegJob(inputURL: input, outputURL: output, arguments: args, expectedDuration: expectedDuration, keepOriginalIfOutputIsLarger: true)
    }

    static func videoConversion(input: URL, output: URL, options: VideoConversionOptions, expectedDuration: TimeInterval? = nil) -> FFmpegJob {
        let outputExtension = output.pathExtension.lowercased()
        var args = ["-y", "-hide_banner", "-i", input.path]

        if options.losslessWhenPossible && ["mp4", "mov", "m4v"].contains(outputExtension) {
            args += ["-map", "0", "-c", "copy", "-movflags", "+faststart", output.path]
        } else {
            let codec = outputExtension == "webm" ? "libvpx-vp9" : options.codec.encoderName
            args += ["-c:v", codec]
            if codec.contains("videotoolbox") {
                args += ["-allow_sw", "1", "-b:v", "0"]
            } else if codec == "libx264" {
                args += ["-crf", "23"]
            } else if codec == "libx265" {
                args += ["-crf", "28"]
            } else if codec == "libvpx-vp9" {
                args += ["-crf", "30", "-b:v", "0"]
            } else {
                args += ["-b:v", "0"]
            }

            if outputExtension == "webm" {
                args += ["-c:a", "libopus"]
            } else {
                args += ["-c:a", "copy", "-movflags", "+faststart"]
            }
            args.append(output.path)
        }

        return FFmpegJob(inputURL: input, outputURL: output, arguments: args, expectedDuration: expectedDuration, keepOriginalIfOutputIsLarger: false)
    }

    static func videoAnimation(input: URL, output: URL, options: AnimationOptions, expectedDuration: TimeInterval? = nil) -> FFmpegJob {
        let extensionName = output.pathExtension.lowercased()
        var args = ["-y", "-hide_banner", "-i", input.path, "-an", "-vf", "fps=\(options.frameRate),scale=\(options.maxWidth):-1:flags=lanczos"]

        switch extensionName {
        case "avif":
            args += ["-c:v", "libaom-av1", "-crf", "\(options.avifCRF)", "-cpu-used", "6"]
        case "webp":
            args += ["-c:v", "libwebp", "-quality", "\(options.quality)", "-loop", "0", "-preset", "picture"]
        default:
            args += ["-loop", "0"]
        }

        args.append(output.path)
        return FFmpegJob(inputURL: input, outputURL: output, arguments: args, expectedDuration: expectedDuration, keepOriginalIfOutputIsLarger: false)
    }

    static func videoAudioEffects(input: URL, output: URL, effects: [AudioFilter], expectedDuration: TimeInterval? = nil) -> FFmpegJob {
        var args = ["-y", "-hide_banner", "-i", input.path, "-map", "0", "-c:v", "copy", "-c:s", "copy"]
        if !effects.isEmpty {
            args += ["-af", effects.map(\.ffmpegFilter).joined(separator: ",")]
        }

        let audioCodec = output.pathExtension.lowercased() == "webm" ? "libopus" : "aac"
        args += ["-c:a", audioCodec, "-b:a", "192k"]
        if ["mp4", "mov", "m4v"].contains(output.pathExtension.lowercased()) {
            args += ["-movflags", "+faststart"]
        }
        args.append(output.path)

        return FFmpegJob(inputURL: input, outputURL: output, arguments: args, expectedDuration: expectedDuration, keepOriginalIfOutputIsLarger: false)
    }

    static func extractAudio(input: URL, output: URL, format: AudioFormat, expectedDuration: TimeInterval? = nil) -> FFmpegJob {
        let args = ["-y", "-hide_banner", "-i", input.path, "-vn"] + format.encodingArguments + [output.path]
        return FFmpegJob(inputURL: input, outputURL: output, arguments: args, expectedDuration: expectedDuration, keepOriginalIfOutputIsLarger: false)
    }

    static func imageCompression(input: URL, output: URL, options: ImageCompressionOptions) -> FFmpegJob {
        var args = ["-y", "-hide_banner", "-i", input.path]
        if let scaleFilter = options.resolution.scaleFilter {
            args += ["-vf", scaleFilter]
        }
        args += options.format.compressionArguments(quality: options.quality)
        args.append(output.path)
        return FFmpegJob(inputURL: input, outputURL: output, arguments: args, expectedDuration: nil, keepOriginalIfOutputIsLarger: true)
    }

    static func imageConversion(input: URL, output: URL, format: ImageFormat) -> FFmpegJob {
        let args = ["-y", "-hide_banner", "-i", input.path] + format.conversionArguments + [output.path]
        return FFmpegJob(inputURL: input, outputURL: output, arguments: args, expectedDuration: nil, keepOriginalIfOutputIsLarger: false)
    }

    static func audioCompression(input: URL, output: URL, options: AudioCompressionOptions, expectedDuration: TimeInterval? = nil) -> FFmpegJob {
        var args = ["-y", "-hide_banner", "-i", input.path, "-vn"]
        args += ["-b:a", "\(options.bitrateKbps)k", "-ar", "\(options.sampleRateHz)", "-ac", "\(options.channels.rawValue)"]
        args += options.format.encodingArguments
        args.append(output.path)
        return FFmpegJob(inputURL: input, outputURL: output, arguments: args, expectedDuration: expectedDuration, keepOriginalIfOutputIsLarger: true)
    }

    static func audioConversion(input: URL, output: URL, format: AudioFormat, expectedDuration: TimeInterval? = nil) -> FFmpegJob {
        let args = ["-y", "-hide_banner", "-i", input.path, "-vn"] + format.conversionArguments + [output.path]
        return FFmpegJob(inputURL: input, outputURL: output, arguments: args, expectedDuration: expectedDuration, keepOriginalIfOutputIsLarger: false)
    }

    static func audioEffects(input: URL, output: URL, effects: [AudioFilter], expectedDuration: TimeInterval? = nil) -> FFmpegJob {
        var args = ["-y", "-hide_banner", "-i", input.path, "-vn"]
        if !effects.isEmpty {
            args += ["-af", effects.map(\.ffmpegFilter).joined(separator: ",")]
        }
        args += ["-c:a", output.pathExtension.lowercased() == "wav" ? "pcm_s16le" : "aac", output.path]
        return FFmpegJob(inputURL: input, outputURL: output, arguments: args, expectedDuration: expectedDuration, keepOriginalIfOutputIsLarger: false)
    }
}

struct VideoCompressionOptions {
    var resolution: OutputResolution = .p1080
    var frameRate: Double? = 30
    var bitrateMode: BitrateMode = .auto
    var customBitrateKbps: Int = 8000
    var codec: VideoCodec = .h264

    var bitrateKbps: Int {
        switch bitrateMode {
        case .custom:
            return min(max(customBitrateKbps, 500), 15_000)
        case .auto:
            return resolution.defaultVideoBitrateKbps
        }
    }
}

struct VideoConversionOptions {
    var codec: VideoCodec = .h264
    var losslessWhenPossible = true
}

struct AnimationOptions {
    var frameRate = 15
    var maxWidth = 1280
    var quality = 82
    var avifCRF = 34
}

struct ImageCompressionOptions {
    var resolution: OutputResolution = .original
    var resolutionLabel: String = "Original"
    var quality = 82
    var format: ImageFormat = .jpeg
    var preserveAnimation = true
    var stripMetadata = true
}

struct AudioCompressionOptions {
    var bitrateKbps = 160
    var sampleRateHz = 44_100
    var channels: AudioChannels = .stereo
    var format: AudioFormat = .m4a
    var preventUpscaling = true
}

enum BitrateMode {
    case auto
    case custom
}

enum OutputResolution: String {
    case original
    case p720
    case p1080
    case p2k
    case p4k

    var scaleFilter: String? {
        switch self {
        case .original: return nil
        case .p720: return "scale='min(1280,iw)':-2"
        case .p1080: return "scale='min(1920,iw)':-2"
        case .p2k: return "scale='min(2560,iw)':-2"
        case .p4k: return "scale='min(3840,iw)':-2"
        }
    }

    var defaultVideoBitrateKbps: Int {
        switch self {
        case .original: return 8000
        case .p720: return 1500
        case .p1080: return 3000
        case .p2k: return 5000
        case .p4k: return 8000
        }
    }
}

enum VideoCodec {
    case h264
    case hevc
    case vp9
    case av1

    var encoderName: String {
        switch self {
        case .h264:
            #if arch(arm64)
            return "h264_videotoolbox"
            #else
            return "libx264"
            #endif
        case .hevc:
            #if arch(arm64)
            return "hevc_videotoolbox"
            #else
            return "libx265"
            #endif
        case .vp9: return "libvpx-vp9"
        case .av1: return "libaom-av1"
        }
    }
}

enum ImageFormat {
    case jpeg
    case png
    case heic
    case webp
    case avif
    case gif

    func compressionArguments(quality: Int) -> [String] {
        let clampedQuality = min(max(quality, 10), 100)
        switch self {
        case .jpeg:
            return ["-q:v", "\(jpegQualityScale(from: clampedQuality))"]
        case .png:
            return ["-compression_level", "9"]
        case .webp:
            return ["-c:v", "libwebp", "-quality", "\(clampedQuality)"]
        case .avif:
            return ["-c:v", "libaom-av1", "-crf", "\(max(18, 63 - clampedQuality / 2))"]
        case .heic:
            return ["-q:v", "\(jpegQualityScale(from: clampedQuality))"]
        case .gif:
            return []
        }
    }

    var conversionArguments: [String] {
        switch self {
        case .png:
            return ["-compression_level", "0"]
        case .webp:
            return ["-c:v", "libwebp", "-lossless", "1"]
        case .avif:
            return ["-c:v", "libaom-av1", "-crf", "20"]
        default:
            return []
        }
    }

    private func jpegQualityScale(from percent: Int) -> Int {
        max(2, min(31, 32 - Int(Double(percent) * 0.30)))
    }
}

enum AudioFormat: String {
    case mp3
    case m4a
    case aac
    case flac
    case wav
    case ogg
    case webm

    var encodingArguments: [String] {
        switch self {
        case .mp3: return ["-c:a", "libmp3lame"]
        case .m4a, .aac: return ["-c:a", "aac"]
        case .flac: return ["-c:a", "flac"]
        case .wav: return ["-c:a", "pcm_s16le"]
        case .ogg: return ["-c:a", "libvorbis"]
        case .webm: return ["-c:a", "libopus"]
        }
    }

    var conversionArguments: [String] {
        switch self {
        case .flac, .wav:
            return encodingArguments
        default:
            return ["-c:a", "copy"]
        }
    }
}

enum AudioChannels: Int {
    case mono = 1
    case stereo = 2
}

enum AudioFilter: CaseIterable {
    case firequalizer
    case dynamicNormalize
    case loudNormalize
    case stereoWiden
    case extraStereo
    case speechIsolation
    case speechNormalize
    case noiseReduction
    case lowerPitch
    case raisePitch
    case chorus
    case reverb

    var ffmpegFilter: String {
        switch self {
        case .firequalizer:
            return "firequalizer=gain_entry='entry(60,3);entry(1000,1.5);entry(8000,2)'"
        case .dynamicNormalize:
            return "dynaudnorm"
        case .loudNormalize:
            return "loudnorm"
        case .stereoWiden:
            return "stereowiden=delay=20:feedback=0.3:crossfeed=0.3:drymix=0.8"
        case .extraStereo:
            return "extrastereo=m=1.8"
        case .speechIsolation:
            return "highpass=f=120,lowpass=f=7800,compand=attacks=0.02:decays=0.2:points=-80/-80|-45/-30|-20/-12|0/-6"
        case .speechNormalize:
            return "speechnorm"
        case .noiseReduction:
            return "afftdn=nf=-20"
        case .lowerPitch:
            return "asetrate=44100*0.8909,aresample=44100,atempo=1.1225"
        case .raisePitch:
            return "asetrate=44100*1.1225,aresample=44100,atempo=0.8909"
        case .chorus:
            return "chorus=0.5:0.9:50:0.4:0.25:2"
        case .reverb:
            return "aecho=0.8:0.88:60:0.4"
        }
    }
}

private final class FFmpegProgressParser {
    private let duration: TimeInterval?
    private let startDate = Date()

    init(duration: TimeInterval?) {
        self.duration = duration
    }

    func parse(_ text: String) -> MediaProgress? {
        guard let time = parseTimestamp(from: text) else {
            return MediaProgress(percent: 0, eta: nil, message: text)
        }

        guard let duration, duration > 0 else {
            return MediaProgress(percent: 0, eta: nil, message: text)
        }

        let percent = min(max(time / duration, 0), 1)
        let elapsed = Date().timeIntervalSince(startDate)
        let eta = percent > 0 ? elapsed * (1 - percent) / percent : nil
        return MediaProgress(percent: percent, eta: eta, message: text)
    }

    private func parseTimestamp(from text: String) -> TimeInterval? {
        guard let range = text.range(of: #"time=\d{2}:\d{2}:\d{2}\.\d{2}"#, options: .regularExpression) else {
            return nil
        }

        let timestamp = text[range].replacingOccurrences(of: "time=", with: "")
        let parts = timestamp.split(separator: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else {
            return nil
        }

        return hours * 3600 + minutes * 60 + seconds
    }
}

private final class LockedOutputBuffer {
    private let lock = NSLock()
    private var storage = ""

    var value: String {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ text: String) {
        lock.lock()
        storage += text
        lock.unlock()
    }
}
