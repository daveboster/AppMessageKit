import Foundation
import Testing
@testable import AppMessageKit

@Suite("Watcher and config behavior")
struct WatcherAndConfigTests {
    @Test("config rejects out-of-range send concurrency")
    func configBounds() throws {
        #expect(throws: IMessageError.self) {
            _ = try IMessageSDK(config: IMessageConfig(
                databasePath: "/tmp/missing-chat.db",
                maxConcurrentSends: 0
            ))
        }
    }

    @Test("watch source polls messages since startup row id and dispatches batches sequentially")
    func watchSourcePollsNewRows() async throws {
        let fixture = try MessagesDatabaseFixture()
        defer { fixture.cleanup() }
        let reader = try MessagesDatabaseReader(path: fixture.path)
        let batches = WatchBatchLog()
        let source = MessageWatchSource(
            database: reader,
            databasePath: fixture.path,
            onBatch: { messages in await batches.append(messages) },
            onError: { _ in }
        )

        try await source.start()
        try fixture.insertDirectMessage(text: "new message", rowID: 1, chatJoin: true)
        await source.triggerForTesting()
        try await waitUntil {
            await batches.count == 1
        }

        #expect(await batches.rowIDs == [[1]])
        await source.stop()
        try reader.close()
    }
}

actor WatchBatchLog {
    private var batches: [[Message]] = []

    var count: Int { batches.count }
    var rowIDs: [[Int64]] { batches.map { $0.map(\.rowID) } }

    func append(_ messages: [Message]) {
        batches.append(messages)
    }
}

func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @escaping @Sendable () async -> Bool
) async throws {
    let start = ContinuousClock.now
    while await !condition() {
        if start.duration(to: .now) > timeout {
            throw IMessageError.config("Timed out waiting for condition")
        }
        try await Task.sleep(for: .milliseconds(20))
    }
}
