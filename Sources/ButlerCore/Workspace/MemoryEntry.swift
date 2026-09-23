import Foundation

/// One row of the index the model sees: enough to decide whether to open the file.
public struct MemoryEntry: Equatable, Sendable {
    public var path: String
    public var name: String
    public var description: String
    public var updated: String

    public init(path: String, name: String, description: String, updated: String) {
        self.path = path
        self.name = name
        self.description = description
        self.updated = updated
    }

    /// The block injected into the system prompt. Empty when there is nothing to list.
    ///
    /// Every value here comes off disk: the path from a filename, the rest from
    /// frontmatter the user and the model write. Each one is flattened to one
    /// line first, so no file can forge a row or a heading in the prompt.
    public static func render(_ entries: [MemoryEntry]) -> String {
        guard !entries.isEmpty else { return "" }
        let lines = entries.map { entry -> String in
            let description = capped(WorkspacePaths.oneLine(entry.description))
            let shown = description.isEmpty ? "(no description)" : description
            return "- \(WorkspacePaths.oneLine(entry.path)) — \(shown) (updated \(capped(WorkspacePaths.oneLine(entry.updated))))"
        }
        return (["# Memory index"] + lines).joined(separator: "\n")
    }

    /// The longest a frontmatter value may be in a row. The index goes into
    /// every model call, so a value's cost is per turn and permanent: one file
    /// with a 10 KB description would pay for itself forever. The path is not
    /// capped because the filesystem already bounds it.
    private static let valueLimit = 200

    /// Capped here and not on the entry, so the value on disk stays true, the
    /// same way the path does. Folding runs first, so the cap counts the
    /// characters the prompt actually carries.
    private static func capped(_ text: String) -> String {
        guard text.count > valueLimit else { return text }
        return text.prefix(valueLimit - 1).trimmingCharacters(in: .whitespaces) + "…"
    }
}
