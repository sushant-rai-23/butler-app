import Foundation

/// The user's memory as markdown under one root (default `~/Butler`).
public final class MarkdownWorkspace: Workspace, @unchecked Sendable {
    public static let defaultRoot = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Butler")
    public static let coreFiles = ["SOUL.md", "USER.md", "HEARTBEAT.md", "LESSONS.md"]
    public static let folders = ["projects", "people", "topics", "daily"]

    /// The Templates folder shipped with the app, or nil if the resource bundle is missing.
    public static var bundledTemplates: URL? {
        Bundle.module.url(forResource: "Templates", withExtension: nil)
    }

    public let rootURL: URL
    /// Called on a background queue after files change on disk.
    public var changeHandler: (() -> Void)?
    private var watcher: FSEventsWatcher?
    private let fileManager = FileManager.default

    public init(rootURL: URL = MarkdownWorkspace.defaultRoot) {
        self.rootURL = rootURL
    }

    public var exists: Bool {
        fileManager.fileExists(atPath: rootURL.appending(path: "SOUL.md").path)
    }

    /// Create-only: copies each core file that is missing and creates folders.
    public func seed(from templates: URL) throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        for file in Self.coreFiles {
            let target = rootURL.appending(path: file)
            guard !fileManager.fileExists(atPath: target.path) else { continue }
            try fileManager.copyItem(at: templates.appending(path: file), to: target)
        }
        for folder in Self.folders {
            try fileManager.createDirectory(at: rootURL.appending(path: folder), withIntermediateDirectories: true)
        }
    }

    public func read(_ relativePath: String) throws -> String {
        try WorkspacePaths.checkReadable(relativePath)
        let url = rootURL.appending(path: relativePath)
        try WorkspacePaths.checkContained(url, inRoot: rootURL)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Atomic write. If the content has frontmatter, `updated` becomes today.
    ///
    /// Holds the same policy as `append`: "append is the model's only write" is
    /// a convention, and this method sits next to it on the protocol, so it is
    /// where a future write tool would reach first. Folders are not created on
    /// the way — `checkWritable` only allows the ones `seed` already made.
    public func write(_ contents: String, to relativePath: String) throws {
        try WorkspacePaths.checkWritable(relativePath)
        var doc = MarkdownDocument.parse(contents)
        var text = contents
        if doc.frontmatter != nil {
            doc.frontmatter?.updated = Self.dateString(Date())
            text = doc.render()
        }
        try writeRaw(text, to: rootURL.appending(path: relativePath))
    }

    /// Appends one dated bullet, creating the file with frontmatter if needed.
    /// The existing body above the new line is never touched.
    ///
    /// Read, modify, write with no lock, on an `@unchecked Sendable` type: two
    /// concurrent appends would lose a bullet. True, and fine while the agent
    /// loop is serial; a second writer needs a serial queue here first.
    public func append(_ text: String, to relativePath: String, description: String?) throws {
        try WorkspacePaths.checkWritable(relativePath)
        let fact = WorkspacePaths.oneLine(text)
        guard !fact.isEmpty else { throw WorkspaceError.factRequired(relativePath) }
        let url = rootURL.appending(path: relativePath)
        let today = Self.dateString(Date())
        let bullet = "- \(today): \(fact)"

        if fileManager.fileExists(atPath: url.path) {
            // Through `read`, so containment is checked before the file is opened.
            let existing = try read(relativePath)
            var doc = MarkdownDocument.parse(existing)
            // Butler re-renders a file only when it can write the parse back
            // byte for byte AND there is an `updated:` line already there to
            // patch. A file that merely opens with a thematic break parses as
            // frontmatter, and rendering it would grow a key the user never
            // wrote in the middle of their prose. That file gets the bullet
            // added to its own bytes and nothing else.
            let faithful = doc.render() == existing.trimmingTrailingNewlines()
            if faithful, doc.frontmatter?.updated.isEmpty == false {
                doc.frontmatter?.updated = today
                doc.body = doc.body.isEmpty ? bullet : doc.body + "\n" + bullet
                try writeRaw(doc.render(), to: url)
            } else {
                let kept = existing.trimmingTrailingNewlines()
                try writeRaw(kept.isEmpty ? bullet : kept + "\n" + bullet, to: url)
            }
            return
        }

        // Split the way the filesystem does: a `/` followed by a combining mark
        // is one Character, so Character-based splitting would read the whole
        // path as one component, skip this check and let a raw Cocoa error —
        // which carries the absolute path — escape to the caller.
        let folder = WorkspacePaths.segments(relativePath).first ?? ""
        if Self.folders.contains(folder) {
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: &isDirectory)
            guard exists, isDirectory.boolValue else { throw WorkspaceError.folderMissing(folder) }
        }
        let trimmedDescription = (description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else { throw WorkspaceError.descriptionRequired(relativePath) }
        let name = String(url.lastPathComponent.dropLast(3))
        let doc = MarkdownDocument(
            frontmatter: .new(name: name, description: trimmedDescription, updated: today),
            body: bullet
        )
        try writeRaw(doc.render(), to: url)
    }

    private func writeRaw(_ text: String, to url: URL) throws {
        try WorkspacePaths.checkContained(url, inRoot: rootURL)
        var text = text
        if !text.hasSuffix("\n") { text += "\n" }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    public func document(_ relativePath: String) throws -> MarkdownDocument {
        MarkdownDocument.parse(try read(relativePath))
    }

    /// Body only, comments stripped: what a file contributes to a prompt.
    public func promptText(_ relativePath: String) throws -> String {
        try document(relativePath).body.strippingCommentLines().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// One entry per `.md` file directly inside the seeded folders, sorted by path.
    /// A file Butler cannot read or parse still appears, with an empty
    /// description, so nothing the model might need goes invisible. A path the
    /// model would not be allowed to open is left out instead of advertised,
    /// and so is one that leaves the workspace through a symlink.
    public func index() throws -> [MemoryEntry] {
        var entries: [MemoryEntry] = []
        for folder in Self.folders {
            let folderURL = rootURL.appending(path: folder)
            let names = (try? fileManager.contentsOfDirectory(atPath: folderURL.path)) ?? []
            for file in names where file.hasSuffix(".md") {
                let path = "\(folder)/\(file)"
                guard (try? WorkspacePaths.checkReadable(path)) != nil,
                      (try? WorkspacePaths.checkContained(folderURL.appending(path: file), inRoot: rootURL)) != nil
                else { continue }
                let fm = (try? document(path))?.frontmatter
                let name = (fm?.name).flatMap { $0.isEmpty ? nil : $0 } ?? String(file.dropLast(3))
                entries.append(MemoryEntry(
                    path: path,
                    name: name,
                    description: fm?.description ?? "",
                    updated: fm?.updated ?? ""
                ))
            }
        }
        return entries.sorted { $0.path < $1.path }
    }

    /// SOUL, USER, LESSONS, today's note if there is one, then the memory index.
    /// Each part is omitted when empty, so the prompt never carries placeholders.
    /// A missing LESSONS.md or daily note is normal, not an error; SOUL and USER
    /// still throw, because without them there is no persona.
    ///
    /// Bodies go in verbatim, the way SOUL and USER always have: in Butler the
    /// workspace IS the prompt, and the line held is structural — a value may
    /// say anything, but may not break out of its slot. `# Today` and the index
    /// heading are slots Butler authors, and nothing the model writes can open a
    /// section beside them, because `append` is its only write and folds a fact
    /// into one dated bullet. `write` would not: wiring a tool to it puts a
    /// model-authored heading one line above Butler's own, and this decision
    /// has to be made again on that day.
    ///
    /// Butler's own sections are h1 on purpose. Every template body opens with
    /// one — `# Soul`, `# User`, `# Lessons` — so an h2 here would nest today's
    /// events and the index under whichever file came last, and they would read
    /// as that file's content. Do not demote them because h2 looks tidier.
    public func systemPrompt() throws -> String {
        var parts = [try promptText("SOUL.md"), try promptText("USER.md")]
        if let lessons = try? promptText("LESSONS.md") { parts.append(lessons) }
        let todayPath = "daily/\(Self.dateString(Date())).md"
        if let today = try? promptText(todayPath), !today.isEmpty {
            parts.append("# Today\n\(today)")
        }
        parts.append(MemoryEntry.render((try? index()) ?? []))
        return parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    public func applyOnboarding(_ answers: OnboardingAnswers) throws {
        var doc = try document("USER.md")
        doc.body = answers.renderBody()
        try write(doc.render(), to: "USER.md")
    }

    public func startWatching() {
        stopWatching()
        let watcher = FSEventsWatcher(root: rootURL) { [weak self] in
            self?.changeHandler?()
        }
        watcher.start()
        self.watcher = watcher
    }

    public func stopWatching() {
        watcher?.stop()
        watcher = nil
    }

    public static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
