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

struct DesignIcon: View {
  let name: String
  @ScaledMetric(relativeTo: .body) private var size = 22
  init(_ name: String) { self.name = name }
  var body: some View {
    Image(name).renderingMode(.template).resizable().scaledToFit()
      .frame(width: size, height: size).accessibilityHidden(true)
  }
}

struct PrimaryAction: View {
  let title: String
  let icon: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack {
        DesignIcon(icon)
        Text(title).font(.headline)
      }
      .frame(maxWidth: .infinity, minHeight: 48)
      .padding(.horizontal, 8)
      .foregroundStyle(Color(uiColor: .systemBackground))
      .background(Color(uiColor: .label), in: RoundedRectangle(cornerRadius: 12))
    }.buttonStyle(.plain)
  }
}

struct InvertedCard<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View {
    content.frame(maxWidth: .infinity, alignment: .leading)
      .padding(20).foregroundStyle(Color(uiColor: .systemBackground))
      .background(.primary, in: RoundedRectangle(cornerRadius: 16))
  }
}

struct DeadlineRow: View {
  let deadline: Deadline
  let company: String
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      DesignIcon("ClipboardList").padding(.top, 2)
      VStack(alignment: .leading, spacing: 4) {
        Text(deadline.title).font(.headline)
        Text(company).font(.subheadline)
        Text(JapaneseDate.label(deadline.day, time: deadline.time)).font(.subheadline)
      }.fixedSize(horizontal: false, vertical: true)
    }.padding(.vertical, 4)
  }
}

struct DetailValue: View {
  let label: String
  let value: String
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.caption)
      Text(value).font(.headline)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
  }
}
