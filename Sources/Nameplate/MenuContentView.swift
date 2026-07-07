import SwiftUI

@MainActor
struct MenuContentView: View {
    @ObservedObject var settings: AppSettings
    let services: AppServices

    var body: some View {
        let identity = self.settings.identity

        Text("\(identity.glyph.isEmpty ? "" : identity.glyph + " ")\(identity.name)")

        Divider()

        Toggle("Show overlays", isOn: self.$settings.overlaysEnabled)

        Toggle("Frame", isOn: self.$settings.frameEnabled)
        Toggle("Name tag", isOn: self.$settings.tagEnabled)
        Toggle("Watermark", isOn: self.$settings.watermarkEnabled)

        Divider()

        Button("Show splash") {
            self.services.showSplash(force: true)
        }

        Divider()

        Button("Settings…") {
            self.services.showSettings()
        }
        .keyboardShortcut(",")

        Button("Quit Nameplate") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
