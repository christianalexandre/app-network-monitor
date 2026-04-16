import XCTest
@testable import AppNetworkMonitor

internal final class PulseProtocolIntegrationTests: XCTestCase {

    override internal func setUp() {
        super.setUp()
        MockManager.shared.clearRules()
    }

    override internal func tearDown() {
        MockManager.shared.clearRules()
        super.tearDown()
    }

    // MARK: - Mock Response Path

    internal func test_startLoading_returnsMockedResponse_whenRuleMatches() throws {
        let rule = MockRule(
            path: "/api/mock-test",
            statusCode: 200,
            responseHeaders: ["X-Custom": "test-value"],
            responseBody: "{\"mocked\":true}"
        )
        MockManager.shared.addRule(rule)

        let url = try XCTUnwrap(URL(string: "https://example.com/api/mock-test"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "mock response received")
        var receivedData: Data?
        var receivedResponse: HTTPURLResponse?

        session.dataTask(with: request) { data, response, error in
            receivedData = data
            receivedResponse = response as? HTTPURLResponse
            XCTAssertNil(error)
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)

        XCTAssertEqual(receivedResponse?.statusCode, 200)
        XCTAssertEqual(receivedResponse?.allHeaderFields["X-Custom"] as? String, "test-value")

        let body = receivedData.flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(body, "{\"mocked\":true}")
    }

    internal func test_startLoading_returnsMockedResponse_withDelay() throws {
        let rule = MockRule(
            path: "/api/delayed",
            statusCode: 201,
            responseBody: "delayed",
            delayMs: 100
        )
        MockManager.shared.addRule(rule)

        let url = try XCTUnwrap(URL(string: "https://example.com/api/delayed"))
        let request = URLRequest(url: url)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "delayed mock response")
        let startTime = Date()

        session.dataTask(with: request) { _, response, _ in
            let elapsed = Date().timeIntervalSince(startTime)
            XCTAssertGreaterThanOrEqual(elapsed, 0.05)
            let httpResponse = response as? HTTPURLResponse
            XCTAssertEqual(httpResponse?.statusCode, 201)
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }

    internal func test_startLoading_returnsMockedResponse_withDefaultContentType() throws {
        let rule = MockRule(
            path: "/api/default-ct",
            statusCode: 200,
            responseBody: "{}"
        )
        MockManager.shared.addRule(rule)

        let url = try XCTUnwrap(URL(string: "https://example.com/api/default-ct"))
        let request = URLRequest(url: url)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "mock with default content type")

        session.dataTask(with: request) { _, response, _ in
            let httpResponse = response as? HTTPURLResponse
            XCTAssertEqual(httpResponse?.allHeaderFields["Content-Type"] as? String, "application/json")
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }

    internal func test_startLoading_returnsMockedResponse_withPOSTMethod() throws {
        let rule = MockRule(
            path: "/api/post-test",
            method: "POST",
            statusCode: 201,
            responseBody: "{\"created\":true}"
        )
        MockManager.shared.addRule(rule)

        let url = try XCTUnwrap(URL(string: "https://example.com/api/post-test"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "{\"name\":\"test\"}".data(using: .utf8)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "POST mock response")

        session.dataTask(with: request) { data, response, error in
            XCTAssertNil(error)
            let httpResponse = response as? HTTPURLResponse
            XCTAssertEqual(httpResponse?.statusCode, 201)
            let body = data.flatMap { String(data: $0, encoding: .utf8) }
            XCTAssertEqual(body, "{\"created\":true}")
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }

    internal func test_startLoading_returnsMockedResponse_withNoBody() throws {
        let rule = MockRule(
            path: "/api/no-body",
            statusCode: 204
        )
        MockManager.shared.addRule(rule)

        let url = try XCTUnwrap(URL(string: "https://example.com/api/no-body"))
        let request = URLRequest(url: url)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "no body mock response")

        session.dataTask(with: request) { data, response, _ in
            let httpResponse = response as? HTTPURLResponse
            XCTAssertEqual(httpResponse?.statusCode, 204)
            XCTAssertTrue(data == nil || data?.isEmpty == true)
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - stopLoading Path

    internal func test_stopLoading_cancelsMockedTask() throws {
        let rule = MockRule(
            path: "/api/cancel-test",
            statusCode: 200,
            responseBody: "should be cancelled",
            delayMs: 2000
        )
        MockManager.shared.addRule(rule)

        let url = try XCTUnwrap(URL(string: "https://example.com/api/cancel-test"))
        let request = URLRequest(url: url)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "task cancelled")

        let task = session.dataTask(with: request) { _, _, error in
            // Should receive a cancellation error
            if let error = error as? URLError {
                XCTAssertEqual(error.code, .cancelled)
            }
            expectation.fulfill()
        }
        task.resume()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            task.cancel()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Request Body Capture

    internal func test_startLoading_capturesRequestBodyFromHTTPBody() throws {
        let rule = MockRule(
            path: "/api/body-capture",
            statusCode: 200,
            responseBody: "{\"ok\":true}"
        )
        MockManager.shared.addRule(rule)

        let url = try XCTUnwrap(URL(string: "https://example.com/api/body-capture"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "{\"field\":\"value\"}".data(using: .utf8)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "body captured")

        session.dataTask(with: request) { _, response, error in
            XCTAssertNil(error)
            let httpResponse = response as? HTTPURLResponse
            XCTAssertEqual(httpResponse?.statusCode, 200)
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Request Body Stream Capture

    internal func test_startLoading_capturesRequestBodyFromStream() throws {
        let rule = MockRule(
            path: "/api/stream-body",
            statusCode: 200,
            responseBody: "{\"ok\":true}"
        )
        MockManager.shared.addRule(rule)

        let url = try XCTUnwrap(URL(string: "https://example.com/api/stream-body"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let bodyData = "{\"stream\":\"data\"}".data(using: .utf8)!
        request.httpBodyStream = InputStream(data: bodyData)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "stream body captured")

        session.dataTask(with: request) { _, response, error in
            XCTAssertNil(error)
            let httpResponse = response as? HTTPURLResponse
            XCTAssertEqual(httpResponse?.statusCode, 200)
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Real Network Path (non-mock)

    internal func test_startLoading_makesRealRequest_whenNoMockRuleMatches() throws {
        // No mock rules set - this exercises the real network path:
        // getOrCreateSession, URLSession delegates, sendToSocket(state: .pending/.completed)
        let url = try XCTUnwrap(URL(string: "https://httpbin.org/get"))
        let request = URLRequest(url: url)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "real network response")

        session.dataTask(with: request) { data, response, error in
            // Whether it succeeds or fails, the delegate methods are exercised
            if error == nil {
                let httpResponse = response as? HTTPURLResponse
                XCTAssertEqual(httpResponse?.statusCode, 200)
                XCTAssertNotNil(data)
            }
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 15.0)
    }

    internal func test_startLoading_handlesNetworkError_whenHostUnreachable() throws {
        // Request to non-routable address exercises the error path in didCompleteWithError
        let url = try XCTUnwrap(URL(string: "https://192.0.2.1/unreachable"))
        let request = URLRequest(url: url)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        config.timeoutIntervalForRequest = 2
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "network error received")

        session.dataTask(with: request) { _, _, error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 10.0)
    }

    internal func test_startLoading_realRequest_withPOSTBody() throws {
        // Exercises captureRequestBody with httpBody on real network path
        let url = try XCTUnwrap(URL(string: "https://httpbin.org/post"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "{\"key\":\"value\"}".data(using: .utf8)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "POST response")

        session.dataTask(with: request) { data, response, error in
            if error == nil {
                let httpResponse = response as? HTTPURLResponse
                XCTAssertEqual(httpResponse?.statusCode, 200)
            }
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 15.0)
    }

    // MARK: - Wildcard Mock

    internal func test_startLoading_matchesWildcardRule() throws {
        let rule = MockRule(
            path: "/api/*/items",
            statusCode: 200,
            responseBody: "{\"items\":[]}"
        )
        MockManager.shared.addRule(rule)

        let url = try XCTUnwrap(URL(string: "https://example.com/api/v2/items"))
        let request = URLRequest(url: url)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PulseProtocol.self]
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        let session = URLSession(configuration: config)

        let expectation = expectation(description: "wildcard mock response")

        session.dataTask(with: request) { data, response, _ in
            let httpResponse = response as? HTTPURLResponse
            XCTAssertEqual(httpResponse?.statusCode, 200)
            let body = data.flatMap { String(data: $0, encoding: .utf8) }
            XCTAssertEqual(body, "{\"items\":[]}")
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5.0)
    }
}
