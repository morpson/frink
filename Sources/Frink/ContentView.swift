import AppKit
import AVFoundation
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("isGrandmaMode") private var isGrandmaMode = false
    @State private var selectedMedia = MediaKind.video
    @State private var selectedTool = MediaTool.videoCompression
    @StateObject private var queue = BatchQueueModel()

    private var activeAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    var body: some View {
        Group {
            if isGrandmaMode {
                GrandmaModeView(queue: queue, isGrandmaMode: $isGrandmaMode)
            } else {
                StudioView(
                    selectedMedia: $selectedMedia,
                    selectedTool: $selectedTool,
                    queue: queue,
                    appearanceMode: $appearanceMode,
                    isGrandmaMode: $isGrandmaMode
                )
            }
        }
        .frame(minWidth: isGrandmaMode ? 720 : 920, minHeight: isGrandmaMode ? 600 : 720)
        .preferredColorScheme(activeAppearance.colorScheme)
        .environment(\.isGrandmaMode, isGrandmaMode)
        .onAppear {
            DMGCleaner.checkAndPromptClean()
        }
    }
}

private struct StudioView: View {
    @Binding var selectedMedia: MediaKind
    @Binding var selectedTool: MediaTool
    @ObservedObject var queue: BatchQueueModel
    @Binding var appearanceMode: String
    @Binding var isGrandmaMode: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var toolsForMedia: [MediaTool] {
        MediaTool.publicTools.filter { $0.kind == selectedMedia }
    }

    var body: some View {
        HSplitView {
            SidebarView(selectedMedia: $selectedMedia, selectedTool: $selectedTool)

            ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HeaderBar(appearanceMode: $appearanceMode, isGrandmaMode: $isGrandmaMode)
                        HeroToolHeader(tool: selectedTool)

                        PrimaryToolPanel(tool: selectedTool, queue: queue)

                        DisclosureGroup {
                            ToolGridView(
                                tools: toolsForMedia.filter { $0 != selectedTool },
                                selectedTool: $selectedTool
                            )
                        } label: {
                            Text("More Tools")
                                .font(.headline)
                        }
                    }
                    .padding(22)
                }
                .frame(minWidth: 480)
                .background(FrinkTheme.background(for: colorScheme))

                QueuePanel(queue: queue, selectedTool: selectedTool)
                    .frame(minWidth: 180, idealWidth: 230, maxWidth: 380)
            }
        .background(FrinkTheme.background(for: colorScheme))
        .onChange(of: selectedMedia) { newValue in
            selectedTool = MediaTool.defaultTool(for: newValue)
        }
    }
}

private struct SidebarView: View {
    @Binding var selectedMedia: MediaKind
    @Binding var selectedTool: MediaTool

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
                .frame(height: 52)

            ForEach(MediaKind.allCases) { media in
                Button {
                    selectedMedia = media
                    selectedTool = MediaTool.defaultTool(for: media)
                } label: {
                    VStack(alignment: .center, spacing: 10) {
                        MediaArtwork(kind: media)
                            .frame(maxWidth: .infinity, maxHeight: 58, alignment: .center)

                        ZStack {
                            Text(media.title)
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity, alignment: .center)

                            Circle()
                                .fill(selectedMedia == media ? Color.black : Color.white.opacity(0.45))
                                .frame(width: 16, height: 16)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(14)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 116, maxHeight: 116, alignment: .leading)
                    .background(media.color)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.black.opacity(selectedMedia == media ? 0.2 : 0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(width: 178)
        .background(.ultraThinMaterial)
    }
}

private struct AccelerationStatusCard: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.yellow)
                .frame(width: 26, height: 26)
                .background(Color.yellow.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 0) {
                #if arch(arm64)
                Text("VideoToolbox")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text("Hardware Acceleration")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                #else
                Text("FFmpeg CPU")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text("Software Encoding")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                #endif
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct OperationalStatusWidget: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
            Text("All Systems Operational")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct CompactAccelerationStatusCard: View {
    var body: some View {
        Image(systemName: "cpu")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.yellow)
            .frame(width: 32, height: 32)
            .background(Color.yellow.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            )
            #if arch(arm64)
            .help("VideoToolbox Hardware Acceleration")
            #else
            .help("FFmpeg CPU Software Encoding")
            #endif
    }
}

private struct CompactOperationalStatusWidget: View {
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 10, height: 10)
            .frame(width: 32, height: 32)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            )
            .help("All Systems Operational")
    }
}

private struct HeaderBar: View {
    @Binding var appearanceMode: String
    @Binding var isGrandmaMode: Bool
    @State private var showingSettings = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let titleSize = min(max(width * 0.15, 96), 172)
            let controlSize = min(max(width * 0.045, 40), 58)

            ZStack(alignment: .bottomLeading) {
                Text("frink")
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .kerning(0)
                    .lineLimit(1)
                    .foregroundStyle(.primary.opacity(0.92))
                    .alignmentGuide(.bottom) { d in d[.bottom] }
                    .offset(x: -6, y: titleSize * 0.22)
                    .accessibilityHidden(true)

                HStack(alignment: .center, spacing: 12) {
                    Spacer()

                    if width > 760 {
                        AccelerationStatusCard()
                        OperationalStatusWidget()
                    } else if width > 520 {
                        CompactAccelerationStatusCard()
                        CompactOperationalStatusWidget()
                    }

                    Button {
                        isGrandmaMode = true
                    } label: {
                        GrandmaIcon()
                            .frame(width: controlSize, height: controlSize)
                    }
                    .buttonStyle(.plain)
                    .help("Grandma Mode")

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: min(controlSize * 0.48, 24), weight: .semibold))
                            .frame(width: controlSize, height: controlSize)
                    }
                    .buttonStyle(FrinkIconButtonStyle())
                    .help("Settings")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 14)
            }
        }
        .frame(height: 118)
        .sheet(isPresented: $showingSettings) {
            SettingsView(appearanceMode: $appearanceMode, isGrandmaMode: $isGrandmaMode)
        }
    }
}

private struct HeroToolHeader: View {
    let tool: MediaTool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(tool.kind.badge)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(tool.kind.color)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(tool.title)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .kerning(0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)

                Text(tool.subtitle)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(tool.formats.prefix(5), id: \.self) { format in
                        Text(format)
                            .font(.caption.bold())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: true)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    Text("Formats supported")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .layoutPriority(1)

            Spacer()

            MediaArtwork(kind: tool.kind)
                .frame(width: 132, height: 122)
                .layoutPriority(0)
        }
        .foregroundStyle(.black)
        .padding(18)
        .background(
            LinearGradient(colors: [tool.kind.color, tool.kind.color.opacity(0.72)], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WidthReader: View {
    @Binding var width: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    width = proxy.size.width
                }
                .onChange(of: proxy.size.width) { newValue in
                    width = newValue
                }
        }
    }
}

private struct PrimaryToolPanel: View {
    let tool: MediaTool
    @ObservedObject var queue: BatchQueueModel
    @State private var panelWidth: CGFloat = 800

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if panelWidth > 640 {
                    HStack(alignment: .top, spacing: 16) {
                        DropZoneView(tool: tool, queue: queue)
                            .frame(maxWidth: 320)

                        Divider()

                        ToolOptionsView(tool: tool, queue: queue)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                } else {
                    VStack(spacing: 16) {
                        DropZoneView(tool: tool, queue: queue)
                            .frame(maxWidth: .infinity)

                        Divider()

                        ToolOptionsView(tool: tool, queue: queue)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
            .padding(14)
            .background(WidthReader(width: $panelWidth))

            Divider()

            MetricsStrip(tool: tool, queue: queue)
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary.opacity(0.12)))
    }
}

private struct ToolConfigurationLayout: View {
    let tool: MediaTool
    @ObservedObject var queue: BatchQueueModel
    let isCompact: Bool

