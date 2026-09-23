import XCTest
@testable import ButlerCore

final class FSEventsWatcherTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL.temporaryDirectory.appending(path: "butler-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appending(path: "people"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testFiresWhenAFileIsCreatedInASubfolder() throws {
        let fired = expectation(description: "handler fired")
        fired.assertForOverFulfill = false
        let watcher = FSEventsWatcher(root: root) { fired.fulfill() }
        watcher.start()
        defer { watcher.stop() }

        try "hello".write(to: root.appending(path: "people/new.md"), atomically: true, encoding: .utf8)

        wait(for: [fired], timeout: 5)
    }

    func testFiresOnAnAtomicSaveOverAnExistingFile() throws {
        let target = root.appending(path: "people/existing.md")
        try "before".write(to: target, atomically: true, encoding: .utf8)

        let fired = expectation(description: "handler fired")
        fired.assertForOverFulfill = false
        let watcher = FSEventsWatcher(root: root) { fired.fulfill() }
        watcher.start()
        defer { watcher.stop() }

        // atomically: true is write-temp-then-rename, the same thing editors do.
        try "after".write(to: target, atomically: true, encoding: .utf8)

        wait(for: [fired], timeout: 5)
    }

    func testStopSilencesTheHandler() throws {
        let fired = expectation(description: "handler must not fire")
        fired.isInverted = true
        let watcher = FSEventsWatcher(root: root) { fired.fulfill() }
        watcher.start()
        watcher.stop()

        try "x".write(to: root.appending(path: "people/after-stop.md"), atomically: true, encoding: .utf8)

        wait(for: [fired], timeout: 2)
    }
}
