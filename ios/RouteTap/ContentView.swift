import SwiftUI

struct ContentView: View {
	@StateObject private var auth = AuthModel()

	var body: some View {
		Group {
			switch auth.state {
			case .restoring:
				ProgressView("ログイン状態を確認中…")
			case .signedOut:
				AuthView(model: auth)
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
			case .signedIn(let user):
				// The saved-route home screen is implemented in the next step.
				VStack(spacing: 20) {
					Image(systemName: "checkmark.circle.fill")
						.font(.system(size: 48)).foregroundStyle(.green)
					Text("ログインしました").font(.title2.bold())
					Text(user.email).foregroundStyle(.secondary)
					if let error = auth.errorMessage {
						Text(error).foregroundStyle(.red)
					}
					Button("ログアウト") { auth.logout() }
						.buttonStyle(.bordered)
						.accessibilityIdentifier("auth.logout")
				}
				.padding(28)
			}
		}
		.tint(Color(red: 0.02, green: 0.60, blue: 0.33))
		.task { await auth.restoreIfNeeded() }
	}
}

#Preview { ContentView() }
