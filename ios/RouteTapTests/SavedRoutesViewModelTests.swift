import Foundation
import Testing

@testable import RouteTap

@MainActor
struct SavedRoutesViewModelTests {
	final class Tokens: TokenStoring {
		var token: String? = "saved-token"
		var readError: Error?
		func read() throws -> String? {
			if let readError { throw readError }
			return token
		}
		func save(_ token: String) throws { self.token = token }
		func delete() throws { token = nil }
	}

	final class API: SavedRouteServicing {
		var routes: [SavedRoute] = []
		var fetchError: Error?
		var createError: Error?
		var fetchedToken: String?
		var createdToken: String?
		var submittedInput: SavedRouteInput?
		var createCount = 0
		var beforeCreate: (() async -> Void)?
		let createdRoute = SavedRoute(id: 12, name: "通勤", origin: "大井町駅", destination: "浜松町駅")

		func fetchRoutes(token: String) async throws -> [SavedRoute] {
			fetchedToken = token
			if let fetchError { throw fetchError }
			return routes
		}

		func createRoute(input: SavedRouteInput, token: String) async throws -> SavedRoute {
			createCount += 1
			submittedInput = input
			createdToken = token
			await beforeCreate?()
			if let createError { throw createError }
			return createdRoute
		}
	}

	let validInput = SavedRouteInput(name: "通勤", origin: "大井町駅", destination: "浜松町駅")

	@Test func loadUsesSavedTokenAndReturnsRoutes() async {
		let api = API()
		api.routes = [api.createdRoute]
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		#expect(api.fetchedToken == "saved-token")
		#expect(model.routes == api.routes)
		#expect(model.hasLoaded)
		#expect(!model.isLoading)
		#expect(model.loadError == nil)
	}

	@Test func emptyListIsACompletedLoad() async {
		let model = SavedRoutesViewModel(api: API(), tokens: Tokens())
		await model.load()
		#expect(model.routes.isEmpty)
		#expect(model.hasLoaded)
	}

	@Test func saveTrimsInputAndInsertsSuccessfulResponseAtTop() async {
		let api = API()
		let oldRoute = SavedRoute(id: 1, name: "帰宅", origin: "浜松町駅", destination: "大井町駅")
		api.routes = [oldRoute]
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		let saved = await model.save(
			SavedRouteInput(name: " 通勤　", origin: "　大井町駅 ", destination: "浜松町駅\n"))
		#expect(saved)
		#expect(api.submittedInput == validInput)
		#expect(api.createdToken == "saved-token")
		#expect(model.routes == [api.createdRoute, oldRoute])
		#expect(!model.isSaving)
	}

	@Test func invalidInputDoesNotSendRequest() async {
		let inputs = [
			SavedRouteInput(name: "　", origin: "大井町駅", destination: "浜松町駅"),
			SavedRouteInput(name: "通勤", origin: "", destination: "浜松町駅"),
			SavedRouteInput(name: "通勤", origin: "大井町駅", destination: " "),
			SavedRouteInput(
				name: String(repeating: "名", count: 101), origin: "駅", destination: "駅"),
			SavedRouteInput(
				name: "通勤", origin: String(repeating: "駅", count: 501), destination: "駅"),
			SavedRouteInput(
				name: "通勤", origin: "駅", destination: String(repeating: "駅", count: 501)),
		]
		for input in inputs {
			let api = API()
			let model = SavedRoutesViewModel(api: api, tokens: Tokens())
			let saved = await model.save(input)
			#expect(!saved)
			#expect(api.createCount == 0)
			#expect(model.saveError != nil)
		}
	}

	@Test func unicodeLengthUsesTheSameUnitsAsGo() async {
		let api = API()
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		let input = SavedRouteInput(
			name: String(repeating: "か\u{3099}", count: 51), origin: "駅", destination: "駅")
		#expect(input.name.count == 51)
		#expect(input.name.unicodeScalars.count == 102)
		#expect(await model.save(input) == false)
		#expect(api.createCount == 0)
		#expect(model.saveError == "表示名は100文字以内で入力してください。")
	}