    var body: some View {
        Group {
            if isCompact {
                VStack(spacing: 16) {
                    DropZoneView(tool: tool, queue: queue)

                    Divider()

                    ToolOptionsView(tool: tool, queue: queue)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                HStack(spacing: 16) {
                    DropZoneView(tool: tool, queue: queue)

                    Divider()

                    ToolOptionsView(tool: tool, queue: queue)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }
}

private struct DropZoneView: View {
    let tool: MediaTool
    @ObservedObject var queue: BatchQueueModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: 48, weight: .medium))
            Text("Drag & drop \(tool.kind.dropLabel) here\nor click to browse")
                .multilineTextAlignment(.center)
                .font(.headline)
            Button {
                queue.chooseFiles(preferredKind: tool.kind, preferredTool: tool)
            } label: {
                Label("Choose Files", systemImage: "plus")
            }
            .buttonStyle(FrinkActionButtonStyle(color: tool.kind.color, compact: true))
        }
        .frame(minWidth: 210, idealWidth: 250, maxWidth: .infinity)
        .frame(minHeight: 230)
        .padding(18)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                .foregroundStyle(.secondary.opacity(0.45))
        )
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            queue.addDroppedItems(providers: providers, preferredKind: tool.kind, preferredTool: tool)
            return true
        }
    }
}

private struct ToolOptionsView: View {
    let tool: MediaTool
    @ObservedObject var queue: BatchQueueModel
    @State private var resolution = "1080p"
    @State private var frameRate = "30 fps (lower only)"
    @State private var bitrateMode = "Auto"
    @State private var bitrate = 8000.0
    @State private var quality = 82.0
    @State private var audioBitrate = "160 kbps"
    @State private var sampleRate = "44.1 kHz"
    @State private var channels = "Stereo"
    @State private var outputFormat = ""
    @State private var preserveAnimation = true
    @State private var smartDecision = true
    @State private var language = "English"
    @State private var pitch = 1.0
    @State private var speechRate = 0.48
    @State private var effects = Set<AudioEffect>([.dynamicNormalize])

    private let resolutions = ["Original", "4K", "2K", "1080p", "720p"]
    private let frameRates = ["60 fps (lower only)", "30 fps (lower only)", "24 fps (lower only)", "23.98 fps (lower only)"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch tool {
            case .videoCompression:
                RecommendationBanner(suggestion: queue.latestSuggestion, expectedKind: .video)
                resolutionPicker
                pickerRow("Frame Rate", selection: $frameRate, values: frameRates, note: "23.98 - 60 fps")
                segmentedRow("Bitrate", selection: $bitrateMode, values: ["Auto", "Custom"])
                sliderRow(value: $bitrate, range: 500...15000, label: String(format: "%.1f Mbps", bitrate / 1000))
                Toggle("Keep original if output is larger", isOn: $smartDecision)

            case .videoConversion:
                formatPicker(["MP4", "MOV", "M4V", "WebM"])
                FeatureList(items: ["Lossless remux where possible", "Smart audio copy", "VideoToolbox for H.264/HEVC", "VP9 for WebM", "Preserve source bitrate"])

            case .videoAnimation:
                formatPicker(["WebP", "AVIF", "GIF"])
                pickerRow("Frame Rate", selection: $frameRate, values: ["15 fps", "12 fps", "10 fps"], note: "optimized")
                FeatureList(items: ["High quality presets", "Direct AVIF through libaom-av1", "Timeline-aware output"])

            case .videoAudioEffects:
                formatPicker(["MP4", "MOV", "M4V"])
                EffectsPicker(effects: $effects)
                FeatureList(items: ["Applies filters to the audio track", "Copies video stream without re-encoding", "Useful for interviews, screen recordings, and noisy clips"])

            case .extractAudio:
                formatPicker(["MP3", "M4A", "AAC", "FLAC", "WAV", "OGG"])
                FeatureList(items: ["Copies compatible streams", "Falls back to efficient encoding"])

            case .imageCompression:
                RecommendationBanner(suggestion: queue.latestSuggestion, expectedKind: .image)
                resolutionPicker
                sliderRow(value: $quality, range: 10...100, label: "\(Int(quality))% quality")
                Toggle("Preserve animation when detected", isOn: $preserveAnimation)
                Toggle("Keep original if output is larger", isOn: $smartDecision)
                FeatureList(items: ["MozJPEG for JPEG", "OxiPNG/Zopfli lossless PNG", "Animated WebP/AVIF/GIF detection", "Frame count indicator"])

            case .imageConversion:
                formatPicker(["JPEG", "PNG", "WebP", "HEIC", "AVIF", "GIF"])
                FeatureList(items: ["Format conversion only", "No extra compression", "Batch processing"])

            case .audioCompression:
                RecommendationBanner(suggestion: queue.latestSuggestion, expectedKind: .audio)
                pickerRow("Bitrate", selection: $audioBitrate, values: ["32 kbps", "48 kbps", "64 kbps", "96 kbps", "128 kbps", "160 kbps", "256 kbps", "320 kbps"], note: nil)
                pickerRow("Sample Rate", selection: $sampleRate, values: ["8 kHz", "11.025 kHz", "16 kHz", "22.05 kHz", "32 kHz", "44.1 kHz", "48 kHz"], note: nil)
                segmentedRow("Channels", selection: $channels, values: ["Mono", "Stereo"])
                Toggle("Prevent low-quality audio upscaling", isOn: $smartDecision)

            case .audioConversion:
                formatPicker(["MP3", "M4A", "FLAC", "WAV", "WebM"])
                FeatureList(items: ["Lossless conversion where possible", "Batch conversion", "Smart stream copy"])

            case .audioToText:
                pickerRow("Language", selection: $language, values: ["English", "Chinese", "Japanese", "Korean", "Spanish", "French", "German", "Italian", "Portuguese", "Russian"], note: "Apple Speech")
                FeatureList(items: ["Copy transcription to clipboard", "Local framework integration target"])

            case .textToSpeech:
                pickerRow("Voice Language", selection: $language, values: ["English", "Chinese", "Japanese", "Korean", "Spanish", "French", "German", "Italian", "Portuguese", "Russian"], note: "optimized voice")
                sliderRow(value: $pitch, range: 0.5...2.0, label: String(format: "Pitch %.1f", pitch))
                sliderRow(value: $speechRate, range: 0.2...0.8, label: String(format: "Rate %.2f", speechRate))
                FeatureList(items: ["Import text files", "Save WAV to Files or iCloud", "Progress indicator"])

            case .audioEffects:
                formatPicker(["MP3", "M4A", "FLAC", "WAV"])
                EffectsPicker(effects: $effects)
            }
        }
        .onAppear {
            if outputFormat.isEmpty {
                outputFormat = tool.formats.first ?? ""
            }
        }
        .onChange(of: queue.recommendationVersion) { _ in
            applyLatestSuggestion()
        }
    }

    private func applyLatestSuggestion() {
        guard let suggestion = queue.latestSuggestion, suggestion.kind == tool.kind else { return }

        switch suggestion.kind {
        case .video:
            resolution = suggestion.resolution
            frameRate = suggestion.frameRateLabel
            bitrateMode = suggestion.bitrateMode
            bitrate = Double(suggestion.bitrateKbps)
        case .image:
            resolution = suggestion.resolution
            quality = Double(suggestion.quality)
            preserveAnimation = suggestion.preserveAnimation
        case .audio:
            audioBitrate = "\(suggestion.bitrateKbps) kbps"
            sampleRate = suggestion.sampleRateLabel
            channels = suggestion.channelsLabel
        }
    }

    private var resolutionPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Resolution")
                .font(.headline)
            Picker("Resolution", selection: $resolution) {
                ForEach(resolutions, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
        }
    }

    private func formatPicker(_ formats: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Output Format")
                .font(.headline)
            Picker("Output Format", selection: $outputFormat) {
                ForEach(formats, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            .onAppear {
                outputFormat = formats.first ?? ""
            }
        }
    }

    private func pickerRow(_ title: String, selection: Binding<String>, values: [String], note: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.headline)
                Picker(title, selection: selection) {
                    ForEach(values, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 280)
            }
            if let note {
                Text(note)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private func segmentedRow(_ title: String, selection: Binding<String>, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.headline)
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 230)
        }
    }

    private func sliderRow(value: Binding<Double>, range: ClosedRange<Double>, label: String) -> some View {
        HStack(spacing: 12) {
            Slider(value: value, in: range)
                .tint(.yellow)
            Text(label)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 98)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: 360)
    }
}

private struct MetricsStrip: View {
    let tool: MediaTool
    @ObservedObject var queue: BatchQueueModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 12) {
            MetricItem(symbol: "clock.badge.checkmark", title: "Estimated Time", value: queue.etaText, footnote: "For \(queue.items.count) files")
            MetricItem(symbol: "scalemass", title: tool.kind == .audio ? "Quality Guard" : "Compression Estimate", value: tool.kind == .audio ? "On" : "65%", footnote: tool.kind == .audio ? "No upscaling" : "Space Savings")
            MetricItem(symbol: "chart.bar", title: "Acceleration", value: tool.usesHardware ? "Hardware" : "Smart", footnote: tool.engine)
        }
        .padding(14)
    }
}

