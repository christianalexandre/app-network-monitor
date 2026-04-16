import Foundation

internal extension URLSession {
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

internal extension URLSessionConfiguration {
    @objc dynamic class var swizzledDefault: URLSessionConfiguration {
        let config = self.swizzledDefault
        config.protocolClasses = [PulseProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
    
    @objc dynamic class var swizzledEphemeral: URLSessionConfiguration {
        let config = self.swizzledEphemeral
        config.protocolClasses = [PulseProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
    
    @objc dynamic func swizzled_init() -> URLSessionConfiguration {
        let config = self.swizzled_init()
        config.protocolClasses = [PulseProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
}
