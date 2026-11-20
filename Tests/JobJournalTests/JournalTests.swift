import Foundation
import Testing

@testable import JobJournal

let tokyo: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
  return calendar
}()

func day(_ key: String = "2026-12-04") throws -> Day {
  try #require(Day(key: key))
}

func draft(
  _ company: String = "B社", _ title: String = "エントリーシート提出",
  _ key: String = "2026-12-04", time: Int? = nil, notify: Bool = true
) throws -> DeadlineDraft {
  try DeadlineDraft(company: company, title: title, day: day(key), time: time, notify: notify)
}

@Suite struct JournalTests {
  @Test func validatesCalendarDatesAndClassifiesCivilDays() throws {
    #expect(Day(key: "2026-02-29") == nil)
    #expect(Day(key: "2024-02-29") != nil)
    #expect(Day(key: "2026-2-03") == nil)
    let today = try day("2026-12-03")
    #expect(try day("2026-12-02").bucket(on: today) == .overdue)
    #expect(today.bucket(on: today) == .today)
    #expect(try day().bucket(on: today) == .future)
    #expect(Day(try today.date(in: tokyo), calendar: tokyo) == today)
  }

  @Test func registrationEditingAndHistoryUseOneEmployerIdentity() throws {
    var journal = Journal()
    let a = try journal.save(draft("A社", "適性検査"))
    let b = try journal.save(draft(" B社 ", " エントリーシート提出 ", time: 1020))
    let company = try #require(journal.companies.first { $0.name == "B社" })
    #expect(try journal.addEmployer("B社") == company.id)
    #expect(journal.companies.count == 2)
    #expect(journal.open().map(\.id) == [b, a])
    #expect(journal.open().first?.title == "エントリーシート提出")
    #expect(try journal.save(draft("B社", "更新", "2026-12-05"), editing: b) == b)
    #expect(try journal.open(on: day()).map(\.id) == [a])
    let submitted = try day("2026-12-03").date(in: tokyo)
    try journal.complete(b, at: submitted)
    try journal.complete(b, at: submitted.addingTimeInterval(800))
    try journal.setStage(.waiting, for: company.id)
    #expect(journal.history(for: company.id).map(\.completedAt) == [submitted])
    #expect(journal.companies.first { $0.id == company.id }?.stage == .waiting)
    #expect(journal.open().map(\.id) == [a])
    #expect(throws: JournalError.self) { try journal.save(draft(), editing: b) }
  }

  @Test func invalidInputNeverCreatesAnEmployerOrChangesAnotherRecord() throws {
    var journal = Journal()
    for invalid in [
      try draft(" ", "件"), try draft("B社", "\n"), try draft(time: 1440), try draft(time: -1),
    ] {
      #expect(throws: JournalError.self) { try journal.save(invalid) }
    }
    #expect(throws: JournalError.self) { try journal.save(draft(), editing: UUID()) }
    #expect(throws: JournalError.self) { try journal.setStage(.waiting, for: UUID()) }
    #expect(throws: JournalError.self) { try journal.complete(UUID(), at: Date()) }
    #expect(journal == Journal())
  }

  @Test func persistsTheWholeChangeAndReportsCorruption() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("records.json")
    let file = JournalFile(url: url)
    #expect(try file.load() == Journal())
    var journal = Journal()
    let saved = try journal.save(draft())
    try journal.complete(saved, at: Date(timeIntervalSince1970: 1_796_281_200))
    try file.write(journal)
    #expect(try JournalFile(url: url).load() == journal)
    let broken = Data("invalid".utf8)
    try broken.write(to: url)
    #expect(throws: (any Error).self) { try file.load() }
    #expect(try Data(contentsOf: url) == broken)
  }
}
