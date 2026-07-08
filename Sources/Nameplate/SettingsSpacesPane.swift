import NameplateCore
import NameplateSpaces
import SwiftUI

@MainActor
struct SpacesSettingsPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var spaces: SpaceMonitor

    var body: some View {
        Form {
            if !SpaceMonitor.isSupported {
                Section {
                    Label {
                        Text("Space detection is unavailable on this macOS version. "
                            + "Per-Space branding needs system interfaces this build "
                            + "could not find.")
                            .font(.callout)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                self.content
            }
        }
        .formStyle(.grouped)
        .onAppear {
            self.spaces.refresh()
        }
    }

    @ViewBuilder
    private var content: some View {
        Section {
            CaptionedToggle(
                title: "Tag Spaces",
                caption: "Give each Mission Control Space its own name and color. "
                    + "Space detection uses unsupported system interfaces and may "
                    + "stop working after a macOS update.",
                isOn: self.$settings.spacesEnabled)
        }

        ForEach(self.sortedDisplays, id: \.displayUUID) { display in
            Section {
                ForEach(display.spaces, id: \.uuid) { space in
                    SpaceRow(
                        settings: self.settings,
                        space: space,
                        isCurrent: display.current.uuid == space.uuid)
                }
            } header: {
                if self.sortedDisplays.count > 1 {
                    Text(self.displayName(for: display.displayUUID))
                } else {
                    Text("Spaces")
                }
            }
            .disabled(!self.settings.spacesEnabled)
        }

        Section {
            CaptionedToggle(
                title: "Space in name tag",
                caption: "Adds the Space as a second segment of the name tag pill.",
                isOn: self.$settings.spaceInTag)
            CaptionedToggle(
                title: "Space in menu bar",
                caption: nil,
                isOn: self.$settings.spaceInMenuBar)
            CaptionedToggle(
                title: "Splash when switching Spaces",
                caption: nil,
                isOn: self.$settings.splashOnSpaceChange)
        } header: {
            Text("Appearance")
        } footer: {
            Text("Spaces are name-only: frame, colors, and watermark always carry "
                + "the machine identity. Untagged Spaces show the machine name alone.")
        }
        .disabled(!self.settings.spacesEnabled)

        Section {
            LabeledContent {
                HStack(spacing: 8) {
                    if self.settings.workspaceFileExists {
                        Button("Reveal") {
                            NSWorkspace.shared
                                .activateFileViewerSelecting([WorkspaceFile.defaultPath])
                        }
                    }
                    Button("Reload") { self.settings.reloadWorkspaces() }
                }
                .controlSize(.small)
            } label: {
                Text(self.settings.workspaceFileExists
                    ? "Stored in ~/.config/nameplate/workspaces.json"
                    : "Saved to ~/.config/nameplate/workspaces.json on first edit")
            }
        } footer: {
            Text("Keyed by short hostname like the fleet file, so one dotfiles-synced "
                + "file covers every Mac.")
        }
    }

    /// Primary display first, then stable by UUID.
    private var sortedDisplays: [DisplaySpaces] {
        let primary = NSScreen.screens.first?.displayUUID
        return self.spaces.displays.values.sorted {
            if $0.displayUUID == primary { return true }
            if $1.displayUUID == primary { return false }
            return $0.displayUUID < $1.displayUUID
        }
    }

    private func displayName(for uuid: String) -> String {
        NSScreen.screens.first { $0.displayUUID == uuid }?.localizedName ?? "Display"
    }
}

/// One Space: desktop number, active marker, editable name.
/// Name edits commit on submit or focus loss — committing every keystroke
/// would churn workspaces.json and fight the file watcher.
@MainActor
private struct SpaceRow: View {
    @ObservedObject var settings: AppSettings
    let space: SpaceInfo
    let isCurrent: Bool

    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(self.isCurrent ? Color.accentColor : Color.secondary.opacity(0.25))
                .frame(width: 6, height: 6)
                .help(self.isCurrent ? "Current Space" : "")

            Text(self.space.index.map(String.init) ?? "–")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)

            if self.space.isFullscreen {
                Text("Full screen app")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                TextField("", text: self.$name, prompt: Text("Untagged"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .focused(self.$nameFocused)
                    .onSubmit { self.commit() }
            }
        }
        .onAppear { self.load() }
        .onChange(of: self.settings.hostWorkspaces) {
            // External edit (file watcher, CLI) — refresh unless mid-edit.
            if !self.nameFocused { self.load() }
        }
        .onChange(of: self.nameFocused) {
            if !self.nameFocused { self.commit() }
        }
    }

    private var entry: WorkspaceEntry? {
        self.settings.workspaceEntry(forSpaceUUID: self.space.uuid, index: self.space.index)
    }

    private func load() {
        self.name = self.entry?.name ?? ""
    }

    private func commit() {
        let trimmedName = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.settings.setWorkspaceEntry(
            WorkspaceEntry(name: trimmedName.isEmpty ? nil : trimmedName),
            forSpaceUUID: self.space.uuid)
    }
}
