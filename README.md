# frink

> Native, hardware-accelerated macOS batch utility for ultra-fast video, audio, and image compression and conversion.

[![Platform macOS](https://img.shields.io/badge/platform-macOS%2012.0+-blue.svg)](https://developer.apple.com/macos/)
[![Architecture Universal](https://img.shields.io/badge/architecture-Universal%20(Apple%20Silicon%20%2F%20Intel)-orange.svg)](https://developer.apple.com/macos/)
[![Engine FFmpeg 8.1](https://img.shields.io/badge/engine-FFmpeg%208.1-green.svg)](https://ffmpeg.org/)
[![Listing itch.io](https://img.shields.io/badge/store-itch.io-ff2453.svg)](https://gcmayson.itch.io/frink)

---

## 🎮 Get Frink

Download the official universal macOS app installer directly from itch.io:

👉 **[Download on itch.io](https://gcmayson.itch.io/frink)**

---

## ✨ Features

### 🎬 Video Tools (Amber Theme)
*   **Video Compression**: Batch compress MP4, MOV, and M4V clips with optimal quality settings.
*   **Video Conversion**: High-speed format remuxing and transcoding.
*   **Video to Animation**: Convert video frames into highly-optimized WebP, AVIF, or legacy GIF animations.
*   **Audio Extractor**: Strip and save audio soundtracks in the format of your choice.

### 🖼️ Image Tools (Pink Theme)
*   **Image Compression**: Reduce file footprints with MozJPEG and OxiPNG decoders while guarding pixel density.
*   **Format Conversion**: Convert images instantly between JPEG, PNG, WebP, AVIF, HEIC, and GIF.
*   **Animation Protection**: Automatically detects animated frames to keep motion intact.

### 🔊 Audio Tools (Green Theme)
*   **Audio Compression**: Control bitrates, sample rates, and channel layouts manually.
*   **Audio Conversion**: Lossless paths for converting between MP3, M4A, FLAC, and WAV.
*   **Upscale Prevention**: Smart guards to block artificial quality upscaling.

### 👵 Grandma Mode (Yellow Theme)
*   **Zero Configuration**: A simplified drag-and-drop screen. Just drop files, click start, and get instant compression results without tweaking bitrates or codecs.

---

## 🚀 Installation & Ejection Prompt

Frink is packaged as a standard macOS Disk Image (`.dmg`):
1. Mount the downloaded `Frink.dmg`.
2. Drag `Frink.app` into your **Applications** folder.
3. Upon launching from your Applications folder for the first time, Frink's post-installation cleaner will automatically detect the mounted installer, show a prompt, unmount (eject) the disk image, and move the original `.dmg` installer file to the **Trash** for a clean workspace.

---

## 🛠️ Development & Packaging

To compile a universal macOS release build and package it locally:

1. Clone this repository:
   ```bash
   git clone https://github.com/morpson/frink.git
   cd frink
   ```
2. Build the app bundle and packages (creates both `.dmg` and `.zip` outputs):
   ```bash
   ./scripts/build-dmg.sh
   ```
   Outputs will be placed inside `dist/gumroad/`.

> [!NOTE]
> By default, the packaging script uses macOS ad-hoc code-signing (`-`) to satisfy security runtime validation requirements.
