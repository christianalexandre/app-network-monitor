//
//  SocketClient.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import Network
import Foundation

final class SocketClient: @unchecked Sendable {
    static let shared = SocketClient()
    
    private var connection: NWConnection?
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.debug.socket")
    private var isScanning = false
    
    func connect() {
        guard connection?.state != .ready && !isScanning else { return }
        startScanning()
    }
    
    private func startScanning() {
        isScanning = true
        print("[AppNetworkMonitor] Searching for AppNetworkMonitor...")

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_appmonitor._tcp", domain: nil), using: parameters)
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }

            if let result = results.first {
                print("[AppNetworkMonitor] Found: \(result.endpoint)")
                browser.cancel()
                self.isScanning = false
                self.connectToEndpoint(result.endpoint)
            }
        }
        
        self.browser = browser
        browser.start(queue: queue)
    }
    
    private func connectToEndpoint(_ endpoint: NWEndpoint) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        
        let framerOptions = NWProtocolFramer.Options(definition: AppNetworkProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols.insert(framerOptions, at: 0)
        
        connection = NWConnection(to: endpoint, using: parameters)
        
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                print("[AppNetworkMonitor] Connected!")
            case .failed(let error):
                print("[AppNetworkMonitor] Failure: \(error)")
                self.scheduleRetry()
            case .waiting(let error):
                print("[AppNetworkMonitor] Waiting... \(error.localizedDescription)")
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
    }
    
    private func scheduleRetry() {
        connection?.cancel()
        connection = nil
        isScanning = false
        queue.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.connect()
        }
    }
    
    func send(log: LogModel) {
        guard connection?.state == .ready else { return }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(log) else { return }
        
        let message = NWProtocolFramer.Message(definition: AppNetworkProtocol.definition)
        let context = NWConnection.ContentContext(identifier: "LogMessage", metadata: [message])
        
        connection?.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { error in
            if let error = error {
                print("[AppNetworkMonitor] Send failure: \(error)")
            }
        })
    }
}
