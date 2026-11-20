import JobJournal
import UserNotifications
import XCTest

@testable import JobHunterNote

final class ReminderTests: XCTestCase {
  @MainActor func testAccentMatchesSystemLabelInLightAndDarkAppearance() throws {
    let accent = try XCTUnwrap(UIColor(named: "AccentColor"))
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    for style in [UIUserInterfaceStyle.light, .dark] {
      let traits = UITraitCollection(userInterfaceStyle: style)
      func channels(_ color: UIColor) throws -> [CGFloat] {
        try XCTUnwrap(
          color.resolvedColor(with: traits).cgColor.converted(
            to: space, intent: .defaultIntent, options: nil)?.components)
      }
      let expected = try channels(.label)
      let actual = try channels(accent)
      XCTAssertEqual(actual.count, expected.count)
      for (a, b) in zip(actual, expected) { XCTAssertEqual(a, b, accuracy: 0.002) }
    }
  }

  func testNotificationRouteOpensOnlyAValidCalendarDay() {
    XCTAssertEqual(ReminderRoute.day(from: ["dueDay": "2026-12-04"])?.key, "2026-12-04")
    XCTAssertNil(ReminderRoute.day(from: ["dueDay": "2026-02-30"]))
    XCTAssertNil(ReminderRoute.day(from: [:]))
  }

  @MainActor func testRequestGroupsByDateAndCarriesTheTapDestination() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
    let day = try XCTUnwrap(Day(key: "2026-12-04"))
    var journal = Journal()
    for title in ["ES", "Interview"] {
      _ = try journal.save(
        DeadlineDraft(company: "ACME", title: title, day: day, time: nil, notify: true))
    }
    let plan = try XCTUnwrap(
      ReminderPlan.pending(in: journal, now: .distantPast, calendar: calendar).first)
    let request = LocalReminders().request(for: plan, calendar: calendar)
    XCTAssertEqual(request.identifier, "deadline.2026-12-04")
    XCTAssertEqual(request.content.title, "明日の締切は2件")
    XCTAssertEqual(ReminderRoute.day(from: request.content.userInfo), day)
    let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
    XCTAssertFalse(trigger.repeats)
    XCTAssertEqual(trigger.dateComponents.day, 3)
    XCTAssertEqual(trigger.dateComponents.hour, 19)
    XCTAssertEqual(trigger.dateComponents.minute, 0)
  }

  @MainActor func testFailedDiskWriteLeavesPublishedJournalUntouched() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = JournalStore(file: JournalFile(url: folder.appendingPathComponent("journal.json")))
    try FileManager.default.removeItem(at: folder)
    try Data().write(to: folder)
    XCTAssertThrowsError(try store.change { try $0.addEmployer("ACME") })
    XCTAssertTrue(store.journal.companies.isEmpty)
  }

  #if targetEnvironment(simulator)
    @MainActor func testSystemReplacesTheEveningCountAndCancelsTheLastReminder() async throws {
      let center = UNUserNotificationCenter.current()
      let granted = try await center.requestAuthorization(options: [.provisional, .alert, .sound])
      XCTAssertTrue(granted)
      let namespace = "test." + UUID().uuidString + "."
      let reminders = LocalReminders(namespace: namespace)
      let calendar = Day.gregorian(in: .current)
      let now = Date()
      let due = Day(
        try XCTUnwrap(calendar.date(byAdding: .day, value: 5, to: now)), calendar: calendar)
      let identifier = namespace + due.key
      defer { center.removePendingNotificationRequests(withIdentifiers: [identifier]) }
      var journal = Journal()
      let first = try journal.save(DeadlineDraft(company: "A", title: "ES", day: due))
      let second = try journal.save(DeadlineDraft(company: "B", title: "Interview", day: due))
      try await reminders.refresh(journal: journal, now: now, calendar: calendar)
      var pending = await center.pendingNotificationRequests().filter {
        $0.identifier == identifier
      }
      XCTAssertEqual(pending.map(\.content.title), ["明日の締切は2件"])
      try journal.complete(first, at: now)
      try await reminders.refresh(journal: journal, now: now, calendar: calendar)
      pending = await center.pendingNotificationRequests().filter { $0.identifier == identifier }
      XCTAssertEqual(pending.map(\.content.title), ["明日の締切は1件"])
      try journal.complete(second, at: now)
      try await reminders.refresh(journal: journal, now: now, calendar: calendar)
      pending = await center.pendingNotificationRequests().filter { $0.identifier == identifier }
      XCTAssertTrue(pending.isEmpty)
    }
  #endif
}
