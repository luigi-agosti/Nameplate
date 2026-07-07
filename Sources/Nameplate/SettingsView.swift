import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let services: AppServices

    var body: some View {
        TabView {
            IdentitySettingsPane(settings: self.settings)
                .tabItem { Label("Identity", systemImage: "person.text.rectangle") }

            LayersSettingsPane(settings: self.settings)
                .tabItem { Label("Layers", systemImage: "square.3.layers.3d") }

            SplashSettingsPane(settings: self.settings, services: self.services)
                .tabItem { Label("Splash", systemImage: "sparkles.rectangle.stack") }

            GeneralSettingsPane(settings: self.settings)
                .tabItem { Label("General", systemImage: "gearshape") }

            AboutPane()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: Self.windowWidth, height: Self.windowHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    static let windowWidth: CGFloat = 560
    static let windowHeight: CGFloat = 600
}

extension Notification.Name {
    static let nameplateOpenSettings = Notification.Name("nameplateOpenSettings")
}
