import Foundation

typealias RawRow = [String: Any]

func normalized(_ value: Any?) -> Any? {
    if value == nil { return nil }
    if value is NSNull { return nil }
    return value
}

func optionalInt(_ value: Any?, _ field: String) throws -> Int64? {
    guard let value = normalized(value) else { return nil }
    if let value = value as? Int64 { return value }
    if let value = value as? Int { return Int64(value) }
    if let value = value as? Int32 { return Int64(value) }
    if let value = value as? UInt64, value <= Int64.max { return Int64(value) }
    if let value = value as? Double, value.isFinite { return Int64(value) }
    if let value = value as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let parsed = Int64(value) {
        return parsed
    }
    throw IMessageError.database("Invalid numeric field: \(field)")
}

func requiredInt(_ value: Any?, _ field: String) throws -> Int64 {
    guard let parsed = try optionalInt(value, field) else {
        throw IMessageError.database("Missing numeric field: \(field)")
    }
    return parsed
}

func optionalString(_ value: Any?, _ field: String) throws -> String? {
    guard let value = normalized(value) else { return nil }
    if let value = value as? String { return value }
    throw IMessageError.database("Invalid string field: \(field)")
}

func optionalNonEmptyString(_ value: Any?, _ field: String) throws -> String? {
    guard let value = try optionalString(value, field) else { return nil }
    return value.isEmpty ? nil : value
}

func requiredNonEmptyString(_ value: Any?, _ field: String) throws -> String {
    guard let parsed = try optionalNonEmptyString(value, field) else {
        throw IMessageError.database("Missing string field: \(field)")
    }
    return parsed
}

func flag(_ value: Any?, _ field: String) throws -> Bool {
    guard let value = normalized(value) else { return false }
    if let value = value as? Bool { return value }
    return try optionalInt(value, field) != 0
}

func optionalDate(_ value: Any?, _ field: String) throws -> Date? {
    guard let parsed = try optionalInt(value, field), parsed != 0 else { return nil }
    return dateFromMacTimestampNanoseconds(parsed)
}

func requiredDate(_ value: Any?, _ field: String) throws -> Date {
    dateFromMacTimestampNanoseconds(try requiredInt(value, field))
}

func optionalData(_ value: Any?, _ field: String) throws -> Data? {
    guard let value = normalized(value) else { return nil }
    if let value = value as? Data { return value }
    if let value = value as? [UInt8] { return Data(value) }
    throw IMessageError.database("Invalid data field: \(field)")
}

func optionalParticipant(_ value: Any?, _ field: String) throws -> String? {
    guard let string = try optionalString(value, field)?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else {
        return nil
    }
    return string
}
