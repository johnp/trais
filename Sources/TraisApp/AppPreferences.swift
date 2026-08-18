import Foundation

struct AppPreferences {
    static let defaultEndpoint = "https://litellm.example.com/key/info"
    static let defaultIntervalMinutes = 10

    private enum Key {
        static let endpoint = "endpoint"
        static let intervalMinutes = "intervalMinutes"
        static let currency = "currency"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var endpoint: String {
        get { defaults.string(forKey: Key.endpoint) ?? Self.defaultEndpoint }
        nonmutating set { defaults.set(newValue, forKey: Key.endpoint) }
    }

    var intervalMinutes: Int {
        get {
            let value = defaults.integer(forKey: Key.intervalMinutes)
            return value > 0 ? value : Self.defaultIntervalMinutes
        }
        nonmutating set { defaults.set(newValue, forKey: Key.intervalMinutes) }
    }

    var currency: DisplayCurrency {
        get {
            guard let value = defaults.string(forKey: Key.currency) else { return .usDollar }
            return DisplayCurrency(rawValue: value) ?? .usDollar
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.currency) }
    }
}

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fiveMinutes: "5 minutes"
        case .tenMinutes: "10 minutes"
        case .fifteenMinutes: "15 minutes"
        case .thirtyMinutes: "30 minutes"
        case .oneHour: "1 hour"
        }
    }
}
