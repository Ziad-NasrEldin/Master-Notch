# Building minitap

Xcode build and packaging notes for local development.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac
- Xcode 16 or later

## Build

Open the Xcode project, then build the app target:

```bash
open boringNotch.xcodeproj
```

- Product: `minitap.app`
- Bundle identifier: `ai.minitap.minitap`
- XPC helper: `ai.minitap.minitap.MinitapXPCHelper`
- Spotify callback URL scheme: `minitap://spotify-auth/callback`

## Package

The DMG wrapper expects the renamed app bundle:

```bash
Configuration/dmg/create_dmg.sh /path/to/minitap.app /path/to/minitap.dmg minitap
```

The Sparkle feed URL is `https://www.minitap.ai/appcast.xml`. Host a signed appcast at that URL before shipping updater-enabled builds.

## Contribute

Read [CONTRIBUTING.md](../CONTRIBUTING.md) before opening a pull request.
Keep user-facing copy, bundle identifiers, URL schemes, and app assets aligned with the minitap brand contract in [`boringNotch/models/MinitapBrand.swift`](../boringNotch/models/MinitapBrand.swift).
