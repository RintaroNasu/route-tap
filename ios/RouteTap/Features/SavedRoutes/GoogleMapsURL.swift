import Foundation

enum GoogleMapsURL {
	static func directions(for route: SavedRoute, direction: RouteDirection) throws -> URL {
		try directions(
			origin: direction.origin(for: route), destination: direction.destination(for: route))
	}

	static func directions(origin: String, destination: String) throws -> URL {
		let origin = origin.trimmingCharacters(in: .whitespacesAndNewlines)
		let destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !origin.isEmpty, !destination.isEmpty else {
			throw GoogleMapsURLError.missingPlace
		}

		var components = URLComponents()
		components.scheme = "https"
		components.host = "www.google.com"
		components.path = "/maps/dir/"
		components.queryItems = [
			URLQueryItem(name: "api", value: "1"),
			URLQueryItem(name: "origin", value: origin),
			URLQueryItem(name: "destination", value: destination),
			URLQueryItem(name: "travelmode", value: "transit"),
		]
		// Google Mapsでは「+」が空白と解釈されるため、文字としてエンコードする。
		components.percentEncodedQuery = components.percentEncodedQuery?
			.replacingOccurrences(of: "+", with: "%2B")
			.replacingOccurrences(of: ",", with: "%2C")

		guard let url = components.url else { throw GoogleMapsURLError.invalidURL }
		guard url.absoluteString.count <= 2048 else { throw GoogleMapsURLError.tooLong }
		return url
	}
}

enum GoogleMapsURLError: LocalizedError, Equatable {
	case missingPlace, invalidURL, tooLong

	var errorDescription: String? {
		switch self {
		case .missingPlace: "出発地と目的地を確認してください。"
		case .invalidURL: "経路検索のURLを作成できませんでした。"
		case .tooLong: "場所の情報が長すぎます。出発地・目的地を短くして登録し直してください。"
		}
	}
}
