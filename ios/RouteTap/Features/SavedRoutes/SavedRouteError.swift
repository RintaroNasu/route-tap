import Foundation

enum SavedRouteError: LocalizedError, Equatable {
	case configuration, connection, invalidResponse, invalidInput, unauthorized, server

	var errorDescription: String? {
		switch self {
		case .configuration: "接続先が設定されていません。APIの接続設定を確認してください。"
		case .connection: "サーバーに接続できません。通信環境を確認して、もう一度お試しください。"
		case .invalidResponse: "サーバーからの応答を確認できませんでした。もう一度お試しください。"
		case .invalidInput: "表示名・出発地・目的地の入力内容を確認してください。"
		case .unauthorized: "ログインの有効期限が切れました。再度ログインしてください。"
		case .server: "サーバーで問題が発生しました。時間をおいてお試しください。"
		}
	}
}
