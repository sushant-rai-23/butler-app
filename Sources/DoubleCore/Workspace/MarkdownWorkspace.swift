import Foundation

/// The user's memory as markdown under one root (default `~/Double`).
public final class MarkdownWorkspace: Workspace, @unchecked Sendable {
    public static let defaultRoot = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Double")
    public static let coreFiles = ["SOUL.md", "USER.md", "HEARTBEAT.md", "LESSONS.md"]
    public static let folders = ["projects", "people", "topics", "daily"]

    /// The Templates folder shipped with the app, or nil if the resource bundle is missing.
    public static var bundledTemplates: URL? {
        Bundle.module.url(forResource: "Templates", withExtension: nil)
    }

    public let rootURL: URL
    /// Called on a background queue after files change on disk.
    public var changeHandler: (() -> Void)?
    private var watcher: FileWatcher?
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
        try String(contentsOf: rootURL.appending(path: relativePath), encoding: .utf8)
    }

    /// Atomic write. If the content has frontmatter, `updated` becomes today.
    public func write(_ contents: String, to relativePath: String) throws {
        var doc = MarkdownDocument.parse(contents)
        var text = contents
        if doc.frontmatter != nil {
            doc.frontmatter?.updated = Self.dateString(Date())
            text = doc.render()
        }
        if !text.hasSuffix("\n") { text += "\n" }
        let url = rootURL.appending(path: relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    public func document(_ relativePath: String) throws -> MarkdownDocument {
        MarkdownDocument.parse(try read(relativePath))
    }

    /// Body only, comments stripped: what a file contributes to a prompt.
    public func promptText(_ relativePath: String) throws -> String {
        try document(relativePath).body.strippingCommentLines().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func systemPrompt() throws -> String {
        try [promptText("SOUL.md"), promptText("USER.md")].joined(separator: "\n\n")
    }

    public func applyOnboarding(_ answers: OnboardingAnswers) throws {
        var doc = try document("USER.md")
        doc.body = answers.renderBody()
        try write(doc.render(), to: "USER.md")
    }

    public func startWatching() {
        stopWatching()
        let watcher = FileWatcher(directory: rootURL, files: Self.coreFiles.map { rootURL.appending(path: $0) }) { [weak self] in
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
