import Foundation
import Security

protocol TokenStoring {
	func read() throws -> String?
	func save(_ token: String) throws
	func delete() throws
}

struct KeychainTokenStore: TokenStoring {
	// Keep sessions for different API environments separate.
	private let service =
		(Bundle.main.bundleIdentifier ?? "RouteTap") + ".auth."
		+ (APIConfiguration.baseURL?.absoluteString ?? "unconfigured")

	private var query: [String: Any] {
		[
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: "access-token",
		]
	}

	func read() throws -> String? {
		var query = query
		query[kSecReturnData as String] = true
		query[kSecMatchLimit as String] = kSecMatchLimitOne
		var result: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &result)
		if status == errSecItemNotFound { return nil }
		guard status == errSecSuccess, let data = result as? Data,
			let token = String(data: data, encoding: .utf8)
		else { throw AuthError.keychain }
		return token
	}

	func save(_ token: String) throws {
		let values: [String: Any] = [
			kSecValueData as String: Data(token.utf8),
			kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
		]
		let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
		if status == errSecItemNotFound {
			let status = SecItemAdd(
				query.merging(values) { _, new in new } as CFDictionary, nil)
			guard status == errSecSuccess else { throw AuthError.keychain }
		} else if status != errSecSuccess {
			throw AuthError.keychain
		}
	}

	func delete() throws {
		let status = SecItemDelete(query as CFDictionary)
		guard status == errSecSuccess || status == errSecItemNotFound else {
			throw AuthError.keychain
		}
	}
}
