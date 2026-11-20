import JobJournal
import SwiftUI

struct DeadlineEditor: View {
  let store: JournalStore
  let reminders: LocalReminders
  let editing: UUID?
  let returnToList: () -> Void
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @State private var draft: DeadlineDraft
  @State private var saving = false
  @State private var choosingDay = false
  @State private var receipt: Receipt?
  @State private var saveFailed = false
  @FocusState private var focus: Field?
  @State private var choice: Field?

  private enum Field { case company, title }
  private enum Receipt { case off, denied, unavailable }

  init(
    store: JournalStore, reminders: LocalReminders, editing: UUID?, now: Date,
    returnToList: @escaping () -> Void
  ) {
    self.store = store
    self.reminders = reminders
    self.editing = editing
    self.returnToList = returnToList
    if let id = editing, let entry = store.journal.deadline(id) {
      _draft = State(
        initialValue: DeadlineDraft(
          company: store.journal.company(entry.companyID)?.name ?? "",
          title: entry.title, day: entry.day, time: entry.time, notify: entry.notify))
    } else {
      let calendar = Calendar.current
      let date = calendar.date(byAdding: .day, value: 1, to: now) ?? now
      _draft = State(
        initialValue: DeadlineDraft(company: "", title: "", day: Day(date, calendar: calendar)))
    }
  }

  var body: some View {
    NavigationStack {
      if let receipt {
        receiptView(receipt)
      } else {
        Form {
          Section {
            TextField("企業名を入力", text: $draft.company)
              .focused($focus, equals: .company).submitLabel(.done).accessibilityIdentifier(
                "companyField")
            if !store.journal.companies.isEmpty {
              Button("登録済みの企業から選ぶ") {
                focus = nil
                choice = .company
              }
              .accessibilityIdentifier("chooseCompany")
            }
          } header: {
            Label("企業名", image: "BriefcaseBusiness")
          }
          Section {
            TextField("用件を入力", text: $draft.title)
              .focused($focus, equals: .title).submitLabel(.done).accessibilityIdentifier(
                "titleField")
            Button("入力例から選ぶ") {
              focus = nil
              choice = .title
            }
            .accessibilityIdentifier("chooseTitle")
          } header: {
            Label("用件", image: "FileText")
          }
          Section {
            Button {
              focus = nil
              choosingDay.toggle()
            } label: {
              LabeledContent {
                if choosingDay {
                  Text("完了")
                } else {
                  Text(dateBinding.wrappedValue, format: .dateTime.year().month().day())
                }
              } label: {
                Label("締切日", image: "CalendarDays")
              }
            }
            .accessibilityLabel(choosingDay ? "日付の選択を完了" : "締切日")
            .accessibilityValue(
              Text(dateBinding.wrappedValue, format: .dateTime.year().month().day())
            )
            .accessibilityIdentifier(choosingDay ? "confirmDay" : "dueDate")
            if choosingDay {
              DatePicker("締切日", selection: dateBinding, displayedComponents: .date)
                .datePickerStyle(.graphical)
            }
            Toggle(
              isOn: Binding(get: { draft.time != nil }, set: { draft.time = $0 ? 17 * 60 : nil })
            ) {
              Label("時刻を指定", image: "Clock")
            }.accessibilityIdentifier("timeToggle")
            if draft.time != nil {
              DatePicker("締切時刻", selection: timeBinding, displayedComponents: .hourAndMinute)
                .accessibilityIdentifier("dueTime")
            }
          }
          Section {
            Toggle(isOn: $draft.notify) { Label("前夜の通知", image: "Bell") }
              .accessibilityIdentifier("reminderToggle")
          } footer: {
            Text("締切の前日 19:00")
          }
        }
        .onSubmit { focus = nil }
        .navigationDestination(item: $choice) { field in
          switch field {
          case .company:
            List(store.journal.companies.sorted { $0.name < $1.name }) { employer in
              Button(employer.name) {
                draft.company = employer.name
                choice = nil
              }
              .accessibilityIdentifier("existing." + employer.name)
            }.navigationTitle("企業を選択")
          case .title:
            List(["エントリーシート提出", "面接の日程確認", "適性検査"], id: \.self) { title in
              Button(title) {
                draft.title = title
                choice = nil
              }
              .accessibilityIdentifier("example." + title)
            }.navigationTitle("用件の入力例")
          }
        }
        .navigationTitle(editing == nil ? "締切を追加" : "締切を編集").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("キャンセル") { dismiss() }.disabled(saving).accessibilityIdentifier("cancelEditor")
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("保存") { Task { await save() } }
              .disabled(
                saving
                  || [draft.company, draft.title].contains {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  }
              )
              .accessibilityIdentifier("saveDeadline")
          }
        }
      }
    }
    .interactiveDismissDisabled(saving)
    .alert("締切を保存できませんでした", isPresented: $saveFailed) { Button("閉じる") {} }
  }

  private var dateBinding: Binding<Date> {
    Binding(
      get: { (try? draft.day.date(in: .current)) ?? Date() },
      set: { draft.day = Day($0, calendar: .current) })
  }

  private var timeBinding: Binding<Date> {
    Binding(
      get: {
        let m = draft.time ?? 1020
        return Calendar.current.date(
          bySettingHour: m / 60, minute: m % 60, second: 0, of: dateBinding.wrappedValue)
          ?? dateBinding.wrappedValue
      },
      set: {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
        draft.time = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
      })
  }

  private func save() async {
    guard !saving else { return }
    saving = true
    defer { saving = false }
    focus = nil
    do { try store.change { try $0.save(draft, editing: editing) } } catch {
      saveFailed = true
      return
    }
    guard draft.notify else {
      receipt = .off
      return
    }
    if store.exampleDate == nil {
      do {
        guard try await reminders.requestAccess() else {
          receipt = .denied
          return
        }
        try await reminders.refresh(
          journal: store.journal, now: Date(), calendar: Day.gregorian(in: .current))
      } catch {
        receipt = .unavailable
        return
      }
    }
    dismiss()
  }

  private func receiptView(_ receipt: Receipt) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text("締切を保存しました").font(.largeTitle.bold())
        InvertedCard {
          VStack(alignment: .leading, spacing: 8) {
            Text(draft.company).font(.subheadline)
            Text(draft.title).font(.headline)
            Text(JapaneseDate.label(draft.day, time: draft.time))
          }
        }
        switch receipt {
        case .off:
          Label("前夜の通知はオフです", image: "BellOff")
        case .denied:
          Text("端末の設定で通知がオフになっています。")
          Button("通知設定を開く") {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
              openURL(url)
            }
          }
        case .unavailable:
          Text("前夜の通知を予約できませんでした。アプリを開き直すと再試行します。")
        }
        Text("締切は一覧から確認できます。")
      }.frame(maxWidth: 680, alignment: .leading).padding()
    }.navigationTitle("登録完了").navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .bottom) {
        PrimaryAction(title: "締切一覧へ", icon: "ArrowRightLight", action: returnToList)
          .accessibilityIdentifier("closeReceipt").frame(maxWidth: 680).padding()
      }
  }
}
