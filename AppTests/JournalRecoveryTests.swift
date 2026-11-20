import Foundation
import JobJournal
import XCTest

@testable import JobHunterNote

@MainActor
final class JournalRecoveryTests: XCTestCase {
  func testUnreadableStorePreservesLastGoodStateAndRecoversFromDisk() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = JournalFile(url: directory.appending(path: "journal.json"))
    let store = JournalStore(file: file)
    let employer = try store.change { try $0.addEmployer("A社", stage: .interview) }
    let good = try Data(contentsOf: file.url)
    let damaged = Data("{".utf8)
    try damaged.write(to: file.url)
    store.reload()
    XCTAssertTrue(store.couldNotLoad)
    XCTAssertEqual(store.journal.company(employer)?.stage, .interview)
    let restarted = JournalStore(file: file)
    for instance in [store, restarted] {
      XCTAssertTrue(instance.couldNotLoad)
      XCTAssertThrowsError(try instance.change { try $0.setStage(.waiting, for: employer) })
      XCTAssertEqual(try Data(contentsOf: file.url), damaged)
    }
    try good.write(to: file.url)
    restarted.reload()
    XCTAssertFalse(restarted.couldNotLoad)
    XCTAssertThrowsError(
      try restarted.change { journal in
        try journal.addEmployer("B社")
        try journal.complete(UUID(), at: Date())
      })
    XCTAssertEqual(try Data(contentsOf: file.url), good)
    XCTAssertEqual(restarted.journal.companies.map(\.name), ["A社"])
    try restarted.change { try $0.setStage(.waiting, for: employer) }
    XCTAssertEqual(try file.load().company(employer)?.stage, .waiting)
  }

  func testSamplesAreIndependentOfEachOtherAndTheLiveFile() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let live = JournalStore(file: JournalFile(url: directory.appending(path: "journal.json")))
    try live.change { try $0.addEmployer("本番") }
    let sample = try JournalStore.example(calendar: .current)
    let first = try XCTUnwrap(sample.journal.open().first)
    try sample.change { try $0.complete(first.id, at: XCTUnwrap(sample.exampleDate)) }
    XCTAssertTrue(sample.journal.open().isEmpty)
    let reopened = try JournalStore.example(calendar: .current)
    XCTAssertEqual(reopened.journal.open().map(\.title), ["適性検査"])
    live.reload()
    XCTAssertEqual(live.journal.companies.map(\.name), ["本番"])
    XCTAssertTrue(live.journal.deadlines.isEmpty)
  }
}
