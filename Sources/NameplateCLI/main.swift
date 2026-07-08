import AppKit
import Foundation
import NameplateCore
import NameplateSpaces
import notify

// nameplate CLI — poke the running Nameplate app from scripts and agents.
//
//   nameplate attention <message> [--title <t>] [--duration <s>] [--color <hex>]
//   nameplate splash
//   nameplate settings
//   nameplate space list | current | set [...]

let bundleID = "com.steipete.nameplate"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func usage() -> Never {
    print("""
    usage:
      nameplate attention <message> [--title <title>] [--duration <seconds>] [--color <hex>]
      nameplate splash
      nameplate settings
      nameplate space list
      nameplate space current
      nameplate space set [--space <uuid|number>] [--name <name>] [--clear]

    attention shows a topmost message card with pulsating screen borders —
    use it when an agent needs the human, and always say why.

    space edits per-Space names in ~/.config/nameplate/workspaces.json;
    the app picks changes up live. set targets the active Space by default.
    """)
    exit(2)
}

/// The app must be running to render anything; launch it if needed.
/// Returns true when the app had to be cold-launched.
@discardableResult
func ensureAppRunning() -> Bool {
    let running = NSWorkspace.shared.runningApplications.contains {
        $0.bundleIdentifier?.hasPrefix(bundleID) == true
    }
    if running { return false }

    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
        fail("Nameplate.app is not installed (bundle id \(bundleID) not found).")
    }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    let semaphore = DispatchSemaphore(value: 0)
    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 5)
    // Give the fresh instance a beat to register its notification listeners.
    Thread.sleep(forTimeInterval: 0.8)
    return true
}

/// Darwin notifications are not queued; on a cold launch the app might still
/// be starting when the first post fires. The app consumes attention requests
/// from disk at startup, and for the notification-only commands we simply
/// post again after a grace period.
func post(_ name: String, retryAfterColdLaunch coldLaunched: Bool) {
    notify_post(name)
    if coldLaunched {
        Thread.sleep(forTimeInterval: 1.5)
        notify_post(name)
    }
}

var arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { usage() }
arguments.removeFirst()

switch command {
case "attention":
    var title: String?
    var duration: Double?
    var color: String?
    var messageParts: [String] = []

    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        func flagValue() -> String {
            index += 1
            guard index < arguments.count else { fail("missing value for \(argument)") }
            return arguments[index]
        }
        switch argument {
        case "--title": title = flagValue()
        case "--duration":
            guard let value = Double(flagValue()) else { fail("--duration expects seconds") }
            duration = value
        case "--color": color = flagValue()
        case "--help", "-h": usage()
        default: messageParts.append(argument)
        }
        index += 1
    }

    let message = messageParts.joined(separator: " ")
    guard !message.isEmpty else { fail("attention needs a message — say why you need the human.") }

    do {
        try AttentionRequest(
            title: title,
            message: message,
            duration: duration,
            color: color,
            createdAt: Date()).write()
    } catch {
        fail("could not write attention request: \(error.localizedDescription)")
    }
    // On a cold launch the app consumes the request file at startup, so a
    // missed notification cannot drop the alert.
    ensureAppRunning()
    notify_post(AttentionRequest.notificationName)

case "splash":
    let coldLaunched = ensureAppRunning()
    post("com.steipete.nameplate.splash", retryAfterColdLaunch: coldLaunched)

case "settings":
    let coldLaunched = ensureAppRunning()
    post("com.steipete.nameplate.settings", retryAfterColdLaunch: coldLaunched)

case "space":
    guard SpaceQuery.isSupported else {
        fail("Space detection is unavailable on this macOS version.")
    }
    let snapshot = SpaceQuery.snapshot()
    guard !snapshot.isEmpty else { fail("could not read Spaces from the window server.") }
    let host = Hostnames.current()
    let workspaces = WorkspaceFile.load(forHost: host)

    func describe(_ space: SpaceInfo, current: Bool) -> String {
        let marker = current ? "*" : " "
        let number = space.index.map(String.init) ?? "-"
        if space.isFullscreen {
            return "\(marker) \(number)  (full screen app)  \(space.uuid)"
        }
        let entry = WorkspaceFile.entry(in: workspaces, spaceUUID: space.uuid, spaceIndex: space.index)
        let name = entry.map { SpaceIdentity(entry: $0, index: space.index).name } ?? "(untagged)"
        return "\(marker) \(number)  \(name)  \(space.uuid)"
    }

    guard let subcommand = arguments.first else { usage() }
    arguments.removeFirst()

    switch subcommand {
    case "list":
        for display in snapshot {
            if snapshot.count > 1 {
                print("display \(display.displayUUID):")
            }
            for space in display.spaces {
                print(describe(space, current: space.uuid == display.current.uuid))
            }
        }

    case "current":
        for display in snapshot {
            print(describe(display.current, current: true))
        }

    case "set":
        var target: String?
        var name: String?
        var clear = false

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            func flagValue() -> String {
                index += 1
                guard index < arguments.count else { fail("missing value for \(argument)") }
                return arguments[index]
            }
            switch argument {
            case "--space": target = flagValue()
            case "--name": name = flagValue()
            case "--clear": clear = true
            case "--help", "-h": usage()
            default: fail("unknown flag: \(argument)")
            }
            index += 1
        }

        let all = snapshot.flatMap(\.spaces)
        let space: SpaceInfo
        if let target {
            guard let match = all.first(where: {
                $0.uuid == target || $0.index.map(String.init) == target
            }) else {
                fail("no Space matches \"\(target)\" — see nameplate space list.")
            }
            space = match
        } else {
            space = snapshot[0].current
        }
        guard !space.isFullscreen else {
            fail("full-screen-app Spaces cannot be tagged.")
        }

        let hostKey = Hostnames.short(host)
        var entries = WorkspaceFile.loadAll()
        var hostEntry = entries[hostKey] ?? HostWorkspaces()
        if clear {
            hostEntry.spaces.removeValue(forKey: space.uuid)
        } else {
            guard let name, !name.isEmpty else {
                fail("set needs --name <name> (or --clear).")
            }
            hostEntry.spaces[space.uuid] = WorkspaceEntry(name: name)
        }
        if hostEntry.spaces.isEmpty {
            entries.removeValue(forKey: hostKey)
        } else {
            entries[hostKey] = hostEntry
        }
        do {
            try WorkspaceFile.save(entries)
        } catch {
            fail("could not write workspaces file: \(error.localizedDescription)")
        }
        let resolved = WorkspaceFile.entry(
            in: entries[hostKey], spaceUUID: space.uuid, spaceIndex: space.index)
        let label = resolved.map { SpaceIdentity(entry: $0, index: space.index).name } ?? "(untagged)"
        print("space \(space.index.map(String.init) ?? space.uuid) → \(label)")

    default:
        fail("unknown space subcommand: \(subcommand)")
    }

case "--help", "-h", "help":
    usage()

default:
    fail("unknown command: \(command)")
}
