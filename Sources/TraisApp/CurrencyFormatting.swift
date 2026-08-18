import Foundation

enum DisplayCurrency: String, CaseIterable, Identifiable, Sendable {
    case usDollar
    case euro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .usDollar: "Dollar ($)"
        case .euro: "Euro (€)"
        }
    }

    fileprivate var locale: Locale {
        switch self {
        case .usDollar: Locale(identifier: "en_US")
        case .euro: Locale(identifier: "de_DE")
        }
    }
}

extension Double {
    func formattedCurrency(
        _ currency: DisplayCurrency,
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int = 2
    ) -> String {
        let sign = self < 0 ? "-" : ""
        let amount = abs(self).formatted(
            .number
                .locale(currency.locale)
                .precision(.fractionLength(minimumFractionDigits...maximumFractionDigits))
        )

        switch currency {
        case .usDollar:
            return "\(sign)$\(amount)"
        case .euro:
            return "\(sign)\(amount) €"
        }
    }
}
