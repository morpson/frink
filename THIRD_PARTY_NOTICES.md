# frink Third-Party Notices

frink uses Apple platform frameworks and bundles open source media tools. These projects are not authored by frink.

This file is an attribution index. When distributing a build that bundles any of these binaries, include the corresponding full license text and comply with that project's redistribution terms, including source-code offer requirements where applicable.

## FFmpeg

- Project: FFmpeg
- Website: https://ffmpeg.org/
- Bundled version: 8.1
- Bundled binary source: https://ffmpeg.martin-riedl.de/
- License: GPL 2+ for the bundled build because it was configured with `--enable-gpl`
- Use in frink: media probing, compression, conversion, animation export, audio extraction, and audio filters.
- Notes: frink looks for the bundled `ffmpeg` first and falls back to common Homebrew paths. Full FFmpeg license files are included in `Contents/Resources/FFmpegLicenses` in packaged app builds.

## VideoToolbox

- Project: Apple VideoToolbox
- Website: https://developer.apple.com/documentation/videotoolbox
- License: Apple platform framework
- Use in frink: hardware-accelerated H.264 and HEVC encoding through FFmpeg's `h264_videotoolbox` and `hevc_videotoolbox` encoders.

## libaom

- Project: Alliance for Open Media libaom
- Website: https://aomedia.googlesource.com/aom/
- License: BSD 2-Clause
- Use in frink: AVIF and AV1 encoding through FFmpeg when available.

## libvpx

- Project: WebM Project libvpx
- Website: https://chromium.googlesource.com/webm/libvpx
- License: BSD 3-Clause
- Use in frink: VP9/WebM encoding through FFmpeg when available.

## libwebp

- Project: WebP
- Website: https://chromium.googlesource.com/webm/libwebp
- License: BSD 3-Clause
- Use in frink: animated and still WebP encoding through FFmpeg when available.

## libopus

- Project: Opus Codec
- Website: https://opus-codec.org/
- License: BSD 3-Clause
- Use in frink: WebM/Opus audio encoding through FFmpeg when available.

## libvorbis

- Project: Xiph.Org Vorbis
- Website: https://xiph.org/vorbis/
- License: BSD-style Xiph license
- Use in frink: OGG/Vorbis audio encoding through FFmpeg when available.

## LAME

- Project: LAME MP3 Encoder
- Website: https://lame.sourceforge.io/
- License: LGPL
- Use in frink: MP3 encoding through FFmpeg's `libmp3lame` encoder when available.

## MozJPEG

- Project: MozJPEG
- Website: https://github.com/mozilla/mozjpeg
- License: BSD-style IJG/libjpeg-turbo-derived licenses
- Use in frink: planned high-quality JPEG compression path.

## OxiPNG

- Project: OxiPNG
- Website: https://github.com/shssoichiro/oxipng
- License: MIT
- Use in frink: planned lossless PNG optimization path.

## Zopfli

- Project: Google Zopfli
- Website: https://github.com/google/zopfli
- License: Apache License 2.0
- Use in frink: planned PNG deflate optimization path.

## Apple Speech, AVFoundation, ImageIO, and SwiftUI

- Project: Apple SDK frameworks
- Website: https://developer.apple.com/documentation/
- License: Apple SDK and platform terms
- Use in frink: native macOS UI, file metadata detection, speech transcription, and text-to-speech.
