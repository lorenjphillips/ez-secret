import Foundation

public enum Destination: Equatable {
    case envFile(path: String, key: String)
    case file(path: String)
    case keychain(service: String, account: String)

    public var userDescription: String {
        switch self {
        case .envFile(let path, let key):
            return "Will be saved to \(Destination.abbreviate(path)) → \(key)"
        case .file(let path):
            return "Will be saved to \(Destination.abbreviate(path))"
        case .keychain(let service, let account):
            return "Will be saved to the login Keychain as \(service) / \(account)"
        }
    }

    public var shortDescription: String {
        switch self {
        case .envFile(let path, let key):
            return "\(Destination.abbreviate(path)) → \(key)"
        case .file(let path):
            return Destination.abbreviate(path)
        case .keychain(let service, let account):
            return "Keychain · \(service) / \(account)"
        }
    }

    public var stdoutDescription: String {
        switch self {
        case .envFile(let path, let key):
            return "env-file \(path) key=\(key)"
        case .file(let path):
            return "file \(path)"
        case .keychain(let service, let account):
            return "keychain service=\(service) account=\(account)"
        }
    }

    public var kindName: String {
        switch self {
        case .envFile: return "env-file"
        case .file: return "file"
        case .keychain: return "keychain"
        }
    }

    public static func absolutePath(_ raw: String) -> String {
        let expanded = (raw as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") { return (expanded as NSString).standardizingPath }
        let cwd = FileManager.default.currentDirectoryPath
        return ((cwd as NSString).appendingPathComponent(expanded) as NSString).standardizingPath
    }

    public static func abbreviate(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
