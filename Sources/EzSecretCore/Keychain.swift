import Foundation
import Security

public enum Keychain {
    public struct Error: Swift.Error, LocalizedError {
        public let operation: String
        public let status: OSStatus

        public var errorDescription: String? {
            let msg = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
            return "keychain \(operation) failed: \(msg) (OSStatus \(status))"
        }
    }

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public static func upsert(service: String, account: String, label: String?, secret: String) throws {
        let data = Data(secret.utf8)
        var query = baseQuery(service: service, account: account)

        let found = SecItemCopyMatching(query as CFDictionary, nil)
        switch found {
        case errSecSuccess:
            var attrs: [String: Any] = [kSecValueData as String: data]
            if let label { attrs[kSecAttrLabel as String] = label }
            let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
            guard status == errSecSuccess else { throw Error(operation: "update", status: status) }
        case errSecItemNotFound:
            query[kSecValueData as String] = data
            if let label { query[kSecAttrLabel as String] = label }
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else { throw Error(operation: "add", status: status) }
        default:
            throw Error(operation: "lookup", status: found)
        }
    }

    public static func read(service: String, account: String) throws -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        switch status {
        case errSecSuccess:
            guard let data = out as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw Error(operation: "read", status: status)
        }
    }

    public static func delete(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Error(operation: "delete", status: status)
        }
    }
}
