//
//  UIWindow+Motion.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import SwiftUI

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { PulseBridge.shared.presentConsole() }
        super.motionEnded(motion, with: event)
    }
}
