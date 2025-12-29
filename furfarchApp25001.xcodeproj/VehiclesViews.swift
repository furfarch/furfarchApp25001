import SwiftUI
import UIKit

struct VehicleFormView: View {
    @State private var plate: String = ""
    @State private var model: String = ""
    @State private var color: String = ""

    var body: some View {
        Form {
            Section(header: Text("Vehicle Details")) {
                TextField("License Plate", text: $plate)
                PlateScannerView { recognized in
                    // Prefill the plate field with recognized text
                    self.plate = recognized
                }
                TextField("Model", text: $model)
                TextField("Color", text: $color)
            }
        }
        .navigationTitle("Add/Edit Vehicle")
    }
}
