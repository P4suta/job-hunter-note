import Foundation
import JobJournal
import Observation

@MainActor @Observable
final class JournalStore {
  private(set) var journal = Journal()
  private(set) var couldNotLoad = false
  let file: JournalFile?
  let exampleDate: Date?

  init(file: JournalFile) {
    self.file = file
    exampleDate = nil
    reload()
  }

  private init(example: Journal, date: Date) {
    file = nil
    journal = example
    exampleDate = date
  }

  static func onDevice() -> JournalStore {
    var folder = URL.applicationSupportDirectory
    #if DEBUG
      if let value = ProcessInfo.processInfo.environment["JOB_NOTE_TEST_STORE"],
        let id = UUID(uuidString: value)
      {
        folder.append(path: "UITests/" + id.uuidString)
      }
    #endif
    return JournalStore(file: JournalFile(url: folder.appending(path: "journal.json")))
  }

  static func example(calendar: Calendar) throws -> JournalStore {
    guard let today = Day(key: "2026-12-03"), let tomorrow = Day(key: "2026-12-04") else {
      throw JournalError.invalidDay
    }
    var journal = Journal()
    _ = try journal.addEmployer("A社", stage: .assessment)
    _ = try journal.addEmployer("B社")
    _ = try journal.save(DeadlineDraft(company: "A社", title: "適性検査", day: tomorrow))
    return try JournalStore(example: journal, date: today.date(in: calendar))
  }

  func reload() {
    guard let file else { return }
    do {
      journal = try file.load()
      couldNotLoad = false
    } catch {
      couldNotLoad = true
    }
  }

  @discardableResult
  func change<T>(_ apply: (inout Journal) throws -> T) throws -> T {
    guard !couldNotLoad else { throw JournalError.invalidFile }
    var candidate = journal
    let result = try apply(&candidate)
    try file?.write(candidate)
    journal = candidate
    return result
  }
}
