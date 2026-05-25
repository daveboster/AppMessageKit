import Foundation
import GRDB
import Testing
@testable import AppMessageKit

@Suite("Messages database reader")
struct DatabaseReaderTests {
    @Test("fixture database supports message, chat, search, attachment, and backfill queries")
    func fixtureDatabaseQueries() async throws {
        let fixture = try MessagesDatabaseFixture()
        defer { fixture.cleanup() }

        try fixture.insertDirectMessage(text: "hello searchable", rowID: 1, chatJoin: true, attachment: true)
        try fixture.insertDirectMessage(text: "", attributedBody: AttributedBodyDecoderTestsFixture.editedBody, rowID: 2, chatJoin: true)
        try fixture.insertDirectMessage(text: "orphan", rowID: 3, chatJoin: false)

        let reader = try MessagesDatabaseReader(path: fixture.path)
        let messages = try await reader.messages(MessageQuery(limit: 10))
        #expect(messages.count == 3)
        #expect(messages.first?.attachments.count == 0)

        let search = try await reader.messages(MessageQuery(search: "Edited", limit: 10))
        #expect(search.map(\.text) == ["Edited"])

        let chats = try await reader.chats(ChatQuery(hasUnread: true))
        #expect(chats.count == 1)
        #expect(chats[0].unreadCount >= 2)

        try fixture.attachChatJoin(messageID: 3)
        let backfilled = try await reader.messagesSince(rowID: 2, query: MessageQuery(limit: 10))
        #expect(backfilled.first?.chatID != nil)
        try reader.close()
    }
}

enum AttributedBodyDecoderTestsFixture {
    static let editedBody = Data(base64Encoded: "BAtzdHJlYW10eXBlZIHoA4QBQISEhBJOU0F0dHJpYnV0ZWRTdHJpbmcAhIQITlNPYmplY3QAhZKEhIQITlNTdHJpbmcBlIQBKwZFZGl0ZWSGhAJpSQEGkoSEhAxOU0RpY3Rpb25hcnkAlIQBaQKShJaWJl9fa0lNQmFzZVdyaXRpbmdEaXJlY3Rpb25BdHRyaWJ1dGVOYW1lhpKEhIQITlNOdW1iZXIAhIQHTlNWYWx1ZQCUhAEqhIQBcZ3/hpKElpYdX19rSU1NZXNzYWdlUGFydEF0dHJpYnV0ZU5hbWWGkoSbnJ2dAIaGhg==")!
}
