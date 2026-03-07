//
//  MockManager.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 06/03/26.
//

import Foundation

final class MockManager: @unchecked Sendable {
    static let shared = MockManager()
    
    private let lock = NSLock()
    private var _rules: [MockRule] = []
    
    private(set) var rules: [MockRule] {
        get { lock.withLock { _rules } }
        set { lock.withLock { _rules = newValue } }
    }
    
    private init() {}
    
    /// Adiciona uma nova regra de mock
    func addRule(_ rule: MockRule) {
        lock.withLock {
            _rules.removeAll { $0.id == rule.id }
            _rules.append(rule)
        }
    }
    
    func removeRule(id: UUID) {
        lock.withLock {
            _rules.removeAll { $0.id == id }
        }
    }
    
    func clearRules() {
        lock.withLock {
            _rules.removeAll()
        }
    }
    
    func syncRules(_ newRules: [MockRule]) {
        lock.withLock {
            _rules = newRules
        }
    }
    
    func findMatchingRule(for url: URL, method: String?) -> MockRule? {
        return lock.withLock {
            _rules.first { $0.matches(url: url, httpMethod: method) }
        }
    }
    
    func hasMock(for request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return findMatchingRule(for: url, method: request.httpMethod) != nil
    }
    
    func createMockResponse(for rule: MockRule, url: URL) -> (HTTPURLResponse?, Data?) {
        var headers: [String: String] = rule.responseHeaders ?? [:]
        
        if headers["Content-Type"] == nil {
            headers["Content-Type"] = "application/json"
        }
        
        let response = HTTPURLResponse(
            url: url,
            statusCode: rule.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )
        
        let data = rule.responseBody?.data(using: .utf8)
        
        return (response, data)
    }
}
