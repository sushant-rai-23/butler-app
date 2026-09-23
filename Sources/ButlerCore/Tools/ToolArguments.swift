import Foundation

/// How every tool reads the arguments the model produced.
///
/// This is the seam where the model's own words become arguments, so nothing
/// here trusts a shape. Malformed JSON, a top-level array, a missing key, a
/// value that is a number, null, an object or an array, and a blank string all
/// come back nil, and the tool turns nil into one `error:` line the model can
/// read and retry from. Duplicate keys are left to the decoder; either value
/// still goes through the same checks.
enum ToolArguments {
    static func string(_ key: String, in arguments: String) -> String? {
        guard let value = strings(in: arguments)[key],
              !value.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        return value
    }

    /// The `path` argument, accepted only in a shape Butler can name back to
    /// the model: relative, free of anything that forges a line, and short
    /// enough to stay inside a sentence.
    ///
    /// Which paths are legal is `WorkspacePaths`' job, not this one, so the
    /// character rule is borrowed from it rather than copied. This is about
    /// what may be echoed: a `WorkspaceError` quotes the path it was given,
    /// that text goes to the model, and an absolute path or a megabyte of
    /// padding would come straight back out.
    ///
    /// The length is counted in UTF-8 bytes, which is what the filesystem and
    /// the model's context both count in. Graphemes are the wrong unit: a
    /// letter followed by fifty thousand combining marks is four Characters and
    /// a hundred kilobytes.
    static func path(in arguments: String) -> String? {
        let maximumBytes = 256 // Longer than any path the filesystem will accept anyway.
        guard let path = string("path", in: arguments), path.utf8.count <= maximumBytes, !path.hasPrefix("/"),
              !path.unicodeScalars.contains(where: WorkspacePaths.isStructurallyUnsafe)
        else { return nil }
        return path
    }

    /// `JSONDecoder`, never `JSONSerialization`. Serialization recurses once per
    /// level of nesting, `invoke` is async and so runs on a cooperative thread
    /// with a 512 KB stack, and four kilobytes of input — `{"a":` nested about
    /// 470 deep — overflows it and takes the process down with SIGBUS. Its own
    /// depth guard is 512, above what that stack survives, so the guard never
    /// fires. Measured, on both sides. Do not swap this back.
    private static func strings(in arguments: String) -> [String: String] {
        (try? JSONDecoder().decode(StringFields.self, from: Data(arguments.utf8)))?.values ?? [:]
    }
}

/// The string-valued keys of a JSON object, and nothing else. A value that is a
/// number, null, an array or an object is simply absent, which is what the tool
/// tells the model, and one bad value never costs the others.
private struct StringFields: Decodable {
    let values: [String: String]

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        var values: [String: String] = [:]
        for key in container.allKeys {
            if let value = try? container.decode(String.self, forKey: key) {
                values[key.stringValue] = value
            }
        }
        self.values = values
    }
}
