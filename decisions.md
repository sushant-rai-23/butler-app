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
