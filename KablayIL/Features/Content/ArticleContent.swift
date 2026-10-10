import Foundation

/// A blog article arrives from the published catalog as editorial HTML. The app
/// renders it with native SwiftUI views instead of a web view, so the article
/// reads like the built-in guides: real headings, lists, callouts, and tables
/// that follow Dynamic Type, the app theme, and RTL layout.
enum ArticleBlock: Identifiable, Hashable {
    case heading(level: Int, text: AttributedString)
    case paragraph(AttributedString)
    case bullets([AttributedString])
    case numbered([AttributedString])
    case quote(AttributedString)
    case callout(AttributedString)
    case table(headers: [AttributedString], rows: [[AttributedString]])
    case image(URL)

    var id: String {
        switch self {
        case let .heading(level, text): "h\(level):\(String(text.characters))"
        case let .paragraph(text): "p:\(String(text.characters))"
        case let .bullets(items): "ul:\(items.map { String($0.characters) }.joined(separator: "|"))"
        case let .numbered(items): "ol:\(items.map { String($0.characters) }.joined(separator: "|"))"
        case let .quote(text): "q:\(String(text.characters))"
        case let .callout(text): "c:\(String(text.characters))"
        case let .table(headers, rows): "t:\(headers.count):\(rows.count):\(headers.map { String($0.characters) }.joined(separator: "|"))"
        case let .image(url): "img:\(url.absoluteString)"
        }
    }
}

// MARK: - Minimal HTML tree

private indirect enum HTMLNode {
    case text(String)
    case element(name: String, attributes: [String: String], children: [HTMLNode])
}

private enum HTMLParser {
    private static let voidElements: Set<String> = ["br", "img", "hr", "input", "meta", "link", "source", "col"]

    static func parse(_ html: String) -> [HTMLNode] {
        var scanner = Scanner(source: Array(html))
        return scanner.parseNodes(until: nil)
    }

    private struct Scanner {
        let source: [Character]
        var index = 0

        init(source: [Character]) { self.source = source }

        var isAtEnd: Bool { index >= source.count }

        mutating func parseNodes(until closingTag: String?) -> [HTMLNode] {
            var nodes: [HTMLNode] = []
            while !isAtEnd {
                if source[index] == "<" {
                    if matchesClosingTag() {
                        let start = index
                        let name = readClosingTag()
                        if name == closingTag { return nodes }
                        if closingTag == nil { continue }
                        // The tag closes an ancestor. Rewind so that ancestor
                        // consumes it, instead of dropping the rest of the
                        // document on a single mismatch.
                        index = start
                        return nodes
                    }
                    if let node = readElement() {
                        nodes.append(node)
                        continue
                    }
                    // A stray '<' that starts no tag is literal text.
                    nodes.append(.text("<"))
                    index += 1
                    continue
                }
                nodes.append(.text(readText()))
            }
            return nodes
        }

        private func matchesClosingTag() -> Bool {
            index + 1 < source.count && source[index + 1] == "/"
        }

        private mutating func readClosingTag() -> String {
            index += 2
            var name = ""
            while !isAtEnd, source[index] != ">" {
                name.append(source[index])
                index += 1
            }
            if !isAtEnd { index += 1 }
            return name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        private mutating func readText() -> String {
            var text = ""
            while !isAtEnd, source[index] != "<" {
                text.append(source[index])
                index += 1
            }
            return text
        }

        private mutating func readElement() -> HTMLNode? {
            let start = index
            index += 1
            guard !isAtEnd else { index = start; return nil }

            // Comments and declarations carry no content for the reader.
            if source[index] == "!" {
                while !isAtEnd, source[index] != ">" { index += 1 }
                if !isAtEnd { index += 1 }
                return .text("")
            }

            var name = ""
            while !isAtEnd, !source[index].isWhitespace, source[index] != ">", source[index] != "/" {
                name.append(source[index])
                index += 1
            }
            guard !name.isEmpty else { index = start; return nil }
            name = name.lowercased()

            var attributes: [String: String] = [:]
            var selfClosing = false
            while !isAtEnd, source[index] != ">" {
                if source[index] == "/" {
                    selfClosing = true
                    index += 1
                    continue
                }
                if source[index].isWhitespace {
                    index += 1
                    continue
                }
                let (key, value) = readAttribute()
                if !key.isEmpty { attributes[key] = value }
            }
            if !isAtEnd { index += 1 }

            if selfClosing || voidElements.contains(name) {
                return .element(name: name, attributes: attributes, children: [])
            }

            let children = parseNodes(until: name)
            return .element(name: name, attributes: attributes, children: children)
        }

        private mutating func readAttribute() -> (String, String) {
            var key = ""
            while !isAtEnd, !source[index].isWhitespace, source[index] != "=", source[index] != ">", source[index] != "/" {
                key.append(source[index])
                index += 1
            }
            while !isAtEnd, source[index].isWhitespace { index += 1 }
            guard !isAtEnd, source[index] == "=" else { return (key.lowercased(), "") }
            index += 1
            while !isAtEnd, source[index].isWhitespace { index += 1 }
            guard !isAtEnd else { return (key.lowercased(), "") }

            var value = ""
            if source[index] == "\"" || source[index] == "'" {
                let quote = source[index]
                index += 1
                while !isAtEnd, source[index] != quote {
                    value.append(source[index])
                    index += 1
                }
                if !isAtEnd { index += 1 }
            } else {
                while !isAtEnd, !source[index].isWhitespace, source[index] != ">" {
                    value.append(source[index])
                    index += 1
                }
            }
            return (key.lowercased(), value)
        }
    }
}

// MARK: - Entities

private enum HTMLEntities {
    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "mdash": "—", "ndash": "–", "hellip": "…", "laquo": "«", "raquo": "»",
        "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "bull": "•",
        "middot": "·", "times": "×", "deg": "°", "euro": "€", "copy": "©",
        "reg": "®", "trade": "™", "shy": "", "thinsp": "\u{2009}", "sup2": "²", "sup3": "³",
    ]

