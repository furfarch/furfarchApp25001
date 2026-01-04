import SwiftUI
import SwiftData

/// Simple add-vehicle flow used by the main (+) button.
/// Always creates a new vehicle (VehicleFormView(vehicle: nil)).
struct AddVehicleFlowView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VehicleFormView(vehicle: nil)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}
