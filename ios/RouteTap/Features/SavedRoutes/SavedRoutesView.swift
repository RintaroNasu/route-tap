import SwiftUI

struct SavedRoutesView: View {
	@StateObject private var viewModel = SavedRoutesViewModel()
	@State private var activeForm: RouteForm?
	@State private var routeToDelete: SavedRoute?
	@State private var showingDeleteConfirmation = false
	@State private var showingDeleteError = false
	@State private var showingAccountDeletionConfirmation = false
	@Environment(\.scenePhase) private var scenePhase

	let accountError: String?
	let isDeletingAccount: Bool
	let onLogout: () -> Void
	let onSessionExpired: () -> Void
	let onDeleteAccount: () async -> Void

	private struct RouteForm: Identifiable {
		let id = UUID()
		let route: SavedRoute?
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 26) {
				header
				if isDeletingAccount {
					HStack(spacing: 12) {
						ProgressView()
						Text("アカウントを削除中…").font(.subheadline)
					}
					.accessibilityIdentifier("auth.deletingAccount")
				}
				if let accountError {
					Text(accountError).font(.subheadline).foregroundStyle(.red)
						.accessibilityIdentifier("auth.accountError")
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
		.disabled(isDeletingAccount)
		.refreshable {
			if !isDeletingAccount { await viewModel.load() }
		}
		.sheet(item: $activeForm) { form in
			SavedRouteFormView(viewModel: viewModel, route: form.route)
		}
		.alert("移動を削除しますか？", isPresented: $showingDeleteConfirmation, presenting: routeToDelete) {
			route in
			Button("削除", role: .destructive) {
				routeToDelete = nil
				Task { await viewModel.delete(route) }
			}
			.accessibilityIdentifier("routes.confirmDelete")
			Button("キャンセル", role: .cancel) { routeToDelete = nil }
		} message: { route in
			Text("「\(route.name)」を削除します。この操作は取り消せません。")
		}
		.alert("移動を削除できませんでした", isPresented: $showingDeleteError) {
			Button("閉じる", role: .cancel) { viewModel.clearDeleteError() }
		} message: {
			Text(viewModel.deleteError ?? "もう一度お試しください。")
		}
		.onChange(of: viewModel.deleteError) { _, error in
			showingDeleteError = error != nil
		}
		.alert("アカウントを削除しますか？", isPresented: $showingAccountDeletionConfirmation) {
			Button("アカウントを削除", role: .destructive) {
				Task { await onDeleteAccount() }
			}
			.disabled(viewModel.isBusy || isDeletingAccount)
			.accessibilityIdentifier("auth.confirmAccountDeletion")
			Button("キャンセル", role: .cancel) {}
		} message: {
			Text("アカウントと保存した移動がすべて削除されます。この操作は取り消せません。")
		}
		.task { if !isDeletingAccount { await viewModel.load() } }
		.onChange(of: scenePhase) { _, phase in
			if phase == .active && !isDeletingAccount { Task { await viewModel.load() } }
		}
		.onChange(of: viewModel.sessionExpired) { _, expired in
			if expired {
				activeForm = nil
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
						.disabled(viewModel.isSaving || viewModel.deletingRouteID != nil)
						.accessibilityIdentifier("auth.logout")
					Button("アカウント削除", role: .destructive) {
						showingAccountDeletionConfirmation = true
					}
					.disabled(viewModel.isBusy || isDeletingAccount)
					.accessibilityIdentifier("auth.deleteAccount")
				} label: {
					Image(systemName: "person.crop.circle")
						.font(.title2)
						.foregroundStyle(.secondary)
						.frame(width: 44, height: 44)
				}
				.accessibilityLabel("アカウント")
				Button {
					activeForm = RouteForm(route: nil)
				} label: {
					Image(systemName: "plus")
						.font(.system(size: 23, weight: .medium))
						.frame(width: 48, height: 48)
						.background(.tint.opacity(0.09), in: Circle())
				}
				.disabled(viewModel.isBusy)
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
					SavedRouteCard(
						route: route,
						actionsDisabled: viewModel.isBusy,
						isDeleting: viewModel.deletingRouteID == route.id,
						onEdit: { activeForm = RouteForm(route: route) },
						onDelete: {
							routeToDelete = route
							showingDeleteConfirmation = true
						}
					)
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
				.disabled(viewModel.isBusy)
		}
		.accessibilityIdentifier("routes.loadError")
	}
}
