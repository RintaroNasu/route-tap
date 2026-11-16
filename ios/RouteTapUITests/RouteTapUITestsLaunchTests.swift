//
//  RouteTapUITestsLaunchTests.swift
//  RouteTapUITests
//
//  Created by 那須凜太郎 on 2026/10/13.
//

import XCTest

final class RouteTapUITestsLaunchTests: XCTestCase {

	override class var runsForEachTargetApplicationUIConfiguration: Bool {
		true
	}

	override func setUpWithError() throws {
		continueAfterFailure = false
	}

	@MainActor
	func testLaunch() throws {
		let app = XCUIApplication()
		app.launch()

		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = "Launch Screen"
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}
