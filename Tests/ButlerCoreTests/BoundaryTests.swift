import XCTest

/// No vendor name may appear outside ButlerProviders. Scans source files, not tests.
final class BoundaryTests: XCTestCase {
    func testNoVendorNamesOutsideProviders() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources")
        var hits: [String] = []
        for module in ["ButlerApp", "ButlerCore", "ButlerTools", "ButlerWatch"] {
            let dir = sources.appending(path: module)
            guard let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in files where url.pathExtension == "swift" {
                let text = try String(contentsOf: url, encoding: .utf8)
                if text.range(of: "gemini", options: .caseInsensitive) != nil {
                    hits.append("\(module)/\(url.lastPathComponent)")
                }
            }
        }
        XCTAssertEqual(hits, [], "vendor name leaked outside ButlerProviders")
    }
}
