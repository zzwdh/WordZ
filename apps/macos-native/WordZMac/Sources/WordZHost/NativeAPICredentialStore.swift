import Foundation
import Security

package protocol NativeAPICredentialStoring: AnyObject {
    func hasCredential() -> Bool
    func loadCredential() throws -> String?
    func saveCredential(_ credential: String) throws
    func clearCredential() throws
}

package final class NativeKeychainAPICredentialStore: NativeAPICredentialStoring {
    private let service: String
    private let account: String

    package init(
        service: String = "com.zzwdh.wordz.api",
        account: String = "default"
    ) {
        self.service = service
        self.account = account
    }

    package func hasCredential() -> Bool {
        var query = baseQuery()
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    package func loadCredential() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw keychainError(status)
        }
        guard let data = item as? Data else {
            throw NSError(
                domain: "WordZMac.NativeKeychainAPICredentialStore",
                code: Int(errSecDecode),
                userInfo: [
                    NSLocalizedDescriptionKey: "无法读取 API 凭据。"
                ]
            )
        }
        return String(data: data, encoding: .utf8)
    }

    package func saveCredential(_ credential: String) throws {
        let data = Data(credential.utf8)
        var query = baseQuery()
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw keychainError(updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw keychainError(addStatus)
        }
    }

    package func clearCredential() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func keychainError(_ status: OSStatus) -> NSError {
        NSError(
            domain: "WordZMac.NativeKeychainAPICredentialStore",
            code: Int(status),
            userInfo: [
                NSLocalizedDescriptionKey: "无法访问 API 凭据存储（\(status)）。"
            ]
        )
    }
}
