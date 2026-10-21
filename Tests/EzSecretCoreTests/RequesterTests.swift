import XCTest
@testable import EzSecretCore

final class RequesterTests: XCTestCase {
    func testClaudeCustomTitleBeatsAITitle() {
        let data = Data("""
        {"type":"ai-title","aiTitle":"First AI"}
        {"type":"custom-title","customTitle":"First custom"}
        {"type":"custom-title","customTitle":"Latest custom"}
        invalid custom-title
        {"type":"ai-title","aiTitle":"Latest AI"}
        """.utf8)
        XCTAssertEqual(Requester.claudeTitle(from: data), "Latest custom")
        XCTAssertEqual(Requester.claudeTitle(from: Data("{\"type\":\"ai-title\",\"aiTitle\":\"Only AI\"}".utf8)), "Only AI")
    }

    func testCodexLastMatchingID() {
        let data = Data("""
        {"id":"target","thread_name":"First"}
        {"id":"other","thread_name":"Other"}
        invalid
        {"id":"target","thread_name":"Last"}
        {"id":"other","thread_name":"Later other"}
        """.utf8)
        XCTAssertEqual(Requester.codexTitle(from: data, threadID: "target"), "Last")
        XCTAssertNil(Requester.codexTitle(from: data, threadID: "missing"))
    }

    func testDisplayTrimsFlattensAndTruncates() {
        XCTAssertEqual(Requester.display(kind: "Codex", name: " \n Demo\r\n session\t "), "Codex · Demo session")
        XCTAssertEqual(Requester.display(kind: "Claude Code", name: "  "), "Claude Code")
        XCTAssertEqual(Requester.display(name: "  " + String(repeating: "👩🏽‍💻", count: 49)), String(repeating: "👩🏽‍💻", count: 47) + "…")
    }
}