private struct MetricItem: View {
    let symbol: String
    let title: String
    let value: String
    let footnote: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.yellow)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(value)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
}

private struct ToolGridView: View {
    let tools: [MediaTool]
    @Binding var selectedTool: MediaTool

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
            ForEach(tools) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: tool.symbol)
                            .font(.system(size: 28, weight: .semibold))
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tool.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(tool.shortDescription)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .padding(12)
                    .background(tool.kind.color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct QueuePanel: View {
    @ObservedObject var queue: BatchQueueModel
    let selectedTool: MediaTool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Batch Queue")
                    .font(.headline)
                Spacer()
                Text("\(queue.items.count)")
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
            }
            .padding(16)

            Divider()

            ScrollView {
                if queue.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("No files yet")
                            .font(.headline)
                        Text("Add files from the main panel or drag them into the drop area.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(queue.items) { item in
                            QueueRow(item: item) {
                                queue.remove(item)
                            }
                            Divider()
                        }
                    }
                }
            }

            QueueSummary(queue: queue, selectedTool: selectedTool)
                .padding(12)
        }
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
    }
}

private struct QueueRow: View {
    let item: QueueItem
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(item.kind.color.opacity(0.75))
                .frame(width: 58, height: 58)
                .overlay(Image(systemName: item.kind.symbol).foregroundStyle(.black).font(.title2))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let suggestion = item.suggestion {
                    Text(suggestion.queueLine)
                        .font(.caption)
                        .foregroundStyle(item.kind.color)
                        .lineLimit(1)
                }
                Text(item.requestedTool?.title ?? "Queued for \(MediaTool.defaultTool(for: item.kind).title)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if item.progress > 0 {
                    ProgressView(value: item.progress)
                        .tint(.yellow)
                    Text(item.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    outputDetails
                } else if item.detail == "Detecting..." {
                    Text("Detecting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(item.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 4)

            Button(action: removeAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Remove from Queue")
        }
        .padding(12)
    }

    @ViewBuilder
    private var outputDetails: some View {
        if let outputURL = item.outputURL {
            if let processedToolTitle = item.processedToolTitle {
                Text(processedToolTitle)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Text(outputURL.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Reveal Output in Finder")
            }
        }
    }
}

private struct QueueSummary: View {
    @ObservedObject var queue: BatchQueueModel
    let selectedTool: MediaTool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if queue.items.isEmpty {
                Text("Ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Add files to begin")
                    .font(.title3.bold())
            } else if queue.hasActiveJobs {
                HStack {
                    Text("Overall Progress")
                    Spacer()
                    Text("ETA: \(queue.etaText)")
                }
                .font(.caption)
                Text("\(Int(queue.overallProgress * 100))%")
                    .font(.title.bold())
                ProgressView(value: queue.overallProgress)
                    .tint(.yellow)
            } else {
                Text("Queued")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(queue.items.count) \(queue.items.count == 1 ? "file" : "files") ready")
                    .font(.title3.bold())
                Button {
                    queue.startProcessing(tool: selectedTool)
                } label: {
                    Label(queue.allItemsComplete ? "Run Again" : "Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FrinkActionButtonStyle(color: .yellow, compact: true))
            }
        }
        .padding(14)
        .background(Color.yellow.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.25)))
    }
}

private struct GrandmaModeView: View {
    @ObservedObject var queue: BatchQueueModel
    @Binding var isGrandmaMode: Bool
    @State private var selectedKind = MediaKind.video
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 26) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let titleSize = min(max(width * 0.16, 92), 168)
                let grandmaSize = min(max(width * 0.055, 52), 74)

                ZStack(alignment: .bottomLeading) {
                    Text("frink")
                        .font(.system(size: titleSize, weight: .black, design: .rounded))
                        .kerning(0)
                        .lineLimit(1)
                        .foregroundStyle(.primary.opacity(0.92))
                        .offset(x: -6, y: titleSize * 0.22)
                        .accessibilityHidden(true)

                    HStack(spacing: 14) {
                        Spacer()

                        if width > 520 {
                            Text("Grandma Mode")
                                .font(.system(size: min(max(width * 0.03, 20), 30), weight: .black, design: .rounded))
                                .lineLimit(1)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.yellow)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Button {
                            isGrandmaMode = false
                        } label: {
                            GrandmaIcon()
                                .frame(width: grandmaSize, height: grandmaSize)
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16, weight: .black))
                                        .foregroundStyle(.black, Color.white)
                                        .offset(x: 3, y: -3)
                                }
                        }
                        .buttonStyle(.plain)
                        .help("Exit Grandma Mode")
                    }
                    .padding(.bottom, 12)
                }
            }
            .frame(height: 122)

            Picker("Media", selection: $selectedKind) {
                ForEach(MediaKind.allCases) { kind in
                    Label(kind.title, systemImage: kind.symbol).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .font(.title)

            VStack(spacing: 18) {
                MediaArtwork(kind: selectedKind)
                    .frame(maxWidth: 132, maxHeight: 132)
                Text("Drop \(selectedKind.dropLabel) here")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(grandmaSubtitle)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    queue.chooseFiles(preferredKind: selectedKind)
                } label: {
                    Label("Choose Files", systemImage: "plus")
                        .font(.system(size: 30, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(FrinkActionButtonStyle(color: selectedKind.color, compact: false))
                .controlSize(.large)
            }
            .padding(34)
            .frame(maxWidth: .infinity, minHeight: 330)
            .background(selectedKind.color.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedKind.color.opacity(0.55), lineWidth: 2))
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                queue.addDroppedItems(providers: providers, preferredKind: selectedKind)
                return true
            }

            HStack(spacing: 16) {
                GrandmaAction(title: "Make Smaller", symbol: "arrow.down.forward.and.arrow.up.backward", color: .yellow) {
                    queue.chooseFiles(preferredKind: selectedKind)
                }
                GrandmaAction(title: "Change Format", symbol: "arrow.triangle.2.circlepath", color: .pink) {
                    queue.chooseFiles(preferredKind: selectedKind)
                }
            }

            if !queue.items.isEmpty {
                Button {
                    queue.startProcessing(tool: MediaTool.defaultTool(for: selectedKind))
                } label: {
                    Label(queue.hasActiveJobs ? "Working" : "Start", systemImage: queue.hasActiveJobs ? "hourglass" : "play.fill")
                        .font(.system(size: 30, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(FrinkActionButtonStyle(color: selectedKind.color, compact: false))
                .disabled(queue.hasActiveJobs)
            }

            Spacer()
        }
        .padding(32)
        .background(FrinkTheme.background(for: colorScheme))
    }

    private var grandmaSubtitle: String {
        switch selectedKind {
        case .video:
            return "We will keep the video looking good and save space."
        case .image:
            return "We will shrink pictures without confusing settings."
        case .audio:
            return "We will shrink sound, convert it, or turn speech into text."
        }
    }
}

private struct GrandmaAction: View {
    let title: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 46, weight: .bold))
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .foregroundStyle(.black)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct MediaArtwork: View {
    let kind: MediaKind

    var body: some View {
        GraphicImage(name: kind.graphicName, accessibilityLabel: kind.title)
    }
}

private struct GrandmaIcon: View {
    var body: some View {
        GraphicImage(name: "grandma", accessibilityLabel: "Grandma Mode")
        .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}

private struct GraphicImage: View {
    let name: String
    let accessibilityLabel: String

    var body: some View {
        if let image = FrinkGraphicLoader.image(named: name) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(accessibilityLabel)
        } else {
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .accessibilityLabel(accessibilityLabel)
        }
    }
}

private enum FrinkGraphicLoader {
    static func image(named name: String) -> NSImage? {
        let fileName = "\(name).png"
        if let appResourceURL = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "Graphics"),
           let image = NSImage(contentsOf: appResourceURL) {
            return image
        }

        if let packageResourceURL = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Graphics"),
           let image = NSImage(contentsOf: packageResourceURL) {
            return image
        }

        return nil
    }
}

