import Network
import XCTest

final class SavedRoutesUITests: XCTestCase {
	@MainActor
	func testAccountDeletionCancelFailureAndRetry() throws {
		continueAfterFailure = false
		XCUIDevice.shared.orientation = .portrait
		let server = try RouteTestServer(routes: [
			["id": 1, "name": "削除前の通勤", "origin": "大井町駅", "destination": "浜松町駅"]
		])
		defer { server.stop() }
		let app = XCUIApplication()
		app.launchEnvironment["ROUTETAP_API_BASE_URL"] = server.baseURL
		app.launch()
		login(app)
		XCTAssertTrue(element("routes.card.1", in: app).waitForExistence(timeout: 5))
		app.buttons["アカウント"].tap()
		XCTAssertGreaterThan(
			app.buttons["auth.deleteAccount"].frame.minY, app.buttons["auth.logout"].frame.minY)
		let menu = XCTAttachment(screenshot: app.screenshot())
		menu.name = "アカウントメニュー"
		menu.lifetime = .keepAlways
		add(menu)
		app.buttons["auth.deleteAccount"].tap()
		let alert = app.alerts["アカウントを削除しますか？"]
		XCTAssertTrue(alert.waitForExistence(timeout: 5))
		XCTAssertTrue(alert.staticTexts["アカウントと保存した移動がすべて削除されます。この操作は取り消せません。"].exists)
		let confirmation = XCTAttachment(screenshot: app.screenshot())
		confirmation.name = "アカウント削除の確認"
		confirmation.lifetime = .keepAlways
		add(confirmation)
		alert.buttons["キャンセル"].tap()
		XCTAssertEqual(server.accountDeletionCount(), 0)
		XCTAssertTrue(element("routes.card.1", in: app).exists)
		server.failNextAccountDeletion()
		app.buttons["アカウント"].tap()
		app.buttons["auth.deleteAccount"].tap()
		alert.buttons["auth.confirmAccountDeletion"].tap()
		XCTAssertTrue(app.staticTexts["auth.accountError"].waitForExistence(timeout: 5))
		XCTAssertTrue(element("routes.card.1", in: app).exists)
		XCTAssertEqual(server.accountDeletionCount(), 1)
		app.buttons["アカウント"].tap()
		app.buttons["auth.deleteAccount"].tap()
		alert.buttons["auth.confirmAccountDeletion"].tap()
		XCTAssertTrue(app.staticTexts["auth.heading"].waitForExistence(timeout: 10))
		XCTAssertEqual(server.accountDeletionCount(), 2)
		XCTAssertFalse(element("routes.card.1", in: app).exists)
		app.terminate()
		app.launch()
		XCTAssertTrue(app.staticTexts["auth.heading"].waitForExistence(timeout: 10))
	}

