import Foundation
import XCTest
@testable import KablayIL

/// Wire-contract regression tests; no production requests or order mutations.
final class ProductionAPICompatibilityTests: XCTestCase {
    private func client(_ fixture: String) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProductionFixtureURLProtocol.self]
        let base = URL(string: "https://release-fixture.invalid/\(fixture)/")!
        return APIClient(apiBaseURL: base, triageBaseURL: base,
                         session: URLSession(configuration: configuration))
    }

    func testAttachmentFieldOrderWithObjectAnswers() async throws {
        let leads = try await client("object").fetchProfessionalLeads(token: "fixture-only")
        let lead = try XCTUnwrap(leads.first)
        XCTAssertEqual(leads.count, 1)
        XCTAssertEqual(lead.attachmentURLs.map(\.lastPathComponent),
                       ["top.jpg", "attachment.jpg", "image.jpg", "photo.jpg", "file.jpg", "media.jpg"])
        XCTAssertTrue(lead.attachmentURLs.allSatisfy { $0.host == "release-fixture.invalid" })
    }

    func testAttachmentFieldOrderWithSQLiteJSONStringAnswers() async throws {
        let leads = try await client("string").fetchProfessionalLeads(token: "fixture-only")
        let lead = try XCTUnwrap(leads.first)
        XCTAssertEqual(lead.attachmentURLs.map(\.lastPathComponent),
                       ["top.jpg", "attachment.jpg", "image.jpg", "photo.jpg", "file.jpg", "media.jpg"])
    }

    func testAbsentOptionalAttachmentsStayEmpty() async throws {
        let leads = try await client("missing").fetchProfessionalLeads(token: "fixture-only")
        XCTAssertEqual(leads.count, 1)
        XCTAssertTrue(try XCTUnwrap(leads.first).attachmentURLs.isEmpty)
    }

    func testCatalogUsesActualSnakeCaseMobileContract() async throws {
        let catalog = try await client("catalog").fetchServiceCatalog()
        XCTAssertEqual(catalog.version, "2026-08-31.1")
        XCTAssertEqual(catalog.categories.count, 1)
        let category = try XCTUnwrap(catalog.categories.first)
        XCTAssertEqual(category.id, "plumbing")
        XCTAssertEqual(category.groups.count, 1)
        XCTAssertEqual(category.groups.first?.services.first?.en, "Leak repair")
    }
}

private final class ProductionFixtureURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              url.host == "release-fixture.invalid",
              request.httpMethod == "GET" else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let fixture = url.path.split(separator: "/").first.map(String.init) ?? ""
            let payload: [String: Any]
            if fixture == "catalog", url.path.hasSuffix("/catalog/v1") {
                let service: [String: Any] = [
                    "id": "fixture-service", "task_type_id": "subcategory.fixture-service",
                    "title": ["he": "תיקון נזילה", "ru": "Ремонт течи", "en": "Leak repair"]
                ]
                let group: [String: Any] = [
                    "id": "leaks", "title": ["he": "נזילות", "ru": "Течи", "en": "Leaks"],
                    "services": [service]
                ]
                let category: [String: Any] = [
                    "id": "plumbing", "database_id": "fixture-category",
                    "title": ["he": "אינסטלציה", "ru": "Сантехника", "en": "Plumbing"],
                    "system_image": "wrench.and.screwdriver.fill", "tint_hex": "337CCF",
                    "groups": [group]
                ]
                payload = ["version": "2026-08-31.1",
                           "generated_at": "2026-09-30T00:00:00.000Z", "categories": [category]]
            } else if ["object", "string", "missing"].contains(fixture),
                      url.path.hasSuffix("/specialists/me/available-tasks") {
                var task: [String: Any] = [
                    "id": "fixture-task", "title": "Fixture task", "category_slug": "plumbing",
                    "city": "haifa", "created_at": "2026-09-30T00:00:00.000Z"
                ]
                if fixture != "missing" {
                    let fields = [
                        "attachments": ["/media/top.jpg", "/media/attachment.jpg"],
                        "images": ["/media/image.jpg"], "photos": ["/media/photo.jpg"],
                        "files": ["/media/file.jpg"], "media": ["/media/media.jpg"]
                    ]
                    task["attachments"] = ["/media/top.jpg"]
                    if fixture == "string" {
                        let data = try JSONSerialization.data(withJSONObject: fields)
                        task["answers_json"] = String(decoding: data, as: UTF8.self)
                    } else {
                        task["answers_json"] = fields
                    }
                }
                payload = ["tasks": [task], "pages": 1]
            } else {
                throw URLError(.unsupportedURL)
            }
            let data = try JSONSerialization.data(withJSONObject: payload)
            let response = HTTPURLResponse(url: url, statusCode: 200,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
