import Foundation

public enum Requester {
    public static func claudeTitle(from data: Data) -> String? {
        let customMarker = Data("custom-title".utf8)
        let aiMarker = Data("ai-title".utf8)
        var custom: [String: Any]?
        var ai: [String: Any]?
        for line in data.split(separator: 0x0a) {
            guard line.range(of: customMarker) != nil || line.range(of: aiMarker) != nil,
                  let record = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else { continue }
            switch record["type"] as? String {
            case "custom-title": custom = record
            case "ai-title": ai = record
            default: break
            }
        }
        if let custom { return custom["customTitle"] as? String }
        return ai?["aiTitle"] as? String
    }

    public static func codexTitle(from data: Data, threadID: String) -> String? {
        var title: String?
        for line in data.split(separator: 0x0a) {
            guard let record = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                  record["id"] as? String == threadID else { continue }
            title = record["thread_name"] as? String
        }
        return title
    }

    public static func display(kind: String? = nil, name: String?) -> String? {
        let title = (name ?? "").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !title.isEmpty else { return kind }
        let shortened = title.count > 48 ? String(title.prefix(47)) + "…" : title
        return kind.map { "\($0) · \(shortened)" } ?? shortened
    }
}
