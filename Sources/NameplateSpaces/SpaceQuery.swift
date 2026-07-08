import CoreGraphics
import Foundation

/// One Space (virtual desktop) as reported by the window server.
public struct SpaceInfo: Equatable, Sendable {
    public let uuid: String
    /// 1-based Mission Control desktop number, counted across displays in
    /// window-server order (matches the user-visible "Desktop N"); nil for
    /// fullscreen-app Spaces.
    public let index: Int?
    public let isFullscreen: Bool

    public init(uuid: String, index: Int?, isFullscreen: Bool) {
        self.uuid = uuid
        self.index = index
        self.isFullscreen = isFullscreen
    }
}

/// The Spaces of one display plus which one is active there.
public struct DisplaySpaces: Equatable, Sendable {
    public let displayUUID: String
    public let current: SpaceInfo
    public let spaces: [SpaceInfo]

    public init(displayUUID: String, current: SpaceInfo, spaces: [SpaceInfo]) {
        self.displayUUID = displayUUID
        self.current = current
        self.spaces = spaces
    }
}

/// Read-only Space identification via private SkyLight (CGS) calls — the same
/// queries Hammerspoon and yabai use; no SIP changes needed. The public
/// `NSWorkspace.activeSpaceDidChangeNotification` says only *that* a switch
/// happened, never *which* Space is active, so there is no supported
/// alternative. Symbols are resolved with dlsym: if a macOS update removes
/// them, `isSupported` turns false and callers degrade to machine-only
/// branding instead of crashing.
public enum SpaceQuery {
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias CopyManagedDisplaySpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias DisplayUUIDFn = @convention(c) (CGDirectDisplayID) -> Unmanaged<CFUUID>?

    private struct Symbols: @unchecked Sendable {
        let mainConnection: MainConnectionFn
        let copyManagedDisplaySpaces: CopyManagedDisplaySpacesFn
    }

    // Public CoreGraphics call, but no longer surfaced to Swift by the SDK.
    private static let displayUUIDFn: DisplayUUIDFn? = {
        guard let raw = dlsym(
            dlopen(nil, RTLD_LAZY),
            "CGDisplayCreateUUIDFromDisplayID")
        else { return nil }
        return unsafeBitCast(raw, to: DisplayUUIDFn.self)
    }()

    private static let symbols: Symbols? = {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            RTLD_LAZY)
        else { return nil }
        func symbol<T>(_ names: String...) -> T? {
            for name in names {
                if let raw = dlsym(handle, name) {
                    return unsafeBitCast(raw, to: T.self)
                }
            }
            return nil
        }
        guard
            let main: MainConnectionFn = symbol("SLSMainConnectionID", "CGSMainConnectionID"),
            let copy: CopyManagedDisplaySpacesFn = symbol(
                "SLSCopyManagedDisplaySpaces", "CGSCopyManagedDisplaySpaces")
        else { return nil }
        return Symbols(mainConnection: main, copyManagedDisplaySpaces: copy)
    }()

    public static var isSupported: Bool { self.symbols != nil }

    /// Current window-server snapshot of every display's Spaces. Empty when
    /// unsupported or when the returned data no longer parses.
    public static func snapshot() -> [DisplaySpaces] {
        guard let symbols = self.symbols,
              let raw = symbols.copyManagedDisplaySpaces(symbols.mainConnection())?
              .takeRetainedValue() as? [[String: Any]]
        else { return [] }

        var result: [DisplaySpaces] = []
        var desktopNumber = 0
        for display in raw {
            let identifier = display["Display Identifier"] as? String ?? "Main"
            // With one display (or "Displays have separate Spaces" off) the
            // window server reports the literal identifier "Main".
            guard let displayUUID = identifier == "Main"
                ? self.displayUUID(for: CGMainDisplayID())
                : identifier
            else { continue }

            var spaces: [SpaceInfo] = []
            for space in display["Spaces"] as? [[String: Any]] ?? [] {
                guard let uuid = space["uuid"] as? String else { continue }
                let isFullscreen = (space["type"] as? Int ?? 0) != 0
                if !isFullscreen { desktopNumber += 1 }
                spaces.append(SpaceInfo(
                    uuid: uuid,
                    index: isFullscreen ? nil : desktopNumber,
                    isFullscreen: isFullscreen))
            }

            let currentUUID = (display["Current Space"] as? [String: Any])?["uuid"] as? String
            let current = spaces.first { $0.uuid == currentUUID }
                ?? SpaceInfo(uuid: currentUUID ?? "", index: nil, isFullscreen: true)
            result.append(DisplaySpaces(displayUUID: displayUUID, current: current, spaces: spaces))
        }
        return result
    }

    /// UUID string for a CGDirectDisplayID, matching the window server's
    /// "Display Identifier" values.
    public static func displayUUID(for displayID: CGDirectDisplayID) -> String? {
        guard let uuid = self.displayUUIDFn?(displayID)?.takeRetainedValue() else {
            return nil
        }
        return CFUUIDCreateString(nil, uuid) as String?
    }
}
