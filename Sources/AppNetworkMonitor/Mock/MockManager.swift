import Foundation

internal final class MockManager: @unchecked Sendable {
    internal static let shared = MockManager()
    
    private let lock = NSLock()
    private var _rules: [MockRule] = []
    
    private(set) var rules: [MockRule] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _rules
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _rules = newValue
        }
    }
    
    private init() {}
    
    /// Adiciona uma nova regra de mock
    internal func addRule(_ rule: MockRule) {
        lock.lock()
        defer { lock.unlock() }
        _rules.removeAll { $0.id == rule.id }
        _rules.append(rule)
    }
    
    internal func removeRule(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        _rules.removeAll { $0.id == id }
    }
    
    internal func clearRules() {
        lock.lock()
        defer { lock.unlock() }
        _rules.removeAll()
    }
    
    internal func syncRules(_ newRules: [MockRule]) {
        lock.lock()
        defer { lock.unlock() }
        _rules = newRules
    }
    
    internal func findMatchingRule(for url: URL, method: String?) -> MockRule? {
        lock.lock()
        defer { lock.unlock() }
        return _rules.first { $0.matches(url: url, httpMethod: method) }
    }
    
    internal func hasMock(for request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return findMatchingRule(for: url, method: request.httpMethod) != nil
    }
    
    internal func createMockResponse(for rule: MockRule, url: URL) -> (HTTPURLResponse?, Data?) {
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
