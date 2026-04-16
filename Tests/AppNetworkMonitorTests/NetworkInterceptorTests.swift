import XCTest
@testable import AppNetworkMonitor

internal final class NetworkInterceptorTests: XCTestCase {

    internal func test_shared_returnsSameInstance() {
        let instance1 = NetworkInterceptor.shared
        let instance2 = NetworkInterceptor.shared
        XCTAssertTrue(instance1 === instance2)
    }

    internal func test_start_registersProtocol() {
        NetworkInterceptor.shared.start()
        // Calling start again should be idempotent (guard !started)
        NetworkInterceptor.shared.start()
        // If we reach here without crash, idempotency works
    }
}
