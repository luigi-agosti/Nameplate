import SwiftUI

@MainActor
struct SettingsPaneLayout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                self.content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

@MainActor
struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content)
    {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(self.title)
                .font(.headline)

            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            self.content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
struct PreferenceToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var binding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: self.$binding) {
                Text(self.title)
                    .font(.body)
            }
            .toggleStyle(.checkbox)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var format: (Double) -> String = { String(format: "%.0f", $0) }

    var body: some View {
        HStack(spacing: 12) {
            Text(self.title)
                .font(.body)
                .frame(width: 88, alignment: .leading)
            Slider(value: self.$value, in: self.range, step: self.step)
            Text(self.format(self.value))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}
