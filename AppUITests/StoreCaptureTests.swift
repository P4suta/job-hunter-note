import JobJournal
import XCTest

@MainActor
final class StoreCaptureTests: XCTestCase {
  let app = XCUIApplication()
  let files = FileManager.default
  var captureFolder: URL { URL.documentsDirectory.appending(path: "StoreCapture") }

  func launchJournal() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .portrait
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    func date(_ offset: Int) throws -> Date {
      try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: today))
    }
    var journal = Journal()
    for (employer, stage) in [
      ("あおば出版", Stage.interview), ("汐見工房", .assessment), ("北野企画", .documents),
      ("南町書店", .waiting),
    ] {
      try journal.addEmployer(employer, stage: stage)
    }
    for (company, title, offset, time) in [
      ("あおば出版", "一次面接", 0, 14 * 60), ("汐見工房", "適性検査", 1, 17 * 60),
      ("北野企画", "作品集の提出", 3, 18 * 60), ("南町書店", "面談日程の返信", 4, 12 * 60),
    ] {
      try journal.save(
        DeadlineDraft(
          company: company, title: title, day: Day(try date(offset), calendar: calendar), time: time
        ))
    }
    for (title, offset) in [("書類提出", -3), ("履歴書の提出", -5), ("説明会の申込", -8)] {
      let submission = try date(offset)
      let id = try journal.save(
        DeadlineDraft(company: "あおば出版", title: title, day: Day(submission, calendar: calendar)))
      try journal.complete(id, at: submission)
    }
    app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    app.launchEnvironment["JOB_NOTE_TEST_STORE"] = UUID().uuidString
    app.launchEnvironment["JOB_NOTE_TEST_JOURNAL"] = String(
      decoding: try JSONEncoder().encode(journal), as: UTF8.self)
    app.launch()
  }

  func element(_ identifier: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  func capture(_ name: String) throws {
    let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
    guard files.fileExists(atPath: captureFolder.appending(path: "active").path) else { return }
    let ready = captureFolder.appending(path: name + ".ready")
    try Data().write(to: ready, options: .atomic)
    let done = captureFolder.appending(path: name + ".done")
    let acknowledged = NSPredicate { _, _ in FileManager.default.fileExists(atPath: done.path) }
    let response = XCTNSPredicateExpectation(predicate: acknowledged, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [response], timeout: 45), .completed, name)
  }

  func testDeadlineListAndSelectedDetail() throws {
    try launchJournal()
    XCTAssertTrue(element("task.適性検査").waitForExistence(timeout: 8))
    let isPad = UIDevice.current.userInterfaceIdiom == .pad
    if isPad {
      XCUIDevice.shared.orientation = .landscapeLeft
      defer { XCUIDevice.shared.orientation = .portrait }
      try selectDeadline(captureList: false, bothColumns: true)
    } else {
      try selectDeadline(captureList: true, bothColumns: false)
    }
  }

  func selectDeadline(captureList: Bool, bothColumns: Bool) throws {
    if captureList { try capture("deadlines") }
    let row = element("task.一次面接")
    XCTAssertTrue(row.isHittable)
    row.tap()
    let title = element("deadlineTitle")
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertTrue(element("completeDeadline").isHittable)
    if bothColumns {
      XCTAssertGreaterThan(app.frame.width, app.frame.height)
      XCTAssertLessThanOrEqual(row.frame.maxX, title.frame.minX)
    }
    try capture("deadline-detail")
  }

  func testEmployerListAndSubmissionHistory() throws {
    try launchJournal()
    let tab = app.buttons.matching(NSPredicate(format: "label == %@", "応募先")).firstMatch
    XCTAssertTrue(tab.waitForExistence(timeout: 5))
    tab.tap()
    let employer = element("employer.あおば出版")
    XCTAssertTrue(employer.waitForExistence(timeout: 5))
    employer.tap()
    let submission = element("history.書類提出")
    XCTAssertTrue(submission.waitForExistence(timeout: 5))
    XCTAssertTrue(element("changeStage").label.contains("面接"))
    if app.frame.width >= 700 {
      XCTAssertTrue(employer.isHittable)
      XCTAssertLessThanOrEqual(employer.frame.maxX, submission.frame.minX)
    }
    try capture("employers")
  }

  func testCompletingAListRowPreservesAnotherOpenDetail() throws {
    try launchJournal()
    let first = element("task.一次面接")
    let other = element("task.適性検査")
    XCTAssertTrue(first.waitForExistence(timeout: 5))
    let split = app.frame.width >= 700
    if split { first.tap() }
    other.swipeLeft(velocity: .slow)
    if other.exists {
      let swipeCompletion = NSPredicate(
        format: "label == %@ AND identifier != %@", "完了にする", "completeDeadline")
      let action = app.buttons.matching(swipeCompletion).firstMatch
      XCTAssertTrue(action.waitForExistence(timeout: 5), app.debugDescription)
      action.tap()
    }
    XCTAssertTrue(other.waitForNonExistence(timeout: 5))
    XCTAssertTrue(first.isHittable)
    if split { XCTAssertTrue(element("deadlineTitle").isHittable) }
  }
}
