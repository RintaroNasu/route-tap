import Foundation
import Testing

@testable import RouteTap

@MainActor
struct SavedRouteEditDeleteTests {
	private typealias API = SavedRoutesViewModelTests.API
	private typealias Tokens = SavedRoutesViewModelTests.Tokens
	private let target = SavedRoute(id: 1, name: "通勤", origin: "大井町駅", destination: "浜松町駅")
	private let other = SavedRoute(id: 2, name: "休日", origin: "渋谷駅", destination: "新宿駅")
	private let input = SavedRouteInput(name: " 平日通勤　", origin: " 大井町駅 ", destination: "浜松町駅\n")

	@Test func updateNormalizesInputAndReplacesOnlyTargetWithoutReordering() async {
		let api = API()
		api.routes = [other, target]
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		#expect(await model.save(input, editing: target))
		#expect(api.updatedID == target.id)
		#expect(api.updatedToken == "saved-token")
		#expect(
			api.updatedInput == SavedRouteInput(name: "平日通勤", origin: "大井町駅", destination: "浜松町駅"))
		#expect(api.createCount == 0)
		#expect(
			model.routes == [
				other, SavedRoute(id: 1, name: "平日通勤", origin: "大井町駅", destination: "浜松町駅"),
			])
		#expect(!model.isBusy)
	}

	@Test func updateUsesTheSameInputValidationAsRegistration() async {
		let inputs = [
			SavedRouteInput(name: "　", origin: "駅", destination: "駅"),
			SavedRouteInput(name: "通勤", origin: " ", destination: "駅"),
			SavedRouteInput(name: "通勤", origin: "駅", destination: ""),
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
			#expect(await model.save(input, editing: target) == false)
			#expect(api.updateCount == 0)
			#expect(model.saveError != nil)
		}
	}

	@Test func failedUpdateKeepsListAndCanBeRetried() async {
		let api = API()
		api.routes = [target, other]
		api.updateError = SavedRouteError.connection
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		#expect(await model.save(input, editing: target) == false)
		#expect(model.routes == [target, other])
		#expect(model.saveError == SavedRouteError.connection.localizedDescription)
		#expect(!model.isSaving)
		api.updateError = nil
		#expect(await model.save(input, editing: target))
		#expect(model.saveError == nil)
	}

	@Test func missingUpdateRefreshesListAndReportsNotFound() async {
		let api = API()
		api.routes = [target, other]
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		api.routes = [other]
		api.updateError = SavedRouteError.notFound
		#expect(await model.save(input, editing: target) == false)
		#expect(model.routes == [other])
		#expect(api.fetchCount == 2)
		#expect(model.saveError == SavedRouteError.notFound.localizedDescription)
		#expect(!model.isBusy)
	}

	@Test func successfulUpdateWithMissingLocalEntryRefreshesList() async {
		let api = API()
		api.routes = [target, other]
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		#expect(await model.save(input, editing: target))
		#expect(api.fetchCount == 1)
		#expect(model.routes == api.routes)
		#expect(!model.isBusy)
	}

	@Test func deleteRemovesOnlyTargetAndSupportsAnEmptyList() async {
		let api = API()
		api.routes = [target, other]
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		#expect(await model.delete(target))
		#expect(model.routes == [other])
		#expect(api.deletedID == target.id)
		#expect(api.deletedToken == "saved-token")
		#expect(await model.delete(other))
		#expect(model.routes.isEmpty)
		#expect(model.hasLoaded)
		#expect(model.deletingRouteID == nil)
	}

	@Test func failedDeleteKeepsCardAndCanBeRetried() async {
		let api = API()
		api.routes = [target]
		api.deleteError = SavedRouteError.server
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		#expect(await model.delete(target) == false)
		#expect(model.routes == [target])
		#expect(model.deleteError == SavedRouteError.server.localizedDescription)
		#expect(!model.isBusy)
		model.clearDeleteError()
		#expect(model.deleteError == nil)
		api.deleteError = nil
		#expect(await model.delete(target))
		#expect(model.routes.isEmpty)
	}

	@Test func missingDeleteRefreshesListAndReportsNotFound() async {
		let api = API()
		api.routes = [target]
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		api.routes = []
		api.deleteError = SavedRouteError.notFound
		#expect(await model.delete(target) == false)
		#expect(model.routes.isEmpty)
		#expect(api.fetchCount == 2)
		#expect(model.deleteError == SavedRouteError.notFound.localizedDescription)
		#expect(!model.isBusy)
	}

	@Test func notFoundWithFailedRefreshRetainsListAndReportsBothErrors() async {
		let api = API()
		api.routes = [target]
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		api.deleteError = SavedRouteError.notFound
		api.fetchError = SavedRouteError.connection
		#expect(await model.delete(target) == false)
		#expect(model.routes == [target])
		#expect(model.deleteError == SavedRouteError.notFound.localizedDescription)
		#expect(model.loadError == SavedRouteError.connection.localizedDescription)
		#expect(!model.isBusy)
	}

	@Test func unauthorizedMutationsExpireSession() async {
		for update in [true, false] {
			let api = API()
			api.routes = [target]
			api.updateError = SavedRouteError.unauthorized
			api.deleteError = SavedRouteError.unauthorized
			let model = SavedRoutesViewModel(api: api, tokens: Tokens())
			await model.load()
			if update {
				#expect(await model.save(input, editing: target) == false)
			} else {
				#expect(await model.delete(target) == false)
			}
			#expect(model.sessionExpired)
			#expect(model.routes.isEmpty)
			#expect(model.deleteError == nil)
			#expect(!model.isBusy)
		}
	}

	@Test func cancelledMutationsDoNotShowErrorsOrChangeList() async {
		let api = API()
		api.routes = [target]
		api.updateError = CancellationError()
		api.deleteError = CancellationError()
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		#expect(await model.save(input, editing: target) == false)
		#expect(await model.delete(target) == false)
		#expect(model.routes == [target])
		#expect(model.saveError == nil)
		#expect(model.deleteError == nil)
	}

	@Test func updatingBlocksOtherMutationsAndRefresh() async {
		let api = API()
		api.routes = [target]
		var continuation: CheckedContinuation<Void, Never>?
		api.beforeUpdate = { await withCheckedContinuation { continuation = $0 } }
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		let task = Task { await model.save(input, editing: target) }
		while continuation == nil { await Task.yield() }
		#expect(model.isSaving)
		#expect(await model.save(input, editing: target) == false)
		#expect(await model.save(input) == false)
		#expect(await model.delete(target) == false)
		await model.load()
		#expect(api.fetchCount == 1)
		#expect(api.updateCount == 1)
		#expect(api.deleteCount == 0)
		continuation?.resume()
		#expect(await task.value)
	}

	@Test func deletingBlocksOtherMutationsAndRefresh() async {
		let api = API()
		api.routes = [target]
		var continuation: CheckedContinuation<Void, Never>?
		api.beforeDelete = { await withCheckedContinuation { continuation = $0 } }
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		await model.load()
		let task = Task { await model.delete(target) }
		while continuation == nil { await Task.yield() }
		#expect(model.deletingRouteID == target.id)
		#expect(await model.delete(target) == false)
		#expect(await model.save(input, editing: target) == false)
		#expect(await model.save(input) == false)
		await model.load()
		#expect(api.fetchCount == 1)
		#expect(api.deleteCount == 1)
		#expect(api.updateCount == 0)
		continuation?.resume()
		#expect(await task.value)
	}

	@Test func loadingBlocksMutationsUntilFetchFinishes() async {
		let api = API()
		api.routes = [target]
		var continuation: CheckedContinuation<Void, Never>?
		api.beforeFetch = { await withCheckedContinuation { continuation = $0 } }
		let model = SavedRoutesViewModel(api: api, tokens: Tokens())
		let task = Task { await model.load() }
		while continuation == nil { await Task.yield() }
		#expect(await model.save(input, editing: target) == false)
		#expect(await model.delete(target) == false)
		#expect(api.updateCount == 0)
		#expect(api.deleteCount == 0)
		continuation?.resume()
		await task.value
		#expect(model.routes == [target])
	}
}
