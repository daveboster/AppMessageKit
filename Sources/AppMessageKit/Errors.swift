import Foundation

public enum IMessageErrorCode: String, Sendable, Equatable {
    case platform
    case database
    case send
    case config
}

public final class IMessageError: Error, CustomStringConvertible, @unchecked Sendable {
    public let code: IMessageErrorCode
    public let message: String
    public let underlyingError: (any Error)?

    public init(_ code: IMessageErrorCode, _ message: String, underlyingError: (any Error)? = nil) {
        self.code = code
        self.message = message
        self.underlyingError = underlyingError
    }

    public var description: String {
        "\(code.rawValue.uppercased()): \(message)"
    }

    public static func platform(_ message: String = "Only macOS is supported", underlyingError: (any Error)? = nil) -> IMessageError {
        IMessageError(.platform, message, underlyingError: underlyingError)
    }

    public static func database(_ message: String, underlyingError: (any Error)? = nil) -> IMessageError {
        IMessageError(.database, message, underlyingError: underlyingError)
    }

    public static func send(_ message: String, underlyingError: (any Error)? = nil) -> IMessageError {
        IMessageError(.send, message, underlyingError: underlyingError)
    }

    public static func config(_ message: String, underlyingError: (any Error)? = nil) -> IMessageError {
        IMessageError(.config, message, underlyingError: underlyingError)
    }
}

func errorMessage(_ value: any Error) -> String {
    if let error = value as? IMessageError {
        return error.message
    }
    return String(describing: value)
}
