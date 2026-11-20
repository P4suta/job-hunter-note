import JobJournal
import SwiftUI

struct EmployerList: View {
  let journal: Journal
  @Binding var selection: UUID?
  let add: () -> Void
  var body: some View {
    List(selection: $selection) {
      Section("登録済み \(journal.companies.count)社") {
        if journal.companies.isEmpty { Text("登録した応募先はまだありません。") }
        ForEach(
          journal.companies.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
          }
        ) { company in
          NavigationLink(value: company.id) {
            Label {
              VStack(alignment: .leading, spacing: 4) {
                Text(company.name).font(.headline)
                Text(company.stage.label).font(.subheadline)
              }
            } icon: {
              Image(systemName: "briefcase")
            }
          }.accessibilityIdentifier("employer." + company.name)
        }
      }
      Section("サポート情報") {
        Link("サポート", destination: URL(string: "https://job-hunter-note.yasunobu.dev/support/")!)
        Link(
          "プライバシーポリシー", destination: URL(string: "https://job-hunter-note.yasunobu.dev/privacy/")!)
      }
    }.listStyle(.insetGrouped).navigationTitle("応募先")
      .toolbar {
        Button(action: add) { Label("応募先を追加", systemImage: "plus") }
          .accessibilityIdentifier("addEmployer")
      }
  }
}

struct EmployerDetail: View {
  let employer: Employer
  let history: [Deadline]
  let changeStage: () -> Void
  var body: some View {
    List {
      Section {
        Button(action: changeStage) {
          LabeledContent {
            Text(employer.stage.label).foregroundStyle(Color(uiColor: .label))
          } label: {
            Label("選考段階", systemImage: "list.bullet")
          }
        }
        .accessibilityLabel("選考段階、" + employer.stage.label)
        .accessibilityIdentifier("changeStage")
      } header: {
        Text(employer.name).font(.largeTitle.bold()).foregroundStyle(Color(uiColor: .label))
          .textCase(nil)
      }
      Section("提出履歴") {
        if history.isEmpty { Text("提出履歴はまだありません。") }
        ForEach(history) { item in
          if let date = item.completedAt {
            Label {
              VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline)
                Text(JapaneseDate.label(Day(date, calendar: .current)) + " 提出").font(.subheadline)
              }
            } icon: {
              Image(systemName: "checkmark.circle")
            }
            .accessibilityElement(children: .combine).accessibilityIdentifier(
              "history." + item.title)
          }
        }
      }
    }.listStyle(.insetGrouped).navigationTitle("応募先の詳細").navigationBarTitleDisplayMode(.inline)
  }
}

struct EmployerEditor: View {
  let store: JournalStore
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var stage = Stage.documents
  @State private var saveFailed = false
  var body: some View {
    NavigationStack {
      Form {
        Section("企業名") {
          TextField("企業名を入力", text: $name).submitLabel(.done).accessibilityIdentifier(
            "employerName")
        }
        Picker("選考段階", selection: $stage) {
          ForEach(Stage.allCases, id: \.self) { Text($0.label).tag($0) }
        }
      }.navigationTitle("応募先を追加").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("保存") {
              do {
                try store.change { try $0.addEmployer(name, stage: stage) }
                dismiss()
              } catch { saveFailed = true }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
              .accessibilityIdentifier("saveEmployer")
          }
        }
        .alert("応募先を保存できませんでした", isPresented: $saveFailed) { Button("閉じる") {} }
    }
  }
}

struct StageEditor: View {
  let store: JournalStore
  let id: UUID
  @Environment(\.dismiss) private var dismiss
  @State private var saveFailed = false
  var body: some View {
    NavigationStack {
      List(Stage.allCases, id: \.self) { stage in
        Button {
          do {
            try store.change { try $0.setStage(stage, for: id) }
            dismiss()
          } catch { saveFailed = true }
        } label: {
          HStack {
            Text(stage.label)
            Spacer()
            if store.journal.company(id)?.stage == stage { Image(systemName: "checkmark") }
          }
        }.accessibilityIdentifier("stage." + stage.rawValue)
          .accessibilityAddTraits(store.journal.company(id)?.stage == stage ? .isSelected : [])
      }.navigationTitle("選考段階を変更").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } } }
        .alert("選考段階を保存できませんでした", isPresented: $saveFailed) { Button("閉じる") {} }
    }.presentationDetents([.medium, .large])
  }
}
