import Foundation

public actor SpendHistoryStore {
    private struct Document: Codable {
        let version: Int
        var samples: [SpendSample]
    }

    private enum HistoryError: Error {
        case unsupportedVersion(Int)
    }

    private let fileURL: URL
    private let retentionInterval: TimeInterval
    private let maximumSampleCount: Int
    private let fileManager: FileManager

    public init(
        fileURL: URL,
        retentionInterval: TimeInterval = 7 * 24 * 60 * 60,
        maximumSampleCount: Int = 1_000,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.retentionInterval = retentionInterval
        self.maximumSampleCount = maximumSampleCount
        self.fileManager = fileManager
    }

    public func load(now: Date = Date()) throws -> [SpendSample] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let document = try Self.decoder.decode(Document.self, from: data)
            guard document.version == 1 else {
                throw HistoryError.unsupportedVersion(document.version)
            }

            let samples = normalized(document.samples, now: now)
            if samples != document.samples {
                try save(samples)
            }
            return samples
        } catch {
            try quarantineUnreadableHistory()
            return []
        }
    }

    @discardableResult
    public func append(_ sample: SpendSample, now: Date = Date()) throws -> [SpendSample] {
        var samples = try load(now: now)
        samples.append(sample)
        samples = normalized(samples, now: now)
        try save(samples)
        return samples
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private func normalized(_ samples: [SpendSample], now: Date) -> [SpendSample] {
        let cutoff = now.addingTimeInterval(-retentionInterval)
        var result =
            samples
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
        if result.count > maximumSampleCount {
            result.removeFirst(result.count - maximumSampleCount)
        }
        return result
    }

    private func save(_ samples: [SpendSample]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let document = Document(version: 1, samples: samples)
        let data = try Self.encoder.encode(document)
        try data.write(to: fileURL, options: .atomic)
    }

    private func quarantineUnreadableHistory() throws {
        let quarantineURL =
            fileURL
            .deletingPathExtension()
            .appendingPathExtension("corrupt.json")
        if fileManager.fileExists(atPath: quarantineURL.path) {
            try fileManager.removeItem(at: quarantineURL)
        }
        try fileManager.moveItem(at: fileURL, to: quarantineURL)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()
}
