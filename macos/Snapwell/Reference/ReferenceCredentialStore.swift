import Foundation
import Security
import CryptoKit

/// Keychain only: an unavailable Keychain is an error, never a plaintext fallback.
enum ReferenceCredentialStore {
    private static let namespace = "com.vaultline.reference.connections"
    static func account(endpoint: String) -> String {
        SHA256.hash(data: Data(endpoint.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private static func query(_ endpoint: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: namespace,
         kSecAttrAccount as String: account(endpoint: endpoint)]
    }
    static func save(_ token: String, endpoint: String) throws {
        var q = query(endpoint)
        let attributes: [String: Any] = [kSecValueData as String: Data(token.utf8), kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let update = SecItemUpdate(q as CFDictionary, attributes as CFDictionary)
        if update == errSecItemNotFound {
            q.merge(attributes) { _, value in value }; try check(SecItemAdd(q as CFDictionary, nil))
        } else { try check(update) }
    }
    static func load(endpoint: String) throws -> String? {
        var q = query(endpoint); q[kSecReturnData as String] = true
        var result: AnyObject?; let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }; try check(status)
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else { throw ReferenceError.message("The stored connection credential could not be read.") }
        return value
    }
    static func forget(endpoint: String) throws { let status = SecItemDelete(query(endpoint) as CFDictionary); if status != errSecItemNotFound { try check(status) } }
    private static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw ReferenceError.message("Keychain access failed (\(status)). The credential was not saved to a file.") }
    }
}
