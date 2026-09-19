import XCTest
@testable import DoubleProviders

final class SSEParserTests: XCTestCase {
    private func run(_ lines: [String]) -> [String] {
        var parser = SSEParser()
        var out: [String] = []
        for line in lines { if let payload = parser.consume(line: line) { out.append(payload) } }
        if let tail = parser.flush() { out.append(tail) }
        return out
    }

    func testDataLinesSeparatedByBlankLines() {
        XCTAssertEqual(run(["data: {\"a\":1}", "", "data: {\"b\":2}", ""]), ["{\"a\":1}", "{\"b\":2}"])
    }

    func testMultiLineDataIsJoinedWithNewline() {
        XCTAssertEqual(run(["data: one", "data: two", ""]), ["one\ntwo"])
    }

    func testCommentsAndOtherFieldsAreIgnored() {
        XCTAssertEqual(run([": keep-alive", "event: ping", "id: 7", "data: x", ""]), ["x"])
    }

    func testTrailingEventWithoutBlankLineIsFlushed() {
        XCTAssertEqual(run(["data: last"]), ["last"])
    }

    func testCarriageReturnsAreStripped() {
        XCTAssertEqual(run(["data: x\r", "\r"]), ["x"])
    }
}
