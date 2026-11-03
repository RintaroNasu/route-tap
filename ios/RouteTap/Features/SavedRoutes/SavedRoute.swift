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