    static func decode(_ value: String) -> String {
        guard value.contains("&") else { return value }
        var result = ""
        var iterator = value.startIndex
        while iterator < value.endIndex {
            let character = value[iterator]
            guard character == "&",
                  let terminator = value[iterator...].firstIndex(of: ";"),
                  value.distance(from: iterator, to: terminator) <= 10 else {
                result.append(character)
                iterator = value.index(after: iterator)
                continue
            }
            let body = String(value[value.index(after: iterator)..<terminator])
            if let replacement = named[body.lowercased()] {
                result.append(replacement)
            } else if body.hasPrefix("#") {
                let digits = String(body.dropFirst())
                let scalarValue = digits.lowercased().hasPrefix("x")
                    ? UInt32(digits.dropFirst(), radix: 16)
                    : UInt32(digits)
                if let scalarValue, let scalar = Unicode.Scalar(scalarValue) {
                    result.append(Character(scalar))
                } else {
                    result.append("&\(body);")
                }
            } else {
                result.append("&\(body);")
            }
            iterator = value.index(after: terminator)
        }
        return result
    }
}

// MARK: - Blocks

enum ArticleContent {
    private static let blockContainers: Set<String> = [
        "div", "section", "article", "main", "figure", "header", "footer", "span", "body", "html",
    ]

    static func blocks(from html: String, baseURL: URL) -> [ArticleBlock] {
        var blocks: [ArticleBlock] = []
        append(HTMLParser.parse(html), to: &blocks, baseURL: baseURL)
        return blocks
    }

    /// Reading time for an article that ships no explicit estimate. 180 words a
    /// minute matches a mixed Hebrew/Russian/English editorial pace.
    static func readingMinutes(from html: String) -> Int {
        let words = plainText(html).split(whereSeparator: \.isWhitespace).count
        return min(60, max(1, Int((Double(words) / 180.0).rounded(.up))))
    }

    static func plainText(_ html: String) -> String {
        var text = ""
        collectText(HTMLParser.parse(html), into: &text)
        return text
    }

    private static func append(_ nodes: [HTMLNode], to blocks: inout [ArticleBlock], baseURL: URL) {
        for node in nodes {
            switch node {
            case let .text(value):
                let inline = inlineText(from: [.text(value)])
                if !isBlank(inline) { blocks.append(.paragraph(inline)) }
            case let .element(name, attributes, children):
                appendElement(name: name, attributes: attributes, children: children, to: &blocks, baseURL: baseURL)
            }
        }
    }

    private static func appendElement(
        name: String,
        attributes: [String: String],
        children: [HTMLNode],
        to blocks: inout [ArticleBlock],
        baseURL: URL
    ) {
        switch name {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(name.dropFirst()) ?? 2
            let text = inlineText(from: children)
            if !isBlank(text) { blocks.append(.heading(level: level, text: text)) }
        case "p":
            let text = inlineText(from: children)
            if !isBlank(text) { blocks.append(.paragraph(text)) }
        case "ul":
            let items = listItems(children, baseURL: baseURL)
            if !items.isEmpty { blocks.append(.bullets(items)) }
        case "ol":
            let items = listItems(children, baseURL: baseURL)
            if !items.isEmpty { blocks.append(.numbered(items)) }
        case "blockquote":
            let text = inlineText(from: children)
            if !isBlank(text) { blocks.append(.quote(text)) }
        case "aside":
            let text = inlineText(from: children)
            if !isBlank(text) { blocks.append(.callout(text)) }
        case "table":
            if let table = tableBlock(children) { blocks.append(table) }
        case "img":
            if let source = attributes["src"], let url = resolve(source, baseURL: baseURL) {
                blocks.append(.image(url))
            }
        case "br", "hr", "script", "style", "noscript", "svg", "iframe", "form", "button":
            break
        default:
            guard blockContainers.contains(name) else {
                let text = inlineText(from: children)
                if !isBlank(text) { blocks.append(.paragraph(text)) }
                return
            }
            // A wrapper contributes nothing itself. When it mixes inline text
            // with nested blocks, the inline part still becomes a paragraph so
            // no editorial copy is lost.
            var pending: [HTMLNode] = []
            for child in children {
                if isBlockLevel(child) {
                    flush(&pending, into: &blocks)
                    append([child], to: &blocks, baseURL: baseURL)
                } else {
                    pending.append(child)
                }
            }
            flush(&pending, into: &blocks)
        }
    }

