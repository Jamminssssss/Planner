import Foundation
import CryptoKit
import LocalAuthentication
import Security
import SwiftUI
import SwiftData
import Combine

// MARK: - Diary Lock Manager

@MainActor
final class DiaryLockManager: ObservableObject {

    static let shared = DiaryLockManager()

    @Published private(set) var isAuthenticating = false
    private var unlockedIDs: Set<PersistentIdentifier> = []

    private let keychainService = Bundle.main.bundleIdentifier.map { "\($0).diaryLock" } ?? "com.diary.app.diaryLock"
    private let keychainAccount = "diaryMasterKey"

    private init() {}

    // MARK: - Session Management
    func isSessionUnlocked(for entry: DiaryEntry) -> Bool {
        guard entry.isLocked else { return true }
        return unlockedIDs.contains(entry.persistentModelID)
    }

    func clearAllSessions() { unlockedIDs.removeAll() }
    func clearSession(for entry: DiaryEntry) { unlockedIDs.remove(entry.persistentModelID) }

    // MARK: - Authentication
    
    /// 💡 핵심 버그 수정: LAContext의 .deviceOwnerAuthentication은 OS 차원에서
    /// 자동으로 '생체 인식 시도 -> 실패/미지원 시 비밀번호 입력창'으로 물 흐르듯 처리해 줍니다.
    func authenticate(reason: String = "Authenticate to access your diary") async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        var error: NSError?
        
