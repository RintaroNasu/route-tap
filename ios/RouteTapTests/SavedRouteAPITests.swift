import Foundation
import Testing

@testable import RouteTap

private final class RouteURLProtocol: URLProtocol {
	static var handler: ((URLRequest) throws -> (Int, Data))?
	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
	override func startLoading() {
		do {
			let (status, data) = try Self.handler!(request)
			let response = HTTPURLResponse(
				url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			client?.urlProtocol(self, didLoad: data)
			client?.urlProtocolDidFinishLoading(self)
		} catch { client?.urlProtocol(self, didFailWithError: error) }
	}
	override func stopLoading() {}
}

struct SavedRouteAPITests {
	@Test func requestsResponsesAndFailures() async throws {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [RouteURLProtocol.self]
		let session = URLSession(configuration: configuration)
		defer {
			session.invalidateAndCancel()
			RouteURLProtocol.handler = nil
		}
		let api = SavedRouteAPI(baseURL: URL(string: "https://api.example.com"), session: session)
		let routeJSON =
			#"{"id":12,"name":"通勤","origin":"大井町駅","destination":"浜松町駅","created_at":"2026-11-03T18:03:00+09:00","updated_at":"2026-11-03T18:03:00+09:00"}"#
		RouteURLProtocol.handler = { request in
			#expect(request.url?.path == "/routes")
			#expect(request.httpMethod == "GET")
			#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer saved-token")
			#expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
			return (200, Data("[\(routeJSON)]".utf8))
		}
		let routes = try await api.fetchRoutes(token: "saved-token")
		#expect(routes == [SavedRoute(id: 12, name: "通勤", origin: "大井町駅", destination: "浜松町駅")])

		RouteURLProtocol.handler = { request in
			#expect(request.url?.path == "/routes")
			#expect(request.httpMethod == "POST")
			#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer saved-token")
			#expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
			let data: Data
			if let body = request.httpBody {
				data = body
			} else {
				let stream = try #require(request.httpBodyStream)
				stream.open()
				defer { stream.close() }
				data = Data(reading: stream)
			}
			let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
			#expect(body == ["name": "通勤", "origin": "大井町駅", "destination": "浜松町駅"])
			return (201, Data(routeJSON.utf8))
		}
		let created = try await api.createRoute(
			input: SavedRouteInput(name: "通勤", origin: "大井町駅", destination: "浜松町駅"),
			token: "saved-token")
		#expect(created == routes.first)

		RouteURLProtocol.handler = { request in
			#expect(request.url?.path == "/routes/12")
			#expect(request.httpMethod == "PUT")
			#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer saved-token")
			#expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
			let data: Data
			if let body = request.httpBody {
				data = body
			} else {
				let stream = try #require(request.httpBodyStream)
				stream.open()
				defer { stream.close() }
				data = Data(reading: stream)
			}
			let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
			#expect(body == ["name": "通勤", "origin": "大井町駅", "destination": "浜松町駅"])
			return (200, Data(routeJSON.utf8))
		}
		let updated = try await api.updateRoute(
			id: 12, input: SavedRouteInput(name: "通勤", origin: "大井町駅", destination: "浜松町駅"),
			token: "saved-token")
		#expect(updated == created)
		RouteURLProtocol.handler = { request in
			#expect(request.url?.path == "/routes/12")
			#expect(request.httpMethod == "DELETE")
			#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer saved-token")
			#expect(request.httpBody == nil)
			return (204, Data())
		}
		try await api.deleteRoute(id: 12, token: "saved-token")

		RouteURLProtocol.handler = { _ in (200, Data("[]".utf8)) }
		#expect(try await api.fetchRoutes(token: "saved-token").isEmpty)

		for status in [400, 401, 404, 500] {
			RouteURLProtocol.handler = { _ in
				(status, Data(#"{"error":{"message":"private details"}}"#.utf8))
			}
			for operation in ["list", "create", "update", "delete"] {
				do {
					switch operation {
					case "list": _ = try await api.fetchRoutes(token: "saved-token")
					case "create":
						_ = try await api.createRoute(
							input: SavedRouteInput(), token: "saved-token")
					case "update":
						_ = try await api.updateRoute(
							id: 12, input: SavedRouteInput(), token: "saved-token")
					default: try await api.deleteRoute(id: 12, token: "saved-token")
					}
					Issue.record("HTTP error was accepted")
				} catch let error as SavedRouteError {
					let expected: SavedRouteError =
						switch status {
						case 400: .invalidInput
						case 401: .unauthorized
						case 404: .notFound
						default: .server
						}
					#expect(error == expected)
				}
			}
		}
		RouteURLProtocol.handler = { _ in (200, Data("invalid JSON".utf8)) }
		await #expect(throws: SavedRouteError.invalidResponse) {
			_ = try await api.fetchRoutes(token: "saved-token")
		}
		await #expect(throws: SavedRouteError.invalidResponse) {
			_ = try await api.createRoute(input: SavedRouteInput(), token: "saved-token")
		}
		await #expect(throws: SavedRouteError.invalidResponse) {
			_ = try await api.updateRoute(id: 12, input: SavedRouteInput(), token: "saved-token")
		}
		RouteURLProtocol.handler = { _ in (200, Data(routeJSON.utf8)) }
		await #expect(throws: SavedRouteError.invalidResponse) {
			_ = try await api.updateRoute(id: 99, input: SavedRouteInput(), token: "saved-token")
		}

		RouteURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
		await #expect(throws: SavedRouteError.connection) {
			_ = try await api.fetchRoutes(token: "saved-token")
		}
		await #expect(throws: SavedRouteError.connection) {
			_ = try await api.updateRoute(id: 12, input: SavedRouteInput(), token: "saved-token")
		}
		await #expect(throws: SavedRouteError.connection) {
			try await api.deleteRoute(id: 12, token: "saved-token")
		}

		let unconfigured = SavedRouteAPI(baseURL: nil, session: session)
		await #expect(throws: SavedRouteError.configuration) {
			_ = try await unconfigured.fetchRoutes(token: "saved-token")
		}
	}
}

extension Data {
	fileprivate init(reading stream: InputStream) {
		self.init()
		var buffer = [UInt8](repeating: 0, count: 1024)
		while stream.hasBytesAvailable {
			let count = stream.read(&buffer, maxLength: buffer.count)
			if count <= 0 { break }
			append(buffer, count: count)
		}
	}
}
