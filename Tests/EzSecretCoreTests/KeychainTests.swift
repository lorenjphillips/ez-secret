import XCTest
@testable import EzSecretCore

final class KeychainTests: XCTestCase {
    private let service = "ez-secret.test.\(UUID().uuidString)"
    private let account = "unit-test"

    override func tearDownWithError() throws {
        try Keychain.delete(service: service, account: account)
    }

    func testUpsertReadUpdateDeleteRoundTrip() throws {
        XCTAssertNil(try Keychain.read(service: service, account: account))

        try Keychain.upsert(service: service, account: account, label: "ez-secret test", secret: "first-värde")
        XCTAssertEqual(try Keychain.read(service: service, account: account), "first-värde")

        try Keychain.upsert(service: service, account: account, label: "ez-secret test", secret: "second")
        XCTAssertEqual(try Keychain.read(service: service, account: account), "second")

        try Keychain.delete(service: service, account: account)
        XCTAssertNil(try Keychain.read(service: service, account: account))
        XCTAssertNoThrow(try Keychain.delete(service: service, account: account))
    }

    func testStoreViaSecretStoreReportsMetadataOnly() throws {
        let result = try SecretStore.store("abc", to: .keychain(service: service, account: account), label: "x")
        XCTAssertEqual(result.length, 3)
        XCTAssertEqual(result.sha256Prefix, "ba7816bf")
        XCTAssertEqual(result.stdoutLine, "stored: keychain service=\(service) account=\(account), length: 3, sha256-prefix: ba7816bf")
        XCTAssertFalse(result.stdoutLine.contains("abc,"))
        XCTAssertEqual(try Keychain.read(service: service, account: account), "abc")
    }
}
