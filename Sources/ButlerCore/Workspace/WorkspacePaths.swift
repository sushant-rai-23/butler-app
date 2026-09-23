import Foundation

public enum WorkspaceError: Error, Equatable {
    /// The model asked for a path outside what it may touch.
    case pathNotAllowed(String)
    /// Creating a file needs a one-line description for the index.
    case descriptionRequired(String)
    /// A seeded folder is gone; Butler does not recreate it silently.
    case folderMissing(String)
    /// An append with nothing to say. A blank bullet would still bump `updated`
    /// and make a file that learned nothing look fresh in the index.
    case factRequired(String)
}

extension WorkspaceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .pathNotAllowed(let path): return "\(path) is not a path Butler may use here."
        case .descriptionRequired(let path): return "\(path) does not exist yet, so it needs a one-line description."
        case .folderMissing(let folder): return "The \(folder) folder is missing from the workspace."
        case .factRequired(let path): return "An append to \(path) needs something to say."
        }
    }
}

/// Which relative paths the model may read and write.
///
/// Readable: any `.md` file under the root. Writable: `USER.md`, `LESSONS.md`,
/// and exactly one level inside a seeded folder. `SOUL.md` and `HEARTBEAT.md`
/// are the user's to edit, not the model's.
public enum WorkspacePaths {
    private static let writableRootFiles = ["USER.md", "LESSONS.md"]

    public static func checkReadable(_ path: String) throws {
        guard isWellFormed(path) else { throw WorkspaceError.pathNotAllowed(path) }
    }

    public static func checkWritable(_ path: String) throws {
        guard isWellFormed(path) else { throw WorkspaceError.pathNotAllowed(path) }
        let parts = segments(path)
        if parts.count == 1, writableRootFiles.contains(parts[0]) { return }
        if parts.count == 2, MarkdownWorkspace.folders.contains(parts[0]) { return }
        throw WorkspaceError.pathNotAllowed(path)
    }

    /// These rules are string work, so they cannot see that `daily` is a symlink
    /// to somewhere else. Disk has to answer that: resolve the parent and refuse
    /// a symlinked leaf, so a redirected folder or file cannot move a read or a
    /// write out of the workspace.
    ///
    /// Two things the obvious version gets wrong, both measured. Resolving the
    /// FULL path does not resolve a symlinked parent when the leaf does not
    /// exist yet, so the parent is resolved on its own. And resolving only the
    /// parent misses a symlinked leaf, whose parent is clean while the open
    /// follows the link out, hence `isSymbolicLinkKey` (which does not follow
    /// the link). Both sides are resolved before comparing, because `/var` and
    /// `/private/var` otherwise mismatch on macOS.
    ///
    /// The error names the leaf, never the absolute path: a tool error can be
    /// handed back to the model, and the user's home directory is not its business.
    public static func checkContained(_ url: URL, inRoot root: URL) throws {
        let root = root.resolvingSymlinksInPath().standardizedFileURL
        let parent = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        guard parent.path == root.path || parent.path.hasPrefix(root.path + "/") else {
            throw WorkspaceError.pathNotAllowed(url.lastPathComponent)
        }
        let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard values?.isSymbolicLink != true else {
            throw WorkspaceError.pathNotAllowed(url.lastPathComponent)
        }
    }

    /// A value on its way into one line that Butler authors: a memory bullet, or
    /// a row of the prompt index. Every kind of line break becomes a space and
    /// the invisible scalars a path may not contain are dropped, so model text
    /// can neither become a line of its own nor read as something it is not.
    ///
    /// Line breaks are asked of the platform rather than listed here: a list
    /// missed U+0085 NEL, which is neither a control byte nor an invisible and
    /// so forged a row. A break becomes a space and not nothing, so folding can
    /// never weld two words into one.
    static func oneLine(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if Character(scalar).isNewline || scalar == "\t" {
                scalars.append(" ")
            } else if scalar.value < 0x20 || scalar.value == 0x7F
                || scalar.properties.isDefaultIgnorableCodePoint
                || scalar.properties.isBidiControl {
                continue
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars).trimmingCharacters(in: .whitespaces)
    }

    /// A scalar that may appear neither in a path nor in a line Butler authors
    /// about one: a control byte, any kind of line break, an invisible, a bidi
    /// control. An unterminated override or isolate reverses or hides the rest
    /// of the line wherever it renders, which is the same structural forgery as
    /// a newline, so one predicate answers for both. `isNewline` rather than a
    /// byte range, because U+0085, U+2028 and U+2029 are line breaks that no
    /// list of control bytes catches.
    static func isStructurallyUnsafe(_ scalar: Unicode.Scalar) -> Bool {
        Character(scalar).isNewline
            || scalar.value < 0x20 || scalar.value == 0x7F
            || scalar.properties.isDefaultIgnorableCodePoint
            || scalar.properties.isBidiControl
    }

    private static func isWellFormed(_ path: String) -> Bool {
        guard !path.isEmpty, path.hasSuffix(".md"), !path.hasPrefix("/") else { return false }
        guard !path.unicodeScalars.contains(where: isStructurallyUnsafe) else { return false }
        let parts = segments(path)
        guard !parts.contains(".."), !parts.contains("."), !parts.contains("") else { return false }
        guard let name = parts.last, name != ".md" else { return false }
        return true
    }

    /// Splits on the `/` byte, the way the filesystem does. `components(separatedBy:)`
    /// works on Swift Characters, and a `/` followed by a combining mark is one
    /// Character, so a `..` segment could hide inside a component and escape the root.
    static func segments(_ path: String) -> [String] {
        path.utf8.split(separator: UInt8(ascii: "/"), omittingEmptySubsequences: false).map {
            String(decoding: $0, as: UTF8.self)
        }
    }
}
