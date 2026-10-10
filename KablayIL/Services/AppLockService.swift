import CryptoKit
import Foundation
import LocalAuthentication
import Observation
import Security

struct AppLockCredential: Codable, Equatable {
    let salt: Data
    let digest: Data
    var biometricsEnabled: Bool
}

enum AppLockError: LocalizedError {
    case invalidPIN
    case randomGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidPIN: "PIN must contain exactly six digits."
        case .randomGenerationFailed: "Could not securely create the app PIN."
        }
    }
}

@MainActor
@Observable
final class AppLockService {
    private(set) var credential: AppLockCredential?
    private(set) var isLocked = false
    private(set) var failedAttempts = 0
    private(set) var retryAfter: Date?

    init() {
        credential = KeychainStore.loadLockCredential()
    }

    var isConfigured: Bool { credential != nil }
    var biometricsEnabled: Bool { credential?.biometricsEnabled == true }
    var remainingDelay: Int {
        guard let retryAfter else { return 0 }
        return max(0, Int(ceil(retryAfter.timeIntervalSinceNow)))
    }

    var biometricSymbol: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType == .touchID ? "touchid" : "faceid"
    }

    var biometricsAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func onSessionRestored() {
        isLocked = credential != nil
    }

    func onAuthenticated() {
        isLocked = false
    }

    func lock() {
        guard credential != nil else { return }
        isLocked = true
    }

    func configure(pin: String, biometricsEnabled: Bool) throws {
        guard Self.isValidPIN(pin) else { throw AppLockError.invalidPIN }
        var salt = Data(count: 32)
        let status = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard status == errSecSuccess else { throw AppLockError.randomGenerationFailed }
        let newCredential = AppLockCredential(
            salt: salt,
            digest: Self.digest(pin: pin, salt: salt),
            biometricsEnabled: biometricsEnabled && biometricsAvailable
        )
        try KeychainStore.saveLockCredential(newCredential)
        credential = newCredential
        isLocked = false
        failedAttempts = 0
        retryAfter = nil
    }

    func verify(pin: String) -> Bool {
        guard let credential, remainingDelay == 0, Self.isValidPIN(pin) else { return false }
        let candidate = Self.digest(pin: pin, salt: credential.salt)
        guard Self.constantTimeEqual(candidate, credential.digest) else {
            failedAttempts += 1
            if failedAttempts >= 5 {
                retryAfter = Date().addingTimeInterval(30)
                failedAttempts = 0
            }
            return false
        }
        isLocked = false
        failedAttempts = 0
        retryAfter = nil
        return true
    }

    func unlockWithBiometrics(reason: String) async -> Bool {
        guard biometricsEnabled, biometricsAvailable else { return false }
        let context = LAContext()
        context.localizedCancelTitle = "PIN"
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if success { isLocked = false }
            return success
        } catch {
            return false
        }
    }

    func setBiometricsEnabled(_ enabled: Bool) throws {
        guard var credential else { return }
        credential.biometricsEnabled = enabled && biometricsAvailable
        try KeychainStore.saveLockCredential(credential)
        self.credential = credential
    }

    func removeProtection() {
        KeychainStore.clearLockCredential()
        credential = nil
        isLocked = false
        failedAttempts = 0
        retryAfter = nil
    }

    nonisolated static func isValidPIN(_ pin: String) -> Bool {
        pin.count == 6 && pin.allSatisfy(\.isNumber)
    }

    nonisolated static func digest(pin: String, salt: Data) -> Data {
        var input = salt
        input.append(Data(pin.utf8))
        return Data(SHA256.hash(data: input))
    }

    nonisolated private static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).reduce(UInt8(0)) { result, pair in result | (pair.0 ^ pair.1) } == 0
    }
}
