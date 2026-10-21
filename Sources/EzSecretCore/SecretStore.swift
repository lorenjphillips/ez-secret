import CryptoKit
import Foundation

public struct StoreResult: Equatable {
    public let destination: Destination
    public let length: Int
    public let sha256Prefix: String?

    public var stdoutLine: String {
        var line = "stored: \(destination.stdoutDescription), length: \(length)"
        if let p = sha256Prefix { line += ", sha256-prefix: \(p)" }
        return line
    }
}

public enum SecretStore {
    public static func sha256Prefix(of secret: String, hexChars: Int = 8) -> String {
        let digest = SHA256.hash(data: Data(secret.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(hexChars))
    }

    public static func store(_ secret: String, to destination: Destination, label: String?, digest: Bool = true) throws -> StoreResult {
        switch destination {
        case .envFile(let path, let key):
            try EnvFile.upsert(path: path, key: key, value: secret)
        case .file(let path):
            try AtomicFile.write(Data(secret.utf8), to: path, mode: 0o600)
        case .keychain(let service, let account):
            try Keychain.upsert(service: service, account: account, label: label, secret: secret)
        }
        return StoreResult(
            destination: destination,
            length: secret.count,
            sha256Prefix: digest ? sha256Prefix(of: secret) : nil
        )
    }
}
