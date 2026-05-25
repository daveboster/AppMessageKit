import Foundation
import Testing
@testable import AppMessageKit

@Suite("Messages database row mapping")
struct MapperTests {
    @Test("message mapper parses numeric booleans, reactions, and Tahoe retractions")
    func mapsMessageSemantics() throws {
        let sentAt = Date(timeIntervalSince1970: 1_704_067_200)
        let editedAt = Date(timeIntervalSince1970: 1_704_067_260)
        let message = try MessageRowMapper.message(
            from: messageRow([
                "is_from_me": "0",
                "is_read": "1",
                "is_sent": "1",
                "is_delivered": "0",
                "date": macTimestampNanoseconds(from: sentAt),
                "date_edited": macTimestampNanoseconds(from: editedAt),
                "date_retracted": 0,
                "is_empty": 1,
                "message_summary_info": Data([0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x52, 0x72, 0x70]),
                "associated_message_type": 2000,
                "associated_message_guid": "target-guid"
            ]),
            attachments: []
        )

        #expect(message.isFromMe == false)
        #expect(message.isRead == true)
        #expect(message.isSent == true)
        #expect(message.isDelivered == false)
        #expect(message.retractedAt == editedAt)
        #expect(message.reaction?.kind == .love)
        #expect(message.reaction?.targetMessageID == "target-guid")
        #expect(message.reaction?.textRange.location == 0)
    }

    @Test("mapper throws when required identifiers or timestamps are malformed")
    func mapperValidation() {
        #expect(throws: IMessageError.self) {
            _ = try MessageRowMapper.message(from: messageRow(["id": "bad-id"]), attachments: [])
        }

        #expect(throws: IMessageError.self) {
            _ = try MessageRowMapper.attachment(from: attachmentRow(["created_date": NSNull()]))
        }
    }

    @Test("attachment mapper resolves relative and tilde paths")
    func attachmentPathResolution() throws {
        let attachment = try MessageRowMapper.attachment(from: attachmentRow([
            "filename": "~/Library/Messages/Attachments/test.jpg",
            "transfer_name": NSNull()
        ]))

        #expect(attachment.localPath?.hasSuffix("/Library/Messages/Attachments/test.jpg") == true)
        #expect(attachment.fileName == "test.jpg")
        #expect(attachment.mimeType == "image/jpeg")
    }
}

func messageRow(_ overrides: [String: Any]) -> [String: Any] {
    var row: [String: Any] = [
        "id": 1,
        "guid": "message-guid-1",
        "text": "hello",
        "attributedBody": NSNull(),
        "service": "iMessage",
        "is_from_me": 0,
        "is_read": 1,
        "is_sent": 1,
        "is_delivered": 1,
        "was_downgraded": 0,
        "did_notify_recipient": 0,
        "is_auto_reply": 0,
        "is_system_message": 0,
        "is_forward": 0,
        "is_audio_message": 0,
        "is_played": 0,
        "is_expirable": 0,
        "error": 0,
        "is_spam": 0,
        "is_kt_verified": 0,
        "has_unseen_mention": 0,
        "was_delivered_quietly": 0,
        "is_sos": 0,
        "is_critical": 0,
        "sent_or_received_off_grid": 0,
        "date": macTimestampNanoseconds(from: Date(timeIntervalSince1970: 1_704_067_200)),
        "date_delivered": 0,
        "date_read": 0,
        "date_played": 0,
        "date_edited": 0,
        "date_retracted": 0,
        "date_recovered": 0,
        "reply_to_guid": NSNull(),
        "thread_originator_guid": NSNull(),
        "group_title": NSNull(),
        "expressive_send_style_id": NSNull(),
        "balloon_bundle_id": NSNull(),
        "destination_caller_id": NSNull(),
        "ck_chat_id": NSNull(),
        "was_detonated": 0,
        "expire_state": 0,
        "share_status": 0,
        "share_direction": 0,
        "schedule_type": 0,
        "schedule_state": 0,
        "part_count": 0,
        "cache_has_attachments": 0,
        "associated_message_type": 0,
        "associated_message_guid": NSNull(),
        "associated_message_emoji": NSNull(),
        "associated_message_range_location": NSNull(),
        "associated_message_range_length": NSNull(),
        "item_type": 0,
        "group_action_type": 0,
        "participant": "+1234567890",
        "affected_participant": NSNull(),
        "chat_id": "+1234567890",
        "chat_guid": "iMessage;-;+1234567890",
        "chat_style": 45
    ]
    row.merge(overrides) { _, new in new }
    return row
}

func attachmentRow(_ overrides: [String: Any]) -> [String: Any] {
    var row: [String: Any] = [
        "guid": "attachment-guid-1",
        "created_date": macTimestampNanoseconds(from: Date(timeIntervalSince1970: 1_704_067_200)),
        "filename": "~/Library/test.jpg",
        "uti": "public.jpeg",
        "mime_type": "image/jpeg",
        "transfer_state": 3,
        "is_outgoing": 0,
        "transfer_name": "test.jpg",
        "total_bytes": 42,
        "is_sticker": 0,
        "is_commsafety_sensitive": 0,
        "emoji_image_short_description": NSNull()
    ]
    row.merge(overrides) { _, new in new }
    return row
}
