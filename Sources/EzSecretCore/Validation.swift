import Foundation

public struct ValidationRules: Equatable {
    public var requiredPrefix: String?
    public var minLength: Int?

    public init(requiredPrefix: String? = nil, minLength: Int? = nil) {
        self.requiredPrefix = requiredPrefix
        self.minLength = minLength
    }

    public var isEmpty: Bool { requiredPrefix == nil && minLength == nil }

    public var hint: String? {
        var parts: [String] = []
        if let p = requiredPrefix { parts.append("start with “\(p)”") }
        if let n = minLength { parts.append("be at least \(n) characters") }
        guard !parts.isEmpty else { return nil }
        return "Expected to " + parts.joined(separator: " and ")
    }

    public func validate(_ secret: String) -> String? {
        if secret.isEmpty { return "Nothing was entered" }
        if let p = requiredPrefix, !secret.hasPrefix(p) {
            return "Value does not start with “\(p)”"
        }
        if let n = minLength, secret.count < n {
            return "Value is \(secret.count) characters; expected at least \(n)"
        }
        return nil
    }
}

public func stripTrailingNewline(_ s: String) -> String {
    var bytes = Array(s.utf8)
    guard bytes.last == 0x0A else { return s }
    bytes.removeLast()
    if bytes.last == 0x0D { bytes.removeLast() }
    return String(decoding: bytes, as: UTF8.self)
}
