import Combine
import Foundation

@MainActor
final class SavedRoutesViewModel: ObservableObject {
	@Published private(set) var routes: [SavedRoute] = []
	@Published private(set) var isLoading = false
	@Published private(set) var isSaving = false
	@Published private(set) var deletingRouteID: UUID?
	@Published private(set) var deleteError: String?
	@Published private(set) var hasLoaded = false
	@Published private(set) var loadError: String?
	@Published private(set) var saveError: String?

	var isBusy: Bool { isLoading || isSaving || deletingRouteID != nil }
	private let store: any SavedRouteStoring

	init(store: any SavedRouteStoring = SavedRouteStore()) { self.store = store }

	func load() async {
		guard !isBusy else { return }
		isLoading = true
		loadError = nil
		defer { isLoading = false }
		do {
			routes = try store.load()
			hasLoaded = true
		} catch {
			loadError = error.localizedDescription
		}
	}

	func save(_ input: SavedRouteInput, editing route: SavedRoute? = nil) async -> Bool {
		guard !isBusy else { return false }
		saveError = nil
		let input = SavedRouteInput(
			name: input.name.trimmingCharacters(in: .whitespacesAndNewlines),
			origin: input.origin.trimmingCharacters(in: .whitespacesAndNewlines),
			destination: input.destination.trimmingCharacters(in: .whitespacesAndNewlines))
		if let message = validationMessage(for: input) {
			saveError = message
			return false
		}
		isSaving = true
		defer { isSaving = false }
		do {
			var latest = try store.load()
			let saved = SavedRoute(
				id: route?.id ?? UUID(), name: input.name,
				origin: input.origin, destination: input.destination)
			if let route {
				guard let index = latest.firstIndex(where: { $0.id == route.id }) else {
					throw SavedRouteError.notFound
				}
				latest[index] = saved
			} else {
				latest.insert(saved, at: 0)
			}
			try store.save(latest)
			routes = latest
			hasLoaded = true
			loadError = nil
			return true
		} catch {
			saveError = error.localizedDescription
			return false
		}
	}

	func delete(_ route: SavedRoute) async -> Bool {
		guard !isBusy else { return false }
		deletingRouteID = route.id
		deleteError = nil
		defer { deletingRouteID = nil }
		do {
			var latest = try store.load()
			latest.removeAll { $0.id == route.id }
			try store.save(latest)
			routes = latest
			hasLoaded = true
			loadError = nil
			return true
		} catch {
			deleteError = error.localizedDescription
			return false
		}
	}

	func clearDeleteError() { deleteError = nil }
	func clearSaveError() { saveError = nil }

	private func validationMessage(for input: SavedRouteInput) -> String? {
		if input.name.isEmpty { return "表示名を入力してください。" }
		if input.origin.isEmpty { return "出発地を入力してください。" }
		if input.destination.isEmpty { return "目的地を入力してください。" }
		if input.name.unicodeScalars.count > 100 { return "表示名は100文字以内で入力してください。" }
		if input.origin.unicodeScalars.count > 500 { return "出発地は500文字以内で入力してください。" }
		if input.destination.unicodeScalars.count > 500 { return "目的地は500文字以内で入力してください。" }
		return nil
	}
}
