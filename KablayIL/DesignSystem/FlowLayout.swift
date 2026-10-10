import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var layoutDirection: LayoutDirection = .leftToRight

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let intrinsicWidth = subviews
            .map { $0.sizeThatFits(.unspecified).width }
            .filter(\.isFinite)
            .map { max(1, $0) }
            .max() ?? 1
        let proposedWidth = proposal.width ?? intrinsicWidth
        let width = proposedWidth.isFinite ? max(1, proposedWidth) : intrinsicWidth
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = safeSize(
                subview.sizeThatFits(ProposedViewSize(width: width, height: nil)),
                maximumWidth: width
            )
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        let height = y + lineHeight
        return CGSize(width: width, height: height.isFinite ? max(0, height) : 0)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let availableWidth = bounds.width.isFinite ? max(1, bounds.width) : 1
        var x = layoutDirection == .rightToLeft ? bounds.maxX : bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = safeSize(
                subview.sizeThatFits(ProposedViewSize(width: availableWidth, height: nil)),
                maximumWidth: availableWidth
            )
            if layoutDirection == .rightToLeft {
                if x < bounds.maxX, x - size.width < bounds.minX {
                    x = bounds.maxX
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topTrailing,
                    proposal: ProposedViewSize(size)
                )
                x -= size.width + spacing
            } else {
                if x > bounds.minX, x + size.width > bounds.maxX {
                    x = bounds.minX
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            lineHeight = max(lineHeight, size.height)
        }
    }

    private func safeSize(_ proposed: CGSize, maximumWidth: CGFloat) -> CGSize {
        let width = proposed.width.isFinite ? min(max(0, proposed.width), maximumWidth) : maximumWidth
        let height = proposed.height.isFinite ? max(0, proposed.height) : 0
        return CGSize(width: width, height: height)
    }
}
