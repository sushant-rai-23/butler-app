import XCTest
import AppKit
@testable import DoubleApp

final class MenuBarStateTests: XCTestCase {
    func testEveryStateHasADistinctSymbolThatResolves() {
        let symbols = MenuBarState.allCases.map(\.symbolName)
        XCTAssertEqual(Set(symbols).count, MenuBarState.allCases.count)
        for state in MenuBarState.allCases {
            XCTAssertNotNil(
                NSImage(systemSymbolName: state.symbolName, accessibilityDescription: nil),
                "\(state) symbol \(state.symbolName) is not an SF Symbol"
            )
        }
    }

    func testIdleIsTheDefaultState() {
        XCTAssertEqual(MenuBarState.default, .idle)
    }
}
