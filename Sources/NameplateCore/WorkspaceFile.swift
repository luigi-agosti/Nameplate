import Foundation

/// Per-Space (virtual desktop) branding for one Space: a name, nothing else.
/// Spaces deliberately have no color of their own — the machine color is the
/// "which machine am I on" signal and stays unambiguous.
public struct WorkspaceEntry: Codable, Equatable, Sendable {
    public var name: String?

    public init(name: String? = nil) {
        self.name = name
    }

    public var isEmpty: Bool {
        self.name?.isEmpty ?? true
    }
}

/// One host's Space branding: entries keyed by Space UUID (preferred, stable
/// across reordering) or by 1-based desktop number as a string (hand-editable;
/// a UUID key wins on conflict).
public struct HostWorkspaces: Codable, Equatable, Sendable {
    public var spaces: [String: WorkspaceEntry]

    public init(spaces: [String: WorkspaceEntry] = [:]) {
        self.spaces = spaces
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.spaces = try container.decodeIfPresent([String: WorkspaceEntry].self, forKey: .spaces) ?? [:]
    }
}

/// Companion to fleet.json: `~/.config/nameplate/workspaces.json`, keyed by
/// short hostname (Space UUIDs are per-machine, so one dotfiles-synced file
/// covers the whole fleet):
///
///     {
///       "megaclaw": {
///         "spaces": {
///           "5A1F…-UUID": { "name": "Code" },
///           "3":          { "name": "Comms" }
///         }
///       }
///     }
public enum WorkspaceFile {
    public static var defaultPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config/nameplate/workspaces.json")
    }

    public static func parse(_ data: Data) throws -> [String: HostWorkspaces] {
        let decoded = try JSONDecoder().decode([String: HostWorkspaces].self, from: data)
        var normalized: [String: HostWorkspaces] = [:]
        for (key, value) in decoded {
            normalized[Hostnames.short(key)] = value
        }
        return normalized
    }

    public static func encode(_ entries: [String: HostWorkspaces]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries)
    }

    public static func loadAll(from url: URL = defaultPath) -> [String: HostWorkspaces] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? parse(data) else { return [:] }
        return entries
    }

    public static func load(from url: URL = defaultPath, forHost host: String) -> HostWorkspaces? {
        self.loadAll(from: url)[Hostnames.short(host)]
    }

    public static func save(_ entries: [String: HostWorkspaces], to url: URL = defaultPath) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try self.encode(entries).write(to: url, options: .atomic)
    }

    /// Space UUID key wins over a 1-based desktop-number key.
    public static func entry(
        in host: HostWorkspaces?,
        spaceUUID: String,
        spaceIndex: Int?) -> WorkspaceEntry?
    {
        guard let host else { return nil }
        if !spaceUUID.isEmpty, let byUUID = host.spaces[spaceUUID] { return byUUID }
        if let index = spaceIndex, let byIndex = host.spaces[String(index)] { return byIndex }
        return nil
    }
}

/// Resolved branding of the active Space. Only configured Spaces resolve —
/// untagged Spaces render machine identity alone.
public struct SpaceIdentity: Equatable, Sendable {
    public var name: String

    public init(entry: WorkspaceEntry, index: Int?) {
        let trimmed = entry.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.name = trimmed.isEmpty ? (index.map { "Space \($0)" } ?? "Space") : trimmed
    }
}
