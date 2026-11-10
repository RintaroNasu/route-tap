import Foundation
import Testing

@testable import RouteTap

@MainActor
struct AccountDeletionTests {
	private typealias API = RouteTapTests.API
	private typealias Tokens = RouteTapTests.TokenStore

	@Test func successfulDeletionClearsSession() async {
		let api = API()
		let tokens = Tokens()
		tokens.token = "saved-token"
		let model = AuthViewModel(api: api, tokens: tokens)
		await model.restoreIfNeeded()
		await model.deleteAccount()
		#expect(api.deleteCount == 1)
		#expect(api.deletedToken == "saved-token")
		#expect(tokens.token == nil)
		#expect(model.state == .signedOut)
		#expect(model.errorMessage == nil)
		#expect(!model.isBusy && !model.isDeletingAccount)
	}

	@Test func failurePreservesSessionAndAllowsRetry() async {
		for error in [AuthError.connection, .server] {
			let api = API()
			let tokens = Tokens()
			tokens.token = "saved-token"
			let model = AuthViewModel(api: api, tokens: tokens)
			await model.restoreIfNeeded()
			api.deleteError = error
			await model.deleteAccount()
			#expect(model.state == .signedIn(api.user))
			#expect(tokens.token == "saved-token")
			#expect(model.errorMessage == error.localizedDescription)
			#expect(!model.isBusy && !model.isDeletingAccount)
			api.deleteError = nil
			await model.deleteAccount()
			#expect(model.state == .signedOut)
			#expect(api.deleteCount == 2)
		}
	}

	@Test func unauthorizedDeletionExpiresSession() async {
		let api = API()
		let tokens = Tokens()
		tokens.token = "expired-token"
		let model = AuthViewModel(api: api, tokens: tokens)
		await model.restoreIfNeeded()
		api.deleteError = AuthError.unauthorized
		await model.deleteAccount()
		#expect(model.state == .signedOut)
		#expect(tokens.token == nil)
		#expect(model.errorMessage == "ログインの有効期限が切れました。再度ログインしてください。")
	}

	@Test func cleanupFailureHidesDeletedAccountAndRetriesOnlyKeychain() async {
		let api = API()
		let tokens = Tokens()
		tokens.token = "saved-token"
		let model = AuthViewModel(api: api, tokens: tokens)
		await model.restoreIfNeeded()
		tokens.failDelete = true
		await model.deleteAccount()
		#expect(model.state == .accountDeleted)
		#expect(model.errorMessage != nil)
		#expect(tokens.token == "saved-token")
		await model.restore()
		await model.deleteAccount()
		#expect(model.state == .accountDeleted)
		model.retryAccountCleanup()
		#expect(model.state == .accountDeleted)
		tokens.failDelete = false
		model.retryAccountCleanup()
		#expect(model.state == .signedOut)
		#expect(tokens.token == nil)
		#expect(api.deleteCount == 1)
	}

	@Test func deletionBlocksDuplicateRequestsAndLogout() async {
		let api = API()
		let tokens = Tokens()
		tokens.token = "saved-token"
		let model = AuthViewModel(api: api, tokens: tokens)
		await model.restoreIfNeeded()
		var continuation: CheckedContinuation<Void, Never>?
		api.beforeDelete = { await withCheckedContinuation { continuation = $0 } }
		let deletion = Task { await model.deleteAccount() }
		while continuation == nil { await Task.yield() }
		#expect(model.isBusy && model.isDeletingAccount)
		await model.deleteAccount()
		model.logout()
		await model.submit(email: "other@example.com", password: "password", mode: .login)
		#expect(api.deleteCount == 1)
		#expect(api.submittedEmail == nil)
		#expect(tokens.token == "saved-token")
		continuation?.resume()
		await deletion.value
		#expect(model.state == .signedOut)
	}

	@Test func cancellationAndSignedOutDoNotDeleteLocalSession() async {
		let api = API()
		let tokens = Tokens()
		let model = AuthViewModel(api: api, tokens: tokens)
		await model.restoreIfNeeded()
		await model.deleteAccount()
		#expect(api.deleteCount == 0)
		tokens.token = "saved-token"
		await model.restore()
		api.deleteError = CancellationError()
		await model.deleteAccount()
		#expect(model.state == .signedIn(api.user))
		#expect(tokens.token == "saved-token")
		#expect(model.errorMessage == nil)
		#expect(!model.isBusy && !model.isDeletingAccount)
	}
}
