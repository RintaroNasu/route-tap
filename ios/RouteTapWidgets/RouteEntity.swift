import AppIntents

struct RouteEntity: AppEntity {
	static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "保存した移動")
	static var defaultQuery = RouteEntityQuery()

	let id: String
	let name: String
	let origin: String
	let destination: String

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(title: "\(name)", subtitle: "\(origin) → \(destination)")
	}
}

struct RouteEntityQuery: EntityQuery {
	func entities(for identifiers: [String]) async throws -> [RouteEntity] {
		routes().filter { identifiers.contains($0.id) }
	}

	func suggestedEntities() async throws -> [RouteEntity] { routes() }

	private func routes() -> [RouteEntity] {
		guard let routes = try? SavedRouteStore().load() else { return [] }
		return routes.map {
			RouteEntity(
				id: $0.id.uuidString, name: $0.name, origin: $0.origin,
				destination: $0.destination)
		}
	}
}

struct RouteWidgetConfiguration: WidgetConfigurationIntent {
	static var title: LocalizedStringResource = "表示する移動"
	static var description = IntentDescription("RouteTapで保存した移動を選んでください。")
	@Parameter(title: "移動") var route: RouteEntity?
}
