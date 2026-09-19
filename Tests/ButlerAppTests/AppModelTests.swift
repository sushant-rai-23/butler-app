import ButlerCore
import ButlerProviders
import ButlerTools
import XCTest
@testable import ButlerApp

private struct IdleLoop: AgentLoop {
    func send(_ input: String, model: String, maximumRisk: RiskLevel, onDelta: @escaping @Sendable (String) -> Void) async throws -> String { "" }
    func reset() async {}
}

@MainActor
final class AppModelTests: XCTestCase {
    private var root: URL!
    private var settings: AppSettings!
    private var keychain: InMemoryKeychainStore!

    override func setUp() {
        root = FileManager.default.temporaryDirectory.appending(path: "butler-app-\(UUID().uuidString)")
        settings = AppSettings(defaults: UserDefaults(suiteName: "com.butler.app.tests.\(UUID().uuidString)")!)
        keychain = InMemoryKeychainStore()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeModel() -> AppModel {
        let workspace = MarkdownWorkspace(rootURL: root)
        let session = ChatSession(loop: IdleLoop(), settings: settings)
        return AppModel(settings: settings, keychain: keychain, workspace: workspace, session: session)
    }

    func testRoutesOnboardingThenKeyThenChat() throws {
        let model = makeModel()
        XCTAssertEqual(model.screen, .onboarding)

        model.onboarding.answers = ["Sushant", "Founder", "09:00 to 23:00", "Xcode", "Name the next step"]
        model.finishOnboarding()
        XCTAssertNil(model.lastError)
        XCTAssertEqual(model.screen, .keyEntry)
        XCTAssertTrue(try model.workspace.read("USER.md").contains("Name: Sushant"))

        model.saveKey("  AIza-test  ")
        XCTAssertEqual(model.screen, .chat)
        XCTAssertEqual(try keychain.get(settings.providerDescriptor.keychainKey), "AIza-test")
        model.workspace.stopWatching()
    }

    func testExistingWorkspaceWithKeyOpensChat() throws {
        let workspace = MarkdownWorkspace(rootURL: root)
        try workspace.seed(from: XCTUnwrap(MarkdownWorkspace.bundledTemplates))
        try keychain.set("k", for: settings.providerDescriptor.keychainKey)
        XCTAssertEqual(makeModel().screen, .chat)
    }
}
