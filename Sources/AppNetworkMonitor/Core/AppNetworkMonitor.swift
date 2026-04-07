#if APPNETWORKMONITOR_ENABLED
//
//  AppNetworkMonitor.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import Foundation
import SwiftUI

public class AppNetworkMonitor: @unchecked Sendable {
    public static let shared = AppNetworkMonitor()
    
    public func start() {
        SocketClient.shared.connect()
        NetworkInterceptor.shared.start()
    }
    
    @MainActor func presentConsole() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController
        else { return }

        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            if presented is UIHostingController<PulseContainerView> { return }
            topViewController = presented
        }

        let consoleView = PulseContainerView()
        let hostingController = UIHostingController(rootView: consoleView)
        hostingController.modalPresentationStyle = .fullScreen
        topViewController.present(hostingController, animated: true)
    }
}
#endif
