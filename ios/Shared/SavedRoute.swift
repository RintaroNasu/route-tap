import Foundation

struct SavedRoute: Codable, Identifiable, Equatable {
	let id: UUID
	let name: String
	let origin: String
	let destination: String
}

struct SavedRouteInput: Equatable {
	var name = ""
	var origin = ""
	var destination = ""
}

enum RouteDirection: String, CaseIterable {
	case outbound, inbound

	var title: String { self == .outbound ? "往路" : "復路" }

	func origin(for route: SavedRoute) -> String {
		self == .outbound ? route.origin : route.destination
	}

	func destination(for route: SavedRoute) -> String {
		self == .outbound ? route.destination : route.origin
	}
}
