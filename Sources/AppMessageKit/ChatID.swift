import Foundation

public struct ChatID: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    public typealias RawValue = String

    public let raw: String
    public let isGroup: Bool

    private static let groupSeparator = ";+;"
    private static let directSeparator = ";-;"

    public init(rawValue: String) {
        self.init(userInput: rawValue)
    }

    public init(userInput raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        self.raw = trimmed
        self.isGroup = Self.detectGroup(trimmed)
    }

    private init(raw: String, isGroup: Bool) {
        self.raw = raw
        self.isGroup = isGroup
    }

    public static func dmRecipient(_ recipient: String, prefix: String = "iMessage") -> ChatID {
        ChatID(raw: "\(prefix)\(directSeparator)\(recipient)", isGroup: false)
    }

    public var rawValue: String { raw }
    public var description: String { raw }

    public var coreIdentifier: String {
        extractAfter(Self.groupSeparator) ?? extractAfter(Self.directSeparator) ?? raw
    }

    public func extractRecipient() -> String? {
        extractAfter(Self.directSeparator)
    }

    public func validate() throws {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IMessageError.config("ChatID cannot be empty")
        }
        guard raw.contains(";") else { return }
        if Self.isValidPrefixedFormat(raw, separator: Self.groupSeparator) { return }
        if Self.isValidPrefixedFormat(raw, separator: Self.directSeparator) { return }
        throw IMessageError.config("Malformed chat id: \"\(raw)\" (expected service;+;guid or service;-;address)")
    }

    public func buildGroupGUID(prefix: String) throws -> String {
        guard isGroup else {
            throw IMessageError.config("buildGroupGUID is group-only; \"\(raw)\" is not a group chat id")
        }
        return "\(prefix)\(Self.groupSeparator)\(coreIdentifier)"
    }

    private func extractAfter(_ separator: String) -> String? {
        guard let range = raw.range(of: separator) else { return nil }
        let suffix = String(raw[range.upperBound...])
        return suffix.isEmpty ? nil : suffix
    }

    private static func detectGroup(_ raw: String) -> Bool {
        if raw.contains(groupSeparator) { return true }
        if raw.contains(";") { return false }
        guard raw.hasPrefix("chat"), raw.count > 4 else { return false }
        return raw.dropFirst(4).allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    private static func isValidPrefixedFormat(_ raw: String, separator: String) -> Bool {
        guard let range = raw.range(of: separator) else { return false }
        let prefix = String(raw[..<range.lowerBound])
        let suffix = String(raw[range.upperBound...])
        guard !suffix.isEmpty else { return false }
        guard let first = prefix.first, first.isLetter else { return false }
        return prefix.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-" }
    }
}
