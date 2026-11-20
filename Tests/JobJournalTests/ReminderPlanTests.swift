import Foundation
import Testing

@testable import JobJournal

@Suite struct ReminderPlanTests {
  @Test func groupsEnabledUnfinishedDeadlinesAndUsesPreviousLocalEvening() throws {
    var journal = Journal()
    let first = try journal.save(draft("A社", "適性検査"))
    _ = try journal.save(draft())
    _ = try journal.save(draft("C社", "通知オフ", notify: false))
    _ = try journal.save(draft("D社", "面接", "2026-12-05"))
    let now = try day("2026-12-03").date(in: tokyo)
    let plans = ReminderPlan.pending(in: journal, now: now, calendar: tokyo)
    #expect(plans.map(\.count) == [2, 1])
    let firstPlan = try #require(plans.first)
    #expect(firstPlan.day == (try day()))
    #expect(Day(firstPlan.fireDate, calendar: tokyo) == (try day("2026-12-03")))
    #expect(tokyo.component(.hour, from: firstPlan.fireDate) == 19)
    #expect(
      ReminderPlan.pending(in: journal, now: firstPlan.fireDate, calendar: tokyo).map(\.count) == [
        1
      ])
    try journal.complete(first, at: now)
    #expect(
      ReminderPlan.pending(in: journal, now: now, calendar: tokyo, limit: 1).map(\.count) == [1])
  }

  @Test func remindersUseCivilEveningsAcrossDSTAndNewYear() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    for (due, previous) in [
      ("2026-03-09", "2026-03-08"), ("2026-11-02", "2026-11-01"), ("2027-01-01", "2026-12-31"),
    ] {
      var journal = Journal()
      _ = try journal.save(draft("A", "面接", due))
      let plan = try #require(
        ReminderPlan.pending(in: journal, now: .distantPast, calendar: calendar).first)
      #expect(Day(plan.fireDate, calendar: calendar) == (try day(previous)))
      #expect(calendar.component(.hour, from: plan.fireDate) == 19)
    }
  }
}
