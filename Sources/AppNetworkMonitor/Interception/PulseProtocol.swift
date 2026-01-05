//
//  PulseProtocol.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import Foundation
import Pulse

final class PulseProtocol: URLProtocol, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    
    private lazy var internalSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = ["X-Pulse-Internal": "true"]
        config.protocolClasses = []
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    let requestID = UUID()
    var dataTask: URLSessionDataTask?
    var receivedData = Data()
    var response: URLResponse?
    var startTime: Date?
    
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
        self.sendToSocket(state: .pending)
        
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else { return }
        URLProtocol.setProperty(true, forKey: "PulseHandled", in: mutableRequest)
        
        let finalRequest = mutableRequest as URLRequest
        self.dataTask = self.internalSession.dataTask(with: finalRequest)
        self.dataTask?.resume()
    }
    
    override func stopLoading() {
        self.dataTask?.cancel()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.receivedData.append(data)
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
        let reqBody = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
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
