import ButlerTools
import XCTest
@testable import ButlerCore

/// A workspace whose every method fails the way the filesystem does: with a
/// Cocoa error whose text carries the user's absolute path. Nothing it says may
/// reach the model.
private struct FailingWorkspace: Workspace {
    let rootURL = URL(fileURLWithPath: "/Users/someone/Butler")
    var failure: Error {
        NSError(domain: NSCocoaErrorDomain, code: 257, userInfo: [
            NSLocalizedDescriptionKey: "The file could not be opened: /Users/someone/Butler/people/aditya.md",
            NSFilePathErrorKey: "/Users/someone/Butler/people/aditya.md",
        ])
    }

    func read(_ relativePath: String) throws -> String { throw failure }
    func write(_ contents: String, to relativePath: String) throws { throw failure }
    func document(_ relativePath: String) throws -> MarkdownDocument { throw failure }
    func index() throws -> [MemoryEntry] { throw failure }
    func append(_ text: String, to relativePath: String, description: String?) throws { throw failure }
    func systemPrompt() throws -> String { throw failure }
}

final class MemoryToolsTests: XCTestCase {
    private var root: URL!
    private var ws: MarkdownWorkspace!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "butler-tools-\(UUID().uuidString)")
        ws = MarkdownWorkspace(rootURL: root)
        try ws.seed(from: XCTUnwrap(MarkdownWorkspace.bundledTemplates))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testRiskLevelsMatchTheTaxonomy() {
        XCTAssertEqual(MemoryReadTool(workspace: ws).risk, .low)
        XCTAssertEqual(MemoryWriteTool(workspace: ws).risk, .medium)
    }

    func testSchemasNameTheRequiredArguments() throws {
        let read = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(MemoryReadTool(workspace: ws).parametersSchema.utf8)) as? [String: Any])
        XCTAssertEqual(read["required"] as? [String], ["path"])
        let write = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(MemoryWriteTool(workspace: ws).parametersSchema.utf8)) as? [String: Any])
        XCTAssertEqual(write["required"] as? [String], ["path", "text"])
        let properties = try XCTUnwrap(write["properties"] as? [String: Any])
        XCTAssertNotNil(properties["description"], "description is optional but must be offered")
    }

    func testReadReturnsTheBodyWithoutFrontmatterOrComments() async throws {
        try ws.append("Runs the backend.", to: "people/aditya.md", description: "Backend lead.")
        let output = try await MemoryReadTool(workspace: ws).invoke(arguments: #"{"path":"people/aditya.md"}"#)
        XCTAssertTrue(output.contains("Runs the backend."))
        XCTAssertFalse(output.contains("---"))
        XCTAssertFalse(output.contains("description:"))
    }

    func testReadReturnsAnErrorStringForBadInput() async throws {
        let tool = MemoryReadTool(workspace: ws)
        let missing = try await tool.invoke(arguments: #"{"path":"people/nobody.md"}"#)
        XCTAssertTrue(missing.hasPrefix("error:"), missing)
        let escape = try await tool.invoke(arguments: #"{"path":"../escape.md"}"#)
        XCTAssertTrue(escape.hasPrefix("error:"), escape)
        let malformed = try await tool.invoke(arguments: "not json")
        XCTAssertTrue(malformed.hasPrefix("error:"), malformed)
        let noPath = try await tool.invoke(arguments: #"{}"#)
        XCTAssertTrue(noPath.hasPrefix("error:"), noPath)
    }

    func testWriteCreatesThenAppends() async throws {
        let tool = MemoryWriteTool(workspace: ws)
        let created = try await tool.invoke(arguments: #"{"path":"people/aditya.md","text":"Runs the backend.","description":"Backend lead."}"#)
        XCTAssertEqual(created, "Created people/aditya.md")

        let appended = try await tool.invoke(arguments: #"{"path":"people/aditya.md","text":"Prefers small PRs."}"#)
        XCTAssertEqual(appended, "Appended to people/aditya.md")

        let body = try ws.document("people/aditya.md").body
        XCTAssertTrue(body.contains("Runs the backend."))
        XCTAssertTrue(body.contains("Prefers small PRs."))
    }

    func testWriteRefusesSoulAndReportsMissingDescription() async throws {
        let tool = MemoryWriteTool(workspace: ws)
        let refused = try await tool.invoke(arguments: #"{"path":"SOUL.md","text":"nope"}"#)
        XCTAssertTrue(refused.hasPrefix("error:"), refused)
        XCTAssertTrue(refused.contains("SOUL.md"))

        let noDescription = try await tool.invoke(arguments: #"{"path":"topics/new.md","text":"x"}"#)
        XCTAssertTrue(noDescription.hasPrefix("error:"), noDescription)
        XCTAssertTrue(noDescription.contains("description"))
    }

    // MARK: - Hostile arguments

    /// Arguments are a JSON string the model produced, so every shape it could
    /// produce has to come back as one recoverable line, never as a throw: a
    /// throw leaves the agent loop, while an `error:` line is something the
    /// model can read and fix.
    func testHostileArgumentsComeBackAsOneErrorLine() async throws {
        let giant = String(repeating: "a", count: 200_000)
        // Four Characters, 100 004 UTF-8 bytes: a length bound counted in
        // graphemes does not see this one.
        let combining = "a" + String(repeating: "\u{0301}", count: 50_000)
        // Nested deeper than a cooperative thread's 512 KB stack survives, and
        // shallower than JSONSerialization's own depth guard, so the guard
        // never fires. `invoke` is async, so this runs on that stack.
        func nested(_ depth: Int) -> String {
            String(repeating: #"{"a":"#, count: depth) + "1" + String(repeating: "}", count: depth)
        }
        let cases: [String] = [
            "",
            "   ",
            "not json",
            "null",
            "[1,2,3]",
            #"["path","people/aditya.md"]"#,
            #""people/aditya.md""#,
            #"{"path":42}"#,
            #"{"path":null}"#,
            #"{"path":true}"#,
            #"{"path":["people/aditya.md"]}"#,
            #"{"path":{"value":"people/aditya.md"}}"#,
            #"{"path":""}"#,
            #"{"path":"   "}"#,
            #"{"wrong":"people/aditya.md"}"#,
            #"{"path":"people/aditya.md""#,
            #"{"path":"/etc/passwd"}"#,
            #"{"path":"people/../../escape.md"}"#,
            #"{"path":"people/aditya.md\nname: forged"}"#,
            #"{"path":"\#(giant).md"}"#,
            #"{"path":"people/aditya.md","path":"../escape.md"}"#,
            #"{"path":"../escape.md","path":"people/aditya.md"}"#,
            String(repeating: "[", count: 1024) + String(repeating: "]", count: 1024),
            nested(500),
            nested(5_000),
            #"{"path":"\#(combining).md"}"#,
            #"{"path":"people/a\u{202E}gpj.dm\u{2066}.md"}"#,
            #"{"path":"people/a\u{200B}b.md"}"#,
            #"{"path":"people/aditya.md","text":42}"#,
            #"{"path":"people/aditya.md","text":null}"#,
            #"{"text":"orphan"}"#,
        ]
        let read = MemoryReadTool(workspace: ws)
        let write = MemoryWriteTool(workspace: ws)
        for arguments in cases {
            for output in [try await read.invoke(arguments: arguments), try await write.invoke(arguments: arguments)] {
                XCTAssertTrue(output.hasPrefix("error:"), "\(arguments.prefix(60)) -> \(output.prefix(200))")
                XCTAssertFalse(
                    output.unicodeScalars.contains(where: WorkspacePaths.isStructurallyUnsafe),
                    "an error line may not carry a character that forges one: \(output.debugDescription)"
                )
                // Bytes, not Characters: the consumer counts bytes, and 100 000
                // combining marks are four Characters.
                XCTAssertLessThan(output.utf8.count, 300, "a hostile argument may not be echoed back whole")
                assertNoAbsolutePath(output)
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: "escape.md").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.deletingLastPathComponent().appending(path: "escape.md").path))
    }

    /// A real disk failure carries the user's home directory in its text. That
    /// text is not Butler's to hand to the model.
    func testNoErrorMentionsTheUsersFilesystem() async throws {
        let failing = FailingWorkspace()
        let read = try await MemoryReadTool(workspace: failing).invoke(arguments: #"{"path":"people/aditya.md"}"#)
        XCTAssertTrue(read.hasPrefix("error:"), read)
        assertNoAbsolutePath(read)
        let write = try await MemoryWriteTool(workspace: failing)
            .invoke(arguments: #"{"path":"people/aditya.md","text":"x","description":"y"}"#)
        XCTAssertTrue(write.hasPrefix("error:"), write)
        assertNoAbsolutePath(write)
    }

    /// The same thing against the real filesystem: a file that cannot be opened.
    func testAnUnreadableFileComesBackAsACleanErrorLine() async throws {
        try XCTSkipIf(getuid() == 0, "root can read a 000 file, so there is no failure to observe")
        try ws.append("Runs the backend.", to: "people/aditya.md", description: "Backend lead.")
        let url = root.appending(path: "people/aditya.md")
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }
        XCTAssertThrowsError(try ws.read("people/aditya.md"))

        let read = try await MemoryReadTool(workspace: ws).invoke(arguments: #"{"path":"people/aditya.md"}"#)
        XCTAssertTrue(read.hasPrefix("error:"), read)
        assertNoAbsolutePath(read)
        let write = try await MemoryWriteTool(workspace: ws).invoke(arguments: #"{"path":"people/aditya.md","text":"x"}"#)
        XCTAssertTrue(write.hasPrefix("error:"), write)
        assertNoAbsolutePath(write)
    }

    /// Error text is written for the model. Nothing in it may name a place on
    /// the user's disk, neither the workspace Butler failed in nor a path the
    /// model itself guessed at.
    private func assertNoAbsolutePath(_ output: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(output.contains(root?.path ?? "/nothing"), output, file: file, line: line)
        for word in output.split(whereSeparator: \.isWhitespace) {
            XCTAssertFalse(word.hasPrefix("/"), "\(word) is an absolute path: \(output)", file: file, line: line)
        }
    }
}
