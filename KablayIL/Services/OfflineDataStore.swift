import CryptoKit
import Foundation
import SwiftUI

/// Last known good server responses live in Application Support, which iOS does
/// not evict like URLCache. A complete successful listing replaces stale rows;
/// a partial page or failed refresh keeps the last known good content.
struct OfflineSnapshot<Value: Codable>: Codable {
    let savedAt: Date
    let value: Value
}

enum OfflineDataStore {
    // JSON encoding, decoding and atomic writes can take seconds for a warm
    // account. Keep them serialized and off SwiftUI's main actor. Serialization
    // also makes a later page's snapshot win over an earlier page's snapshot.
    private static let ioQueue = DispatchQueue(label: "il.co.kablay.offline-snapshots", qos: .utility)

    private static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KABLAYOffline/v1", isDirectory: true)
    }

    static func load<Value: Codable>(
        _ type: Value.Type,
        key: String,
        accountID: String? = nil,
        baseURL: URL? = nil
    ) -> OfflineSnapshot<Value>? {
        let url = fileURL(key: key, accountID: accountID, baseURL: baseURL)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(OfflineSnapshot<Value>.self, from: data)
    }

    static func loadAsync<Value: Codable>(
        _ type: Value.Type,
        key: String,
        accountID: String? = nil
    ) async -> OfflineSnapshot<Value>? {
        await withCheckedContinuation { continuation in
            ioQueue.async {
                continuation.resume(returning: load(type, key: key, accountID: accountID))
            }
        }
    }

    @discardableResult
    static func save<Value: Codable>(
        _ value: Value,
        key: String,
        accountID: String? = nil,
        baseURL: URL? = nil,
        date: Date = .now
    ) -> Date? {
        let url = fileURL(key: key, accountID: accountID, baseURL: baseURL)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(OfflineSnapshot(savedAt: date, value: value))
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableURL = url
            try? mutableURL.setResourceValues(values)
            return date
        } catch {
            return nil
        }
    }

    /// Queue a complete immutable value snapshot without blocking a frame.
    /// Callers already have fresh server data in memory; the returned date is
    /// the timestamp that will be written with this snapshot.
    @discardableResult
    static func saveDeferred<Value: Codable>(
        _ value: Value,
        key: String,
        accountID: String? = nil,
        date: Date = .now
    ) -> Date {
        ioQueue.async {
            _ = save(value, key: key, accountID: accountID, date: date)
        }
        return date
    }

    static func removeDeferred(key: String, accountID: String? = nil) {
        ioQueue.async { remove(key: key, accountID: accountID) }
    }

    static func removeAccount(_ id: String, baseURL: URL? = nil) {
        let directory = (baseURL ?? root).appendingPathComponent("account-\(digest(id))", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
    }

    static func removeAccountDeferred(_ id: String) {
        ioQueue.async { removeAccount(id) }
    }

    static func remove(key: String, accountID: String? = nil, baseURL: URL? = nil) {
        try? FileManager.default.removeItem(at: fileURL(key: key, accountID: accountID, baseURL: baseURL))
    }

    private static func fileURL(key: String, accountID: String?, baseURL: URL?) -> URL {
        let parent = baseURL ?? root
        let directory = accountID.map { parent.appendingPathComponent("account-\(digest($0))", isDirectory: true) }
            ?? parent.appendingPathComponent("public", isDirectory: true)
        return directory.appendingPathComponent("\(digest(key)).json")
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum OfflineFreshness {
    static let specialists: TimeInterval = 30 * 60
    static let articles: TimeInterval = 12 * 60 * 60
    static let personalTasks: TimeInterval = 5 * 60
    static let availableJobs: TimeInterval = 2 * 60
    static let serviceCatalog: TimeInterval = 24 * 60 * 60

    static func needsRefresh(_ date: Date?, after interval: TimeInterval, now: Date = .now) -> Bool {
        guard let date else { return true }
        return now.timeIntervalSince(date) >= interval
    }
}

/// Show when a list was last confirmed by the server. A saved list remains
/// browsable without connectivity, but no one should mistake it for live jobs.
struct OfflineFreshnessLabel: View {
    let updatedAt: Date?
    let isSavedCopy: Bool
    let staleAfter: TimeInterval
    let locale: AppLocale

    var body: some View {
        if let updatedAt {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let old = OfflineFreshness.needsRefresh(updatedAt, after: staleAfter, now: context.date)
                Label {
                    Text(title(updatedAt: updatedAt, old: old, now: context.date))
                        .font(.caption)
                        .foregroundStyle(old || isSavedCopy ? .orange : .secondary)
                } icon: {
                    Image(systemName: old || isSavedCopy ? "clock.arrow.circlepath" : "checkmark.circle")
                        .foregroundStyle(old || isSavedCopy ? .orange : .green)
                }
                .accessibilityLabel(title(updatedAt: updatedAt, old: old, now: context.date))
            }
        }
    }

    private func title(updatedAt: Date, old: Bool, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale.locale
        formatter.unitsStyle = .full
        let age = formatter.localizedString(for: updatedAt, relativeTo: now)
        let prefix = isSavedCopy
            ? locale.text(he: "עותק שמור", ru: "Сохранённая копия", en: "Saved copy")
            : locale.text(he: "עודכן", ru: "Обновлено", en: "Updated")
        let suffix = old
            ? locale.text(he: " · ייתכן שאינו עדכני", ru: " · может быть неактуально", en: " · may be outdated")
            : ""
        return "\(prefix) \(age)\(suffix)"
    }
}
