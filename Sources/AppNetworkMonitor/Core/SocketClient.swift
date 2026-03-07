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
    private let lock = NSLock()
    private var _isScanning = false
    private var _isRetrying = false
    
    private var isScanning: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isScanning
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isScanning = newValue
        }
    }
    
    private var isRetrying: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isRetrying
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isRetrying = newValue
        }
    }
    
    func connect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard self.connection?.state != .ready && !self.isScanning else { return }
            self.startScanning()
        }
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
                self.startReceiving()
            case .failed(let error):
                print("[AppNetworkMonitor] Failure: \(error)")
                self.scheduleRetry(isLocalCancellation: false)
            case .waiting(let error):
                print("[AppNetworkMonitor] Waiting... \(error.localizedDescription)")
            case .cancelled:
                print("[AppNetworkMonitor] Connection cancelled")
                self.scheduleRetry(isLocalCancellation: false)
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
    }
    
    private func scheduleRetry(isLocalCancellation: Bool = false) {
        guard !isRetrying else { return }
        isRetrying = true
        
        if !isLocalCancellation {
            connection?.cancel()
        }
        connection = nil
        isScanning = false
        
        queue.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.isRetrying = false
            self?.connect()
        }
    }
    
    // MARK: - Receiving Messages from Mac
    
    private func startReceiving() {
        receiveNextMessage()
    }
    
    private func receiveNextMessage() {
        connection?.receiveMessage { [weak self] content, context, isComplete, error in
            guard let self = self else { return }
            guard error == nil else { return }
            
            if let data = content, !data.isEmpty {
                self.handleReceivedMessage(data)
            }
            
            if self.connection?.state == .ready {
                self.receiveNextMessage()
            }
        }
    }
    
    private func handleReceivedMessage(_ data: Data) {
        do {
            let message = try JSONDecoder().decode(SocketMessage.self, from: data)
            
            switch message.type {
            case .addMockRule:
                let rule = try JSONDecoder().decode(MockRule.self, from: message.payload)
                MockManager.shared.addRule(rule)
                
            case .removeMockRule:
                let id = try JSONDecoder().decode(UUID.self, from: message.payload)
                MockManager.shared.removeRule(id: id)
                
            case .clearMockRules:
                MockManager.shared.clearRules()
                
            case .syncMockRules:
                let rules = try JSONDecoder().decode([MockRule].self, from: message.payload)
                MockManager.shared.syncRules(rules)
                
            case .log:
                break
            }
        } catch { }
    }
    
    func send(log: LogModel) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard self.connection?.state == .ready else {
                print("[AppNetworkMonitor] Cannot send - not connected")
                return
            }
            
            guard let socketMessage = try? SocketMessage.log(log) else {
                print("[AppNetworkMonitor] Failed to encode log")
                return
            }
            
            self.sendSocketMessage(socketMessage)
        }
    }
    
    private func sendSocketMessage(_ socketMessage: SocketMessage) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(socketMessage) else { return }
        
        let message = NWProtocolFramer.Message(definition: AppNetworkProtocol.definition)
        let context = NWConnection.ContentContext(identifier: "SocketMessage", metadata: [message])
        
        connection?.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
    }
}
