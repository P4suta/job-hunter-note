import JobJournal
import UserNotifications
import XCTest

@testable import JobHunterNote

@MainActor
final class ReminderReconciliationTests: XCTestCase {
  #if targetEnvironment(simulator)
    func testRefreshRepairsTheTapDestinationAndPreservesUnrelatedRequests() async throws {
      let center = UNUserNotificationCenter.current()
      let granted = try await center.requestAuthorization(options: [.provisional, .alert, .sound])
      XCTAssertTrue(granted)
      let calendar = Day.gregorian(in: .current)
      let now = Date()
      let due = Day(
        try XCTUnwrap(calendar.date(byAdding: .day, value: 4, to: now)), calendar: calendar)
      var journal = Journal()
      try journal.save(DeadlineDraft(company: "A社", title: "提出", day: due))
      let prefix = "test." + UUID().uuidString + "."
      let reminders = LocalReminders(namespace: prefix)
      let plan = try XCTUnwrap(
        ReminderPlan.pending(in: journal, now: now, calendar: calendar).first)
      let desired = reminders.request(for: plan, calendar: calendar)
      let wrong = try XCTUnwrap(desired.content.mutableCopy() as? UNMutableNotificationContent)
      wrong.userInfo = ["dueDay": "2001-01-01", "count": 7]
      let other = "other." + UUID().uuidString
      defer {
        center.removePendingNotificationRequests(withIdentifiers: [other, desired.identifier])
      }
      try await center.add(
        UNNotificationRequest(identifier: other, content: wrong, trigger: desired.trigger))
      try await center.add(
        UNNotificationRequest(
          identifier: desired.identifier, content: wrong, trigger: desired.trigger))
      try await reminders.refresh(journal: journal, now: now, calendar: calendar)
      let pending = await center.pendingNotificationRequests()
      let repaired = try XCTUnwrap(pending.first { $0.identifier == desired.identifier })
      XCTAssertEqual(ReminderRoute.day(from: repaired.content.userInfo), due)
      XCTAssertEqual(repaired.content.userInfo["count"] as? Int, 1)
      let trigger = try XCTUnwrap(repaired.trigger as? UNCalendarNotificationTrigger)
      XCTAssertEqual(
        try XCTUnwrap(trigger.nextTriggerDate()).timeIntervalSince(plan.fireDate), 0, accuracy: 1)
      let unrelated = try XCTUnwrap(pending.first { $0.identifier == other })
      XCTAssertEqual(unrelated.content.userInfo["count"] as? Int, 7)
    }
  #endif
}
