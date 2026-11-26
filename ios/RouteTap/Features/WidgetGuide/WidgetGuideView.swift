import SwiftUI

struct WidgetGuideView: View {
	let route: SavedRoute?
	@State private var showingInstructions: Bool
	@Environment(\.dismiss) private var dismiss

	init(route: SavedRoute? = nil) {
		self.route = route
		_showingInstructions = State(initialValue: route == nil)
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				if showingInstructions {
					instructions
				} else if let route {
					introduction(for: route)
				}
			}
			.frame(maxWidth: 520)
			.padding(24)
			.frame(maxWidth: .infinity)
		}
		.background(Color(.systemBackground))
		.safeAreaInset(edge: .bottom) { footer }
		.presentationDetents(showingInstructions ? [.large] : [.height(650), .large])
		.presentationDragIndicator(.visible)
	}

	private func introduction(for route: SavedRoute) -> some View {
		VStack(spacing: 18) {
			Image(systemName: "checkmark")
				.font(.title.weight(.semibold))
				.foregroundStyle(.tint)
				.frame(width: 64, height: 64)
				.background(.tint.opacity(0.1), in: Circle())
				.accessibilityHidden(true)
			Text("移動を保存しました")
				.font(.headline)
				.accessibilityIdentifier("widgetGuide.saved")
			Text("ホーム画面から、すぐ出発。")
				.font(.title2.bold())
				.accessibilityAddTraits(.isHeader)
			Text("ウィジェットで、いつもの移動を開けます。")
				.font(.subheadline)
				.foregroundStyle(.secondary)
			WidgetGuidePreview(route: route)
			Text("ウィジェットのイメージ")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.multilineTextAlignment(.center)
		.frame(maxWidth: .infinity)
	}

	private var instructions: some View {
		VStack(alignment: .leading, spacing: 20) {
			HStack(alignment: .top) {
				Text("ウィジェットの追加方法")
					.font(.title2.bold())
					.accessibilityAddTraits(.isHeader)
					.accessibilityIdentifier("widgetGuide.heading")
				Spacer(minLength: 8)
				Button(action: { dismiss() }) {
					Image(systemName: "xmark")
						.font(.headline)
						.frame(width: 44, height: 44)
						.contentShape(Rectangle())
				}
				.foregroundStyle(.primary)
				.accessibilityLabel("閉じる")
				.accessibilityIdentifier("widgetGuide.close")
			}
			Text("いつもの移動を、ホーム画面に。")
				.font(.subheadline)
				.foregroundStyle(.secondary)
			WidgetGuideStep(
				number: 1, title: "ホーム画面を長押し",
				message: "アプリを閉じて、ホーム画面の空いている場所を長押しします。「編集」→「ウィジェットを追加」を選びます。",
				imageName: "WidgetGuideHome",
				imageDescription: "ホーム画面の編集メニュー。一番上の「ウィジェットを追加」を押します。",
				highlight: CGRect(x: 0.03, y: 0.32, width: 0.93, height: 0.21))
			WidgetGuideStep(
				number: 2, title: "RouteTapを検索して追加",
				message: "検索欄で「RouteTap」を探して選び、「ウィジェットを追加」を押します。",
				imageName: "WidgetGuideAdd",
				imageDescription: "RouteTapのウィジェット選択画面。下の青い「ウィジェットを追加」を押します。",
				highlight: CGRect(x: 0.03, y: 0.85, width: 0.94, height: 0.12))
			WidgetGuideStep(
				number: 3, title: "保存した移動を選択",
				message: "追加したウィジェットを長押しし、「ウィジェットを編集」を選びます。「移動」を押して、使いたいルートを選択してください。",
				imageName: "WidgetGuideSelect",
				imageDescription: "ウィジェットの設定画面。「移動」を押し、候補から保存したルートを選びます。",
				highlight: CGRect(x: 0.07, y: 0.35, width: 0.87, height: 0.13))
			Label("画面は一例です。OSのバージョンによって表示が異なる場合があります。", systemImage: "info.circle")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}

	private var footer: some View {
		VStack(spacing: 8) {
			Button {
				if showingInstructions {
					dismiss()
				} else {
					showingInstructions = true
				}
			} label: {
				Text(showingInstructions ? "わかりました" : "ウィジェットの追加方法を見る")
					.font(.headline)
					.multilineTextAlignment(.center)
					.frame(maxWidth: .infinity, minHeight: 56)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.foregroundStyle(.white)
			.background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
			.accessibilityIdentifier(
				showingInstructions ? "widgetGuide.done" : "widgetGuide.showSteps")
			if !showingInstructions {
				Button("あとで") { dismiss() }
					.frame(maxWidth: .infinity, minHeight: 44)
					.contentShape(Rectangle())
					.accessibilityIdentifier("widgetGuide.later")
				Text("ホーム画面への追加操作が必要です")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth: 520)
		.padding(.horizontal, 24)
		.padding(.vertical, 16)
		.frame(maxWidth: .infinity)
		.background(Color(.systemBackground))
	}
}

private struct WidgetGuideStep: View {
	let number: Int
	let title: String
	let message: String
	let imageName: String
	let imageDescription: String
	let highlight: CGRect

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack(alignment: .top, spacing: 10) {
				Text("\(number)")
					.font(.subheadline.bold())
					.foregroundStyle(.white)
					.frame(width: 28, height: 28)
					.background(Color.accentColor, in: Circle())
					.accessibilityHidden(true)
				Text(title)
					.font(.headline)
					.accessibilityLabel("手順\(number)、\(title)")
					.accessibilityAddTraits(.isHeader)
			}
			Text(message)
				.font(.subheadline)
				.foregroundStyle(.secondary)
			Image(imageName)
				.resizable()
				.scaledToFit()
				.overlay {
					GeometryReader { geometry in
						RoundedRectangle(cornerRadius: 10)
							.stroke(.white, lineWidth: 5)
							.overlay(
								RoundedRectangle(cornerRadius: 10).stroke(
									Color.accentColor, lineWidth: 3)
							)
							.frame(
								width: geometry.size.width * highlight.width,
								height: geometry.size.height * highlight.height
							)
							.offset(
								x: geometry.size.width * highlight.minX,
								y: geometry.size.height * highlight.minY)
					}
					.accessibilityHidden(true)
					.allowsHitTesting(false)
				}
				.clipShape(RoundedRectangle(cornerRadius: 12))
				.frame(maxWidth: 340)
				.frame(maxWidth: .infinity)
				.accessibilityLabel(imageDescription)
				.accessibilityIdentifier("widgetGuide.image.\(number)")
		}
		.padding(16)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18)
		)
		.overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray5), lineWidth: 1))
	}
}

private struct WidgetGuidePreview: View {
	let route: SavedRoute

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Label("RouteTap", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
				.font(.subheadline.bold())
				.foregroundStyle(.tint)
			Text(route.name)
				.font(.title3.bold())
				.lineLimit(2)
				.accessibilityIdentifier("widgetGuide.previewName")
			Text("\(route.origin) → \(route.destination)")
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.lineLimit(3)
			HStack(spacing: 10) {
				previewAction("往路を開く", symbol: "arrow.up.right")
				previewAction("復路を開く", symbol: "arrow.uturn.backward")
			}
			.accessibilityHidden(true)
		}
		.padding(20)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20)
		)
		.overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5), lineWidth: 1))
		.multilineTextAlignment(.leading)
	}

	private func previewAction(_ title: String, symbol: String) -> some View {
		Label(title, systemImage: symbol)
			.font(.subheadline.weight(.semibold))
			.foregroundStyle(.tint)
			.frame(maxWidth: .infinity, minHeight: 44)
			.background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
	}
}
