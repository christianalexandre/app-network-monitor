import XCTest
@testable import AppNetworkMonitor

internal final class PulseProtocolTests: XCTestCase {

    // MARK: - canInit Tests

    internal func test_canInit_returnsFalse_forNonHTTPScheme() throws {
        let url = try XCTUnwrap(URL(string: "ftp://example.com/file"))
        let request = URLRequest(url: url)
        XCTAssertFalse(PulseProtocol.canInit(with: request))
    }

    internal func test_canInit_returnsFalse_forCustomScheme() throws {
        let url = try XCTUnwrap(URL(string: "myapp://deeplink"))
        let request = URLRequest(url: url)
        XCTAssertFalse(PulseProtocol.canInit(with: request))
    }

    internal func test_canInit_returnsTrue_forHTTPRequest() throws {
        let url = try XCTUnwrap(URL(string: "http://example.com/api"))
        let request = URLRequest(url: url)
        XCTAssertTrue(PulseProtocol.canInit(with: request))
    }

    internal func test_canInit_returnsTrue_forHTTPSRequest() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api"))
        let request = URLRequest(url: url)
        XCTAssertTrue(PulseProtocol.canInit(with: request))
    }

    internal func test_canInit_returnsFalse_forAlreadyHandledRequest() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api"))
        let mutableRequest = NSMutableURLRequest(url: url)
        URLProtocol.setProperty(true, forKey: "PulseHandled", in: mutableRequest)
        XCTAssertFalse(PulseProtocol.canInit(with: mutableRequest as URLRequest))
    }

    internal func test_canInit_returnsFalse_forAppMonitorURL() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/_appmonitor/status"))
        let request = URLRequest(url: url)
        XCTAssertFalse(PulseProtocol.canInit(with: request))
    }

    internal func test_canInit_returnsTrue_forRegularHTTPSURL() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/v1/products"))
        let request = URLRequest(url: url)
        XCTAssertTrue(PulseProtocol.canInit(with: request))
    }

    internal func test_canInit_returnsFalse_forURLWithNoScheme() {
        var components = URLComponents()
        components.host = "example.com"
        components.path = "/api"
        // URLComponents without scheme produces a URL with no scheme
        if let url = components.url {
            let request = URLRequest(url: url)
            XCTAssertFalse(PulseProtocol.canInit(with: request))
        }
    }

    internal func test_canInit_returnsFalse_forAppMonitorInPath() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/path/_appmonitor/endpoint"))
        let request = URLRequest(url: url)
        XCTAssertFalse(PulseProtocol.canInit(with: request))
    }

    // MARK: - canonicalRequest Tests

    internal func test_canonicalRequest_returnsSameRequest() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api"))
        let request = URLRequest(url: url)
        let canonical = PulseProtocol.canonicalRequest(for: request)
        XCTAssertEqual(canonical.url, request.url)
    }

    internal func test_canonicalRequest_preservesHTTPMethod() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let canonical = PulseProtocol.canonicalRequest(for: request)
        XCTAssertEqual(canonical.httpMethod, "POST")
    }

    internal func test_canonicalRequest_preservesHeaders() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/api"))
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let canonical = PulseProtocol.canonicalRequest(for: request)
        XCTAssertEqual(canonical.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
}
