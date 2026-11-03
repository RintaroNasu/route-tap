import Combine
import Foundation

@MainActor
final class SavedRoutesViewModel: ObservableObject {
	@Published private(set) var routes: [SavedRoute] = []
	@Published private(set) var isLoading = false
	@Published private(set) var isSaving = false
	@Published private(set) var hasLoaded = false
	@Published private(set) var loadError: String?
	@Published private(set) var saveError: String?
	@Published private(set) var sessionExpired = false

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
		guard !isLoading, !isSaving, !sessionExpired else { return }
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

	func save(_ input: SavedRouteInput) async -> Bool {
		guard !isSaving, !isLoading, !sessionExpired else { return false }
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
			let route = try await api.createRoute(input: input, token: token())
			routes.insert(route, at: 0)
			hasLoaded = true
			return true
		} catch is CancellationError {
			return false
		} catch SavedRouteError.unauthorized {
			expireSession()
		} catch {
			saveError = error.localizedDescription
		}
		return false
	}

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
