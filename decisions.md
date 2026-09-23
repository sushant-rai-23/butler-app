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
- **Why:** Targets give module boundaries and per-module tests with one manifest. ButlerApp depends on everything; nothing depends on it. ButlerCore depends on ButlerProviders and ButlerTools by protocol only. Providers, Tools, Watch are leaves.
- **Revisit when:** A module is reused outside the app, or compile times demand splitting.

## 2026-09-19: Zero third-party dependencies in Phase 0
- **Context:** Sparkle, MCP SDK, hotkey libraries are all tempting.
- **Options:** Add Sparkle and KeyboardShortcuts now; add nothing.
- **Why:** Nothing in Phase 0 uses them, and Sparkle needs a signed bundle we do not have. Carbon `RegisterEventHotKey` covers hotkeys in about 60 lines when needed.
- **Revisit when:** Phase adds auto-update or MCP.

## 2026-09-19: Status item is an NSStatusItem in the app delegate, not MenuBarExtra
- **Context:** Clicking the icon must open a floating panel titled Butler in one click.
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
- **Why:** `stream(_ request: ChatRequest) -> AsyncThrowingStream<StreamEvent, Error>` is the one method adapters implement; `complete` collects it. `ChatRequest` carries `model`, `system`, `messages`, `tools`, so the system prompt is not a message role (Gemini accepts only user and model roles) and switching model is just the next request. `ToolCall.opaque` is a string the provider writes and reads and Core only stores, so no vendor type leaves ButlerProviders. (A message-level opaque field was considered and dropped: Gemini's signature rides on the function-call part.) `Message.parts` replaces `content` so image parts exist for the Phase 3 watcher.
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

## 2026-09-20: Templates live in Sources/ButlerCore/Templates
- **Context:** The app must find the seed templates at runtime from `swift run`. SwiftPM resources must sit inside the target folder; a symlink is copied into the resource bundle as a dangling link.
- **Options:** Symlink from the target into a root `Templates/`; embed the files as Swift strings; move the folder into the target.
- **Why:** Moving is the only option SwiftPM handles natively. `Bundle.module` serves them from `Butler_ButlerCore.bundle` under `swift run` and inside a real bundle later.
- **Revisit when:** Never, unless templates gain an editor outside the package.

## 2026-09-20: Workspace root is ~/Butler
- **Context:** Phase 1 needs a fixed home for SOUL, USER, HEARTBEAT, LESSONS and the four folders.
- **Options:** `~/Butler`; `~/Documents/Butler`; `~/Library/Application Support/Butler`; user-chosen at onboarding.
- **Why:** A visible home-folder directory matches "memory is markdown you can read, edit or delete". Application Support hides it; Documents raises iCloud sync questions. The root is injectable so tests use a temp dir.
- **Revisit when:** Users ask to point it at a synced folder; add a Settings field, not an onboarding picker.

## 2026-09-20: Non-secret settings in UserDefaults suite com.butler.app; secrets in the Keychain under service com.butler.app
- **Context:** A bare `swift run` binary has no bundle identifier, so `UserDefaults.standard` has no stable home.
- **Options:** `UserDefaults.standard`; a named suite; a settings.json in ~/Butler.
- **Why:** The named suite works unsigned and in a bundle. Stored: providerID, chatModel, useAppKitInputField. Secrets go only to `SecurityKeychainStore` under account `<provider>.apiKey`.
- **Revisit when:** Settings should travel with the workspace; then move them into ~/Butler and keep the suite for machine-local toggles.

## 2026-09-20: ProviderCatalog is the only adapter factory, and every adapter passes ProviderContract
- **Context:** ButlerApp must build a provider and show a picker without importing a vendor type.
- **Options:** The app switches on a string and constructs adapters; adapters self-register into a mutable registry; a static catalog in ButlerProviders.
- **Why:** The static catalog keeps every vendor name inside ButlerProviders, and `BoundaryTests` greps for leaks. `ProviderDescriptor` carries displayName, defaultModel, keychainKey and keyHelpURL. Every adapter passes the scenarios in `ProviderContract` with its own fixtures through `FakeURLProtocol`, offline.
- **Revisit when:** A provider needs runtime discovery (Ollama); add a `discover()` hook, not a mutable registry.

## 2026-09-20: AgentLoop is send(_:model:maximumRisk:onDelta:) with a round cap, rollback, and no empty turns
- **Context:** Phase 0's `run(input:)` had no streaming and fixed risk at construction.
- **Options:** Return a stream to the caller; a per-delta callback plus the final text; keep `run` and add a second entry point.
- **Why:** One entry point with `onDelta` keeps the app's transcript simple. Chat passes `.medium`, so `high` tools are never offered. Eight tool rounds max. Any error, including an empty reply (content filtered, out of tokens), rolls the turn back so history never holds a half-finished exchange or an empty assistant message, which vendors reject. Unknown or over-risk tools return an `error:` string to the model rather than throwing.
- **Revisit when:** The Phase 2 scheduler needs a turn without a user message; add a second method rather than overloading `send`.

Minor, recorded here rather than as entries: the hotkey is Cmd+Shift+Space; Core's observation type is `ScreenObservation` because a type named `Observation` shadows Apple's Observation module in files that use `@Observable`.

## 2026-09-23: Frontmatter keeps its raw block; writes patch `updated` in place
- **Context:** Phase 2a lets the model append to files the user also hand-edits. The parser understood four keys and re-rendered the block from them, so anything else was lost on write.
- **Options:** Keep re-rendering from parsed keys; preserve the raw text and patch known lines; take a YAML dependency.
- **Why:** `Frontmatter.rawBlock` holds the exact text between the fences and `render()` replaces only the `updated:` line, so a user's `tags:`, comments, key order and multi-line values survive a write by Butler. `extra` is gone: two mechanisms for one job. `name`, `description` and `aliases` are `let`, because `render()` ignores them — a later rename must rewrite `rawBlock`, and the compiler now says so. `Frontmatter.new` is the only sanitising constructor.
- **Revisit when:** Butler needs to change a key it did not write, or a user wants nested YAML read back; then take a real YAML parser. Note `parse` treats any `---`-fenced top block as frontmatter, which is why `append` needs a round-trip guard for a file that opens with a thematic break.

## 2026-09-23: The model may read anything under the workspace but write only four folders, USER.md and LESSONS.md
- **Context:** `memory.write` takes a path from the model.
- **Options:** Allow any path under the root; an allowlist of folders; ask the user per write.
- **Why:** `WorkspacePaths` rejects `..`, absolute paths and non-markdown for reads, and additionally rejects `SOUL.md`, `HEARTBEAT.md` and anything deeper than one level for writes. The persona and the schedule are the user's to edit. Enforced in the workspace, not the tool, so every caller inherits it. Three things the first implementation got wrong, each found by review and each worth remembering for any future check on hostile input: paths are split on the `/` **byte**, because `components(separatedBy:)` compares grapheme clusters and a `/` fused with a combining mark reads as one component, which let `..` escape the root; control, default-ignorable and bidi-control scalars are rejected, because an invisible or right-to-left-overridden filename renders as something it is not; and the writable set is an **allowlist**, so the filesystem's case- and normalisation-insensitivity can only cause a false reject, never a bypass.
- **Revisit when:** The Memory tab offers delete, which needs its own gate and a confirmation.

## 2026-09-23: A string path policy is not containment; the disk check is separate
- **Context:** `WorkspacePaths` is pure string work and cannot see that `~/Butler/daily` is a symlink somewhere else.
- **Options:** Resolve symlinks inside the string policy; a separate disk-level check; trust the folder because Butler seeded it.
- **Why:** `WorkspacePaths.checkContained(_:inRoot:)` runs on every read and every write. Both obvious implementations are wrong: `resolvingSymlinksInPath()` on the full path does not resolve a symlinked parent when the leaf does not exist yet, and resolving only the parent misses a symlinked leaf, so the parent is resolved on its own **and** the leaf is rejected when it is a link. Both sides are resolved before comparing, because `/var` and `/private/var` otherwise mismatch. Without it, a symlinked folder let a write land outside the workspace and let a read pull an arbitrary file into the prompt and over the network to the provider.
- **Revisit when:** Butler ever needs to follow a link deliberately, for a workspace on a synced volume.

## 2026-09-23: Memory tools live in ButlerCore, and writing is medium risk
- **Context:** `memory.read` and `memory.write` conform to `ButlerTools.Tool` but need `Workspace`, a `ButlerCore` type.
- **Options:** Put them in ButlerTools and add a dependency on Core; put them in Core; move Workspace into ButlerTools.
- **Why:** ButlerTools is a leaf and must stay one, so the tool lives with the thing it wraps. No new edge in the dependency graph. `memory.write` is `.medium` because the `Tool` protocol already defines medium as "writes Butler's own files"; chat runs at `.medium`, so both are offered today, and a future read-only turn can cap at `.low` and still get `memory.read`.
- **Revisit when:** A tool needs no Core type at all; it belongs in ButlerTools then.

## 2026-09-23: A tool's return string is model-visible text, so it is bounded and folded like any other injected line
- **Context:** `invoke` returns a string the model reads and may echo. `WorkspaceError` quotes the path it was given, and the path comes from the model.
- **Options:** Return the error verbatim; sanitise at the workspace; sanitise at the tool boundary.
- **Why:** At the tool boundary, because the workspace's errors are also read by the user, who wants their diagnostics. `ToolArguments.path(in:)` refuses a path that is not one line, is structurally unsafe, or exceeds 256 **bytes** before the workspace sees it, so the error is always safe to quote. Two real escapes closed: a newline in a path forged a second line in the tool result, and a long path flooded the reply. A catch-all never returns `localizedDescription`, because Foundation errors embed the user's home directory.
- **Revisit when:** A tool needs to return structured data rather than a line of text.

## 2026-09-23: Tool arguments are decoded with JSONDecoder, never JSONSerialization
- **Context:** `Tool.invoke` is `async`, so it runs on a Swift concurrency cooperative thread with a 512 KB stack, not the main thread's 8 MB.
- **Options:** Keep `JSONSerialization`; bound the nesting depth before parsing; decode with `JSONDecoder`.
- **Why:** `JSONSerialization.jsonObject` recurses per nesting level, and its own depth guard is 512 — above what that stack survives. About 4 KB of nested JSON from the model killed the process with SIGBUS. `JSONDecoder` was measured clean on the same thread from depth 400 to 100,000. A malformed or hostile provider response must never be able to terminate Butler.
- **Revisit when:** Never, unless Apple documents a depth bound for `JSONSerialization` that fits a cooperative stack.

## 2026-09-23: The memory index goes in the prompt unfenced; containment is structural
- **Context:** Every prompt carries one line per memory file. Both the user and the model can write those files.
- **Options:** Wrap the index in a code fence; add a "treat as data" banner; guarantee only that a value cannot break out of its row.
- **Why:** `SOUL.md` and `USER.md` already go into the prompt verbatim — in Butler the workspace *is* the prompt — so fencing the index while injecting the persona raw would be incoherent. A fence is worse than nothing, because a description containing a triple backtick forges the fence's end unless the value is folded anyway, so the fold does all the work in both designs. CLAUDE.md's fencing rule is about window titles and app names, a genuinely different trust domain. The line that is enforced: a value may say anything, but may not break out of its row. `WorkspacePaths.oneLine` folds every line break the platform recognises — a hand-written list missed U+0085 and forged a row. Butler's own prompt sections are h1, because every template body opens with one and an h2 would nest today's events under whichever file came last.
- **Revisit when:** A tool lets the model write `LESSONS.md` or `USER.md` wholesale, which the path policy already permits. Then a model-authored heading sits one line above Butler's own and this is decided again.

## 2026-09-23: FSEvents replaces the DispatchSource watcher
- **Context:** Phase 2a reads `projects/`, `people/`, `topics/` and `daily/`. The old watcher watched the root and four fixed files by descriptor.
- **Options:** One DispatchSource per folder; FSEvents on the root, recursive; no watcher, since `systemPrompt()` reads disk per turn anyway.
- **Why:** FSEvents watches paths, so it sees files created inside subfolders and survives the write-temp-then-rename editors do on save, which invalidates a descriptor. Stream creation failure is logged and ignored, because the app is still correct without a watcher. The C callback reaches a small box holding only the handler, never the watcher: with an unretained pointer to the watcher, the last release could run on the stream's own queue and deadlock `deinit` against `stop()`.
- **Revisit when:** The Memory tab needs per-file events rather than one coalesced signal, or something expensive hangs off `changeHandler` and wants its own debounce.
