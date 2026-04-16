import Foundation

internal final class PulseAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender, @unchecked Sendable {
    internal typealias CompletionHandler = (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    private let completionHandler: CompletionHandler
    
    internal init(completionHandler: @escaping CompletionHandler) {
        self.completionHandler = completionHandler
    }
    
    internal func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) { completionHandler(.useCredential, credential) }
    internal func continueWithoutCredential(for challenge: URLAuthenticationChallenge) { completionHandler(.performDefaultHandling, nil) }
    internal func cancel(_ challenge: URLAuthenticationChallenge) { completionHandler(.cancelAuthenticationChallenge, nil) }
    internal func performDefaultHandling(for challenge: URLAuthenticationChallenge) { completionHandler(.performDefaultHandling, nil) }
    internal func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) { completionHandler(.rejectProtectionSpace, nil) }
}
