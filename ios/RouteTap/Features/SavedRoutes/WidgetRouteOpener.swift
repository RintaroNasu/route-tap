import Combine
import Foundation

@MainActor
final class WidgetRouteOpener: ObservableObject {
	@Published var errorMessage: String?
	private var pendingLink: WidgetRouteLink?
	private let store: any WidgetRouteStoring

	init(store: any WidgetRouteStoring = WidgetRouteStore()) { self.store = store }

	func receive(_ url: URL) {
		if url.scheme == "routetap", url.host == "home" {
			pendingLink = nil
			return
		}
		guard let link = WidgetRouteLink(url: url) else {
			pendingLink = nil
			errorMessage = "ウィジェットのリンクを読み取れませんでした。設定し直してください。"
			return
		}
		pendingLink = link
	}

	func takeURL(accountID: String?, isRestoring: Bool) -> URL? {
		guard !isRestoring, let link = pendingLink else { return nil }
		pendingLink = nil
		guard let accountID else {
			errorMessage = "RouteTapでログインしてから、ウィジェットをもう一度タップしてください。"
			return nil
		}
		guard link.accountID == accountID, let snapshot = store.read(),
			snapshot.accountID == accountID
		else {
			errorMessage = "別のアカウントの移動です。ウィジェットの移動を選び直してください。"
			return nil
		}
		guard let route = snapshot.routes.first(where: { $0.id == link.routeID }) else {
			errorMessage = "この移動は見つかりません。アプリで一覧を更新するか、ウィジェットの移動を選び直してください。"
			return nil
		}
		do { return try GoogleMapsURL.directions(for: route, direction: link.direction) } catch {
			errorMessage = error.localizedDescription
			return nil
		}
	}
}
