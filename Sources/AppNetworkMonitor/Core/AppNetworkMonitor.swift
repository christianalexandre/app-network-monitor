import Foundation
import SwiftUI

public class AppNetworkMonitor: @unchecked Sendable {
    public static let shared = AppNetworkMonitor()

    @MainActor private var consoleHostingController: UIHostingController<PulseContainerView>?

    public func start() {
        SocketClient.shared.connect()
        NetworkInterceptor.shared.start()
    }

    @MainActor public func presentConsole() {
        let windowScene = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first as? UIWindowScene
        guard let rootViewController = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            if presented is UIHostingController<PulseContainerView> { return }
            topViewController = presented
        }

        let hostingController = getOrCreateConsoleController()
        topViewController.present(hostingController, animated: true)
    }

    @MainActor private func getOrCreateConsoleController() -> UIHostingController<PulseContainerView> {
        if let existing = consoleHostingController {
            return existing
        }
        let controller = UIHostingController(rootView: PulseContainerView())
        controller.modalPresentationStyle = .fullScreen
        consoleHostingController = controller
        return controller
    }
}
