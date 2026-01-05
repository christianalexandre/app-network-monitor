//
//  PulseAuthenticationChallengeSender.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import Foundation

final class PulseAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender, @unchecked Sendable {
    typealias CompletionHandler = (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    private let completionHandler: CompletionHandler
    
    init(completionHandler: @escaping CompletionHandler) {
        self.completionHandler = completionHandler
    }
    
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) { completionHandler(.useCredential, credential) }
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) { completionHandler(.useCredential, nil) }
    func cancel(_ challenge: URLAuthenticationChallenge) { completionHandler(.cancelAuthenticationChallenge, nil) }
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) { completionHandler(.performDefaultHandling, nil) }
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) { completionHandler(.rejectProtectionSpace, nil) }
}
