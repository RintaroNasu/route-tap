import Foundation
import Testing

@testable import RouteTap

final class WidgetTestStore: WidgetRouteStoring {
	var snapshot: WidgetRouteSnapshot?
	func read() -> WidgetRouteSnapshot? { snapshot }
	func beginSession(accountID: String) {
		if snapshot?.accountID != accountID {
			snapshot = WidgetRouteSnapshot(accountID: accountID, routes: [])
		}
	}
	func save(_ routes: [SavedRoute], accountID: String) {
		guard snapshot?.accountID == accountID else { return }
		snapshot = WidgetRouteSnapshot(accountID: accountID, routes: routes)
	}
	func clear() { snapshot = nil }
}

struct WidgetRouteStoreTests {
	let route = SavedRoute(id: 1, name: "通勤", origin: "大井町駅", destination: "浜松町駅")

	@Test func sharesLatestRoutesAndDoesNotResurrectSignedOutData() throws {
		let suite = "RouteTap.widget-tests.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer { defaults.removePersistentDomain(forName: suite) }
		var reloads = 0
		let store = WidgetRouteStore(defaults: defaults, reload: { reloads += 1 })
		let reader = WidgetRouteStore(defaults: defaults, reload: {})
		store.beginSession(accountID: "account-a")
		store.save([route], accountID: "account-a")
		#expect(reader.read()?.routes == [route])
		let edited = SavedRoute(id: 1, name: "ジム", origin: "大井町駅", destination: "渋谷駅")
		store.save([edited], accountID: "account-a")
		#expect(reader.read()?.routes == [edited])
		store.save([], accountID: "account-a")
		#expect(reader.read()?.routes == [])
		store.clear()
		store.save([route], accountID: "account-a")
		#expect(reader.read() == nil)
		store.beginSession(accountID: "account-b")
		store.save([route], accountID: "account-a")
		#expect(reader.read()?.accountID == "account-b")
		#expect(reader.read()?.routes.isEmpty == true)
		#expect(reloads == 6)
	}

	@Test func sameAccountKeepsRoutesButDifferentAccountGetsEmptyList() throws {
		let suite = "RouteTap.widget-tests.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer { defaults.removePersistentDomain(forName: suite) }
		let store = WidgetRouteStore(defaults: defaults, reload: {})
		store.beginSession(accountID: "a")
		store.save([route], accountID: "a")
		store.beginSession(accountID: "a")
		#expect(store.read()?.routes == [route])
		store.beginSession(accountID: "b")
		#expect(store.read()?.routes == [])
	}

	@Test func linksPreserveAccountAndDirectionAndRejectInvalidParameters() throws {
		let link = WidgetRouteLink(
			accountID: "https://example.com/#1", routeID: 42, direction: .inbound)
		#expect(WidgetRouteLink(url: try #require(link.url)) == link)
		for value in [
			"https://route?account=a&id=1&direction=outbound",
			"routetap://route?account=a&id=0&direction=outbound",
			"routetap://route?account=a&id=1&direction=unknown",
			"routetap://route?account=a&id=1&direction=outbound&id=2",
			"routetap://route?account=a&id=1&direction=outbound&origin=other",
		] {
			#expect(WidgetRouteLink(url: try #require(URL(string: value))) == nil)
		}
	}
}

@MainActor
struct WidgetLifecycleTests {
	private let route = SavedRoute(id: 1, name: "通勤", origin: "大井町駅", destination: "浜松町駅")

	@Test func openerWaitsForRestorationAndUsesEditedRouteInChosenDirection() throws {
		let store = WidgetTestStore()
		store.beginSession(accountID: "a")
		store.save([route], accountID: "a")
		let opener = WidgetRouteOpener(store: store)
		let link = WidgetRouteLink(accountID: "a", routeID: 1, direction: .inbound)
		opener.receive(try #require(link.url))
		#expect(opener.takeURL(accountID: nil, isRestoring: true) == nil)
		let edited = SavedRoute(id: 1, name: "ジム", origin: "大井町駅", destination: "渋谷駅")
		store.save([edited], accountID: "a")
		let url = try #require(opener.takeURL(accountID: "a", isRestoring: false))
		let items = try #require(
			URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
		#expect(items.first(where: { $0.name == "origin" })?.value == "渋谷駅")
		#expect(items.first(where: { $0.name == "destination" })?.value == "大井町駅")
		#expect(opener.takeURL(accountID: "a", isRestoring: false) == nil)
	}

	@Test func staleLinksCannotOpenAfterLogoutAccountSwitchOrDeletion() throws {
		let store = WidgetTestStore()
		let opener = WidgetRouteOpener(store: store)
		let link = try #require(
			WidgetRouteLink(accountID: "a", routeID: 1, direction: .outbound).url)
		for accountID in [nil, "b", "a"] as [String?] {
			store.beginSession(accountID: accountID ?? "a")
			opener.receive(link)
			#expect(opener.takeURL(accountID: accountID, isRestoring: false) == nil)
			#expect(opener.errorMessage != nil)
		}
	}

