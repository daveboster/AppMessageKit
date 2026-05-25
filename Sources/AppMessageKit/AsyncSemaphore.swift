import Foundation

actor AsyncSemaphore {
    private let limit: Int
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
        self.permits = max(1, limit)
    }

    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }

    private func acquire() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private nonisolated func release() {
        Task { await releaseIsolated() }
    }

    private func releaseIsolated() {
        if waiters.isEmpty {
            permits = min(limit, permits + 1)
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}
