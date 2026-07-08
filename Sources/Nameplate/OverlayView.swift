import NameplateCore
import SwiftUI

extension ScreenCorner {
    var alignment: Alignment {
        switch self {
        case .topLeft: .topLeading
        case .topRight: .topTrailing
        case .bottomLeft: .bottomLeading
        case .bottomRight: .bottomTrailing
        }
    }
}

extension AppSettings {
    /// The frame shape honoring the per-corner rounding switches.
    func frameShape(scale: CGFloat = 1) -> UnevenRoundedRectangle {
        let radius = self.frameCornerRadius * scale
        return UnevenRoundedRectangle(
            topLeadingRadius: self.frameRoundTopLeft ? radius : 0,
            bottomLeadingRadius: self.frameRoundBottomLeft ? radius : 0,
            bottomTrailingRadius: self.frameRoundBottomRight ? radius : 0,
            topTrailingRadius: self.frameRoundTopRight ? radius : 0,
            style: .continuous)
    }
}

/// Full-screen transparent content: frame border, name tag, watermark.
/// Everything is drawn on top of whatever wallpaper and windows are there —
/// Nameplate never touches the actual desktop background.
struct OverlayView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var spaces: SpaceMonitor
    var displayUUID: String?

    var body: some View {
        let identity = self.settings.identity
        let space = self.settings.spaceIdentity(
            for: self.spaces.current(onDisplay: self.displayUUID))
        ZStack {
            if self.settings.frameEnabled {
                self.settings.frameShape()
                    .strokeBorder(
                        identity.color.opacity(self.settings.frameOpacity),
                        lineWidth: self.settings.frameThickness)
                    .ignoresSafeArea()
            }

            if self.settings.watermarkEnabled {
                WatermarkLabel(identity: identity, opacity: self.settings.watermarkOpacity)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: self.settings.watermarkCorner.alignment)
                    .padding(self.layerPadding)
            }

            if self.settings.tagEnabled {
                NameTagPill(
                    identity: identity,
                    space: self.settings.spaceInTag ? space : nil,
                    showsGlyph: self.settings.tagShowsGlyph)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: self.settings.tagCorner.alignment)
                    .padding(self.layerPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var layerPadding: CGFloat {
        (self.settings.frameEnabled ? self.settings.frameThickness : 0) + 10
    }
}

struct NameTagPill: View {
    let identity: MacIdentity
    var space: SpaceIdentity? = nil
    var showsGlyph: Bool = true
    var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 0) {
            self.segment(
                glyph: self.identity.glyph,
                name: self.identity.name,
                text: self.identity.textOnColor)

            if let space {
                self.segment(glyph: "", name: space.name, text: self.identity.textOnColor)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(self.identity.textOnColor.opacity(0.3))
                            .frame(width: 1)
                    }
            }
        }
        .background(self.identity.color)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.35), radius: 3 * self.scale, y: 1 * self.scale)
    }

    private func segment(glyph: String, name: String, text: Color) -> some View {
        HStack(spacing: 5 * self.scale) {
            if self.showsGlyph, !glyph.isEmpty {
                Text(glyph)
                    .font(.system(size: 12 * self.scale))
            }
            Text(name)
                .font(.system(size: 12 * self.scale, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(text)
        .padding(.horizontal, 10 * self.scale)
        .padding(.vertical, 4 * self.scale)
    }
}

struct WatermarkLabel: View {
    let identity: MacIdentity
    let opacity: Double
    var scale: CGFloat = 1

    var body: some View {
        Text(self.identity.name.uppercased())
            .font(.system(size: 64 * self.scale, weight: .black, design: .rounded))
            .kerning(2 * self.scale)
            .lineLimit(1)
            .foregroundStyle(self.identity.color.opacity(self.opacity))
    }
}
