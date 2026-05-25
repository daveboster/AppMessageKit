import Foundation

protocol AppleScriptExecuting: Sendable {
    func execute(script: String, timeout: Duration) async throws -> String
}

protocol MessagesAppProbing: Sendable {
    func messagesAppIsRunning() async -> Bool
}

struct ProcessAppleScriptExecutor: AppleScriptExecuting {
    func execute(script: String, timeout: Duration) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                let process = Process()
                let output = Pipe()
                let error = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                process.standardOutput = output
                process.standardError = error
                try process.run()
                process.waitUntilExit()
                let out = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                guard process.terminationStatus == 0 else {
                    throw IMessageError.send(err.isEmpty ? "osascript exited with status \(process.terminationStatus)" : err)
                }
                return out
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw IMessageError.send("AppleScript timed out")
            }
            guard let first = try await group.next() else { return "" }
            group.cancelAll()
            return first
        }
    }
}

struct ProcessMessagesAppProbe: MessagesAppProbing {
    func messagesAppIsRunning() async -> Bool {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", #"tell application "System Events" to (name of processes) contains "Messages""#]
        process.standardOutput = output
        do {
            try process.run()
            process.waitUntilExit()
            let result = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return result == "true"
        } catch {
            return false
        }
    }
}

enum AppleScriptBuilder {
    static func sendScript(method: SendMethod, identifier: String, text: String?, attachment: String?) -> String {
        let target: String
        switch method {
        case .buddy:
            target = #"buddy "\#(escape(identifier))" of service "iMessage""#
        case .chat:
            target = #"chat id "\#(escape(identifier))""#
        }

        let payload: String
        if let attachment {
            payload = #"POSIX file "\#(escape(attachment))""#
        } else {
            payload = #""\#(escape(text ?? ""))""#
        }

        if let text, !text.isEmpty, attachment != nil {
            return """
            tell application "Messages"
                set targetService to service "iMessage"
                send "\(escape(text))" to \(target)
                send \(payload) to \(target)
            end tell
            """
        }

        return """
        tell application "Messages"
            set targetService to service "iMessage"
            send \(payload) to \(target)
        end tell
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

enum SendMethod {
    case buddy
    case chat
}
