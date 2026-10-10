import Foundation

enum MobileContract {
    static let version = "1.0.0"
    static let schemaNames: Set<String> = [
        "Task",
        "TaskDetailResponse",
        "Proposal",
        "Specialist",
        "Completion",
        "Notification",
        "CreditAccount",
        "Catalog",
    ]

    static func validateBundledSnapshot(bundle: Bundle = .main) -> Bool {
        guard let url = bundle.url(forResource: "MobileContract", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["version"] as? String == version,
              let schemas = object["schemas"] as? [String: Any]
        else { return false }
        return schemaNames.isSubset(of: Set(schemas.keys))
    }
}
