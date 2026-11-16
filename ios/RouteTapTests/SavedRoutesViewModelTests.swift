import Foundation
import Testing

@testable import RouteTap

final class TestRouteStore: SavedRouteStoring {
	var routes: [SavedRoute] = []
	var loadError: Error?
	var saveError: Error?
	var saves = 0

	func load() throws -> [SavedRoute] {
		if let loadError { throw loadError }
		return routes
	}

	func save(_ routes: [SavedRoute]) throws {
		if let saveError { throw saveError }
		self.routes = routes
		saves += 1
	}
}

@MainActor
struct SavedRoutesViewModelTests {
	let input = SavedRouteInput(name: "通勤", origin: "大井町駅", destination: "浜松町駅")

	@Test func createsAndReloadsWithoutAuthentication() async throws {
		let store = TestRouteStore()
		let model = SavedRoutesViewModel(store: store)
		await model.load()
		#expect(model.hasLoaded)
		#expect(model.routes.isEmpty)
		#expect(await model.save(input))
		#expect(store.routes == model.routes)
		let reopened = SavedRoutesViewModel(store: store)
		await reopened.load()
		#expect(reopened.routes == model.routes)
		#expect(reopened.loadError == nil)
	}

	@Test func trimsInputsAndAssignsDistinctStableIDs() async throws {
		let store = TestRouteStore()
		let model = SavedRoutesViewModel(store: store)
		#expect(
			await model.save(SavedRouteInput(name: " 通勤　", origin: "　大井町駅 ", destination: "浜松町駅\n"))
		)
		let first = try #require(model.routes.first)
		#expect(first.name == input.name)
		#expect(first.origin == input.origin)
		#expect(first.destination == input.destination)
		#expect(await model.save(input))
		#expect(model.routes.count == 2)
		#expect(model.routes[0].id != first.id)
		#expect(model.routes[1].id == first.id)
	}

	@Test func validatesEmptyFieldsAndUnicodeLengthBeforeWriting() async {
		let store = TestRouteStore()
		let model = SavedRoutesViewModel(store: store)
		for invalid in [
			SavedRouteInput(name: "　", origin: "駅", destination: "駅"),
			SavedRouteInput(name: "名", origin: "", destination: "駅"),
			SavedRouteInput(name: "名", origin: "駅", destination: "\n"),
			SavedRouteInput(
				name: String(repeating: "名", count: 101), origin: "駅", destination: "駅"),
			SavedRouteInput(
				name: "名", origin: String(repeating: "駅", count: 501), destination: "駅"),
			SavedRouteInput(
				name: "名", origin: "駅", destination: String(repeating: "駅", count: 501)),
			SavedRouteInput(
				name: String(repeating: "か\u{3099}", count: 51), origin: "駅", destination: "駅"),
		] {
			#expect(await model.save(invalid) == false)
			#expect(model.saveError != nil)
		}
		#expect(store.saves == 0)
		#expect(
			await model.save(
				SavedRouteInput(
					name: String(repeating: "名", count: 100),
					origin: String(repeating: "駅", count: 500),
					destination: String(repeating: "駅", count: 500))))
	}

	@Test func updatesOnlyTargetAndKeepsItsIDAndPosition() async throws {
		let store = TestRouteStore()
		let model = SavedRoutesViewModel(store: store)
		#expect(await model.save(input))
		let target = try #require(model.routes.first)
		#expect(await model.save(input))
		let other = try #require(model.routes.first)
		#expect(
			await model.save(
				SavedRouteInput(name: "平日通勤", origin: "新宿駅", destination: "渋谷駅"), editing: target))
		#expect(model.routes.map(\.id) == [other.id, target.id])
		#expect(model.routes.last?.name == "平日通勤")
		#expect(store.routes == model.routes)
	}

	@Test func deletesOnlyTargetAndPersistsEmptyList() async throws {
		let store = TestRouteStore()
		let model = SavedRoutesViewModel(store: store)
		#expect(await model.save(input))
		let first = try #require(model.routes.first)
		#expect(await model.save(input))
		let second = try #require(model.routes.first)
		#expect(await model.delete(first))
		#expect(store.routes == [second])
		#expect(await model.delete(second))
		#expect(store.routes.isEmpty)
		#expect(model.routes.isEmpty)
	}

	@Test func failedCreateUpdateAndDeletePreserveListAndAllowRetry() async throws {
		let store = TestRouteStore()
		let model = SavedRoutesViewModel(store: store)
		#expect(await model.save(input))
		let original = model.routes
		let route = try #require(original.first)
		store.saveError = SavedRouteStorageError.writeFailed
		#expect(await model.save(input) == false)
		#expect(await model.save(input, editing: route) == false)
		#expect(model.saveError != nil)
		#expect(await model.delete(route) == false)
		#expect(model.deleteError != nil)
		#expect(model.routes == original)
		#expect(store.routes == original)
		#expect(!model.isBusy)
		store.saveError = nil
		model.clearDeleteError()
		model.clearSaveError()
		#expect(model.deleteError == nil)
		#expect(model.saveError == nil)
		#expect(await model.delete(route))
	}

	@Test func readFailureDoesNotLookLikeEmptyDataOrAllowOverwrite() async throws {
		let store = TestRouteStore()
		let model = SavedRoutesViewModel(store: store)
		store.loadError = SavedRouteStorageError.readFailed
		await model.load()
		#expect(!model.hasLoaded)
		#expect(model.loadError != nil)
		#expect(await model.save(input) == false)
		#expect(store.saves == 0)
		store.loadError = nil
		#expect(await model.save(input))
		let original = model.routes
		let route = try #require(original.first)
		store.loadError = SavedRouteStorageError.readFailed
		await model.load()
		#expect(model.routes == original)
		#expect(model.hasLoaded)
		#expect(await model.delete(route) == false)
		#expect(model.routes == original)
	}

	@Test func staleEditDoesNotResurrectDeletedRoute() async throws {
		let store = TestRouteStore()
		let model = SavedRoutesViewModel(store: store)
		#expect(await model.save(input))
		let deleted = try #require(model.routes.first)
		store.routes = []
		#expect(await model.save(input, editing: deleted) == false)
		#expect(model.saveError == SavedRouteError.notFound.localizedDescription)
		#expect(store.routes.isEmpty)
	}
}
