# Double

Double is an open-source macOS body double for people with ADHD. You tell it what you are committing to right now, it quietly watches which app and window is in front, and it nudges you only when you drift, stall, or run out the clock. It is native Swift with no backend and no account. You bring your own model key (Gemini via the free AI Studio tier by default), and everything it remembers about you lives as plain markdown files on your disk that you can read, edit, or delete.

> **Under construction.** Phase 0 is a scaffold: a menu bar icon and an empty panel. Nothing watches anything yet. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for where it is going.

## Build from source

Requires macOS 14 or newer and Xcode 15.4 or newer (Swift 5.10+). There is no Xcode project; this is a plain Swift package.

```sh
swift build
swift test
swift run DoubleApp
```

`swift run DoubleApp` runs unsigned and shows a menu bar icon. Click it to open the panel.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
