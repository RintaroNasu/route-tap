import Foundation
import Testing

@testable import RouteTap

@MainActor
struct RouteTapTests {
	final class TokenStore: TokenStoring {
		var token: String?
		var failSave = false
		func read() throws -> String? { token }
		func save(_ token: String) throws {
			if failSave { throw AuthError.keychain }
			self.token = token
		}
		func delete() throws { token = nil }
	}

	final class API: AuthServicing {
		var authenticateError: AuthError?
		var profileError: AuthError?
		var submittedEmail: String?
		var submittedPassword: String?
		var submittedMode: AuthMode?
		let user = AuthenticatedUser(id: 1, email: "test@example.com")
		func signUp(email: String, password: String) async throws -> String {
			return try await authenticate(email: email, password: password, mode: .signup)
		}
		func login(email: String, password: String) async throws -> String {
			return try await authenticate(email: email, password: password, mode: .login)
		}
		private func authenticate(email: String, password: String, mode: AuthMode) async throws
			-> String
		{
			submittedEmail = email
			submittedPassword = password
			submittedMode = mode
			if let authenticateError { throw authenticateError }
			return "test-token"
		}
		func fetchCurrentUser(token: String) async throws -> AuthenticatedUser {
			if let profileError { throw profileError }
			return user
		}
	}

	@Test func loginNormalizesEmailAndPersistsSession() async {
		let api = API()
		let tokens = TokenStore()
		let model = AuthModel(api: api, tokens: tokens)
		await model.restoreIfNeeded()
		#expect(model.state == .signedOut)
		await model.submit(
			email: " TEST@EXAMPLE.COM ", password: " password ", mode: .login)
		#expect(api.submittedEmail == "test@example.com")
		#expect(api.submittedPassword == " password ")
		#expect(api.submittedMode == .login)
		#expect(tokens.token == "test-token")
		#expect(model.state == .signedIn(api.user))
		model.logout()
		#expect(tokens.token == nil)
		#expect(model.state == .signedOut)
	}

	@Test func signupUsesSignupEndpointAndReportsDuplicates() async {
		let api = API()
		api.authenticateError = .duplicateEmail
		let tokens = TokenStore()
		let model = AuthModel(api: api, tokens: tokens)
		await model.restoreIfNeeded()
		await model.submit(email: "test@example.com", password: "password", mode: .signup)
		#expect(api.submittedMode == .signup)
		#expect(model.state == .signedOut)
		#expect(model.errorMessage == AuthError.duplicateEmail.localizedDescription)
		#expect(tokens.token == nil)
	}

	@Test func restoresSavedSession() async {
		let api = API()
		let tokens = TokenStore()
		tokens.token = "saved-token"
		let model = AuthModel(api: api, tokens: tokens)
		await model.restoreIfNeeded()
		#expect(model.state == .signedIn(api.user))
	}

	@Test func expiredTokenIsRemoved() async {
		let api = API()
		api.profileError = .unauthorized
		let tokens = TokenStore()
		tokens.token = "expired-token"
		let model = AuthModel(api: api, tokens: tokens)
		await model.restoreIfNeeded()
		#expect(model.state == .signedOut)
		#expect(tokens.token == nil)
		#expect(model.errorMessage != nil)
	}

	@Test func temporaryFailurePreservesTokenAndAllowsRetry() async {
		let api = API()
		api.profileError = .connection
		let tokens = TokenStore()
		let model = AuthModel(api: api, tokens: tokens)
		await model.restoreIfNeeded()
		await model.submit(email: "test@example.com", password: "password", mode: .signup)
		#expect(model.state == .unavailable)
		#expect(tokens.token == "test-token")
		api.profileError = nil
		await model.restore()
		#expect(model.state == .signedIn(api.user))
	}

	@Test func keychainFailureDoesNotReportSuccessfulLogin() async {
		let api = API()
		let tokens = TokenStore()
		tokens.failSave = true
		let model = AuthModel(api: api, tokens: tokens)
		await model.restoreIfNeeded()
		await model.submit(email: "test@example.com", password: "password", mode: .login)
		#expect(model.state == .signedOut)
		#expect(model.errorMessage == AuthError.keychain.localizedDescription)
	}

	@Test func invalidInputDoesNotCallAPI() async {
		let api = API()
		let model = AuthModel(api: api, tokens: TokenStore())
		await model.restoreIfNeeded()
		await model.submit(email: "", password: "", mode: .login)
		#expect(api.submittedEmail == nil)
		#expect(model.errorMessage != nil)
		await model.submit(
			email: "test@example.com", password: String(repeating: "あ", count: 25),
			mode: .signup)
		#expect(api.submittedEmail == nil)
		#expect(model.errorMessage != nil)
	}
}

private final class StubURLProtocol: URLProtocol {
	static var handler: ((URLRequest) throws -> (Int, Data))?
	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
	override func startLoading() {
		do {
			let (status, data) = try Self.handler!(request)
			let response = HTTPURLResponse(
				url: request.url!, statusCode: status, httpVersion: nil,
				headerFields: nil)!
			client?.urlProtocol(
				self, didReceive: response, cacheStoragePolicy: .notAllowed)
			client?.urlProtocol(self, didLoad: data)
			client?.urlProtocolDidFinishLoading(self)
		} catch { client?.urlProtocol(self, didFailWithError: error) }
	}
	override func stopLoading() {}
}

struct AuthAPITests {
	@Test func endpointsBearerHeaderAndHTTPErrorMapping() async throws {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [StubURLProtocol.self]
		let session = URLSession(configuration: configuration)
		defer {
			session.invalidateAndCancel()
			StubURLProtocol.handler = nil
		}
		let api = AuthAPI(baseURL: URL(string: "https://api.example.com"), session: session)
		for mode in [AuthMode.login, .signup] {
			StubURLProtocol.handler = { request in
				#expect(request.url?.path == "/" + mode.rawValue)
				#expect(request.httpMethod == "POST")
				#expect(
					request.value(forHTTPHeaderField: "Content-Type")
						== "application/json")
				return (200, Data(#"{"token":"api-test-token"}"#.utf8))
			}
			let token: String
			switch mode {
			case .signup:
				token = try await api.signUp(email: "test@example.com", password: "password")
			case .login:
				token = try await api.login(email: "test@example.com", password: "password")
			}
			#expect(token == "api-test-token")
		}
		StubURLProtocol.handler = { request in
			#expect(request.url?.path == "/me")
			#expect(
				request.value(forHTTPHeaderField: "Authorization")
					== "Bearer api-test-token")
			return (200, Data(#"{"id":42,"email":"test@example.com"}"#.utf8))
		}
		let user = try await api.fetchCurrentUser(token: "api-test-token")
		#expect(user.id == 42)
		for status in [400, 401, 409, 500] {
			StubURLProtocol.handler = { _ in (status, Data()) }
			do {
				_ = try await api.login(email: "test@example.com", password: "password")
				Issue.record("HTTP error was accepted")
			} catch let error as AuthError {
				let expected: AuthError =
					switch status {
					case 400: .invalidInput
					case 401: .unauthorized
					case 409: .duplicateEmail
					default: .server
					}
				#expect(error.localizedDescription == expected.localizedDescription)
			}
		}
	}
}
