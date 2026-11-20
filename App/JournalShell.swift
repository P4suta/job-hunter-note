import JobJournal
import SwiftUI

enum JournalTab: Hashable { case deadlines, employers }

private enum JournalSheet: Identifiable {
  case deadline(UUID?)
  case employer
  case stage(UUID)
  case notice(ReminderPlan)
  var id: String {
    switch self {
    case .deadline(let id): "deadline." + (id?.uuidString ?? "add")
    case .employer: "employer"
    case .stage(let id): "stage." + id.uuidString
    case .notice(let plan): "notice." + plan.day.key
    }
  }
}

struct JournalShell: View {
  let store: JournalStore
  let reminders: LocalReminders
  var router: NotificationRouter?
  var closeExample: (() -> Void)?
  @Environment(\.scenePhase) private var phase
  @Environment(\.dynamicTypeSize) private var textSize
  @State private var tab = JournalTab.deadlines
  @State private var taskID: UUID?
  @State private var employerID: UUID?
  @State private var taskColumn: NavigationSplitViewColumn = .sidebar
  @State private var companyColumn: NavigationSplitViewColumn = .sidebar
  @State private var filter: Day?
  @State private var sheet: JournalSheet?
  @State private var example: JournalStore?
  @State private var clock = Date()
  @State private var warning: String?

  private var now: Date { store.exampleDate ?? clock }
  private var today: Day { Day(now, calendar: .current) }

  var body: some View {
    Group {
      if store.couldNotLoad {
        ContentUnavailableView {
          Label("記録を開けませんでした", systemImage: "exclamationmark.folder")
        } actions: {
          Button("読み込み直す") { store.reload() }
        }
      } else {
        tabs
      }
    }
    .onChange(of: phase, initial: true) { _, phase in
      if phase == .active { refreshClock() }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
    ) { _ in refreshClock() }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
      refreshClock()
    }
    .onChange(of: store.journal) { _, _ in reconcile() }
    .onChange(of: router?.destination?.id, initial: true) { _, _ in
      guard let day = router?.destination?.day else { return }
      example = nil
      showDeadlines(on: day)
      router?.destination = nil
    }
    .sheet(item: $sheet) { sheet in
      switch sheet {
      case .deadline(let id):
        DeadlineEditor(store: store, reminders: reminders, editing: id, now: now) {
          showDeadlines(on: nil)
        }
      case .employer: EmployerEditor(store: store)
      case .stage(let id): StageEditor(store: store, id: id)
      case .notice(let plan):
        ExampleNotice(day: plan.day, count: plan.count) {
          showDeadlines(on: plan.day)
        }
      }
    }
    .fullScreenCover(
      isPresented: Binding(get: { example != nil }, set: { if !$0 { example = nil } })
    ) {
      if let example {
        JournalShell(store: example, reminders: reminders, closeExample: { self.example = nil })
      }
    }
    .alert(
      "操作を完了できませんでした",
      isPresented: Binding(get: { warning != nil }, set: { if !$0 { warning = nil } })
    ) {
      Button("閉じる") { warning = nil }
    } message: {
      Text(warning ?? "")
    }
  }

  private var tabs: some View {
    TabView(selection: $tab) {
      Tab("締切", image: "CalendarDays", value: JournalTab.deadlines) { deadlineSplit }
        .accessibilityIdentifier("tabDeadlines")
      Tab("応募先", image: "BriefcaseBusiness", value: JournalTab.employers) { employerSplit }
        .accessibilityIdentifier("tabEmployers")
    }.tabViewStyle(.tabBarOnly)
  }

  private var deadlineSplit: some View {
    NavigationSplitView(preferredCompactColumn: $taskColumn) {
      deadlineList.toolbar { exampleToolbar }
    } detail: {
      selectedDeadline
    }
    .navigationSplitViewStyle(.balanced)
  }

  private var deadlineList: DeadlineList {
    let offer: (() -> Void)? = closeExample == nil ? { startExample() } : nil
    return DeadlineList(
      journal: store.journal, today: today, filter: filter, selection: $taskID,
      add: { sheet = .deadline(nil) }, clearFilter: { filter = nil }, example: offer)
  }

  @ViewBuilder private var selectedDeadline: some View {
    if let id = taskID, let entry = store.journal.deadline(id), entry.completedAt == nil {
      DeadlineDetail(
        entry: entry, company: store.journal.company(entry.companyID)?.name ?? "",
        edit: { sheet = .deadline(id) }, complete: { complete(id) })
    } else {
      ContentUnavailableView("用件を選択", systemImage: "list.clipboard")
    }
  }

  private var employerSplit: some View {
    NavigationSplitView(preferredCompactColumn: $companyColumn) {
      EmployerList(journal: store.journal, selection: $employerID, add: { sheet = .employer })
        .toolbar { if closeExample != nil { exitButton } }
    } detail: {
      if let id = employerID, let employer = store.journal.company(id) {
        EmployerDetail(employer: employer, history: store.journal.history(for: id)) {
          sheet = .stage(id)
        }
      } else {
        ContentUnavailableView("応募先を選択", systemImage: "briefcase")
      }
    }.navigationSplitViewStyle(.balanced)
  }

  @ToolbarContentBuilder private var exampleToolbar: some ToolbarContent {
    if closeExample != nil {
      exitButton
      ToolbarItem(placement: .topBarTrailing) {
        let calendar = Day.gregorian(in: .current)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now).map {
          Day($0, calendar: calendar)
        }
        let plan = ReminderPlan.pending(in: store.journal, now: now, calendar: calendar).first {
          $0.day == tomorrow
        }
        Button {
          if let plan { sheet = .notice(plan) }
        } label: {
          Label("前夜の通知を見る", image: "Bell")
        }.disabled(plan == nil).accessibilityIdentifier("previewNotification")
      }
    }
  }

  private var exitButton: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button {
        closeExample?()
      } label: {
        if textSize.isAccessibilitySize {
          Label("入力例を閉じる", systemImage: "xmark").labelStyle(.iconOnly)
        } else {
          Text("入力例を閉じる")
        }
      }.accessibilityIdentifier("exitExample")
    }
  }

  private func startExample() {
    do { example = try JournalStore.example(calendar: .current) } catch {
      warning = "入力例を開けませんでした。"
    }
  }

  private func complete(_ id: UUID) {
    do {
      try store.change { try $0.complete(id, at: store.exampleDate ?? Date()) }
      taskID = nil
      taskColumn = .sidebar
    } catch { warning = "記録を保存できませんでした。もう一度お試しください。" }
  }

  private func showDeadlines(on day: Day?) {
    sheet = nil
    taskID = nil
    taskColumn = .sidebar
    filter = day
    tab = .deadlines
  }

  private func refreshClock() {
    clock = Date()
    reconcile()
  }

  private func reconcile() {
    guard store.exampleDate == nil, !store.couldNotLoad else { return }
    Task {
      do {
        try await reminders.refresh(
          journal: store.journal, now: Date(), calendar: Day.gregorian(in: .current))
      } catch { warning = "前夜の通知を予約できませんでした。アプリを開き直すと再試行します。" }
    }
  }
}
