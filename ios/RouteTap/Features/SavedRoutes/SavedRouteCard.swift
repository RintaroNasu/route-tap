import SwiftUI

struct SavedRouteCard: View {
	let route: SavedRoute
	let actionsDisabled: Bool
	let isDeleting: Bool
	let onEdit: () -> Void
	let onDelete: () -> Void
	@State private var direction: RouteDirection = .outbound
	@Environment(\.openURL) private var openURL
	@State private var showingMapsError = false
	@State private var mapsErrorMessage = ""

	var body: some View {
		VStack(alignment: .leading, spacing: 22) {
			header
			directionPicker
			routeDetails
			mapsButton
		}
		.padding(20)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
		.overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5), lineWidth: 1))
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier("routes.card.\(route.id)")
		.alert("Google Mapsを開けませんでした", isPresented: $showingMapsError) {
			Button("閉じる", role: .cancel) {}
		} message: {
			Text(mapsErrorMessage)
		}
	}

	private var header: some View {
		HStack(spacing: 14) {
			Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
				.font(.title2.weight(.semibold))
				.foregroundStyle(.tint)
				.frame(width: 52, height: 52)
				.background(.tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
				.accessibilityHidden(true)
			Text(route.name)
				.font(.title3.bold())
				.fixedSize(horizontal: false, vertical: true)
			Spacer(minLength: 0)
			if isDeleting {
				ProgressView().accessibilityLabel("削除中")
					.accessibilityIdentifier("routes.deleting.\(route.id)")
			} else {
				actionsMenu
			}
		}
	}

	private var actionsMenu: some View {
		Menu {
			Button(action: onEdit) { Label("編集", systemImage: "pencil") }
				.accessibilityIdentifier("routes.edit.\(route.id)")
			Button(role: .destructive, action: onDelete) { Label("削除", systemImage: "trash") }
				.accessibilityIdentifier("routes.delete.\(route.id)")
		} label: {
			Image(systemName: "ellipsis")
				.font(.title3.weight(.semibold))
				.foregroundStyle(.secondary)
				.frame(width: 44, height: 44)
		}
		.disabled(actionsDisabled)
		.accessibilityLabel("\(route.name)の操作")
		.accessibilityIdentifier("routes.menu.\(route.id)")
	}

	private var directionPicker: some View {
		HStack(spacing: 0) {
			ForEach(RouteDirection.allCases, id: \.self) { choice in
				Button {
					direction = choice
				} label: {
					Text(choice.title)
						.font(.subheadline.weight(.semibold))
						.frame(maxWidth: .infinity, minHeight: 44)
				}
				.buttonStyle(.plain)
				.foregroundStyle(direction == choice ? Color.white : Color.secondary)
				.background(
					direction == choice ? Color.accentColor : Color.clear,
					in: RoundedRectangle(cornerRadius: 8)
				)
				.accessibilityAddTraits(direction == choice ? [.isSelected] : [])
				.accessibilityIdentifier("routes.direction.\(choice.rawValue).\(route.id)")
			}
		}
		.padding(4)
		.background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
	}

	private var routeDetails: some View {
		VStack(alignment: .leading, spacing: 0) {
			locationRow(title: "出発地", place: direction.origin(for: route), symbol: "circle")
				.accessibilityIdentifier("routes.origin.\(route.id)")
			Rectangle()
				.fill(Color(.systemGray4))
				.frame(width: 2, height: 18)
				.padding(.leading, 9)
				.padding(.vertical, 4)
			locationRow(
				title: "目的地", place: direction.destination(for: route), symbol: "mappin.circle.fill"
			)
			.accessibilityIdentifier("routes.destination.\(route.id)")
		}
	}

	private var mapsButton: some View {
		Button(action: openGoogleMaps) {
			Label("Google Mapsで開く", systemImage: "arrow.up.right.square")
				.font(.headline)
				.frame(maxWidth: .infinity, minHeight: 54)
		}
		.buttonStyle(.plain)
		.foregroundStyle(.white)
		.background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
		.accessibilityHint(
			"\(direction.origin(for: route))から\(direction.destination(for: route))への公共交通の経路を検索します"
		)
		.accessibilityIdentifier("routes.openMaps.\(route.id)")
	}

	private func openGoogleMaps() {
		do {
			let url = try GoogleMapsURL.directions(for: route, direction: direction)
			openURL(url) { accepted in
				if !accepted {
					mapsErrorMessage = "リンクを開けませんでした。時間をおいて、もう一度お試しください。"
					showingMapsError = true
				}
			}
		} catch {
			mapsErrorMessage = error.localizedDescription
			showingMapsError = true
		}
	}

	private func locationRow(title: String, place: String, symbol: String) -> some View {
		HStack(alignment: .top, spacing: 14) {
			Image(systemName: symbol)
				.font(.system(size: 19, weight: .medium))
				.foregroundStyle(.secondary)
				.frame(width: 20)
				.padding(.top, 3)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: 5) {
				Text(title).font(.caption).foregroundStyle(.secondary)
				Text(place)
					.font(.body.weight(.semibold))
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.accessibilityElement(children: .combine)
	}
}
