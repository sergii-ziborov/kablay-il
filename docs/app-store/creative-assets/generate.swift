import AppKit
import Foundation
import ImageIO

// Run from the repository root: swift docs/app-store/creative-assets/generate.swift
// App Store Connect: header 3840×1646, search results 1920×1280, opaque PNG.
private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let screenshots = root.appendingPathComponent("docs/app-store/screenshots")
private let output = root.appendingPathComponent("docs/app-store/creative-assets")

private struct Copy {
    let code: String
    let headerTitle: [String]
    let headerSubtitle: String
    let searchTitle: [String]
    let searchSubtitle: String
    let steps: [String]
    let screenshotNames: [String]
    let rightToLeft: Bool
}

private let copies = [
    Copy(code: "en", headerTitle: ["Home repair,", "made easier."],
         headerSubtitle: "Find local specialists. Send a clear request. Keep the work together.",
         searchTitle: ["The right specialist", "for your home."],
         searchSubtitle: "Search · Request · Connect", steps: ["Find a specialist", "Describe the job", "Manage the work"],
         screenshotNames: ["01-catalog.png", "03-request.png", "02-smart-search.png"], rightToLeft: false),
    Copy(code: "ru", headerTitle: ["Ремонт дома", "стал проще."],
         headerSubtitle: "Найдите мастера рядом, опишите задачу и ведите работу в одном месте.",
         searchTitle: ["Найдите мастера", "для своего дома."],
         searchSubtitle: "Поиск · Заявка · Работа", steps: ["Найдите мастера", "Опишите задачу", "Следите за работой"],
         screenshotNames: ["ru-01-catalog.png", "ru-03-request.png", "ru-02-guides.png"], rightToLeft: false),
    Copy(code: "he", headerTitle: ["בעלי מקצוע לבית", "במקום אחד."],
         headerSubtitle: "מחפשים בעל מקצוע, מתארים את העבודה ומנהלים את הכול בקלות.",
         searchTitle: ["בעל המקצוע הנכון", "לבית שלכם."],
         searchSubtitle: "חיפוש · בקשה · עבודה", steps: ["מוצאים בעל מקצוע", "מתארים את העבודה", "מנהלים את התהליך"],
         screenshotNames: ["he-01-catalog.png", "he-03-request.png", "he-02-guides.png"], rightToLeft: true),
]

private let coral = NSColor(calibratedRed: 0.94, green: 0.18, blue: 0.26, alpha: 1)
private let white = NSColor.white
private let pale = NSColor(calibratedRed: 0.78, green: 0.82, blue: 0.90, alpha: 1)
private let background = NSColor(calibratedRed: 0.065, green: 0.083, blue: 0.14, alpha: 1)

private func rect(_ x: CGFloat, _ top: CGFloat, _ width: CGFloat, _ height: CGFloat, canvas: CGFloat) -> NSRect {
    NSRect(x: x, y: canvas - top - height, width: width, height: height)
}

private func drawText(_ value: String, x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat,
                      size: CGFloat, weight: NSFont.Weight, color: NSColor, canvas: CGFloat,
                      alignment: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byTruncatingTail
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    (value as NSString).draw(in: rect(x, top, width, height, canvas: canvas), withAttributes: attributes)
}

private func fillRound(_ frame: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius).fill()
}

private func drawScreenshot(_ name: String, x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat,
                            radius: CGFloat, canvas: CGFloat) throws {
    guard let image = NSImage(contentsOf: screenshots.appendingPathComponent(name)) else {
        throw NSError(domain: "CreativeAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing screenshot: \(name)"])
    }
    let frame = rect(x, top, width, height, canvas: canvas)
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.45)
    shadow.shadowBlurRadius = 55
    shadow.shadowOffset = NSSize(width: 0, height: -16)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    fillRound(frame, radius: radius, color: .white)
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: frame, from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

