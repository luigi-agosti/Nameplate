import AppKit
import NameplateCore
import notify
import SwiftUI

@main
@MainActor
struct NameplateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings: AppSettings
    @StateObject private var services: AppServices

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _services = StateObject(wrappedValue: AppServices(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra(isInserted: self.menuBarInserted) {
            MenuContentView(settings: self.settings, services: self.services)
        } label: {
            StatusLabel(settings: self.settings)
        }
    }

    private var menuBarInserted: Binding<Bool> {
        Binding(
            get: { !self.settings.hideMenuBarIcon },
            set: { self.settings.hideMenuBarIcon = !$0 })
    }
}

/// Long-lived controllers, wired together once per app lifetime.
@MainActor
final class AppServices: ObservableObject {
    private let settings: AppSettings
    private var overlay: OverlayController?
    private var splash: SplashController?
    private var monitor: ConnectionMonitor?
    private var settingsWindow: SettingsWindowController?

    init(settings: AppSettings) {
        self.settings = settings
        // App.init runs before NSApplication finishes launching; creating
        // NSPanels that early wedges SwiftUI's scene setup (menus never open,
        // Settings never appears). Defer to the first run-loop turn.
        DispatchQueue.main.async {
            self.start()
        }
    }

    func showSplash(force: Bool = false) {
        self.splash?.show(force: force)
    }

    func showSettings() {
        if self.settingsWindow == nil {
            self.settingsWindow = SettingsWindowController(settings: self.settings, services: self)
        }
        self.settingsWindow?.show()
    }

    private func start() {
        guard self.monitor == nil else { return }
        let settings = self.settings
        self.overlay = OverlayController(settings: settings)
        self.splash = SplashController(settings: settings)
        let monitor = ConnectionMonitor()
        self.monitor = monitor

        monitor.onTrigger = { [weak self, weak settings] trigger in
            guard let self, let settings else { return }
            let wanted = switch trigger {
            case .wake: settings.splashOnWake
            case .unlock: settings.splashOnUnlock
            case .displayChange: settings.splashOnDisplayChange
            }
            if wanted {
                self.splash?.show()
            }
        }

        _ = NotificationCenter.default.addObserver(
            forName: .nameplateShowSplash,
            object: nil,
            queue: .main)
        { [weak self] _ in
            MainActor.assumeIsolated {
                self?.splash?.show(force: true)
            }
        }

        _ = NotificationCenter.default.addObserver(
            forName: .nameplateOpenSettings,
            object: nil,
            queue: .main)
        { [weak self] _ in
            MainActor.assumeIsolated {
                self?.showSettings()
            }
        }

        // Scripting hook that works everywhere, no app activation needed:
        //   notifyutil -p com.steipete.nameplate.splash
        self.registerDarwinTrigger(name: "com.steipete.nameplate.splash") { services in
            services.splash?.show(force: true)
        }
        self.registerDarwinTrigger(name: "com.steipete.nameplate.settings") { _ in
            NotificationCenter.default.post(name: .nameplateOpenSettings, object: nil)
        }
    }

    private func registerDarwinTrigger(name: String, action: @escaping @MainActor (AppServices) -> Void) {
        var token: Int32 = 0
        notify_register_dispatch(name, &token, DispatchQueue.main) { [weak self] (_: Int32) in
            MainActor.assumeIsolated {
                guard let self else { return }
                action(self)
            }
        }
    }
}

@MainActor
private struct StatusLabel: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        let identity = self.settings.identity
        HStack(spacing: 4) {
            Image(nsImage: StatusItemIcon.image(for: identity))
            if self.settings.showNameInMenuBar {
                Text(identity.name)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // SwiftUI installs its own kAEGetURL handler and never forwards to
        // application(_:open:) or a MenuBarExtra's onOpenURL. Registering here
        // (after SwiftUI's) replaces it so nameplate:// URLs reach us.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(self.handleGetURL(event:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))

        let firstRunKey = "hasCompletedFirstRun"
        if !UserDefaults.standard.bool(forKey: firstRunKey) {
            UserDefaults.standard.set(true, forKey: firstRunKey)
            // Give the scenes a beat to attach, then greet with Settings.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NotificationCenter.default.post(name: .nameplateOpenSettings, object: nil)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .nameplateOpenSettings, object: nil)
        return false
    }

    @objc private func handleGetURL(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "nameplate" else { return }
        switch url.host() {
        case "splash":
            NotificationCenter.default.post(name: .nameplateShowSplash, object: nil)
        case "settings":
            NotificationCenter.default.post(name: .nameplateOpenSettings, object: nil)
        default:
            break
        }
    }
}
