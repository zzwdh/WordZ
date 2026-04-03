import Foundation

enum NativeDateFormatting {
    private static let iso8601ThreadKey = "WordZMac.NativeDateFormatting.ISO8601"
    private static let compactTimestampThreadKey = "WordZMac.NativeDateFormatting.CompactTimestamp"

    static func iso8601String(from date: Date) -> String {
        let dictionary = Thread.current.threadDictionary
        let formatter: ISO8601DateFormatter
        if let cached = dictionary[iso8601ThreadKey] as? ISO8601DateFormatter {
            formatter = cached
        } else {
            let created = ISO8601DateFormatter()
            created.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            dictionary[iso8601ThreadKey] = created
            formatter = created
        }
        return formatter.string(from: date)
    }

    static func compactTimestampString(from date: Date) -> String {
        let dictionary = Thread.current.threadDictionary
        let formatter: DateFormatter
        if let cached = dictionary[compactTimestampThreadKey] as? DateFormatter {
            formatter = cached
        } else {
            let created = DateFormatter()
            created.calendar = Calendar(identifier: .gregorian)
            created.locale = Locale(identifier: "en_US_POSIX")
            created.timeZone = .current
            created.dateFormat = "yyyyMMdd-HHmmss"
            dictionary[compactTimestampThreadKey] = created
            formatter = created
        }
        return formatter.string(from: date)
    }
}
