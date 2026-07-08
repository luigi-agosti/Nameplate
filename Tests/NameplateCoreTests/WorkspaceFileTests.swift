import Foundation
import Testing
@testable import NameplateCore

@Suite("WorkspaceFile")
struct WorkspaceFileTests {
    let sample = Data("""
    {
      "Megaclaw.local": {
        "spaces": {
          "5A1F0000-0000-0000-0000-000000000001": { "name": "Code" },
          "3": { "name": "Comms" }
        }
      },
      "clawmac": {
        "spaces": { "1": { "name": "Main" } }
      }
    }
    """.utf8)

    @Test func parsesAndNormalizesHostKeys() throws {
        let entries = try WorkspaceFile.parse(self.sample)
        #expect(entries.count == 2)
        let host = try #require(entries["megaclaw"])
        #expect(host.spaces.count == 2)
        #expect(host.spaces["3"]?.name == "Comms")
        #expect(entries["clawmac"]?.spaces["1"]?.name == "Main")
    }

    @Test func ignoresRetiredFields() throws {
        // Files written by earlier builds may carry color/glyph/frameFollows.
        let data = Data("""
        {
          "megaclaw": {
            "frameFollows": "space",
            "spaces": { "2": { "name": "Code", "color": "#378ADD", "glyph": "⌘" } }
          }
        }
        """.utf8)
        let host = try #require(try WorkspaceFile.parse(data)["megaclaw"])
        #expect(host.spaces["2"]?.name == "Code")
    }

    @Test func uuidKeyWinsOverIndexKey() throws {
        let host = try WorkspaceFile.parse(self.sample)["megaclaw"]
        let uuid = "5A1F0000-0000-0000-0000-000000000001"
        // Space with both a UUID entry and a colliding index entry.
        let byUUID = WorkspaceFile.entry(in: host, spaceUUID: uuid, spaceIndex: 3)
        #expect(byUUID?.name == "Code")
        // Unconfigured UUID falls back to the desktop-number key.
        let byIndex = WorkspaceFile.entry(in: host, spaceUUID: "other-uuid", spaceIndex: 3)
        #expect(byIndex?.name == "Comms")
        // Untagged space resolves to nothing.
        #expect(WorkspaceFile.entry(in: host, spaceUUID: "other-uuid", spaceIndex: 9) == nil)
        #expect(WorkspaceFile.entry(in: nil, spaceUUID: uuid, spaceIndex: 1) == nil)
    }

    @Test func toleratesMissingSpacesKey() throws {
        let data = Data(#"{ "megaclaw": {} }"#.utf8)
        let host = try #require(try WorkspaceFile.parse(data)["megaclaw"])
        #expect(host.spaces.isEmpty)
    }

    @Test func encodeRoundTrips() throws {
        let entries = try WorkspaceFile.parse(self.sample)
        let reparsed = try WorkspaceFile.parse(WorkspaceFile.encode(entries))
        #expect(reparsed == entries)
    }

    @Test func emptyEntryDetection() {
        #expect(WorkspaceEntry().isEmpty)
        #expect(WorkspaceEntry(name: "").isEmpty)
        #expect(!WorkspaceEntry(name: "Code").isEmpty)
    }
}

@Suite("SpaceIdentity")
struct SpaceIdentityTests {
    @Test func trimsName() {
        let identity = SpaceIdentity(entry: WorkspaceEntry(name: "  Code "), index: 2)
        #expect(identity.name == "Code")
    }

    @Test func fallsBackToDesktopNumberName() {
        let identity = SpaceIdentity(entry: WorkspaceEntry(name: "  "), index: 4)
        #expect(identity.name == "Space 4")
        let unnumbered = SpaceIdentity(entry: WorkspaceEntry(), index: nil)
        #expect(unnumbered.name == "Space")
    }
}
