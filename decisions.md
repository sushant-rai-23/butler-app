# Decisions

ADR-lite. Newest at the bottom. Format: date, decision, context, options, why, revisit when.

## 2026-09-19: SwiftPM-only package, no Xcode project committed
- **Context:** Open-source macOS app; contributors should build with one command.
- **Options:** Xcode project; SwiftPM package with `xed .` for IDE use; Tuist.
- **Why:** SwiftPM builds and tests from the CLI and CI with no generated files. buddy-app proves a menu bar app ships this way, including notarised DMGs later.
- **Revisit when:** Asset catalogs, Info.plist keys, or Sparkle need a bundle. Plan a build script, not a project.

## 2026-09-19: One package, five targets, strict dependency direction
- **Context:** Need boundaries that tests and reviewers can check.
- **Options:** Five separate packages with path dependencies; one package with targets; one flat target.
- **Why:** Targets give module boundaries and per-module tests with one manifest. DoubleApp depends on everything; nothing depends on it. DoubleCore depends on DoubleProviders and DoubleTools by protocol only. Providers, Tools, Watch are leaves.
- **Revisit when:** A module is reused outside the app, or compile times demand splitting.

## 2026-09-19: Zero third-party dependencies in Phase 0
- **Context:** Sparkle, MCP SDK, hotkey libraries are all tempting.
- **Options:** Add Sparkle and KeyboardShortcuts now; add nothing.
- **Why:** Nothing in Phase 0 uses them, and Sparkle needs a signed bundle we do not have. Carbon `RegisterEventHotKey` covers hotkeys in about 60 lines when needed.
- **Revisit when:** Phase adds auto-update or MCP.

## 2026-09-19: Status item is an NSStatusItem in the app delegate, not MenuBarExtra
- **Context:** Clicking the icon must open a floating panel titled Double in one click.
- **Options:** SwiftUI `MenuBarExtra` `.window` style (its own popover, not a floating panel, auto-dismisses); `MenuBarExtra` `.menu` style with an "Open" item (two clicks, blocks run loop); `NSStatusItem` toggling a real `NSPanel`, with a hidden `MenuBarExtra(isInserted: false)` only to satisfy SwiftUI's scene requirement.
- **Why:** `MenuBarExtra` cannot be opened or closed programmatically (Apple FB10185203). The NSStatusItem path is what Maccy ships, needs no dependency, and the same panel will host nudges later.
- **Revisit when:** Apple adds programmatic control to MenuBarExtra.

## 2026-09-19: Keychain behind a protocol; only the in-memory fake exists in Phase 0
- **Context:** Tests must inject a fake; unsigned `swift run` builds change code identity every build, so the login keychain prompts on each rebuild.
- **Options:** Ship the Security-framework store now; ship protocol plus fake, real store when a key is first stored.
- **Why:** No Phase 0 code stores a key, so the real store would be untested dead code.
- **Revisit when:** Phase 1 adds the Gemini adapter. Use the file-based login keychain (do not set `kSecUseDataProtectionKeychain`) so unsigned builds work.

## 2026-09-19: CI on macos-15, not macos-14
- **Context:** Brief asked for macos-14.
- **Options:** macos-14; macos-15; matrix.
- **Why:** GitHub deprecated macos-14 in July 2026 and removes it on 2026-11-02. macos-15 ships Xcode 16 whose Swift 6 compiler builds tools-version 5.10 packages in language mode 5. A matrix doubles CI time for a zero-dependency package.
- **Revisit when:** Adopting Swift 6 language mode.

## 2026-09-19: Gemini is the true default provider
- **Context:** buddy-app defaults to a local CLI and falls back to Gemini after probing the filesystem.
- **Options:** Probe for installed CLIs; default to Gemini and let the user switch.
- **Why:** Free AI Studio tier, no install step, deterministic first-run. Key goes in the `x-goog-api-key` header, never the URL.
- **Revisit when:** A second provider ships and users ask for a picker at onboarding.