    private static func flush(_ pending: inout [HTMLNode], into blocks: inout [ArticleBlock]) {
        guard !pending.isEmpty else { return }
        let text = inlineText(from: pending)
        pending = []
        if !isBlank(text) { blocks.append(.paragraph(text)) }
    }

    private static func isBlockLevel(_ node: HTMLNode) -> Bool {
        guard case let .element(name, _, _) = node else { return false }
        return blockContainers.contains(name)
            || ["h1", "h2", "h3", "h4", "h5", "h6", "p", "ul", "ol", "blockquote", "aside", "table", "img"].contains(name)
    }

    private static func listItems(_ nodes: [HTMLNode], baseURL: URL) -> [AttributedString] {
        var items: [AttributedString] = []
        for node in nodes {
            guard case let .element(name, _, children) = node, name == "li" else { continue }
            let text = inlineText(from: children)
            if !isBlank(text) { items.append(text) }
        }
        return items
    }

    private static func tableBlock(_ nodes: [HTMLNode]) -> ArticleBlock? {
        var headers: [AttributedString] = []
        var rows: [[AttributedString]] = []

        func walk(_ nodes: [HTMLNode]) {
            for node in nodes {
                guard case let .element(name, _, children) = node else { continue }
                switch name {
                case "thead", "tbody", "tfoot":
                    walk(children)
                case "tr":
                    var cells: [AttributedString] = []
                    var isHeaderRow = false
                    for cell in children {
                        guard case let .element(cellName, _, cellChildren) = cell,
                              cellName == "td" || cellName == "th" else { continue }
                        if cellName == "th" { isHeaderRow = true }
                        cells.append(inlineText(from: cellChildren))
                    }
                    guard !cells.isEmpty else { continue }
                    if isHeaderRow, headers.isEmpty { headers = cells } else { rows.append(cells) }
                default:
                    walk(children)
                }
            }
        }

        walk(nodes)
        guard !headers.isEmpty || !rows.isEmpty else { return nil }
        return .table(headers: headers, rows: rows)
    }

    // MARK: Inline runs

    private struct InlineStyle {
        var bold = false
        var italic = false
        var link: URL?
    }

    private static func inlineText(from nodes: [HTMLNode]) -> AttributedString {
        var result = AttributedString()
        appendInline(nodes, style: InlineStyle(), into: &result)
        return trimmed(result)
    }

    private static func appendInline(_ nodes: [HTMLNode], style: InlineStyle, into result: inout AttributedString) {
        for node in nodes {
            switch node {
            case let .text(value):
                let decoded = HTMLEntities.decode(value)
                let collapsed = decoded.replacingOccurrences(
                    of: "[ \\t\\n\\r]+",
                    with: " ",
                    options: .regularExpression
                )
                guard !collapsed.isEmpty else { continue }
                var run = AttributedString(collapsed)
                if style.bold { run.inlinePresentationIntent = .stronglyEmphasized }
                if style.italic {
                    run.inlinePresentationIntent = style.bold
                        ? [.stronglyEmphasized, .emphasized]
                        : .emphasized
                }
                if let link = style.link { run.link = link }
                result.append(run)
            case let .element(name, attributes, children):
                var nested = style
                switch name {
                case "strong", "b": nested.bold = true
                case "em", "i": nested.italic = true
                case "a":
                    if let href = attributes["href"], let url = resolve(href, baseURL: AppConfiguration.webBaseURL) {
                        nested.link = url
                    }
                case "br":
                    result.append(AttributedString("\n"))
                    continue
                case "script", "style", "svg", "img": continue
                default: break
                }
                appendInline(children, style: nested, into: &result)
            }
        }
    }

    private static func collectText(_ nodes: [HTMLNode], into text: inout String) {
        for node in nodes {
            switch node {
            case let .text(value):
                text.append(HTMLEntities.decode(value))
                text.append(" ")
            case let .element(name, _, children):
                guard !["script", "style", "svg"].contains(name) else { continue }
                collectText(children, into: &text)
            }
        }
    }

    private static func trimmed(_ value: AttributedString) -> AttributedString {
        var result = value
        while let first = result.characters.first, first.isWhitespace {
            result.removeSubrange(result.startIndex..<result.index(afterCharacter: result.startIndex))
        }
        while let last = result.characters.last, last.isWhitespace {
            let end = result.endIndex
            result.removeSubrange(result.index(beforeCharacter: end)..<end)
        }
        return result
    }

    private static func isBlank(_ value: AttributedString) -> Bool {
        String(value.characters).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func resolve(_ value: String, baseURL: URL) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let absolute = URL(string: trimmed), absolute.scheme != nil { return absolute }
        return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
    }
}

private extension AttributedString {
    func index(afterCharacter index: AttributedString.Index) -> AttributedString.Index {
        characters.index(after: index)
    }

    func index(beforeCharacter index: AttributedString.Index) -> AttributedString.Index {
        characters.index(before: index)
    }
}
