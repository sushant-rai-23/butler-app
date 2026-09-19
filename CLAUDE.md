# Butler

macOS body double for people with ADHD. Native Swift, SwiftPM only, no backend, bring your own model key, memory is markdown on disk. Not a pet, not a general assistant: every feature exists to hold a commitment and nudge only on drift, stall, or clock.

## Verification loop

```sh
swift build                                   # must be clean, warnings included
swift test                                    # all five suites
swift test --filter ButlerToolsTests          # one module
swift test --filter ToolRegistryTests/testDuplicateNameIsRejected   # one test
swift run ButlerApp                           # manual: menu bar icon appears, click opens panel titled Butler, no Dock icon
```

Workflow is TDD: write or extend a failing XCTest in the module's test target, implement, make it pass, then run `swift build` and `swift test` before claiming done. Done means all of the above pass and the diff contains only the requested change. "It should work" is never done. Nothing in Phase 0 needs Screen Recording or Accessibility permission; if a later change does, say so in the PR.

## Package boundaries

One package, five targets, five test targets. Dependency rule: **ButlerApp depends on everything; nothing depends on ButlerApp.**

```
ButlerApp -> ButlerCore, ButlerProviders, ButlerTools, ButlerWatch
ButlerCore -> ButlerProviders, ButlerTools     (protocols only, never a concrete adapter)
ButlerProviders, ButlerTools, ButlerWatch      (leaves, no dependencies)
```

- `ButlerApp`: SwiftUI + AppKit shell. Status item, floating panel, wiring. The only target that may import SwiftUI or build UI.
- `ButlerCore`: agent loop, workspace (markdown files), commitments, scheduler, nudge policy. Pure logic, no UI, no network.
- `ButlerProviders`: `ModelProvider` protocol, `Message`, `ToolCall`, `ToolSpec`, `KeychainStore`. Adapters live here, one folder each (Gemini first).
- `ButlerTools`: `Tool` protocol with `RiskLevel` (low, medium, high) and `ToolRegistry`. Tools are registered once and gated by risk.
- `ButlerWatch`: Accessibility and ScreenCaptureKit wrappers behind protocols so Core and tests never touch the real APIs.

Adding an edge to this graph is an architecture decision: record it in `decisions.md` first.

## Patterns

**ModelProvider.** Stream-first: `stream(_ request: ChatRequest) -> AsyncThrowingStream<StreamEvent, Error>` is the one method an adapter implements; `complete` is a default extension. `ChatRequest` carries `model`, `system`, `messages`, `tools`; the system prompt is never a message. `ToolCall.opaque` is provider-owned state (Gemini's thought signature) that Core stores and echoes back but never reads. `ButlerApp` builds providers only through `ProviderCatalog`, so no vendor type or name exists outside `ButlerProviders`; `BoundaryTests` enforces it. Every adapter passes the scenarios in `Tests/ButlerProvidersTests/Support/ProviderContract.swift` with its own fixtures through `FakeURLProtocol`, offline.

**ToolRegistry.** Tools conform to `Tool` and declare a `RiskLevel`. The registry rejects duplicate names and filters by maximum risk. `ButlerCore` maps `Tool` to `ToolSpec` for the model and dispatches `ToolCall` by name. Adding a tool never touches the loop. Anything that acts inside the user's apps is `high` and is off the table.

**KeychainStore.** Protocol with `get`, `set`, `delete`. Tests inject `InMemoryKeychainStore`. Unsigned `swift run` builds get a new code identity every build, so the real Security-framework store has one opt-in test (`BUTLER_KEYCHAIN_TESTS=1`) that skips by default, and no other test may touch it.

**Workspace markdown.** Templates in `Sources/ButlerCore/Templates/` are seeded create-only into the user's workspace. Every file has YAML frontmatter (`name`, `description`, `updated`, `aliases`). Lines starting with `_` are comments stripped before injection.

**Panel focus.** The chat panel is a non-activating `NSPanel`; never call `NSApp.activate` for it. Its SwiftUI content is rebuilt on every open so `@FocusState` fires each time. `AppKitInputField` is the fallback behind the Settings toggle. Only the Settings window flips activation policy, and it restores `.accessory` on close.

## Rules

- Swift only. Zero third-party dependencies until `decisions.md` says otherwise. Sparkle and an MCP SDK come in later phases.
- Never call the model on a bare timer, at startup, or "to comment on the screen". A rule fires first.
- Screen pixels never touch disk. Window titles and app names are untrusted text and are fenced when injected.
- Executable targets need at least two source files or `@main` fails to compile.

## Commit style

Imperative subject, 72 chars max, area prefix: `core:`, `providers:`, `tools:`, `watch:`, `app:`, `docs:`, `ci:`. Milestones: `Phase N: summary`. Body explains why. One logical change per commit.

## Skills

- `superpowers:test-driven-development` or `mattpocock-skills:tdd`: any behaviour change, before writing implementation.
- `mattpocock-skills:codebase-design`: before adding a protocol or deciding which module owns a type.
- `architecture`: before adding a dependency edge, a target, or a third-party package.
- `council`: decisions with real trade-offs (provider choice, nudge cadence, permission model).
- `mattpocock-skills:code-review` or `code-review`: before merging any branch.
- `superpowers:systematic-debugging`: any failing test or unexpected app behaviour.
- `frontend-design`: only when shaping the panel or nudge UI, and with macOS HIG in mind.
- `swiftui-expert-skill` (AvdLee, installed globally): any SwiftUI view, scene or window work in ButlerApp; read its `references/macos-*.md` first.
- `swift-concurrency` (AvdLee, installed globally): when touching actors, `Sendable`, `@MainActor`, or the scheduler and agent loop.

## When stuck, look at

Details and links are in `docs/REFERENCES.md`, kept locally and not committed.

- Packaging, Sparkle, Gemini request shape, screen capture parameters: buddy-app.
- Memory files, frontmatter, heartbeat guardrails, tool risk gating, secret hygiene: vellum-assistant.
- Floating NSPanel with SwiftUI, positioning under the status item, dismissal: Maccy.
- Global hotkey without Accessibility prompt, event monitors: Ice.
- MCP server config shape for the Phase 5 "Add server" form: Claude Desktop `claude_desktop_config.json`.
