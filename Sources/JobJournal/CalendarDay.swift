import Foundation

public enum DeadlineBucket: CaseIterable, Sendable {
  case overdue, today, future
}

public struct Day: Hashable, Comparable, Codable, Sendable {
  public let key: String

  public init(_ date: Date, calendar: Calendar) {
    let parts = Self.gregorian(in: calendar.timeZone).dateComponents(
      [.year, .month, .day], from: date)
    key = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
  }

  public init?(key: String) {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3, (1...9999).contains(parts[0]) else { return nil }
    let calendar = Self.gregorian(in: .gmt)
    guard
      let date = calendar.date(
        from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
      Day(date, calendar: calendar).key == key
    else { return nil }
    self.key = key
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    guard let day = Day(key: try container.decode(String.self)) else {
      throw JournalError.invalidDay
    }
    self = day
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(key)
  }

  public func date(in calendar: Calendar) throws -> Date {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    let local = Self.gregorian(in: calendar.timeZone)
    guard
      let date = local.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
      Day(date, calendar: local) == self
    else { throw JournalError.invalidDay }
    return date
  }

  public static func gregorian(in zone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    return calendar
  }

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.key < rhs.key }

  public func bucket(on today: Day) -> DeadlineBucket {
    if self < today { return .overdue }
    if today < self { return .future }
    return .today
  }
}
