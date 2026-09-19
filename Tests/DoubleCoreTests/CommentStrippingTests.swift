import XCTest
@testable import DoubleCore

final class CommentStrippingTests: XCTestCase {
    func testLinesStartingWithUnderscoreAreRemoved() {
        let text = "_a comment_\n# Title\n_another_\nkeep _this_ line\n"
        XCTAssertEqual(text.strippingCommentLines(), "# Title\nkeep _this_ line\n")
    }
}
