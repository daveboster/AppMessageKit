import Darwin
import Dispatch
import Foundation

actor WatchTrigger {
    private var continuation: CheckedContinuation<Void, Never>?
    private var pending = false

    func trigger() {
        if let continuation {
            self.continuation = nil
            continuation.resume()
        } else {
            pending = true
        }
    }

    func wait() async {
        if pending {
            pending = false
            return
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

public final class MessageWatchSource: @unchecked Sendable {
    private let database: MessagesDatabaseReader
    private let databasePath: String
    private let onBatch: @Sendable ([Message]) async -> Void
    private let onError: @Sendable (any Error) -> Void
    private let debug: Bool
    private let trigger = WatchTrigger()
    private let queue = DispatchQueue(label: "AppMessageKit.MessageWatchSource")

    private var lastRowID: Int64 = -1
    private var isRunning = false
    private var consumer: Task<Void, Never>?
    private var fileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?

    public init(
        database: MessagesDatabaseReader,
        databasePath: String,
        onBatch: @escaping @Sendable ([Message]) async -> Void,
        onError: @escaping @Sendable (any Error) -> Void,
        debug: Bool = false
    ) {
        self.database = database
        self.databasePath = databasePath
        self.onBatch = onBatch
        self.onError = onError
        self.debug = debug
    }

    public func start() async throws {
        guard !isRunning else { return }
        lastRowID = try await database.maxRowID()
        isRunning = true
        do {
            try attachBestAvailableSource()
        } catch {
            isRunning = false
            throw error
        }
        consumer = Task { await consumeLoop() }
        await trigger.trigger()
    }

    public func stop() async {
        guard isRunning || consumer != nil else { return }
        isRunning = false
        detachSource()
        await trigger.trigger()
        await consumer?.value
        consumer = nil
    }

    func triggerForTesting() async {
        await trigger.trigger()
    }

    private func consumeLoop() async {
        while isRunning {
            await trigger.wait()
            guard isRunning else { break }
            do {
                while try await processBatch() {
                    guard isRunning else { break }
                }
            } catch {
                onError(error)
            }
        }
    }

    private func processBatch() async throws -> Bool {
        let messages = try await database.messagesSince(rowID: lastRowID, query: MessageQuery(limit: 100))
        if !messages.isEmpty {
            await onBatch(messages)
            if let last = messages.last {
                lastRowID = last.rowID
            }
        }
        return messages.count == 100
    }

    private func attachBestAvailableSource() throws {
        if attachSource(path: "\(databasePath)-wal", mask: [.write, .delete, .rename]) {
            return
        }
        let directory = URL(fileURLWithPath: databasePath).deletingLastPathComponent().path
        guard attachSource(path: directory, mask: [.write, .delete, .rename]) else {
            throw IMessageError.database("Failed to start watcher: WAL missing and directory watch failed")
        }
    }

    private func attachSource(path: String, mask: DispatchSource.FileSystemEvent) -> Bool {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return false }
        detachSource()
        fileDescriptor = fd
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: mask, queue: queue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.trigger.trigger() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
        if debug {
            fputs("[MessageWatchSource] watching \(path)\n", stderr)
        }
        return true
    }

    private func detachSource() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }
}