private struct SettingsView: View {
    @Binding var appearanceMode: String
    @Binding var isGrandmaMode: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showingOpenSource = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                    Text("App-wide display and accessibility preferences.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(FrinkIconButtonStyle())
            }
            .padding(22)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                        .font(.headline)
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(14)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Toggle(isOn: $isGrandmaMode) {
                    HStack(spacing: 12) {
                        GrandmaIcon()
                            .frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Grandma Mode")
                                .font(.headline)
                            Text("Simpler tools, bigger text, and fewer choices.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(.switch)
                .padding(14)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    showingOpenSource = true
                } label: {
                    HStack {
                        Label("Open Source Acknowledgements", systemImage: "info.circle")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .padding(.vertical, 3)
                }
                .buttonStyle(FrinkActionButtonStyle(color: .yellow, compact: true))

                Spacer()
            }
            .padding(22)
        }
        .frame(width: 480, height: 420)
        .sheet(isPresented: $showingOpenSource) {
            OpenSourceAttributionsView()
        }
    }
}

private struct FrinkActionButtonStyle: ButtonStyle {
    var color: Color
    var compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .headline : .system(size: 26, weight: .black, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, compact ? 14 : 20)
            .padding(.vertical, compact ? 8 : 16)
            .background(color.opacity(configuration.isPressed ? 0.72 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.18), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct FrinkIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary.opacity(configuration.isPressed ? 0.28 : 0.14), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct FeatureList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }
}

private struct EffectsPicker: View {
    @Binding var effects: Set<AudioEffect>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 8)], spacing: 8) {
            ForEach(AudioEffect.allCases) { effect in
                Toggle(isOn: Binding(
                    get: { effects.contains(effect) },
                    set: { enabled in
                        if enabled {
                            effects.insert(effect)
                        } else {
                            effects.remove(effect)
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(effect.title)
                            .font(.subheadline.bold())
                        Text(effect.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(effect.filterNames)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

private struct OpenSourceAttributionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Open Source")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                    Text("Media libraries and frameworks acknowledged by frink.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(22)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("frink invokes or is designed to interoperate with these open source media projects. If a future build bundles any external binaries, the distributed app must include the corresponding full license texts and comply with that binary's license terms.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(ThirdPartyAttribution.all) { attribution in
                        AttributionRow(attribution: attribution)
                    }
                }
                .padding(22)
            }
        }
        .frame(width: 680, height: 640)
    }
}

private struct AttributionRow: View {
    let attribution: ThirdPartyAttribution

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(attribution.name)
                    .font(.headline)
                Spacer()
                Text(attribution.license)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            Text(attribution.use)
                .font(.subheadline)

            Text(attribution.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary.opacity(0.1)))
    }
}

private struct ThirdPartyAttribution: Identifiable {
    let id = UUID()
    let name: String
    let license: String
    let url: String
    let use: String

    static let all = [
        ThirdPartyAttribution(name: "FFmpeg", license: "LGPL 2.1+ / GPL 2+", url: "https://ffmpeg.org/", use: "Media probing, compression, conversion, animation export, audio extraction, and audio filters."),
        ThirdPartyAttribution(name: "Apple VideoToolbox", license: "Apple SDK", url: "https://developer.apple.com/documentation/videotoolbox", use: "Hardware-accelerated H.264 and HEVC encoding through FFmpeg's VideoToolbox encoders."),
        ThirdPartyAttribution(name: "libaom", license: "BSD 2-Clause", url: "https://aomedia.googlesource.com/aom/", use: "AVIF and AV1 encoding through FFmpeg when available."),
        ThirdPartyAttribution(name: "libvpx", license: "BSD 3-Clause", url: "https://chromium.googlesource.com/webm/libvpx", use: "VP9/WebM encoding through FFmpeg when available."),
        ThirdPartyAttribution(name: "libwebp", license: "BSD 3-Clause", url: "https://chromium.googlesource.com/webm/libwebp", use: "Animated and still WebP encoding through FFmpeg when available."),
        ThirdPartyAttribution(name: "libopus", license: "BSD 3-Clause", url: "https://opus-codec.org/", use: "WebM/Opus audio encoding through FFmpeg when available."),
        ThirdPartyAttribution(name: "libvorbis", license: "Xiph BSD-style", url: "https://xiph.org/vorbis/", use: "OGG/Vorbis audio encoding through FFmpeg when available."),
        ThirdPartyAttribution(name: "LAME MP3 Encoder", license: "LGPL", url: "https://lame.sourceforge.io/", use: "MP3 encoding through FFmpeg's libmp3lame encoder when available."),
        ThirdPartyAttribution(name: "MozJPEG", license: "BSD-style", url: "https://github.com/mozilla/mozjpeg", use: "Planned high-quality JPEG compression path."),
        ThirdPartyAttribution(name: "OxiPNG", license: "MIT", url: "https://github.com/shssoichiro/oxipng", use: "Planned lossless PNG optimization path."),
        ThirdPartyAttribution(name: "Zopfli", license: "Apache 2.0", url: "https://github.com/google/zopfli", use: "Planned PNG deflate optimization path."),
        ThirdPartyAttribution(name: "Apple Speech, AVFoundation, ImageIO, SwiftUI", license: "Apple SDK", url: "https://developer.apple.com/documentation/", use: "Native macOS UI, media metadata detection, speech transcription, and text-to-speech.")
    ]
}

private struct RecommendationBanner: View {
    let suggestion: CompressionSuggestion?
    let expectedKind: MediaKind

    var body: some View {
        if let suggestion, suggestion.kind == expectedKind {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Auto Suggested", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                    Text(suggestion.confidence)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(expectedKind.color.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                Text(suggestion.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(suggestion.chips, id: \.self) { chip in
                        Text(chip)
                            .font(.caption.bold())
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(12)
            .background(expectedKind.color.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(expectedKind.color.opacity(0.35)))
        }
    }
}

private struct WindowDots: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.red).frame(width: 13, height: 13)
            Circle().fill(Color.yellow).frame(width: 13, height: 13)
            Circle().fill(Color.green).frame(width: 13, height: 13)
        }
    }
}

private struct IsometricModeGraphic: View {
    let kind: MediaKind

    var body: some View {
        LegoStairGraphic(kind: kind)
            .drawingGroup()
    }
}

private struct LegoStairGraphic: View {
    let kind: MediaKind

    var body: some View {
        ZStack {
            BlockFaceView(points: [p(55, 22), p(110, 0), p(138, 18), p(84, 47)], color: palette.top)
            BlockFaceView(points: [p(84, 47), p(138, 18), p(138, 92), p(84, 122)], color: palette.right)
            BlockFaceView(points: [p(55, 22), p(84, 47), p(84, 83), p(55, 63)], color: palette.left)
            BlockFaceView(points: [p(18, 70), p(55, 51), p(84, 66), p(47, 88)], color: palette.stepTop)
            BlockFaceView(points: [p(18, 70), p(47, 88), p(47, 122), p(18, 104)], color: palette.stepLeft)
            BlockFaceView(points: [p(47, 88), p(84, 66), p(84, 122), p(47, 122)], color: palette.stepRight)

            detail
        }
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y)
    }

    @ViewBuilder
    private var detail: some View {
        switch kind {
        case .video:
            EmptyView()
        case .image:
            Path { path in
                path.move(to: p(29, 94))
                path.addLine(to: p(38, 86))
                path.addLine(to: p(48, 96))
                path.addLine(to: p(56, 90))
            }
            .stroke(Color.black, lineWidth: 3)
            Circle()
                .fill(Color.black)
                .frame(width: 6, height: 6)
                .position(x: 36, y: 79)
        case .audio:
            HStack(spacing: 5) {
                ForEach([14, 28, 42, 30, 18], id: \.self) { height in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black)
                        .frame(width: 5, height: CGFloat(height))
                }
            }
            .rotationEffect(.degrees(-22))
            .position(x: 50, y: 89)
        }
    }

    private var palette: LegoPalette {
        switch kind {
        case .video:
            return LegoPalette(top: .orange, right: Color(red: 1.0, green: 0.42, blue: 0.05), left: .pink, stepTop: .pink.opacity(0.92), stepLeft: .pink.opacity(0.82), stepRight: Color(red: 1.0, green: 0.42, blue: 0.05).opacity(0.9))
        case .image:
            return LegoPalette(top: Color(red: 1.0, green: 0.74, blue: 0.13), right: Color(red: 0.94, green: 0.36, blue: 0.62), left: Color(red: 0.98, green: 0.63, blue: 0.78), stepTop: Color(red: 0.98, green: 0.63, blue: 0.78), stepLeft: Color(red: 0.94, green: 0.36, blue: 0.62).opacity(0.82), stepRight: Color(red: 1.0, green: 0.74, blue: 0.13).opacity(0.85))
        case .audio:
            return LegoPalette(top: Color(red: 0.64, green: 0.75, blue: 0.43), right: Color(red: 0.44, green: 0.56, blue: 0.30), left: Color(red: 1.0, green: 0.74, blue: 0.13), stepTop: Color(red: 1.0, green: 0.74, blue: 0.13).opacity(0.95), stepLeft: Color(red: 0.64, green: 0.75, blue: 0.43), stepRight: Color(red: 0.44, green: 0.56, blue: 0.30).opacity(0.86))
        }
    }
}