	@MainActor
	func testRegisterRetryAndReloadSavedRoutes() throws {
		continueAfterFailure = false
		XCUIDevice.shared.orientation = .portrait
		let server = try RouteTestServer()
		defer { server.stop() }
		let app = XCUIApplication()
		app.launchEnvironment["ROUTETAP_API_BASE_URL"] = server.baseURL
		app.launch()

		login(app)
		XCTAssertTrue(element("routes.empty", in: app).waitForExistence(timeout: 5))
		app.buttons["routes.add"].tap()
		app.buttons["routes.save"].tap()
		XCTAssertTrue(app.staticTexts["routes.saveError"].exists)

		for (field, value) in [
			("name", "会社への移動"), ("origin", "大井町駅、東京都品川区"), ("destination", "浜松町駅、東京都港区"),
		] {
			let input = element("routes." + field, in: app)
			input.tap()
			input.typeText(value)
		}
		app.keyboards.buttons.matching(
			NSPredicate(format: "identifier ==[c] %@ OR label == %@", "done", "完了")
		).firstMatch.tap()
		XCTAssertEqual(
			XCTWaiter.wait(
				for: [
					XCTNSPredicateExpectation(
						predicate: NSPredicate(format: "exists == false"),
						object: app.keyboards.firstMatch
					)
				], timeout: 3), .completed
		)
		XCTAssertFalse(app.staticTexts["routes.saveError"].exists)
		let form = XCTAttachment(screenshot: app.screenshot())
		form.name = "移動を登録"
		form.lifetime = .keepAlways
		add(form)

		server.failNextSave()
		app.buttons["routes.save"].tap()
		XCTAssertTrue(app.staticTexts["routes.saveError"].waitForExistence(timeout: 5))
		XCTAssertTrue(app.buttons["routes.save"].exists)
		XCTAssertTrue(element("routes.name", in: app).value as? String == "会社への移動")
		app.buttons["routes.save"].tap()
		let card = element("routes.card.1", in: app)
		XCTAssertTrue(card.waitForExistence(timeout: 10))
		XCTAssertTrue(card.staticTexts["会社への移動"].exists)
		XCTAssertTrue(element("routes.origin.1", in: app).label.contains("大井町駅"))
		XCTAssertTrue(element("routes.destination.1", in: app).label.contains("浜松町駅"))
		app.buttons["routes.direction.inbound.1"].tap()
		XCTAssertTrue(element("routes.origin.1", in: app).label.contains("浜松町駅"))
		XCTAssertTrue(element("routes.destination.1", in: app).label.contains("大井町駅"))
		XCTAssertTrue(app.buttons["routes.openMaps.1"].exists)
		XCTAssertEqual(app.buttons["routes.openMaps.1"].label, "Google Mapsで開く")
		let home = XCTAttachment(screenshot: app.screenshot())
		home.name = "いつもの移動・復路"
		home.lifetime = .keepAlways
		add(home)

		XCUIDevice.shared.press(.home)
		app.activate()
		XCTAssertTrue(element("routes.card.1", in: app).waitForExistence(timeout: 10))
		XCTAssertTrue(element("routes.origin.1", in: app).label.contains("浜松町駅"))
		app.buttons["routes.direction.outbound.1"].tap()
		XCTAssertTrue(element("routes.origin.1", in: app).label.contains("大井町駅"))
		XCTAssertTrue(element("routes.destination.1", in: app).label.contains("浜松町駅"))

		app.terminate()
		app.launch()
		XCTAssertTrue(element("routes.card.1", in: app).waitForExistence(timeout: 10))
		XCTAssertTrue(element("routes.origin.1", in: app).label.contains("大井町駅"))
		app.buttons["アカウント"].tap()
		app.buttons["auth.logout"].tap()
		XCTAssertTrue(app.staticTexts["auth.heading"].waitForExistence(timeout: 10))
	}

	@MainActor
	func testGoogleMapsShowsErrorWhenPlaceMakesURLTooLong() throws {
		continueAfterFailure = false
		XCUIDevice.shared.orientation = .portrait
		let server = try RouteTestServer(routes: [
			[
				"id": 1, "name": "長い場所", "origin": String(repeating: "駅", count: 260),
				"destination": "浜松町駅",
			]
		])
		defer { server.stop() }
		let app = XCUIApplication()
		app.launchEnvironment["ROUTETAP_API_BASE_URL"] = server.baseURL
		app.launch()
		login(app)
		let button = app.buttons["routes.openMaps.1"]
		XCTAssertTrue(button.waitForExistence(timeout: 10))
		for _ in 0..<3 {
			if button.isHittable { break }
			app.swipeUp()
		}
		button.tap()
		let alert = app.alerts["Google Mapsを開けませんでした"]
		XCTAssertTrue(alert.waitForExistence(timeout: 5))
		XCTAssertTrue(alert.staticTexts["場所の情報が長すぎます。出発地・目的地を短くして登録し直してください。"].exists)
		alert.buttons["閉じる"].tap()
		XCTAssertTrue(app.staticTexts["routes.heading"].exists)
	}

	@MainActor
	func testDirectionSelectionIsIndependentForEachCard() throws {
		continueAfterFailure = false
		XCUIDevice.shared.orientation = .portrait
		let server = try RouteTestServer(routes: [
			["id": 1, "name": "通勤", "origin": "大井町駅", "destination": "浜松町駅"],
			["id": 2, "name": "休日", "origin": "渋谷駅", "destination": "新宿駅"],
		])
		defer { server.stop() }
		let app = XCUIApplication()
		app.launchEnvironment["ROUTETAP_API_BASE_URL"] = server.baseURL
		app.launch()
		login(app)
		XCTAssertTrue(app.buttons["routes.direction.inbound.1"].waitForExistence(timeout: 10))
		app.buttons["routes.direction.inbound.1"].tap()
		XCTAssertTrue(element("routes.origin.1", in: app).label.contains("浜松町駅"))
		app.swipeUp()
		XCTAssertTrue(element("routes.origin.2", in: app).waitForExistence(timeout: 5))
		XCTAssertTrue(element("routes.origin.2", in: app).label.contains("渋谷駅"))
		XCTAssertTrue(element("routes.destination.2", in: app).label.contains("新宿駅"))
		app.buttons["routes.direction.inbound.2"].tap()
		XCTAssertTrue(element("routes.origin.2", in: app).label.contains("新宿駅"))
		app.swipeDown()
		XCTAssertTrue(element("routes.origin.1", in: app).label.contains("浜松町駅"))
	}

