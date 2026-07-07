import AppKit

/// Fires when a remote session most likely just started. There is no public
/// "someone connected via Jump Desktop / Screen Sharing" API, so we listen to
/// the events that accompany a connect in practice: displays waking, the
/// session unlocking, and display reconfiguration (headless Macs get a virtual
/// display plugged in by the remote-desktop host).
@MainActor
final class ConnectionMonitor {
    enum Trigger {
        case wake
        case unlock
        case displayChange
    }

    var onTrigger: ((Trigger) -> Void)?

    // App-lifetime object: observers are registered once and never removed.
    init() {
        self.observe(
            center: NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.screensDidWakeNotification,
            trigger: .wake)
        self.observe(
            center: NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            trigger: .wake)
        self.observe(
            center: NotificationCenter.default,
            name: NSApplication.didChangeScreenParametersNotification,
            trigger: .displayChange)

        _ = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main)
        { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onTrigger?(.unlock)
            }
        }
    }

    private func observe(center: NotificationCenter, name: Notification.Name, trigger: Trigger) {
        _ = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onTrigger?(trigger)
            }
        }
    }
}
