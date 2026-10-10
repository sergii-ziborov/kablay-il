import Foundation

enum UserRole: String, Codable {
    case client
    case specialist
    case admin
}

struct SessionUser: Codable, Equatable {
    let id: String
    var name: String
    let phone: String?
    var role: UserRole
    var locale: AppLocale?
    var preferredCity: String? = nil
}

struct AuthSession: Codable, Equatable {
    let token: String
    var user: SessionUser
}

struct TriageResult: Codable, Equatable, Identifiable {
    let category: String
    let serviceID: String?
    let serviceTitle: String?
    let confident: Bool
    let urgency: String
    let title: String
    let details: String?
    let questions: [String]
    let safety: String?

    var id: String { "\(category):\(serviceID ?? title)" }

    enum CodingKeys: String, CodingKey {
        case category, confident, urgency, title, details, questions, safety
        case serviceID = "serviceId"
        case serviceTitle
    }
}

struct TranslationBatch: Codable, Equatable {
    let targetLocale: AppLocale
    let sourceLocales: [String]
    let translations: [String]
}

struct TaskDraft: Equatable {
    var categoryID = ""
    var title = ""
    var details = ""
    var city = ""
    var address = ""
    var latitude: Double?
    var longitude: Double?
    var timing = "flexible"
    var budget = ""
    var answers: [String: String] = [:]
    /// Optional services that supplement the primary selected service. These
    /// never replace `title` or `answers["selectedService"]`.
    var relatedServices: [LocalizedValue] = []
    var attachmentURLs: [String] = []

    var canContinueFromDescription: Bool {
        !categoryID.isEmpty && title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4
    }

    var canPublish: Bool {
        canContinueFromDescription
            && city.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
            && address.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }
}
