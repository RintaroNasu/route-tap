import XCTest

final class SavedRoutesUITests: XCTestCase {
	override func setUpWithError() throws {
		continueAfterFailure = false
		XCUIDevice.shared.orientation = .portrait
	}

	@MainActor
	func testRegisterAndRelaunchWithoutLoginOrAPI() throws {
		let app = launchIsolatedApp()
		XCTAssertTrue(element("routes.empty", in: app).waitForExistence(timeout: 5))
		XCTAssertFalse(app.staticTexts["auth.heading"].exists)
		XCTAssertFalse(app.buttons["アカウント"].exists)
		app.buttons["routes.add"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
		app.buttons["routes.save"].tap()
		XCTAssertTrue(app.staticTexts["routes.saveError"].exists)
		fillForm(in: app, name: "会社への移動", origin: "大井町駅", destination: "浜松町駅")
		app.buttons["routes.save"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
			.tap()
		dismissWidgetIntroduction(in: app)
		let card = firstCard(in: app)
		XCTAssertTrue(card.waitForExistence(timeout: 5))
		let id = card.identifier.replacingOccurrences(of: "routes.card.", with: "")
		XCTAssertTrue(card.staticTexts["会社への移動"].exists)
		app.buttons["routes.direction.inbound.\(id)"].coordinate(
			withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)
		).tap()
		XCTAssertTrue(element("routes.origin.\(id)", in: app).label.contains("浜松町駅"))
		XCTAssertTrue(element("routes.destination.\(id)", in: app).label.contains("大井町駅"))
		XCTAssertTrue(app.buttons["routes.openMaps.\(id)"].exists)
		attach(app, name: "端末保存・復路")
		app.terminate()
		app.launch()
		XCTAssertTrue(element("routes.card.\(id)", in: app).waitForExistence(timeout: 10))
		XCTAssertTrue(app.staticTexts["会社への移動"].exists)
		XCTAssertFalse(app.staticTexts["auth.heading"].exists)
	}

	@MainActor
	func testEditCancelAndDeletePersistAcrossRelaunch() throws {
		let app = launchIsolatedApp()
		app.buttons["routes.add"].tap()
		fillForm(in: app, name: "通勤", origin: "大井町駅", destination: "浜松町駅")
		app.buttons["routes.save"].tap()
		dismissWidgetIntroduction(in: app)
		let card = firstCard(in: app)
		XCTAssertTrue(card.waitForExistence(timeout: 5))
		let id = card.identifier.replacingOccurrences(of: "routes.card.", with: "")
		app.buttons["routes.menu.\(id)"].tap()
		app.buttons["routes.edit.\(id)"].tap()
		XCTAssertTrue(app.staticTexts["routes.formHeading"].waitForExistence(timeout: 5))
		XCTAssertEqual(element("routes.origin", in: app).value as? String, "大井町駅")
		app.buttons["routes.close"].tap()
		XCTAssertTrue(app.staticTexts["通勤"].exists)
		app.buttons["routes.menu.\(id)"].tap()
		app.buttons["routes.edit.\(id)"].tap()
		let name = element("routes.name", in: app)
		name.tap()
		name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "平日通勤")
		name.typeText("\n")
		app.buttons["routes.save"].tap()
		XCTAssertTrue(app.staticTexts["平日通勤"].waitForExistence(timeout: 5))
		app.terminate()
		app.launch()
		XCTAssertTrue(app.staticTexts["平日通勤"].waitForExistence(timeout: 10))
		app.buttons["routes.menu.\(id)"].tap()
		app.buttons["routes.delete.\(id)"].tap()
		let alert = app.alerts["移動を削除しますか？"]
		XCTAssertTrue(alert.waitForExistence(timeout: 5))
		alert.buttons["キャンセル"].tap()
		XCTAssertTrue(element("routes.card.\(id)", in: app).exists)
		app.buttons["routes.menu.\(id)"].tap()
		app.buttons["routes.delete.\(id)"].tap()
		// 同じ削除ボタンが親子の要素として公開される場合も、1つを指定する。
		let confirmDelete = alert.buttons.matching(identifier: "routes.confirmDelete").firstMatch
		XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
		confirmDelete.tap()
		XCTAssertTrue(element("routes.empty", in: app).waitForExistence(timeout: 5))
		app.terminate()
		app.launch()
		XCTAssertTrue(element("routes.empty", in: app).waitForExistence(timeout: 10))
	}

