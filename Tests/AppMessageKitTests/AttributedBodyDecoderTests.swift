import Foundation
import Testing
@testable import AppMessageKit

@Suite("Attributed body decoding")
struct AttributedBodyDecoderTests {
    @Test("decodes real chat.db attributedBody fixture blobs")
    func decodesFixtures() {
        #expect(AttributedBodyDecoder.text(from: fixture("BAtzdHJlYW10eXBlZIHoA4QBQISEhBJOU0F0dHJpYnV0ZWRTdHJpbmcAhIQITlNPYmplY3QAhZKEhIQITlNTdHJpbmcBlIQBKwZFZGl0ZWSGhAJpSQEGkoSEhAxOU0RpY3Rpb25hcnkAlIQBaQKShJaWJl9fa0lNQmFzZVdyaXRpbmdEaXJlY3Rpb25BdHRyaWJ1dGVOYW1lhpKEhIQITlNOdW1iZXIAhIQHTlNWYWx1ZQCUhAEqhIQBcZ3/hpKElpYdX19rSU1NZXNzYWdlUGFydEF0dHJpYnV0ZU5hbWWGkoSbnJ2dAIaGhg==")) == "Edited")
    }

    @Test("returns nil for empty or malformed blobs")
    func rejectsMalformedBlobs() {
        #expect(AttributedBodyDecoder.text(from: Data()) == nil)
        #expect(AttributedBodyDecoder.text(from: Data([0x01, 0x02, 0x03, 0x04])) == nil)
    }

    private func fixture(_ base64: String) -> Data {
        Data(base64Encoded: base64)!
    }
}
