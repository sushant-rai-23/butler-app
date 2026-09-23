import ButlerTools
import Foundation

/// Reads one memory file for the model. Low risk: it only reads Butler's own files.
public struct MemoryReadTool: Tool {
    private let workspace: any Workspace

    public init(workspace: any Workspace) {
        self.workspace = workspace
    }

    public var name: String { "memory.read" }

    public var description: String {
        "Read one memory file. Use when the memory index shows a file relevant to what sir is asking. Path is relative, for example people/aditya.md."
    }

    public var parametersSchema: String {
        #"{"type":"object","properties":{"path":{"type":"string","description":"Relative path from the memory index, e.g. people/aditya.md"}},"required":["path"]}"#
    }

    public var risk: RiskLevel { .low }

    /// Never throws. A throw would leave the agent loop; an `error:` line goes
    /// back to the model as text it can recover from.
    public func invoke(arguments: String) async throws -> String {
        guard let path = ToolArguments.path(in: arguments) else {
            return "error: memory.read needs a relative path, for example people/aditya.md"
        }
        do {
            let body = try workspace.document(path).body
                .strippingCommentLines()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return body.isEmpty ? "\(path) is empty." : body
        } catch let error as WorkspaceError {
            return "error: \(error.localizedDescription)"
        } catch {
            // Deliberately not `error`: a Cocoa failure names the file by its
            // absolute path, and the user's home directory is not the model's
            // business. The path is ours, checked above, so it is safe to name.
            // Nor a guess at why: a directory at people/dir.md and a file the
            // user cannot open both land here, and "it may not exist yet" would
            // have Butler tell sir a file he is looking at is not there.
            return "error: could not read \(path)."
        }
    }
}
