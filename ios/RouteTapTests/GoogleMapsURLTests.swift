import Foundation
import Testing

@testable import RouteTap

struct GoogleMapsURLTests {
	@Test func buildsPublicTransitDirectionsWithJapanesePlaces() throws {
		let origin = "大井町駅、東京都品川区"
		let destination = "浜松町駅、東京都港区"
		let url = try GoogleMapsURL.directions(origin: origin, destination: destination)
		let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
		#expect(components.scheme == "https")
		#expect(components.host == "www.google.com")
		#expect(components.path == "/maps/dir/")
		let items = try #require(components.queryItems)
		#expect(items.count == 4)
		#expect(items.first { $0.name == "api" }?.value == "1")
		#expect(items.first { $0.name == "origin" }?.value == origin)
		#expect(items.first { $0.name == "destination" }?.value == destination)
		#expect(items.first { $0.name == "travelmode" }?.value == "transit")
		#expect(url.absoluteString.contains("%E5"))
	}

	@Test func preservesSpacesAndReservedCharactersAsPlaceText() throws {
		let origin = "C++ Cafe, 東京 & 駅 #1?travelmode=driving"
		let destination = "A/B + 100% ビル=入口"
		let url = try GoogleMapsURL.directions(origin: origin, destination: destination)
		let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
		let items = try #require(components.queryItems)
		#expect(items.count == 4)
		#expect(items.first { $0.name == "origin" }?.value == origin)
		#expect(items.first { $0.name == "destination" }?.value == destination)
		#expect(items.first { $0.name == "travelmode" }?.value == "transit")
		#expect(components.fragment == nil)
		#expect(!url.absoluteString.contains("+"))
		#expect(url.absoluteString.contains("%2B"))
		#expect(url.absoluteString.contains("%2C"))
		#expect(url.absoluteString.contains("%26"))
		#expect(url.absoluteString.contains("%23"))
		#expect(url.absoluteString.contains("%20"))
	}

	@Test func trimsOuterWhitespaceAndRequiresBothPlaces() throws {
		let url = try GoogleMapsURL.directions(origin: "　大井町駅 ", destination: " 浜松町駅\n")
		let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
		#expect(components.queryItems?.first { $0.name == "origin" }?.value == "大井町駅")
		#expect(components.queryItems?.first { $0.name == "destination" }?.value == "浜松町駅")
		for (origin, destination) in [("", "駅"), ("　", "駅"), ("駅", "\n")] {
			#expect(throws: GoogleMapsURLError.missingPlace) {
				try GoogleMapsURL.directions(origin: origin, destination: destination)
			}
		}
	}

	@Test func checksEncodedLengthWithoutTruncatingPlaces() throws {
		let shortURL = try GoogleMapsURL.directions(origin: "a", destination: "b")
		let extraCharacters = 2048 - shortURL.absoluteString.count
		let longestOrigin = String(repeating: "a", count: extraCharacters + 1)
		let url = try GoogleMapsURL.directions(origin: longestOrigin, destination: "b")
		#expect(url.absoluteString.count == 2048)
		#expect(throws: GoogleMapsURLError.tooLong) {
			try GoogleMapsURL.directions(origin: longestOrigin + "a", destination: "b")
		}
		#expect(throws: GoogleMapsURLError.tooLong) {
			try GoogleMapsURL.directions(
				origin: String(repeating: "駅", count: 500), destination: "浜松町駅")
		}
	}
	@Test func directionChangesBothDisplayLocationsAndSearchURL() throws {
		let route = SavedRoute(id: 1, name: "通勤", origin: "大井町駅", destination: "浜松町駅")
		for direction in RouteDirection.allCases {
			let expectedOrigin = direction == .outbound ? "大井町駅" : "浜松町駅"
			let expectedDestination = direction == .outbound ? "浜松町駅" : "大井町駅"
			#expect(direction.origin(for: route) == expectedOrigin)
			#expect(direction.destination(for: route) == expectedDestination)
			let url = try GoogleMapsURL.directions(for: route, direction: direction)
			let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
			#expect(components.queryItems?.first { $0.name == "origin" }?.value == expectedOrigin)
			#expect(
				components.queryItems?.first { $0.name == "destination" }?.value
					== expectedDestination)
			#expect(components.queryItems?.first { $0.name == "travelmode" }?.value == "transit")
		}
		#expect(route.origin == "大井町駅")
		#expect(route.destination == "浜松町駅")
	}

}
