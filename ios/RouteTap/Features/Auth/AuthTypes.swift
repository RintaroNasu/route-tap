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
