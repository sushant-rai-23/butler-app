import XCTest
@testable import DoubleCore

final class FrontmatterTests: XCTestCase {
    let sample = """
    ---
    name: soul
    description: Who Double is.
    updated: 2026-09-19
    aliases: [persona, jarvis]
    custom: kept
    ---
    # Soul

    Body text.
    """

    func testParsesKnownKeysAndKeepsUnknownOnes() {
        let doc = MarkdownDocument.parse(sample)
        XCTAssertEqual(doc.frontmatter?.name, "soul")
        XCTAssertEqual(doc.frontmatter?.description, "Who Double is.")
        XCTAssertEqual(doc.frontmatter?.updated, "2026-09-19")
        XCTAssertEqual(doc.frontmatter?.aliases, ["persona", "jarvis"])
        XCTAssertEqual(doc.frontmatter?.extra, ["custom": "kept"])
        XCTAssertEqual(doc.body, "# Soul\n\nBody text.")
    }

    func testRenderRoundTrips() {
        let doc = MarkdownDocument.parse(sample)
        XCTAssertEqual(doc.render(), sample)
    }

    func testNoFrontmatterIsJustBody() {
        let doc = MarkdownDocument.parse("# Plain\n")
        XCTAssertNil(doc.frontmatter)
        XCTAssertEqual(doc.body, "# Plain")
        XCTAssertEqual(doc.render(), "# Plain")
    }

    func testEmptyAliasesRenderAsEmptyList() {
        var doc = MarkdownDocument.parse(sample)
        doc.frontmatter?.aliases = []
        XCTAssertTrue(doc.render().contains("aliases: []"))
        XCTAssertEqual(MarkdownDocument.parse(doc.render()).frontmatter?.aliases, [])
    }
}
