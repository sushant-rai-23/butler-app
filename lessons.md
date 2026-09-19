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
