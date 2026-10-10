import Foundation

/// Smart Search sends the text a person typed to a third-party AI service to
/// classify it into a service category. Two things follow from that.
///
/// The person has to be told and has to agree first, and the text has to be
/// stripped of the things nobody needs for classification. A description like
/// "кран течёт на Ротшильд 22, звоните +972…" is a repair description to the
/// user and personal data to everyone else, so phone numbers, emails, links,
/// and house numbers never leave the device.
enum SmartSearchPrivacy {
    /// Bumped when the disclosure text changes materially, so an old agreement
    /// is not treated as consent to something new.
    static let consentVersion = 1

    private static let phone = try? NSRegularExpression(
        pattern: #"(?:\+?972|\b0)(?:[\s().-]*\d){8,10}"#
    )
    private static let internationalPhone = try? NSRegularExpression(
        pattern: #"\+(?:[\s().-]*\d){9,15}"#
    )
    private static let email = try? NSRegularExpression(
        pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
        options: [.caseInsensitive]
    )
    private static let link = try? NSRegularExpression(
        pattern: #"(?:https?://|www\.)\S+"#,
        options: [.caseInsensitive]
    )
    /// A street name followed by a number is the part that turns a description
    /// into an address. The street stays; the number does not.
    private static let houseNumber = try? NSRegularExpression(
        pattern: #"(?<=\p{L})[\s,]+\d{1,4}(?:\s*[/-]\s*\d{1,4})?\b"#,
        options: [.caseInsensitive]
    )
    /// An apartment can be written apart from the house number, and on its own
    /// it still narrows an address down to one door.
    private static let apartment = try? NSRegularExpression(
        pattern: #"(?:кв\.?|квартира|apt\.?|apartment|flat|דירה)\s*\d{1,4}"#,
        options: [.caseInsensitive]
    )

    /// Removes contact details and street numbers. The remaining words are what
    /// the classifier actually needs: the trade, the symptom, the room.
    static func redact(_ text: String) -> String {
        var result = text
        for expression in [phone, internationalPhone, email, link, apartment, houseNumber] {
            guard let expression else { continue }
            result = expression.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }
        return result
            .replacingOccurrences(of: "[ \t]{2,}", with: " ", options: .regularExpression)
            // Redaction leaves punctuation stranded: "на Ротшильд , кв." reads
            // worse to the classifier than the sentence without it.
            .replacingOccurrences(of: "[ \t]+([,.;:])", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "(?:[,;:]\\s*)+([,.;:])", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "[,;:\\s]+$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the text still carries something worth classifying after the
    /// redaction. Sending a string of removed fragments helps nobody.
    static func isClassifiable(_ redacted: String) -> Bool {
        redacted.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    }
}