## 2026-09-20: PRD stays local, forbidden-words rule is a note only
- **Context:** docs/prd.md is an internal planning document that names the predecessor tools.
- **Options:** Commit it and exclude it from checks; commit and edit it; keep it out of git.
- **Why:** It is not part of the open-source release. It is in .gitignore. The CI grep for the forbidden words was removed as overkill for a fresh project; CLAUDE.md keeps one line.
- **Revisit when:** A public roadmap document is wanted; write a new one rather than publishing the PRD.

## 2026-09-20: ModelProvider is stream-first with a ChatRequest, and Message carries opaque provider state
- **Context:** Phase 1 needs streamed replies, tool calls, and images. Gemini 3 returns a per-call id and a thought signature that must be echoed back verbatim or the next request fails with 400.
- **Options:** Keep `complete()` and add streaming beside it; stream-first with `complete()` as a default extension; leak a Gemini-specific signature field into Core.
- **Why:** `stream(_ request: ChatRequest) -> AsyncThrowingStream<StreamEvent, Error>` is the one method adapters implement; `complete` collects it. `ChatRequest` carries `model`, `system`, `messages`, `tools`, so the system prompt is not a message role (Gemini accepts only user and model roles) and switching model is just the next request. `Message.opaque` and `ToolCall.opaque` are strings the provider writes and reads and Core only stores, so no vendor type leaves DoubleProviders. `Message.parts` replaces `content` so image parts exist for the Phase 3 watcher.
- **Revisit when:** A provider needs structured opaque state that a string cannot hold; then make it `Data`.

## 2026-09-20: Default model is gemini-3.8-flash, chosen per request from Settings
- **Context:** Google's current free Flash is gemini-3.8-flash. Free-tier daily limits are no longer published; an unofficial September 2026 measurement suggests low daily caps on Flash and higher ones on Flash-Lite.
- **Options:** gemini-3.8-flash; gemini-3.5-flash-lite for headroom; gemini-2.5-flash as the PRD named.
- **Why:** Chat quality matters for the persona, the model picker makes switching trivial, and the Phase 3 watcher slot can use Flash-Lite. Thinking is set low by model family (thinkingLevel for 3.x, thinkingBudget for 2.5) to cut latency.
- **Revisit when:** Real free-tier caps are confirmed in AI Studio, or the watcher slot lands.

## 2026-09-20: Settings is our own NSWindow, not the SwiftUI Settings scene
- **Context:** In an accessory app the SwiftUI Settings scene does not come to the front without flipping activation policy and activating the app.
- **Options:** SwiftUI `Settings` scene with the activation flip; our own `NSWindow` hosting a SwiftUI view with the same flip under our control.
- **Why:** We already own the panel in AppKit; owning the settings window too keeps one pattern and no scene quirks. Activation is flipped to `.regular` only while Settings is open and restored to `.accessory` on close. The chat panel never activates the app.
- **Revisit when:** Apple makes Settings work from accessory apps without the flip.

## 2026-09-20: Panel focus via fresh hosting view per open, with an AppKit fallback
- **Context:** SwiftUI `@FocusState` inside a non-activating panel has a documented macOS-version regression (Maccy issue 876).
- **Options:** `@FocusState` only; AppKit `NSTextField` only; SwiftUI first with a flagged AppKit fallback.
- **Why:** Rebuilding the `NSHostingView` on every open (Ice's pattern) makes SwiftUI's appear-time focus fire every time. An `NSViewRepresentable` text field that claims first responder once its window is key ships behind one flag as the deterministic fallback. Global hotkey is Carbon `RegisterEventHotKey`, which needs no permission.
- **Revisit when:** The fallback is never needed across two macOS releases; delete it.

## 2026-09-20: Workspace watches the root only, frontmatter parser is hand-written
- **Context:** Phase 1 reads only SOUL, USER, HEARTBEAT and LESSONS. Full YAML would be a dependency.
- **Options:** FSEvents recursive now; DispatchSource on the root and top-level files; a YAML package.
- **Why:** DispatchSource covers Phase 1 with no C callback plumbing. The parser handles `key: value` lines and an inline `[a, b]` list, preserves unknown keys as raw strings, and bumps `updated` on write.
- **Revisit when:** Phase 2 reads projects/ and daily/; switch to FSEvents then.
