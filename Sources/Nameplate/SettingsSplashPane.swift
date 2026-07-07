import SwiftUI

@MainActor
struct SplashSettingsPane: View {
    @ObservedObject var settings: AppSettings
    let services: AppServices

    static let splashCommand = "notifyutil -p com.steipete.nameplate.splash"

    var body: some View {
        SettingsPaneLayout {
            SettingsSection(
                "Connect splash",
                subtitle: "Flashes this Mac's name across the screen when a remote session likely just "
                    + "started, then fades out.")
            {
                VStack(alignment: .leading, spacing: 12) {
                    PreferenceToggleRow(
                        title: "Enable splash",
                        subtitle: nil,
                        binding: self.$settings.splashEnabled)
                    LabeledSlider(
                        title: "Duration",
                        value: self.$settings.splashDuration,
                        range: 0.8...4,
                        step: 0.1,
                        format: { String(format: "%.1f s", $0) })
                        .disabled(!self.settings.splashEnabled)
                    Button("Preview splash") {
                        self.services.showSplash(force: true)
                    }
                }
            }

            SettingsSection(
                "Triggers",
                subtitle: "macOS has no public \"remote session started\" event, so Nameplate reacts to its "
                    + "reliable companions. On a headless Mac, the remote host plugging in its virtual "
                    + "display fires the display trigger.")
            {
                VStack(alignment: .leading, spacing: 12) {
                    PreferenceToggleRow(
                        title: "When displays wake",
                        subtitle: nil,
                        binding: self.$settings.splashOnWake)
                    PreferenceToggleRow(
                        title: "When the screen unlocks",
                        subtitle: nil,
                        binding: self.$settings.splashOnUnlock)
                    PreferenceToggleRow(
                        title: "When displays change",
                        subtitle: nil,
                        binding: self.$settings.splashOnDisplayChange)
                }
                .disabled(!self.settings.splashEnabled)
            }

            SettingsSection(
                "Scripting",
                subtitle: "Trigger the splash from anywhere — hook it into your own connect automation.")
            {
                HStack(spacing: 8) {
                    Text(verbatim: Self.splashCommand)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Self.splashCommand, forType: .string)
                    }
                    .controlSize(.small)
                }
            }
        }
    }
}
