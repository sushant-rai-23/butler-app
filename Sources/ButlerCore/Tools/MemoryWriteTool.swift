import ButlerTools
import Foundation

/// Appends one fact to a memory file. Medium risk: it writes Butler's own files.
public struct MemoryWriteTool: Tool {
    private let workspace: any Workspace

    public init(workspace: any Workspace) {
        self.workspace = workspace
    }

    public var name: String { "memory.write" }

    public var description: String {
        """
        Append one fact to a memory file, creating it if needed. Use when sir says remember, states a durable fact about a person, project or topic, or asks you to note something. Put the day's events in daily/YYYY-MM-DD.md. One bullet per fact, in sir's own words, never your inference. A new file needs a one-line description saying what is inside and when to read it.
        """
    }

    public var parametersSchema: String {
        #"{"type":"object","properties":{"path":{"type":"string","description":"Relative path, e.g. people/aditya.md, projects/butler.md, topics/health.md or daily/2026-09-22.md"},"text":{"type":"string","description":"The single fact to append, in sir's words"},"description":{"type":"string","description":"One line describing the file. Required when creating a new file."}},"required":["path","text"]}"#
    }

    public var risk: RiskLevel { .medium }

    /// Never throws, for the same reason `memory.read` does not.
    public func invoke(arguments: String) async throws -> String {
        guard let path = ToolArguments.path(in: arguments) else {
            return "error: memory.write needs a relative path, for example people/aditya.md"
        }
        guard let text = ToolArguments.string("text", in: arguments) else {
            return "error: memory.write needs the text to append"
        }
        let existed = (try? workspace.read(path)) != nil
        do {
            try workspace.append(text, to: path, description: ToolArguments.string("description", in: arguments))
            return existed ? "Appended to \(path)" : "Created \(path)"
        } catch let error as WorkspaceError {
            return "error: \(error.localizedDescription)"
        } catch {
            // See `MemoryReadTool.invoke`: the underlying error names the user's
            // filesystem, so only Butler's own words go back.
            return "error: could not write \(path)."
        }
    }
}
