import Foundation

struct WidgetRouteLink: Equatable {
	let routeID: UUID
	let direction: RouteDirection

	var url: URL? {
		var components = URLComponents()
		components.scheme = "routetap"
		components.host = "route"
		components.queryItems = [
			URLQueryItem(name: "id", value: routeID.uuidString),
			URLQueryItem(name: "direction", value: direction.rawValue),
		]
		return components.url
	}

	init(routeID: UUID, direction: RouteDirection) {
		self.routeID = routeID
		self.direction = direction
	}

	init?(url: URL) {
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
			components.scheme == "routetap", components.host == "route",
			components.path.isEmpty, components.user == nil, components.password == nil,
			components.port == nil, components.fragment == nil,
			let items = components.queryItems, items.count == 2,
			Set(items.map(\.name)) == Set(["id", "direction"]),
			let rawID = items.first(where: { $0.name == "id" })?.value,
			let routeID = UUID(uuidString: rawID),
			let rawDirection = items.first(where: { $0.name == "direction" })?.value,
			let direction = RouteDirection(rawValue: rawDirection)
		else { return nil }
		self.init(routeID: routeID, direction: direction)
	}
}
