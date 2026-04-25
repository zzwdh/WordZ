import Foundation

package typealias JSONObject = [String: Any]

package enum JSONFieldReader {
    package static func string(_ object: JSONObject, key: String, fallback: String = "") -> String {
        String(object[key] as? String ?? fallback)
    }

    package static func bool(_ object: JSONObject, key: String, fallback: Bool = false) -> Bool {
        object[key] as? Bool ?? fallback
    }

    package static func int(_ object: JSONObject, key: String, fallback: Int = 0) -> Int {
        if let value = object[key] as? Int {
            return value
        }
        if let value = object[key] as? Double {
            return Int(value)
        }
        return fallback
    }

    package static func double(_ object: JSONObject, key: String, fallback: Double = 0) -> Double {
        if let value = object[key] as? Double {
            return value
        }
        if let value = object[key] as? Int {
            return Double(value)
        }
        return fallback
    }

    package static func dictionary(_ object: JSONObject, key: String) -> JSONObject {
        object[key] as? JSONObject ?? [:]
    }

    package static func array(_ object: JSONObject, key: String) -> [Any] {
        object[key] as? [Any] ?? []
    }

    package static func stringArray(_ object: JSONObject, key: String) -> [String] {
        if let values = object[key] as? [String] {
            return values
        }
        if let values = object[key] as? [Any] {
            return values.compactMap { $0 as? String }
        }
        if let value = object[key] as? String {
            return value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
}
