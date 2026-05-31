# Vendored FFmpeg

Frink bundles a universal macOS FFmpeg 8.1 binary built from the static macOS
release binaries published at:

https://ffmpeg.martin-riedl.de/

The checked-in binaries under `macos-universal/` were produced with `lipo` from
the separate amd64 and arm64 downloads below.

## Inputs

- `ffmpeg` amd64:
  `https://ffmpeg.martin-riedl.de/download/macos/amd64/1774556648_8.1/ffmpeg.zip`
  SHA-256: `eaa8aa619f8eccc7f548a730097f5d299cbf2d418888421c137557344d821130`
- `ffmpeg` arm64:
  `https://ffmpeg.martin-riedl.de/download/macos/arm64/1774549676_8.1/ffmpeg.zip`
  SHA-256: `cc3a7e0cce36c5eca6c17eeb93830984c657637a8e710dc98f19c8051201fa3a`
- `ffprobe` amd64:
  `https://ffmpeg.martin-riedl.de/download/macos/amd64/1774556648_8.1/ffprobe.zip`
  SHA-256: `221bd0716dc15daf5745c5503773e5c23264c10c5ea956aa17ef492bbc0b0ac7`
- `ffprobe` arm64:
  `https://ffmpeg.martin-riedl.de/download/macos/arm64/1774549676_8.1/ffprobe.zip`
  SHA-256: `fd2e6b7fad9c9aa2bec17c0d7211b5afcc00b4b5c9b63c120985e80c3c198af6`

## Rebuild

```bash
lipo -create amd64/ffmpeg arm64/ffmpeg -output macos-universal/ffmpeg
lipo -create amd64/ffprobe arm64/ffprobe -output macos-universal/ffprobe
chmod +x macos-universal/ffmpeg macos-universal/ffprobe
```

The bundled FFmpeg build is GPL because its configuration includes
`--enable-gpl`. Keep the license files in `vendor/ffmpeg/licenses/` in sync with
the bundled FFmpeg version.
