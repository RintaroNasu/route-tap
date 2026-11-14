import SwiftUI

struct ContentView: View {
	@StateObject private var auth = AuthViewModel()
	@StateObject private var widgetOpener = WidgetRouteOpener()
	@State private var showingWidgetError = false
	@Environment(\.openURL) private var openURL

	var body: some View {
		Group {
			switch auth.state {
			case .restoring:
				ProgressView("ログイン状態を確認中…")
			case .signedOut:
				AuthView(viewModel: auth)
			case .unavailable:
				VStack(spacing: 20) {
					Image(systemName: "wifi.exclamationmark").font(.largeTitle)
					Text("ログイン状態を確認できませんでした").font(.headline)
					Text(auth.errorMessage ?? "もう一度お試しください。")
						.foregroundStyle(.secondary)
					Button("再試行") { Task { await auth.restore() } }
						.buttonStyle(.borderedProminent)
						.disabled(auth.isBusy)
					Button("ログイン画面に戻る") { auth.logout() }
						.disabled(auth.isBusy)
				}
				.padding(28)
				.multilineTextAlignment(.center)
			case .accountDeleted:
				VStack(spacing: 20) {
					Image(systemName: "checkmark.circle")
						.font(.system(size: 44)).foregroundStyle(.tint)
					Text("アカウントは削除されています").font(.title2.bold())
					Text(auth.errorMessage ?? "この端末のログイン情報を消去してください。")
						.foregroundStyle(.secondary)
					Button("ログイン情報を消去して戻る") { auth.retryAccountCleanup() }
						.buttonStyle(.borderedProminent)
						.disabled(auth.isBusy)
						.accessibilityIdentifier("auth.retryAccountCleanup")
				}
				.padding(28)
				.multilineTextAlignment(.center)

			case .signedIn(let user):
				SavedRoutesView(
					accountID: auth.accountID ?? "",
					accountError: auth.errorMessage,
					isDeletingAccount: auth.isDeletingAccount,
					onLogout: auth.logout,
					onSessionExpired: auth.expireSession,
					onDeleteAccount: auth.deleteAccount
				)
				.id(user.id)
			}
		}
		.tint(Color(red: 0.02, green: 0.60, blue: 0.33))
		.task {
			await auth.restoreIfNeeded()
			openWidgetRoute()
		}
		.onOpenURL { url in
			widgetOpener.receive(url)
			openWidgetRoute()
		}
		.onChange(of: auth.state) { _, _ in openWidgetRoute() }
		.onChange(of: auth.isBusy) { _, busy in if !busy { openWidgetRoute() } }
		.onChange(of: widgetOpener.errorMessage) { _, message in
			showingWidgetError = message != nil
		}
		.alert("移動を開けませんでした", isPresented: $showingWidgetError) {
			Button("閉じる", role: .cancel) { widgetOpener.errorMessage = nil }
		} message: {
			Text(widgetOpener.errorMessage ?? "もう一度お試しください。")
		}
	}

	private func openWidgetRoute() {
		guard
			let url = widgetOpener.takeURL(
				accountID: auth.accountID, isRestoring: auth.state == .restoring || auth.isBusy)
		else { return }
		openURL(url) { accepted in
			if !accepted { widgetOpener.errorMessage = "Google Mapsを開けませんでした。時間をおいて、もう一度お試しください。" }
		}
	}
}

#Preview { ContentView() }
