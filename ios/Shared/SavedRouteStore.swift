import Foundation
import WidgetKit

protocol SavedRouteStoring {
	func load() throws -> [SavedRoute]
	func save(_ routes: [SavedRoute]) throws
}

struct SavedRouteStore: SavedRouteStoring {
	static let groupID = "group.com.rintaro.RouteTap"
	static let widgetKind = "RouteTapRouteWidget"
	private let fileURL: URL?
	private let reloadWidgets: () -> Void

	private struct Document: Codable {
		let version: Int
		let routes: [SavedRoute]
	}

	init(
		fileURL: URL? = SavedRouteStore.defaultFileURL,
		reloadWidgets: @escaping () -> Void = {
			WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
		}
	) {
		self.fileURL = fileURL
		self.reloadWidgets = reloadWidgets
	}

	static var defaultFileURL: URL? {
		let directory = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: groupID)
		// UIテストの保存先だけ分離し、実際のルートを変更しない。
		#if DEBUG
			if let value = ProcessInfo.processInfo.environment["ROUTETAP_UI_TEST_STORE_ID"],
				let id = UUID(uuidString: value)
			{
				return directory?.appendingPathComponent("uitest-\(id.uuidString).json")
			}
		#endif
		return directory?.appendingPathComponent("local-saved-routes-v1.json")
	}

	func load() throws -> [SavedRoute] {
		guard let fileURL else { throw SavedRouteStorageError.unavailable }
		let data: Data
		do {
			data = try Data(contentsOf: fileURL)
		} catch CocoaError.fileReadNoSuchFile {
			return []
		} catch {
			throw SavedRouteStorageError.readFailed
		}
		guard let document = try? JSONDecoder().decode(Document.self, from: data),
			document.version == 1,
			Set(document.routes.map(\.id)).count == document.routes.count
		else { throw SavedRouteStorageError.readFailed }
		return document.routes
	}

	func save(_ routes: [SavedRoute]) throws {
		guard let fileURL else { throw SavedRouteStorageError.unavailable }
		// 読めない既存ファイルを、空の一覧などで上書きしない。
		_ = try load()
		guard Set(routes.map(\.id)).count == routes.count else {
			throw SavedRouteStorageError.writeFailed
		}
		do {
			let data = try JSONEncoder().encode(Document(version: 1, routes: routes))
			try data.write(
				to: fileURL,
				options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
		} catch {
			throw SavedRouteStorageError.writeFailed
		}
		reloadWidgets()
	}
}

enum SavedRouteStorageError: LocalizedError {
	case unavailable, readFailed, writeFailed

	var errorDescription: String? {
		switch self {
		case .unavailable: "保存場所を開けません。アプリの共有設定を確認してください。"
		case .readFailed: "保存した移動を読み込めませんでした。データは上書きしていません。もう一度お試しください。"
		case .writeFailed: "移動を保存できませんでした。端末の空き容量などを確認して、もう一度お試しください。"
		}
	}
}
