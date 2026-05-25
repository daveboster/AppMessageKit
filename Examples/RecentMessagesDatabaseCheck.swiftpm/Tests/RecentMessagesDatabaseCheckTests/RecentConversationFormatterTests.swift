import Foundation
import Testing
@testable import RecentMessagesDatabaseCheck

@Suite("Recent conversation formatter")
struct RecentConversationFormatterTests {
    @Test("renders database path and recent conversation snapshots")
    func rendersRecentConversationSnapshots() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshots = [
            ConversationSnapshot(
                ordinal: 1,
                title: "Family",
                chatID: "any;+;chat123",
                kind: "group",
                service: "iMessage",
                lastMessageAt: date,
                unreadCount: 2
            ),
            ConversationSnapshot(
                ordinal: 2,
                title: "+15555550123",
                chatID: "iMessage;-;+15555550123",
                kind: "dm",
                service: "SMS",
                lastMessageAt: nil,
                unreadCount: 0
            )
        ]

        let output = RecentConversationFormatter.render(
            databasePath: "/tmp/chat.db",
            snapshots: snapshots
        )

        #expect(output.contains("Database: /tmp/chat.db"))
        #expect(output.contains("Found 2 recent conversations"))
        #expect(output.contains("1. Family"))
        #expect(output.contains("unread: 2"))
        #expect(output.contains("2023-11-14T22:13:20Z"))
        #expect(output.contains("2. +15555550123"))
        #expect(output.contains("last message: unknown"))
    }

    @Test("renders an empty conversation list clearly")
    func rendersEmptyConversationList() {
        let output = RecentConversationFormatter.render(databasePath: "/tmp/chat.db", snapshots: [])

        #expect(output.contains("Found 0 recent conversations"))
        #expect(output.contains("No conversations were returned"))
    }
}
