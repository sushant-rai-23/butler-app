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

## 2026-09-20: docs/ stays local and out of the repo
- **Context:** docs/prd.md is an internal planning document that names the tools this project replaces.
- **Options:** Commit it and exclude it from checks; commit and edit it; keep it out of git.
- **Why:** It is not part of the open-source release. The whole `docs/` folder is gitignored: it holds the PRD, the phase plans, the reference notes and the codebase guide, all of which are working material rather than shipped documentation. The naming rule was dropped entirely, because stating it in a public file published the very names it was meant to keep out.
- **Revisit when:** A public roadmap document is wanted; write a new one rather than publishing the PRD.

## 2026-09-20: ModelProvider is stream-first with a ChatRequest, and ToolCall carries opaque provider state
- **Context:** Phase 1 needs streamed replies, tool calls, and images. Gemini 3 returns a per-call id and a thought signature that must be echoed back verbatim or the next request fails with 400.
- **Options:** Keep `complete()` and add streaming beside it; stream-first with `complete()` as a default extension; leak a Gemini-specific signature field into Core.
- **Why:** `stream(_ request: ChatRequest) -> AsyncThrowingStream<StreamEvent, Error>` is the one method adapters implement; `complete` collects it. `ChatRequest` carries `model`, `system`, `messages`, `tools`, so the system prompt is not a message role (Gemini accepts only user and model roles) and switching model is just the next request. `ToolCall.opaque` is a string the provider writes and reads and Core only stores, so no vendor type leaves DoubleProviders. (A message-level opaque field was considered and dropped: Gemini's signature rides on the function-call part.) `Message.parts` replaces `content` so image parts exist for the Phase 3 watcher.
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

## 2026-09-20: Templates live in Sources/DoubleCore/Templates
- **Context:** The app must find the seed templates at runtime from `swift run`. SwiftPM resources must sit inside the target folder; a symlink is copied into the resource bundle as a dangling link.
- **Options:** Symlink from the target into a root `Templates/`; embed the files as Swift strings; move the folder into the target.
- **Why:** Moving is the only option SwiftPM handles natively. `Bundle.module` serves them from `Double_DoubleCore.bundle` under `swift run` and inside a real bundle later.
- **Revisit when:** Never, unless templates gain an editor outside the package.

## 2026-09-20: Workspace root is ~/Double
- **Context:** Phase 1 needs a fixed home for SOUL, USER, HEARTBEAT, LESSONS and the four folders.
- **Options:** `~/Double`; `~/Documents/Double`; `~/Library/Application Support/Double`; user-chosen at onboarding.
- **Why:** A visible home-folder directory matches "memory is markdown you can read, edit or delete". Application Support hides it; Documents raises iCloud sync questions. The root is injectable so tests use a temp dir.
- **Revisit when:** Users ask to point it at a synced folder; add a Settings field, not an onboarding picker.

## 2026-09-20: Non-secret settings in UserDefaults suite com.double.app; secrets in the Keychain under service com.double.app
- **Context:** A bare `swift run` binary has no bundle identifier, so `UserDefaults.standard` has no stable home.
- **Options:** `UserDefaults.standard`; a named suite; a settings.json in ~/Double.
- **Why:** The named suite works unsigned and in a bundle. Stored: providerID, chatModel, useAppKitInputField. Secrets go only to `SecurityKeychainStore` under account `<provider>.apiKey`.
- **Revisit when:** Settings should travel with the workspace; then move them into ~/Double and keep the suite for machine-local toggles.

## 2026-09-20: ProviderCatalog is the only adapter factory, and every adapter passes ProviderContract
- **Context:** DoubleApp must build a provider and show a picker without importing a vendor type.
- **Options:** The app switches on a string and constructs adapters; adapters self-register into a mutable registry; a static catalog in DoubleProviders.
- **Why:** The static catalog keeps every vendor name inside DoubleProviders, and `BoundaryTests` greps for leaks. `ProviderDescriptor` carries displayName, defaultModel, keychainKey and keyHelpURL. Every adapter passes the scenarios in `ProviderContract` with its own fixtures through `FakeURLProtocol`, offline.
- **Revisit when:** A provider needs runtime discovery (Ollama); add a `discover()` hook, not a mutable registry.

## 2026-09-20: AgentLoop is send(_:model:maximumRisk:onDelta:) with a round cap, rollback, and no empty turns
- **Context:** Phase 0's `run(input:)` had no streaming and fixed risk at construction.
- **Options:** Return a stream to the caller; a per-delta callback plus the final text; keep `run` and add a second entry point.
- **Why:** One entry point with `onDelta` keeps the app's transcript simple. Chat passes `.medium`, so `high` tools are never offered. Eight tool rounds max. Any error, including an empty reply (content filtered, out of tokens), rolls the turn back so history never holds a half-finished exchange or an empty assistant message, which vendors reject. Unknown or over-risk tools return an `error:` string to the model rather than throwing.
- **Revisit when:** The Phase 2 scheduler needs a turn without a user message; add a second method rather than overloading `send`.

Minor, recorded here rather than as entries: the hotkey is Cmd+Shift+Space; Core's observation type is `ScreenObservation` because a type named `Observation` shadows Apple's Observation module in files that use `@Observable`.
