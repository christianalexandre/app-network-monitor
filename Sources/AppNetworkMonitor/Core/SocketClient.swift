//
//  SocketClient.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import Foundation
import Network

final class SocketClient: @unchecked Sendable {
    static let shared = SocketClient()
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.debug.socket")
    
    func connect() {
        let endpoint = NWEndpoint.service(name: "AppNetworkMonitor", type: "_appmonitor._tcp", domain: "local", interface: nil)
        let parameters = NWParameters.tcp
        let webSocketOptions = NWProtocolWebSocket.Options()
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)
        
        connection = NWConnection(to: endpoint, using: parameters)
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            if case .failed = state {
                self.queue.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.connect()
                }
            }
        }
        connection?.start(queue: queue)
    }
    
    func send(log: LogModel) {
        guard connection?.state == .ready else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(log) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "log", metadata: [metadata])
        connection?.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
    }
}
