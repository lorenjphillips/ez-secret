import XCTest
@testable import EzSecretCore

final class EnvFileTests: XCTestCase {
    func testAppendsNewKeyToFileWithoutTrailingNewline() throws {
        let out = try EnvFile.upsert(contents: "A=1\nB=2", key: "C", value: "3")
        XCTAssertEqual(out, "A=1\nB=2\nC=3\n")
    }

    func testEmptyContentsProducesSingleLine() throws {
        XCTAssertEqual(try EnvFile.upsert(contents: "", key: "K", value: "v"), "K=v\n")
    }

    func testReplacesExistingKeyInPlaceKeepingEverythingElse() throws {
        let input = """
        # Cloudflare
        CLOUDFLARE_API_TOKEN=old
        OTHER=keep   # trailing comment

        export DB_URL=postgres://x
        """
        let out = try EnvFile.upsert(contents: input, key: "CLOUDFLARE_API_TOKEN", value: "new")
        XCTAssertEqual(out, """
        # Cloudflare
        CLOUDFLARE_API_TOKEN=new
        OTHER=keep   # trailing comment

        export DB_URL=postgres://x

        """)
    }

    func testPreservesExportPrefixAndIndentation() throws {
        let out = try EnvFile.upsert(contents: "  export TOKEN = old\n", key: "TOKEN", value: "new")
        XCTAssertEqual(out, "  export TOKEN=new\n")
    }

    func testDoesNotMatchPrefixedKeysOrCommentedKeys() throws {
        let input = "TOKEN_V2=a\n#TOKEN=b\nMY_TOKEN=c\n"
        let out = try EnvFile.upsert(contents: input, key: "TOKEN", value: "x")
        XCTAssertEqual(out, "TOKEN_V2=a\n#TOKEN=b\nMY_TOKEN=c\nTOKEN=x\n")
    }

    func testCollapsesDuplicateDefinitions() throws {
        let out = try EnvFile.upsert(contents: "K=1\nX=y\nK=2\n", key: "K", value: "3")
        XCTAssertEqual(out, "K=3\nX=y\n")
    }

    func testQuotesValuesWithSpacesAndHash() throws {
        XCTAssertEqual(EnvFile.quote("plain-token_123/ab+c="), "plain-token_123/ab+c=")
        XCTAssertEqual(EnvFile.quote("has space"), "'has space'")
        XCTAssertEqual(EnvFile.quote("pass#word"), "'pass#word'")
        XCTAssertEqual(EnvFile.quote("co$t"), "'co$t'")
        XCTAssertEqual(EnvFile.quote(""), "''")
        XCTAssertEqual(EnvFile.quote("it's \"x\"\\"), "\"it's \\\"x\\\"\\\\\"")
        XCTAssertEqual(EnvFile.quote("a\nb"), "\"a\\nb\"")
        let out = try EnvFile.upsert(contents: "", key: "P", value: "two words")
        XCTAssertEqual(out, "P='two words'\n")
    }

    func testRejectsInvalidKey() {
        XCTAssertThrowsError(try EnvFile.upsert(contents: "", key: "1BAD", value: "v"))
        XCTAssertThrowsError(try EnvFile.upsert(contents: "", key: "BAD-KEY", value: "v"))
        XCTAssertFalse(EnvFile.isValidKey(""))
        XCTAssertTrue(EnvFile.isValidKey("_OK_9"))
    }

    func testFileUpsertCreatesWith0600AndTightensExistingMode() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ez-secret-env-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent(".env").path

        try EnvFile.upsert(path: path, key: "A", value: "1")
        XCTAssertEqual(try AtomicFile.currentMode(of: path), 0o600)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "A=1\n")

        XCTAssertEqual(chmod(path, 0o640), 0)
        try EnvFile.upsert(path: path, key: "B", value: "2")
        XCTAssertEqual(try AtomicFile.currentMode(of: path), 0o600)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "A=1\nB=2\n")

        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.contains(".tmp-") }
        XCTAssertEqual(leftovers, [])
    }
}
