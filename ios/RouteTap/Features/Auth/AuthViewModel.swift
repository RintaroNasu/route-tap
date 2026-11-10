import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
	enum State: Equatable {
		case restoring, signedOut
		case signedIn(AuthenticatedUser)
		case unavailable
		case accountDeleted
	}

	@Published private(set) var state: State = .restoring
	@Published private(set) var isBusy = false
	@Published private(set) var isDeletingAccount = false
	@Published private(set) var errorMessage: String?
	private let api: any AuthServicing
	private let tokens: any TokenStoring
	private var didRestore = false

	init(api: any AuthServicing = AuthAPI(), tokens: any TokenStoring = KeychainTokenStore()) {
		self.api = api
		self.tokens = tokens
	}

	func restoreIfNeeded() async {
		guard !didRestore else { return }
		didRestore = true
		await restore()
	}

	func restore() async {
		guard !isBusy, state != .accountDeleted else { return }
		isBusy = true
		defer { isBusy = false }
		errorMessage = nil
		do {
			guard let token = try tokens.read() else {
				state = .signedOut
				return
			}
			try await loadUser(token: token)
		} catch {
			state = .unavailable
			errorMessage = error.localizedDescription
		}
	}

	func submit(email: String, password: String, mode: AuthMode) async {
		guard !isBusy, state != .accountDeleted else { return }
		let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		guard !email.isEmpty, !password.isEmpty else {
			errorMessage = "メールアドレスとパスワードを入力してください。"
			return
		}
		// bcrypt accepts at most 72 bytes; do not silently truncate a password.
		guard password.utf8.count <= 72 else {
			errorMessage = "パスワードはUTF-8で72バイト以内にしてください。"
			return
		}
		isBusy = true
		defer { isBusy = false }
		errorMessage = nil
		do {
			let token: String
			switch mode {
			case .signup:
				token = try await api.signUp(email: email, password: password)
			case .login:
				token = try await api.login(email: email, password: password)
			}
			try tokens.save(token)
			// Preserve the token if /me temporarily fails after signup succeeds.
			do { try await loadUser(token: token) } catch {
				state = .unavailable
				errorMessage = error.localizedDescription
			}
		} catch {
			errorMessage = error.localizedDescription
		}
	}

	func deleteAccount() async {
		guard !isBusy, case .signedIn = state else { return }
		isBusy = true
		isDeletingAccount = true
		errorMessage = nil
		defer {
			isDeletingAccount = false
			isBusy = false
		}
		do {
			guard let token = try tokens.read(), !token.isEmpty else {
				expireSession()
				return
			}
			try await api.deleteAccount(token: token)
			finishAccountDeletion()
		} catch is CancellationError {
			return
		} catch AuthError.unauthorized {
			expireSession()
		} catch {
			errorMessage = error.localizedDescription
		}
	}

	func retryAccountCleanup() {
		guard !isBusy, state == .accountDeleted else { return }
		finishAccountDeletion()
	}

	private func finishAccountDeletion() {
		state = .accountDeleted
		errorMessage = nil
		do {
			try tokens.delete()
			state = .signedOut
		} catch {
			errorMessage = "アカウントの削除は完了していますが、この端末のログイン情報を消去できませんでした。再試行してください。"
		}
	}

	func logout() {
		guard !isBusy else { return }
		do {
			try tokens.delete()
			errorMessage = nil
			state = .signedOut
		} catch { errorMessage = error.localizedDescription }
	}

	func expireSession() {
		do {
			try tokens.delete()
			state = .signedOut
			errorMessage = "ログインの有効期限が切れました。再度ログインしてください。"
		} catch {
			state = .unavailable
			errorMessage = error.localizedDescription
		}
	}

	func clearError() { errorMessage = nil }

	private func loadUser(token: String) async throws {
		do { state = .signedIn(try await api.fetchCurrentUser(token: token)) } catch AuthError
			.unauthorized
		{
			try tokens.delete()
			state = .signedOut
			errorMessage = "ログインの有効期限が切れました。再度ログインしてください。"
		}
	}
}
