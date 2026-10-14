import SwiftUI

/// Train tab. Adding today's workout and the session come in the next M4 steps.
struct TrainView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today").font(Theme.heading)
                    Text("Adding today's workout comes in the next step. The test screen still has everything.")
                        .foregroundStyle(.secondary)
                    NavigationLink("Open the test screen") {
                        PlateCalculatorView()
                    }
                    .buttonStyle(.black)
                }
                .drawer()
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Train")
        }
    }
}
