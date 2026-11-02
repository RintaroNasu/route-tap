import XCTest

final class RouteTapUITests: XCTestCase {
	@MainActor
	func testLoginSignupSwitchAndValidation() throws {
		continueAfterFailure = false
		XCUIDevice.shared.orientation = .portrait
		let app = XCUIApplication()
		// Isolate the UI test Keychain namespace from the developer's session.
		app.launchEnvironment["ROUTETAP_API_BASE_URL"] = "http://127.0.0.1:9"
		app.launch()
		XCTAssertTrue(app.staticTexts["auth.heading"].waitForExistence(timeout: 10))
		XCTAssertEqual(app.staticTexts["auth.heading"].label, "ログイン")
		XCTAssertTrue(app.staticTexts["RouteTap"].exists)
		app.buttons["auth.submit"].tap()
		XCTAssertTrue(app.staticTexts["auth.error"].exists)
		let login = XCTAttachment(screenshot: app.screenshot())
		login.name = "ログイン"
		login.lifetime = .keepAlways
		add(login)
		app.buttons["auth.switch"].tap()
		XCTAssertEqual(app.staticTexts["auth.heading"].label, "新規登録")
		XCTAssertFalse(app.staticTexts["auth.error"].exists)
		XCTAssertTrue(app.buttons["auth.submit"].label.contains("アカウントを作成"))
		XCTAssertFalse(app.buttons["パスワードを忘れた方"].exists)
		let signup = XCTAttachment(screenshot: app.screenshot())
		signup.name = "新規登録"
		signup.lifetime = .keepAlways
		add(signup)
		app.buttons["パスワードを表示"].tap()
		XCTAssertTrue(app.textFields["auth.password"].exists)
		app.buttons["パスワードを隠す"].tap()
		XCTAssertTrue(app.secureTextFields["auth.password"].exists)
		app.buttons["auth.switch"].tap()
		XCTAssertEqual(app.staticTexts["auth.heading"].label, "ログイン")
	}
}
