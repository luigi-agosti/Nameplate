import AppKit
import NameplateCore

/// Renders the colored mini-nameplate for the menu bar. A plain NSImage with
/// isTemplate=false keeps its color instead of being flattened to monochrome.
enum StatusItemIcon {
    @MainActor
    static func image(for identity: MacIdentity) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let color = identity.nsColor
        let image = NSImage(size: size, flipped: false) { rect in
            let plate = NSRect(x: 1, y: 4.5, width: 16, height: 9)
            let path = NSBezierPath(roundedRect: plate, xRadius: 3, yRadius: 3)
            color.setFill()
            path.fill()

            // Tiny "screw" dots hint at a physical nameplate.
            let dotColor = ColorHex.prefersDarkText(on: identity.colorHex)
                ? NSColor.black.withAlphaComponent(0.55)
                : NSColor.white.withAlphaComponent(0.8)
            dotColor.setFill()
            for x: CGFloat in [3.5, 12.5] {
                NSBezierPath(ovalIn: NSRect(x: x, y: 8, width: 2, height: 2)).fill()
            }
            _ = rect
            return true
        }
        image.isTemplate = false
        return image
    }
}
