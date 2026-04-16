import XCTest
@testable import AppNetworkMonitor

internal final class MockRuleTests: XCTestCase {

    internal func test_matches_returnsTrue_forExactPath() throws {
        let rule = MockRule(path: "/api/v1/products", statusCode: 200)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/v1/products"))
        XCTAssertTrue(rule.matches(url: url, httpMethod: nil))
    }

    internal func test_matches_returnsFalse_forDifferentPath() throws {
        let rule = MockRule(path: "/api/v1/products", statusCode: 200)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/v1/users"))
        XCTAssertFalse(rule.matches(url: url, httpMethod: nil))
    }

    internal func test_matches_returnsFalse_whenDisabled() throws {
        let rule = MockRule(path: "/api/v1/products", statusCode: 200, isEnabled: false)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/v1/products"))
        XCTAssertFalse(rule.matches(url: url, httpMethod: nil))
    }

    internal func test_matches_filtersMethod_whenSpecified() throws {
        let rule = MockRule(path: "/api/v1/products", method: "POST", statusCode: 200)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/v1/products"))
        XCTAssertTrue(rule.matches(url: url, httpMethod: "POST"))
        XCTAssertFalse(rule.matches(url: url, httpMethod: "GET"))
    }

    internal func test_matches_methodComparison_isCaseInsensitive() throws {
        let rule = MockRule(path: "/api/v1/products", method: "post", statusCode: 200)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/v1/products"))
        XCTAssertTrue(rule.matches(url: url, httpMethod: "POST"))
    }

    internal func test_matches_wildcardPattern() throws {
        let rule = MockRule(path: "/api/*/products", statusCode: 200)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/v1/products"))
        XCTAssertTrue(rule.matches(url: url, httpMethod: nil))
    }

    internal func test_matches_returnsFalse_whenWildcardDoesNotMatch() throws {
        let rule = MockRule(path: "/api/*/products", statusCode: 200)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/v1/users"))
        XCTAssertFalse(rule.matches(url: url, httpMethod: nil))
    }

    internal func test_matches_returnsTrue_whenRuleMethodIsNil() throws {
        let rule = MockRule(path: "/api/test", statusCode: 200)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/test"))
        XCTAssertTrue(rule.matches(url: url, httpMethod: "GET"))
    }

    internal func test_matches_returnsTrue_whenRequestMethodIsNil() throws {
        let rule = MockRule(path: "/api/test", method: "GET", statusCode: 200)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/test"))
        XCTAssertTrue(rule.matches(url: url, httpMethod: nil))
    }

    internal func test_matches_returnsFalse_whenPathDoesNotMatchAndNoWildcard() throws {
        let rule = MockRule(path: "/api/v1/products", statusCode: 200)
        let url = try XCTUnwrap(URL(string: "https://example.com/api/v2/products"))
        XCTAssertFalse(rule.matches(url: url, httpMethod: nil))
    }

    internal func test_init_defaultValues() {
        let rule = MockRule(path: "/test")
        XCTAssertEqual(rule.statusCode, 200)
        XCTAssertNil(rule.method)
        XCTAssertNil(rule.responseHeaders)
        XCTAssertNil(rule.responseBody)
        XCTAssertEqual(rule.delayMs, 0)
        XCTAssertTrue(rule.isEnabled)
    }

    internal func test_init_customValues() {
        let id = UUID()
        let rule = MockRule(
            id: id,
            path: "/api/test",
            method: "POST",
            statusCode: 201,
            responseHeaders: ["X-Custom": "value"],
            responseBody: "{\"ok\": true}",
            delayMs: 500,
            isEnabled: false
        )
        XCTAssertEqual(rule.id, id)
        XCTAssertEqual(rule.path, "/api/test")
        XCTAssertEqual(rule.method, "POST")
        XCTAssertEqual(rule.statusCode, 201)
        XCTAssertEqual(rule.responseHeaders, ["X-Custom": "value"])
        XCTAssertEqual(rule.responseBody, "{\"ok\": true}")
        XCTAssertEqual(rule.delayMs, 500)
        XCTAssertFalse(rule.isEnabled)
    }

    internal func test_mockRule_conformsToCodable() throws {
        let original = MockRule(
            path: "/api/test",
            method: "POST",
            statusCode: 201,
            responseHeaders: ["Content-Type": "text/plain"],
            responseBody: "hello",
            delayMs: 100,
            isEnabled: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MockRule.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    internal func test_mockRule_conformsToHashable() {
        let id = UUID()
        let rule1 = MockRule(id: id, path: "/test", statusCode: 200)
        let rule2 = MockRule(id: id, path: "/test", statusCode: 200)
        XCTAssertEqual(rule1, rule2)
        XCTAssertEqual(rule1.hashValue, rule2.hashValue)
    }
}
