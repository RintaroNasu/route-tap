import SwiftUI

struct SavedRouteCard: View {
	let route: SavedRoute

	var body: some View {
		VStack(alignment: .leading, spacing: 22) {
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
			}
			VStack(alignment: .leading, spacing: 0) {
				locationRow(title: "出発地", place: route.origin, symbol: "circle")
				Rectangle()
					.fill(Color(.systemGray4))
					.frame(width: 2, height: 18)
					.padding(.leading, 9)
					.padding(.vertical, 4)
				locationRow(title: "目的地", place: route.destination, symbol: "mappin.circle.fill")
			}
		}
		.padding(20)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
		.overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5), lineWidth: 1))
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier("routes.card.\(route.id)")
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
	}
}
