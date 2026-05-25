import Foundation

public struct MessageQuery: Sendable, Equatable {
    public var chatID: String?
    public var participant: String?
    public var service: Service?
    public var isFromMe: Bool?
    public var isRead: Bool?
    public var hasAttachments: Bool?
    public var excludeReactions: Bool
    public var since: Date?
    public var before: Date?
    public var search: String?
    public var limit: Int?
    public var offset: Int?

    public init(
        chatID: String? = nil,
        participant: String? = nil,
        service: Service? = nil,
        isFromMe: Bool? = nil,
        isRead: Bool? = nil,
        hasAttachments: Bool? = nil,
        excludeReactions: Bool = false,
        since: Date? = nil,
        before: Date? = nil,
        search: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.chatID = chatID
        self.participant = participant
        self.service = service
        self.isFromMe = isFromMe
        self.isRead = isRead
        self.hasAttachments = hasAttachments
        self.excludeReactions = excludeReactions
        self.since = since
        self.before = before
        self.search = search
        self.limit = limit
        self.offset = offset
    }
}

public struct ChatQuery: Sendable, Equatable {
    public enum SortBy: String, Sendable {
        case recent
        case name
    }

    public var chatID: String?
    public var kind: ChatKind?
    public var service: Service?
    public var isArchived: Bool?
    public var hasUnread: Bool?
    public var sortBy: SortBy
    public var search: String?
    public var limit: Int?
    public var offset: Int?

    public init(
        chatID: String? = nil,
        kind: ChatKind? = nil,
        service: Service? = nil,
        isArchived: Bool? = nil,
        hasUnread: Bool? = nil,
        sortBy: SortBy = .recent,
        search: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.chatID = chatID
        self.kind = kind
        self.service = service
        self.isArchived = isArchived
        self.hasUnread = hasUnread
        self.sortBy = sortBy
        self.search = search
        self.limit = limit
        self.offset = offset
    }
}

public struct SendRequest: Sendable, Equatable {
    public var to: String
    public var text: String?
    public var attachments: [String]

    public init(to: String, text: String? = nil, attachments: [String] = []) {
        self.to = to
        self.text = text
        self.attachments = attachments
    }
}
