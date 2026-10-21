import Foundation

public enum EnvFile {
    public enum Error: Swift.Error, LocalizedError, Equatable {
        case invalidKey(String)
        case notUTF8(String)

        public var errorDescription: String? {
            switch self {
            case .invalidKey(let k):
                return "invalid env key '\(k)': must match [A-Za-z_][A-Za-z0-9_]*"
            case .notUTF8(let p):
                return "env file is not valid UTF-8: \(p)"
            }
        }
    }

    public static func isValidKey(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first else { return false }
        guard first == "_" || (first.isASCII && CharacterSet.letters.contains(first)) else { return false }
        return key.unicodeScalars.allSatisfy { s in
            s == "_" || (s.isASCII && CharacterSet.alphanumerics.contains(s))
        }
    }

    public static func upsert(contents: String, key: String, value: String) throws -> String {
        guard isValidKey(key) else { throw Error.invalidKey(key) }
        let assignment = "\(key)=\(quote(value))"

        var lines: [String]
        if contents.isEmpty {
            lines = []
        } else {
            lines = contents.components(separatedBy: "\n")
            if contents.hasSuffix("\n") { lines.removeLast() }
        }

        var out: [String] = []
        out.reserveCapacity(lines.count + 1)
        var replaced = false
        for line in lines {
            if let prefix = matchPrefix(line: line, key: key) {
                if !replaced {
                    out.append(prefix + assignment)
                    replaced = true
                }
                continue
            }
            out.append(line)
        }
        if !replaced { out.append(assignment) }
        return out.joined(separator: "\n") + "\n"
    }

    @discardableResult
    public static func upsert(path: String, key: String, value: String) throws -> String {
        let fm = FileManager.default
        var existing = ""
        if fm.fileExists(atPath: path) {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            guard let text = String(data: data, encoding: .utf8) else { throw Error.notUTF8(path) }
            existing = text
        }
        let updated = try upsert(contents: existing, key: key, value: value)
        try AtomicFile.write(Data(updated.utf8), to: path, mode: 0o600)
        return updated
    }

    static func matchPrefix(line: String, key: String) -> String? {
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == " " || line[idx] == "\t" { idx = line.index(after: idx) }
        var rest = line[idx...]
        if rest.hasPrefix("export"), let afterExport = rest.index(rest.startIndex, offsetBy: 6, limitedBy: rest.endIndex),
           afterExport < rest.endIndex, rest[afterExport] == " " || rest[afterExport] == "\t" {
            var j = afterExport
            while j < rest.endIndex, rest[j] == " " || rest[j] == "\t" { j = rest.index(after: j) }
            rest = rest[j...]
        }
        guard rest.hasPrefix(key) else { return nil }
        var k = rest.index(rest.startIndex, offsetBy: key.count)
        while k < rest.endIndex, rest[k] == " " || rest[k] == "\t" { k = rest.index(after: k) }
        guard k < rest.endIndex, rest[k] == "=" else { return nil }
        return String(line[line.startIndex..<rest.startIndex])
    }

    public static func quote(_ value: String) -> String {
        let risky: Set<Character> = ["#", "\"", "'", "\\", "$", "`"]
        let isBareSafe = !value.isEmpty && value.unicodeScalars.allSatisfy { s in
            s.value >= 0x21 && s.value <= 0x7E && !risky.contains(Character(s))
        }
        if isBareSafe { return value }

        let hasControl = value.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7F }
        if !value.contains("'") && !hasControl {
            return "'" + value + "'"
        }

        var escaped = ""
        escaped.reserveCapacity(value.count + 2)
        for ch in value {
            switch ch {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            default: escaped.append(ch)
            }
        }
        return "\"" + escaped + "\""
    }
}
