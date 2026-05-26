import Foundation

extension LibraryCatalogStore {
    func encodeJSON<T: Encodable>(_ value: T?) -> String {
        guard let value,
              let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    func decodeJSON<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        guard let data = string.data(using: .utf8), !data.isEmpty else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func timestamp() -> String {
        NativeDateFormatting.iso8601String(from: Date())
    }
}
