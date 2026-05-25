import Foundation

public struct Service: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String { rawValue }

    public static let iMessage: Service = "iMessage"
    public static let sms: Service = "SMS"
    public static let rcs: Service = "RCS"
}

public enum ChatKind: String, Sendable, Equatable {
    case dm
    case group
    case unknown
}

public enum MessageKind: String, Sendable, Equatable {
    case text
    case memberAdded
    case memberRemoved
    case nameChanged
    case groupAction
    case unknown
}

public enum ReactionKind: String, Sendable, Equatable {
    case love
    case like
    case dislike
    case laugh
    case emphasize
    case question
    case emoji
    case sticker
}

public struct ReactionTextRange: Equatable, Sendable {
    public var location: Int
    public var length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}

public struct Reaction: Equatable, Sendable {
    public var kind: ReactionKind
    public var targetMessageID: String?
    public var emoji: String?
    public var textRange: ReactionTextRange
    public var isRemoved: Bool

    public init(kind: ReactionKind, targetMessageID: String?, emoji: String?, textRange: ReactionTextRange, isRemoved: Bool) {
        self.kind = kind
        self.targetMessageID = targetMessageID
        self.emoji = emoji
        self.textRange = textRange
        self.isRemoved = isRemoved
    }
}

public enum TransferStatus: String, Sendable, Equatable {
    case pending
    case transferring
    case complete
    case failed
    case unknown
}

public struct Attachment: Equatable, Sendable {
    public var id: String
    public var fileName: String?
    public var localPath: String?
    public var mimeType: String
    public var uti: String?
    public var sizeBytes: Int64
    public var transferStatus: TransferStatus
    public var isFromMe: Bool
    public var isSticker: Bool
    public var isSensitiveContent: Bool
    public var altText: String?
    public var createdAt: Date
}

public enum ExpireStatus: String, Sendable, Equatable {
    case active
    case willExpire
    case expired
}

public enum ShareActivity: String, Sendable, Equatable {
    case none
    case pending
    case active
    case unknown
}

public enum ShareDirection: String, Sendable, Equatable {
    case none
    case incoming
    case outgoing
    case unknown
}

public enum ScheduleKind: String, Sendable, Equatable {
    case none
    case sendLater
    case unknown
}

public enum ScheduleStatus: String, Sendable, Equatable {
    case none
    case pending
    case sent
    case failed
    case unknown
}

public struct Message: Equatable, Sendable {
    public var rowID: Int64
    public var id: String
    public var chatID: String?
    public var chatKind: ChatKind
    public var participant: String?
    public var service: Service?
    public var text: String?
    public var kind: MessageKind
    public var isFromMe: Bool
    public var isRead: Bool
    public var isSent: Bool
    public var isDelivered: Bool
    public var isDowngraded: Bool
    public var didNotifyRecipient: Bool
    public var isAutoReply: Bool
    public var isSystem: Bool
    public var isForwarded: Bool
    public var isAudioMessage: Bool
    public var isPlayed: Bool
    public var isExpirable: Bool
    public var hasError: Bool
    public var errorCode: Int64
    public var isSpam: Bool
    public var isContactKeyVerified: Bool
    public var hasUnseenMention: Bool
    public var wasDeliveredQuietly: Bool
    public var isEmergencySos: Bool
    public var isCriticalAlert: Bool
    public var isOffGrid: Bool
    public var createdAt: Date
    public var deliveredAt: Date?
    public var readAt: Date?
    public var playedAt: Date?
    public var editedAt: Date?
    public var retractedAt: Date?
    public var recoveredAt: Date?
    public var replyToMessageID: String?
    public var threadRootMessageID: String?
    public var affectedParticipant: String?
    public var newGroupName: String?
    public var sendEffect: String?
    public var appBundleID: String?
    public var isInvisibleInkRevealed: Bool
    public var expireStatus: ExpireStatus
    public var shareActivity: ShareActivity
    public var shareDirection: ShareDirection
    public var scheduleKind: ScheduleKind
    public var scheduleStatus: ScheduleStatus
    public var segmentCount: Int64
    public var hasAttachments: Bool
    public var reaction: Reaction?
    public var attachments: [Attachment]
}

public struct Chat: Equatable, Sendable {
    public var chatID: String
    public var name: String?
    public var service: Service?
    public var kind: ChatKind
    public var account: String?
    public var isArchived: Bool
    public var isFiltered: Bool
    public var dropsIncomingMessages: Bool
    public var autoDeletesIncomingMessages: Bool
    public var lastReadAt: Date?
    public var unreadCount: Int64
    public var lastMessageAt: Date?
}
