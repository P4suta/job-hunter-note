import JobJournal
import SwiftUI

struct DeadlineList: View {
  let journal: Journal
  let today: Day
  let filter: Day?
  @Binding var selection: UUID?
  let add: () -> Void
  let clearFilter: () -> Void
  let example: (() -> Void)?

  var body: some View {
    let entries = journal.open(on: filter)
    List(selection: $selection) {
      if let filter {
        Text(JapaneseDate.label(filter)).font(.headline).accessibilityIdentifier("dayFilter")
        Button("すべての締切を見る", action: clearFilter)
      } else {
        Text(JapaneseDate.label(today)).font(.subheadline).listRowSeparator(.hidden)
      }
      if journal.deadlines.isEmpty {
        VStack(alignment: .leading, spacing: 16) {
          DesignIcon("CalendarPlus")
          Text("登録した締切はまだありません").font(.title2.bold())
            .accessibilityIdentifier("emptyDeadlines")
          Text("企業名、用件、締切日を登録できます。")
        }.padding(.vertical, 24)
          .listRowSeparator(.hidden)
      } else {
        InvertedCard {
          HStack {
            VStack(alignment: .leading, spacing: 5) {
              Text("未完了の用件").font(.subheadline.bold())
              Text("\(entries.count)件").font(.largeTitle.bold()).monospacedDigit()
            }
            Spacer()
            DesignIcon("CalendarDaysLight")
          }
        }.listRowSeparator(.hidden).accessibilityElement(children: .combine)
        if filter != nil {
          if entries.isEmpty { Text("未完了の用件はありません。") }
          rows(entries)
        } else {
          ForEach(DeadlineBucket.allCases, id: \.self) { bucket in
            let items = entries.filter { $0.day.bucket(on: today) == bucket }
            Section {
              rows(items)
            } header: {
              HStack {
                Text(bucket.label)
                Spacer()
                Text("\(items.count)件").monospacedDigit()
              }
              .font(.subheadline.bold()).foregroundStyle(.primary).textCase(nil)
            }
          }
        }
      }
    }
    .listStyle(.plain)
    .navigationTitle(filter == nil ? "締切" : "締切日の用件")
    .toolbar {
      if journal.deadlines.isEmpty, let example {
        ToolbarItem(placement: .topBarTrailing) {
          Button("入力例で試す", action: example).accessibilityIdentifier("startExample")
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      PrimaryAction(
        title: journal.deadlines.isEmpty ? "最初の締切を追加" : "締切を追加", icon: "PlusLight", action: add
      )
      .accessibilityIdentifier("addDeadline").padding(.horizontal).padding(.vertical, 8)
      .background(Color(uiColor: .systemBackground))
    }
  }

  @ViewBuilder private func rows(_ entries: [Deadline]) -> some View {
    ForEach(entries) { deadline in
      NavigationLink(value: deadline.id) {
        DeadlineRow(deadline: deadline, company: journal.company(deadline.companyID)?.name ?? "")
      }.accessibilityIdentifier("task." + deadline.title)
    }
  }
}

struct DeadlineDetail: View {
  let entry: Deadline
  let company: String
  let edit: () -> Void
  let complete: () -> Void
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text(company).font(.subheadline.bold())
        Text(entry.title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
          .padding(.bottom, 16)
        Divider()
        DetailValue(label: "締切日", value: JapaneseDate.label(entry.day))
        Divider()
        DetailValue(label: "時刻", value: entry.time.map(JapaneseDate.clock) ?? "指定なし")
        Divider()
        DetailValue(label: "前夜の通知", value: entry.notify ? "前日 19:00" : "オフ")
      }.padding().frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
    }
    .navigationTitle("用件の詳細").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      Button("編集", action: edit).accessibilityIdentifier("editDeadline")
    }
    .safeAreaInset(edge: .bottom) {
      PrimaryAction(title: "完了にする", icon: "CheckLight", action: complete)
        .accessibilityIdentifier("completeDeadline").frame(maxWidth: 680).padding()
    }
  }
}

struct ExampleNotice: View {
  let day: Day
  let count: Int
  let open: () -> Void
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 24) {
        Text("19:00").font(.largeTitle.bold()).monospacedDigit()
        Button(action: open) {
          HStack(alignment: .top) {
            DesignIcon("Bell")
            VStack(alignment: .leading, spacing: 6) {
              Text("明日の締切は\(count)件").font(.headline)
              Text(JapaneseDate.label(day))
            }
            Spacer()
          }.padding().background(.background, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).accessibilityIdentifier("openNotification")
        Spacer()
      }.padding().frame(maxWidth: 680).navigationTitle("前夜の通知見本")
        .toolbar { Button("閉じる") { dismiss() } }
    }.presentationDetents([.medium, .large])
  }
}
