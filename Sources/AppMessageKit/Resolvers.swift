import Foundation

let chatStyleDM: Int64 = 45
let chatStyleGroup: Int64 = 43

func resolveService(_ raw: String?) -> Service? {
    guard let raw, !raw.isEmpty else { return nil }
    return Service(rawValue: raw)
}

func resolveChatKind(_ style: Int64?) -> ChatKind {
    switch style {
    case chatStyleDM:
        return .dm
    case chatStyleGroup:
        return .group
    default:
        return .unknown
    }
}

func resolveMessageKind(itemType: Int64?, groupActionType: Int64?) -> MessageKind {
    switch itemType {
    case 0:
        return .text
    case 1:
        return groupActionType == 1 ? .memberRemoved : .memberAdded
    case 2:
        return .nameChanged
    case 3:
        return .groupAction
    default:
        return .unknown
    }
}

func resolveExpireStatus(_ code: Int64?) -> ExpireStatus {
    switch code {
    case 1:
        return .willExpire
    case 2:
        return .expired
    default:
        return .active
    }
}

func resolveShareActivity(_ code: Int64?) -> ShareActivity {
    switch code {
    case 0:
        return .none
    case 1:
        return .pending
    case 2:
        return .active
    default:
        return .unknown
    }
}

func resolveShareDirection(_ code: Int64?) -> ShareDirection {
    switch code {
    case 0:
        return .none
    case 1:
        return .incoming
    case 2:
        return .outgoing
    default:
        return .unknown
    }
}

func resolveScheduleKind(_ code: Int64?) -> ScheduleKind {
    switch code {
    case 0:
        return .none
    case 1, 2:
        return .sendLater
    default:
        return .unknown
    }
}

func resolveScheduleStatus(_ code: Int64?) -> ScheduleStatus {
    switch code {
    case 0:
        return .none
    case 1:
        return .pending
    case 2:
        return .sent
    case 3:
        return .failed
    default:
        return .unknown
    }
}

func resolveTransferStatus(_ code: Int64?) -> TransferStatus {
    switch code {
    case 0:
        return .pending
    case 1, 2:
        return .transferring
    case 3:
        return .complete
    case 4, 5:
        return .failed
    default:
        return .unknown
    }
}

func resolveReactionMeta(_ code: Int64?) -> (ReactionKind?, Bool) {
    guard let code, code != 0 else { return (nil, false) }
    let removed = code < 0
    switch abs(code) {
    case 2000:
        return (.love, removed)
    case 2001:
        return (.like, removed)
    case 2002:
        return (.dislike, removed)
    case 2003:
        return (.laugh, removed)
    case 2004:
        return (.emphasize, removed)
    case 2005:
        return (.question, removed)
    case 2006:
        return (.emoji, removed)
    case 2007:
        return (.sticker, removed)
    default:
        return (nil, false)
    }
}
