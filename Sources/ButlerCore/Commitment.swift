import Foundation

/// What the user said they are doing right now, and until when.
///
/// There is at most one active commitment. It is the anchor every nudge is
/// measured against; with no commitment, Butler stays silent.
public struct Commitment: Equatable, Codable, Sendable {
    public var id: UUID
    public var text: String
    public var startedAt: Date
    public var deadline: Date?

    public init(id: UUID = UUID(), text: String, startedAt: Date, deadline: Date? = nil) {
        self.id = id
        self.text = text
        self.startedAt = startedAt
        self.deadline = deadline
    }
}

/// Persistence for the active commitment. Implemented over the workspace later.
public protocol CommitmentStore: Sendable {
    func current() throws -> Commitment?
    func save(_ commitment: Commitment?) throws
}