	@Test func authenticationBeginsAndClearsWidgetSession() async {
		let store = WidgetTestStore()
		let tokens = RouteTapTests.TokenStore()
		tokens.token = "saved-token"
		let api = RouteTapTests.API()
		let auth = AuthViewModel(api: api, tokens: tokens, widgetStore: store)
		await auth.restoreIfNeeded()
		#expect(store.read()?.accountID == auth.accountID)
		store.save([route], accountID: auth.accountID!)
		api.deleteError = AuthError.server
		await auth.deleteAccount()
		#expect(store.read()?.routes == [route])
		api.deleteError = nil
		tokens.failDelete = true
		await auth.deleteAccount()
		#expect(auth.state == .accountDeleted)
		#expect(store.read() == nil)
	}

	@Test func logoutAndExpiredAuthenticationClearWidgetData() async {
		for expired in [false, true] {
			let store = WidgetTestStore()
			let tokens = RouteTapTests.TokenStore()
			tokens.token = "saved-token"
			let auth = AuthViewModel(api: RouteTapTests.API(), tokens: tokens, widgetStore: store)
			await auth.restoreIfNeeded()
			store.save([route], accountID: auth.accountID!)
			if expired { auth.expireSession() } else { auth.logout() }
			#expect(store.read() == nil)
			#expect(auth.state == .signedOut)
		}
	}

	@Test func routeMutationsUpdateWidgetOnlyAfterServerSuccess() async {
		let store = WidgetTestStore()
		store.beginSession(accountID: "a")
		let api = SavedRoutesViewModelTests.API()
		api.routes = [route]
		let model = SavedRoutesViewModel(
			api: api, tokens: SavedRoutesViewModelTests.Tokens(), accountID: "a", widgetStore: store
		)
		await model.load()
		#expect(store.read()?.routes == [route])
		let input = SavedRouteInput(name: "ジム", origin: "大井町駅", destination: "渋谷駅")
		api.updateError = SavedRouteError.server
		#expect(await model.save(input, editing: route) == false)
		#expect(store.read()?.routes == [route])
		api.updateError = nil
		#expect(await model.save(input, editing: route))
		#expect(store.read()?.routes.first?.destination == "渋谷駅")
		#expect(await model.delete(route))
		#expect(store.read()?.routes.isEmpty == true)
		#expect(await model.save(input))
		#expect(store.read()?.routes.first?.id == api.createdRoute.id)
	}

	@Test func routeResponseAfterLogoutCannotRepopulateWidget() async {
		let store = WidgetTestStore()
		store.beginSession(accountID: "a")
		let api = SavedRoutesViewModelTests.API()
		api.routes = [route]
		api.beforeFetch = { store.clear() }
		let model = SavedRoutesViewModel(
			api: api, tokens: SavedRoutesViewModelTests.Tokens(), accountID: "a", widgetStore: store
		)
		await model.load()
		#expect(store.read() == nil)
	}
	@Test func expiredRequestFromPreviousAccountDoesNotClearNewWidgetSession() async {
		let store = WidgetTestStore()
		store.beginSession(accountID: "a")
		let api = SavedRoutesViewModelTests.API()
		api.beforeFetch = { store.beginSession(accountID: "b") }
		api.fetchError = SavedRouteError.unauthorized
		let model = SavedRoutesViewModel(
			api: api, tokens: SavedRoutesViewModelTests.Tokens(), accountID: "a", widgetStore: store
		)
		await model.load()
		#expect(model.sessionExpired)
		#expect(store.read()?.accountID == "b")
	}

}
