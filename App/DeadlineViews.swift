import JobJournal
import SwiftUI

struct DeadlineList: View {
  let journal: Journal
  let today: Day
  let filter: Day?
  @Binding var selection: UUID?
  let add: () -> Void
  let edit: (UUID) -> Void
  let complete: (UUID) -> Void
  let clearFilter: () -> Void
  let example: (() -> Void)?

  var body: some View {
    let entries = journal.open(on: filter)
    List(selection: $selection) {
      if let filter {
        Section {
          Button("すべての締切を見る", action: clearFilter)
        } header: {
          Text(JapaneseDate.label(filter)).accessibilityIdentifier("dayFilter")
        }
      }
      if filter != nil {
        Section("未完了の用件 \(entries.count)件") { rows(entries) }
      } else {
        ForEach(DeadlineBucket.allCases, id: \.self) { bucket in
          let items = entries.filter { $0.day.bucket(on: today) == bucket }
          if !items.isEmpty {
            Section {
              rows(items)
            } header: {
              HStack {
                Text(bucket.label)
                Spacer()
                Text("\(items.count)件").monospacedDigit()
              }
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .overlay {
      if entries.isEmpty, filter == nil {
        ContentUnavailableView {
          Label(
            journal.deadlines.isEmpty ? "登録した締切はまだありません" : "未完了の用件はありません",
            systemImage: "calendar"
          )
          .accessibilityIdentifier("emptyDeadlines")
        } description: {
          Text("企業名、用件、締切日を登録できます。")
        } actions: {
          if journal.deadlines.isEmpty, let example {
            Button("入力例で試す", action: example).accessibilityIdentifier("startExample")
          }
        }
      }
    }
    .navigationTitle(filter == nil ? "締切" : "締切日の用件")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("締切を追加", systemImage: "plus", action: add).accessibilityIdentifier("addDeadline")
      }
    }
  }

  @ViewBuilder private func rows(_ entries: [Deadline]) -> some View {
    ForEach(entries) { deadline in
      NavigationLink(value: deadline.id) {
        Label {
          VStack(alignment: .leading, spacing: 3) {
            Text(deadline.title).font(.headline)
            Text(journal.company(deadline.companyID)?.name ?? "").font(.subheadline)
            Text(JapaneseDate.label(deadline.day, time: deadline.time)).font(.footnote)
          }
        } icon: {
          Image(systemName: "doc.text")
        }
      }
      .accessibilityIdentifier("task." + deadline.title)
      .swipeActions { rowActions(deadline.id) }
      .contextMenu { rowActions(deadline.id) }
    }
  }

  @ViewBuilder private func rowActions(_ id: UUID) -> some View {
    Button("完了にする", systemImage: "checkmark") { complete(id) }
    Button("編集", systemImage: "pencil") { edit(id) }
  }
}

struct DeadlineDetail: View {
  let entry: Deadline
  let company: String
  let edit: () -> Void
  let complete: () -> Void

  var body: some View {
    List {
      Section {
        Label(company, systemImage: "briefcase")
        LabeledContent {
          Text(JapaneseDate.label(entry.day)).foregroundStyle(Color(uiColor: .label))
        } label: {
          Label("締切日", systemImage: "calendar")
        }
        LabeledContent {
          Text(entry.time.map(JapaneseDate.clock) ?? "指定なし").foregroundStyle(Color(uiColor: .label))
        } label: {
          Label("時刻", systemImage: "clock")
        }
      } header: {
        Text(entry.title).font(.largeTitle.bold()).foregroundStyle(Color(uiColor: .label)).textCase(
          nil
        )
        .accessibilityIdentifier("deadlineTitle")
      }
      Section {
        LabeledContent {
          Text(entry.notify ? "前日 19:00" : "オフ").foregroundStyle(Color(uiColor: .label))
        } label: {
          Label("前夜の通知", systemImage: "bell")
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("用件の詳細").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button("編集", systemImage: "pencil", action: edit).accessibilityIdentifier("editDeadline")
        Button("完了にする", systemImage: "checkmark", action: complete)
          .accessibilityIdentifier("completeDeadline")
      }
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
      List {
        Section("19:00") {
          Button(action: open) {
            Label {
              VStack(alignment: .leading) {
                Text("明日の締切は\(count)件").font(.headline)
                Text(JapaneseDate.label(day)).font(.subheadline)
              }
            } icon: {
              Image(systemName: "bell")
            }
          }
          .accessibilityIdentifier("openNotification")
        }
      }
      .navigationTitle("前夜の通知見本")
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
    }
    .presentationDetents([.medium, .large])
  }
}
