import Foundation

struct WidgetRouteLink: Equatable {
	let accountID: String
	let routeID: UInt
	let direction: RouteDirection

	var url: URL? {
		var components = URLComponents()
		components.scheme = "routetap"
		components.host = "route"
		components.queryItems = [
			URLQueryItem(name: "account", value: accountID),
			URLQueryItem(name: "id", value: String(routeID)),
			URLQueryItem(name: "direction", value: direction.rawValue),
		]
		return components.url
	}

	init(accountID: String, routeID: UInt, direction: RouteDirection) {
		self.accountID = accountID
		self.routeID = routeID
		self.direction = direction
	}

	init?(url: URL) {
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
			components.scheme == "routetap", components.host == "route",
			components.path.isEmpty, components.user == nil, components.password == nil,
			components.port == nil, components.fragment == nil,
			let items = components.queryItems, items.count == 3,
			Set(items.map(\.name)) == Set(["account", "id", "direction"]),
			let accountID = items.first(where: { $0.name == "account" })?.value, !accountID.isEmpty,
			let rawID = items.first(where: { $0.name == "id" })?.value,
			let routeID = UInt(rawID), routeID > 0,
			let rawDirection = items.first(where: { $0.name == "direction" })?.value,
			let direction = RouteDirection(rawValue: rawDirection)
		else { return nil }
		self.init(accountID: accountID, routeID: routeID, direction: direction)
	}
}
