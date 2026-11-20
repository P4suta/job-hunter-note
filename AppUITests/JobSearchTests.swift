import XCTest

@MainActor
final class JobSearchTests: XCTestCase {
  let app = XCUIApplication()

  private func configure() {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .portrait
    app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    app.launchEnvironment["JOB_NOTE_TEST_STORE"] = UUID().uuidString
  }

  func control(_ name: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: name).firstMatch
  }

  private func selectTab(_ title: String) {
    let tab = app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    XCTAssertTrue(tab.waitForExistence(timeout: 5), title)
    tab.tap()
  }

  func tap(_ name: String) {
    let element = control(name)
    if !element.waitForExistence(timeout: 2) || !element.isHittable {
      if let form = app.collectionViews.allElementsBoundByIndex.last {
        for direction in [true, false] {
          for _ in 0..<6 {
            if element.exists && element.isHittable { break }
            let top = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.36))
            let bottom = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.64))
            let start = direction ? bottom : top
            start.press(forDuration: 0.07, thenDragTo: direction ? top : bottom)
          }
          if element.exists && element.isHittable { break }
        }
      }
    }
    XCTAssertTrue(element.exists && element.isHittable, "Missing \(name)\n\(app.debugDescription)")
    if element.elementType == .switch, let toggle = element.switches.allElementsBoundByIndex.last {
      toggle.tap()
    } else {
      element.tap()
    }
  }

  func type(_ value: String, into name: String) {
    tap(name)
    let field = control(name)
    field.typeText(value)
    let entered = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value CONTAINS %@", value), object: field)
    XCTAssertEqual(XCTWaiter.wait(for: [entered], timeout: 10), .completed, name)
    let keyboard = app.keyboards.firstMatch
    let showingKeyboard = keyboard.exists && keyboard.isHittable
    field.typeText("\n")
    if showingKeyboard {
      XCTAssertTrue(keyboard.waitForNonExistence(timeout: 10), name)
    }
  }

  private func turnOffEveningReminder() {
    let form = app.collectionViews.containing(.textField, identifier: "titleField").firstMatch
    form.swipeUp()
    let toggle = app.switches["reminderToggle"].firstMatch
    XCTAssertEqual(toggle.value as? String, "1")
    tap("reminderToggle")
    let off = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", "0"), object: toggle)
    XCTAssertEqual(XCTWaiter.wait(for: [off], timeout: 10), .completed)
  }

  func testRegisterCancelEditCompleteAndPersistHistory() {
    configure()
    app.launch()
    tap("addDeadline")
    let save = app.buttons["保存"].firstMatch
    XCTAssertTrue(save.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(save.isEnabled, save.debugDescription)
    type("Unused", into: "companyField")
    XCTAssertFalse(save.isEnabled, save.debugDescription)
    tap("cancelEditor")
    XCTAssertTrue(control("emptyDeadlines").exists)
    tap("addDeadline")
    type("ACME", into: "companyField")
    type("Interview", into: "titleField")
    XCTAssertTrue(save.isEnabled, save.debugDescription)
    turnOffEveningReminder()
    tap("saveDeadline")
    XCTAssertTrue(app.staticTexts["前夜の通知はオフです"].waitForExistence(timeout: 5))
    tap("closeReceipt")
    tap("task.Interview")
    tap("editDeadline")
    type(" change", into: "titleField")
    tap("cancelEditor")
    XCTAssertTrue(control("completeDeadline").exists)
    tap("editDeadline")
    tap("saveDeadline")
    tap("closeReceipt")
    XCTAssertFalse(control("completeDeadline").exists, "The receipt returns to the deadline list.")
    tap("task.Interview")
    tap("completeDeadline")
    XCTAssertFalse(control("task.Interview").exists)
    selectTab("応募先")
    tap("employer.ACME")
    XCTAssertTrue(control("history.Interview").exists)
    tap("changeStage")
    tap("stage.waiting")
    app.terminate()
    app.launch()
    selectTab("応募先")
    tap("employer.ACME")
    XCTAssertTrue(control("history.Interview").exists)
    XCTAssertTrue(control("changeStage").label.contains("結果待ち"))
  }

  func testSupportAndPrivacyAreAvailableBeforeAddingAnEmployer() {
    configure()
    app.launch()
    selectTab("応募先")
    for title in ["サポート", "プライバシーポリシー"] {
      let link = app.links[title].firstMatch
      let action = link.exists ? link : app.buttons[title].firstMatch
      XCTAssertTrue(action.waitForExistence(timeout: 4), app.debugDescription)
      XCTAssertTrue(action.isHittable, title)
    }
  }

  func testSampleNotificationOpensTheDayAndCompletesOneOfTwo() {
    func capture(_ name: String) {
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
    }

    configure()
    app.launch()
    tap("startExample")
    XCTAssertTrue(control("task.適性検査").exists)
    tap("addDeadline")
    tap("chooseCompany")
    tap("existing.B社")
    tap("chooseTitle")
    tap("example.エントリーシート提出")
    tap("saveDeadline")
    XCTAssertTrue(control("task.エントリーシート提出").exists)
    capture("Store-Deadlines")
    tap("previewNotification")
    tap("openNotification")
    XCTAssertTrue(control("dayFilter").exists)
    tap("task.エントリーシート提出")
    if UIDevice.current.userInterfaceIdiom == .pad {
      XCUIDevice.shared.orientation = .landscapeLeft
      let list = control("task.適性検査")
      let detail = control("completeDeadline")
      XCTAssertTrue(list.isHittable)
      XCTAssertLessThanOrEqual(list.frame.maxX, detail.frame.minX)
    }
    XCTAssertTrue(control("completeDeadline").isHittable)
    capture("Store-Deadline-Detail")
    tap("completeDeadline")
    XCTAssertTrue(control("task.適性検査").exists)
    XCTAssertFalse(control("task.エントリーシート提出").exists)
    tap("exitExample")
    XCTAssertTrue(control("emptyDeadlines").waitForExistence(timeout: 5))
  }

  func testExampleOffersANotificationOnlyWhileAReminderIsScheduled() {
    configure()
    app.launch()
    tap("startExample")
    XCTAssertTrue(control("previewNotification").isEnabled)
    tap("task.適性検査")
    tap("editDeadline")
    turnOffEveningReminder()
    tap("saveDeadline")
    tap("closeReceipt")
    XCTAssertTrue(control("task.適性検査").exists)
    XCTAssertFalse(control("previewNotification").isEnabled)
    tap("task.適性検査")
    tap("completeDeadline")
    XCTAssertFalse(control("previewNotification").isEnabled)
    tap("exitExample")
    XCTAssertTrue(control("emptyDeadlines").waitForExistence(timeout: 5))
  }

  func testLargeTextAndRotationPreserveTheDraftAndSelectedEmployer() {
    configure()
    app.launchArguments += [
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
    ]
    XCUIDevice.shared.orientation = .portrait
    defer { XCUIDevice.shared.orientation = .portrait }
    app.launch()
    selectTab("応募先")
    tap("addEmployer")
    type("Long Company Name Research and Design", into: "employerName")
    tap("saveEmployer")
    tap("employer.Long Company Name Research and Design")
    XCTAssertTrue(control("changeStage").exists)
    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(control("changeStage").waitForExistence(timeout: 5))
    XCUIDevice.shared.orientation = .portrait
    selectTab("締切")
    tap("addDeadline")
    type("Draft", into: "titleField")
    XCUIDevice.shared.orientation = .landscapeLeft
    XCUIDevice.shared.orientation = .portrait
    XCTAssertEqual(control("titleField").value as? String, "Draft")
    tap("cancelEditor")
    XCTAssertTrue(control("emptyDeadlines").exists)
  }

  func testNativeDateAndOptionalTimeReachTheSavedDetail() throws {
    configure()
    app.launch()
    tap("startExample")
    tap("task.適性検査")
    tap("editDeadline")
    tap("dueDate")
    let fifth = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "12月5日")).firstMatch
    XCTAssertTrue(fifth.waitForExistence(timeout: 5), app.debugDescription)
    fifth.tap()
    let confirmDay = app.buttons["confirmDay"]
    XCTAssertTrue(confirmDay.waitForExistence(timeout: 3))
    confirmDay.tap()
    XCTAssertTrue(confirmDay.waitForNonExistence(timeout: 5))
    let timePicker = control("dueTime")
    XCTAssertFalse(timePicker.exists)
    tap("timeToggle")
    XCTAssertTrue(timePicker.waitForExistence(timeout: 5), app.debugDescription)
    tap("saveDeadline")
    XCTAssertTrue(app.staticTexts["12月5日（土）"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["17:00"].exists)
    XCTAssertTrue(control("saveDeadline").waitForNonExistence(timeout: 5))
    try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .trait])
    for text in ["A社", "締切日", "12月5日（土）", "時刻", "17:00", "前夜の通知", "前日 19:00"] {
      let element = app.staticTexts[text].firstMatch
      XCTAssertGreaterThanOrEqual(try TextContrast.ratio(in: element.screenshot().image), 4.5, text)
    }
    for name in ["editDeadline", "completeDeadline", "addDeadline"] {
      let button = control(name)
      if name == "addDeadline" && (!button.exists || !button.isHittable) { continue }
      XCTAssertTrue(button.isEnabled, name)
      XCTAssertGreaterThanOrEqual(
        try TextContrast.ratio(in: button.screenshot().image, centerOfControl: true), 4.5, name)
    }
  }

  func testLargerTextExpandsTheDeadlineTitleAndDateWithoutLosingTheAction() throws {
    configure()
    var standardSidebarTitleWidth: CGFloat?
    func sizes(at category: UIContentSizeCategory) throws -> [CGFloat] {
      app.launchArguments = [
        "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
        "-UIPreferredContentSizeCategoryName", category.rawValue,
      ]
      app.launch()
      tap("startExample")
      XCTAssertTrue(app.buttons["入力例を閉じる"].firstMatch.isHittable)
      tap("task.適性検査")
      let title = app.staticTexts["適性検査"].firstMatch
      let date = app.staticTexts["12月4日（金）"].firstMatch
      XCTAssertTrue(title.exists && date.exists)
      let complete = control("completeDeadline")
      XCTAssertTrue(complete.isHittable)
      let add = control("addDeadline")
      if add.exists && add.isHittable && add.frame.maxX <= complete.frame.minX {
        let heading = app.navigationBars.staticTexts["締切"].firstMatch
        XCTAssertTrue(heading.isHittable)
        if category == .large {
          standardSidebarTitleWidth = heading.frame.width
        } else {
          let standard = try XCTUnwrap(standardSidebarTitleWidth)
          XCTAssertGreaterThanOrEqual(heading.frame.width + 1, standard)
          XCTAssertGreaterThanOrEqual(
            try TextContrast.minimumOuterThirdContrast(in: heading.screenshot().image), 4.5, "締切")
          let row = control("task.適性検査")
          if row.frame.maxY > add.frame.minY {
            let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
            let end = start.withOffset(CGVector(dx: 0, dy: -row.frame.height))
            start.press(forDuration: 0.08, thenDragTo: end)
          }
          let readable = NSPredicate { _, _ in row.frame.maxY <= add.frame.minY + 1 }
          let aboveButton = XCTNSPredicateExpectation(predicate: readable, object: nil)
          XCTAssertEqual(XCTWaiter.wait(for: [aboveButton], timeout: 5), .completed)
        }
      }
      let heights = [title.frame.height, date.frame.height]
      app.terminate()
      return heights
    }
    let normal = try sizes(at: .large)
    let large = try sizes(at: .accessibilityExtraExtraExtraLarge)
    for (standard, enlarged) in zip(normal, large) {
      XCTAssertGreaterThan(enlarged, standard * 1.2)
    }
  }

  func testContrastMeasurementRejectsFadedTextInEitherAppearance() throws {
    func ratio(_ ink: CGFloat, on paper: CGFloat) throws -> Double {
      let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { renderer in
        UIColor(white: paper, alpha: 1).setFill()
        renderer.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        UIColor(white: ink, alpha: 1).setFill()
        renderer.fill(CGRect(x: 6, y: 0, width: 12, height: 24))
      }
      return try TextContrast.ratio(in: image)
    }
    XCTAssertEqual(try ratio(0, on: 1), 21, accuracy: 0.01)
    XCTAssertEqual(try ratio(1, on: 0), 21, accuracy: 0.01)
    XCTAssertLessThan(try ratio(0.8, on: 1), 4.5)
    XCTAssertLessThan(try ratio(0.2, on: 0), 4.5)

    func title(_ text: String, background: CGFloat) -> UIImage {
      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.boldSystemFont(ofSize: 20),
        .foregroundColor: UIColor(white: 1 - background, alpha: 1),
      ]
      let line = text as NSString
      let measured = line.size(withAttributes: attributes)
      let size = CGSize(width: ceil(measured.width), height: ceil(measured.height))
      let format = UIGraphicsImageRendererFormat()
      format.opaque = true
      return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
        UIColor(white: background, alpha: 1).setFill()
        renderer.fill(CGRect(origin: .zero, size: size))
        line.draw(at: .zero, withAttributes: attributes)
      }
    }
    for background: CGFloat in [0, 1] {
      XCTAssertGreaterThanOrEqual(
        try TextContrast.minimumOuterThirdContrast(in: title("締切", background: background)), 4.5)
      XCTAssertLessThan(
        try TextContrast.minimumOuterThirdContrast(in: title("…", background: background)), 4.5,
        "Ellipsis on \(background)")
    }
  }
}
