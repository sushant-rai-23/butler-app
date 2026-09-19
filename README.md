# Double

Double is an open-source macOS body double for people with ADHD. You tell it what you are committing to right now, it quietly watches which app and window is in front, and it nudges you only when you drift, stall, or run out the clock. It is native Swift with no backend and no account. You bring your own model key (Gemini via the free AI Studio tier by default), and everything it remembers about you lives as plain markdown files on your disk that you can read, edit, or delete.

## First run

1. `swift run DoubleApp`. A menu bar icon appears; there is no Dock icon.
2. Press Cmd+Shift+Space or click the icon. Answer five questions; they fill `~/Double/USER.md`.
3. Paste a Gemini key from https://aistudio.google.com/apikey. It is stored in the macOS Keychain.
4. Ask "who are you". Replies stream in the Jarvis voice.

Edit anything in `~/Double` with a text editor; changes apply to the next message. New to the code? Read [docs/CODEBASE-GUIDE.md](docs/CODEBASE-GUIDE.md). Settings (right-click the icon) lets you pick a model or change the key.

> **Under construction.** Phase 1 ships chat only. Commitments, scheduled check-ins and the body double session come next. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

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
