import Combine
import Foundation

@MainActor
final class SavedRoutesViewModel: ObservableObject {
	@Published private(set) var routes: [SavedRoute] = []
	@Published private(set) var isLoading = false
	@Published private(set) var isSaving = false
	@Published private(set) var deletingRouteID: UInt?
	@Published private(set) var deleteError: String?
	@Published private(set) var hasLoaded = false
	@Published private(set) var loadError: String?
	@Published private(set) var saveError: String?
	@Published private(set) var sessionExpired = false

	var isBusy: Bool { isLoading || isSaving || deletingRouteID != nil }

	private let api: any SavedRouteServicing
	private let tokens: any TokenStoring

	init(
		api: any SavedRouteServicing = SavedRouteAPI(),
		tokens: any TokenStoring = KeychainTokenStore()
	) {
		self.api = api
		self.tokens = tokens
	}

	func load() async {
		guard !isBusy, !sessionExpired else { return }
		isLoading = true
		loadError = nil
		defer { isLoading = false }
		do {
			routes = try await api.fetchRoutes(token: token())
			hasLoaded = true
		} catch is CancellationError {
			return
		} catch SavedRouteError.unauthorized {
			expireSession()
		} catch {
			loadError = error.localizedDescription
		}
	}

	func save(_ input: SavedRouteInput, editing route: SavedRoute? = nil) async -> Bool {
		guard !isBusy, !sessionExpired else { return false }
		saveError = nil
		let input = SavedRouteInput(
			name: input.name.trimmingCharacters(in: .whitespacesAndNewlines),
			origin: input.origin.trimmingCharacters(in: .whitespacesAndNewlines),
			destination: input.destination.trimmingCharacters(in: .whitespacesAndNewlines)
		)
		if let message = validationMessage(for: input) {
			saveError = message
			return false
		}
		isSaving = true
		defer { isSaving = false }
		do {
			if let route {
				let updated = try await api.updateRoute(id: route.id, input: input, token: token())
				if let index = routes.firstIndex(where: { $0.id == route.id }) {
					routes[index] = updated
				} else {
					isSaving = false
					await load()
				}
			} else {
				let created = try await api.createRoute(input: input, token: token())
				routes.insert(created, at: 0)
				hasLoaded = true
			}
			return true
		} catch is CancellationError {
			return false
		} catch SavedRouteError.unauthorized {
			expireSession()
		} catch SavedRouteError.notFound {
			saveError = SavedRouteError.notFound.localizedDescription
			if route != nil {
				isSaving = false
				await load()
			}
		} catch {
			saveError = error.localizedDescription
		}
		return false
	}

	func delete(_ route: SavedRoute) async -> Bool {
		guard !isBusy, !sessionExpired else { return false }
		deletingRouteID = route.id
		deleteError = nil
		defer { deletingRouteID = nil }
		do {
			try await api.deleteRoute(id: route.id, token: token())
			routes.removeAll { $0.id == route.id }
			return true
		} catch is CancellationError {
			return false
		} catch SavedRouteError.unauthorized {
			expireSession()
		} catch SavedRouteError.notFound {
			deleteError = SavedRouteError.notFound.localizedDescription
			deletingRouteID = nil
			await load()
		} catch {
			deleteError = error.localizedDescription
		}
		return false
	}

	func clearDeleteError() { deleteError = nil }

	func clearSaveError() {
		saveError = nil
	}

	private func token() throws -> String {
		guard let token = try tokens.read(), !token.isEmpty else {
			throw SavedRouteError.unauthorized
		}
		return token
	}

	private func expireSession() {
		routes = []
		loadError = nil
		saveError = nil
		deleteError = nil
		sessionExpired = true
	}

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
