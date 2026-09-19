import Foundation

/// The YAML block at the top of every workspace file. Only the subset Double
/// writes: `key: value` lines and an inline `[a, b]` list for aliases.
/// Unknown keys are kept verbatim in `extra` so user additions survive.
public struct Frontmatter: Equatable, Sendable {
    public var name: String
    public var description: String
    public var updated: String
    public var aliases: [String]
    public var extra: [String: String]

    public init(name: String, description: String, updated: String, aliases: [String], extra: [String: String] = [:]) {
        self.name = name
        self.description = description
        self.updated = updated
        self.aliases = aliases
        self.extra = extra
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
        var fields: [String: String] = [:]
        for line in lines[1..<end] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            fields[key] = value
        }
        let known = ["name", "description", "updated", "aliases"]
        let frontmatter = Frontmatter(
            name: fields["name"] ?? "",
            description: fields["description"] ?? "",
            updated: fields["updated"] ?? "",
            aliases: parseList(fields["aliases"] ?? "[]"),
            extra: fields.filter { !known.contains($0.key) }
        )
        let body = lines[(end + 1)...].joined(separator: "\n").trimmingTrailingNewlines()
        return MarkdownDocument(frontmatter: frontmatter, body: body)
    }

    public func render() -> String {
        guard let fm = frontmatter else { return body }
        var lines = ["---", "name: \(fm.name)", "description: \(fm.description)", "updated: \(fm.updated)", "aliases: [\(fm.aliases.joined(separator: ", "))]"]
        for key in fm.extra.keys.sorted() { lines.append("\(key): \(fm.extra[key]!)") }
        lines.append("---")
        lines.append(body)
        return lines.joined(separator: "\n")
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
