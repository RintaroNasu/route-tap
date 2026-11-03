import Foundation

protocol SavedRouteServicing {
	func fetchRoutes(token: String) async throws -> [SavedRoute]
	func createRoute(input: SavedRouteInput, token: String) async throws -> SavedRoute
}

struct SavedRouteAPI: SavedRouteServicing {
	let baseURL: URL?
	let session: URLSession

	init(baseURL: URL? = APIConfiguration.baseURL, session: URLSession = .shared) {
		self.baseURL = baseURL
		self.session = session
	}

	func fetchRoutes(token: String) async throws -> [SavedRoute] {
		let request = try makeRequest(token: token)
		let data = try await send(request)
		do {
			return try JSONDecoder().decode([SavedRoute].self, from: data)
		} catch {
			throw SavedRouteError.invalidResponse
		}
	}

	func createRoute(input: SavedRouteInput, token: String) async throws -> SavedRoute {
		var request = try makeRequest(token: token)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(input)
		let data = try await send(request)
		do {
			return try JSONDecoder().decode(SavedRoute.self, from: data)
		} catch {
			throw SavedRouteError.invalidResponse
		}
	}

	private func makeRequest(token: String) throws -> URLRequest {
		guard let baseURL else { throw SavedRouteError.configuration }
		var request = URLRequest(url: baseURL.appendingPathComponent("routes"))
		request.timeoutInterval = 20
		request.cachePolicy = .reloadIgnoringLocalCacheData
		request.setValue("application/json", forHTTPHeaderField: "Accept")
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		return request
	}

	private func send(_ request: URLRequest) async throws -> Data {
		let data: Data
		let response: URLResponse
		do {
			(data, response) = try await session.data(for: request)
		} catch {
			if Task.isCancelled { throw CancellationError() }
			throw SavedRouteError.connection
		}
		guard let response = response as? HTTPURLResponse else {
			throw SavedRouteError.invalidResponse
		}
		switch response.statusCode {
		case 200..<300: return data
		case 400: throw SavedRouteError.invalidInput
		case 401: throw SavedRouteError.unauthorized
		default: throw SavedRouteError.server
		}
	}
}
