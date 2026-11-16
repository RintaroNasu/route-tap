import Foundation
import Testing

@testable import RouteTap

@MainActor
struct WidgetTests {
	let route = SavedRoute(id: UUID(), name: "通勤", origin: "大井町駅", destination: "浜松町駅")

	@Test func linksRoundTripBothDirectionsAndRejectMalformedOrLegacyLinks() throws {
		for direction in RouteDirection.allCases {
			let link = WidgetRouteLink(routeID: route.id, direction: direction)
			#expect(WidgetRouteLink(url: try #require(link.url)) == link)
		}
		for text in [
			"https://route?id=1&direction=inbound",
			"routetap://route?id=1&direction=inbound",
			"routetap://route?id=\(route.id)&direction=invalid",
			"routetap://route?id=\(route.id)&direction=inbound&id=\(route.id)",
			"routetap://route?id=\(route.id)&direction=inbound#fragment",
			"routetap://route?account=old&id=1&direction=outbound",
		] {
			#expect(WidgetRouteLink(url: try #require(URL(string: text))) == nil)
		}
	}

	@Test func opensLatestEditedRouteWithoutLoginAndRespectsDirection() throws {
		let store = TestRouteStore()
		store.routes = [route]
		let opener = WidgetRouteOpener(store: store)
		let link = try #require(WidgetRouteLink(routeID: route.id, direction: .inbound).url)
		store.routes = [SavedRoute(id: route.id, name: "変更", origin: "新宿駅", destination: "池袋駅")]
		let destination = try #require(opener.destination(for: link))
		let items = try #require(
			URLComponents(url: destination, resolvingAgainstBaseURL: false)?.queryItems)
		#expect(items.first { $0.name == "origin" }?.value == "池袋駅")
		#expect(items.first { $0.name == "destination" }?.value == "新宿駅")
		#expect(opener.errorMessage == nil)
	}

	@Test func deletedRoutesAndInvalidLinksDoNotOpenMaps() throws {
		let store = TestRouteStore()
		let opener = WidgetRouteOpener(store: store)
		let link = try #require(WidgetRouteLink(routeID: route.id, direction: .outbound).url)
		#expect(opener.destination(for: link) == nil)
		#expect(opener.errorMessage?.contains("見つかりません") == true)
		#expect(
			opener.destination(
				for: try #require(
					URL(string: "routetap://route?account=old&id=1&direction=inbound"))) == nil)
		#expect(opener.errorMessage?.contains("選び直して") == true)
		#expect(opener.destination(for: try #require(URL(string: "routetap://home"))) == nil)
		#expect(opener.errorMessage == nil)
	}

	@Test func storageAndURLFailuresAreReported() throws {
		let store = TestRouteStore()
		let opener = WidgetRouteOpener(store: store)
		let link = try #require(WidgetRouteLink(routeID: route.id, direction: .outbound).url)
		store.loadError = SavedRouteStorageError.readFailed
		#expect(opener.destination(for: link) == nil)
		#expect(opener.errorMessage == SavedRouteStorageError.readFailed.localizedDescription)
		store.loadError = nil
		store.routes = [
			SavedRoute(
				id: route.id, name: "長文", origin: String(repeating: "駅", count: 500),
				destination: "駅")
		]
		#expect(opener.destination(for: link) == nil)
		#expect(opener.errorMessage == GoogleMapsURLError.tooLong.localizedDescription)
	}

	@Test func appAndWidgetReaderShareOnlySuccessfullySavedChanges() async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
			UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let file = directory.appendingPathComponent("routes.json")
		var reloads = 0
		let store = SavedRouteStore(fileURL: file, reloadWidgets: { reloads += 1 })
		let model = SavedRoutesViewModel(store: store)
		let reader = SavedRouteStore(fileURL: file, reloadWidgets: {})
		#expect(
			await model.save(
				SavedRouteInput(
					name: route.name, origin: route.origin, destination: route.destination)))
		let saved = try #require(model.routes.first)
		let opener = WidgetRouteOpener(store: reader)
		let link = try #require(WidgetRouteLink(routeID: saved.id, direction: .outbound).url)
		#expect(opener.destination(for: link) != nil)
		#expect(
			await model.save(
				SavedRouteInput(name: "帰宅", origin: "渋谷駅", destination: "大井町駅"), editing: saved))
		#expect(try reader.load().first?.origin == "渋谷駅")
		#expect(
			opener.destination(for: link)
				== (try GoogleMapsURL.directions(origin: "渋谷駅", destination: "大井町駅")))
		#expect(await model.delete(saved))
		#expect(opener.destination(for: link) == nil)
		#expect(reloads == 3)
	}
}
