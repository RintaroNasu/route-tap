import Foundation

protocol AuthServicing {
	func signUp(email: String, password: String) async throws -> String
	func login(email: String, password: String) async throws -> String
	func fetchCurrentUser(token: String) async throws -> AuthenticatedUser
}

struct AuthAPI: AuthServicing {
	let baseURL: URL?
	let session: URLSession

	init(baseURL: URL? = APIConfiguration.baseURL, session: URLSession = .shared) {
		self.baseURL = baseURL
		self.session = session
	}

	func signUp(email: String, password: String) async throws -> String {
		var request: URLRequest = try makeRequest(path: "signup")
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		let credentials: Credentials = Credentials(email: email, password: password)
		request.httpBody = try JSONEncoder().encode(credentials)

		let data: Data = try await send(request)

		do {
			let response: TokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
			guard !response.token.isEmpty else {
				throw AuthError.invalidResponse
			}
			return response.token
		} catch {
			throw AuthError.invalidResponse
		}
	}

	func login(email: String, password: String) async throws -> String {
		var request: URLRequest = try makeRequest(path: "login")
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		let credentials = Credentials(email: email, password: password)
		request.httpBody = try JSONEncoder().encode(credentials)

		let data = try await send(request)

		do {
			let response = try JSONDecoder().decode(TokenResponse.self, from: data)
			guard !response.token.isEmpty else {
				throw AuthError.invalidResponse
			}
			return response.token
		} catch {
			throw AuthError.invalidResponse
		}
	}

	func fetchCurrentUser(token: String) async throws -> AuthenticatedUser {
		var request = try makeRequest(path: "me")
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

		let data = try await send(request)

		do {
			return try JSONDecoder().decode(AuthenticatedUser.self, from: data)
		} catch {
			throw AuthError.invalidResponse
		}
	}

	private func makeRequest(path: String) throws -> URLRequest {
		guard let baseURL else {
			throw AuthError.configuration
		}
		let url: URL = baseURL.appendingPathComponent(path)
		var request = URLRequest(url: url)
		request.timeoutInterval = 20
		request.cachePolicy = .reloadIgnoringLocalCacheData
		request.setValue("application/json", forHTTPHeaderField: "Accept")
		return request
	}

	private func send(_ request: URLRequest) async throws -> Data {
		let data: Data
		let response: URLResponse
		do {
			(data, response) = try await session.data(for: request)
		} catch {
			if Task.isCancelled {
				throw CancellationError()
			}
			throw AuthError.connection
		}

		guard let httpResponse = response as? HTTPURLResponse else {
			throw AuthError.invalidResponse
		}
		switch httpResponse.statusCode {
		case 200..<300:
			return data
		case 400:
			throw AuthError.invalidInput
		case 401:
			throw AuthError.unauthorized
		case 409:
			throw AuthError.duplicateEmail
		default:
			throw AuthError.server
		}
	}
}

private struct Credentials: Encodable {
	let email: String
	let password: String
}

private struct TokenResponse: Decodable {
	let token: String
}
