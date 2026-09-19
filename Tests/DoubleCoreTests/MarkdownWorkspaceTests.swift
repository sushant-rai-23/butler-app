import XCTest
@testable import DoubleCore

final class MarkdownWorkspaceTests: XCTestCase {
    private var root: URL!
    private var templates: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "double-ws-\(UUID().uuidString)")
        templates = try XCTUnwrap(MarkdownWorkspace.bundledTemplates)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testSeedCreatesCoreFilesAndFoldersOnce() throws {
        let ws = MarkdownWorkspace(rootURL: root)
        XCTAssertFalse(ws.exists)
        try ws.seed(from: templates)
        XCTAssertTrue(ws.exists)
        for file in MarkdownWorkspace.coreFiles { XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: file).path), file) }
        for folder in MarkdownWorkspace.folders { XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: folder).path), folder) }
        try ws.write("# Mine", to: "USER.md")
        try ws.seed(from: templates)
        XCTAssertEqual(try ws.read("USER.md"), "# Mine\n", "seed never overwrites; write adds the trailing newline")
    }

    func testWriteBumpsUpdatedWhenFrontmatterExists() throws {
        let ws = MarkdownWorkspace(rootURL: root)
        try ws.seed(from: templates)
        var doc = try ws.document("LESSONS.md")
        doc.body += "\n- 2026-09-20: sir prefers short nudges."
        try ws.write(doc.render(), to: "LESSONS.md")
        let today = MarkdownWorkspace.dateString(Date())
        XCTAssertEqual(try ws.document("LESSONS.md").frontmatter?.updated, today)
    }

    func testSystemPromptIsSoulThenUserWithCommentsStrippedAndNoFrontmatter() throws {
        let ws = MarkdownWorkspace(rootURL: root)
        try ws.seed(from: templates)
        let prompt = try ws.systemPrompt()
        XCTAssertTrue(prompt.hasPrefix("# Soul"), String(prompt.prefix(40)))
        XCTAssertTrue(prompt.contains("# User"))
        XCTAssertFalse(prompt.contains("---\nname:"))
        XCTAssertFalse(prompt.contains("\n_"), "comment lines are stripped")
        XCTAssertTrue(prompt.contains("sir"))
    }

    func testApplyOnboardingFillsUserFile() throws {
        let ws = MarkdownWorkspace(rootURL: root)
        try ws.seed(from: templates)
        let answers = OnboardingAnswers(name: "Sushant", work: "Solo founder", hours: "09:00 to 23:00", workApps: "Xcode, Terminal", helpsWhenStuck: "Name the next step")
        try ws.applyOnboarding(answers)
        let user = try ws.document("USER.md")
        XCTAssertEqual(user.frontmatter?.name, "user")
        XCTAssertTrue(user.body.contains("Name: Sushant"))
        XCTAssertTrue(user.body.contains("Solo founder"))
        XCTAssertFalse(user.body.contains("_your name_"))
    }

    func testWatcherFiresWhenAFileChangesOnDisk() throws {
        let ws = MarkdownWorkspace(rootURL: root)
        try ws.seed(from: templates)
        let fired = expectation(description: "change observed")
        fired.assertForOverFulfill = false
        ws.changeHandler = { fired.fulfill() }
        ws.startWatching()
        defer { ws.stopWatching() }
        let url = root.appending(path: "USER.md")
        try "# edited elsewhere".write(to: url, atomically: true, encoding: .utf8)
        wait(for: [fired], timeout: 3)
    }
}
