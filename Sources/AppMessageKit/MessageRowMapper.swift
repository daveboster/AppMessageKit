import Foundation

public enum MessageRowMapper {
    public static func chat(from row: [String: Any]) throws -> Chat {
        let guid = try requiredNonEmptyString(row["guid"], "chat.guid")
        return Chat(
            chatID: ChatID(userInput: guid).raw,
            name: try optionalNonEmptyString(row["display_name"], "chat.display_name"),
            service: resolveService(try optionalNonEmptyString(row["service_name"], "chat.service_name")),
            kind: resolveChatKind(try optionalInt(row["style"], "chat.style")),
            account: try optionalNonEmptyString(row["account_login"], "chat.account_login"),
            isArchived: try flag(row["is_archived"], "chat.is_archived"),
            isFiltered: try flag(row["is_filtered"], "chat.is_filtered"),
            dropsIncomingMessages: try flag(row["is_blackholed"], "chat.is_blackholed"),
            autoDeletesIncomingMessages: try flag(row["is_deleting_incoming_messages"], "chat.is_deleting_incoming_messages"),
            lastReadAt: try optionalDate(row["last_read_message_timestamp"], "chat.last_read_message_timestamp"),
            unreadCount: try requiredInt(row["unread_count"], "chat.unread_count"),
            lastMessageAt: try optionalDate(row["last_date"], "chat.last_date")
        )
    }

    public static func message(from row: [String: Any], attachments: [Attachment]) throws -> Message {
        let resolved = try resolveMessageChatID(row)
        let chatKind = try resolveMessageChatKind(chatStyle: optionalInt(row["chat_style"], "message.chat_style"), chatID: resolved)
        let errorCode = try optionalInt(row["error"], "message.error") ?? 0
        let directRetract = try optionalDate(row["date_retracted"], "message.date_retracted")
        let fallbackRetract = try detectTahoeRetract(row)
            ? (optionalDate(row["date_edited"], "message.date_edited") ?? optionalDate(row["date"], "message.date"))
            : nil

        return Message(
            rowID: try requiredInt(row["id"], "message.id"),
            id: try requiredNonEmptyString(row["guid"], "message.guid"),
            chatID: resolved?.raw,
            chatKind: chatKind,
            participant: try optionalParticipant(row["participant"], "message.participant"),
            service: resolveService(try optionalNonEmptyString(row["service"], "message.service")),
            text: try resolveMessageText(row),
            kind: resolveMessageKind(
                itemType: try optionalInt(row["item_type"], "message.item_type"),
                groupActionType: try optionalInt(row["group_action_type"], "message.group_action_type")
            ),
            isFromMe: try flag(row["is_from_me"], "message.is_from_me"),
            isRead: try flag(row["is_read"], "message.is_read"),
            isSent: try flag(row["is_sent"], "message.is_sent"),
            isDelivered: try flag(row["is_delivered"], "message.is_delivered"),
            isDowngraded: try flag(row["was_downgraded"], "message.was_downgraded"),
            didNotifyRecipient: try flag(row["did_notify_recipient"], "message.did_notify_recipient"),
            isAutoReply: try flag(row["is_auto_reply"], "message.is_auto_reply"),
            isSystem: try flag(row["is_system_message"], "message.is_system_message"),
            isForwarded: try flag(row["is_forward"], "message.is_forward"),
            isAudioMessage: try flag(row["is_audio_message"], "message.is_audio_message"),
            isPlayed: try flag(row["is_played"], "message.is_played"),
            isExpirable: try flag(row["is_expirable"], "message.is_expirable"),
            hasError: errorCode != 0,
            errorCode: errorCode,
            isSpam: try flag(row["is_spam"], "message.is_spam"),
            isContactKeyVerified: try flag(row["is_kt_verified"], "message.is_kt_verified"),
            hasUnseenMention: try flag(row["has_unseen_mention"], "message.has_unseen_mention"),
            wasDeliveredQuietly: try flag(row["was_delivered_quietly"], "message.was_delivered_quietly"),
            isEmergencySos: try flag(row["is_sos"], "message.is_sos"),
            isCriticalAlert: try flag(row["is_critical"], "message.is_critical"),
            isOffGrid: try flag(row["sent_or_received_off_grid"], "message.sent_or_received_off_grid"),
            createdAt: try requiredDate(row["date"], "message.date"),
            deliveredAt: try optionalDate(row["date_delivered"], "message.date_delivered"),
            readAt: try optionalDate(row["date_read"], "message.date_read"),
            playedAt: try optionalDate(row["date_played"], "message.date_played"),
            editedAt: try optionalDate(row["date_edited"], "message.date_edited"),
            retractedAt: directRetract ?? fallbackRetract,
            recoveredAt: try optionalDate(row["date_recovered"], "message.date_recovered"),
            replyToMessageID: try optionalNonEmptyString(row["reply_to_guid"], "message.reply_to_guid"),
            threadRootMessageID: try optionalNonEmptyString(row["thread_originator_guid"], "message.thread_originator_guid"),
            affectedParticipant: try optionalParticipant(row["affected_participant"], "message.affected_participant"),
            newGroupName: try optionalNonEmptyString(row["group_title"], "message.group_title"),
            sendEffect: try optionalNonEmptyString(row["expressive_send_style_id"], "message.expressive_send_style_id"),
            appBundleID: try optionalNonEmptyString(row["balloon_bundle_id"], "message.balloon_bundle_id"),
            isInvisibleInkRevealed: try flag(row["was_detonated"], "message.was_detonated"),
            expireStatus: resolveExpireStatus(try optionalInt(row["expire_state"], "message.expire_state")),
            shareActivity: resolveShareActivity(try optionalInt(row["share_status"], "message.share_status")),
            shareDirection: resolveShareDirection(try optionalInt(row["share_direction"], "message.share_direction")),
            scheduleKind: resolveScheduleKind(try optionalInt(row["schedule_type"], "message.schedule_type")),
            scheduleStatus: resolveScheduleStatus(try optionalInt(row["schedule_state"], "message.schedule_state")),
            segmentCount: try optionalInt(row["part_count"], "message.part_count") ?? 0,
            hasAttachments: try flag(row["cache_has_attachments"], "message.cache_has_attachments"),
            reaction: try reaction(from: row),
            attachments: attachments
        )
    }

