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
        if let presented = rootViewController.presentedViewController,
           presented is UIHostingController<PulseContainerView> {
            return
        }
        
        let consoleView = PulseContainerView()
        let hostingController = UIHostingController(rootView: consoleView)
        hostingController.modalPresentationStyle = .fullScreen
        rootViewController.present(hostingController, animated: true)
    }
}
