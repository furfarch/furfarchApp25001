import SwiftUI

struct SectionsView: View {
    @State private var showingAbout = false
    @State private var showingAddVehicle = false

    var body: some View {
        NavigationStack {
            VehiclesListView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: "car")
                                Text("Vehicles")
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "road.lanes")
                                Text("Drive Log")
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "checklist")
                                Text("Checklist")
                            }
                        }
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    }
                    // Trailing: About first, then +
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { showingAbout = true } label: { Image(systemName: "info.circle") }
                            .accessibilityLabel("About")
                        Button { showingAddVehicle = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Add Vehicle")
                    }
                }
                .sheet(isPresented: $showingAbout) {
                    NavigationStack { AboutView().navigationTitle("About") }
                }
                .sheet(isPresented: $showingAddVehicle) {
                    NavigationStack { AddVehicleFlowView() }
                }
        }
    }
}

#Preview {
    SectionsView()
}
