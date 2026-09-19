import XCTest
@testable import ButlerWatch

private struct FakeObserver: AccessibilityObserver {
    var isTrusted: Bool
    var window: FrontmostWindow?
    func frontmostWindow() -> FrontmostWindow? { window }
}

final class AccessibilityObserverTests: XCTestCase {
    func testObserverCanBeFakedForTests() {
        let window = FrontmostWindow(appName: "Xcode", bundleID: "com.apple.dt.Xcode", title: "Butler")
        let observer: any AccessibilityObserver = FakeObserver(isTrusted: true, window: window)
        XCTAssertTrue(observer.isTrusted)
        XCTAssertEqual(observer.frontmostWindow(), window)
    }
}
