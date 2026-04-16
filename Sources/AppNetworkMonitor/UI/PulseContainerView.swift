import SwiftUI
import PulseUI

internal struct PulseContainerView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ConsoleView().navigationTitle("Console").navigationBarTitleDisplayMode(.inline)
        }
    }
}
