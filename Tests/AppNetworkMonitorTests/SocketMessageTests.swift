import XCTest
@testable import AppNetworkMonitor

internal final class SocketMessageTests: XCTestCase {

    // MARK: - SocketMessageType Tests

    internal func test_socketMessageType_rawValues() {
        XCTAssertEqual(SocketMessageType.log.rawValue, "LOG")
        XCTAssertEqual(SocketMessageType.addMockRule.rawValue, "ADD_MOCK_RULE")
        XCTAssertEqual(SocketMessageType.removeMockRule.rawValue, "REMOVE_MOCK_RULE")
        XCTAssertEqual(SocketMessageType.clearMockRules.rawValue, "CLEAR_MOCK_RULES")
        XCTAssertEqual(SocketMessageType.syncMockRules.rawValue, "SYNC_MOCK_RULES")
    }

    internal func test_socketMessageType_decodesFromRawValue() throws {
        let data = try XCTUnwrap("\"LOG\"".data(using: .utf8))
        let decoded = try JSONDecoder().decode(SocketMessageType.self, from: data)
        XCTAssertEqual(decoded, .log)
    }

    // MARK: - SocketMessage Init Tests

    internal func test_init_setsTypeAndPayload() {
        let payload = Data([0x01, 0x02, 0x03])
        let message = SocketMessage(type: .log, payload: payload)
        XCTAssertEqual(message.type, .log)
        XCTAssertEqual(message.payload, payload)
    }

    // MARK: - Factory Method Tests

    internal func test_log_createsMessageWithLogType() throws {
        let log = LogModel(
            id: UUID(),
            timestamp: Date(),
            method: "GET",
            url: "https://example.com/api",
            statusCode: 200,
            duration: 0.5,
            requestHeaders: nil,
            responseHeaders: nil,
            requestBody: nil,
            responseBody: nil
        )
        let message = try SocketMessage.log(log)
        XCTAssertEqual(message.type, .log)
        XCTAssertFalse(message.payload.isEmpty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LogModel.self, from: message.payload)
        XCTAssertEqual(decoded.id, log.id)
        XCTAssertEqual(decoded.method, log.method)
        XCTAssertEqual(decoded.url, log.url)
    }

    internal func test_addMockRule_createsMessageWithCorrectType() throws {
        let rule = MockRule(path: "/api/test", statusCode: 200)
        let message = try SocketMessage.addMockRule(rule)
        XCTAssertEqual(message.type, .addMockRule)

        let decoded = try JSONDecoder().decode(MockRule.self, from: message.payload)
        XCTAssertEqual(decoded.id, rule.id)
        XCTAssertEqual(decoded.path, rule.path)
    }

    internal func test_removeMockRule_createsMessageWithCorrectType() throws {
        let id = UUID()
        let message = try SocketMessage.removeMockRule(id: id)
        XCTAssertEqual(message.type, .removeMockRule)

        let decoded = try JSONDecoder().decode(UUID.self, from: message.payload)
        XCTAssertEqual(decoded, id)
    }

    internal func test_clearMockRules_createsMessageWithEmptyPayload() {
        let message = SocketMessage.clearMockRules()
        XCTAssertEqual(message.type, .clearMockRules)
        XCTAssertTrue(message.payload.isEmpty)
    }

    internal func test_syncMockRules_createsMessageWithCorrectType() throws {
        let rules = [
            MockRule(path: "/api/v1", statusCode: 200),
            MockRule(path: "/api/v2", statusCode: 201)
        ]
        let message = try SocketMessage.syncMockRules(rules)
        XCTAssertEqual(message.type, .syncMockRules)

        let decoded = try JSONDecoder().decode([MockRule].self, from: message.payload)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].path, "/api/v1")
        XCTAssertEqual(decoded[1].path, "/api/v2")
    }

    // MARK: - Codable Tests

    internal func test_socketMessage_encodesAndDecodes() throws {
        let original = SocketMessage(type: .log, payload: Data("test".utf8))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SocketMessage.self, from: data)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.payload, original.payload)
    }
}
