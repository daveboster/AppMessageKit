import Foundation

public enum PluginOrder: Sendable, Equatable {
    case pre
    case post
}

public struct BeforeSendContext: Sendable {
    public var request: SendRequest
    public init(request: SendRequest) {
        self.request = request
    }
}

public struct AfterSendContext: Sendable {
    public var request: SendRequest
    public init(request: SendRequest) {
        self.request = request
    }
}

public struct BeforeMessageQueryContext: Sendable {
    public var query: MessageQuery
}

public struct AfterMessageQueryContext: Sendable {
    public var query: MessageQuery
    public var messages: [Message]
}

public struct BeforeChatQueryContext: Sendable {
    public var query: ChatQuery
}

public struct AfterChatQueryContext: Sendable {
    public var query: ChatQuery
    public var chats: [Chat]
}

public struct PluginErrorContext: Sendable {
    public var error: IMessageError
    public var hook: String
    public var pluginName: String
}

public protocol IMessagePlugin: Sendable {
    var name: String { get }
    var order: PluginOrder? { get }

    func onInit() async throws
    func onDestroy() async throws
    func onBeforeSend(_ context: BeforeSendContext) async throws
    func onAfterSend(_ context: AfterSendContext) async throws
    func onBeforeMessageQuery(_ context: BeforeMessageQueryContext) async throws
    func onAfterMessageQuery(_ context: AfterMessageQueryContext) async throws
    func onBeforeChatQuery(_ context: BeforeChatQueryContext) async throws
    func onAfterChatQuery(_ context: AfterChatQueryContext) async throws
    func onIncomingMessage(_ message: Message) async throws
    func onFromMe(_ message: Message) async throws
    func onError(_ context: PluginErrorContext) async
}

public extension IMessagePlugin {
    var order: PluginOrder? { nil }
    func onInit() async throws {}
    func onDestroy() async throws {}
    func onBeforeSend(_ context: BeforeSendContext) async throws {}
    func onAfterSend(_ context: AfterSendContext) async throws {}
    func onBeforeMessageQuery(_ context: BeforeMessageQueryContext) async throws {}
    func onAfterMessageQuery(_ context: AfterMessageQueryContext) async throws {}
    func onBeforeChatQuery(_ context: BeforeChatQueryContext) async throws {}
    func onAfterChatQuery(_ context: AfterChatQueryContext) async throws {}
    func onIncomingMessage(_ message: Message) async throws {}
    func onFromMe(_ message: Message) async throws {}
    func onError(_ context: PluginErrorContext) async {}
}

public enum ObservingPluginHook: Sendable {
    case afterSend(AfterSendContext)
    case afterMessageQuery(AfterMessageQueryContext)
    case afterChatQuery(AfterChatQueryContext)
    case incomingMessage(Message)
    case fromMe(Message)
    case destroy
}

public enum InterruptingPluginHook: Sendable {
    case beforeSend(BeforeSendContext)
    case beforeMessageQuery(BeforeMessageQueryContext)
    case beforeChatQuery(BeforeChatQueryContext)
}

public final class PluginManager: @unchecked Sendable {
    private var plugins: [any IMessagePlugin] = []
    private var initialized = false
    private var destroying = false

    public init(plugins: [any IMessagePlugin] = []) {
        self.plugins = plugins
    }

    public func use(_ plugin: any IMessagePlugin) async throws {
        guard !destroying else {
            throw IMessageError.config("PluginManager is destroying, cannot register new plugins")
        }
        guard !plugins.contains(where: { $0.name == plugin.name }) else {
            throw IMessageError.config("Plugin \"\(plugin.name)\" is already registered")
        }
        plugins.append(plugin)
        if initialized {
            do {
                try await plugin.onInit()
            } catch {
                await report(plugin: plugin.name, hook: "onInit", error: error)
            }
        }
    }

    public func initPlugins() async throws {
        guard !initialized else { return }
        for plugin in sortedPlugins() {
            do {
                try await plugin.onInit()
            } catch {
                await report(plugin: plugin.name, hook: "onInit", error: error)
            }
        }
        initialized = true
    }

    public func destroy() async {
        destroying = true
        for plugin in sortedPlugins() {
            do {
                try await plugin.onDestroy()
            } catch {
                await report(plugin: plugin.name, hook: "onDestroy", error: error)
            }
        }
        plugins.removeAll()
        initialized = false
        destroying = false
    }

    @discardableResult
    public func callHook(_ hook: ObservingPluginHook) async -> [IMessageError] {
        var errors: [IMessageError] = []
        for plugin in sortedPlugins() {
            do {
                switch hook {
                case .afterSend(let context):
                    try await plugin.onAfterSend(context)
                case .afterMessageQuery(let context):
                    try await plugin.onAfterMessageQuery(context)
                case .afterChatQuery(let context):
                    try await plugin.onAfterChatQuery(context)
                case .incomingMessage(let message):
                    try await plugin.onIncomingMessage(message)
                case .fromMe(let message):
                    try await plugin.onFromMe(message)
                case .destroy:
                    try await plugin.onDestroy()
                }
            } catch {
                let wrapped = wrap(error, code: .config, pluginName: plugin.name, hook: hook.name)
                errors.append(wrapped)
                await plugin.onError(PluginErrorContext(error: wrapped, hook: hook.name, pluginName: plugin.name))
            }
        }
        return errors
    }

    public func callInterruptingHook(_ hook: InterruptingPluginHook, code: IMessageErrorCode) async throws {
        for plugin in sortedPlugins() {
            do {
                switch hook {
                case .beforeSend(let context):
                    try await plugin.onBeforeSend(context)
                case .beforeMessageQuery(let context):
                    try await plugin.onBeforeMessageQuery(context)
                case .beforeChatQuery(let context):
                    try await plugin.onBeforeChatQuery(context)
                }
            } catch {
                throw IMessageError(code, "Plugin \"\(plugin.name)\" \(hook.name) rejected: \(errorMessage(error))", underlyingError: error)
            }
        }
    }

    private func sortedPlugins() -> [any IMessagePlugin] {
        let pre = plugins.filter { $0.order == .pre }
        let normal = plugins.filter { $0.order == nil }
        let post = plugins.filter { $0.order == .post }
        return pre + normal + post
    }

    private func wrap(_ error: any Error, code: IMessageErrorCode, pluginName: String, hook: String) -> IMessageError {
        if let error = error as? IMessageError { return error }
        return IMessageError(code, "Plugin \"\(pluginName)\" \(hook) failed: \(errorMessage(error))", underlyingError: error)
    }

    private func report(plugin: String, hook: String, error: any Error) async {
        let wrapped = wrap(error, code: .config, pluginName: plugin, hook: hook)
        for observer in sortedPlugins() where observer.name != plugin {
            await observer.onError(PluginErrorContext(error: wrapped, hook: hook, pluginName: plugin))
        }
    }
}

private extension ObservingPluginHook {
    var name: String {
        switch self {
        case .afterSend: "onAfterSend"
        case .afterMessageQuery: "onAfterMessageQuery"
        case .afterChatQuery: "onAfterChatQuery"
        case .incomingMessage: "onIncomingMessage"
        case .fromMe: "onFromMe"
        case .destroy: "onDestroy"
        }
    }
}

private extension InterruptingPluginHook {
    var name: String {
        switch self {
        case .beforeSend: "onBeforeSend"
        case .beforeMessageQuery: "onBeforeMessageQuery"
        case .beforeChatQuery: "onBeforeChatQuery"
        }
    }
}
