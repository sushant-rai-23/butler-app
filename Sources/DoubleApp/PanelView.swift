import SwiftUI

/// Content of the floating panel. Empty in Phase 0.
struct PanelView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Double")
                .font(.title2.weight(.semibold))
            Text("Nothing to hold yet, sir.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .frame(width: 360, height: 420, alignment: .topLeading)
    }
}