    public static func attachment(from row: [String: Any]) throws -> Attachment {
        let localPath = try resolveAttachmentLocalPath(row["filename"])
        return Attachment(
            id: try requiredNonEmptyString(row["guid"], "attachment.guid"),
            fileName: try resolveAttachmentFileName(row["transfer_name"], localPath: localPath),
            localPath: localPath,
            mimeType: try optionalNonEmptyString(row["mime_type"], "attachment.mime_type") ?? "application/octet-stream",
            uti: try optionalNonEmptyString(row["uti"], "attachment.uti"),
            sizeBytes: try optionalInt(row["total_bytes"], "attachment.total_bytes") ?? 0,
            transferStatus: resolveTransferStatus(try optionalInt(row["transfer_state"], "attachment.transfer_state")),
            isFromMe: try flag(row["is_outgoing"], "attachment.is_outgoing"),
            isSticker: try flag(row["is_sticker"], "attachment.is_sticker"),
            isSensitiveContent: try flag(row["is_commsafety_sensitive"], "attachment.is_commsafety_sensitive"),
            altText: try optionalNonEmptyString(row["emoji_image_short_description"], "attachment.emoji_image_short_description"),
            createdAt: try requiredDate(row["created_date"], "attachment.created_date")
        )
    }

    static func patchMessageChatInfo(_ message: Message, row: [String: Any]) throws -> Message {
        guard let resolved = try resolvePrimaryChatID(guid: row["chat_guid"], identifier: row["chat_id"]) else {
            return message
        }
        var updated = message
        updated.chatID = resolved.raw
        updated.chatKind = try resolveMessageChatKind(chatStyle: optionalInt(row["chat_style"], "chat.style"), chatID: resolved)
        return updated
    }

