#if APPNETWORKMONITOR_ENABLED
//
//  NetworkInterceptor.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import Foundation

final class NetworkInterceptor: @unchecked Sendable {
    static let shared = NetworkInterceptor()
    private var started = false
    
    func start() {
        guard !started else { return }
        started = true
        
        URLProtocol.registerClass(PulseProtocol.self)
        
        swizzleConfigurationGetters()
        swizzleConfigurationInit()
        swizzleSessionInstanceInit()
        swizzleSessionClassMethod()
        
        print("NetworkInterceptor: Started!")
    }
    
    private func swizzleConfigurationGetters() {
        let selectors = [
            #selector(getter: URLSessionConfiguration.default),
            #selector(getter: URLSessionConfiguration.ephemeral)
        ]
        for selector in selectors {
            let swizzledSelector = Selector("swizzled_" + String(describing: selector))
            guard let originalMethod = class_getClassMethod(URLSessionConfiguration.self, selector),
                  let swizzledMethod = class_getClassMethod(URLSessionConfiguration.self, swizzledSelector) else { continue }
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    private func swizzleConfigurationInit() {
        let selector = #selector(URLSessionConfiguration.init)
        let swizzledSelector = #selector(URLSessionConfiguration.swizzled_init)
        guard let originalMethod = class_getInstanceMethod(URLSessionConfiguration.self, selector),
              let swizzledMethod = class_getInstanceMethod(URLSessionConfiguration.self, swizzledSelector) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    private func swizzleSessionInstanceInit() {
        let selector = #selector(URLSession.init(configuration:delegate:delegateQueue:))
        let swizzledSelector = #selector(URLSession.swizzled_init(configuration:delegate:delegateQueue:))
        guard let originalMethod = class_getInstanceMethod(URLSession.self, selector),
              let swizzledMethod = class_getInstanceMethod(URLSession.self, swizzledSelector) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    private func swizzleSessionClassMethod() {
        let selector = #selector(URLSession.init(configuration:delegate:delegateQueue:))
        let swizzledSelector = #selector(URLSession.swizzled_session(configuration:delegate:delegateQueue:))
        
        guard let originalMethod = class_getClassMethod(URLSession.self, selector),
              let swizzledMethod = class_getClassMethod(URLSession.self, swizzledSelector) else {
            print("Error: Cannot find session.")
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
#endif
