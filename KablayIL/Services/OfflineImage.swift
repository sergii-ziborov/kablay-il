import CryptoKit
import Foundation
import SwiftUI
import UIKit

struct SavedImage: Sendable {
    let data: Data
    let fetchedAt: Date
}

/// URLCache may evict images at any time and AsyncImage has no offline
/// guarantee. These files are the app's own last known good image library.
actor OfflineImageStore {
    static let shared = OfflineImageStore()
    static let refreshAfter: TimeInterval = 7 * 24 * 60 * 60

    private let directory: URL
    private let session: URLSession

    init(directory: URL? = nil, session: URLSession? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KABLAYOffline/v1/media", isDirectory: true)
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func cached(_ url: URL) -> SavedImage? {
        let file = imageURL(url)
        guard let data = try? Data(contentsOf: file),
              let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              let date = attributes[.modificationDate] as? Date else { return nil }
        return SavedImage(data: data, fetchedAt: date)
    }

    func fetch(_ url: URL) async throws -> SavedImage {
        guard url.scheme?.lowercased() == "https" else { throw URLError(.unsupportedURL) }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 25
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              !data.isEmpty, data.count <= 12 * 1024 * 1024,
              UIImage(data: data) != nil else { throw URLError(.cannotDecodeContentData) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = imageURL(url)
        try data.write(to: file, options: .atomic)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: file.path
        )
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableFile = file
        try? mutableFile.setResourceValues(resourceValues)
        return SavedImage(data: data, fetchedAt: .now)
    }

    func prefetch(_ urls: [URL]) async {
        var seen = Set<URL>()
        let unique = urls.filter {
            $0.scheme?.lowercased() == "https" && seen.insert($0).inserted
        }.prefix(160)
        await withTaskGroup(of: Void.self) { group in
            var pending = Array(unique)[...]
            for _ in 0..<min(4, pending.count) {
                let url = pending.removeFirst()
                group.addTask { await self.refreshIfNeeded(url) }
            }
            while await group.next() != nil, !pending.isEmpty {
                let url = pending.removeFirst()
                group.addTask { await self.refreshIfNeeded(url) }
            }
        }
    }

    func remove(_ urls: [URL]) {
        for url in urls { try? FileManager.default.removeItem(at: imageURL(url)) }
    }

    /// Remove only images that no longer belong to the refreshed catalogs and
    /// have not been fetched for 90 days. Current content remains available.
    func prune(keeping urls: [URL], now: Date = .now) {
        let keep = Set(urls.map { digest($0.absoluteString) })
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles
        ) else { return }
        for file in files where file.pathExtension == "image" {
            guard !keep.contains(file.deletingPathExtension().lastPathComponent),
                  let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  now.timeIntervalSince(date) > 90 * 24 * 60 * 60 else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func refreshIfNeeded(_ url: URL) async {
        if let cached = cached(url),
           !OfflineFreshness.needsRefresh(cached.fetchedAt, after: Self.refreshAfter) { return }
        _ = try? await fetch(url)
    }

    private func imageURL(_ url: URL) -> URL {
        directory.appendingPathComponent("\(digest(url.absoluteString)).image")
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Drop-in image view for the AsyncImage phase-style call sites. It displays
/// saved pixels first and refreshes them in the background when they age.
struct OfflineImage<Content: View>: View {
    let url: URL?
    let transaction: Transaction
    let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.transaction = transaction
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        phase = .empty
        guard let url else { return }
        var hadSavedImage = false
        if let saved = await OfflineImageStore.shared.cached(url), let image = UIImage(data: saved.data) {
            hadSavedImage = true
            withTransaction(transaction) { phase = .success(Image(uiImage: image)) }
            if !OfflineFreshness.needsRefresh(saved.fetchedAt, after: OfflineImageStore.refreshAfter) { return }
        }
        do {
            let saved = try await OfflineImageStore.shared.fetch(url)
            guard !Task.isCancelled, let image = UIImage(data: saved.data) else { return }
            withTransaction(transaction) { phase = .success(Image(uiImage: image)) }
        } catch {
            if !hadSavedImage, !Task.isCancelled { phase = .failure(error) }
        }
    }
}