        // 기기 비밀번호 등 어떠한 방식의 인증이라도 가능한지 체크
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print("[DiaryLock] ❌ deviceOwnerAuthentication unavailable: \(error?.localizedDescription ?? "")")
            throw LockError.biometricUnavailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            guard success else {
                print("[DiaryLock] ❌ Authentication returned false")
                throw LockError.authenticationFailed
            }
            print("[DiaryLock] ✅ Authentication succeeded")
            
        } catch let laError as LAError {
            print("[DiaryLock] LAError code=\(laError.code.rawValue)")
            switch laError.code {
            case .userCancel, .appCancel, .systemCancel:
                throw LockError.userCancelled
            default:
                throw LockError.authenticationFailed
            }
        }
    }

    // MARK: - Unlock Entry
    func unlockEntry(_ entry: DiaryEntry) async throws -> (text: String, imageDatas: [Data]) {
        guard entry.isLocked else { return (entry.text, entry.sortedImages.map { $0.imageData }) }

        if unlockedIDs.contains(entry.persistentModelID) { return try decryptEntryContent(entry) }

        try await authenticate(reason: "Unlock \(entry.previewTitle)")
        let result = try decryptEntryContent(entry)
        unlockedIDs.insert(entry.persistentModelID)
        return result
    }

    func decryptEntryContent(_ entry: DiaryEntry) throws -> (text: String, imageDatas: [Data]) {
        let key = try getMasterKey()
        let text: String
        if let enc = entry.encryptedText, !enc.isEmpty { text = try decryptString(enc, using: key) }
        else { text = entry.text }

        var imageDatas: [Data] = []
        for img in entry.sortedImages {
            if let enc = img.encryptedData, !enc.isEmpty, let dec = try? decryptData(enc, using: key) {
                imageDatas.append(dec)
            } else if !img.imageData.isEmpty {
                imageDatas.append(img.imageData)
            }
        }
        return (text, imageDatas)
    }

    // MARK: - Lock Entry
    func lockEntry(_ entry: DiaryEntry, text: String, imageDataList: [Data], in context: ModelContext) throws {
        let key = try getMasterKey()
        entry.encryptedText = try encryptString(text, using: key)
        entry.text = ""

        let images = entry.sortedImages
        for (i, img) in images.enumerated() {
            if i < imageDataList.count {
                img.encryptedData = try encryptData(imageDataList[i], using: key)
                img.imageData = Data()
            }
        }
        entry.isLocked = true
        unlockedIDs.remove(entry.persistentModelID)
        try context.save()
    }

    func prepareNewLockedEntry(_ entry: DiaryEntry, text: String, imageDataList: [Data]) throws {
        let key = try getMasterKey()
        entry.encryptedText = try encryptString(text, using: key)
        entry.text = ""

        let images = entry.sortedImages
        for (i, img) in images.enumerated() where i < imageDataList.count {
            img.encryptedData = try encryptData(imageDataList[i], using: key)
            img.imageData = Data()
        }
        entry.isLocked = true
    }

    func reEncryptEntry(_ entry: DiaryEntry, newText: String, newImageDataList: [Data], in context: ModelContext) throws {
        let key = try getMasterKey()
        entry.encryptedText = try encryptString(newText, using: key)
        entry.text = ""

        let images = entry.sortedImages
        for (i, img) in images.enumerated() {
            if i < newImageDataList.count {
                img.encryptedData = try encryptData(newImageDataList[i], using: key)
                img.imageData = Data()
            } else {
                img.encryptedData = nil
                img.imageData = Data()
            }
        }
        entry.isLocked = true
        try context.save()
    }

    // MARK: - Remove Lock
    func removeLock(from entry: DiaryEntry, in context: ModelContext) async throws {
        guard entry.isLocked else { return }
        try await authenticate(reason: "Remove protection from this entry")
        let key = try getMasterKey()

        if let enc = entry.encryptedText, !enc.isEmpty {
            entry.text = try decryptString(enc, using: key)
            entry.encryptedText = nil
        }
        for img in entry.sortedImages {
            if let enc = img.encryptedData, !enc.isEmpty {
                img.imageData = try decryptData(enc, using: key)
                img.encryptedData = nil
            }
        }
        entry.isLocked = false
        unlockedIDs.remove(entry.persistentModelID)
        try context.save()
    }

    // MARK: - AES-256-GCM
    func encryptString(_ string: String, using key: SymmetricKey) throws -> Data {
        guard let data = string.data(using: .utf8) else { throw LockError.encryptionFailed }
        return try encryptData(data, using: key)
    }

    func encryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(data, using: key)
        guard let combined = box.combined else { throw LockError.encryptionFailed }
        return combined
    }

    func decryptString(_ data: Data, using key: SymmetricKey) throws -> String {
        let plain = try decryptData(data, using: key)
        guard let string = String(data: plain, encoding: .utf8) else { throw LockError.decryptionFailed }
        return string
    }

    func decryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    // MARK: - Keychain
    func getMasterKey() throws -> SymmetricKey {
        if let existing = try? loadKeyFromKeychain() { return existing }
        let fresh = SymmetricKey(size: .bits256)
        try saveKeyToKeychain(fresh)
        return fresh
    }

    private func saveKeyToKeychain(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        SecItemDelete(attrs as CFDictionary)
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else { throw LockError.keychainWrite(status) }
    }

    private func loadKeyFromKeychain() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ref: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &ref)
        guard status == errSecSuccess, let data = ref as? Data else { throw LockError.keyNotFound }
        return SymmetricKey(data: data)
    }

    // MARK: - Biometric Info
    var biometryType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    var biometryName: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    var biometrySystemImage: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }
}

// MARK: - Lock Errors
enum LockError: LocalizedError {
    case biometricUnavailable
    case authenticationFailed
    case userCancelled
    case encryptionFailed
    case decryptionFailed
    case keyNotFound
    case keychainWrite(OSStatus)

    var errorDescription: String? {
        switch self {
        case .biometricUnavailable: return "Authentication is not available on this device right now."
        case .authenticationFailed: return "Authentication failed. Please try again."
        case .userCancelled: return nil
        case .encryptionFailed: return "Could not encrypt this entry."
        case .decryptionFailed: return "Could not decrypt this entry."
        case .keyNotFound: return "Encryption key not found."
        case .keychainWrite(let s): return "Keychain write failed (OSStatus \(s))."
        }
    }
}
