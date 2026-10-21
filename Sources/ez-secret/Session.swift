import CoreGraphics
import Darwin
import EzSecretCore
import Foundation

enum Session {
    enum GUIAvailability {
        case available
        case remoteSSH
        case noWindowServer

        var errorMessage: String {
            switch self {
            case .available:
                return ""
            case .remoteSSH:
                return "error: this is an ssh session (SSH_CONNECTION/SSH_TTY is set). The panel would open on the remote Mac's display, not yours. Run the same command in a terminal on that Mac's desktop, pipe the value in with --stdin, or pass --force-gui if you really are at its console."
            case .noWindowServer:
                return "error: no GUI session. ez-secret must run from a terminal on the Mac's desktop (not launchd, CI, or ssh as a user who is not logged in). Use --stdin to pipe a value in instead."
            }
        }
    }

    static func guiAvailability(forceGUI: Bool) -> GUIAvailability {
        let env = ProcessInfo.processInfo.environment
        let overSSH = env["SSH_CONNECTION"] != nil || env["SSH_TTY"] != nil || env["SSH_CLIENT"] != nil
        if overSSH && !forceGUI { return .remoteSSH }
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return .noWindowServer }
        if let onConsole = dict[kCGSessionOnConsoleKey as String] as? Bool, !onConsole { return .noWindowServer }
        return .available
    }

    static func requesterName(requester: String? = nil) -> String? {
        let env = ProcessInfo.processInfo.environment
        let shells: Set<String> = ["sh", "bash", "zsh", "fish", "dash", "login", "script", "env", "caffeinate", "tmux", "xcrun"]
        var pid = getppid()
        var visited: Set<pid_t> = []
        var fallback: String?
        var firstName: String?
        var kind: String?
        while pid > 1, visited.insert(pid).inserted {
            let argumentName = argumentZeroName(pid)
            if argumentName == "claude" || argumentName == "codex" {
                kind = argumentName == "claude" ? "Claude Code" : "Codex"
                break
            }
            if let name = argumentName ?? processName(pid) {
                if firstName == nil { firstName = name }
                if fallback == nil, !shells.contains(name) { fallback = name }
            }
            guard let next = parentPID(of: pid) else { break }
            pid = next
        }
        if kind == nil {
            if env["CODEX_THREAD_ID"] != nil { kind = "Codex" }
            else if env["CLAUDECODE"] == "1" { kind = "Claude Code" }
        }
        if let kind {
            return Requester.display(kind: kind, name: sessionTitle(kind: kind, environment: env))
        }
        if requester != nil { return Requester.display(name: requester) }
        return fallback ?? firstName
    }

    private static func sessionTitle(kind: String, environment env: [String: String]) -> String? {
        if kind == "Codex" {
            guard let id = env["CODEX_THREAD_ID"], !id.isEmpty else { return nil }
            let home = env["CODEX_HOME"] ?? NSHomeDirectory() + "/.codex"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: home).appendingPathComponent("session_index.jsonl")) else { return nil }
            return Requester.codexTitle(from: data, threadID: id)
        }
        guard let id = env["CLAUDE_CODE_SESSION_ID"], !id.isEmpty else { return nil }
        let home = env["CLAUDE_CONFIG_DIR"] ?? NSHomeDirectory() + "/.claude"
        let projects = URL(fileURLWithPath: home).appendingPathComponent("projects")
        guard let directories = try? FileManager.default.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil) else { return nil }
        for directory in directories {
            let file = directory.appendingPathComponent(id + ".jsonl")
            if let data = try? Data(contentsOf: file) { return Requester.claudeTitle(from: data) }
        }
        return nil
    }

    private static func processName(_ pid: pid_t) -> String? {
        if let name = argumentZeroName(pid) { return name }
        var buf = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let n = proc_pidpath(pid, &buf, UInt32(buf.count))
        guard n > 0 else { return nil }
        let path = String(cString: buf)
        return (path as NSString).lastPathComponent
    }

    private static func argumentZeroName(_ pid: pid_t) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size else { return nil }
        var buf = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, UInt32(mib.count), &buf, &size, nil, 0) == 0 else { return nil }
        var start = MemoryLayout<Int32>.size
        while start < size, buf[start] != 0 { start += 1 }
        while start < size, buf[start] == 0 { start += 1 }
        var end = start
        while end < size, buf[end] != 0 { end += 1 }
        guard start < end, end < size,
              let argument = String(bytes: buf[start..<end], encoding: .utf8) else { return nil }
        var name = (argument as NSString).lastPathComponent
        if name.hasPrefix("-") { name.removeFirst() }
        return name.isEmpty ? nil : name
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }
}
