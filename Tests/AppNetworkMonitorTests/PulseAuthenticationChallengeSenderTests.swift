import XCTest
@testable import AppNetworkMonitor

internal final class PulseAuthenticationChallengeSenderTests: XCTestCase {

    private func makeDummyChallenge() -> URLAuthenticationChallenge {
        let space = URLProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodDefault
        )
        return URLAuthenticationChallenge(
            protectionSpace: space,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: DummySender()
        )
    }

    internal func test_useCredential_callsCompletionWithUseCredential() {
        let expectation = expectation(description: "completion called")
        let credential = URLCredential(user: "user", password: "pass", persistence: .none)

        let sender = PulseAuthenticationChallengeSender { disposition, cred in
            XCTAssertEqual(disposition, .useCredential)
            XCTAssertEqual(cred, credential)
            expectation.fulfill()
        }

        sender.use(credential, for: makeDummyChallenge())
        wait(for: [expectation], timeout: 1.0)
    }

    internal func test_continueWithoutCredential_callsCompletionWithPerformDefaultHandling() {
        let expectation = expectation(description: "completion called")

        let sender = PulseAuthenticationChallengeSender { disposition, cred in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(cred)
            expectation.fulfill()
        }

        sender.continueWithoutCredential(for: makeDummyChallenge())
        wait(for: [expectation], timeout: 1.0)
    }

    internal func test_cancel_callsCompletionWithCancelAuthenticationChallenge() {
        let expectation = expectation(description: "completion called")

        let sender = PulseAuthenticationChallengeSender { disposition, cred in
            XCTAssertEqual(disposition, .cancelAuthenticationChallenge)
            XCTAssertNil(cred)
            expectation.fulfill()
        }

        sender.cancel(makeDummyChallenge())
        wait(for: [expectation], timeout: 1.0)
    }

    internal func test_performDefaultHandling_callsCompletionWithPerformDefaultHandling() {
        let expectation = expectation(description: "completion called")

        let sender = PulseAuthenticationChallengeSender { disposition, cred in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(cred)
            expectation.fulfill()
        }

        sender.performDefaultHandling(for: makeDummyChallenge())
        wait(for: [expectation], timeout: 1.0)
    }

    internal func test_rejectProtectionSpaceAndContinue_callsCompletionWithRejectProtectionSpace() {
        let expectation = expectation(description: "completion called")

        let sender = PulseAuthenticationChallengeSender { disposition, cred in
            XCTAssertEqual(disposition, .rejectProtectionSpace)
            XCTAssertNil(cred)
            expectation.fulfill()
        }

        sender.rejectProtectionSpaceAndContinue(with: makeDummyChallenge())
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Helpers

private final class DummySender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {}
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {}
}