private struct LegoPalette {
    let top: Color
    let right: Color
    let left: Color
    let stepTop: Color
    let stepLeft: Color
    let stepRight: Color
}

private struct BlockFaceView: View {
    let points: [CGPoint]
    let color: Color

    var body: some View {
        BlockFace(points: points)
            .fill(color)
            .overlay(BlockFace(points: points).stroke(Color.black, lineWidth: 3))
    }
}

private struct BlockFace: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }
}

private enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private enum MediaKind: String, CaseIterable, Identifiable {
    case video
    case image
    case audio

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var badge: String { "\(title.uppercased()) TOOL" }

    var symbol: String {
        switch self {
        case .video: return "video"
        case .image: return "photo"
        case .audio: return "waveform"
        }
    }

    var graphicName: String {
        switch self {
        case .video: return "video"
        case .image: return "image"
        case .audio: return "audio"
        }
    }

    var color: Color {
        switch self {
        case .video: return Color(red: 1.0, green: 0.74, blue: 0.13)
        case .image: return Color(red: 0.94, green: 0.36, blue: 0.62)
        case .audio: return Color(red: 0.44, green: 0.56, blue: 0.30)
        }
    }

    var dropLabel: String {
        switch self {
        case .video: return "videos"
        case .image: return "images"
        case .audio: return "audio"
        }
    }

    var allowedContentTypes: [UTType] {
        switch self {
        case .video:
            return [.movie, .mpeg4Movie, .quickTimeMovie]
        case .image:
            return [.image, .jpeg, .png, .gif, .heic, .webP]
        case .audio:
            return [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
        }
    }
}

private enum MediaTool: String, CaseIterable, Identifiable {
    case videoCompression
    case videoConversion
    case videoAnimation
    case videoAudioEffects
    case extractAudio
    case imageCompression
    case imageConversion
    case audioCompression
    case audioConversion
    case audioToText
    case textToSpeech
    case audioEffects

    var id: String { rawValue }

    static var publicTools: [MediaTool] {
        allCases.filter { $0.isPubliclyAvailable }
    }

    var isPubliclyAvailable: Bool {
        switch self {
        case .audioToText, .textToSpeech:
            return false
        default:
            return true
        }
    }

    static func defaultTool(for kind: MediaKind) -> MediaTool {
        switch kind {
        case .video: return .videoCompression
        case .image: return .imageCompression
        case .audio: return .audioCompression
        }
    }

    var kind: MediaKind {
        switch self {
        case .videoCompression, .videoConversion, .videoAnimation, .videoAudioEffects, .extractAudio:
            return .video
        case .imageCompression, .imageConversion:
            return .image
        case .audioCompression, .audioConversion, .audioToText, .textToSpeech, .audioEffects:
            return .audio
        }
    }

    var title: String {
        switch self {
        case .videoCompression: return "Video Compression"
        case .videoConversion: return "Video Conversion"
        case .videoAnimation: return "Video to Animation"
        case .videoAudioEffects: return "Video Audio Effects"
        case .extractAudio: return "Extract Audio"
        case .imageCompression: return "Image Compression"
        case .imageConversion: return "Image Conversion"
        case .audioCompression: return "Audio Compression"
        case .audioConversion: return "Audio Conversion"
        case .audioToText: return "Audio to Text"
        case .textToSpeech: return "Text to Speech"
        case .audioEffects: return "Audio Effects"
        }
    }

    var subtitle: String {
        switch self {
        case .videoCompression: return "Compress videos efficiently with smart settings."
        case .videoConversion: return "Batch convert formats while preserving quality."
        case .videoAnimation: return "Create optimized WebP, AVIF, and GIF animations."
        case .videoAudioEffects: return "Clean, normalize, widen, or stylize a video's audio track."
        case .extractAudio: return "Save video audio tracks in the format you need."
        case .imageCompression: return "Reduce image size while protecting pixels and animation."
        case .imageConversion: return "Change image formats without extra compression."
        case .audioCompression: return "Shrink audio with bitrate, sample rate, and channel control."
        case .audioConversion: return "Convert audio formats with lossless paths where possible."
        case .audioToText: return "Transcribe speech using Apple's Speech framework."
        case .textToSpeech: return "Generate natural spoken audio from text."
        case .audioEffects: return "Apply practical FFmpeg audio filters."
        }
    }

    var shortDescription: String {
        switch self {
        case .videoCompression: return "Shrink MOV, MP4, M4V"
        case .videoConversion: return "Convert MP4, MOV, WebM"
        case .videoAnimation: return "Create GIFs and animations"
        case .videoAudioEffects: return "Process video sound"
        case .extractAudio: return "Save audio from video"
        case .imageCompression: return "Reduce size, keep quality"
        case .imageConversion: return "Convert JPG, PNG, WebP"
        case .audioCompression: return "Shrink audio files"
        case .audioConversion: return "Convert sound formats"
        case .audioToText: return "Transcribe audio"
        case .textToSpeech: return "Generate natural voice"
        case .audioEffects: return "Normalize, widen, clean"
        }
    }

    var symbol: String {
        switch self {
        case .videoCompression: return "video"
        case .videoConversion: return "movieclapper"
        case .videoAnimation: return "photo.on.rectangle.angled"
        case .videoAudioEffects: return "slider.horizontal.3"
        case .extractAudio: return "music.note"
        case .imageCompression: return "photo"
        case .imageConversion: return "arrow.triangle.2.circlepath"
        case .audioCompression: return "waveform"
        case .audioConversion: return "speaker.wave.2"
        case .audioToText: return "textformat"
        case .textToSpeech: return "bubble.left"
        case .audioEffects: return "slider.horizontal.3"
        }
    }

    var formats: [String] {
        switch self {
        case .videoCompression: return ["MOV", "MP4", "M4V"]
        case .videoConversion: return ["MP4", "MOV", "M4V", "WebM"]
        case .videoAnimation: return ["WebP", "AVIF", "GIF"]
        case .videoAudioEffects: return ["MP4", "MOV", "M4V"]
        case .extractAudio: return ["MP3", "M4A", "AAC", "FLAC", "WAV", "OGG"]
        case .imageCompression: return ["JPEG", "PNG", "HEIC", "WebP", "AVIF", "GIF"]
        case .imageConversion: return ["JPEG", "PNG", "WebP", "HEIC", "AVIF", "GIF"]
        case .audioCompression: return ["MP3", "M4A", "AAC"]
        case .audioConversion: return ["MP3", "M4A", "FLAC", "WAV", "WebM"]
        case .audioToText: return ["TXT"]
        case .textToSpeech: return ["WAV"]
        case .audioEffects: return ["MP3", "M4A", "FLAC", "WAV"]
        }
    }

    var engine: String {
        switch self {
        case .audioToText: return "Apple Speech"
        case .textToSpeech: return "AVSpeech"
        case .imageCompression, .imageConversion: return "ImageIO"
        default: return "FFmpeg"
        }
    }

    var usesHardware: Bool {
        switch self {
        case .videoCompression, .videoConversion:
            return true
        default:
            return false
        }
    }
}

private enum AudioEffect: String, CaseIterable, Identifiable {
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firequalizer: return "Equalizer Presets"
        case .dynamicNormalize: return "Dynamic Normalize"
        case .loudNormalize: return "Loud Normalize"
        case .stereoWiden: return "Stereo Widen"
        case .extraStereo: return "Extra Stereo"
        case .speechIsolation: return "Speech Isolation"
        case .speechNormalize: return "Speech Normalize"
        case .noiseReduction: return "Noise Reduction"
        case .lowerPitch: return "Lower Pitch"
        case .raisePitch: return "Raise Pitch"
        case .chorus: return "Chorus"
        case .reverb: return "Reverb"
        }
    }

    var description: String {
        switch self {
        case .firequalizer: return "Apply a balanced equalizer preset."
        case .dynamicNormalize: return "Even out volume dynamically."
        case .loudNormalize: return "Normalize perceived loudness."
        case .stereoWiden: return "Add delay for wider stereo."
        case .extraStereo: return "Increase stereo separation."
        case .speechIsolation: return "Improve speech in noisy files."
        case .speechNormalize: return "Even out spoken volume."
        case .noiseReduction: return "Mild broadband noise reduction."
        case .lowerPitch: return "Lower pitch without changing tempo."
        case .raisePitch: return "Raise pitch without changing tempo."
        case .chorus: return "Apply a mild chorus effect."
        case .reverb: return "Apply a mild reverb effect."
        }
    }

    var filterNames: String {
        switch self {
        case .firequalizer: return "firequalizer"
        case .dynamicNormalize: return "dynaudnorm"
        case .loudNormalize: return "loudnorm"
        case .stereoWiden: return "stereowiden"
        case .extraStereo: return "extrastereo"
        case .speechIsolation: return "lowpass + highpass + compand"
        case .speechNormalize: return "speechnorm"
        case .noiseReduction: return "afftdn"
        case .lowerPitch: return "asetrate + aresample + atempo"
        case .raisePitch: return "asetrate + aresample + atempo"
        case .chorus: return "chorus"
        case .reverb: return "aecho"
        }
    }
}

