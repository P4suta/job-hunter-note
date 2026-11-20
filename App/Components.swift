import JobJournal
import SwiftUI

extension Stage {
  var label: String {
    switch self {
    case .documents: "書類選考"
    case .assessment: "適性検査"
    case .interview: "面接"
    case .waiting: "結果待ち"
    }
  }
}

extension DeadlineBucket {
  var label: String {
    switch self {
    case .overdue: "期限切れ"
    case .today: "今日"
    case .future: "明日以降"
    }
  }
}

enum JapaneseDate {
  static func label(_ day: Day, time: Int? = nil) -> String {
    let calendar = Day.gregorian(in: .current)
    guard let date = try? day.date(in: calendar) else { return day.key }
    let style = Date.VerbatimFormatStyle(
      format: "\(month: .defaultDigits)月\(day: .defaultDigits)日（\(weekday: .abbreviated)）",
      locale: Locale(identifier: "ja_JP"), timeZone: calendar.timeZone, calendar: calendar
    )
    let label = date.formatted(style)
    return time.map { label + " " + clock($0) } ?? label
  }

  static func clock(_ minutes: Int) -> String {
    String(format: "%d:%02d", minutes / 60, minutes % 60)
  }
}
