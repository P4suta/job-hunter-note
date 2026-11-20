import JobJournal
import UserNotifications
import XCTest

@testable import JobHunterNote

@MainActor
private final class TestNotificationCenter: ReminderCenter {
  enum Failure: Error { case unavailable }
  var status: UNAuthorizationStatus = .authorized
  var grant = false
  var prompts: [UNAuthorizationOptions] = []
  var requests: [String: UNNotificationRequest] = [:]
  var additions: [String] = []
  var removals: [String] = []
  var failOnce: String?
  var beforeRead: (() async -> Void)?

  func authorizationStatus() async -> UNAuthorizationStatus { status }

  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
    prompts.append(options)
    status = grant ? .authorized : .denied
    return grant
  }

  func pendingNotificationRequests() async -> [UNNotificationRequest] {
    await beforeRead?()
    return Array(requests.values)
  }

  func add(_ request: UNNotificationRequest) async throws {
    if request.identifier == failOnce {
      failOnce = nil
      throw Failure.unavailable
    }
    additions.append(request.identifier)
    requests[request.identifier] = request
  }

  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
    removals.append(contentsOf: identifiers)
    for id in identifiers { requests.removeValue(forKey: id) }
  }
}

@MainActor
final class ReminderAuthorizationTests: XCTestCase {
  private let calendar = Day.gregorian(in: .gmt)
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  private func journal(_ keys: [String]) throws -> Journal {
    var journal = Journal()
    for key in keys {
      let day = try XCTUnwrap(Day(key: key))
      try journal.save(DeadlineDraft(company: "A社", title: "提出", day: day))
    }
    return journal
  }

  func testPermissionDecisionsPromptOnceAndRememberTheResponse() async throws {
    for grant in [true, false] {
      let center = TestNotificationCenter()
      let reminders = LocalReminders(center: center)
      center.status = .notDetermined
      center.grant = grant
      for _ in 0..<2 {
        let allowed = try await reminders.requestAccess()
        XCTAssertEqual(allowed, grant)
      }
      XCTAssertEqual(center.prompts, [[.alert, .sound]])
    }
    for status in [UNAuthorizationStatus.authorized, .provisional, .ephemeral, .denied] {
      let center = TestNotificationCenter()
      center.status = status
      let allowed = try await LocalReminders(center: center).requestAccess()
      XCTAssertEqual(allowed, status != .denied)
      XCTAssertTrue(center.prompts.isEmpty)
    }
  }

  func testFailedAdditionCanBeRetriedAndRevocationRemovesOnlyOwnedRequests() async throws {
    let center = TestNotificationCenter()
    let reminders = LocalReminders(center: center)
    let scheduled = try journal(["2026-12-04", "2026-12-05", "2026-12-06"])
    let ids = ["deadline.2026-12-04", "deadline.2026-12-05", "deadline.2026-12-06"]
    center.requests["other"] = UNNotificationRequest(
      identifier: "other", content: UNMutableNotificationContent(), trigger: nil)
    center.failOnce = ids[1]
    do {
      try await reminders.refresh(journal: scheduled, now: now, calendar: calendar)
      XCTFail("The notification center error must reach the caller.")
    } catch TestNotificationCenter.Failure.unavailable {}
    XCTAssertEqual(center.additions, [ids[0]])
    try await reminders.refresh(journal: scheduled, now: now, calendar: calendar)
    try await reminders.refresh(journal: scheduled, now: now, calendar: calendar)
    XCTAssertEqual(center.additions, ids)
    center.status = .denied
    try await reminders.refresh(journal: scheduled, now: now, calendar: calendar)
    XCTAssertEqual(Set(center.removals), Set(ids))
    XCTAssertEqual(Array(center.requests.keys), ["other"])
  }

  func testForeignRequestsReserveCapacityAndEarliestDeadlinesUseTheRemainingSlots() async throws {
    let center = TestNotificationCenter()
    let reminders = LocalReminders(center: center)
    for index in 0..<63 {
      let id = "other." + String(index)
      center.requests[id] = UNNotificationRequest(
        identifier: id, content: UNMutableNotificationContent(), trigger: nil)
    }
    let scheduled = try journal(["2026-12-07", "2026-12-03", "2026-12-05"])
    try await reminders.refresh(journal: scheduled, now: now, calendar: calendar)
    XCTAssertEqual(center.additions, ["deadline.2026-12-03"])
    center.requests.removeValue(forKey: "other.0")
    try await reminders.refresh(journal: scheduled, now: now, calendar: calendar)
    XCTAssertEqual(center.additions, ["deadline.2026-12-03", "deadline.2026-12-05"])
    XCTAssertEqual(center.requests.count, 64)
    XCTAssertTrue(center.removals.isEmpty)
  }

  func testSupersededReadCannotRemoveAnAlreadyCorrectReminder() async throws {
    let center = TestNotificationCenter()
    let reminders = LocalReminders(center: center)
    let wanted = try journal(["2026-12-04"])
    try await reminders.refresh(journal: wanted, now: now, calendar: calendar)
    let began = expectation(description: "The earlier refresh is reading pending requests")
    var release: CheckedContinuation<Void, Never>?
    center.beforeRead = {
      await withCheckedContinuation { continuation in
        release = continuation
        began.fulfill()
      }
    }
    let earlier = Task {
      try await reminders.refresh(journal: Journal(), now: now, calendar: calendar)
    }
    let read = await XCTWaiter.fulfillment(of: [began], timeout: 3)
    XCTAssertEqual(read, .completed)
    center.beforeRead = nil
    release?.resume()
    try await reminders.refresh(journal: wanted, now: now, calendar: calendar)
    try await earlier.value
    XCTAssertTrue(center.removals.isEmpty)
    XCTAssertEqual(center.additions, ["deadline.2026-12-04"])
  }
}
