import Foundation

public final class IMessageSDK: @unchecked Sendable {
    private let databasePath: String
    private let debug: Bool
    private let database: MessagesDatabaseReader
    private let sender: MessageSender
    private let plugins: PluginManager

    private var watchSource: MessageWatchSource?
    private var destroyed = false

    public init(config: IMessageConfig = IMessageConfig()) throws {
        try requireMacOS()
        let maxConcurrentSends = try validateBound(config.maxConcurrentSends, Bounds.maxConcurrentSends, name: "maxConcurrentSends")
        databasePath = config.databasePath ?? defaultMessagesDatabasePath()
        debug = config.debug
        database = try MessagesDatabaseReader(path: databasePath)
        sender = MessageSender(maxConcurrentSends: maxConcurrentSends, sendTimeout: config.sendTimeout)
        plugins = PluginManager(plugins: config.plugins)
    }

    public func use(_ plugin: any IMessagePlugin) async throws -> Self {
        try assertNotDestroyed()
        try await plugins.use(plugin)
        return self
    }

    public func messages(_ query: MessageQuery = MessageQuery()) async throws -> [Message] {
        try assertNotDestroyed()
        try await plugins.initPlugins()
        try await plugins.callInterruptingHook(.beforeMessageQuery(BeforeMessageQueryContext(query: query)), code: .database)
        let messages = try await database.messages(query)
        _ = await plugins.callHook(.afterMessageQuery(AfterMessageQueryContext(query: query, messages: messages)))
        return messages
    }

    public func chats(_ query: ChatQuery = ChatQuery()) async throws -> [Chat] {
        try assertNotDestroyed()
        try await plugins.initPlugins()
        try await plugins.callInterruptingHook(.beforeChatQuery(BeforeChatQueryContext(query: query)), code: .database)
        let chats = try await database.chats(query)
        _ = await plugins.callHook(.afterChatQuery(AfterChatQueryContext(query: query, chats: chats)))
        return chats
    }

    public func send(_ request: SendRequest) async throws {
        try assertNotDestroyed()
        try await plugins.initPlugins()
        try await plugins.callInterruptingHook(.beforeSend(BeforeSendContext(request: request)), code: .send)
        try await sender.send(request)
        _ = await plugins.callHook(.afterSend(AfterSendContext(request: request)))
    }

    public func startWatching(events: DispatchEvents = DispatchEvents()) async throws {
        try assertNotDestroyed()
        guard watchSource == nil else {
            throw IMessageError.config("Watcher is already running")
        }
        try await plugins.initPlugins()
        let dispatcher = MessageDispatcher(events: events, plugins: plugins, debug: debug)
        let source = MessageWatchSource(
            database: database,
            databasePath: databasePath,
            onBatch: { messages in await dispatcher.dispatch(messages) },
            onError: { error in dispatcher.handleError(error, context: "watch-source") },
            debug: debug
        )
        watchSource = source
        do {
            try await source.start()
        } catch {
            watchSource = nil
            throw error
        }
    }

    public func stopWatching() async {
        await watchSource?.stop()
        watchSource = nil
    }

    public func close() async throws {
        guard !destroyed else { return }
        destroyed = true
        await stopWatching()
        await plugins.destroy()
        try database.close()
    }

    private func assertNotDestroyed() throws {
        if destroyed {
            throw IMessageError.config("SDK is destroyed")
        }
    }
}
