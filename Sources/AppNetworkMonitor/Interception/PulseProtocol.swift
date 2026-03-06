//
//  PulseProtocol.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import Foundation
import Pulse

final class PulseProtocol: URLProtocol, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    
    private var internalSession: URLSession?
    private let lock = NSLock()
    
    let requestID = UUID()
    private var _dataTask: URLSessionDataTask?
    private var _receivedData = Data()
    private var _response: URLResponse?
    private var _startTime: Date?
    private var _cachedBodyData: Data?
    
    private var dataTask: URLSessionDataTask? {
        get { lock.withLock { _dataTask } }
        set { lock.withLock { _dataTask = newValue } }
    }
    
    private var receivedData: Data {
        get { lock.withLock { _receivedData } }
        set { lock.withLock { _receivedData = newValue } }
    }
    
    private var response: URLResponse? {
        get { lock.withLock { _response } }
        set { lock.withLock { _response = newValue } }
    }
    
    private var startTime: Date? {
        get { lock.withLock { _startTime } }
        set { lock.withLock { _startTime = newValue } }
    }
    
    private var cachedBodyData: Data? {
        get { lock.withLock { _cachedBodyData } }
        set { lock.withLock { _cachedBodyData = newValue } }
    }
    
    private func getOrCreateSession() -> URLSession {
        if let session = internalSession {
            return session
        }
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        config.protocolClasses = []
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        internalSession = session
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
        self.sendToSocket(state: .pending)
        
        let finalRequest = mutableRequest as URLRequest
        let session = getOrCreateSession()
        self.dataTask = session.dataTask(with: finalRequest)
        self.dataTask?.resume()
    }
    
    override func stopLoading() {
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
        lock.withLock { _receivedData.append(data) }
        self.client?.urlProtocol(self, didLoad: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error { self.client?.urlProtocol(self, didFailWithError: error) }
        else { self.client?.urlProtocolDidFinishLoading(self) }
        
        self.sendToSocket(state: .completed)
        self.saveToLocalPulse(data: self.receivedData, response: self.response, error: error)
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
    
    private enum TaskState { case pending, completed }
    
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
        
        let finalStatus = (state == .pending) ? 0 : statusCode
        let reqBody = self.cachedBodyData.flatMap { String(data: $0, encoding: .utf8) }
        let resBody = (state == .completed) ? String(data: self.receivedData, encoding: .utf8) : nil
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
