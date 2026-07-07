import AppKit
import Combine
import SwiftUI

/// Click-through, always-on-top panels shared by the overlay and the splash.
enum OverlayPanelFactory {
    @MainActor
    static func makePanel(for screen: NSScreen, level: NSWindow.Level) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.level = level
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .none
        // Visible on every Space, next to fullscreen apps, and pinned during Mission Control.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return panel
    }
}

/// Owns one overlay panel per screen and keeps them alive across display
/// reconfiguration. The SwiftUI content observes AppSettings directly, so the
/// controller only manages panel lifecycle and overall visibility.
@MainActor
final class OverlayController {
    private let settings: AppSettings
    private var panels: [NSPanel] = []
    private var cancellable: AnyCancellable?
    // App-lifetime object: observers are registered once and never removed.

    init(settings: AppSettings) {
        self.settings = settings
        self.rebuildPanels()

        // objectWillChange fires before the write lands; hop once so we read
        // the post-change values.
        self.cancellable = settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.applyVisibility()
                }
            }

        _ = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main)
        { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuildPanels()
            }
        }
    }

    private var shouldBeVisible: Bool {
        self.settings.overlaysEnabled
            && (self.settings.frameEnabled || self.settings.tagEnabled || self.settings.watermarkEnabled)
    }

    func rebuildPanels() {
        for panel in self.panels {
            panel.close()
        }
        self.panels = NSScreen.screens.map { screen in
            // .statusBar floats above app windows and fullscreen content but
            // stays below pop-up menus. Anything higher (.screenSaver) blocks
            // NSMenu from opening at all.
            let panel = OverlayPanelFactory.makePanel(for: screen, level: .statusBar)
            panel.contentView = NSHostingView(rootView: OverlayView(settings: self.settings))
            panel.setFrame(screen.frame, display: true)
            return panel
        }
        self.applyVisibility()
    }

    func applyVisibility() {
        let visible = self.shouldBeVisible
        for panel in self.panels {
            if visible {
                if !panel.isVisible {
                    panel.orderFrontRegardless()
                }
            } else {
                panel.orderOut(nil)
            }
        }
    }
}
