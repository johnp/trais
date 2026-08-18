import SwiftUI

@main
struct TraisApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            SpendPanelView()
                .environmentObject(model)
        } label: {
            Label(model.currentSpendText, systemImage: "chart.line.uptrend.xyaxis")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