	@Test func exactLengthLimitsAreAccepted() async {
		let api = API()
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		let input = SavedRouteInput(
			name: String(repeating: "名", count: 100), origin: String(repeating: "駅", count: 500),
			destination: String(repeating: "先", count: 500))
		#expect(await model.save(input))
		#expect(api.createCount == 1)
	}

	@Test func failedSaveDoesNotInsertAndCanBeRetried() async {
		let api = API()
		api.createError = SavedRouteError.connection
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		#expect(await model.save(validInput) == false)
		#expect(model.routes.isEmpty)
		#expect(model.saveError == SavedRouteError.connection.localizedDescription)
		#expect(!model.isSaving)
		model.clearSaveError()
		#expect(model.saveError == nil)
		api.createError = nil
		#expect(await model.save(validInput))
		#expect(model.routes == [api.createdRoute])
	}

	@Test func refreshFailurePreservesPreviouslyLoadedRoutesAndAllowsRetry() async {
		let api = API()
		api.routes = [api.createdRoute]
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		api.fetchError = SavedRouteError.server
		await model.load()
		#expect(model.routes == [api.createdRoute])
		#expect(model.hasLoaded)
		#expect(model.loadError == SavedRouteError.server.localizedDescription)
		#expect(!model.isLoading)
		api.fetchError = nil
		await model.load()
		#expect(model.loadError == nil)
	}

	@Test func failedInitialLoadDoesNotLookLikeAnEmptyList() async {
		let api = API()
		api.fetchError = SavedRouteError.connection
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		#expect(!model.hasLoaded)
		#expect(model.loadError != nil)
	}

	@Test func unauthorizedRefreshRemovesVisibleRoutes() async {
		let api = API()
		api.routes = [api.createdRoute]
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		api.fetchError = SavedRouteError.unauthorized
		await model.load()
		#expect(model.routes.isEmpty)
		#expect(model.sessionExpired)
	}

	@Test func missingTokenAndUnauthorizedSaveExpireSession() async {
		let tokens = Tokens()
		tokens.token = nil
		let api = API()
		let model = SavedRoutesViewModel(api: api, tokens: tokens)
		await model.load()
		#expect(model.sessionExpired)
		#expect(api.fetchedToken == nil)

		api.createError = SavedRouteError.unauthorized
		let saveModel = SavedRoutesViewModel(api: api, tokens: Tokens())
		#expect(await saveModel.save(validInput) == false)
		#expect(saveModel.sessionExpired)
		#expect(saveModel.routes.isEmpty)
	}

	@Test func keychainReadFailureDoesNotSendRequest() async {
		let tokens = Tokens()
		tokens.readError = AuthError.keychain
		let api = API()
		let model = SavedRoutesViewModel(api: api, tokens: tokens)
		await model.load()
		#expect(api.fetchedToken == nil)
		#expect(model.loadError == AuthError.keychain.localizedDescription)
	}

	@Test func cancellationDoesNotShowAnError() async {
		let api = API()
		api.fetchError = CancellationError()
		api.createError = CancellationError()
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		#expect(model.loadError == nil)
		#expect(await model.save(validInput) == false)
		#expect(model.saveError == nil)
		#expect(!model.isSaving)
	}

	@Test func savingPreventsDuplicateRequestsAndConcurrentRefresh() async {
		let api = API()
		var continuation: CheckedContinuation<Void, Never>?
		api.beforeCreate = {
			await withCheckedContinuation { continuation = $0 }
		}
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		let task = Task { await model.save(validInput) }
		while continuation == nil { await Task.yield() }
		#expect(model.isSaving)
		#expect(await model.save(validInput) == false)
		await model.load()
		#expect(api.fetchedToken == nil)
		#expect(api.createCount == 1)
		continuation?.resume()
		#expect(await task.value)
		#expect(!model.isSaving)
	}

	@Test func sessionExpiryRemovesTokenAndReturnsToLogin() {
		let tokens = Tokens()
		let model = AuthViewModel(api: RouteTapTests.API(), tokens: tokens)
		model.expireSession()
		#expect(tokens.token == nil)
		#expect(model.state == .signedOut)
		#expect(model.errorMessage == "ログインの有効期限が切れました。再度ログインしてください。")
	}
}
