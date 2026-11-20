import JobJournal
import UIKit
import UserNotifications

enum ReminderRoute {
  static func day(from info: [AnyHashable: Any]) -> Day? {
    (info["dueDay"] as? String).flatMap(Day.init(key:))
  }
}

@MainActor @Observable
final class NotificationRouter: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  struct Destination: Identifiable {
    let id = UUID()
    let day: Day
  }
  var destination: Destination?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
      let day = ReminderRoute.day(from: response.notification.request.content.userInfo)
    else { return }
    await MainActor.run { destination = Destination(day: day) }
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }
}

@MainActor
protocol ReminderCenter {
  func authorizationStatus() async -> UNAuthorizationStatus
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
  func pendingNotificationRequests() async -> [UNNotificationRequest]
  func add(_ request: UNNotificationRequest) async throws
  func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: ReminderCenter {
  func authorizationStatus() async -> UNAuthorizationStatus {
    await notificationSettings().authorizationStatus
  }
}

@MainActor
final class LocalReminders {
  private let center: any ReminderCenter
  private let namespace: String
  private var tail: Task<Void, Never>?
  private var generation = 0

  init(
    namespace: String = "deadline.", center: any ReminderCenter = UNUserNotificationCenter.current()
  ) {
    self.namespace = namespace
    self.center = center
  }

  func requestAccess() async throws -> Bool {
    switch await center.authorizationStatus() {
    case .notDetermined: return try await center.requestAuthorization(options: [.alert, .sound])
    case .authorized, .provisional, .ephemeral: return true
    default: return false
    }
  }

  func request(for plan: ReminderPlan, calendar: Calendar) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = "明日の締切は\(plan.count)件"
    content.body = "タップして締切を確認できます。"
    content.sound = .default
    content.userInfo = ["dueDay": plan.day.key, "count": plan.count]
    var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
    parts.calendar = Calendar(identifier: .gregorian)
    let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
    return UNNotificationRequest(
      identifier: namespace + plan.day.key, content: content, trigger: trigger)
  }

  func refresh(journal: Journal, now: Date, calendar: Calendar) async throws {
    generation += 1
    let current = generation
    let previous = tail
    let job = Task {
      await previous?.value
      guard generation == current else { return }
      let access = await center.authorizationStatus()
      let enabled = [.authorized, .provisional, .ephemeral].contains(access)
      let requests = await center.pendingNotificationRequests()
      guard generation == current else { return }
      let ours = requests.filter { $0.identifier.hasPrefix(namespace) }
      let capacity = max(0, 64 - (requests.count - ours.count))
      let plans =
        enabled
        ? ReminderPlan.pending(in: journal, now: now, calendar: calendar, limit: capacity) : []
      let desiredRequests = plans.map { request(for: $0, calendar: calendar) }
      let wanted = Set(desiredRequests.map(\.identifier))
      let obsolete = ours.map(\.identifier).filter { !wanted.contains($0) }
      if !obsolete.isEmpty { center.removePendingNotificationRequests(withIdentifiers: obsolete) }
      for desired in desiredRequests {
        guard generation == current else { return }
        if ours.contains(where: {
          $0.identifier == desired.identifier && $0.content.title == desired.content.title
            && $0.content.body == desired.content.body
            && NSDictionary(dictionary: $0.content.userInfo).isEqual(to: desired.content.userInfo)
            && ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents
              == (desired.trigger as? UNCalendarNotificationTrigger)?.dateComponents
        }) {
          continue
        }
        try await center.add(desired)
      }
    }
    tail = Task { _ = await job.result }
    defer { if generation == current { tail = nil } }
    try await job.value
  }
}
