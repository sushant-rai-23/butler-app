# Contributing to Double

Thanks for helping. Double is small and opinionated, so please read this before opening a pull request.

## Setup

```sh
git clone <your fork>
cd double
swift build
swift test
swift run DoubleApp
```

No Xcode project is committed. Open the folder in Xcode with `xed .` if you want an IDE; do not commit `.xcodeproj` or `.xcworkspace` files.

## Ground rules

- **Swift only.** No Python, no Node, no external service. Zero third-party dependencies until the roadmap says otherwise.
- **Package boundaries are enforced.** `DoubleApp` depends on everything; nothing depends on `DoubleApp`. `DoubleCore` reaches models and tools only through the `ModelProvider` and `ToolRegistry` protocols. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- **Tests first.** Every behaviour change comes with a failing test that the change makes pass. Each module has its own XCTest target.
- **Privacy is a feature.** Screen content never touches disk, API keys never enter model context or logs, and the model is never called on a bare timer.
- **Not a pet, not a general assistant.** If a change makes Double chattier without a commitment-related reason, it is out of scope.

## Commit style

Imperative subject line, 72 characters or fewer, prefixed with the area: `core:`, `providers:`, `tools:`, `watch:`, `app:`, `docs:`, `ci:`. Milestones use `Phase N: summary`. The body says why, not what.

## Pull requests

1. Branch from `main`.
2. `swift build` and `swift test` pass locally.
3. The diff contains only the requested change. Unrelated cleanup goes in its own PR.
4. Describe how you verified it, including running the app if UI changed.

## Reporting bugs and requesting features

Use the issue templates. For bugs, include your macOS version and the output of `swift --version`.
