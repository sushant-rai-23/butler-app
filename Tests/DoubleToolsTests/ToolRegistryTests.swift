import XCTest
@testable import DoubleTools

private struct StubTool: Tool {
    let name: String
    let risk: RiskLevel
    var description: String { "stub" }
    var parametersSchema: String { "{}" }
    func invoke(arguments: String) async throws -> String { arguments }
}

final class ToolRegistryTests: XCTestCase {
    func testRegisterAndLookupByName() throws {
        let registry = ToolRegistry()
        try registry.register(StubTool(name: "read", risk: .low))
        XCTAssertEqual(registry.tool(named: "read")?.name, "read")
        XCTAssertNil(registry.tool(named: "missing"))
    }

    func testDuplicateNameIsRejected() throws {
        let registry = ToolRegistry()
        try registry.register(StubTool(name: "read", risk: .low))
        XCTAssertThrowsError(try registry.register(StubTool(name: "read", risk: .high))) { error in
            XCTAssertEqual(error as? ToolRegistryError, .duplicateName("read"))
        }
    }

    func testFilterByMaximumRisk() throws {
        let registry = ToolRegistry()
        try registry.register(StubTool(name: "read", risk: .low))
        try registry.register(StubTool(name: "write", risk: .medium))
        try registry.register(StubTool(name: "shell", risk: .high))
        XCTAssertEqual(registry.tools(atMost: .medium).map(\.name), ["read", "write"])
        XCTAssertTrue(RiskLevel.low < RiskLevel.high)
    }
}
