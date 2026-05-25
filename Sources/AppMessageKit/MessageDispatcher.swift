import Foundation

public typealias MessageCallback = @Sendable (Message) async throws -> Void

public struct DispatchEvents: Sendable {
    public var onIncomingMessage: MessageCallback?
    public var onDirectMessage: MessageCallback?
    public var onGroupMessage: MessageCallback?
    public var onFromMeMessage: MessageCallback?
    public var onError: (@Sendable (any Error) -> Void)?

    public init(
        onIncomingMessage: MessageCallback? = nil,
        onDirectMessage: MessageCallback? = nil,
        onGroupMessage: MessageCallback? = nil,
        onFromMeMessage: MessageCallback? = nil,
        onError: (@Sendable (any Error) -> Void)? = nil
    ) {
        self.onIncomingMessage = onIncomingMessage
        self.onDirectMessage = onDirectMessage
        self.onGroupMessage = onGroupMessage
        self.onFromMeMessage = onFromMeMessage
        self.onError = onError
    }
}

final class MessageDispatcher: Sendable {
    private let events: DispatchEvents
    private let plugins: PluginManager
    private let debug: Bool

    init(events: DispatchEvents, plugins: PluginManager, debug: Bool) {
        self.events = events
        self.plugins = plugins
        self.debug = debug
    }

    func dispatch(_ messages: [Message]) async {
        let incoming = messages.filter { !$0.isFromMe }
        let fromMe = messages.filter(\.isFromMe)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.dispatchIncoming(incoming) }
            group.addTask { await self.dispatchFromMe(fromMe) }
        }
    }

    func handleError(_ error: any Error, context: String) {
        if debug {
            fputs("[MessageDispatcher] \(context): \(error)\n", stderr)
        }
        events.onError?(error)
    }

    private func dispatchIncoming(_ messages: [Message]) async {
        for message in messages {
            do {
                _ = await plugins.callHook(.incomingMessage(message))
                try await events.onIncomingMessage?(message)
                switch message.chatKind {
                case .group:
                    try await events.onGroupMessage?(message)
                case .dm:
                    try await events.onDirectMessage?(message)
                case .unknown:
                    break
                }
            } catch {
                handleError(error, context: "dispatch-message")
            }
        }
    }

    private func dispatchFromMe(_ messages: [Message]) async {
        for message in messages {
            do {
                _ = await plugins.callHook(.fromMe(message))
                try await events.onFromMeMessage?(message)
            } catch {
                handleError(error, context: "dispatch-from-me")
            }
        }
    }
}
