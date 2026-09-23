# Lessons

Corrections log. When the same correction happens twice, append one or two lines here and follow it from then on.

- 2026-09-19: Set up repo config, docs, and templates before writing any Swift. The user wants the project scaffolding in place first so code lands into an already-documented structure.

## Teach-back: Phase 0 scaffold (2026-09-19)
- What changed: one SwiftPM package, five targets plus five XCTest targets, repo docs, templates, CI, agents.
- Why this approach: targets give enforceable boundaries with one manifest; NSStatusItem plus NSPanel because MenuBarExtra cannot be opened programmatically.
- Trade-off accepted: a hidden, never-inserted MenuBarExtra exists only to satisfy SwiftUI's scene requirement; the real UI is AppKit.
- Tricky part: ToolSpec lives in ButlerProviders and Tool in ButlerTools so neither leaf depends on the other; ButlerCore is the adapter between them.
- Explain cold: why nothing may depend on ButlerApp, and why the model is never called from a bare timer.

## Teach-back: Phase 1 Gemini end to end (2026-09-20)
- What changed: stream-first ModelProvider, Gemini adapter with offline contract tests, real Keychain, MarkdownWorkspace, DefaultAgentLoop, hotkey + chat panel, Settings, onboarding.
- Why this approach: one seam (`ChatRequest` in, events out) keeps Core vendor-free; `ToolCall.opaque` carries Gemini's signature without Core knowing.
- Trade-off accepted: a hand-written frontmatter parser and root-only file watching, both sized to Phase 1.
- Tricky part: Gemini 3 rejects a tool-result turn missing the thought signature; the fix is a pass-through field, not a Gemini type in Core.
- Explain cold: why the panel never activates the app, and why the system prompt is not a message.

## Teach-back: Phase 2a memory that grows (2026-09-23)
- What changed: frontmatter keeps its raw block, the workspace gained an index and an append, FSEvents watches recursively, and `memory.read` and `memory.write` joined the chat loop.
- Why this approach: the model picks files by one-line description instead of Butler injecting every file, so context stays small as memory grows.
- Trade-off accepted: append-only writes, no edit or delete from chat, until a UI exists that shows the user what is changing.
- Tricky part: every seam that renders user or model text is an injection boundary — a `---` in a description split a file, a newline in a filename forged an index row, and a newline in a path forged a line in a tool result.
- Explain cold: why the index lives in the system prompt rather than behind a list tool, and why a hostile bound must be measured in the consumer's units.

## Corrections from the Phase 2a reviews (2026-09-23)
Eight defects, all found by review rather than by the test suite, and all one of two shapes. Worth reading before writing the next boundary.

**Untrusted text escaping its structural slot.** The value was valid; the container was not defended.
- A model-supplied `description` containing `---` split a memory file and spilled content into the body.
- A newline in a filename forged a whole index row that read as Butler's own words.
- A newline in a path forged a second line in a tool result.
- A hand-written list of line-break characters missed U+0085, so the forgery came straight back.
- Butler's own prompt sections were h2 while every template body opens with h1, so `# Today` and `# Memory index` read as subsections of `LESSONS.md`.

**Bounding or splitting hostile input in the wrong unit.** The check was there and it was measuring the wrong thing.
- `components(separatedBy: "/")` compares grapheme clusters, so `/` fused with a combining mark is one Character and `..` walked straight out of the workspace.
- `path.count` counts grapheme clusters, so 50,000 combining marks are four Characters and 100 KB of bytes, past a 256 "limit" — and the test guarding it used the same wrong measure, so it passed on a 100 KB line.
- `JSONSerialization` recurses per nesting level and its depth guard is 512, but `invoke` is `async`, so it runs on a 512 KB cooperative stack instead of 8 MB. Four kilobytes of nested JSON from the model killed the process.

The rule both shapes give: validate in the representation the consumer uses — bytes for the kernel, scalars for a renderer, stack frames for a parser — and never trust a limit you have not measured in those units.
