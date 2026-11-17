import Foundation
import Security

// keep api keys in the login keychain
enum KeychainStore {
    // keep this lookup key stable across bundle identifier changes
    private static let service = "vitbashy.machelite.apikeys"

    enum Failure: Error {
        case status(OSStatus)

        var message: String {
            switch self {
            case .status(let code):
                let text = SecCopyErrorMessageString(code, nil) as String?
                return text ?? "Keychain error \(code)."
            }
        }
    }

    // attribute-only query — never prompts.
    static func exists(_ account: String) -> Bool {
        var query = baseQuery(account)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    // return nil for missing keys and throw on keychain failures
    static func read(_ account: String) throws -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure.status(status) }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    static func write(_ value: String, account: String) throws {
        let query = baseQuery(account)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try delete(account) }

        let data = Data(trimmed.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw Failure.status(update) }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let add = SecItemAdd(insert as CFDictionary, nil)
        guard add == errSecSuccess else { throw Failure.status(add) }
    }

    static func delete(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.status(status)
        }
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