private func drawBackdrop(width: CGFloat, height: CGFloat) {
    background.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.17, green: 0.09, blue: 0.17, alpha: 1),
        background,
    ])?.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 20)
    coral.withAlphaComponent(0.09).setFill()
    NSBezierPath(ovalIn: NSRect(x: width * 0.61, y: -height * 0.33,
                                width: width * 0.64, height: height * 1.3)).fill()
    NSColor.white.withAlphaComponent(0.035).setStroke()
    for offset in stride(from: CGFloat(0), through: width, by: 210) {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: offset, y: 0))
        line.line(to: NSPoint(x: offset + 280, y: height))
        line.lineWidth = 1
        line.stroke()
    }
}

private func render(width: Int, height: Int, name: String, drawing: (CGFloat) throws -> Void) throws {
    guard let context = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        throw NSError(domain: "CreativeAssets", code: 2)
    }
    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    try drawing(CGFloat(height))
    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name) as CFURL,
                                                             "public.png" as CFString, 1, nil) else {
        throw NSError(domain: "CreativeAssets", code: 3)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "CreativeAssets", code: 4) }
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for copy in copies {
    try render(width: 3840, height: 1646, name: "header-\(copy.code).png") { canvas in
        drawBackdrop(width: 3840, height: canvas)
        let align: NSTextAlignment = copy.rightToLeft ? .right : .left
        drawText("KABLAY", x: 160, top: 105, width: 1740, height: 155,
                 size: 124, weight: .black, color: coral, canvas: canvas)
        let titleSize: CGFloat = copy.code == "ru" ? 130 : 142
        for (index, line) in copy.headerTitle.enumerated() {
            drawText(line, x: 160, top: 360 + CGFloat(index) * 180,
                     width: 1780, height: 165, size: titleSize, weight: .bold,
                     color: white, canvas: canvas, alignment: align)
        }
        drawText(copy.headerSubtitle, x: 160, top: 810, width: 1750, height: 150,
                 size: 51, weight: .regular, color: pale, canvas: canvas, alignment: align)
        for (index, step) in copy.steps.enumerated() {
            let x = CGFloat(160 + index * 570)
            fillRound(rect(x, 1115, 535, 144, canvas: canvas), radius: 28,
                      color: NSColor.white.withAlphaComponent(0.09))
            drawText(String(format: "%02d", index + 1), x: x + 28, top: 1153,
                     width: 65, height: 65, size: 47, weight: .bold, color: coral, canvas: canvas)
            drawText(step, x: x + 100, top: 1153, width: 420, height: 65,
                     size: 39, weight: .semibold, color: white, canvas: canvas)
        }
        for (index, name) in copy.screenshotNames.enumerated() {
            try drawScreenshot(name, x: CGFloat(2140 + index * 520), top: CGFloat(260 + (index % 2) * 70),
                               width: 485, height: 1054, radius: 62, canvas: canvas)
        }
    }

    try render(width: 1920, height: 1280, name: "search-\(copy.code).png") { canvas in
        drawBackdrop(width: 1920, height: canvas)
        let align: NSTextAlignment = copy.rightToLeft ? .right : .left
        drawText("KABLAY", x: 105, top: 98, width: 1000, height: 130,
                 size: 106, weight: .black, color: coral, canvas: canvas)
        for (index, line) in copy.searchTitle.enumerated() {
            drawText(line, x: 105, top: 385 + CGFloat(index) * 140,
                     width: 1070, height: 135, size: copy.code == "ru" ? 86 : 95,
                     weight: .bold, color: white, canvas: canvas, alignment: align)
        }
        drawText(copy.searchSubtitle, x: 105, top: 740, width: 1060, height: 90,
                 size: 52, weight: .medium, color: pale, canvas: canvas, alignment: align)
        fillRound(rect(105, 935, 1040, 12, canvas: canvas), radius: 6, color: coral)
        try drawScreenshot(copy.screenshotNames[0], x: 1315, top: 145, width: 460,
                           height: 1000, radius: 58, canvas: canvas)
    }
}
print("Created six App Store creative assets in \(output.path)")
