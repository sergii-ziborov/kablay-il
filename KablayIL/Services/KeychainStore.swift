import Foundation
import Security

protocol SessionStoring {
    func loadSession() -> AuthSession?
    func saveSession(_ session: AuthSession) throws
    func clearSession()
}

struct KeychainSessionStore: SessionStoring {
    func loadSession() -> AuthSession? {
        KeychainStore.load()
    }

    func saveSession(_ session: AuthSession) throws {
        try KeychainStore.save(session)
    }

    func clearSession() {
        KeychainStore.clear()
    }
}

enum KeychainStore {
    private static let service = "il.co.kablay.app"
    private static let sessionAccount = "auth-session"
    private static let lockAccount = "app-lock"

    static func save(_ session: AuthSession) throws {
        try save(try JSONEncoder().encode(session), account: sessionAccount)
    }

    static func load() -> AuthSession? {
        guard let data = load(account: sessionAccount) else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    static func clear() {
        delete(account: sessionAccount)
    }

    static func saveLockCredential(_ credential: AppLockCredential) throws {
        try save(try JSONEncoder().encode(credential), account: lockAccount)
    }

    static func loadLockCredential() -> AppLockCredential? {
        guard let data = load(account: lockAccount) else { return nil }
        return try? JSONDecoder().decode(AppLockCredential.self, from: data)
    }

    static func clearLockCredential() {
        delete(account: lockAccount)
    }

    private static func save(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    private static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
