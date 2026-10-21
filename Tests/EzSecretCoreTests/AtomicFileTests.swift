import XCTest
@testable import EzSecretCore

final class AtomicFileTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("ez-secret-atomic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testWritesWithMode0600RegardlessOfUmask() throws {
        let old = umask(0o022)
        defer { umask(old) }
        let path = dir.appendingPathComponent("token").path
        try AtomicFile.write(Data("s3cret".utf8), to: path, mode: 0o600)
        XCTAssertEqual(try AtomicFile.currentMode(of: path), 0o600)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "s3cret")
    }

    func testOverwriteReplacesViaRenameAndLeavesNoTemp() throws {
        let path = dir.appendingPathComponent("token").path
        try AtomicFile.write(Data("one".utf8), to: path, mode: 0o600)
        var st1 = stat(); stat(path, &st1)
        try AtomicFile.write(Data("two-longer".utf8), to: path, mode: 0o600)
        var st2 = stat(); stat(path, &st2)
        XCTAssertNotEqual(st1.st_ino, st2.st_ino, "expected a fresh inode from rename(2)")
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "two-longer")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertEqual(leftovers, ["token"])
    }

    func testMissingParentDirectoryIsAClearError() {
        let path = dir.appendingPathComponent("nope/token").path
        XCTAssertThrowsError(try AtomicFile.write(Data(), to: path, mode: 0o600)) { error in
            guard case AtomicFile.Error.parentMissing = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }
}
