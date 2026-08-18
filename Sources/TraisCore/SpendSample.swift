import Foundation

public struct SpendSample: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let value: Decimal

    public init(id: UUID = UUID(), timestamp: Date, value: Decimal) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
    }

    public var chartValue: Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
