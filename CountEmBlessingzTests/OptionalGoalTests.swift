import Testing
import SwiftData
import Foundation
@testable import CountEmBlessingz

/// The honeypot goal is optional: 0 means "no goal", and that is the default.
@MainActor
struct OptionalGoalTests {
    private let us = Locale(identifier: "en_US")

    // MARK: Default

    @Test func newInstallHasNoGoal() {
        let settings = AppSettings()
        #expect(settings.goal == 0)
        #expect(!settings.hasGoal)
    }

    @Test func eraseAllGoesBackToNoGoal() {
        let settings = AppSettings()
        settings.goal = 5_000
        #expect(settings.hasGoal)
        settings.resetToDefaults()
        #expect(settings.goal == 0 && !settings.hasGoal)
    }

    // MARK: Typing in Settings

    @Test func emptyOrZeroTurnsTheGoalOff() {
        #expect(GoalInput.resolve("", current: 20_000, locale: us) == 0)
        #expect(GoalInput.resolve("   ", current: 20_000, locale: us) == 0)
        #expect(GoalInput.resolve("0", current: 20_000, locale: us) == 0)
        #expect(GoalInput.resolve("0.00", current: 20_000, locale: us) == 0)
    }

    @Test func aRealNumberSetsTheGoal() {
        #expect(GoalInput.resolve("5000", current: 0, locale: us) == 5_000)
        #expect(GoalInput.resolve("1,500", current: 0, locale: us) == 1_500)
    }

    @Test func junkKeepsWhatWasThere() {
        #expect(GoalInput.resolve("12abc", current: 7_000, locale: us) == 7_000)
        #expect(GoalInput.resolve("-5", current: 7_000, locale: us) == 7_000)
        #expect(GoalInput.resolve("12abc", current: 0, locale: us) == 0)
    }

    @Test func fieldShowsNothingWhenThereIsNoGoal() {
        #expect(GoalInput.fieldText(for: 0, locale: us) == "")
        #expect(GoalInput.fieldText(for: 20_000, locale: us) == "20,000")
    }

    // MARK: Progress

    @Test func noGoalMeansNoProgress() {
        #expect(GoalProgress.fraction(total: 9_776, goal: 0) == nil)
    }

    @Test func progressIsCappedAtOne() throws {
        #expect(try #require(GoalProgress.fraction(total: 5_000, goal: 20_000)) == 0.25)
        #expect(try #require(GoalProgress.fraction(total: 30_000, goal: 20_000)) == 1)
        #expect(try #require(GoalProgress.fraction(total: 0, goal: 20_000)) == 0)
    }

    // MARK: Currency change and milestones

    @Test func convertingCurrencyKeepsNoGoalAtZero() {
        #expect(CurrencyConverter.convertGoal(0, rate: 0.21) == 0)            // used to become 100
        #expect(CurrencyConverter.convertGoal(20_000, rate: 0.21) == 4_200)   // unchanged behaviour
    }

    @Test func noGoalAddsNoGoalMilestone() {
        #expect(MilestoneService.thresholds(goal: 0) == MilestoneService.thresholds(goal: nil))
        #expect(MilestoneService.crossed(before: 100, after: 150, goal: 0) == nil)
    }
}
