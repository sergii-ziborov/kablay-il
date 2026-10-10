import Foundation

/// Limits the server enforces on a specialist profile.
///
/// The number lived in three string interpolations and two comparisons inside
/// the questionnaire, so raising it server-side left the app quietly refusing
/// the fourth trade. It has one home now, and the API rejects anything above it
/// with `TOO_MANY_CATEGORIES` regardless.
enum SpecialistProfileLimits {
    static let maxCategories = 5
}