private struct MediaAnalysis {
    let url: URL
    let kind: MediaKind
    var width: Int?
    var height: Int?
    var duration: TimeInterval?
    var frameRate: Double?
    var bitrateKbps: Int?
    var codec: String?
    var sampleRate: Double?
    var channels: Int?
    var frameCount: Int?
    var isAnimated = false
    var fileSizeBytes: Int64 = 0

    var detailLine: String {
        let size = ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
        switch kind {
        case .video:
            let dimensions = dimensionText ?? "Video"
            let codecText = codec ?? url.pathExtension.uppercased()
            return "\(dimensions) - \(codecText) - \(size)"
        case .image:
            let dimensions = dimensionText ?? "Image"
            let animation = isAnimated ? "Animated \(frameCount ?? 0) frames" : "Static"
            return "\(dimensions) - \(animation) - \(size)"
        case .audio:
            let rate = sampleRate.map { "\(Int($0 / 1000)) kHz" } ?? "Audio"
            let channelText = channels == 1 ? "mono" : "stereo"
            let bitText = bitrateKbps.map { "\($0) kbps" } ?? url.pathExtension.uppercased()
            return "\(rate) - \(channelText) - \(bitText) - \(size)"
        }
    }

    private var dimensionText: String? {
        guard let width, let height else { return nil }
        return "\(width)x\(height)"
    }
}

private struct CompressionSuggestion {
    let kind: MediaKind
    let resolution: String
    let frameRateLabel: String
    let bitrateMode: String
    let bitrateKbps: Int
    let quality: Int
    let sampleRateLabel: String
    let channelsLabel: String
    let preserveAnimation: Bool
    let summary: String
    let confidence: String
    let chips: [String]

    var queueLine: String {
        switch kind {
        case .video:
            return "Suggested: \(resolution), \(frameRateLabel), \(bitrateKbps / 1000) Mbps"
        case .image:
            return "Suggested: \(resolution), \(quality)% quality"
        case .audio:
            return "Suggested: \(bitrateKbps) kbps, \(sampleRateLabel), \(channelsLabel)"
        }
    }

    static func video(resolution: String, frameRate: String, bitrateKbps: Int, codec: String, reason: String) -> CompressionSuggestion {
        CompressionSuggestion(
            kind: .video,
            resolution: resolution,
            frameRateLabel: frameRate,
            bitrateMode: "Auto",
            bitrateKbps: bitrateKbps,
            quality: 82,
            sampleRateLabel: "44.1 kHz",
            channelsLabel: "Stereo",
            preserveAnimation: false,
            summary: reason,
            confidence: "High confidence",
            chips: [resolution, frameRate, String(format: "%.1f Mbps", Double(bitrateKbps) / 1000), codec]
        )
    }

    static func make(for analysis: MediaAnalysis) -> CompressionSuggestion {
        switch analysis.kind {
        case .video:
            return makeVideoSuggestion(for: analysis)
        case .image:
            return makeImageSuggestion(for: analysis)
        case .audio:
            return makeAudioSuggestion(for: analysis)
        }
    }

    private static func makeVideoSuggestion(for analysis: MediaAnalysis) -> CompressionSuggestion {
        let longEdge = max(analysis.width ?? 0, analysis.height ?? 0)
        let resolution: String
        if longEdge >= 3400 {
            resolution = "4K"
        } else if longEdge >= 2300 {
            resolution = "2K"
        } else if longEdge >= 1600 {
            resolution = "1080p"
        } else if longEdge > 0 {
            resolution = "720p"
        } else {
            resolution = "1080p"
        }

        let bitrate: Int
        switch resolution {
        case "720p": bitrate = 1500
        case "1080p": bitrate = 3000
        case "2K": bitrate = 5000
        default: bitrate = 8000
        }

        let sourceFPS = analysis.frameRate ?? 30
        let recommendedFPS: String
        if sourceFPS > 50 {
            recommendedFPS = "60 fps (lower only)"
        } else if sourceFPS > 30 {
            recommendedFPS = "30 fps (lower only)"
        } else if sourceFPS > 24 {
            recommendedFPS = "30 fps (lower only)"
        } else if sourceFPS > 23.98 {
            recommendedFPS = "24 fps (lower only)"
        } else {
            recommendedFPS = "23.98 fps (lower only)"
        }

        let codec = analysis.codec ?? "Original codec"
        let summary = "Detected \(analysis.detailLine). Frink will preserve \(codec) and lower only resolution or frame rate when useful."
        return video(resolution: resolution, frameRate: recommendedFPS, bitrateKbps: bitrate, codec: codec, reason: summary)
    }

    private static func makeImageSuggestion(for analysis: MediaAnalysis) -> CompressionSuggestion {
        let longEdge = max(analysis.width ?? 0, analysis.height ?? 0)
        let resolution: String
        if longEdge >= 3400 {
            resolution = "4K"
        } else if longEdge >= 2300 {
            resolution = "2K"
        } else if longEdge >= 1600 {
            resolution = "1080p"
        } else if longEdge > 0 {
            resolution = "Original"
        } else {
            resolution = "Original"
        }

        let ext = analysis.url.pathExtension.lowercased()
        let quality = ["png", "gif"].contains(ext) ? 100 : (analysis.fileSizeBytes > 8_000_000 ? 78 : 84)
        let summary = analysis.isAnimated
            ? "Detected animation, so Frink will preserve frames and timeline while compressing each frame."
            : "Detected a static image and selected a quality target that avoids visible degradation."

        return CompressionSuggestion(
            kind: .image,
            resolution: resolution,
            frameRateLabel: "30 fps (lower only)",
            bitrateMode: "Auto",
            bitrateKbps: 3000,
            quality: quality,
            sampleRateLabel: "44.1 kHz",
            channelsLabel: "Stereo",
            preserveAnimation: analysis.isAnimated,
            summary: summary,
            confidence: analysis.width == nil ? "Extension based" : "High confidence",
            chips: [resolution, "\(quality)% quality", analysis.isAnimated ? "Preserve animation" : "Static image", analysis.url.pathExtension.uppercased()]
        )
    }

    private static func makeAudioSuggestion(for analysis: MediaAnalysis) -> CompressionSuggestion {
        let sourceBitrate = analysis.bitrateKbps ?? 160
        let bitrate = min(sourceBitrate, sourceBitrate <= 96 ? sourceBitrate : 160)
        let sampleRate = analysis.sampleRate ?? 44_100
        let sampleRateLabel = sampleRate <= 8_000 ? "8 kHz" :
            sampleRate <= 11_025 ? "11.025 kHz" :
            sampleRate <= 16_000 ? "16 kHz" :
            sampleRate <= 22_050 ? "22.05 kHz" :
            sampleRate <= 32_000 ? "32 kHz" :
            sampleRate <= 44_100 ? "44.1 kHz" : "48 kHz"
        let channelsLabel = analysis.channels == 1 ? "Mono" : "Stereo"

        return CompressionSuggestion(
            kind: .audio,
            resolution: "Original",
            frameRateLabel: "30 fps (lower only)",
            bitrateMode: "Auto",
            bitrateKbps: bitrate,
            quality: 82,
            sampleRateLabel: sampleRateLabel,
            channelsLabel: channelsLabel,
            preserveAnimation: false,
            summary: "Detected \(analysis.detailLine). The suggestion avoids upscaling low-quality source audio.",
            confidence: analysis.sampleRate == nil ? "Extension based" : "High confidence",
            chips: ["\(bitrate) kbps", sampleRateLabel, channelsLabel, "No upscaling"]
        )
    }
}

