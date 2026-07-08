import AppKit
import NameplateSpaces

/// Tracks which Space (virtual desktop) is active on each display. The public
/// notification only signals *that* a switch happened; the actual Space comes
/// from SpaceQuery's private-API snapshot. App-lifetime object: observers are
/// intentionally never removed.
@MainActor
final class SpaceMonitor: ObservableObject {
    static let isSupported = SpaceQuery.isSupported

    /// Keyed by display UUID.
    @Published private(set) var displays: [String: DisplaySpaces] = [:]

    /// Display UUIDs whose active Space changed in the latest refresh.
    var onActiveSpaceChange: (@MainActor ([String]) -> Void)?

    init() {
        self.refresh()

        _ = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main)
        { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }

        _ = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main)
        { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    func refresh() {
        guard Self.isSupported else { return }
        let previous = self.displays
        self.displays = Dictionary(
            SpaceQuery.snapshot().map { ($0.displayUUID, $0) },
            uniquingKeysWith: { first, _ in first })

        let changed = self.displays.compactMap { uuid, display -> String? in
            guard let before = previous[uuid], before.current.uuid != display.current.uuid else {
                return nil
            }
            return uuid
        }
        if !changed.isEmpty {
            self.onActiveSpaceChange?(changed)
        }
    }

    func current(onDisplay uuid: String?) -> SpaceInfo? {
        if let uuid, let display = self.displays[uuid] {
            return display.current
        }
        // With "Displays have separate Spaces" off, the window server reports
        // one shared Space set (identifier "Main", mapped to the primary
        // display's UUID) — it applies to every screen.
        if self.displays.count == 1 {
            return self.displays.values.first?.current
        }
        return nil
    }
}

extension NSScreen {
    /// Window-server display UUID, the key SpaceMonitor uses.
    var displayUUID: String? {
        guard let number = self.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return SpaceQuery.displayUUID(for: number.uint32Value)
    }
}
