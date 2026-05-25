import Foundation

struct SQLQuery: @unchecked Sendable {
    var sql: String
    var arguments: [Any]
}

struct MessageQueryInput {
    var query: MessageQuery
    var sinceRowID: Int64?
    var orderByRowIDAscending: Bool
}

struct MacOS26Queries {
    private let messageFields = [
        "message.ROWID as id",
        "message.guid",
        "message.text",
        "message.attributedBody",
        "message.service",
        "message.is_from_me",
        "message.is_read",
        "message.is_sent",
        "message.is_delivered",
        "message.was_downgraded",
        "message.did_notify_recipient",
        "message.is_auto_reply",
        "message.is_system_message",
        "message.is_forward",
        "message.is_audio_message",
        "message.is_played",
        "message.is_expirable",
        "message.error",
        "message.is_spam",
        "message.is_kt_verified",
        "message.has_unseen_mention",
        "message.was_delivered_quietly",
        "message.is_sos",
        "message.is_critical",
        "message.sent_or_received_off_grid",
        "message.date",
        "message.date_delivered",
        "message.date_read",
        "message.date_played",
        "message.date_edited",
        "message.date_retracted",
        "message.date_recovered",
        "message.is_empty",
        "message.message_summary_info",
        "message.reply_to_guid",
        "message.thread_originator_guid",
        "message.group_title",
        "message.expressive_send_style_id",
        "message.balloon_bundle_id",
        "message.destination_caller_id",
        "message.ck_chat_id as ck_chat_id",
        "message.was_detonated",
        "message.expire_state",
        "message.share_status",
        "message.share_direction",
        "message.schedule_type",
        "message.schedule_state",
        "message.part_count",
        "message.cache_has_attachments",
        "message.associated_message_type",
        "message.associated_message_guid",
        "message.associated_message_emoji",
        "message.associated_message_range_location",
        "message.associated_message_range_length",
        "message.item_type",
        "message.group_action_type",
        "handle.id as participant",
        "other_handle.id as affected_participant",
        "chat.chat_identifier as chat_id",
        "chat.guid as chat_guid",
        "chat.style as chat_style"
    ]

    private let chatFields = [
        "chat.guid",
        "chat.chat_identifier",
        "chat.service_name",
        "chat.style",
        "chat.account_login",
        "chat.is_archived",
        "chat.is_filtered",
        "chat.is_blackholed",
        "chat.is_deleting_incoming_messages",
        "chat.last_read_message_timestamp",
        "chat.display_name",
        "chat_stats.last_date",
        "COALESCE(chat_stats.unread_count, 0) AS unread_count"
    ]

    private let attachmentFields = [
        "message_attachment_join.message_id as msg_id",
        "attachment.guid",
        "attachment.created_date",
        "attachment.filename",
        "attachment.uti",
        "attachment.mime_type",
        "attachment.transfer_state",
        "attachment.is_outgoing",
        "attachment.transfer_name",
        "attachment.total_bytes",
        "attachment.is_sticker",
        "attachment.is_commsafety_sensitive",
        "attachment.emoji_image_short_description"
    ]

