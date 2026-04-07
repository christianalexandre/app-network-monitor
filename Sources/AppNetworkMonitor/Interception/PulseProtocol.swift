//
//  PulseProtocol.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import Foundation
import Pulse

final class PulseProtocol: URLProtocol, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    
    private var _internalSession: URLSession?
    private let lock = NSLock()
    
    let requestID = UUID()
    private var _dataTask: URLSessionDataTask?
    private var _receivedData = Data()
    private var _response: URLResponse?
    private var _startTime: Date?
    private var _cachedBodyData: Data?
    private var _mockWorkItem: DispatchWorkItem?
    private var _isCancelled = false
    
    private var internalSession: URLSession? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _internalSession
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _internalSession = newValue
        }
    }
    
    private var dataTask: URLSessionDataTask? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _dataTask
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _dataTask = newValue
        }
    }
    
    private var receivedData: Data {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _receivedData
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _receivedData = newValue
        }
    }
    
    private var response: URLResponse? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _response
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _response = newValue
        }
    }
    
    private var startTime: Date? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _startTime
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _startTime = newValue
        }
    }
    
    private var cachedBodyData: Data? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _cachedBodyData
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _cachedBodyData = newValue
        }
    }
    
    private var isCancelled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isCancelled
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isCancelled = newValue
        }
    }
    
    private func getOrCreateSession() -> URLSession {
        lock.lock()
        defer { lock.unlock() }
        
        if let session = _internalSession {
            return session
        }
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        config.protocolClasses = []
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        _internalSession = session
        return session
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme, ["http", "https"].contains(scheme) else { return false }
        if URLProtocol.property(forKey: "PulseHandled", in: request) != nil { return false }
        if let urlString = request.url?.absoluteString, urlString.contains("_vvmonitor") { return false }
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        self.startTime = Date()
        
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "PulseProtocol", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create mutable request"]))
            return
        }
        URLProtocol.setProperty(true, forKey: "PulseHandled", in: mutableRequest)
        
        captureRequestBody(mutableRequest: mutableRequest)
        
        if let url = request.url,
           let mockRule = MockManager.shared.findMatchingRule(for: url, method: request.httpMethod) {
            handleMockedResponse(rule: mockRule, url: url)
            return
        }
        
        self.sendToSocket(state: .pending)
        
        let finalRequest = mutableRequest as URLRequest
        let session = getOrCreateSession()
        self.dataTask = session.dataTask(with: finalRequest)
        self.dataTask?.resume()
    }
    
    private func handleMockedResponse(rule: MockRule, url: URL) {
        let (mockResponse, mockData) = MockManager.shared.createMockResponse(for: rule, url: url)
        let delay = DispatchTimeInterval.milliseconds(rule.delayMs)
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            
            if let response = mockResponse {
                self.response = response
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            
            guard !self.isCancelled else { return }
            
            if let data = mockData {
                self.lock.lock()
                self._receivedData = data
                self.lock.unlock()
                self.client?.urlProtocol(self, didLoad: data)
            }
            
            guard !self.isCancelled else { return }
            
            self.client?.urlProtocolDidFinishLoading(self)
            
            self.sendToSocket(state: .mocked)
            self.saveToLocalPulse(data: mockData, response: mockResponse, error: nil)
        }
        
        lock.lock()
        _mockWorkItem = workItem
        lock.unlock()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    override func stopLoading() {
        self.isCancelled = true
        
        lock.lock()
        _mockWorkItem?.cancel()
        _mockWorkItem = nil
        lock.unlock()
        
        self.dataTask?.cancel()
        self.internalSession?.invalidateAndCancel()
        self.internalSession = nil
    }
    
    private func captureRequestBody(mutableRequest: NSMutableURLRequest) {
        if let httpBody = request.httpBody, !httpBody.isEmpty {
            self.cachedBodyData = httpBody
            return
        }
        
        if let stream = mutableRequest.httpBodyStream {
            let data = readStream(stream)
            if !data.isEmpty {
                self.cachedBodyData = data
                mutableRequest.httpBodyStream = InputStream(data: data)
            }
        }
    }
    
    private func readStream(_ stream: InputStream) -> Data {
        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        stream.open()
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        stream.close()
        
        return data
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        _receivedData.append(data)
        lock.unlock()
        self.client?.urlProtocol(self, didLoad: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error { self.client?.urlProtocol(self, didFailWithError: error) }
        else { self.client?.urlProtocolDidFinishLoading(self) }
        
        self.sendToSocket(state: .completed)
        self.saveToLocalPulse(data: self.receivedData, response: self.response, error: error)
        
        // Invalidate session to break retain cycle (URLSession retains its delegate)
        self.internalSession?.finishTasksAndInvalidate()
        self.internalSession = nil
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let pulseSender = PulseAuthenticationChallengeSender(completionHandler: completionHandler)
        let wrappedChallenge = URLAuthenticationChallenge(
            protectionSpace: challenge.protectionSpace,
            proposedCredential: challenge.proposedCredential,
            previousFailureCount: challenge.previousFailureCount,
            failureResponse: challenge.failureResponse,
            error: challenge.error,
            sender: pulseSender
        )
        self.client?.urlProtocol(self, didReceive: wrappedChallenge)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        self.client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
        completionHandler(request)
    }
    
    private enum TaskState { case pending, completed, mocked }
    
    private func sendToSocket(state: TaskState) {
        let url = request.url?.absoluteString ?? "Unknown"
        let method = request.httpMethod ?? "GET"
        let reqHeaders = request.allHTTPHeaderFields
        var statusCode = 0
        var resHeaders: [String: String]? = nil
        
        if let httpResponse = self.response as? HTTPURLResponse {
            statusCode = httpResponse.statusCode
            resHeaders = [:]
            for (key, value) in httpResponse.allHeaderFields {
                if let keyStr = key as? String, let valueStr = value as? String {
                    resHeaders?[keyStr] = valueStr
                }
            }
        }
        
        if state == .mocked {
            if resHeaders == nil { resHeaders = [:] }
            resHeaders?["X-AppNetworkMonitor-Mocked"] = "true"
        }
        
        let finalStatus = (state == .pending) ? 0 : statusCode
        let reqBody = self.cachedBodyData.flatMap { String(data: $0, encoding: .utf8) }
        let resBody = (state == .completed || state == .mocked) ? String(data: self.receivedData, encoding: .utf8) : nil
        let duration = Date().timeIntervalSince(self.startTime ?? Date())
        
        let log = LogModel(
            id: self.requestID,
            timestamp: self.startTime ?? Date(),
            method: method,
            url: url,
            statusCode: finalStatus,
            duration: duration,
            requestHeaders: reqHeaders,
            responseHeaders: resHeaders,
            requestBody: reqBody,
            responseBody: resBody
        )
        
        SocketClient.shared.send(log: log)
    }
    
    private func saveToLocalPulse(data: Data?, response: URLResponse?, error: Error?) {
        LoggerStore.shared.storeRequest(request, response: response, error: error, data: data, metrics: nil)
    }
}
