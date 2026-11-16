import Foundation

enum SavedRouteError: LocalizedError {
	case notFound

	var errorDescription: String? {
		"この移動は見つかりませんでした。一覧を読み込み直してください。"
	}
}
