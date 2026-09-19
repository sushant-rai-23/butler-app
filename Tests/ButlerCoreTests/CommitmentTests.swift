import XCTest
@testable import ButlerCore

final class CommitmentTests: XCTestCase {
    func testCommitmentRoundTripsThroughJSON() throws {
        let original = Commitment(
            text: "Finish the pricing page copy",
            startedAt: Date(timeIntervalSince1970: 1_000),
            deadline: Date(timeIntervalSince1970: 4_600)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Commitment.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testNudgeDecisionsAreComparable() {
        XCTAssertEqual(NudgeDecision.stayQuiet(reason: "on task"), .stayQuiet(reason: "on task"))
        XCTAssertNotEqual(NudgeDecision.stayQuiet(reason: "on task"), .nudge(message: "Sir?"))
    }
}
