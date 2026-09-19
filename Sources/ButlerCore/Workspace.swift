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

    /// SOUL.md then USER.md, frontmatter removed, comment lines stripped.
    func systemPrompt() throws -> String
}
