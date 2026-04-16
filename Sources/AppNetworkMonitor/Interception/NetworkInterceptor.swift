import Foundation

internal final class NetworkInterceptor: @unchecked Sendable {
    internal static let shared = NetworkInterceptor()
    private var started = false
    
    internal func start() {
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
        let mapping: [Selector: Selector] = [
            #selector(getter: URLSessionConfiguration.default): #selector(getter: URLSessionConfiguration.swizzledDefault),
            #selector(getter: URLSessionConfiguration.ephemeral): #selector(getter: URLSessionConfiguration.swizzledEphemeral)
        ]
        for (original, swizzled) in mapping {
            guard let originalMethod = class_getClassMethod(URLSessionConfiguration.self, original),
                  let swizzledMethod = class_getClassMethod(URLSessionConfiguration.self, swizzled) else { continue }
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    private func swizzleConfigurationInit() {
        let selector = NSSelectorFromString("init")
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
