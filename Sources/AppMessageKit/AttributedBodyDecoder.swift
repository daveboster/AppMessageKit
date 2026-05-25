import Foundation

public enum AttributedBodyDecoder {
    public static func text(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        guard
            let cls = NSClassFromString("NSUnarchiver") as AnyObject?,
            let allocated = cls.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
            let unarchiver = allocated.perform(NSSelectorFromString("initForReadingWithData:"), with: data as NSData)?.takeUnretainedValue(),
            let value = unarchiver.perform(NSSelectorFromString("decodeObject"))?.takeUnretainedValue() as? NSAttributedString
        else {
            return nil
        }

        let string = value.string
        return string.isEmpty ? nil : string
    }
}