    func messageQuery(_ input: MessageQueryInput) -> SQLQuery {
        var conditions: [String] = []
        var arguments: [Any] = []
        let filter = input.query

        appendBoolFilter(filter.isRead, column: "message.is_read", conditions: &conditions)
        appendBoolFilter(filter.isFromMe, column: "message.is_from_me", conditions: &conditions)

        if let participant = filter.participant {
            conditions.append("handle.id = ?")
            arguments.append(participant)
        }

        if let chatID = filter.chatID {
            let match = chatIDMatch(chatID, identifierColumn: "chat.chat_identifier", guidColumn: "chat.guid")
            conditions.append(match.sql)
            arguments.append(contentsOf: match.arguments)
        }

        if let service = filter.service {
            conditions.append("message.service = ?")
            arguments.append(service.rawValue)
        }

        if filter.hasAttachments == true {
            conditions.append("EXISTS (SELECT 1 FROM message_attachment_join WHERE message_attachment_join.message_id = message.ROWID)")
        } else if filter.hasAttachments == false {
            conditions.append("NOT EXISTS (SELECT 1 FROM message_attachment_join WHERE message_attachment_join.message_id = message.ROWID)")
        }

        if filter.excludeReactions {
            conditions.append("(message.associated_message_type IS NULL OR message.associated_message_type = 0)")
        }

        if let sinceRowID = input.sinceRowID {
            conditions.append("message.ROWID > ?")
            arguments.append(sinceRowID)
        }

        if let since = filter.since {
            conditions.append("message.date >= ?")
            arguments.append(macTimestampNanoseconds(from: since))
        }

        if let before = filter.before {
            conditions.append("message.date < ?")
            arguments.append(macTimestampNanoseconds(from: before))
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
        let limitOffset = limitOffsetClause(limit: filter.limit, offset: filter.offset, arguments: &arguments)
        let orderBy = input.orderByRowIDAscending ? "ORDER BY message.ROWID ASC" : "ORDER BY message.date DESC"

        return SQLQuery(sql: """
            SELECT
                \(messageFields.joined(separator: ",\n                "))
            FROM message
            LEFT JOIN handle ON message.handle_id = handle.ROWID
            LEFT JOIN handle AS other_handle ON message.other_handle = other_handle.ROWID
            LEFT JOIN chat ON chat.ROWID = (
                SELECT MIN(chat_message_join.chat_id)
                FROM chat_message_join
                WHERE chat_message_join.message_id = message.ROWID
            )
            \(whereClause)
            \(orderBy)
            \(limitOffset)
            """, arguments: arguments)
    }

    func chatQuery(_ query: ChatQuery) -> SQLQuery {
        var conditions: [String] = []
        var arguments: [Any] = []

        if let chatID = query.chatID {
            let match = chatIDMatch(chatID, identifierColumn: "chat_identifier", guidColumn: "guid")
            conditions.append(match.sql)
            arguments.append(contentsOf: match.arguments)
        }

        if query.kind == .group {
            conditions.append("style = ?")
            arguments.append(chatStyleGroup)
        } else if query.kind == .dm {
            conditions.append("style = ?")
            arguments.append(chatStyleDM)
        }

        if let service = query.service {
            conditions.append("service_name = ?")
            arguments.append(service.rawValue)
        }

        appendBoolFilter(query.isArchived, column: "is_archived", conditions: &conditions)

        if query.hasUnread == true {
            conditions.append("unread_count > 0")
        } else if query.hasUnread == false {
            conditions.append("unread_count = 0")
        }

        if let search = query.search {
            let escaped = escapeLikePattern(search)
            conditions.append("(display_name LIKE ? ESCAPE '\\' OR chat_identifier LIKE ? ESCAPE '\\')")
            arguments.append("%\(escaped)%")
            arguments.append("%\(escaped)%")
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
        let orderBy: String
        switch query.sortBy {
        case .recent:
            orderBy = "ORDER BY (last_date IS NULL), last_date DESC"
        case .name:
            orderBy = "ORDER BY (display_name IS NULL), display_name ASC"
        }
        let limitOffset = limitOffsetClause(limit: query.limit, offset: query.offset, arguments: &arguments)

        return SQLQuery(sql: """
            WITH chat_stats AS (
                SELECT
                    chat_message_join.chat_id,
                    MAX(message.date) AS last_date,
                    SUM(CASE WHEN message.is_read = 0 AND message.is_from_me = 0 THEN 1 ELSE 0 END) AS unread_count
                FROM chat_message_join
                INNER JOIN message ON message.ROWID = chat_message_join.message_id
                GROUP BY chat_message_join.chat_id
            ),
            enriched AS (
                SELECT
                    \(chatFields.joined(separator: ",\n                    "))
                FROM chat
                LEFT JOIN chat_stats ON chat_stats.chat_id = chat.ROWID
            )
            SELECT *
            FROM enriched
            \(whereClause)
            \(orderBy)
            \(limitOffset)
            """, arguments: arguments)
    }

    func attachmentQuery(messageIDs: [Int64]) -> SQLQuery {
        let placeholders = Array(repeating: "?", count: messageIDs.count).joined(separator: ",")
        return SQLQuery(sql: """
            SELECT
                \(attachmentFields.joined(separator: ",\n                "))
            FROM attachment
            INNER JOIN message_attachment_join ON attachment.ROWID = message_attachment_join.attachment_id
            WHERE message_attachment_join.message_id IN (\(placeholders))
            AND (attachment.hide_attachment IS NULL OR attachment.hide_attachment = 0)
            ORDER BY message_attachment_join.message_id ASC, message_attachment_join.attachment_id ASC
            """, arguments: messageIDs)
    }

    func maxRowIDQuery() -> SQLQuery {
        SQLQuery(sql: "SELECT MAX(ROWID) AS max_id FROM message", arguments: [])
    }

    func chatBackfillQuery(messageIDs: [Int64]) -> SQLQuery {
        let placeholders = Array(repeating: "?", count: messageIDs.count).joined(separator: ",")
        return SQLQuery(sql: """
            SELECT
                chat_message_join.message_id AS message_rowid,
                chat.chat_identifier AS chat_id,
                chat.guid AS chat_guid,
                chat.style AS chat_style
            FROM chat_message_join
            INNER JOIN chat ON chat.ROWID = chat_message_join.chat_id
            WHERE chat_message_join.message_id IN (\(placeholders))
                AND chat_message_join.chat_id = (
                    SELECT MIN(inner_join.chat_id)
                    FROM chat_message_join inner_join
                    WHERE inner_join.message_id = chat_message_join.message_id
                )
            """, arguments: messageIDs)
    }

    private func chatIDMatch(_ input: String, identifierColumn: String, guidColumn: String) -> (sql: String, arguments: [String]) {
        let core = ChatID(userInput: input).coreIdentifier
        let values = core == input ? [input] : [input, core]
        let placeholders = Array(repeating: "?", count: values.count).joined(separator: ", ")
        return (
            "(\(identifierColumn) IN (\(placeholders)) OR \(guidColumn) IN (\(placeholders)))",
            values + values
        )
    }

    private func appendBoolFilter(_ value: Bool?, column: String, conditions: inout [String]) {
        if value == true {
            conditions.append("\(column) = 1")
        } else if value == false {
            conditions.append("\(column) = 0")
        }
    }

    private func limitOffsetClause(limit: Int?, offset: Int?, arguments: inout [Any]) -> String {
        var result = ""
        if let limit, limit > 0 {
            result += "LIMIT ?"
            arguments.append(limit)
        } else if let offset, offset > 0 {
            result += "LIMIT -1"
        }
        if let offset, offset > 0 {
            result += result.isEmpty ? "OFFSET ?" : " OFFSET ?"
            arguments.append(offset)
        }
        return result
    }

    private func escapeLikePattern(_ input: String) -> String {
        input.reduce(into: "") { result, character in
            if character == "%" || character == "_" || character == "\\" {
                result.append("\\")
            }
            result.append(character)
        }
    }
}
