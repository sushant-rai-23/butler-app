import Foundation

/// The outcome of a self-check. Silence is the default and carries a reason
/// so it can be logged and tested.
public enum NudgeDecision: Equatable, Sendable {
    case stayQuiet(reason: String)
    case nudge(message: String)
}

/// Turns the commitment plus recent observations into at most one short nudge.
///
/// Rules, in order: no commitment means silence; drift is several minutes away
/// from the commitment with no plausible link; a stall is the same window with
/// no change for longer than the user's rhythm; a time-box ending is said once;
/// a dismissed nudge is never repeated for the same commitment.
public protocol NudgePolicy: Sendable {
    func decide(commitment: Commitment?, recent: [Observation], now: Date) -> NudgeDecision
}
