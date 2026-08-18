import Foundation
import TraisCore

func runHistoryChecks() async throws {
    try await checkHistorySortingAndPersistence()
    try await checkHistoryRetentionAndCountLimit()
    try await checkHistoryPrunesOnLoad()
    try await checkCorruptHistoryRecovery()
}

private func checkHistorySortingAndPersistence() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SpendHistoryStore(fileURL: directory.appendingPathComponent("history.json"))
    let now = Date()
    let later = SpendSample(timestamp: now, value: 2)
    let earlier = SpendSample(timestamp: now.addingTimeInterval(-60), value: 1)

    _ = try await store.append(later, now: now)
    let samples = try await store.append(earlier, now: now)
    let persisted = try await store.load()

    try require(samples == [earlier, later], "History samples were not sorted.")
    try require(persisted == [earlier, later], "History samples were not persisted.")
}

private func checkHistoryPrunesOnLoad() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SpendHistoryStore(
        fileURL: directory.appendingPathComponent("history.json"),
        retentionInterval: 100
    )
    let now = Date()
    let oldDate = now.addingTimeInterval(-200)

    _ = try await store.append(SpendSample(timestamp: oldDate, value: 1), now: oldDate)
    let samples = try await store.load(now: now)

    try require(samples.isEmpty, "Expired history was not pruned during load.")
}

private func checkCorruptHistoryRecovery() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let historyURL = directory.appendingPathComponent("history.json")
    try Data("not json".utf8).write(to: historyURL)
    let store = SpendHistoryStore(fileURL: historyURL)
    let now = Date()

    let recovered = try await store.load(now: now)
    try require(recovered.isEmpty, "Corrupt history did not recover to an empty state.")
    try require(
        FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("history.corrupt.json").path),
        "Corrupt history was not quarantined."
    )

    let samples = try await store.append(SpendSample(timestamp: now, value: 4), now: now)
    try require(samples.map(\.value) == [4], "Appending after corrupt history recovery failed.")
}

private func checkHistoryRetentionAndCountLimit() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SpendHistoryStore(
        fileURL: directory.appendingPathComponent("history.json"),
        retentionInterval: 100,
        maximumSampleCount: 2
    )
    let now = Date()

    _ = try await store.append(
        SpendSample(timestamp: now.addingTimeInterval(-200), value: 0), now: now)
    _ = try await store.append(
        SpendSample(timestamp: now.addingTimeInterval(-2), value: 1), now: now)
    _ = try await store.append(
        SpendSample(timestamp: now.addingTimeInterval(-1), value: 2), now: now)
    let samples = try await store.append(SpendSample(timestamp: now, value: 3), now: now)

    try require(samples.map(\.value) == [2, 3], "Retention or count limiting failed.")
}
