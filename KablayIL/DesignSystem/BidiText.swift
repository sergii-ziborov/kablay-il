import Foundation

/// Keeps left-to-right values readable inside Hebrew text.
///
/// Unicode resolves the direction of neutral characters from the paragraph they
/// sit in. A phone number is made almost entirely of neutrals — `+`, spaces,
/// hyphens — so in a Hebrew screen `+972 50-366-9369` is rendered by the system
/// as `972 50-366-9369+`: the plus moves to the other end, and a number quoted
/// inside a sentence lands in the wrong place entirely. The digits are not
/// reordered, but the number reads wrong and can be dialled wrong.
///
/// Wrapping the value in an isolate says "this run is left-to-right and it is
/// one unit", which is exactly true of a phone number, an order number, a price
/// range, or a URL.
extension String {
    private static let leftToRightIsolate = "\u{2066}"
    private static let popDirectionalIsolate = "\u{2069}"

    /// The same string, laid out left to right whatever surrounds it.
    var ltrIsolated: String {
        isEmpty ? self : Self.leftToRightIsolate + self + Self.popDirectionalIsolate
    }
}

extension Optional where Wrapped == String {
    /// Convenience for the common `phone ?? ""` shape at a call site.
    var ltrIsolated: String? {
        guard let self, !self.isEmpty else { return nil }
        return self.ltrIsolated
    }
}
