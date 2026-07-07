// Renders Icon.png (1024x1024): the Nameplate motif — dark screen, colored
// frame, name-tag pill. Run via Scripts/build_icon.sh.
import AppKit

let size: CGFloat = 1024
let jade = NSColor(srgbRed: 0x1D / 255, green: 0x9E / 255, blue: 0x75 / 255, alpha: 1)

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    guard let context = NSGraphicsContext.current?.cgContext else { return false }

    // Screen body: dark rounded rect with a subtle vertical sheen.
    let body = NSRect(x: 80, y: 80, width: 864, height: 864)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 200, yRadius: 200)
    context.saveGState()
    bodyPath.addClip()
    let gradient = NSGradient(
        starting: NSColor(srgbRed: 0.075, green: 0.078, blue: 0.09, alpha: 1),
        ending: NSColor(srgbRed: 0.13, green: 0.135, blue: 0.155, alpha: 1))
    gradient?.draw(in: body, angle: 90)
    context.restoreGState()

    // The frame layer.
    let frameRect = body.insetBy(dx: 108, dy: 108)
    let framePath = NSBezierPath(roundedRect: frameRect, xRadius: 116, yRadius: 116)
    framePath.lineWidth = 44
    jade.setStroke()
    framePath.stroke()

    // The name-tag pill, bottom left.
    let pill = NSRect(x: 268, y: 268, width: 300, height: 108)
    let pillPath = NSBezierPath(roundedRect: pill, xRadius: 54, yRadius: 54)
    jade.setFill()
    pillPath.fill()

    // Screw dots on the plate.
    NSColor.white.withAlphaComponent(0.85).setFill()
    for x: CGFloat in [pill.minX + 40, pill.maxX - 64] {
        NSBezierPath(ovalIn: NSRect(x: x, y: pill.midY - 12, width: 24, height: 24)).fill()
    }
    return true
}

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else {
    fputs("render failed\n", stderr)
    exit(1)
}
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Icon.png"
try png.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")
