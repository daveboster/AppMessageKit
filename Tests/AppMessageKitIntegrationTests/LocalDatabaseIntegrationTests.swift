import Foundation
import Testing
@testable import AppMessageKit

@Suite("Local Messages database integration")
struct LocalDatabaseIntegrationTests {
    @Test("opens an opt-in local chat database read-only")
    func opensOptInDatabase() async throws {
        guard let path = ProcessInfo.processInfo.environment["APPMESSAGEKIT_INTEGRATION_DB"], !path.isEmpty else {
            return
        }

        let reader = try MessagesDatabaseReader(path: path)
        let maxID = try await reader.maxRowID()
        #expect(maxID >= 0)
        _ = try await reader.messages(MessageQuery(limit: 5))
        _ = try await reader.chats(ChatQuery(limit: 5))
        try reader.close()
    }
}
