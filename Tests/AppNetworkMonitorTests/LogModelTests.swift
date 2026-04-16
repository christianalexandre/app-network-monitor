import XCTest
@testable import AppNetworkMonitor

internal final class LogModelTests: XCTestCase {

    internal func test_isMocked_returnsTrue_whenMockedHeaderIsPresent() {
        let log = LogModel(
            id: UUID(),
            timestamp: Date(),
            method: "GET",
            url: "https://example.com/api",
            statusCode: 200,
            duration: 0.5,
            requestHeaders: nil,
            responseHeaders: ["X-AppNetworkMonitor-Mocked": "true"],
            requestBody: nil,
            responseBody: nil
        )
        XCTAssertTrue(log.isMocked)
    }

    internal func test_isMocked_returnsFalse_whenMockedHeaderIsMissing() {
        let log = LogModel(
            id: UUID(),
            timestamp: Date(),
            method: "GET",
            url: "https://example.com/api",
            statusCode: 200,
            duration: 0.5,
            requestHeaders: nil,
            responseHeaders: ["Content-Type": "application/json"],
            requestBody: nil,
            responseBody: nil
        )
        XCTAssertFalse(log.isMocked)
    }

    internal func test_isMocked_returnsFalse_whenResponseHeadersAreNil() {
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
        XCTAssertFalse(log.isMocked)
    }

    internal func test_isMocked_returnsFalse_whenMockedHeaderValueIsNotTrue() {
        let log = LogModel(
            id: UUID(),
            timestamp: Date(),
            method: "GET",
            url: "https://example.com/api",
            statusCode: 200,
            duration: 0.5,
            requestHeaders: nil,
            responseHeaders: ["X-AppNetworkMonitor-Mocked": "false"],
            requestBody: nil,
            responseBody: nil
        )
        XCTAssertFalse(log.isMocked)
    }

    internal func test_logModel_conformsToIdentifiable() {
        let id = UUID()
        let log = LogModel(
            id: id,
            timestamp: Date(),
            method: "POST",
            url: "https://example.com/api",
            statusCode: 201,
            duration: 1.0,
            requestHeaders: nil,
            responseHeaders: nil,
            requestBody: nil,
            responseBody: nil
        )
        XCTAssertEqual(log.id, id)
    }

    internal func test_logModel_conformsToCodable() throws {
        let log = LogModel(
            id: UUID(),
            timestamp: Date(),
            method: "GET",
            url: "https://example.com/api",
            statusCode: 200,
            duration: 0.5,
            requestHeaders: ["Authorization": "Bearer token"],
            responseHeaders: ["Content-Type": "application/json"],
            requestBody: "{\"key\":\"value\"}",
            responseBody: "{\"result\":\"ok\"}"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(log)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LogModel.self, from: data)

        XCTAssertEqual(decoded.id, log.id)
        XCTAssertEqual(decoded.method, log.method)
        XCTAssertEqual(decoded.url, log.url)
        XCTAssertEqual(decoded.statusCode, log.statusCode)
        XCTAssertEqual(decoded.requestHeaders, log.requestHeaders)
        XCTAssertEqual(decoded.responseHeaders, log.responseHeaders)
        XCTAssertEqual(decoded.requestBody, log.requestBody)
        XCTAssertEqual(decoded.responseBody, log.responseBody)
    }

    internal func test_logModel_conformsToHashable() {
        let id = UUID()
        let date = Date()
        let log1 = LogModel(
            id: id, timestamp: date, method: "GET", url: "https://example.com",
            statusCode: 200, duration: 0.5, requestHeaders: nil,
            responseHeaders: nil, requestBody: nil, responseBody: nil
        )
        let log2 = LogModel(
            id: id, timestamp: date, method: "GET", url: "https://example.com",
            statusCode: 200, duration: 0.5, requestHeaders: nil,
            responseHeaders: nil, requestBody: nil, responseBody: nil
        )
        XCTAssertEqual(log1, log2)
        XCTAssertEqual(log1.hashValue, log2.hashValue)
    }
}
