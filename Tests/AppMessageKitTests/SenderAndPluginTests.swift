import Foundation
import Testing
@testable import AppMessageKit

@Suite("Sender and plugin behavior")
struct SenderAndPluginTests {
    @Test("sender rejects URL attachments and preserves missing-file causes")
    func senderValidation() async throws {
        let sender = MessageSender(
            executor: RecordingAppleScriptExecutor(),
            messagesApp: StubMessagesAppProbe(isRunning: true),
            retryDelay: .milliseconds(1)
        )

        await #expect(throws: IMessageError.self) {
            try await sender.send(SendRequest(to: "+1234567890", attachments: ["https://example.test/file.jpg"]))
        }

        await #expect(throws: IMessageError.self) {
            try await sender.send(SendRequest(to: "+1234567890", attachments: ["/tmp/missing-\(UUID().uuidString).jpg"]))
        }
    }

    @Test("sender retries and serializes concurrent sends")
    func senderRetryAndConcurrency() async throws {
        let executor = RecordingAppleScriptExecutor(failuresBeforeSuccess: 2)
        let sender = MessageSender(
            executor: executor,
            messagesApp: StubMessagesAppProbe(isRunning: true),
            maxConcurrentSends: 1,
            retryAttempts: 3,
            retryDelay: .milliseconds(1)
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await sender.send(SendRequest(to: "+1", text: "one")) }
            group.addTask { try await sender.send(SendRequest(to: "+2", text: "two")) }
            try await group.waitForAll()
        }

        #expect(await executor.maxInFlight == 1)
        #expect(await executor.calls.count >= 4)
    }

    @Test("plugin manager orders hooks and lets before hooks interrupt")
    func pluginHooks() async throws {
        let events = EventLog()
        let manager = PluginManager()
        try await manager.use(RecordingPlugin(name: "normal", events: events))
        try await manager.use(RecordingPlugin(name: "pre", order: .pre, events: events))
        try await manager.initPlugins()

        await manager.callHook(.afterSend(AfterSendContext(request: SendRequest(to: "+1", text: "hi"))))
        #expect(await events.values == ["pre:init", "normal:init", "pre:afterSend", "normal:afterSend"])

        try await manager.use(RejectingPlugin(name: "gate"))
        await #expect(throws: IMessageError.self) {
            try await manager.callInterruptingHook(.beforeSend(BeforeSendContext(request: SendRequest(to: "+1", text: "blocked"))), code: .send)
        }
    }
}

actor RecordingAppleScriptExecutor: AppleScriptExecuting {
    private let failuresBeforeSuccess: Int
    private var failures = 0
    private var inFlight = 0
    private(set) var maxInFlight = 0
    private(set) var calls: [String] = []

    init(failuresBeforeSuccess: Int = 0) {
        self.failuresBeforeSuccess = failuresBeforeSuccess
    }

    func execute(script: String, timeout: Duration) async throws -> String {
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        calls.append(script)
        defer { inFlight -= 1 }
        if failures < failuresBeforeSuccess {
            failures += 1
            throw IMessageError.send("transient")
        }
        try await Task.sleep(for: .milliseconds(10))
        return ""
    }
}

struct StubMessagesAppProbe: MessagesAppProbing {
    let isRunning: Bool
    func messagesAppIsRunning() async -> Bool { isRunning }
}

actor EventLog {
    private(set) var values: [String] = []
    func append(_ value: String) {
        values.append(value)
    }
}

struct RecordingPlugin: IMessagePlugin {
    let name: String
    var order: PluginOrder?
    let events: EventLog

    func onInit() async throws {
        await events.append("\(name):init")
    }

    func onAfterSend(_ context: AfterSendContext) async throws {
        await events.append("\(name):afterSend")
    }
}

struct RejectingPlugin: IMessagePlugin {
    let name: String
    func onBeforeSend(_ context: BeforeSendContext) async throws {
        throw NSError(domain: "gate", code: 1)
    }
}
