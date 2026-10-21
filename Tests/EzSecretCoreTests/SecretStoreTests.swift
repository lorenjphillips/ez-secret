import XCTest
import EzSecretCore

final class SecretStoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("ez-secret-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: dir)
    }

    func testEnvFileWritesTightenExistingModesAndPreserveOtherContent() throws {
        for mode: mode_t in [0o644, 0o640, 0o755] {
            let path = dir.appendingPathComponent(".env").path
            let existing = "# Keep this comment\nOTHER=keep   # inline comment\n\nTOKEN=fake-old-value\n"
            try Data(existing.utf8).write(to: URL(fileURLWithPath: path))
            XCTAssertEqual(chmod(path, mode), 0)
            XCTAssertEqual(try AtomicFile.currentMode(of: path), mode)

            _ = try SecretStore.store("fake-test-value", to: .envFile(path: path, key: "TOKEN"), label: nil)

            XCTAssertEqual(try AtomicFile.currentMode(of: path), 0o600)
            let contents = try String(contentsOfFile: path, encoding: .utf8)
            XCTAssertTrue(contents == "# Keep this comment\nOTHER=keep   # inline comment\n\nTOKEN=fake-test-value\n",
                          "dotenv write must preserve unrelated content and update the key")
        }
    }

    func testRawFileWritesTightenExistingModes() throws {
        for mode: mode_t in [0o644, 0o640, 0o755] {
            let path = dir.appendingPathComponent("token").path
            try Data("fake-old-value".utf8).write(to: URL(fileURLWithPath: path))
            XCTAssertEqual(chmod(path, mode), 0)
            XCTAssertEqual(try AtomicFile.currentMode(of: path), mode)

            _ = try SecretStore.store("fake-test-value", to: .file(path: path), label: nil)

            XCTAssertEqual(try AtomicFile.currentMode(of: path), 0o600)
            let contents = try Data(contentsOf: URL(fileURLWithPath: path))
            XCTAssertTrue(contents == Data("fake-test-value".utf8), "raw write must store the exact value")
        }
    }
}
