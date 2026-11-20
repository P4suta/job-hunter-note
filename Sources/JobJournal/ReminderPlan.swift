import Foundation

public struct ReminderPlan: Equatable, Sendable {
  public let day: Day
  public let count: Int
  public let fireDate: Date

  public static func pending(in journal: Journal, now: Date, calendar: Calendar, limit: Int = 64)
    -> [Self]
  {
    let calendar = Day.gregorian(in: calendar.timeZone)
    let civil = Day.gregorian(in: .gmt)
    let groups = Dictionary(grouping: journal.open().filter(\.notify), by: \.day)
    return groups.keys.sorted().compactMap { day -> Self? in
      guard (try? day.date(in: calendar)) != nil, let due = try? day.date(in: civil),
        let previousDate = civil.date(byAdding: .day, value: -1, to: due)
      else { return nil }
      let previous = Day(previousDate, calendar: civil)
      guard let start = try? previous.date(in: calendar),
        let fire = calendar.date(
          bySettingHour: 19, minute: 0, second: 0, of: start, matchingPolicy: .strict),
        Day(fire, calendar: calendar) == previous,
        fire > now, let group = groups[day]
      else { return nil }
      return Self(day: day, count: group.count, fireDate: fire)
    }.prefix(max(0, limit)).map { $0 }
  }
}