	@MainActor
	func testEditAndDeleteWithCancellationAndRetry() throws {
		continueAfterFailure = false
		XCUIDevice.shared.orientation = .portrait
		let server = try RouteTestServer(routes: [
			["id": 1, "name": "通勤", "origin": "大井町駅", "destination": "浜松町駅"]
		])
		defer { server.stop() }
		let app = XCUIApplication()
		app.launchEnvironment["ROUTETAP_API_BASE_URL"] = server.baseURL
		app.launch()
		login(app)
		XCTAssertTrue(app.buttons["routes.menu.1"].waitForExistence(timeout: 10))
		app.buttons["routes.direction.inbound.1"].tap()
		app.buttons["routes.menu.1"].tap()
		app.buttons["routes.edit.1"].tap()
		XCTAssertTrue(app.staticTexts["routes.formHeading"].waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["routes.formHeading"].label, "移動を編集")
		XCTAssertEqual(element("routes.origin", in: app).value as? String, "大井町駅")
		XCTAssertEqual(element("routes.destination", in: app).value as? String, "浜松町駅")
		replaceName("キャンセル用", in: app)
		app.buttons["routes.close"].tap()
		XCTAssertTrue(app.buttons["routes.menu.1"].waitForExistence(timeout: 5))
		XCTAssertTrue(app.staticTexts["通勤"].exists)
		XCTAssertEqual(server.mutationCounts().updates, 0)

		app.buttons["routes.menu.1"].tap()
		app.buttons["routes.edit.1"].tap()
		XCTAssertEqual(element("routes.name", in: app).value as? String, "通勤")
		let edit = XCTAttachment(screenshot: app.screenshot())
		edit.name = "移動を編集"
		edit.lifetime = .keepAlways
		add(edit)
		replaceName("平日通勤", in: app)
		server.failNextUpdate()
		app.buttons["routes.save"].tap()
		XCTAssertTrue(app.staticTexts["routes.saveError"].waitForExistence(timeout: 5))
		XCTAssertEqual(element("routes.name", in: app).value as? String, "平日通勤")
		app.buttons["routes.save"].tap()
		XCTAssertTrue(app.buttons["routes.menu.1"].waitForExistence(timeout: 10))
		XCTAssertTrue(app.staticTexts["平日通勤"].exists)
		XCTAssertTrue(element("routes.origin.1", in: app).label.contains("浜松町駅"))
		XCTAssertTrue(element("routes.destination.1", in: app).label.contains("大井町駅"))
		XCTAssertEqual(server.mutationCounts().updates, 2)

		app.buttons["routes.menu.1"].tap()
		app.buttons["routes.delete.1"].tap()
		let confirm = app.alerts["移動を削除しますか？"]
		XCTAssertTrue(confirm.waitForExistence(timeout: 5))
		XCTAssertTrue(confirm.staticTexts["「平日通勤」を削除します。この操作は取り消せません。"].exists)
		let deletion = XCTAttachment(screenshot: app.screenshot())
		deletion.name = "移動の削除確認"
		deletion.lifetime = .keepAlways
		add(deletion)
		confirm.buttons["キャンセル"].tap()
		XCTAssertTrue(app.buttons["routes.menu.1"].exists)
		XCTAssertEqual(server.mutationCounts().deletes, 0)

		server.failNextDelete()
		app.buttons["routes.menu.1"].tap()
		app.buttons["routes.delete.1"].tap()
		app.alerts["移動を削除しますか？"].buttons["routes.confirmDelete"].tap()
		let error = app.alerts["移動を削除できませんでした"]
		XCTAssertTrue(error.waitForExistence(timeout: 5))
		error.buttons["閉じる"].tap()
		XCTAssertTrue(app.buttons["routes.menu.1"].exists)
		app.buttons["routes.menu.1"].tap()
		app.buttons["routes.delete.1"].tap()
		app.alerts["移動を削除しますか？"].buttons["routes.confirmDelete"].tap()
		XCTAssertTrue(element("routes.empty", in: app).waitForExistence(timeout: 10))
		XCTAssertFalse(element("routes.card.1", in: app).exists)
		XCTAssertEqual(server.mutationCounts().deletes, 2)
	}

