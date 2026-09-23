import ButlerProviders
import ButlerTools
import XCTest
@testable import ButlerCore

/// The Phase 2a goal, end to end: the model files a fact, it survives a
/// restart, the user hand-edits the file, and Butler's next write keeps
/// everything. Only the provider is scripted; the workspace, the tools, the
/// registry and the loop are the real ones.
final class GoalScriptTests: XCTestCase {
    func testRememberThenRecallAcrossARestartAndAHandEdit() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "goal-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        // First launch: seed the workspace and onboard, as the app does.
        let first = MarkdownWorkspace(rootURL: root)
        try first.seed(from: XCTUnwrap(MarkdownWorkspace.bundledTemplates))
        try first.applyOnboarding(OnboardingAnswers(
            name: "Sush", work: "Solo founder", hours: "09:00 to 23:00",
            workApps: "Xcode, Terminal", helpsWhenStuck: "Name the next step"))

        let registry = ToolRegistry()
        try registry.register(MemoryReadTool(workspace: first))
        try registry.register(MemoryWriteTool(workspace: first))

        // Turn 1: "remember that Aditya runs the Scene ON backend..."
        let write = ToolCall(id: "c1", name: "memory.write",
            arguments: #"{"path":"people/aditya.md","text":"Runs the Scene ON backend and prefers PRs under 200 lines.","description":"Backend lead on Scene ON; read when sir mentions the backend or PRs."}"#,
            opaque: "sig")
        let p1 = ScriptedProvider([[.toolCall(write), .finished(.stop)], [.textDelta("Noted, sir."), .finished(.stop)]])
        let loop1 = DefaultAgentLoop(provider: p1, tools: registry, workspace: first)
        let reply = try await loop1.send("remember that Aditya runs the Scene ON backend and prefers PRs under 200 lines",
                                         model: "m", maximumRisk: .medium) { _ in }
        XCTAssertEqual(reply, "Noted, sir.")
        let filed = try first.read("people/aditya.md")
        XCTAssertTrue(filed.contains("Runs the Scene ON backend"), filed)

        // Quit and relaunch: brand new workspace object over the same folder.
        let second = MarkdownWorkspace(rootURL: root)
        let registry2 = ToolRegistry()
        try registry2.register(MemoryReadTool(workspace: second))
        try registry2.register(MemoryWriteTool(workspace: second))

        // Turn 2: "what do you know about Aditya?" — the index must carry the file.
        let read = ToolCall(id: "c2", name: "memory.read", arguments: #"{"path":"people/aditya.md"}"#, opaque: "s2")
        let p2 = ScriptedProvider([[.toolCall(read), .finished(.stop)], [.textDelta("He runs the backend, sir."), .finished(.stop)]])
        let loop2 = DefaultAgentLoop(provider: p2, tools: registry2, workspace: second)
        _ = try await loop2.send("what do you know about Aditya?", model: "m", maximumRisk: .medium) { _ in }

        let promptAfterRestart = try XCTUnwrap(p2.requests[0].system)
        XCTAssertTrue(promptAfterRestart.contains("# Memory index"), "no index after restart")
        XCTAssertTrue(promptAfterRestart.contains("people/aditya.md — Backend lead on Scene ON"), promptAfterRestart)
        let toolResult = p2.requests[1].messages.compactMap { $0.text }.joined(separator: "\n")
        XCTAssertTrue(toolResult.contains("Runs the Scene ON backend"), "read did not return the fact")

        // Hand-edit in a text editor, with frontmatter the user added themselves.
        var edited = try second.read("people/aditya.md")
        edited = edited.replacingOccurrences(of: "aliases: []", with: "aliases: []\ntags: [work, scene-on]")
        edited += "\n- Hand-written by sir: lives in Bangalore."
        try edited.write(to: root.appending(path: "people/aditya.md"), atomically: true, encoding: .utf8)

        // Turn 3: the edit is live, and Butler's own write preserves the user's key.
        let p3 = ScriptedProvider([[.textDelta("Yes, sir."), .finished(.stop)]])
        let loop3 = DefaultAgentLoop(provider: p3, tools: registry2, workspace: second)
        _ = try await loop3.send("anything else?", model: "m", maximumRisk: .medium) { _ in }
        try second.append("Prefers async reviews.", to: "people/aditya.md", description: nil)
        let afterButlerWrote = try second.read("people/aditya.md")
        XCTAssertTrue(afterButlerWrote.contains("tags: [work, scene-on]"), "lost the user's hand-added key:\n\(afterButlerWrote)")
        XCTAssertTrue(afterButlerWrote.contains("lives in Bangalore"), "lost the user's hand-written line")
        XCTAssertTrue(afterButlerWrote.contains("Prefers async reviews"), "lost Butler's own append")
    }
}
