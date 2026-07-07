import AppKit
import SwiftUI

@MainActor
struct GeneralSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPaneLayout {
            SettingsSection(
                "Startup",
                subtitle: "A branding app only works if it is actually running.")
            {
                PreferenceToggleRow(
                    title: "Start at login",
                    subtitle: "Launch Nameplate automatically when you sign in.",
                    binding: self.$settings.launchAtLogin)
            }

            SettingsSection(
                "Menu bar",
                subtitle: "The colored nameplate in the menu bar is itself a branding layer.")
            {
                VStack(alignment: .leading, spacing: 16) {
                    PreferenceToggleRow(
                        title: "Show name next to icon",
                        subtitle: "Display this Mac's name in the menu bar, not just the colored plate.",
                        binding: self.$settings.showNameInMenuBar)

                    Divider()

                    PreferenceToggleRow(
                        title: "Hide menu bar icon",
                        subtitle: "Keep the overlays without the menu bar item. Open Nameplate again "
                            + "(e.g. from Finder or Spotlight) to get back to Settings.",
                        binding: self.$settings.hideMenuBarIcon)
                }
            }

            SettingsSection(
                "Overlays",
                subtitle: "Master switch, also available from the menu bar.")
            {
                PreferenceToggleRow(
                    title: "Show overlays",
                    subtitle: "Turns the frame, name tag, and watermark off at once.",
                    binding: self.$settings.overlaysEnabled)
            }

            SettingsSection("App") {
                HStack {
                    Text("Remove all overlays and quit.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Quit Nameplate") {
                        NSApp.terminate(nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