	@MainActor
	func testWidgetGuideAppearsOnceAndCanBeOpenedFromRouteMenu() throws {
		let app = launchIsolatedApp()
		app.buttons["routes.add"].tap()
		fillForm(in: app, name: "通勤", origin: "大井町駅", destination: "浜松町駅")
		app.buttons["routes.save"].tap()
		XCTAssertTrue(app.staticTexts["widgetGuide.saved"].waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["widgetGuide.previewName"].label, "通勤")
		attach(app, name: "保存後のウィジェット案内")
		app.buttons["widgetGuide.showSteps"].tap()
		XCTAssertTrue(app.staticTexts["widgetGuide.heading"].waitForExistence(timeout: 5))
		XCTAssertTrue(app.images["widgetGuide.image.1"].exists)
		attach(app, name: "ウィジェット追加手順・上部")
		let lastImage = app.images["widgetGuide.image.3"]
		for _ in 0..<5 {
			if lastImage.isHittable { break }
			app.swipeUp()
		}
		XCTAssertTrue(lastImage.isHittable)
		attach(app, name: "ウィジェット追加手順・下部")
		app.buttons["widgetGuide.done"].tap()
		XCTAssertTrue(app.buttons["routes.add"].waitForExistence(timeout: 5))

		// 表示履歴は再起動後も保持し、2件目では案内を出さない。
		app.terminate()
		app.launch()
		XCTAssertTrue(app.buttons["routes.add"].waitForExistence(timeout: 10))
		app.buttons["routes.add"].tap()
		fillForm(in: app, name: "休日", origin: "新宿駅", destination: "渋谷駅")
		app.buttons["routes.save"].tap()
		XCTAssertTrue(app.staticTexts["休日"].waitForExistence(timeout: 5))
		XCTAssertFalse(app.staticTexts["widgetGuide.saved"].exists)
		let id = firstCard(in: app).identifier.replacingOccurrences(of: "routes.card.", with: "")
		app.buttons["routes.menu.\(id)"].tap()
		app.buttons["routes.widgetGuide.\(id)"].tap()
		XCTAssertTrue(app.staticTexts["widgetGuide.heading"].waitForExistence(timeout: 5))
		XCTAssertFalse(app.staticTexts["widgetGuide.saved"].exists)
		app.buttons["widgetGuide.close"].tap()
		XCTAssertTrue(app.buttons["routes.add"].waitForExistence(timeout: 5))
	}

	@MainActor
	private func dismissWidgetIntroduction(in app: XCUIApplication) {
		XCTAssertTrue(app.staticTexts["widgetGuide.saved"].waitForExistence(timeout: 5))
		app.buttons["widgetGuide.later"].tap()
	}

	@MainActor
	private func launchIsolatedApp() -> XCUIApplication {
		let app = XCUIApplication()
		app.launchEnvironment["ROUTETAP_UI_TEST_STORE_ID"] = UUID().uuidString
		app.launch()
		XCTAssertTrue(app.staticTexts["routes.heading"].waitForExistence(timeout: 10))
		return app
	}

	@MainActor
	private func fillForm(
		in app: XCUIApplication, name: String, origin: String, destination: String
	) {
		element("routes.name", in: app).tap()
		for (field, value) in [("name", name), ("origin", origin), ("destination", destination)] {
			let input = element("routes." + field, in: app)
			input.typeText(value)
			XCTAssertEqual(input.value as? String, value)
			input.typeText("\n")
		}
	}

	@MainActor
	private func firstCard(in app: XCUIApplication) -> XCUIElement {
		app.descendants(matching: .any).matching(
			NSPredicate(format: "identifier BEGINSWITH %@", "routes.card.")
		).firstMatch
	}

	@MainActor
	private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
		app.descendants(matching: .any).matching(identifier: identifier).firstMatch
	}

	@MainActor
	private func attach(_ app: XCUIApplication, name: String) {
		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = name
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
