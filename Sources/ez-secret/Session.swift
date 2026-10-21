import CoreGraphics
import Darwin
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

    static func requesterName() -> String? {
        let shells: Set<String> = ["sh", "bash", "zsh", "fish", "dash", "login", "script", "env", "caffeinate", "tmux", "xcrun"]
        var pid = getppid()
        var depth = 0
        var fallback: String?
        while pid > 1, depth < 8 {
            guard let name = processName(pid) else { break }
            if fallback == nil { fallback = name }
            if !shells.contains(name) { return name }
            guard let next = parentPID(of: pid) else { break }
            pid = next
            depth += 1
        }
        return fallback
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
