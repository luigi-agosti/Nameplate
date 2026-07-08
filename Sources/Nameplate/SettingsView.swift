import SwiftUI

enum SettingsTab: String, Hashable, CaseIterable {
    case identity, layers, spaces, splash, general, about

    var label: String {
        switch self {
        case .identity: "Identity"
        case .layers: "Layers"
        case .spaces: "Spaces"
        case .splash: "Splash"
        case .general: "General"
        case .about: "About"
        }
    }
}

extension Notification.Name {
    static let nameplateOpenSettings = Notification.Name("nameplateOpenSettings")
    static let nameplateSelectSettingsTab = Notification.Name("nameplateSelectSettingsTab")
}
