import AppKit
import Combine
import Foundation
import ServiceManagement
import TraisCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var samples: [SpendSample] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var isTesting = false
    @Published private(set) var lastError: String?
    @Published private(set) var statusMessage = "Add your API key in Settings."
    @Published private(set) var launchAtLoginEnabled = false
    @Published var endpointText: String
    @Published var apiKeyDraft: String
    @Published var refreshInterval: RefreshInterval
    @Published var displayCurrency: DisplayCurrency

    private let client: LiteLLMClient
    private let historyStore: SpendHistoryStore
    private let keychain: KeychainStore
    private var apiKey: String?
    private var preferences: AppPreferences
    private var pollingTask: Task<Void, Never>?
    private var wakeObserver: WorkspaceWakeObserver?

    init() {
        let preferences = AppPreferences()
        self.preferences = preferences
        endpointText = preferences.endpoint
        refreshInterval = RefreshInterval(rawValue: preferences.intervalMinutes) ?? .thirtyMinutes
        displayCurrency = preferences.currency
        let keychain = KeychainStore()
        self.keychain = keychain
        let keychainLoadError: String?
        do {
            let savedKey = try keychain.loadAPIKey()
            apiKey = savedKey
            apiKeyDraft = savedKey ?? ""
            keychainLoadError = nil
        } catch {
            apiKey = nil
            apiKeyDraft = ""
            keychainLoadError = error.localizedDescription
        }
        client = LiteLLMClient()

        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let historyURL =
            applicationSupport
            .appendingPathComponent("de.vda0.trais", isDirectory: true)
            .appendingPathComponent("history.json")
        historyStore = SpendHistoryStore(fileURL: historyURL)
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        if let keychainLoadError {
            lastError = keychainLoadError
        }

        wakeObserver = WorkspaceWakeObserver { [weak self] in
            await self?.refresh()
        }

        Task { [weak self] in
            await self?.start()
        }
    }

    deinit {
        pollingTask?.cancel()
    }

    var currentSpendText: String {
        guard let value = samples.last?.chartValue else { return "—" }
        return value.formattedCurrency(
            displayCurrency,
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        )
    }

    var sevenDaySpendText: String {
        guard let first = samples.first, let last = samples.last else { return "—" }
        return formattedChange(from: first.value, to: last.value)
    }

    var todaySpendText: String {
        guard let last = samples.last else { return "—" }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard last.timestamp >= startOfToday else { return "—" }

        let baseline =
            samples.last { $0.timestamp <= startOfToday }
            ?? samples.first { $0.timestamp >= startOfToday }
        guard let baseline else { return "—" }
        return formattedChange(from: baseline.value, to: last.value)
    }

    private func formattedChange(from baseline: Decimal, to current: Decimal) -> String {
        let value = NSDecimalNumber(decimal: current - baseline).doubleValue
        let prefix = value > 0 ? "+" : ""
        return prefix
            + value.formattedCurrency(
                displayCurrency,
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            )
    }

    func saveSettings() {
        let trimmedKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validatedEndpoint() != nil else {
            lastError = "Enter a valid HTTPS endpoint."
            return
        }
        guard !trimmedKey.isEmpty else {
            lastError = "Enter your LiteLLM API key."
            return
        }

        do {
            try keychain.saveAPIKey(trimmedKey)
            apiKey = trimmedKey
            preferences.endpoint = endpointText.trimmingCharacters(in: .whitespacesAndNewlines)
            preferences.intervalMinutes = refreshInterval.rawValue
            preferences.currency = displayCurrency
            lastError = nil
            statusMessage = "Settings saved."
            restartPolling()
            Task { await refresh() }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func testConnection() async {
        guard let endpoint = validatedEndpoint() else {
            lastError = "Enter a valid HTTPS endpoint."
            return
        }
        let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            lastError = "Enter your LiteLLM API key."
            return
        }

        isTesting = true
        defer { isTesting = false }
        do {
            let spend = try await client.fetchSpend(endpoint: endpoint, apiKey: key)
            let value = NSDecimalNumber(decimal: spend).doubleValue.formattedCurrency(
                displayCurrency,
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            )
            lastError = nil
            statusMessage = "Connected successfully: \(value)"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        guard let endpoint = URL(string: preferences.endpoint) else {
            lastError = "The saved LiteLLM endpoint is invalid."
            return
        }

        guard let key = apiKey, !key.isEmpty else {
            statusMessage = "Add your API key in Settings."
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let spend = try await client.fetchSpend(endpoint: endpoint, apiKey: key)
            samples = try await historyStore.append(
                SpendSample(timestamp: Date(), value: spend)
            )
            lastError = nil
            statusMessage = "Updated just now."
        } catch is CancellationError {
            return
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Showing the last successful value."
        }
    }

    func removeAPIKey() {
        do {
            try keychain.deleteAPIKey()
            apiKey = nil
            apiKeyDraft = ""
            lastError = nil
            statusMessage = "API key removed."
        } catch {
            lastError = error.localizedDescription
        }
    }

    func syncLaunchAtLoginStatus() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            lastError = "Allow trais under System Settings › General › Login Items."
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                lastError = "Allow trais under System Settings › General › Login Items."
            } else {
                lastError = nil
            }
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            lastError = error.localizedDescription
        }
    }

    func openLoginItemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func start() async {
        do {
            samples = try await historyStore.load()
        } catch {
            lastError = "History could not be loaded: \(error.localizedDescription)"
        }
        restartPolling()
        await refresh()
    }

    private func restartPolling() {
        pollingTask?.cancel()
        let seconds = TimeInterval(refreshInterval.rawValue * 60)
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(seconds))
                } catch {
                    return
                }
                guard let self else { return }
                await self.refresh()
            }
        }
    }

    private func validatedEndpoint() -> URL? {
        let value = endpointText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), url.scheme == "https", url.host != nil else {
            return nil
        }
        return url
    }
}

private final class WorkspaceWakeObserver: @unchecked Sendable {
    private let center: NotificationCenter
    private let token: NSObjectProtocol

    @MainActor
    init(onWake: @escaping @MainActor @Sendable () async -> Void) {
        let center = NSWorkspace.shared.notificationCenter
        self.center = center
        token = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await onWake()
            }
        }
    }

    deinit {
        center.removeObserver(token)
    }
}
