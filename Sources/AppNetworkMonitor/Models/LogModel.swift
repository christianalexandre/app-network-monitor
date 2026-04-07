#if APPNETWORKMONITOR_ENABLED
//
//  LogModel.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import Foundation

public struct LogModel: Identifiable, Codable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let method: String
    public let url: String
    public let statusCode: Int
    public let duration: TimeInterval
    public let requestHeaders: [String: String]?
    public let responseHeaders: [String: String]?
    public let requestBody: String?
    public let responseBody: String?
    
    public var isMocked: Bool {
        return responseHeaders?["X-AppNetworkMonitor-Mocked"] == "true"
    }
}
#endif
