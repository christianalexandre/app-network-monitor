import XCTest
@testable import AppNetworkMonitor

internal final class MockManagerTests: XCTestCase {

    private var sut: MockManager { MockManager.shared }

    override internal func setUp() {
        super.setUp()
        sut.clearRules()
    }

    override internal func tearDown() {
        sut.clearRules()
        super.tearDown()
    }

    internal func test_addRule_addsRuleToList() {
        let rule = MockRule(path: "/test", statusCode: 200)
        sut.addRule(rule)
        XCTAssertEqual(sut.rules.count, 1)
        XCTAssertEqual(sut.rules.first?.path, "/test")
    }

    internal func test_addRule_replacesExistingRuleWithSameId() {
        let id = UUID()
        let rule1 = MockRule(id: id, path: "/test1", statusCode: 200)
        let rule2 = MockRule(id: id, path: "/test2", statusCode: 201)
        sut.addRule(rule1)
        sut.addRule(rule2)
        XCTAssertEqual(sut.rules.count, 1)
        XCTAssertEqual(sut.rules.first?.path, "/test2")
    }

    internal func test_removeRule_removesRuleById() {
        let rule = MockRule(path: "/test", statusCode: 200)
        sut.addRule(rule)
        sut.removeRule(id: rule.id)
        XCTAssertTrue(sut.rules.isEmpty)
    }

    internal func test_clearRules_removesAllRules() {
        sut.addRule(MockRule(path: "/test1", statusCode: 200))
        sut.addRule(MockRule(path: "/test2", statusCode: 201))
        sut.clearRules()
        XCTAssertTrue(sut.rules.isEmpty)
    }

    internal func test_syncRules_replacesAllRules() {
        sut.addRule(MockRule(path: "/old", statusCode: 200))
        let newRules = [
            MockRule(path: "/new1", statusCode: 200),
            MockRule(path: "/new2", statusCode: 201)
        ]
        sut.syncRules(newRules)
        XCTAssertEqual(sut.rules.count, 2)
        XCTAssertEqual(sut.rules.map(\.path), ["/new1", "/new2"])
    }

    internal func test_findMatchingRule_returnsMatchingRule() throws {
        let rule = MockRule(path: "/api/test", statusCode: 200)
        sut.addRule(rule)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/test"))
        let found = sut.findMatchingRule(for: url, method: nil)
        XCTAssertEqual(found?.id, rule.id)
    }

    internal func test_findMatchingRule_returnsNil_whenNoMatch() throws {
        let rule = MockRule(path: "/api/test", statusCode: 200)
        sut.addRule(rule)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/other"))
        let found = sut.findMatchingRule(for: url, method: nil)
        XCTAssertNil(found)
    }

    internal func test_createMockResponse_setsDefaultContentType() throws {
        let rule = MockRule(path: "/test", statusCode: 200, responseBody: "{}")
        let url = try XCTUnwrap(URL(string: "https://example.com/test"))
        let (response, data) = sut.createMockResponse(for: rule, url: url)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(response?.allHeaderFields["Content-Type"] as? String, "application/json")
        XCTAssertNotNil(data)
    }

    internal func test_createMockResponse_preservesCustomContentType() throws {
        let rule = MockRule(path: "/test", statusCode: 200, responseHeaders: ["Content-Type": "text/plain"], responseBody: "hello")
        let url = try XCTUnwrap(URL(string: "https://example.com/test"))
        let (response, _) = sut.createMockResponse(for: rule, url: url)
        XCTAssertEqual(response?.allHeaderFields["Content-Type"] as? String, "text/plain")
    }

    internal func test_createMockResponse_returnsNilData_whenNoResponseBody() throws {
        let rule = MockRule(path: "/test", statusCode: 204)
        let url = try XCTUnwrap(URL(string: "https://example.com/test"))
        let (response, data) = sut.createMockResponse(for: rule, url: url)
        XCTAssertEqual(response?.statusCode, 204)
        XCTAssertNil(data)
    }

    internal func test_hasMock_returnsTrue_whenMatchingRuleExists() throws {
        let rule = MockRule(path: "/api/test", statusCode: 200)
        sut.addRule(rule)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/test"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        XCTAssertTrue(sut.hasMock(for: request))
    }

    internal func test_hasMock_returnsFalse_whenNoMatchingRule() throws {
        let rule = MockRule(path: "/api/test", statusCode: 200)
        sut.addRule(rule)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/other"))
        let request = URLRequest(url: url)
        XCTAssertFalse(sut.hasMock(for: request))
    }

    internal func test_hasMock_returnsFalse_whenURLIsNil() {
        let request = URLRequest(url: URL(string: "about:blank")!)
        // No rules added, so this should return false
        XCTAssertFalse(sut.hasMock(for: request))
    }

    internal func test_findMatchingRule_respectsMethodFilter() throws {
        let rule = MockRule(path: "/api/test", method: "POST", statusCode: 200)
        sut.addRule(rule)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/test"))
        XCTAssertNil(sut.findMatchingRule(for: url, method: "GET"))
        XCTAssertNotNil(sut.findMatchingRule(for: url, method: "POST"))
    }
}
