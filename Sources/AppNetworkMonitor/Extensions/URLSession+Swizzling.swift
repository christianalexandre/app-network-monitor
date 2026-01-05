//
//  URLSession+Swizzling.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import Foundation

extension URLSession {
    @objc dynamic func swizzled_init(configuration: URLSessionConfiguration, delegate: URLSessionDelegate?, delegateQueue: OperationQueue?) -> URLSession {
        if let headers = configuration.httpAdditionalHeaders as? [String: String], headers["X-Pulse-Internal"] == "true" {
            return self.swizzled_init(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        }
        configuration.protocolClasses = [PulseProtocol.self] + (configuration.protocolClasses ?? [])
        return self.swizzled_init(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
    }
    
    @objc class func swizzled_session(configuration: URLSessionConfiguration, delegate: URLSessionDelegate?, delegateQueue: OperationQueue?) -> URLSession {
        if let headers = configuration.httpAdditionalHeaders as? [String: String], headers["X-Pulse-Internal"] == "true" {
            return self.swizzled_session(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        }
        configuration.protocolClasses = [PulseProtocol.self] + (configuration.protocolClasses ?? [])
        return self.swizzled_session(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
    }
}

extension URLSessionConfiguration {
    @objc dynamic class var swizzled_default: URLSessionConfiguration {
        let config = self.swizzled_default
        config.protocolClasses = [PulseProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
    
    @objc dynamic class var swizzled_ephemeral: URLSessionConfiguration {
        let config = self.swizzled_ephemeral
        config.protocolClasses = [PulseProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
    
    @objc dynamic func swizzled_init() -> URLSessionConfiguration {
        let config = self.swizzled_init() // init original
        config.protocolClasses = [PulseProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
}

