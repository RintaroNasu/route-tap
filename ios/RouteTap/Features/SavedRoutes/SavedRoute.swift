import Foundation

struct SavedRoute: Decodable, Identifiable, Equatable {
	let id: UInt
	let name: String
	let origin: String
	let destination: String
}

struct SavedRouteInput: Encodable, Equatable {
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
