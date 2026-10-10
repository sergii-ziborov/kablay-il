import UIKit
import XCTest
@testable import KablayIL

private final class ImageFixtureProtocol: URLProtocol {
    static var imageData: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let data = Self.imageData else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "image/png"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class OfflineCacheTests: XCTestCase {
    func testPrivateSnapshotsSurviveRestartButStayAccountIsolated() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let article = BlogArticle(
            id: "repair-guide", title: .init(he: "מדריך", ru: "Гайд", en: "Guide"),
            summary: .init(he: "סיכום", ru: "Описание", en: "Summary"), categoryID: "plumbing",
            readingMinutes: 4, coverURL: URL(string: "https://kablay.co.il/cover.jpg"),
            publishedAt: date, content: .init(he: "<p>שלום</p>", ru: "<p>Текст</p>", en: "<p>Text</p>")
        )

        XCTAssertEqual(OfflineDataStore.save([article], key: "articles", accountID: "one", baseURL: directory, date: date), date)
        let restored = try XCTUnwrap(OfflineDataStore.load([BlogArticle].self, key: "articles", accountID: "one", baseURL: directory))
        XCTAssertEqual(restored.savedAt, date)
        XCTAssertEqual(restored.value, [article])
        XCTAssertNil(OfflineDataStore.load([BlogArticle].self, key: "articles", accountID: "two", baseURL: directory))

        OfflineDataStore.removeAccount("one", baseURL: directory)
        XCTAssertNil(OfflineDataStore.load([BlogArticle].self, key: "articles", accountID: "one", baseURL: directory))
    }

    func testFreshnessUsesServerConfirmationTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(OfflineFreshness.needsRefresh(nil, after: 300, now: now))
        XCTAssertFalse(OfflineFreshness.needsRefresh(now.addingTimeInterval(-299), after: 300, now: now))
        XCTAssertTrue(OfflineFreshness.needsRefresh(now.addingTimeInterval(-300), after: 300, now: now))
    }

    func testImageRemainsReadableAfterNetworkFails() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            ImageFixtureProtocol.imageData = nil
            try? FileManager.default.removeItem(at: directory)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageFixtureProtocol.self]
        let session = URLSession(configuration: configuration)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        let imageData = renderer.pngData { context in
            UIColor.red.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        ImageFixtureProtocol.imageData = imageData
        let store = OfflineImageStore(directory: directory, session: session)
        let url = try XCTUnwrap(URL(string: "https://kablay.co.il/example.png"))

        _ = try await store.fetch(url)
        ImageFixtureProtocol.imageData = nil
        let saved = await store.cached(url)
        XCTAssertEqual(saved?.data, imageData)
        XCTAssertNotNil(saved?.fetchedAt)

        let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first)
        let old = Date().addingTimeInterval(-91 * 24 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: file.path)
        await store.prune(keeping: [url])
        let relevant = await store.cached(url)
        XCTAssertNotNil(relevant, "A referenced image must stay available even when old")
        await store.prune(keeping: [])
        let irrelevant = await store.cached(url)
        XCTAssertNil(irrelevant, "An old, unreferenced image should be removed")
    }
}
