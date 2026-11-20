import JobJournal
import SwiftUI

struct EmployerList: View {
  let journal: Journal
  @Binding var selection: UUID?
  let add: () -> Void
  var body: some View {
    List(selection: $selection) {
      Text("登録済み \(journal.companies.count)社").font(.subheadline)
      if journal.companies.isEmpty {
        Text("登録した応募先はまだありません。").padding(.vertical)
      }
      ForEach(
        journal.companies.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      ) { company in
        NavigationLink(value: company.id) {
          HStack(alignment: .top, spacing: 12) {
            DesignIcon("BriefcaseBusiness")
            VStack(alignment: .leading, spacing: 4) {
              Text(company.name).font(.headline)
              Text(company.stage.label).font(.subheadline)
            }
          }.padding(.vertical, 4)
        }.accessibilityIdentifier("employer." + company.name)
      }
      Section {
        Link("サポート", destination: URL(string: "https://job-hunter-note.yasunobu.dev/support/")!)
        Link(
          "プライバシーポリシー", destination: URL(string: "https://job-hunter-note.yasunobu.dev/privacy/")!)
      }
    }.listStyle(.plain).navigationTitle("応募先")
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
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(employer.name).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
        Button(action: changeStage) {
          InvertedCard {
            HStack {
              VStack(alignment: .leading, spacing: 6) {
                Text("選考段階").font(.subheadline)
                Text(employer.stage.label).font(.title2.bold())
              }
              Spacer()
              DesignIcon("ArrowRightLight")
            }
          }
        }.buttonStyle(.plain).accessibilityLabel("選考段階、" + employer.stage.label)
          .accessibilityIdentifier("changeStage")
        Text("提出履歴").font(.title2.bold()).accessibilityAddTraits(.isHeader)
        Divider()
        if history.isEmpty { Text("提出履歴はまだありません。") }
        ForEach(history) { item in
          if let date = item.completedAt {
            DetailValue(
              label: JapaneseDate.label(Day(date, calendar: .current)) + " 提出", value: item.title
            )
            .accessibilityElement(children: .combine).accessibilityIdentifier(
              "history." + item.title)
            Divider()
          }
        }
      }.padding().frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
    }.navigationTitle("応募先の詳細").navigationBarTitleDisplayMode(.inline)
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
        .toolbar { Button("キャンセル") { dismiss() } }
        .alert("選考段階を保存できませんでした", isPresented: $saveFailed) { Button("閉じる") {} }
    }.presentationDetents([.medium, .large])
  }
}
