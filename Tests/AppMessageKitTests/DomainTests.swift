import Foundation
import Testing
@testable import AppMessageKit

@Suite("AppMessageKit domain values")
struct DomainTests {
    @Test("chat ids normalize service-prefixed group and direct-message identifiers")
    func chatIDNormalization() throws {
        let group = ChatID(userInput: " iMessage;+;chatABC123 ")
        #expect(group.raw == "iMessage;+;chatABC123")
        #expect(group.isGroup)
        #expect(group.coreIdentifier == "chatABC123")
        #expect(try group.buildGroupGUID(prefix: "any") == "any;+;chatABC123")

        let direct = ChatID.dmRecipient("+15555550123", prefix: "SMS")
        #expect(direct.raw == "SMS;-;+15555550123")
        #expect(!direct.isGroup)
        #expect(direct.extractRecipient() == "+15555550123")
        #expect(throws: IMessageError.self) {
            try direct.buildGroupGUID(prefix: "iMessage")
        }
    }

    @Test("message target resolves bare group ids and direct recipients")
    func targetResolution() throws {
        let group = try resolveTarget("chat61321855167474084")
        #expect(group == .group(ChatID(userInput: "chat61321855167474084")))

        let direct = try resolveTarget("pilot@example.test")
        #expect(direct == .direct("pilot@example.test"))
    }

    @Test("Apple nanosecond timestamps round-trip from the macOS epoch")
    func timestampConversion() {
        let date = Date(timeIntervalSince1970: 1_704_067_200)
        let mac = macTimestampNanoseconds(from: date)
        #expect(dateFromMacTimestampNanoseconds(mac) == date)
        #expect(dateFromMacTimestampNanoseconds(0) == Date(timeIntervalSinceReferenceDate: 0))
    }
}
