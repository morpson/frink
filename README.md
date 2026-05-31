<p align="center">
  <img src="docs/assets/appicon.png" width="128" height="128" alt="frink app icon">
</p>

# frink

> Native, hardware-accelerated macOS batch utility for ultra-fast video, audio, and image compression and conversion.

**[Download on itch.io](https://gcmayson.itch.io/frink)**

---

## Features

*   **🎬 Video Tools**: Compress MP4, MOV, and M4V; convert streams; build WebP, AVIF, or GIF animations; extract audio.
*   **🖼️ Image Tools**: Compress files losslessly (MozJPEG / OxiPNG); convert between JPEG, PNG, WebP, AVIF, HEIC, and GIF.
*   **🔊 Audio Tools**: Adjust bitrates, sample rates, and channel layouts with upscale protection; convert between MP3, M4A, FLAC, and WAV.
*   **👵 Grandma Mode**: Simplified drag-and-drop compression screen with zero configuration.

---

## Installation & DMG Ejection

1. Mount the downloaded `Frink.dmg`.
2. Drag `Frink.app` into your **Applications** folder.
3. Upon launch, Frink automatically ejects the disk image and moves the original `.dmg` file to the **Trash**.

---

## Development

Build the universal release binary and package it into a `.dmg` and `.zip`:
```bash
./scripts/build-dmg.sh
```
Outputs are placed inside `dist/gumroad/`.