private enum MediaDetector {
    static func detectKind(for url: URL) -> MediaKind {
        let ext = url.pathExtension.lowercased()
        if ["mov", "mp4", "m4v", "webm", "avi", "mkv"].contains(ext) {
            return .video
        }
        if ["jpg", "jpeg", "png", "heic", "heif", "webp", "avif", "gif", "tiff"].contains(ext) {
            return .image
        }
        if ["mp3", "m4a", "aac", "flac", "wav", "ogg", "aif", "aiff", "opus"].contains(ext) {
            return .audio
        }

        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            if type.conforms(to: .movie) { return .video }
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .audio) { return .audio }
        }

        return .video
    }

    static func analyze(url: URL, kind: MediaKind) async -> MediaAnalysis {
        var analysis = MediaAnalysis(url: url, kind: kind)
        analysis.fileSizeBytes = fileSize(for: url)

        switch kind {
        case .video:
            populateVideoAnalysis(&analysis, url: url)
        case .image:
            populateImageAnalysis(&analysis, url: url)
        case .audio:
            populateAudioAnalysis(&analysis, url: url)
        }

        return analysis
    }

    private static func populateVideoAnalysis(_ analysis: inout MediaAnalysis, url: URL) {
        let asset = AVURLAsset(url: url)
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
            analysis.width = Int(abs(size.width).rounded())
            analysis.height = Int(abs(size.height).rounded())
            analysis.frameRate = Double(videoTrack.nominalFrameRate)
            analysis.bitrateKbps = videoTrack.estimatedDataRate > 0 ? Int(videoTrack.estimatedDataRate / 1000) : nil
            analysis.codec = codecName(from: videoTrack.formatDescriptions.first)
        }
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            analysis.channels = audioChannels(from: audioTrack.formatDescriptions.first)
        }
        analysis.duration = CMTimeGetSeconds(asset.duration)
    }

    private static func populateImageAnalysis(_ analysis: inout MediaAnalysis, url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        analysis.frameCount = CGImageSourceGetCount(source)
        analysis.isAnimated = (analysis.frameCount ?? 0) > 1

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return }
        analysis.width = properties[kCGImagePropertyPixelWidth] as? Int
        analysis.height = properties[kCGImagePropertyPixelHeight] as? Int
    }

    private static func populateAudioAnalysis(_ analysis: inout MediaAnalysis, url: URL) {
        let asset = AVURLAsset(url: url)
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            analysis.bitrateKbps = audioTrack.estimatedDataRate > 0 ? Int(audioTrack.estimatedDataRate / 1000) : nil
            analysis.sampleRate = audioSampleRate(from: audioTrack.formatDescriptions.first)
            analysis.channels = audioChannels(from: audioTrack.formatDescriptions.first)
            analysis.codec = codecName(from: audioTrack.formatDescriptions.first)
        }
        analysis.duration = CMTimeGetSeconds(asset.duration)
    }

    private static func fileSize(for url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    private static func codecName(from description: Any?) -> String? {
        guard let description else { return nil }
        let formatDescription = description as! CMFormatDescription
        let codec = CMFormatDescriptionGetMediaSubType(formatDescription)
        let code = String(format: "%c%c%c%c",
                          (codec >> 24) & 0xff,
                          (codec >> 16) & 0xff,
                          (codec >> 8) & 0xff,
                          codec & 0xff)
        switch code.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "avc1": return "H.264"
        case "hvc1", "hev1": return "HEVC"
        case "vp09": return "VP9"
        case "av01": return "AV1"
        case "mp4a": return "AAC"
        default: return code
        }
    }

    private static func audioSampleRate(from description: Any?) -> Double? {
        guard let description else { return nil }
        let formatDescription = description as! CMAudioFormatDescription
        return CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee.mSampleRate
    }

    private static func audioChannels(from description: Any?) -> Int? {
        guard let description else { return nil }
        let formatDescription = description as! CMAudioFormatDescription
        return Int(CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee.mChannelsPerFrame ?? 0)
    }
}

private final class BatchQueueModel: ObservableObject {
    @Published var items: [QueueItem] = []
    @Published var latestSuggestion: CompressionSuggestion?
    @Published var recommendationVersion = 0

    var hasActiveJobs: Bool {
        items.contains { $0.progress > 0 && $0.progress < 1 }
    }

    var allItemsComplete: Bool {
        !items.isEmpty && items.allSatisfy { $0.progress >= 1 }
    }

    var overallProgress: Double {
        guard !items.isEmpty else { return 0 }
        return items.map(\.progress).reduce(0, +) / Double(items.count)
    }

    var etaText: String {
        hasActiveJobs ? "Calculating" : "Not running"
    }

    func chooseFiles(preferredKind: MediaKind, preferredTool: MediaTool? = nil) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = preferredKind.allowedContentTypes
        panel.prompt = "Add"

