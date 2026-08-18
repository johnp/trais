import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("LiteLLM") {
                TextField("Endpoint", text: $model.endpointText)
                    .textFieldStyle(.roundedBorder)
                LabeledContent("API key") {
                    APIKeySecureField(text: $model.apiKeyDraft)
                        .frame(height: 22)
                }
                Text(
                    "The API key is stored in your login Keychain and is never written to history or logs."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Button("Remove API key", role: .destructive) {
                    model.removeAPIKey()
                }
                .disabled(model.apiKeyDraft.isEmpty)
            }

            Section("Display") {
                Picker("Currency", selection: $model.displayCurrency) {
                    ForEach(DisplayCurrency.allCases) { currency in
                        Text(currency.title).tag(currency)
                    }
                }
                .pickerStyle(.segmented)

                Text("Changes the symbol and decimal separator; values are not converted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Updates") {
                Picker("Refresh every", selection: $model.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }

                Toggle(
                    "Launch trais at login",
                    isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )

                Button("Open Login Item Settings") {
                    model.openLoginItemSettings()
                }
                .buttonStyle(.link)
            }

            if let error = model.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            HStack {
                Button("Test connection") {
                    Task { await model.testConnection() }
                }
                .disabled(model.isTesting)

                if model.isTesting {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Button("Save") {
                    model.saveSettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 520)
        .onAppear {
            model.syncLaunchAtLoginStatus()
        }
    }
}
