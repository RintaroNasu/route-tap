import Foundation
import WidgetKit

struct WidgetRouteSnapshot: Codable, Equatable {
	let accountID: String
	var routes: [SavedRoute]

	func entityID(for route: SavedRoute) -> String { "\(accountID)#\(route.id)" }
}

protocol WidgetRouteStoring {
	func read() -> WidgetRouteSnapshot?
	func beginSession(accountID: String)
	func save(_ routes: [SavedRoute], accountID: String)
	func clear()
}

struct WidgetRouteStore: WidgetRouteStoring {
	static let groupID = "group.com.rintaro.RouteTap"
	static let widgetKind = "RouteTapRouteWidget"
	private let key = "saved-route-widget-snapshot"
	private let defaults: UserDefaults?
	private let reload: () -> Void

	init(
		defaults: UserDefaults? = UserDefaults(suiteName: groupID),
		reload: @escaping () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: widgetKind) }
	) {
		self.defaults = defaults
		self.reload = reload
	}

	func read() -> WidgetRouteSnapshot? {
		guard let data = defaults?.data(forKey: key) else { return nil }
		return try? JSONDecoder().decode(WidgetRouteSnapshot.self, from: data)
	}

	func beginSession(accountID: String) {
		guard read()?.accountID != accountID else { return }
		write(WidgetRouteSnapshot(accountID: accountID, routes: []))
	}

	func save(_ routes: [SavedRoute], accountID: String) {
		// ログアウト後に古い通信が完了しても、データを復活させない。
		guard read()?.accountID == accountID else { return }
		write(WidgetRouteSnapshot(accountID: accountID, routes: routes))
	}

	func clear() {
		defaults?.removeObject(forKey: key)
		reload()
	}

	private func write(_ snapshot: WidgetRouteSnapshot) {
		guard let data = try? JSONEncoder().encode(snapshot) else { return }
		defaults?.set(data, forKey: key)
		reload()
	}
}
