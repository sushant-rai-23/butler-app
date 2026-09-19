import ButlerProviders
import XCTest
@testable import ButlerApp

final class AppSettingsTests: XCTestCase {
    private var suite: String!

    override func setUp() { suite = "com.butler.app.tests.\(UUID().uuidString)" }
    override func tearDown() { UserDefaults.standard.removePersistentDomain(forName: suite) }

    func testDefaultsComeFromTheProviderCatalog() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        XCTAssertEqual(settings.providerID, ProviderCatalog.defaultProvider.id)
        XCTAssertFalse(settings.chatModel.isEmpty)
        XCTAssertFalse(settings.useAppKitInputField)
    }

    func testChangesPersistAcrossInstances() {
        let first = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        first.chatModel = "some-model"
        first.useAppKitInputField = true
        let second = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        XCTAssertEqual(second.chatModel, "some-model")
        XCTAssertTrue(second.useAppKitInputField)
    }
}