        guard panel.runModal() == .OK else { return }
        addURLs(panel.urls, preferredKind: preferredKind, preferredTool: preferredTool)
    }

    func addDroppedItems(providers: [NSItemProvider], preferredKind: MediaKind? = nil, preferredTool: MediaTool? = nil) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }

                if let url {
                    DispatchQueue.main.async {
                        self?.addURLs([url], preferredKind: preferredKind, preferredTool: preferredTool)
                    }
                }
            }
        }
    }

    func remove(_ item: QueueItem) {
        items.removeAll { $0.id == item.id }
    }

    func startProcessing(tool: MediaTool) {
        guard !items.isEmpty, !hasActiveJobs else { return }

        for index in items.indices {
            items[index].progress = 0
            items[index].status = "Queued"
            items[index].outputURL = nil
            items[index].processedToolTitle = nil
        }

        Task {
            var lastSuccessfulURL: URL? = nil
            for item in await MainActor.run(body: { items }) {
                await MainActor.run {
                    if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                        self.items[index].progress = 0.03
                        self.items[index].status = "Processing"
                    }
                }

                do {
                    let processingTool = Self.processingTool(for: item, fallbackTool: tool)
                    let outputURL = try Self.outputURL(for: item, tool: processingTool)
                    
                    await MainActor.run {
                        if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                            self.items[index].processedToolTitle = processingTool.title
                            self.items[index].outputURL = outputURL
                        }
                    }

                    if processingTool == .imageCompression {
                        var options = ImageCompressionOptions()
                        options.format = ImageFormat(fileExtension: outputURL.pathExtension)
                        if let suggestion = item.suggestion, suggestion.kind == .image {
                            options.resolution = OutputResolution(label: suggestion.resolution)
                            options.quality = suggestion.quality
                            options.preserveAnimation = suggestion.preserveAnimation
                        }
                        try await FFmpegManager.shared.compressImage(input: item.url, output: outputURL, options: options)
                    } else if processingTool == .imageConversion {
                        let format = ImageFormat(fileExtension: outputURL.pathExtension)
                        try await FFmpegManager.shared.convertImage(input: item.url, output: outputURL, format: format)
                    } else {
                        let job = try Self.job(for: item, tool: processingTool, output: outputURL)
                        _ = try await FFmpegManager.shared.run(job) { progress in
                            guard progress.percent > 0 else { return }
                            Task { @MainActor [weak self] in
                                if let index = self?.items.firstIndex(where: { $0.id == item.id }) {
                                    self?.items[index].progress = max(0.05, min(progress.percent, 0.98))
                                    self?.items[index].status = "Processing"
                                }
                            }
                        }
                    }

                    await MainActor.run {
                        if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                            self.items[index].progress = 1
                            self.items[index].status = "Complete"
                        }
                    }
                    lastSuccessfulURL = outputURL
                } catch {
                    await MainActor.run {
                        if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                            self.items[index].progress = 0
                            self.items[index].status = "Failed: \(error.localizedDescription)"
                        }
                    }
                }
            }

            if let lastURL = lastSuccessfulURL {
                DispatchQueue.main.async {
                    NSWorkspace.shared.activateFileViewerSelecting([lastURL])
                }
            }
        }
    }

    private func addURLs(_ urls: [URL], preferredKind: MediaKind? = nil, preferredTool: MediaTool? = nil) {
        for url in urls {
            let kind = preferredKind ?? MediaDetector.detectKind(for: url)
            let itemID = UUID()
            let requestedTool = Self.validTool(preferredTool, for: kind)
            let placeholder = QueueItem(id: itemID, url: url, name: url.lastPathComponent, detail: "Detecting...", kind: kind, progress: 0, status: "Detecting", suggestion: nil, requestedTool: requestedTool, duration: nil)
            items.append(placeholder)

            Task {
                let analysis = await MediaDetector.analyze(url: url, kind: kind)
                let suggestion = CompressionSuggestion.make(for: analysis)

                await MainActor.run {
                    if let index = self.items.firstIndex(where: { $0.id == itemID }) {
                        self.items[index] = QueueItem(
                            id: itemID,
                            url: url,
                            name: url.lastPathComponent,
                            detail: analysis.detailLine,
                            kind: analysis.kind,
                            progress: 0,
                            status: "Queued",
                            suggestion: suggestion,
                            requestedTool: Self.validTool(requestedTool, for: analysis.kind),
                            duration: analysis.duration
                        )
                    }
                    self.latestSuggestion = suggestion
                    self.recommendationVersion += 1
                }
            }
        }
    }

    private static func processingTool(for item: QueueItem, fallbackTool: MediaTool) -> MediaTool {
        if let requestedTool = validTool(item.requestedTool, for: item.kind) {
            return requestedTool
        }

        return validTool(fallbackTool, for: item.kind) ?? MediaTool.defaultTool(for: item.kind)
    }

    private static func validTool(_ tool: MediaTool?, for kind: MediaKind) -> MediaTool? {
        guard let tool, tool.kind == kind else { return nil }
        return tool
    }

    private static func outputURL(for item: QueueItem, tool: MediaTool) throws -> URL {
        let source = item.url
        let directory = source.deletingLastPathComponent()
        let baseName = source.deletingPathExtension().lastPathComponent
        let ext = outputExtension(for: item, tool: tool)
        var candidate = directory.appendingPathComponent("\(baseName)-frink").appendingPathExtension(ext)
        var counter = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)-frink-\(counter)").appendingPathExtension(ext)
            counter += 1
        }

        return candidate
    }

    private static func outputExtension(for item: QueueItem, tool: MediaTool) -> String {
        switch tool {
        case .videoCompression:
            let sourceExt = item.url.pathExtension.lowercased()
            return ["mov", "mp4", "m4v"].contains(sourceExt) ? sourceExt : "mp4"
        case .videoConversion, .videoAudioEffects:
            return "mp4"
        case .videoAnimation:
            return "webp"
        case .extractAudio:
            return "m4a"
        case .imageCompression:
            let sourceExt = item.url.pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "webp", "gif", "heic", "avif"].contains(sourceExt) ? sourceExt : "jpg"
        case .imageConversion:
            return "jpg"
        case .audioCompression, .audioConversion, .audioEffects:
            return "m4a"
        case .audioToText:
            return "txt"
        case .textToSpeech:
            return "wav"
        }
    }

    private static func job(for item: QueueItem, tool: MediaTool, output: URL) throws -> FFmpegJob {
        switch tool {
        case .videoCompression:
            var options = VideoCompressionOptions()
            if let suggestion = item.suggestion, suggestion.kind == .video {
                options.resolution = OutputResolution(label: suggestion.resolution)
                options.frameRate = Double(suggestion.frameRateLabel.components(separatedBy: " ").first ?? "")
                options.bitrateMode = suggestion.bitrateMode == "Custom" ? .custom : .auto
                options.customBitrateKbps = suggestion.bitrateKbps
            }
            return .videoCompression(input: item.url, output: output, options: options, expectedDuration: item.duration)
        case .videoConversion:
            return .videoConversion(input: item.url, output: output, options: VideoConversionOptions(), expectedDuration: item.duration)
        case .videoAnimation:
            return .videoAnimation(input: item.url, output: output, options: AnimationOptions(), expectedDuration: item.duration)
        case .videoAudioEffects:
            return .videoAudioEffects(input: item.url, output: output, effects: [.dynamicNormalize], expectedDuration: item.duration)
        case .extractAudio:
            return .extractAudio(input: item.url, output: output, format: .m4a, expectedDuration: item.duration)
        case .imageCompression:
            var options = ImageCompressionOptions()
            options.format = ImageFormat(fileExtension: output.pathExtension)
            if let suggestion = item.suggestion, suggestion.kind == .image {
                options.resolution = OutputResolution(label: suggestion.resolution)
                options.quality = suggestion.quality
                options.preserveAnimation = suggestion.preserveAnimation
            }
            return .imageCompression(input: item.url, output: output, options: options)
        case .imageConversion:
            return .imageConversion(input: item.url, output: output, format: .jpeg)
        case .audioCompression:
            var options = AudioCompressionOptions()
            if let suggestion = item.suggestion, suggestion.kind == .audio {
                options.bitrateKbps = suggestion.bitrateKbps
                options.sampleRateHz = AudioSampleRate(label: suggestion.sampleRateLabel).hertz
                options.channels = suggestion.channelsLabel == "Mono" ? .mono : .stereo
            }
            return .audioCompression(input: item.url, output: output, options: options, expectedDuration: item.duration)
        case .audioConversion:
            return .audioConversion(input: item.url, output: output, format: .m4a, expectedDuration: item.duration)
        case .audioEffects:
            return .audioEffects(input: item.url, output: output, effects: [.dynamicNormalize], expectedDuration: item.duration)
        case .audioToText, .textToSpeech:
            throw ProcessingError.unsupportedTool(tool.title)
        }
    }
}

private struct QueueItem: Identifiable {
    let id: UUID
    let url: URL
    let name: String
    let detail: String
    let kind: MediaKind
    var progress: Double
    var status: String
    let suggestion: CompressionSuggestion?
    let requestedTool: MediaTool?
    var outputURL: URL?
    var processedToolTitle: String?
    let duration: TimeInterval?

    init(id: UUID = UUID(), url: URL, name: String, detail: String, kind: MediaKind, progress: Double, status: String, suggestion: CompressionSuggestion?, requestedTool: MediaTool? = nil, outputURL: URL? = nil, processedToolTitle: String? = nil, duration: TimeInterval? = nil) {
        self.id = id
        self.url = url
        self.name = name
        self.detail = detail
        self.kind = kind
        self.progress = progress
        self.status = status
        self.suggestion = suggestion
        self.requestedTool = requestedTool
        self.outputURL = outputURL
        self.processedToolTitle = processedToolTitle
        self.duration = duration
    }
}

private enum ProcessingError: LocalizedError {
    case unsupportedTool(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedTool(tool):
            return "\(tool) is not connected to a production backend yet."
        }
    }
}

private extension OutputResolution {
    init(label: String) {
        switch label {
        case "720p": self = .p720
        case "1080p": self = .p1080
        case "2K": self = .p2k
        case "4K": self = .p4k
        default: self = .original
        }
    }
}

private extension ImageFormat {
    init(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "png": self = .png
        case "webp": self = .webp
        case "heic": self = .heic
        case "avif": self = .avif
        case "gif": self = .gif
        default: self = .jpeg
        }
    }
}

private struct AudioSampleRate {
    let hertz: Int

    init(label: String) {
        switch label {
        case "8 kHz": hertz = 8_000
        case "11.025 kHz": hertz = 11_025
        case "16 kHz": hertz = 16_000
        case "22.05 kHz": hertz = 22_050
        case "32 kHz": hertz = 32_000
        case "48 kHz": hertz = 48_000
        default: hertz = 44_100
        }
    }
}

private enum FrinkTheme {
    static func background(for colorScheme: ColorScheme?) -> some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.05, blue: 0.06), Color(red: 0.1, green: 0.1, blue: 0.09)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.94, blue: 0.86), Color(red: 0.91, green: 0.94, blue: 0.91)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct GrandmaModeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isGrandmaMode: Bool {
        get { self[GrandmaModeKey.self] }
        set { self[GrandmaModeKey.self] = newValue }
    }
}
