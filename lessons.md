# Lessons

Corrections log. When the same correction happens twice, append one or two lines here and follow it from then on.

- 2026-09-19: Set up repo config, docs, and templates before writing any Swift. The user wants the project scaffolding in place first so code lands into an already-documented structure.

## Teach-back: Phase 0 scaffold (2026-09-19)
- What changed: one SwiftPM package, five targets plus five XCTest targets, repo docs, templates, CI, agents.
- Why this approach: targets give enforceable boundaries with one manifest; NSStatusItem plus NSPanel because MenuBarExtra cannot be opened programmatically.
- Trade-off accepted: a hidden, never-inserted MenuBarExtra exists only to satisfy SwiftUI's scene requirement; the real UI is AppKit.
- Tricky part: ToolSpec lives in DoubleProviders and Tool in DoubleTools so neither leaf depends on the other; DoubleCore is the adapter between them.
- Explain cold: why nothing may depend on DoubleApp, and why the model is never called from a bare timer.
