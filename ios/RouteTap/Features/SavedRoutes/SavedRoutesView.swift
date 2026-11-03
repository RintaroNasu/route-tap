import SwiftUI

struct SavedRoutesView: View {
	@StateObject private var viewModel = SavedRoutesViewModel()
	@State private var showingForm = false
	@Environment(\.scenePhase) private var scenePhase

	let accountError: String?
	let onLogout: () -> Void
	let onSessionExpired: () -> Void

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 26) {
				header
				if let accountError {
					Text(accountError).font(.subheadline).foregroundStyle(.red)
				}
				if let error = viewModel.loadError {
					loadError(message: error)
				}
				routeList
			}
			.frame(maxWidth: 600)
			.padding(.horizontal, 24)
			.padding(.vertical, 24)
			.frame(maxWidth: .infinity)
		}
		.background(Color(.systemGroupedBackground))
		.refreshable { await viewModel.load() }
		.sheet(isPresented: $showingForm) {
			SavedRouteFormView(viewModel: viewModel)
		}
		.task { await viewModel.load() }
		.onChange(of: scenePhase) { _, phase in
			if phase == .active { Task { await viewModel.load() } }
		}
		.onChange(of: viewModel.sessionExpired) { _, expired in
			if expired {
				showingForm = false
				onSessionExpired()
			}
		}
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Text("RouteTap")
					.font(.headline.weight(.bold))
					.foregroundStyle(.tint)
				Spacer()
				Menu {
					Button("ログアウト", action: onLogout)
						.accessibilityIdentifier("auth.logout")
				} label: {
					Image(systemName: "person.crop.circle")
						.font(.title2)
						.foregroundStyle(.secondary)
						.frame(width: 44, height: 44)
				}
				.accessibilityLabel("アカウント")
				Button {
					showingForm = true
				} label: {
					Image(systemName: "plus")
						.font(.system(size: 23, weight: .medium))
						.frame(width: 48, height: 48)
						.background(.tint.opacity(0.09), in: Circle())
				}
				.disabled(viewModel.isLoading || viewModel.isSaving)
				.accessibilityLabel("移動を登録")
				.accessibilityIdentifier("routes.add")
			}
			Text("いつもの移動")
				.font(.largeTitle.bold())
				.accessibilityAddTraits(.isHeader)
				.accessibilityIdentifier("routes.heading")
			Text("よく使う移動を、まとめて保存。")
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
	}

	@ViewBuilder
	private var routeList: some View {
		if viewModel.isLoading && !viewModel.hasLoaded {
			ProgressView("移動を読み込み中…")
				.frame(maxWidth: .infinity, minHeight: 240)
		} else if viewModel.hasLoaded && viewModel.routes.isEmpty {
			emptyState
		} else {
			LazyVStack(spacing: 16) {
				ForEach(viewModel.routes) { route in
					SavedRouteCard(route: route)
				}
			}
		}
	}

	private var emptyState: some View {
		VStack(spacing: 16) {
			Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
				.font(.system(size: 42))
				.foregroundStyle(.tint)
				.padding(.bottom, 8)
			Text("いつもの移動を登録しましょう")
				.font(.headline)
			Text("駅名・住所・施設名を保存できます。\n右上の＋から最初の移動を追加してください。")
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 60)
		.accessibilityIdentifier("routes.empty")
	}

	private func loadError(message: String) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(message).font(.subheadline).foregroundStyle(.red)
			if viewModel.hasLoaded && !viewModel.routes.isEmpty {
				Text("前回取得した移動を表示しています。")
					.font(.caption).foregroundStyle(.secondary)
			}
			Button("再試行") { Task { await viewModel.load() } }
				.disabled(viewModel.isLoading || viewModel.isSaving)
		}
		.accessibilityIdentifier("routes.loadError")
	}
}
