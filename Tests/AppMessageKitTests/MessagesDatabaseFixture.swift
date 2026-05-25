import Foundation
import GRDB
@testable import AppMessageKit

final class MessagesDatabaseFixture {
    let path: String
    private let queue: DatabaseQueue

    init() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("appmessagekit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        path = directory.appendingPathComponent("chat.db").path
        queue = try DatabaseQueue(path: path)
        try createSchema()
    }

    func cleanup() {
        try? queue.close()
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: path).deletingLastPathComponent())
    }

    func insertDirectMessage(text: String, attributedBody: Data? = nil, rowID: Int64, chatJoin: Bool, attachment: Bool = false) throws {
        let sender = "+1234567890"
        let service = "iMessage"
        let chatGUID = "iMessage;-;\(sender)"
        let timestamp = macTimestampNanoseconds(from: Date(timeIntervalSince1970: 1_704_067_200 + Double(rowID)))

        try queue.write { db in
            try db.execute(sql: "INSERT OR IGNORE INTO handle (ROWID, id, service) VALUES (1, ?, ?)", arguments: [sender, service])
            try db.execute(sql: """
                INSERT OR IGNORE INTO chat (
                    ROWID, guid, style, chat_identifier, service_name, display_name, is_archived,
                    is_filtered, is_blackholed, is_deleting_incoming_messages, last_read_message_timestamp
                ) VALUES (1, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0)
                """, arguments: [chatGUID, chatStyleDM, sender, service, "Test Chat"])

            try db.execute(sql: """
                INSERT INTO message (
                    ROWID, guid, text, attributedBody, service, handle_id, is_from_me, is_read, is_sent,
                    is_delivered, was_downgraded, did_notify_recipient, is_auto_reply, is_system_message,
                    is_forward, is_audio_message, is_played, is_expirable, error, is_spam, is_kt_verified,
                    has_unseen_mention, was_delivered_quietly, is_sos, is_critical, sent_or_received_off_grid,
                    date, date_delivered, date_read, date_played, date_edited, date_retracted, date_recovered,
                    is_empty, message_summary_info, reply_to_guid, thread_originator_guid, group_title,
                    expressive_send_style_id, balloon_bundle_id, destination_caller_id, ck_chat_id,
                    was_detonated, expire_state, share_status, share_direction, schedule_type, schedule_state,
                    part_count, cache_has_attachments, associated_message_type, associated_message_guid,
                    associated_message_emoji, associated_message_range_location, associated_message_range_length,
                    item_type, group_action_type
                ) VALUES (
                    ?, ?, ?, ?, ?, 1, 0, 0, 1,
                    1, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0,
                    ?, 0, 0, 0, 0, 0, 0,
                    0, NULL, NULL, NULL, NULL,
                    NULL, NULL, NULL, NULL,
                    0, 0, 0, 0, 0, 0,
                    0, ?, 0, NULL,
                    NULL, NULL, NULL,
                    0, 0
                )
                """, arguments: [
                    rowID,
                    "message-\(rowID)",
                    text,
                    attributedBody,
                    service,
                    timestamp,
                    attachment ? 1 : 0
                ])

            if chatJoin {
                try db.execute(sql: "INSERT OR IGNORE INTO chat_message_join (chat_id, message_id, message_date) VALUES (1, ?, ?)", arguments: [rowID, timestamp])
            }

            if attachment {
                try db.execute(sql: """
                    INSERT INTO attachment (
                        ROWID, guid, created_date, filename, uti, mime_type, transfer_state,
                        is_outgoing, transfer_name, total_bytes, is_sticker, is_commsafety_sensitive,
                        emoji_image_short_description, hide_attachment
                    ) VALUES (1, 'attachment-1', ?, '~/Library/test.jpg', 'public.jpeg', 'image/jpeg', 3, 0, 'test.jpg', 42, 0, 0, NULL, 0)
                    """, arguments: [timestamp])
                try db.execute(sql: "INSERT OR IGNORE INTO message_attachment_join (message_id, attachment_id) VALUES (?, 1)", arguments: [rowID])
            }
        }
    }

    func attachChatJoin(messageID: Int64) throws {
        let timestamp = macTimestampNanoseconds(from: Date(timeIntervalSince1970: 1_704_067_200 + Double(messageID)))
        try queue.write { db in
            try db.execute(sql: "INSERT OR IGNORE INTO chat_message_join (chat_id, message_id, message_date) VALUES (1, ?, ?)", arguments: [messageID, timestamp])
        }
    }

    private func createSchema() throws {
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE handle (
                    ROWID INTEGER PRIMARY KEY AUTOINCREMENT UNIQUE,
                    id TEXT NOT NULL,
                    service TEXT NOT NULL,
                    UNIQUE (id, service)
                );

                CREATE TABLE chat (
                    ROWID INTEGER PRIMARY KEY AUTOINCREMENT,
                    guid TEXT UNIQUE NOT NULL,
                    style INTEGER,
                    chat_identifier TEXT,
                    service_name TEXT,
                    account_login TEXT,
                    is_archived INTEGER DEFAULT 0,
                    display_name TEXT,
                    is_filtered INTEGER DEFAULT 0,
                    last_read_message_timestamp INTEGER DEFAULT 0,
                    is_blackholed INTEGER DEFAULT 0,
                    is_deleting_incoming_messages INTEGER DEFAULT 0
                );

                CREATE TABLE message (
                    ROWID INTEGER PRIMARY KEY AUTOINCREMENT,
                    guid TEXT NOT NULL UNIQUE,
                    text TEXT,
                    attributedBody BLOB,
                    service TEXT,
                    handle_id INTEGER DEFAULT 0,
                    error INTEGER DEFAULT 0,
                    date INTEGER,
                    date_read INTEGER,
                    date_delivered INTEGER,
                    is_delivered INTEGER DEFAULT 0,
                    is_from_me INTEGER DEFAULT 0,
                    is_empty INTEGER DEFAULT 0,
                    is_auto_reply INTEGER DEFAULT 0,
                    is_read INTEGER DEFAULT 0,
                    is_sent INTEGER DEFAULT 0,
                    is_forward INTEGER DEFAULT 0,
                    was_downgraded INTEGER DEFAULT 0,
                    is_system_message INTEGER DEFAULT 0,
                    cache_has_attachments INTEGER DEFAULT 0,
                    is_audio_message INTEGER DEFAULT 0,
                    is_played INTEGER DEFAULT 0,
                    date_played INTEGER,
                    item_type INTEGER DEFAULT 0,
                    other_handle INTEGER DEFAULT 0,
                    group_title TEXT,
                    group_action_type INTEGER DEFAULT 0,
                    share_status INTEGER DEFAULT 0,
                    share_direction INTEGER DEFAULT 0,
                    is_expirable INTEGER DEFAULT 0,
                    expire_state INTEGER DEFAULT 0,
                    associated_message_guid TEXT,
                    associated_message_type INTEGER DEFAULT 0,
                    balloon_bundle_id TEXT,
                    expressive_send_style_id TEXT,
                    associated_message_range_location INTEGER DEFAULT 0,
                    associated_message_range_length INTEGER DEFAULT 0,
                    message_summary_info BLOB,
                    destination_caller_id TEXT,
                    reply_to_guid TEXT,
                    is_spam INTEGER DEFAULT 0,
                    has_unseen_mention INTEGER DEFAULT 0,
                    thread_originator_guid TEXT,
                    was_delivered_quietly INTEGER DEFAULT 0,
                    did_notify_recipient INTEGER DEFAULT 0,
                    date_retracted INTEGER,
                    date_edited INTEGER,
                    date_recovered INTEGER,
                    was_detonated INTEGER DEFAULT 0,
                    part_count INTEGER,
                    is_sos INTEGER DEFAULT 0,
                    is_critical INTEGER DEFAULT 0,
                    is_kt_verified INTEGER DEFAULT 0,
                    associated_message_emoji TEXT,
                    schedule_type INTEGER DEFAULT 0,
                    schedule_state INTEGER DEFAULT 0,
                    sent_or_received_off_grid INTEGER DEFAULT 0,
                    ck_chat_id TEXT
                );

                CREATE TABLE chat_message_join (
                    chat_id INTEGER,
                    message_id INTEGER,
                    message_date INTEGER DEFAULT 0,
                    PRIMARY KEY (chat_id, message_id)
                );

                CREATE TABLE attachment (
                    ROWID INTEGER PRIMARY KEY AUTOINCREMENT,
                    guid TEXT NOT NULL UNIQUE,
                    created_date INTEGER DEFAULT 0,
                    filename TEXT,
                    uti TEXT,
                    mime_type TEXT,
                    transfer_state INTEGER DEFAULT 0,
                    is_outgoing INTEGER DEFAULT 0,
                    transfer_name TEXT,
                    total_bytes INTEGER DEFAULT 0,
                    is_sticker INTEGER DEFAULT 0,
                    hide_attachment INTEGER DEFAULT 0,
                    is_commsafety_sensitive INTEGER DEFAULT 0,
                    emoji_image_short_description TEXT
                );

                CREATE TABLE message_attachment_join (
                    message_id INTEGER,
                    attachment_id INTEGER,
                    UNIQUE(message_id, attachment_id)
                );
                """)
        }
    }
}
