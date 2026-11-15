import AppIntents
import SwiftUI
import WidgetKit

@main
struct RouteTapWidgets: WidgetBundle {
	var body: some Widget { RouteTapWidget() }
}

struct RouteTapWidget: Widget {
	var body: some WidgetConfiguration {
		AppIntentConfiguration(
			kind: WidgetRouteStore.widgetKind,
			intent: RouteWidgetConfiguration.self,
			provider: RouteWidgetProvider()
		) { entry in
			RouteWidgetView(entry: entry)
				.containerBackground(.background, for: .widget)
		}
		.configurationDisplayName("いつもの移動")
		.description("保存した移動の往路・復路をGoogle Mapsで確認できます。")
		.supportedFamilies([.systemMedium])
	}
}

struct RouteWidgetEntry: TimelineEntry {
	let date: Date
	let accountID: String?
	let route: SavedRoute?
	let message: String

	static var preview: RouteWidgetEntry {
		RouteWidgetEntry(
			date: .now, accountID: "preview",
			route: SavedRoute(id: 1, name: "通勤", origin: "大井町駅", destination: "浜松町駅"), message: "")
	}
}

struct RouteWidgetProvider: AppIntentTimelineProvider {
	func placeholder(in context: Context) -> RouteWidgetEntry { .preview }

	func snapshot(for configuration: RouteWidgetConfiguration, in context: Context) async
		-> RouteWidgetEntry
	{
		context.isPreview ? .preview : entry(for: configuration)
	}

	func timeline(for configuration: RouteWidgetConfiguration, in context: Context) async
		-> Timeline<RouteWidgetEntry>
	{
		Timeline(entries: [entry(for: configuration)], policy: .never)
	}

	private func entry(for configuration: RouteWidgetConfiguration) -> RouteWidgetEntry {
		let snapshot = WidgetRouteStore().read()
		let route = snapshot?.routes.first {
			snapshot?.entityID(for: $0) == configuration.route?.id
		}
		let message: String
		if snapshot == nil {
			message = "RouteTapでログインしてください"
		} else if configuration.route == nil {
			message = "長押しして「ウィジェットを編集」から移動を選んでください"
		} else {
			message = "移動が見つかりません。ウィジェットの移動を選び直してください"
		}
		return RouteWidgetEntry(
			date: .now, accountID: snapshot?.accountID, route: route, message: message)
	}
}

struct RouteWidgetView: View {
	let entry: RouteWidgetEntry
	private let green = Color(red: 0.02, green: 0.60, blue: 0.33)

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Label("RouteTap", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
				.font(.caption.weight(.bold)).foregroundStyle(green)
			if let route = entry.route, let accountID = entry.accountID {
				Text(route.name).font(.headline).lineLimit(1)
				Text("\(route.origin) → \(route.destination)")
					.font(.caption).foregroundStyle(.secondary).lineLimit(1)
				Spacer(minLength: 0)
				HStack(spacing: 10) {
					routeLink(route, accountID: accountID, direction: .outbound)
					routeLink(route, accountID: accountID, direction: .inbound)
				}
			} else {
				Spacer(minLength: 0)
				Text(entry.message).font(.subheadline).foregroundStyle(.secondary)
				Spacer(minLength: 0)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		.widgetURL(URL(string: "routetap://home"))
	}

	@ViewBuilder
	private func routeLink(_ route: SavedRoute, accountID: String, direction: RouteDirection)
		-> some View
	{
		if let url = WidgetRouteLink(accountID: accountID, routeID: route.id, direction: direction)
			.url
		{
			Link(destination: url) {
				Label(
					"\(direction.title)を開く",
					systemImage: direction == .outbound ? "arrow.up.right" : "arrow.uturn.backward"
				)
				.font(.subheadline.weight(.semibold))
				.frame(maxWidth: .infinity).padding(.vertical, 9)
				.contentShape(Rectangle())
				.foregroundStyle(direction == .outbound ? .white : green)
				.background(
					direction == .outbound ? green : green.opacity(0.1),
					in: RoundedRectangle(cornerRadius: 10))
			}
			.accessibilityLabel("\(route.name)の\(direction.title)を開く")
		}
	}
}

#Preview(as: .systemMedium) {
	RouteTapWidget()
} timeline: {
	RouteWidgetEntry.preview
	RouteWidgetEntry(date: .now, accountID: nil, route: nil, message: "RouteTapでログインしてください")
}
