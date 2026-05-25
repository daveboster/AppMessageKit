import Foundation

public enum Bounds {
    public static let maxConcurrentSends = 1...16
    public static let sendTimeoutMilliseconds = 1_000...300_000
}

public struct IMessageConfig {
    public var databasePath: String?
    public var debug: Bool
    public var maxConcurrentSends: Int
    public var sendTimeout: Duration
    public var plugins: [any IMessagePlugin]

    public init(
        databasePath: String? = nil,
        debug: Bool = false,
        maxConcurrentSends: Int = 4,
        sendTimeout: Duration = .seconds(30),
        plugins: [any IMessagePlugin] = []
    ) {
        self.databasePath = databasePath
        self.debug = debug
        self.maxConcurrentSends = maxConcurrentSends
        self.sendTimeout = sendTimeout
        self.plugins = plugins
    }
}

func validateBound(_ value: Int, _ bounds: ClosedRange<Int>, name: String) throws -> Int {
    guard bounds.contains(value) else {
        throw IMessageError.config("\(name) must be between \(bounds.lowerBound) and \(bounds.upperBound)")
    }
    return value
}

func defaultMessagesDatabasePath(homeDirectory: String = NSHomeDirectory()) -> String {
    "\(homeDirectory)/Library/Messages/chat.db"
}

func requireMacOS() throws {
    #if os(macOS)
    return
    #else
    throw IMessageError.platform()
    #endif
}
