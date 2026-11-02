import Foundation

enum APIConfiguration {
	static var baseURL: URL? {
		let configuredAddress = Bundle.main.object(forInfoDictionaryKey: "RouteTapAPIBaseURL") as? String
		var address = configuredAddress ?? ""

		#if DEBUG
			let environmentAddress = ProcessInfo.processInfo.environment["ROUTETAP_API_BASE_URL"]
			if let environmentAddress {
				address = environmentAddress
			}
		#endif

		guard let url = URL(string: address) else {
			return nil
		}
		guard url.host != nil else {
			return nil
		}
		guard url.user == nil, url.password == nil else {
			return nil
		}

		#if DEBUG
			guard url.scheme == "http" || url.scheme == "https" else {
				return nil
			}
		#else
			guard url.scheme == "https" else {
				return nil
			}
		#endif

		return url
	}
}
