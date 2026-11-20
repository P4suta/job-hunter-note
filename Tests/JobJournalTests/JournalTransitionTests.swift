import Foundation
import Testing

@testable import JobJournal

private enum Change: CaseIterable { case move, silence, complete, reopen }

@Suite struct JournalTransitionTests {
  @Test func editCompleteAndReloadSequencesPreserveHistoryAndReminderMembership() throws {
    let original = try day("2026-12-04")
    let moved = try day("2026-12-05")
    let now = try day("2026-12-02").date(in: tokyo)
    for first in Change.allCases {
      for second in Change.allCases {
        for third in Change.allCases {
          let sequence = [first, second, third]
          var journal = Journal()
          let a = try journal.addEmployer("A社", stage: .interview)
          let b = try journal.addEmployer("B社", stage: .waiting)
          let record = try journal.save(draft("A社", "提出"))
          let other = try journal.save(draft("B社", "提出"))
          var company = a
          var due = original
          var notify = true
          var completed: Date?
          for (step, action) in sequence.enumerated() {
            let timestamp = now.addingTimeInterval(Double(step + 1))
            switch action {
            case .move, .silence:
              let editing = DeadlineDraft(
                company: action == .move || company == b ? "B社" : "A社", title: "提出",
                day: action == .move ? moved : due, notify: action == .silence ? false : notify)
              if completed == nil {
                #expect(try journal.save(editing, editing: record) == record)
                if action == .move {
                  company = b
                  due = moved
                }
                if action == .silence { notify = false }
              } else {
                let previous = journal
                #expect(throws: JournalError.alreadyCompleted) {
                  try journal.save(editing, editing: record)
                }
                #expect(journal == previous)
              }
            case .complete:
              try journal.complete(record, at: timestamp)
              if completed == nil { completed = timestamp }
            case .reopen:
              journal = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(journal))
            }
            let actual = try #require(journal.deadline(record))
            #expect(actual.companyID == company && actual.day == due && actual.notify == notify)
            #expect(actual.completedAt == completed)
            #expect(journal.open().map(\.id).contains(other))
            #expect(journal.open(on: due).map(\.id).contains(record) == (completed == nil))
            for id in [a, b] {
              let expected: [UUID] = completed != nil && id == company ? [record] : []
              #expect(journal.history(for: id).map(\.id) == expected)
            }
            var dates = [original: 1]
            if notify && completed == nil { dates[due, default: 0] += 1 }
            let plans = ReminderPlan.pending(in: journal, now: now, calendar: tokyo)
            #expect(Dictionary(uniqueKeysWithValues: plans.map { ($0.day, $0.count) }) == dates)
            #expect(
              journal.company(a)?.stage == .interview && journal.company(b)?.stage == .waiting)
          }
        }
      }
    }
  }

  @Test func ordersTimedUntimedAndCompletedItemsIndependentlyPerCompany() throws {
    var journal = Journal()
    let a = try journal.addEmployer("A社")
    let b = try journal.addEmployer("B社")
    let firstDay = try day()
    let secondDay = try day("2026-12-05")
    let first = try journal.save(DeadlineDraft(company: "A社", title: "X", day: firstDay, time: 0))
    let same = try journal.save(DeadlineDraft(company: "B社", title: "X", day: firstDay, time: 0))
    let laterTitle = try journal.save(
      DeadlineDraft(company: "A社", title: "Z", day: firstDay, time: 0))
    let late = try journal.save(DeadlineDraft(company: "A社", title: "A", day: firstDay, time: 1439))
    let untimed = try journal.save(DeadlineDraft(company: "A社", title: "A", day: firstDay))
    let tomorrow = try journal.save(
      DeadlineDraft(company: "A社", title: "A", day: secondDay, time: 0))
    let ties = [first, same].sorted { $0.uuidString < $1.uuidString }
    #expect(journal.open().map(\.id) == ties + [laterTitle, late, untimed, tomorrow])
    let ordered = journal.open()
    for (i, left) in ordered.enumerated() {
      for (j, right) in ordered.enumerated() {
        #expect(left.isDueBefore(right) == (i < j))
      }
    }
    let time = try firstDay.date(in: tokyo)
    for id in [first, late, same] { try journal.complete(id, at: time) }
    try journal.complete(untimed, at: time.addingTimeInterval(1))
    let historyTies = [first, late].sorted { $0.uuidString > $1.uuidString }
    #expect(journal.history(for: a).map(\.id) == [untimed] + historyTies)
    #expect(journal.history(for: b).map(\.id) == [same])
    #expect(journal.open(on: firstDay).map(\.id) == [laterTitle])
    for stage in Stage.allCases {
      try journal.setStage(stage, for: a)
      let copy = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(journal))
      #expect(copy.company(a)?.stage == stage && copy.company(b)?.stage == .documents)
    }
  }
}
