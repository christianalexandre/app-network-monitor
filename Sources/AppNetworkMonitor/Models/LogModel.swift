//
//  LogModel.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import Foundation

struct LogModel: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let method: String
    let url: String
    let statusCode: Int
    let duration: TimeInterval
    let requestHeaders: [String: String]?
    let responseHeaders: [String: String]?
    let requestBody: String?
    let responseBody: String?
}
