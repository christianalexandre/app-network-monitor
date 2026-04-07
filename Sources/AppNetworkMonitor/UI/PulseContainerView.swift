#if APPNETWORKMONITOR_ENABLED
//
//  PulseContainerView.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 30/12/25.
//

import SwiftUI
import PulseUI

struct PulseContainerView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ConsoleView().navigationTitle("Console").navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
