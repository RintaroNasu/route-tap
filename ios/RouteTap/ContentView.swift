import SwiftUI

struct ContentView: View {
	@StateObject private var auth = AuthViewModel()

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
		.task { await auth.restoreIfNeeded() }
	}
}

#Preview { ContentView() }
