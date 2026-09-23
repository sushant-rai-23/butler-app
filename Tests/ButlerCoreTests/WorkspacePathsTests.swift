import XCTest
@testable import ButlerCore

final class WorkspacePathsTests: XCTestCase {
    func testReadableAcceptsAnyMarkdownUnderTheRoot() throws {
        XCTAssertNoThrow(try WorkspacePaths.checkReadable("SOUL.md"))
        XCTAssertNoThrow(try WorkspacePaths.checkReadable("people/aditya.md"))
        XCTAssertNoThrow(try WorkspacePaths.checkReadable("daily/2026-09-22.md"))
    }

    func testReadableRejectsEscapesAndNonMarkdown() {
        for path in ["../secrets.md", "people/../../etc/passwd.md", "/etc/hosts.md", "notes.txt", "", "people/"] {
            XCTAssertThrowsError(try WorkspacePaths.checkReadable(path), "should reject \(path)") { error in
                XCTAssertEqual(error as? WorkspaceError, .pathNotAllowed(path))
            }
        }
    }

    func testWritableAcceptsUserLessonsAndOneLevelInAFolder() throws {
        XCTAssertNoThrow(try WorkspacePaths.checkWritable("USER.md"))
        XCTAssertNoThrow(try WorkspacePaths.checkWritable("LESSONS.md"))
        for folder in MarkdownWorkspace.folders {
            XCTAssertNoThrow(try WorkspacePaths.checkWritable("\(folder)/note.md"), "should accept \(folder)")
        }
    }

    func testWritableFoldersAreExactlyTheSeededFour() {
        // checkWritable reads MarkdownWorkspace.folders, so seeding a new folder
        // would hand the model write access to it without an edit here.
        XCTAssertEqual(MarkdownWorkspace.folders, ["projects", "people", "topics", "daily"])
    }

    func testWritableRejectsSoulHeartbeatAndDeepPaths() {
        for path in ["SOUL.md", "HEARTBEAT.md", "random.md", "projects/sub/deep.md", "unknown/file.md", "../x.md"] {
            XCTAssertThrowsError(try WorkspacePaths.checkWritable(path), "should reject \(path)") { error in
                XCTAssertEqual(error as? WorkspaceError, .pathNotAllowed(path))
            }
        }
    }

    func testRejectsSeparatorsHiddenByACombiningMark() {
        // "/" followed by a combining mark is one Swift Character, so a
        // grapheme-level split sees no ".." segment where the filesystem does.
        for path in ["../\u{0301}secrets.md", "daily/../\u{0301}x.md"] {
            XCTAssertThrowsError(try WorkspacePaths.checkReadable(path), "should reject \(path)") { error in
                XCTAssertEqual(error as? WorkspaceError, .pathNotAllowed(path))
            }
            XCTAssertThrowsError(try WorkspacePaths.checkWritable(path), "should reject \(path)") { error in
                XCTAssertEqual(error as? WorkspaceError, .pathNotAllowed(path))
            }
        }
    }

    func testRejectsNamelessFilesAndInvisibleCharacters() {
        // A zero-width name defeats the ".md" guard, and a bidi override makes a
        // model-chosen name render in the index as something it is not.
        for path in [".md", "projects/.md", "daily/a\u{0000}b.md", "daily/a\nb.md",
                     "daily/\u{200B}.md", "daily/a\u{202E}b.md", "daily/\u{FEFF}x.md",
                     "daily/a\u{2028}b.md", "daily/a\u{0085}b.md"] {
            XCTAssertThrowsError(try WorkspacePaths.checkReadable(path), "should reject \(path)") { error in
                XCTAssertEqual(error as? WorkspaceError, .pathNotAllowed(path))
            }
            XCTAssertThrowsError(try WorkspacePaths.checkWritable(path), "should reject \(path)") { error in
                XCTAssertEqual(error as? WorkspaceError, .pathNotAllowed(path))
            }
        }
    }

    func testErrorsAreReadable() {
        XCTAssertEqual(
            WorkspaceError.pathNotAllowed("SOUL.md").errorDescription,
            "SOUL.md is not a path Butler may use here."
        )
        XCTAssertEqual(
            WorkspaceError.descriptionRequired("people/new.md").errorDescription,
            "people/new.md does not exist yet, so it needs a one-line description."
        )
        XCTAssertEqual(
            WorkspaceError.folderMissing("people").errorDescription,
            "The people folder is missing from the workspace."
        )
        XCTAssertEqual(
            WorkspaceError.factRequired("people/new.md").errorDescription,
            "An append to people/new.md needs something to say."
        )
    }
}
