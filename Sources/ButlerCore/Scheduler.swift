import Foundation

/// Fires the periodic self-check and the observation tick.
///
/// The scheduler enforces the hard limits from `HEARTBEAT.md`: active hours,
/// a cap on consecutive runs without user activity, a daily cap, and no
/// overlapping runs. A model is never called from a bare timer; the scheduler
/// only wakes the nudge policy, which decides whether a model call is warranted.
public protocol Scheduler: AnyObject, Sendable {
    func schedule(id: String, every interval: TimeInterval, action: @escaping @Sendable () async -> Void)
    func cancel(id: String)
}
