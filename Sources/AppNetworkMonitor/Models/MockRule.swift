#if APPNETWORKMONITOR_ENABLED
//
//  MockRule.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 06/03/26.
//

import Foundation

public struct MockRule: Codable, Hashable, Identifiable {
    public let id: UUID
    public let path: String
    public let method: String?
    public let statusCode: Int
    public let responseHeaders: [String: String]?
    public let responseBody: String?
    public let delayMs: Int
    public let isEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        path: String,
        method: String? = nil,
        statusCode: Int = 200,
        responseHeaders: [String: String]? = nil,
        responseBody: String? = nil,
        delayMs: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.path = path
        self.method = method
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.delayMs = delayMs
        self.isEnabled = isEnabled
    }
    
    func matches(url: URL, httpMethod: String?) -> Bool {
        guard isEnabled else { return false }
        
        if let ruleMethod = method, let reqMethod = httpMethod {
            if ruleMethod.uppercased() != reqMethod.uppercased() {
                return false
            }
        }
        
        let urlPath = url.path
        
        if path == urlPath {
            return true
        }
        
        if path.contains("*") {
            let escapedPath = NSRegularExpression.escapedPattern(for: path)
            let pattern = escapedPath.replacingOccurrences(of: "\\*", with: ".*")
            
            if let regex = try? NSRegularExpression(pattern: "^\(pattern)$", options: []) {
                let range = NSRange(urlPath.startIndex..., in: urlPath)
                return regex.firstMatch(in: urlPath, options: [], range: range) != nil
            }
        }
        
        return false
    }
}

public enum SocketMessageType: String, Codable {
    case log = "LOG"
    case addMockRule = "ADD_MOCK_RULE"
    case removeMockRule = "REMOVE_MOCK_RULE"
    case clearMockRules = "CLEAR_MOCK_RULES"
    case syncMockRules = "SYNC_MOCK_RULES"
}

public struct SocketMessage: Codable {
    public let type: SocketMessageType
    public let payload: Data
    
    public init(type: SocketMessageType, payload: Data) {
        self.type = type
        self.payload = payload
    }
    
    static func log(_ logModel: LogModel) throws -> SocketMessage {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(logModel)
        return SocketMessage(type: .log, payload: data)
    }
    
    public static func addMockRule(_ rule: MockRule) throws -> SocketMessage {
        let data = try JSONEncoder().encode(rule)
        return SocketMessage(type: .addMockRule, payload: data)
    }
    
    public static func removeMockRule(id: UUID) throws -> SocketMessage {
        let data = try JSONEncoder().encode(id)
        return SocketMessage(type: .removeMockRule, payload: data)
    }
    
    public static func clearMockRules() -> SocketMessage {
        return SocketMessage(type: .clearMockRules, payload: Data())
    }
    
    public static func syncMockRules(_ rules: [MockRule]) throws -> SocketMessage {
        let data = try JSONEncoder().encode(rules)
        return SocketMessage(type: .syncMockRules, payload: data)
    }
}
#endif
