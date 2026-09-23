import Foundation

/// The user's memory: plain markdown files on disk, seeded from `Templates/`.
///
/// Layout: `SOUL.md`, `USER.md`, `HEARTBEAT.md`, `LESSONS.md` at the root, plus
/// `projects/`, `people/`, `topics/`, `daily/`. Every file has YAML frontmatter
/// (`name`, `description`, `updated`, `aliases`). Lines starting with `_` are
/// comments and are stripped before a file is injected into a prompt.
///
/// Seeding is create-only: an existing user file is never overwritten.
public protocol Workspace: Sendable {
    var rootURL: URL { get }
    func read(_ relativePath: String) throws -> String
    func write(_ contents: String, to relativePath: String) throws

    /// The file parsed into frontmatter and body.
    func document(_ relativePath: String) throws -> MarkdownDocument

    /// One entry per markdown file in the seeded folders, for the prompt index.
    func index() throws -> [MemoryEntry]

    /// Appends one dated bullet, creating the file (and requiring a description) if needed.
    func append(_ text: String, to relativePath: String, description: String?) throws

    /// SOUL, USER, LESSONS, today's note and the memory index, in that order,
    /// frontmatter removed and comment lines stripped. Absent parts are omitted.
    func systemPrompt() throws -> String
}
