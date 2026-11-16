import Combine
import Foundation

@MainActor
final class WidgetRouteOpener: ObservableObject {
	@Published var errorMessage: String?
	private let store: any SavedRouteStoring

	init(store: any SavedRouteStoring = SavedRouteStore()) { self.store = store }

	func destination(for url: URL) -> URL? {
		errorMessage = nil
		if url.scheme == "routetap", url.host == "home" { return nil }
		guard let link = WidgetRouteLink(url: url) else {
			errorMessage = "ウィジェットのリンクを読み取れませんでした。移動を選び直してください。"
			return nil
		}
		do {
			guard let route = try store.load().first(where: { $0.id == link.routeID }) else {
				errorMessage = "この移動は見つかりません。ウィジェットの移動を選び直してください。"
				return nil
			}
			return try GoogleMapsURL.directions(for: route, direction: link.direction)
		} catch {
			errorMessage = error.localizedDescription
			return nil
		}
	}
}
