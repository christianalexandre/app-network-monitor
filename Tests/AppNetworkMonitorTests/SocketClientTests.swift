import XCTest
@testable import AppNetworkMonitor

internal final class SocketClientTests: XCTestCase {

    internal func test_shared_returnsSameInstance() {
        let instance1 = SocketClient.shared
        let instance2 = SocketClient.shared
        XCTAssertTrue(instance1 === instance2)
    }

    internal func test_send_doesNotCrash_whenNotConnected() {
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
        // Should return early without crashing since connection is not ready
        SocketClient.shared.send(log: log)
    }

    internal func test_connect_doesNotCrash() {
        // Calling connect without a real server should not crash.
        // It will start scanning but won't find anything.
        SocketClient.shared.connect()
    }
}
