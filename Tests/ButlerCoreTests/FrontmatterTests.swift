import XCTest
@testable import ButlerCore

final class FrontmatterTests: XCTestCase {
    private let sample = """
    ---
    name: user
    description: Who sir is.
    updated: 2026-09-19
    aliases: [profile, me]
    ---
    # User

    Body line.
    """

    func testParsesKnownKeys() {
        let doc = MarkdownDocument.parse(sample)
        XCTAssertEqual(doc.frontmatter?.name, "user")
        XCTAssertEqual(doc.frontmatter?.description, "Who sir is.")
        XCTAssertEqual(doc.frontmatter?.updated, "2026-09-19")
        XCTAssertEqual(doc.frontmatter?.aliases, ["profile", "me"])
        XCTAssertEqual(doc.body, "# User\n\nBody line.")
    }

    func testRoundTripIsByteIdentical() {
        XCTAssertEqual(MarkdownDocument.parse(sample).render(), sample)
    }

    func testUnknownKeysAndCommentsSurviveARender() {
        let text = """
        ---
        name: health
        # a YAML comment Butler does not understand
        tags:
          - sleep
          - focus
        description: Health notes.
        updated: 2026-09-01
        aliases: []
        ---
        Body.
        """
        var doc = MarkdownDocument.parse(text)
        doc.frontmatter?.updated = "2026-09-22"
        let rendered = doc.render()
        XCTAssertTrue(rendered.contains("# a YAML comment Butler does not understand"))
        XCTAssertTrue(rendered.contains("tags:\n  - sleep\n  - focus"))
        XCTAssertTrue(rendered.contains("updated: 2026-09-22"))
        XCTAssertFalse(rendered.contains("updated: 2026-09-01"))
        XCTAssertEqual(rendered.components(separatedBy: "updated:").count - 1, 1)
    }

    func testUpdatedIsAddedWhenTheBlockHasNone() {
        let text = """
        ---
        name: stray
        ---
        Body.
        """
        var doc = MarkdownDocument.parse(text)
        doc.frontmatter?.updated = "2026-09-22"
        XCTAssertTrue(doc.render().contains("updated: 2026-09-22"))
        XCTAssertTrue(doc.render().hasPrefix("---\nname: stray\n"))
    }

    func testNoFrontmatterIsLeftAlone() {
        let doc = MarkdownDocument.parse("# Plain")
        XCTAssertNil(doc.frontmatter)
        XCTAssertEqual(doc.render(), "# Plain")
    }

    func testMissingFrontmatterFieldsAreEmpty() {
        let doc = MarkdownDocument.parse("---\nname: x\n---\nBody.")
        XCTAssertEqual(doc.frontmatter?.description, "")
        XCTAssertEqual(doc.frontmatter?.aliases, [])
    }

    func testNewMakesAButlerAuthoredBlock() {
        let fm = Frontmatter.new(name: "aditya", description: "Runs the backend.", updated: "2026-09-22")
        let rendered = MarkdownDocument(frontmatter: fm, body: "- 2026-09-22: hi").render()
        XCTAssertEqual(rendered, """
        ---
        name: aditya
        description: Runs the backend.
        updated: 2026-09-22
        aliases: []
        ---
        - 2026-09-22: hi
        """)
    }

    func testNewFlattensNewlinesSoValuesCannotBreakOutOfTheBlock() {
        let fm = Frontmatter.new(
            name: "evil\n---\nbody injected",
            description: "first line\r\nsecond line",
            updated: "2026-09-22"
        )
        let rendered = MarkdownDocument(frontmatter: fm, body: "Body.").render()
        XCTAssertEqual(rendered.components(separatedBy: "\n").filter { $0 == "---" }.count, 2, rendered)
        let reparsed = MarkdownDocument.parse(rendered)
        XCTAssertEqual(reparsed.frontmatter?.name, "evil --- body injected")
        XCTAssertEqual(reparsed.frontmatter?.description, "first line second line")
        XCTAssertEqual(reparsed.body, "Body.")
    }

    func testNewTrimsSoItSurvivesItsOwnRoundTrip() {
        let padded = Frontmatter.new(name: "  spaced  ", description: "\nRuns the backend.  ", updated: "2026-09-22")
        XCTAssertEqual(padded.name, "spaced")
        XCTAssertEqual(padded.description, "Runs the backend.")
        let rendered = MarkdownDocument(frontmatter: padded, body: "Body.").render()
        XCTAssertEqual(MarkdownDocument.parse(rendered).frontmatter, padded)
    }

    func testAPatchedUpdatedCannotBreakOutOfTheBlock() {
        var doc = MarkdownDocument.parse(sample)
        doc.frontmatter?.updated = "2026-01-01\n---\nINJECTED"
        let rendered = doc.render()
        XCTAssertEqual(rendered.components(separatedBy: "\n").filter { $0 == "---" }.count, 2, rendered)
        let reparsed = MarkdownDocument.parse(rendered)
        XCTAssertEqual(reparsed.frontmatter?.updated, "2026-01-01 --- INJECTED")
        XCTAssertFalse(reparsed.body.contains("INJECTED"), rendered)
    }

    func testAnAppendedUpdatedCannotBreakOutOfTheBlock() {
        var doc = MarkdownDocument.parse("---\nname: stray\n---\nBody.")
        doc.frontmatter?.updated = "2026-01-01\n---\nINJECTED"
        let rendered = doc.render()
        XCTAssertEqual(rendered.components(separatedBy: "\n").filter { $0 == "---" }.count, 2, rendered)
        XCTAssertEqual(MarkdownDocument.parse(rendered).body, "Body.")
    }

    func testASpacedUpdatedKeyIsPatchedNotDuplicated() {
        let text = """
        ---
        name: spaced
        updated : 2026-09-01
        ---
        Body.
        """
        var doc = MarkdownDocument.parse(text)
        XCTAssertEqual(doc.frontmatter?.updated, "2026-09-01")
        doc.frontmatter?.updated = "2026-09-22"
        let rendered = doc.render()
        XCTAssertEqual(rendered.components(separatedBy: "updated").count - 1, 1, rendered)
        XCTAssertEqual(MarkdownDocument.parse(rendered).frontmatter?.updated, "2026-09-22")
    }

    func testATabIndentedKeyIsNotReadAsTopLevel() {
        let text = "---\nnested:\n\tupdated: 1999-01-01\nupdated: 2026-09-01\n---\nBody."
        var doc = MarkdownDocument.parse(text)
        XCTAssertEqual(doc.frontmatter?.updated, "2026-09-01")
        doc.frontmatter?.updated = "2026-09-22"
        let rendered = doc.render()
        XCTAssertTrue(rendered.contains("\tupdated: 1999-01-01"), rendered)
        XCTAssertTrue(rendered.contains("\nupdated: 2026-09-22"), rendered)
    }

    func testShippedTemplatesRoundTripByteForByte() throws {
        let templates = try XCTUnwrap(MarkdownWorkspace.bundledTemplates)
        for file in MarkdownWorkspace.coreFiles {
            let text = try String(contentsOf: templates.appending(path: file), encoding: .utf8)
            XCTAssertEqual(MarkdownDocument.parse(text).render(), text.trimmingTrailingNewlines(), file)
        }
    }
}
