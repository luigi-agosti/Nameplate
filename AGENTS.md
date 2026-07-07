# Nameplate — agent notes

- SwiftPM menu bar app, zero dependencies. Building needs full Xcode (SwiftUI macros); if `xcode-select -p` is CommandLineTools, set `DEVELOPER_DIR=/Applications/Xcode.app`.
- Build/test: `swift build`, `swift test`. Bundle: `./Scripts/package_app.sh [debug|release]` (signs Developer ID; `APP_IDENTITY="-"` for ad-hoc).
- Icon: `./Scripts/build_icon.sh` regenerates `Icon.icns` from `Scripts/render_icon.swift`.
- Overlay windows are click-through NSPanels at `.screenSaver` level; splash sits one level above. Controllers in `Sources/Nameplate` are app-lifetime singletons — observers are intentionally never removed.
- `NameplateCore` stays AppKit-free (identity, colors, fleet file) and is the only tested target.
- Version bumps: `version.env`. Changelog: one bullet per entry, one line.
