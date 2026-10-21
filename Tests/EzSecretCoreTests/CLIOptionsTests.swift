import XCTest
@testable import EzSecretCore

final class CLIOptionsTests: XCTestCase {
    func testEnvFileDestinationResolvesAbsolutePath() throws {
        guard case .run(let o) = try CLIOptions.parse(["--label", "L", "--env-file", "~/x/.env", "--key", "K"]) else {
            return XCTFail()
        }
        let home = NSHomeDirectory()
        XCTAssertEqual(o.destination, .envFile(path: "\(home)/x/.env", key: "K"))
        XCTAssertEqual(o.timeoutSeconds, 300)
        XCTAssertTrue(o.clearClipboard)
        XCTAssertFalse(o.forceGUI)
        XCTAssertEqual(o.mode, .gui)
        XCTAssertEqual(o.destination.userDescription, "Will be saved to ~/x/.env → K")
    }

    func testAllFlags() throws {
        let args = ["--label", "Demo", "--keychain-service", "svc", "--keychain-account", "acct",
                    "--validate-prefix", "cfp_", "--min-length", "40", "--timeout", "0",
                    "--no-clear-clipboard", "--no-digest", "--force-gui", "--stdin"]
        guard case .run(let o) = try CLIOptions.parse(args) else { return XCTFail() }
        XCTAssertTrue(o.forceGUI)
        XCTAssertEqual(o.destination, .keychain(service: "svc", account: "acct"))
        XCTAssertEqual(o.rules, ValidationRules(requiredPrefix: "cfp_", minLength: 40))
        XCTAssertEqual(o.timeoutSeconds, 0)
        XCTAssertFalse(o.clearClipboard)
        XCTAssertFalse(o.digest)
        XCTAssertEqual(o.mode, .stdin)
    }

    func testRejectsMultipleOrMissingDestinations() {
        XCTAssertThrowsError(try CLIOptions.parse(["--label", "L", "--file", "a", "--env-file", "b", "--key", "K"]))
        XCTAssertThrowsError(try CLIOptions.parse(["--label", "L"]))
        XCTAssertThrowsError(try CLIOptions.parse(["--label", "L", "--env-file", "b"]))
        XCTAssertThrowsError(try CLIOptions.parse(["--label", "L", "--keychain-service", "s"]))
        XCTAssertThrowsError(try CLIOptions.parse(["--file", "a"]))
        XCTAssertThrowsError(try CLIOptions.parse(["--label", "L", "--env-file", "b", "--key", "bad key"]))
        XCTAssertThrowsError(try CLIOptions.parse(["--label", "L", "--file", "a", "--timeout", "-1"]))
        XCTAssertThrowsError(try CLIOptions.parse(["--label", "L", "--file", "a", "--bogus"]))
    }

    func testHelpAndVersionShortCircuit() throws {
        XCTAssertEqual(try CLIOptions.parse(["--help"]), .help)
        XCTAssertEqual(try CLIOptions.parse(["--file", "x", "--version"]), .version)
    }

    func testValidationMessagesNeverContainTheSecret() {
        let rules = ValidationRules(requiredPrefix: "sk-", minLength: 10)
        XCTAssertNil(rules.validate("sk-1234567890"))
        for bad in ["wrongprefix-value", "sk-short", ""] {
            let msg = rules.validate(bad)
            XCTAssertNotNil(msg)
            XCTAssertFalse(msg!.contains(bad), "message leaked the value: \(msg!)")
        }
        XCTAssertEqual(rules.hint, "Expected to start with “sk-” and be at least 10 characters")
    }

    func testStripTrailingNewlineOnlyRemovesOne() {
        XCTAssertEqual(stripTrailingNewline("abc\n"), "abc")
        XCTAssertEqual(stripTrailingNewline("abc\r\n"), "abc")
        XCTAssertEqual(stripTrailingNewline("abc\n\n"), "abc\n")
        XCTAssertEqual(stripTrailingNewline(" abc "), " abc ")
    }
}
