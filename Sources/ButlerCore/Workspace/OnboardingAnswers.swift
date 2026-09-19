import Foundation

/// The five first-run answers that fill USER.md.
public struct OnboardingAnswers: Equatable, Sendable {
    public var name: String
    public var work: String
    public var hours: String
    public var workApps: String
    public var helpsWhenStuck: String

    public init(name: String, work: String, hours: String, workApps: String, helpsWhenStuck: String) {
        self.name = name
        self.work = work
        self.hours = hours
        self.workApps = workApps
        self.helpsWhenStuck = helpsWhenStuck
    }

    /// USER.md body in the same sections as the template.
    func renderBody() -> String {
        """
        # User

        ## Identity
        Name: \(name)
        Address as: sir

        ## Work
        \(work)

        ## Working hours
        Active: \(hours). Butler stays silent outside these hours.

        ## Apps and sites that are always work
        \(workApps)

        ## Apps and sites that are usually drift
        _Not set yet. Butler asks before assuming._

        ## What helps when stuck
        \(helpsWhenStuck)

        ## What does not help
        _Not set yet._
        """
    }
}