    private static func resolveMessageText(_ row: [String: Any]) throws -> String? {
        if let text = try optionalString(row["text"], "message.text"), !text.isEmpty {
            return text
        }
        guard let body = try optionalData(row["attributedBody"], "message.attributedBody") else { return nil }
        return AttributedBodyDecoder.text(from: body)
    }

    private static func reaction(from row: [String: Any]) throws -> Reaction? {
        let meta = resolveReactionMeta(try optionalInt(row["associated_message_type"], "message.associated_message_type"))
        guard let kind = meta.0 else { return nil }
        return Reaction(
            kind: kind,
            targetMessageID: try optionalNonEmptyString(row["associated_message_guid"], "message.associated_message_guid"),
            emoji: try optionalNonEmptyString(row["associated_message_emoji"], "message.associated_message_emoji"),
            textRange: ReactionTextRange(
                location: Int(try optionalInt(row["associated_message_range_location"], "message.associated_message_range_location") ?? 0),
                length: Int(try optionalInt(row["associated_message_range_length"], "message.associated_message_range_length") ?? 0)
            ),
            isRemoved: meta.1
        )
    }

    private static func resolveMessageChatID(_ row: [String: Any]) throws -> ChatID? {
        if let primary = try resolvePrimaryChatID(guid: row["chat_guid"], identifier: row["chat_id"]) {
            return primary
        }
        if let cloudKit = try optionalParticipant(row["ck_chat_id"], "message.ck_chat_id") {
            return ChatID(userInput: cloudKit)
        }
        guard try flag(row["is_from_me"], "message.is_from_me") else { return nil }
        guard let recipient = try optionalParticipant(row["destination_caller_id"], "message.destination_caller_id") else { return nil }
        let prefix = try optionalNonEmptyString(row["service"], "message.service") ?? "iMessage"
        return ChatID.dmRecipient(recipient, prefix: prefix)
    }

    private static func resolvePrimaryChatID(guid: Any?, identifier: Any?) throws -> ChatID? {
        if let guid = try optionalNonEmptyString(guid, "message.chat_guid") {
            return ChatID(userInput: guid)
        }
        if let identifier = try optionalNonEmptyString(identifier, "message.chat_id") {
            return ChatID(userInput: identifier)
        }
        return nil
    }

    private static func resolveMessageChatKind(chatStyle: Int64?, chatID: ChatID?) throws -> ChatKind {
        let styleKind = resolveChatKind(chatStyle)
        if styleKind != .unknown { return styleKind }
        guard let chatID else { return .unknown }
        return chatID.isGroup ? .group : .dm
    }

    private static func detectTahoeRetract(_ row: [String: Any]) throws -> Bool {
        guard try optionalInt(row["is_empty"], "message.is_empty") == 1 else { return false }
        guard let summary = try optionalData(row["message_summary_info"], "message.message_summary_info"), summary.count >= 6 else {
            return false
        }
        return summary.range(of: Data([0x52, 0x72, 0x70])) != nil
    }

    private static func resolveAttachmentLocalPath(_ value: Any?) throws -> String? {
        guard let filename = try optionalNonEmptyString(value, "attachment.filename") else { return nil }
        if filename.hasPrefix("~") {
            return filename.replacingOccurrences(of: #"^~"#, with: NSHomeDirectory(), options: .regularExpression)
        }
        if filename.hasPrefix("/") {
            return filename
        }
        return "\(NSHomeDirectory())/Library/Messages/Attachments/\(filename)"
    }

    private static func resolveAttachmentFileName(_ value: Any?, localPath: String?) throws -> String? {
        if let transferName = try optionalNonEmptyString(value, "attachment.transfer_name") {
            return transferName
        }
        guard let localPath else { return nil }
        let name = URL(fileURLWithPath: localPath).lastPathComponent
        return name.isEmpty ? nil : name
    }
}
