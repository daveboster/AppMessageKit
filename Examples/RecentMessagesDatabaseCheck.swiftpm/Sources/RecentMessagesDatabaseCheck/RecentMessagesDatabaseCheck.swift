import AppMessageKit
import Darwin
import Foundation

struct ConversationSnapshot: Equatable {
    let ordinal: Int
    let title: String
    let chatID: String
    let kind: String
    let service: String
    let lastMessageAt: Date?
    let unreadCount: Int64

    init(
        ordinal: Int,
        title: String,
        chatID: String,
        kind: String,
        service: String,
        lastMessageAt: Date?,
        unreadCount: Int64
    ) {
        self.ordinal = ordinal
        self.title = title
        self.chatID = chatID
        self.kind = kind
        self.service = service
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
    }

    init(chat: Chat, ordinal: Int) {
        self.init(
            ordinal: ordinal,
            title: Self.title(for: chat),
            chatID: chat.chatID,
            kind: chat.kind.rawValue,
            service: chat.service?.rawValue ?? "unknown",
            lastMessageAt: chat.lastMessageAt,
            unreadCount: chat.unreadCount
        )
    }

    private static func title(for chat: Chat) -> String {
        let trimmedName = chat.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedName, !trimmedName.isEmpty else {
            return chat.chatID
        }
        return trimmedName
    }
}

enum RecentConversationFormatter {
    static func render(databasePath: String, snapshots: [ConversationSnapshot]) -> String {
        var lines = [
            "AppMessageKit Recent Messages Database Check",
            "Database: \(databasePath)",
            "Found \(snapshots.count) recent conversations"
        ]

        if snapshots.isEmpty {
            lines.append("No conversations were returned.")
            return lines.joined(separator: "\n")
        }

        lines.append("")
        lines.append(contentsOf: snapshots.map(renderSnapshot))
        return lines.joined(separator: "\n")
    }

    private static func renderSnapshot(_ snapshot: ConversationSnapshot) -> String {
        let lastMessage = snapshot.lastMessageAt.map(formatDate) ?? "unknown"
        return [
            "\(snapshot.ordinal). \(snapshot.title)",
            "   chatID: \(snapshot.chatID)",
            "   kind: \(snapshot.kind)",
            "   service: \(snapshot.service)",
            "   last message: \(lastMessage)",
            "   unread: \(snapshot.unreadCount)"
        ].joined(separator: "\n")
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

struct DatabaseCheckConfiguration {
    static let environmentDatabaseKey = "APPMESSAGEKIT_MESSAGES_DB"
    static let defaultLimit = 10

    let databasePath: String
    let limit: Int

    static func parse(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> DatabaseCheckConfiguration {
        var databasePath: String?
        var limit = defaultLimit
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-h", "--help":
                throw DatabaseCheckArgumentError.helpRequested
            case "--database", "--database-path":
                index += 1
                guard index < arguments.count else {
                    throw DatabaseCheckArgumentError.missingValue(argument)
                }
                databasePath = arguments[index]
            case "--limit":
                index += 1
                guard index < arguments.count else {
                    throw DatabaseCheckArgumentError.missingValue(argument)
                }
                guard let value = Int(arguments[index]), value > 0 else {
                    throw DatabaseCheckArgumentError.invalidLimit(arguments[index])
                }
                limit = value
            default:
                if argument.hasPrefix("--") {
                    throw DatabaseCheckArgumentError.unknownOption(argument)
                }
                guard databasePath == nil else {
                    throw DatabaseCheckArgumentError.unexpectedArgument(argument)
                }
                databasePath = argument
            }
            index += 1
        }

        let resolvedPath = databasePath
            ?? nonEmpty(environment[environmentDatabaseKey])
            ?? defaultDatabasePath()

        return DatabaseCheckConfiguration(
            databasePath: (resolvedPath as NSString).expandingTildeInPath,
            limit: limit
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    private static func defaultDatabasePath() -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Messages/chat.db")
            .path
    }
}

enum DatabaseCheckArgumentError: Error, CustomStringConvertible, Equatable {
    case helpRequested
    case invalidLimit(String)
    case missingValue(String)
    case unexpectedArgument(String)
    case unknownOption(String)

    var description: String {
        switch self {
        case .helpRequested:
            return usage()
        case .invalidLimit(let value):
            return "--limit must be a positive integer, got '\(value)'"
        case .missingValue(let option):
            return "\(option) requires a value"
        case .unexpectedArgument(let argument):
            return "Unexpected argument '\(argument)'"
        case .unknownOption(let option):
            return "Unknown option '\(option)'"
        }
    }
}

enum DatabaseCheckRuntimeError: Error, CustomStringConvertible {
    case missingDatabase(String)
    case unreadableDatabase(String)

    var description: String {
        switch self {
        case .missingDatabase(let path):
            return "No database exists at \(path)"
        case .unreadableDatabase(let path):
            return "The database is not readable at \(path)"
        }
    }
}

@main
enum RecentMessagesDatabaseCheck {
    static func main() async {
        do {
            let configuration = try DatabaseCheckConfiguration.parse()
            try verifyDatabasePath(configuration.databasePath)
            let snapshots = try await loadRecentConversations(configuration)
            print(RecentConversationFormatter.render(
                databasePath: configuration.databasePath,
                snapshots: snapshots
            ))
        } catch DatabaseCheckArgumentError.helpRequested {
            print(usage())
        } catch {
            fputs("RecentMessagesDatabaseCheck: \(error)\n\n\(usage())\n", stderr)
            exit(1)
        }
    }

    private static func verifyDatabasePath(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw DatabaseCheckRuntimeError.missingDatabase(path)
        }
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw DatabaseCheckRuntimeError.unreadableDatabase(path)
        }
    }

    private static func loadRecentConversations(
        _ configuration: DatabaseCheckConfiguration
    ) async throws -> [ConversationSnapshot] {
        let sdk = try IMessageSDK(config: IMessageConfig(databasePath: configuration.databasePath))
        do {
            let chats = try await sdk.chats(ChatQuery(sortBy: .recent, limit: configuration.limit))
            try await sdk.close()
            return chats.enumerated().map { offset, chat in
                ConversationSnapshot(chat: chat, ordinal: offset + 1)
            }
        } catch {
            try? await sdk.close()
            throw error
        }
    }
}

func usage() -> String {
    """
    Usage:
      swift run RecentMessagesDatabaseCheck [path/to/chat.db]
      swift run RecentMessagesDatabaseCheck --database /path/to/chat.db

    Options:
      --database, --database-path  Messages chat.db path.
      --limit                      Number of recent conversations to print. Default: 10.
      -h, --help                   Show this help text.

    Environment:
      \(DatabaseCheckConfiguration.environmentDatabaseKey)  Optional chat.db path.

    The example opens the database read-only through AppMessageKit. Accessing the
    live Messages database may require Full Disk Access for the host process.
    """
}
