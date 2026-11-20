import Foundation
import Testing

@testable import JobJournal

@Suite struct CalendarBoundaryTests {
  @Test func civilDayOrderingIsStrictAndTransitiveAcrossYearEnd() throws {
    let ordered = try ["2027-12-31", "2028-01-01", "2028-02-29"].map { try day($0) }
    for (i, left) in ordered.enumerated() {
      for (j, right) in ordered.enumerated() {
        #expect((left < right) == (i < j))
        #expect((left == right) == (i == j))
        let expected: DeadlineBucket = i < j ? .overdue : (i == j ? .today : .future)
        #expect(left.bucket(on: right) == expected)
      }
    }
  }

  @Test func calendarDaysRoundTripAcrossLeapCenturiesAndTimeZones() throws {
    let zones = ["UTC", "Asia/Kathmandu", "America/New_York", "Australia/Lord_Howe"]
    for year in [1900, 2000, 2024, 2025, 2100] {
      let leap = year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
      let lengths = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
      for (offset, length) in lengths.enumerated() {
        let month = offset + 1
        for number in [1, length, length + 1] {
          let key = String(format: "%04d-%02d-%02d", year, month, number)
          if number > length {
            #expect(Day(key: key) == nil)
            continue
          }
          let parsed = try #require(Day(key: key))
          for zone in zones {
            let calendar = Day.gregorian(in: try #require(TimeZone(identifier: zone)))
            #expect(try Day(parsed.date(in: calendar), calendar: calendar) == parsed)
          }
          #expect(try JSONDecoder().decode(Day.self, from: JSONEncoder().encode(parsed)) == parsed)
        }
      }
    }
  }

  @Test func skipsRemindersWhenThePreviousLocalDateDidNotExist() throws {
    let calendar = Day.gregorian(in: try #require(TimeZone(identifier: "Pacific/Apia")))
    let now = try day("2011-12-28").date(in: calendar)
    var journal = Journal()
    for key in ["2011-12-30", "2011-12-31", "2012-01-01"] {
      try journal.save(draft("A社", "提出", key))
    }
    let plans = ReminderPlan.pending(in: journal, now: now, calendar: calendar)
    #expect(plans.map(\.day.key) == ["2012-01-01"])
    let reminder = try #require(plans.first)
    #expect(Day(reminder.fireDate, calendar: calendar).key == "2011-12-31")
    #expect(calendar.component(.hour, from: reminder.fireDate) == 19)
  }

  @Test func reminderCapacityKeepsNearestEligibleDaysAndRefillsFreedSlots() throws {
    let start = try day("2028-02-01").date(in: tokyo)
    var journal = Journal()
    var records: [(id: UUID, day: Day)] = []
    for offset in (1...70).reversed() {
      let due = Day(
        try #require(tokyo.date(byAdding: .day, value: offset, to: start)), calendar: tokyo)
      let id = try journal.save(
        DeadlineDraft(company: "A社", title: "面接", day: due, notify: offset != 3))
      records.append((id, due))
    }
    records.reverse()
    try journal.complete(records[1].id, at: start)
    try journal.save(DeadlineDraft(company: "B社", title: "資料", day: records[0].day))
    let eligible = [records[0].day] + records.dropFirst(3).map(\.day)
    for limit in [-1, 0, 1, 63, 64, 65, 100] {
      let planned = ReminderPlan.pending(in: journal, now: start, calendar: tokyo, limit: limit)
      #expect(planned.map(\.day) == Array(eligible.prefix(max(0, limit))))
      #expect(planned.map(\.count) == planned.map { $0.day == records[0].day ? 2 : 1 })
    }
    let fire = try #require(
      ReminderPlan.pending(in: journal, now: start, calendar: tokyo).first?.fireDate)
    #expect(
      ReminderPlan.pending(in: journal, now: fire.addingTimeInterval(-1), calendar: tokyo).first?
        .day
        == eligible.first)
    for now in [fire, fire.addingTimeInterval(1)] {
      let pending = ReminderPlan.pending(in: journal, now: now, calendar: tokyo)
      #expect(pending.map(\.day) == Array(eligible.dropFirst().prefix(64)))
    }
  }
}
