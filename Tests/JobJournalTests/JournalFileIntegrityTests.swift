import Foundation
import Testing

@testable import JobJournal

enum InvalidRecord: CaseIterable {
  case duplicateEmployerID, duplicateEmployerName, equivalentEmployerName, duplicateDeadlineID
  case missingEmployer, blankEmployer, blankTitle, earlyTime, lateTime, invalidDate, unknownStage
}

private struct StoredRecords {
  let first = "00000000-0000-4000-8000-000000000001"
  let second = "00000000-0000-4000-8000-000000000002"
  var employers: [[String: Any]]
  var tasks: [[String: Any]]

  init() {
    employers = [
      ["id": first, "name": "A社", "stage": "documents"],
      ["id": second, "name": "B社", "stage": "waiting"],
    ]
    tasks = [
      [
        "id": "00000000-0000-4000-8000-000000000003", "companyID": first, "title": "面接",
        "day": "2028-02-29", "time": 0, "notify": true,
      ],
      [
        "id": "00000000-0000-4000-8000-000000000004", "companyID": second, "title": "資料",
        "day": "2028-03-01", "time": 1439, "notify": false, "completedAt": 0,
      ],
    ]
  }

  mutating func corrupt(_ field: InvalidRecord) {
    switch field {
    case .duplicateEmployerID:
      employers[1]["id"] = first
      tasks[1]["companyID"] = first
    case .duplicateEmployerName: employers[1]["name"] = "A社"
    case .equivalentEmployerName: employers[1]["name"] = " A社\n"
    case .duplicateDeadlineID: tasks[1]["id"] = tasks[0]["id"]
    case .missingEmployer: tasks[1]["companyID"] = tasks[0]["id"]
    case .blankEmployer: employers[1]["name"] = "　 "
    case .blankTitle: tasks[1]["title"] = "\n"
    case .earlyTime: tasks[1]["time"] = -1
    case .lateTime: tasks[1]["time"] = 1440
    case .invalidDate: tasks[1]["day"] = "2100-02-29"
    case .unknownStage: employers[1]["stage"] = "unknown"
    }
  }

  func data() throws -> Data {
    try JSONSerialization.data(withJSONObject: ["companies": employers, "deadlines": tasks])
  }
}

@Suite struct JournalFileIntegrityTests {
  @Test func concurrentFileOperationsOnlyReadCompleteSnapshotsInNestedDirectories() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = JournalFile(url: directory.appending(path: "support/journal/records.json"))
    var first = Journal()
    try first.save(draft("A社", "一次面接"))
    var second = first
    let task = try second.save(draft("B社", "二次面接"))
    try second.complete(task, at: Date(timeIntervalSince1970: 1234))
    let snapshots = [first, second]
    try file.write(first)
    try await withThrowingTaskGroup(of: Void.self) { group in
      for snapshot in snapshots {
        group.addTask {
          for _ in 0..<12 { try file.write(snapshot) }
        }
      }
      for _ in 0..<2 {
        group.addTask {
          for _ in 0..<24 {
            let actual = try file.load()
            #expect(snapshots.contains(actual))
          }
        }
      }
      try await group.waitForAll()
    }
    let final = try file.load()
    #expect(snapshots.contains(final))
  }

  @Test(arguments: InvalidRecord.allCases)
  func decodingRejectsInconsistentRecordsWithoutRewritingTheFile(_ field: InvalidRecord) throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var records = StoredRecords()
    records.corrupt(field)
    let bytes = try records.data()
    try bytes.write(to: url)
    #expect(throws: (any Error).self) { try JSONDecoder().decode(Journal.self, from: bytes) }
    #expect(throws: (any Error).self) { try JournalFile(url: url).load() }
    #expect(try Data(contentsOf: url) == bytes)
  }

  @Test func readsExistingRecordsAndPreservesEmployerIdentityAfterTrimming() throws {
    var records = StoredRecords()
    records.employers[1]["name"] = " B社　"
    var journal = try JSONDecoder().decode(Journal.self, from: records.data())
    let id = try #require(UUID(uuidString: records.second))
    #expect(try journal.addEmployer("B社") == id)
    #expect(journal.companies.count == 2)
    #expect(journal.company(id)?.stage == .waiting)
    #expect(journal.history(for: id).map(\.title) == ["資料"])
    #expect(journal.open().map(\.time) == [0])
    let reopened = try JSONDecoder().decode(Journal.self, from: JSONEncoder().encode(journal))
    #expect(reopened == journal)
  }
}
