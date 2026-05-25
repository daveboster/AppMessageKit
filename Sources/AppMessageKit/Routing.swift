import Foundation

public enum MessageTarget: Equatable, Sendable {
    case group(ChatID)
    case direct(String)
}

public func resolveTarget(_ value: String) throws -> MessageTarget {
    let chatID = ChatID(userInput: value)
    try chatID.validate()
    if chatID.isGroup {
        return .group(chatID)
    }
    return .direct(chatID.extractRecipient() ?? chatID.raw)
}
