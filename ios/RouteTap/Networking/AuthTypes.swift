import Foundation

struct AuthenticatedUser: Decodable, Equatable {
	let id: UInt
	let email: String
}

enum AuthMode: String {
	case login, signup

	var title: String { self == .login ? "ログイン" : "新規登録" }
	var buttonTitle: String { self == .login ? "ログイン" : "アカウントを作成" }
}

enum AuthError: LocalizedError {
	case configuration, invalidResponse, unauthorized, duplicateEmail, invalidInput, server,
		connection, keychain

	var errorDescription: String? {
		switch self {
		case .configuration: "接続先が設定されていません。APIの接続設定を確認してください。"
		case .invalidResponse: "サーバーからの応答を確認できませんでした。もう一度お試しください。"
		case .unauthorized: "メールアドレスまたはパスワードが正しくありません。再度ログインしてください。"
		case .duplicateEmail: "このメールアドレスは登録済みです。ログインしてください。"
		case .invalidInput: "メールアドレスとパスワードを確認してください。"
		case .server: "サーバーで問題が発生しました。時間をおいてお試しください。"
		case .connection: "サーバーに接続できません。通信環境を確認して、もう一度お試しください。"
		case .keychain: "ログイン情報を安全に保存・読み込みできませんでした。もう一度お試しください。"
		}
	}
}
