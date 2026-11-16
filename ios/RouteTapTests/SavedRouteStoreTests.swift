import Foundation
import Testing

@testable import RouteTap

struct SavedRouteStoreTests {
	private func route(_ name: String = "通勤") -> SavedRoute {
		SavedRoute(id: UUID(), name: name, origin: "大井町駅", destination: "浜松町駅")
	}

	@Test func persistsAcrossStoreInstancesAndKeepsIDsAndOrder() throws {
		let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: file) }
		let routes = [route(), route("帰宅")]
		var reloads = 0
		let store = SavedRouteStore(fileURL: file, reloadWidgets: { reloads += 1 })
		#expect(try store.load().isEmpty)
		try store.save(routes)
		#expect(reloads == 1)
		let reopened = SavedRouteStore(fileURL: file, reloadWidgets: {})
		#expect(try reopened.load() == routes)
		try reopened.save([])
		#expect(try store.load().isEmpty)
	}

	@Test func malformedOrUnsupportedDataIsNeverOverwritten() throws {
		let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: file) }
		for text in ["broken", "{\"version\":2,\"routes\":[]}", "{}"] {
			let original = Data(text.utf8)
			try original.write(to: file)
			var reloads = 0
			let store = SavedRouteStore(fileURL: file, reloadWidgets: { reloads += 1 })
			#expect(throws: SavedRouteStorageError.self) { try store.load() }
			#expect(throws: SavedRouteStorageError.self) { try store.save([]) }
			#expect(try Data(contentsOf: file) == original)
			#expect(reloads == 0)
		}
	}

	@Test func failedWriteDoesNotPublishOrReplaceSavedData() throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
			UUID().uuidString)
		// 存在しない親ディレクトリへの書き込みを失敗させる。
		let file = directory.appendingPathComponent("routes.json")
		var reloads = 0
		let store = SavedRouteStore(fileURL: file, reloadWidgets: { reloads += 1 })
		#expect(throws: SavedRouteStorageError.self) { try store.save([route()]) }
		#expect(!FileManager.default.fileExists(atPath: file.path))
		#expect(reloads == 0)
	}

	@Test func missingAppGroupDoesNotFallBackToAnotherLocation() {
		let store = SavedRouteStore(fileURL: nil, reloadWidgets: {})
		#expect(throws: SavedRouteStorageError.self) { try store.load() }
		#expect(throws: SavedRouteStorageError.self) { try store.save([]) }
	}

	@Test func duplicateIDsCannotOverwriteGoodData() throws {
		let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: file) }
		let store = SavedRouteStore(fileURL: file, reloadWidgets: {})
		let saved = route()
		try store.save([saved])
		#expect(throws: SavedRouteStorageError.self) { try store.save([saved, saved]) }
		#expect(try store.load() == [saved])
	}

	@Test func legacyWidgetCacheIsNotImported() throws {
		let suite = "RouteTapTests.\(UUID())"
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer { defaults.removePersistentDomain(forName: suite) }
		defaults.set(Data("old authenticated cache".utf8), forKey: "saved-route-widget-snapshot")
		let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let store = SavedRouteStore(fileURL: file, reloadWidgets: {})
		#expect(try store.load().isEmpty)
	}
}
