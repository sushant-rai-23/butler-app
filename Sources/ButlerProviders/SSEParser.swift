import Foundation

/// Minimal Server-Sent Events parser, fed one line at a time (URLSession's
/// `bytes.lines` already splits lines). Only `data:` fields matter; comments,
/// `event:` and `id:` are ignored. Multi-line data joins with "\n".
struct SSEParser {
    private var dataLines: [String] = []

    /// Returns a complete event payload when a blank line ends one.
    mutating func consume(line rawLine: String) -> String? {
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine
        if line.isEmpty { return flush() }
        if line.hasPrefix(":") { return nil }
        guard line.hasPrefix("data:") else { return nil }
        var value = line.dropFirst("data:".count)
        if value.hasPrefix(" ") { value = value.dropFirst() }
        dataLines.append(String(value))
        return nil
    }

    /// Emits a pending event that was not terminated by a blank line.
    mutating func flush() -> String? {
        guard !dataLines.isEmpty else { return nil }
        defer { dataLines.removeAll() }
        return dataLines.joined(separator: "\n")
    }
}
