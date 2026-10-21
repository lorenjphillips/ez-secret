import Foundation

public enum AtomicFile {
    public enum Error: Swift.Error, LocalizedError {
        case parentMissing(String)
        case posix(String, Int32)

        public var errorDescription: String? {
            switch self {
            case .parentMissing(let dir):
                return "parent directory does not exist: \(dir)"
            case .posix(let op, let errnoValue):
                return "\(op) failed: \(String(cString: strerror(errnoValue))) (errno \(errnoValue))"
            }
        }
    }

    public static func write(_ data: Data, to path: String, mode: mode_t) throws {
        let dir = (path as NSString).deletingLastPathComponent
        let name = (path as NSString).lastPathComponent
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else {
            throw Error.parentMissing(dir)
        }

        let tmpPath = (dir as NSString).appendingPathComponent(".\(name).tmp-\(UUID().uuidString)")
        let fd = open(tmpPath, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw Error.posix("open(\(tmpPath))", errno) }

        var ok = false
        defer {
            if !ok { unlink(tmpPath) }
        }

        try data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            var offset = 0
            while offset < buf.count {
                let n = Darwin.write(fd, buf.baseAddress!.advanced(by: offset), buf.count - offset)
                if n < 0 {
                    if errno == EINTR { continue }
                    let e = errno
                    close(fd)
                    throw Error.posix("write", e)
                }
                offset += n
            }
        }
        if fsync(fd) != 0 {
            let e = errno
            close(fd)
            throw Error.posix("fsync", e)
        }
        if fchmod(fd, mode) != 0 {
            let e = errno
            close(fd)
            throw Error.posix("fchmod", e)
        }
        if close(fd) != 0 { throw Error.posix("close", errno) }
        if rename(tmpPath, path) != 0 { throw Error.posix("rename", errno) }
        ok = true
    }

    public static func currentMode(of path: String) throws -> mode_t? {
        var st = stat()
        if stat(path, &st) != 0 {
            if errno == ENOENT { return nil }
            throw Error.posix("stat(\(path))", errno)
        }
        return st.st_mode & 0o7777
    }
}
