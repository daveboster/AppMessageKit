import Foundation

private let macEpoch = Date(timeIntervalSinceReferenceDate: 0)
private let nanosecondsPerSecond: Double = 1_000_000_000

public func dateFromMacTimestampNanoseconds(_ value: Int64) -> Date {
    macEpoch.addingTimeInterval(Double(value) / nanosecondsPerSecond)
}

public func macTimestampNanoseconds(from date: Date) -> Int64 {
    Int64((date.timeIntervalSince(macEpoch) * nanosecondsPerSecond).rounded())
}
