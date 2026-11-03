import Network
import XCTest

final class SavedRoutesUITests: XCTestCase {
	@MainActor
	func testRegisterRetryAndReloadSavedRoutes() throws {
		continueAfterFailure = false
		XCUIDevice.shared.orientation = .portrait
		let server = try RouteTestServer()
		defer { server.stop() }
		let app = XCUIApplication()
		app.launchEnvironment["ROUTETAP_API_BASE_URL"] = server.baseURL
		app.launch()

		XCTAssertTrue(app.staticTexts["auth.heading"].waitForExistence(timeout: 10))
		app.textFields["auth.email"].tap()
		app.textFields["auth.email"].typeText("test@example.com")
		app.secureTextFields["auth.password"].tap()
		app.secureTextFields["auth.password"].typeText("password")
		app.buttons["auth.submit"].tap()
		XCTAssertTrue(app.staticTexts["routes.heading"].waitForExistence(timeout: 10))
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
		app.keyboards.buttons["done"].tap()
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
		XCTAssertTrue(card.label.contains("会社への移動"))
		XCTAssertTrue(card.label.contains("大井町駅"))
		XCTAssertTrue(card.label.contains("浜松町駅"))
		XCTAssertFalse(app.buttons["Google Mapsで開く"].exists)
		let home = XCTAttachment(screenshot: app.screenshot())
		home.name = "いつもの移動"
		home.lifetime = .keepAlways
		add(home)

		app.terminate()
		app.launch()
		XCTAssertTrue(element("routes.card.1", in: app).waitForExistence(timeout: 10))
		app.buttons["アカウント"].tap()
		app.buttons["auth.logout"].tap()
		XCTAssertTrue(app.staticTexts["auth.heading"].waitForExistence(timeout: 10))
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
	var baseURL: String { "http://127.0.0.1:\(listener.port!.rawValue)" }

	init() throws {
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
	func failNextSave() { queue.sync { shouldFailSave = true } }

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
		let response: Any
		if requestLine.hasPrefix("POST /login ") {
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
				route["id"] = routes.count + 1
				routes.insert(route, at: 0)
				status = 201
				response = route
			}
		} else {
			status = 404
			response = ["error": ["message": "not found"]]
		}
		let data = try! JSONSerialization.data(withJSONObject: response)
		var output = Data(
			"HTTP/1.1 \(status) Response\r\nContent-Type: application/json\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
				.utf8)
		output.append(data)
		connection.send(content: output, completion: .contentProcessed { _ in connection.cancel() })
	}
}
