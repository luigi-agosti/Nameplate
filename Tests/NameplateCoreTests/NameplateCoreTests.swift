import Foundation
import Testing
@testable import NameplateCore

@Suite("ColorHex")
struct ColorHexTests {
    @Test func normalizesSixDigitHex() {
        #expect(ColorHex.normalize("#1d9e75") == "#1D9E75")
        #expect(ColorHex.normalize("1D9E75") == "#1D9E75")
        #expect(ColorHex.normalize("  #1d9e75\n") == "#1D9E75")
    }

    @Test func expandsThreeDigitHex() {
        #expect(ColorHex.normalize("#3fa") == "#33FFAA")
        #expect(ColorHex.normalize("fff") == "#FFFFFF")
    }

    @Test func rejectsInvalidInput() {
        #expect(ColorHex.normalize("") == nil)
        #expect(ColorHex.normalize("#12345") == nil)
        #expect(ColorHex.normalize("nope") == nil)
        #expect(ColorHex.normalize("#GGGGGG") == nil)
    }

    @Test func parsesComponents() throws {
        let rgb = try #require(ColorHex.components("#FF8000"))
        #expect(abs(rgb.red - 1.0) < 0.001)
        #expect(abs(rgb.green - 0x80 / 255.0) < 0.001)
        #expect(abs(rgb.blue) < 0.001)
    }

    @Test func picksReadableTextColor() {
        #expect(ColorHex.prefersDarkText(on: "#FFFFFF"))
        #expect(ColorHex.prefersDarkText(on: "#EF9F27"))
        #expect(!ColorHex.prefersDarkText(on: "#000000"))
        #expect(!ColorHex.prefersDarkText(on: "#0C447C"))
    }
}

@Suite("Palette")
struct PaletteTests {
    @Test func defaultColorIsStablePerHost() {
        let first = NameplatePalette.defaultColor(forHost: "megaclaw.local")
        let second = NameplatePalette.defaultColor(forHost: "MEGACLAW.fritz.box")
        #expect(first == second)
    }

    @Test func differentHostsSpreadAcrossPalette() {
        let hosts = ["megaclaw", "clawmac", "studio-1", "macbook-air", "buildbox", "peters-imac"]
        let colors = Set(hosts.map { NameplatePalette.defaultColor(forHost: $0).hex })
        #expect(colors.count >= 3)
    }
}

@Suite("Hostnames")
struct HostnamesTests {
    @Test func shortensToFirstLabel() {
        #expect(Hostnames.short("Megaclaw.local") == "megaclaw")
        #expect(Hostnames.short("studio-1.fritz.box") == "studio-1")
        #expect(Hostnames.short("plain") == "plain")
        #expect(Hostnames.short("") == "")
    }
}

@Suite("MacIdentity")
struct MacIdentityTests {
    @Test func sanitizesColorOnInit() {
        let identity = MacIdentity(name: "test", colorHex: "not-a-color")
        #expect(identity.colorHex == NameplatePalette.fallback.hex)
        let valid = MacIdentity(name: "test", colorHex: "#1d9e75")
        #expect(valid.colorHex == "#1D9E75")
    }
}

@Suite("FleetFile")
struct FleetFileTests {
    @Test func parsesAndNormalizesKeys() throws {
        let json = """
        {
          "Megaclaw.local": { "name": "MEGACLAW", "color": "#1D9E75", "glyph": "🦞" },
          "clawmac": { "color": "#E24B30" }
        }
        """
        let entries = try FleetFile.parse(Data(json.utf8))
        #expect(entries.count == 2)
        #expect(FleetFile.entry(in: entries, forHost: "megaclaw.fritz.box")?.name == "MEGACLAW")
        #expect(FleetFile.entry(in: entries, forHost: "CLAWMAC")?.color == "#E24B30")
        #expect(FleetFile.entry(in: entries, forHost: "CLAWMAC")?.name == nil)
        #expect(FleetFile.entry(in: entries, forHost: "unknown") == nil)
    }

    @Test func rejectsMalformedJSON() {
        #expect(throws: (any Error).self) {
            try FleetFile.parse(Data("[1, 2, 3]".utf8))
        }
    }
}