	@MainActor
	func testEditingMissingRouteRefreshesList() throws {
		continueAfterFailure = false
		let server = try RouteTestServer(routes: [
			["id": 1, "name": "通勤", "origin": "大井町駅", "destination": "浜松町駅"]
		])
		defer { server.stop() }
		let app = XCUIApplication()
		app.launchEnvironment["ROUTETAP_API_BASE_URL"] = server.baseURL
		app.launch()
		login(app)
		XCTAssertTrue(app.buttons["routes.menu.1"].waitForExistence(timeout: 10))
		app.buttons["routes.menu.1"].tap()
		app.buttons["routes.edit.1"].tap()
		XCTAssertTrue(app.staticTexts["routes.formHeading"].waitForExistence(timeout: 5))
		server.removeRoute(id: 1)
		app.buttons["routes.save"].tap()
		XCTAssertTrue(app.staticTexts["routes.saveError"].waitForExistence(timeout: 5))
		XCTAssertEqual(app.staticTexts["routes.saveError"].label, "この移動は見つかりませんでした。一覧を再取得します。")
		app.buttons["routes.close"].tap()
		XCTAssertTrue(element("routes.empty", in: app).waitForExistence(timeout: 5))
	}

	@MainActor
	private func replaceName(_ name: String, in app: XCUIApplication) {
		let field = element("routes.name", in: app)
		field.tap()
		field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
		let previous = field.value as? String ?? ""
		field.typeText(
			String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + name)
	}

	@MainActor
	private func login(_ app: XCUIApplication) {
		XCTAssertTrue(app.staticTexts["auth.heading"].waitForExistence(timeout: 10))
		app.textFields["auth.email"].tap()
		app.textFields["auth.email"].typeText("test@example.com")
		app.secureTextFields["auth.password"].tap()
		app.secureTextFields["auth.password"].typeText("password")
		app.buttons["auth.submit"].tap()
		XCTAssertTrue(app.staticTexts["routes.heading"].waitForExistence(timeout: 10))
	}

	@MainActor
	private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
		app.descendants(matching: .any).matching(identifier: identifier).firstMatch
	}
}

// テスト専用API。実際のGo API・DB・開発者のログイン情報は使わない。
private final class RouteTestServer {
	private let listener: NWListener
	private let queue = DispatchQueue(label: "RouteTap.UI-test-server")
	private var routes: [[String: Any]] = []
	private var shouldFailSave = false
	private var shouldFailUpdate = false
	private var shouldFailDelete = false
	private var updateRequests = 0
	private var deleteRequests = 0
	private var nextRouteID = 1
	private var shouldFailAccountDeletion = false
	private var accountDeleteRequests = 0
	private var accountDeleted = false
	var baseURL: String { "http://127.0.0.1:\(listener.port!.rawValue)" }

	init(routes: [[String: Any]] = []) throws {
		self.routes = routes
		nextRouteID = (routes.compactMap { $0["id"] as? Int }.max() ?? 0) + 1
		let parameters = NWParameters.tcp
		parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
		listener = try NWListener(using: parameters)
		let ready = DispatchSemaphore(value: 0)
		listener.stateUpdateHandler = { state in
			switch state {
			case .ready, .failed: ready.signal()
			default: break
			}
		}
		listener.newConnectionHandler = { [weak self] connection in
			guard let self else { return }
			connection.start(queue: self.queue)
			self.receive(connection, buffer: Data())
		}
		listener.start(queue: queue)
		guard ready.wait(timeout: .now() + 5) == .success, listener.port != nil else {
			listener.cancel()
			throw NSError(domain: "RouteTestServer", code: 1)
		}
	}

