import Foundation
import GRDB

private struct BackfillRow: @unchecked Sendable {
    var values: [String: Any]
}

public final class MessagesDatabaseReader: @unchecked Sendable {
    private let queue: DatabaseQueue
    private let queries = MacOS26Queries()

    public init(path: String, readOnly: Bool = true) throws {
        var config = Configuration()
        config.readonly = readOnly
        do {
            queue = try DatabaseQueue(path: path, configuration: config)
        } catch {
            throw IMessageError.database("Failed to open database: \(errorMessage(error))", underlyingError: error)
        }
    }

    public func maxRowID() async throws -> Int64 {
        let query = queries.maxRowIDQuery()
        return try await queue.read { db in
            guard let row = try Row.fetchOne(db, sql: query.sql, arguments: arguments(query.arguments)) else {
                return 0
            }
            return (row["max_id"] as Int64?) ?? 0
        }
    }

    public func messages(_ query: MessageQuery = MessageQuery()) async throws -> [Message] {
        if let search = query.search, !search.isEmpty {
            return try await searchMessages(query)
        }
        return try await executeMessageQuery(queries.messageQuery(MessageQueryInput(query: query, sinceRowID: nil, orderByRowIDAscending: false)))
    }

    public func messagesSince(rowID: Int64, query: MessageQuery = MessageQuery()) async throws -> [Message] {
        let sql = queries.messageQuery(MessageQueryInput(query: query, sinceRowID: rowID, orderByRowIDAscending: true))
        let messages = try await executeMessageQuery(sql)
        return try await backfillMissingChatInfo(messages)
    }

    public func chats(_ query: ChatQuery = ChatQuery()) async throws -> [Chat] {
        let sql = queries.chatQuery(query)
        do {
            return try await queue.read { db in
                try Row.fetchAll(db, sql: sql.sql, arguments: arguments(sql.arguments))
                    .map { try MessageRowMapper.chat(from: dictionary(from: $0)) }
            }
        } catch let error as IMessageError {
            throw error
        } catch {
            throw IMessageError.database("Failed to list chats: \(errorMessage(error))", underlyingError: error)
        }
    }

    public func close() throws {
        try queue.close()
    }

    private func executeMessageQuery(_ sql: SQLQuery, includeAttachments: Bool = true) async throws -> [Message] {
        let messages: [Message]
        do {
            messages = try await queue.read { db in
                try Row.fetchAll(db, sql: sql.sql, arguments: arguments(sql.arguments))
                    .map { try MessageRowMapper.message(from: dictionary(from: $0), attachments: []) }
            }
        } catch let error as IMessageError {
            throw error
        } catch {
            throw IMessageError.database("Failed to query messages: \(errorMessage(error))", underlyingError: error)
        }

        guard includeAttachments else { return messages }
        return try await mergeAttachments(messages)
    }

    private func searchMessages(_ query: MessageQuery) async throws -> [Message] {
        let requestedOffset = query.offset ?? 0
        let requestedLimit = query.limit ?? Int.max
        let requiredMatches = requestedOffset + requestedLimit
        let pageSize = max(200, query.limit ?? 0)
        let needle = (query.search ?? "").lowercased()
        var scanOffset = 0
        var matches: [Message] = []

        while matches.count < requiredMatches {
            var pageQuery = query
            pageQuery.search = nil
            pageQuery.limit = pageSize
            pageQuery.offset = scanOffset
            let page = try await executeMessageQuery(
                queries.messageQuery(MessageQueryInput(query: pageQuery, sinceRowID: nil, orderByRowIDAscending: false)),
                includeAttachments: false
            )
            guard !page.isEmpty else { break }
            matches.append(contentsOf: page.filter { $0.text?.lowercased().contains(needle) == true })
            if page.count < pageSize { break }
            scanOffset += pageSize
        }

        let end = requestedLimit == Int.max ? matches.count : min(matches.count, requestedOffset + requestedLimit)
        guard requestedOffset < end else { return [] }
        return try await mergeAttachments(Array(matches[requestedOffset..<end]))
    }

    private func mergeAttachments(_ messages: [Message]) async throws -> [Message] {
        guard !messages.isEmpty else { return [] }
        let map = try await batchAttachments(for: messages.map(\.rowID))
        return messages.map { message in
            var updated = message
            updated.attachments = map[message.rowID] ?? []
            return updated
        }
    }

    private func batchAttachments(for messageIDs: [Int64]) async throws -> [Int64: [Attachment]] {
        var result: [Int64: [Attachment]] = [:]
        let chunkSize = 500
        for start in stride(from: 0, to: messageIDs.count, by: chunkSize) {
            let chunk = Array(messageIDs[start..<min(start + chunkSize, messageIDs.count)])
            let sql = queries.attachmentQuery(messageIDs: chunk)
            do {
                let chunkMap = try await queue.read { db in
                    var chunkResult: [Int64: [Attachment]] = [:]
                    for row in try Row.fetchAll(db, sql: sql.sql, arguments: arguments(sql.arguments)) {
                        let dict = dictionary(from: row)
                        let messageID = try requiredInt(dict["msg_id"], "attachment.msg_id")
                        let attachment = try MessageRowMapper.attachment(from: dict)
                        chunkResult[messageID, default: []].append(attachment)
                    }
                    return chunkResult
                }
                for (messageID, attachments) in chunkMap {
                    result[messageID, default: []].append(contentsOf: attachments)
                }
            } catch let error as IMessageError {
                throw error
            } catch {
                throw IMessageError.database("Failed to query attachments: \(errorMessage(error))", underlyingError: error)
            }
        }
        return result
    }

    private func backfillMissingChatInfo(_ messages: [Message]) async throws -> [Message] {
        var current = messages
        var missing = current.filter { $0.chatID == nil }.map(\.rowID)
        guard !missing.isEmpty else { return current }

        for attempt in 0...2 {
            if attempt > 0 {
                try await Task.sleep(for: .milliseconds(200))
            }
            current = try await runChatBackfillOnce(messages: current, missingIDs: missing)
            missing = current.filter { $0.chatID == nil }.map(\.rowID)
            if missing.isEmpty { break }
        }
        return current
    }

    private func runChatBackfillOnce(messages: [Message], missingIDs: [Int64]) async throws -> [Message] {
        let sql = queries.chatBackfillQuery(messageIDs: missingIDs)
        let rowsByID: [Int64: BackfillRow]
        do {
            rowsByID = try await queue.read { db in
                var rows: [Int64: BackfillRow] = [:]
                for row in try Row.fetchAll(db, sql: sql.sql, arguments: arguments(sql.arguments)) {
                    let dict = dictionary(from: row)
                    if let id = try optionalInt(dict["message_rowid"], "message.message_rowid") {
                        rows[id] = BackfillRow(values: dict)
                    }
                }
                return rows
            }
        } catch let error as IMessageError {
            throw error
        } catch {
            throw IMessageError.database("Failed to backfill chat info: \(errorMessage(error))", underlyingError: error)
        }

        return try messages.map { message in
            guard message.chatID == nil, let row = rowsByID[message.rowID] else { return message }
            return try MessageRowMapper.patchMessageChatInfo(message, row: row.values)
        }
    }
}

private func arguments(_ values: [Any]) -> StatementArguments {
    StatementArguments(values) ?? StatementArguments()
}

private func dictionary(from row: Row) -> [String: Any] {
    Dictionary(uniqueKeysWithValues: row.columnNames.map { name in
        if let value: (any DatabaseValueConvertible) = row[name] {
            return (name, value as Any)
        }
        return (name, NSNull())
    })
}
