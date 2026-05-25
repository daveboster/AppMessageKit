import Foundation

public final class MessageSender: @unchecked Sendable {
    private let executor: any AppleScriptExecuting
    private let messagesApp: any MessagesAppProbing
    private let semaphore: AsyncSemaphore
    private let retryAttempts: Int
    private let retryDelay: Duration
    private let sendTimeout: Duration
    private let servicePrefix: String

    init(
        executor: any AppleScriptExecuting = ProcessAppleScriptExecutor(),
        messagesApp: any MessagesAppProbing = ProcessMessagesAppProbe(),
        maxConcurrentSends: Int = 4,
        retryAttempts: Int = 3,
        retryDelay: Duration = .milliseconds(1_500),
        sendTimeout: Duration = .seconds(30),
        servicePrefix: String = "iMessage"
    ) {
        self.executor = executor
        self.messagesApp = messagesApp
        self.semaphore = AsyncSemaphore(limit: maxConcurrentSends)
        self.retryAttempts = retryAttempts
        self.retryDelay = retryDelay
        self.sendTimeout = sendTimeout
        self.servicePrefix = servicePrefix
    }

    public func send(_ request: SendRequest) async throws {
        try await semaphore.run {
            try await self.runPipeline(request)
        }
    }

    private func runPipeline(_ request: SendRequest) async throws {
        try validateMessageContent(text: request.text, attachments: request.attachments)
        guard await messagesApp.messagesAppIsRunning() else {
            throw IMessageError.send("Messages app is not running")
        }

        let target = try target(for: request.to)
        let attachments = try request.attachments.map(resolveAttachment)
        try await dispatch(target: target, text: request.text, attachments: attachments)
    }

    private func target(for raw: String) throws -> (method: SendMethod, identifier: String) {
        switch try resolveTarget(raw) {
        case .group(let chatID):
            return (.chat, try chatID.buildGroupGUID(prefix: servicePrefix))
        case .direct(let recipient):
            return (.buddy, recipient)
        }
    }

    private func dispatch(target: (method: SendMethod, identifier: String), text: String?, attachments: [String]) async throws {
        if attachments.isEmpty {
            let script = AppleScriptBuilder.sendScript(method: target.method, identifier: target.identifier, text: text, attachment: nil)
            try await executeWithRetry(script, description: "Send text to \(target.identifier)")
            return
        }

        let first = attachments[0]
        let firstScript = AppleScriptBuilder.sendScript(method: target.method, identifier: target.identifier, text: text, attachment: first)
        let firstLabel = (text?.isEmpty == false) ? "text + attachment 1/\(attachments.count)" : "attachment 1/\(attachments.count)"
        try await executeWithRetry(firstScript, description: "Send \(firstLabel) to \(target.identifier)")

        if attachments.count > 1 {
            for index in 1..<attachments.count {
                try await Task.sleep(for: .milliseconds(500))
                let script = AppleScriptBuilder.sendScript(method: target.method, identifier: target.identifier, text: nil, attachment: attachments[index])
                try await executeWithRetry(script, description: "Send attachment \(index + 1)/\(attachments.count) to \(target.identifier)")
            }
        }
    }

    private func executeWithRetry(_ script: String, description: String) async throws {
        var lastError: (any Error)?
        for attempt in 1...retryAttempts {
            do {
                _ = try await executor.execute(script: script, timeout: sendTimeout)
                return
            } catch {
                lastError = error
                if attempt < retryAttempts {
                    try await Task.sleep(for: retryDelay)
                }
            }
        }
        throw IMessageError.send("\(description) failed after \(retryAttempts) attempts: \(lastError.map(errorMessage) ?? "unknown error")", underlyingError: lastError)
    }

    private func resolveAttachment(_ path: String) throws -> String {
        guard !isURL(path) else {
            throw IMessageError.send("URLs are not supported as attachments. Download the file yourself and pass a local path instead: \(path.prefix(120))")
        }
        let resolved = URL(fileURLWithPath: path).standardizedFileURL.path
        guard FileManager.default.isReadableFile(atPath: resolved) else {
            throw IMessageError.send("Attachment unreadable: \(URL(fileURLWithPath: path).lastPathComponent): ENOENT")
        }
        return resolved
    }

    private func validateMessageContent(text: String?, attachments: [String]) throws {
        if (text ?? "").isEmpty && attachments.isEmpty {
            throw IMessageError.send("Message must include text or at least one attachment")
        }
    }

    private func isURL(_ value: String) -> Bool {
        value.lowercased().hasPrefix("http://") || value.lowercased().hasPrefix("https://")
    }
}
