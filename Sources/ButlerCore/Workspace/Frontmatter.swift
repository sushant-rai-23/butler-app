import Foundation

/// The YAML block at the top of every workspace file.
///
/// Butler parses only the four keys it uses and keeps the block's exact text
/// in `rawBlock`. Writing patches the `updated:` line in place and leaves
/// every other line byte-identical, so a user's hand-added keys, comments and
/// multi-line values survive a write by Butler.
public struct Frontmatter: Equatable, Sendable {
    /// Read-only: `render()` writes `rawBlock`, so assigning to these would
    /// not reach the file. Renaming a file or editing its aliases has to
    /// rewrite `rawBlock` instead.
    public let name: String
    public let description: String
    /// The one field `render()` patches into the block.
    public var updated: String
    public let aliases: [String]
    /// The exact lines between the `---` fences, as parsed.
    public var rawBlock: String

    public init(name: String, description: String, updated: String, aliases: [String], rawBlock: String) {
        self.name = name
        self.description = description
        self.updated = updated
        self.aliases = aliases
        self.rawBlock = rawBlock
    }

    /// A block Butler authors itself, for a file it is creating. `name` and
    /// `description` may come from the model, and `rawBlock` is rendered
    /// verbatim, so a newline in either would split the block or close it
    /// early. Both are flattened to one line first.
    public static func new(name: String, description: String, updated: String) -> Frontmatter {
        let name = singleLine(name)
        let description = singleLine(description)
        return Frontmatter(
            name: name,
            description: description,
            updated: updated,
            aliases: [],
            rawBlock: "name: \(name)\ndescription: \(description)\nupdated: \(updated)\naliases: []"
        )
    }

    /// Folds every line break into a single space and trims, so a value can
    /// neither become a line of its own nor come back from a reparse changed.
    static func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}

public struct MarkdownDocument: Equatable, Sendable {
    public var frontmatter: Frontmatter?
    public var body: String

    public init(frontmatter: Frontmatter?, body: String) {
        self.frontmatter = frontmatter
        self.body = body
    }

    public static func parse(_ text: String) -> MarkdownDocument {
        let lines = text.components(separatedBy: "\n")
        guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else {
            return MarkdownDocument(frontmatter: nil, body: text.trimmingTrailingNewlines())
        }
        let blockLines = Array(lines[1..<end])
        var fields: [String: String] = [:]
        for line in blockLines {
            guard let key = Self.key(of: line), let colon = line.firstIndex(of: ":") else { continue }
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if fields[key] == nil { fields[key] = value }
        }
        let frontmatter = Frontmatter(
            name: fields["name"] ?? "",
            description: fields["description"] ?? "",
            updated: fields["updated"] ?? "",
            aliases: parseList(fields["aliases"] ?? "[]"),
            rawBlock: blockLines.joined(separator: "\n")
        )
        let body = lines[(end + 1)...].joined(separator: "\n").trimmingTrailingNewlines()
        return MarkdownDocument(frontmatter: frontmatter, body: body)
    }

    /// Writes the raw block back verbatim, with `updated:` patched to the
    /// current value, folded to one line. A block with no `updated:` line gains one at the end.
    public func render() -> String {
        guard let fm = frontmatter else { return body }
        let updated = Frontmatter.singleLine(fm.updated)
        var blockLines = fm.rawBlock.components(separatedBy: "\n")
        if let i = blockLines.firstIndex(where: { Self.key(of: $0) == "updated" }) {
            blockLines[i] = "updated: \(updated)"
        } else if !updated.isEmpty {
            blockLines.append("updated: \(updated)")
        }
        return (["---"] + blockLines + ["---", body]).joined(separator: "\n")
    }

    /// The top-level key a block line declares, or nil if it declares none:
    /// indented lines belong to the key above, `#` lines are comments. Parsing
    /// and rendering both go through this, so they never disagree about which
    /// line holds a key.
    private static func key(of line: String) -> String? {
        guard line.first?.isWhitespace != true, !line.hasPrefix("#"), let colon = line.firstIndex(of: ":") else { return nil }
        return line[..<colon].trimmingCharacters(in: .whitespaces)
    }

    private static func parseList(_ raw: String) -> [String] {
        var inner = raw.trimmingCharacters(in: .whitespaces)
        guard inner.hasPrefix("["), inner.hasSuffix("]") else { return inner.isEmpty ? [] : [inner] }
        inner.removeFirst(); inner.removeLast()
        return inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

extension String {
    func trimmingTrailingNewlines() -> String {
        var s = Substring(self)
        while s.last == "\n" { s.removeLast() }
        return String(s)
    }
}