	func stop() { listener.cancel() }
	func failNextAccountDeletion() { queue.sync { shouldFailAccountDeletion = true } }
	func accountDeletionCount() -> Int { queue.sync { accountDeleteRequests } }
	func failNextSave() { queue.sync { shouldFailSave = true } }
	func failNextUpdate() { queue.sync { shouldFailUpdate = true } }
	func failNextDelete() { queue.sync { shouldFailDelete = true } }
	func removeRoute(id: Int) { queue.sync { routes.removeAll { $0["id"] as? Int == id } } }
	func mutationCounts() -> (updates: Int, deletes: Int) {
		queue.sync { (updateRequests, deleteRequests) }
	}

	private func receive(_ connection: NWConnection, buffer: Data) {
		connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
			[weak self] data, _, complete, error in
			guard let self else {
				connection.cancel()
				return
			}
			var buffer = buffer
			if let data { buffer.append(data) }
			let separator = Data("\r\n\r\n".utf8)
			if let range = buffer.range(of: separator),
				let header = String(data: buffer[..<range.lowerBound], encoding: .utf8)
			{
				let lines = header.components(separatedBy: "\r\n")
				let contentLength =
					lines.first { $0.lowercased().hasPrefix("content-length:") }
					.flatMap {
						Int(
							$0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(
								in: .whitespaces))
					} ?? 0
				let body = Data(buffer[range.upperBound...])
				if body.count >= contentLength {
					self.respond(connection, requestLine: lines[0], body: body)
					return
				}
			}
			if complete || error != nil {
				connection.cancel()
				return
			}
			self.receive(connection, buffer: buffer)
		}
	}

	private func respond(_ connection: NWConnection, requestLine: String, body: Data) {
		var status = 200
		let response: Any?
		if requestLine.hasPrefix("DELETE /me ") {
			accountDeleteRequests += 1
			if shouldFailAccountDeletion {
				shouldFailAccountDeletion = false
				status = 500
				response = ["error": ["message": "internal server error"]]
			} else {
				accountDeleted = true
				routes.removeAll()
				status = 204
				response = nil
			}
		} else if accountDeleted {
			status = 401
			response = ["error": ["message": "unauthorized"]]
		} else if requestLine.hasPrefix("POST /login ") {
			response = ["token": "ui-test-token"]
		} else if requestLine.hasPrefix("GET /me ") {
			response = ["id": 1, "email": "test@example.com"]
		} else if requestLine.hasPrefix("GET /routes ") {
			response = routes
		} else if requestLine.hasPrefix("POST /routes "),
			var route = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
		{
			if shouldFailSave {
				shouldFailSave = false
				status = 500
				response = [
					"error": ["code": "INTERNAL_ERROR", "message": "internal server error"]
				]
			} else {
				route["id"] = nextRouteID
				nextRouteID += 1
				routes.insert(route, at: 0)
				status = 201
				response = route
			}
		} else if requestLine.hasPrefix("PUT /routes/") {
			updateRequests += 1
			if shouldFailUpdate {
				shouldFailUpdate = false
				status = 500
				response = ["error": ["message": "internal server error"]]
			} else if let id = routeID(from: requestLine),
				let index = routes.firstIndex(where: { $0["id"] as? Int == id }),
				var route = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
			{
				route["id"] = id
				routes[index] = route
				response = route
			} else {
				status = 404
				response = ["error": ["message": "route not found"]]
			}
		} else if requestLine.hasPrefix("DELETE /routes/") {
			deleteRequests += 1
			if shouldFailDelete {
				shouldFailDelete = false
				status = 500
				response = ["error": ["message": "internal server error"]]
			} else if let id = routeID(from: requestLine),
				let index = routes.firstIndex(where: { $0["id"] as? Int == id })
			{
				routes.remove(at: index)
				status = 204
				response = nil
			} else {
				status = 404
				response = ["error": ["message": "route not found"]]
			}
		} else {
			status = 404
			response = ["error": ["message": "not found"]]
		}
		let data = response.map { try! JSONSerialization.data(withJSONObject: $0) } ?? Data()
		var output = Data(
			"HTTP/1.1 \(status) Response\r\nContent-Type: application/json\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
				.utf8)
		output.append(data)
		connection.send(content: output, completion: .contentProcessed { _ in connection.cancel() })
	}
	private func routeID(from requestLine: String) -> Int? {
		let parts = requestLine.split(separator: " ")
		guard parts.count >= 2, let last = parts[1].split(separator: "/").last else { return nil }
		return Int(last)
	}

}
