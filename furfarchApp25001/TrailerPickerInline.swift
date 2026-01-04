import SwiftUI
import SwiftData

/// Standalone implementation to avoid stale linkage state.
/// Computes trailer availability by fetching Vehicles from the current modelContext.
struct TrailerPickerInline: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selection: Trailer?

    @Query(sort: \Trailer.lastEdited, order: .reverse) private var trailers: [Trailer]

    @State private var showingNewTrailer = false
    @State private var refreshID = UUID()

    private var availableTrailers: [Trailer] {
        trailers.filter { t in
            // Allow current selection even if linked (because it's linked to THIS vehicle).
            if selection?.id == t.id { return true }
            // Only allow trailers not linked to any vehicle.
            return t.linkedVehicle == nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Existing", selection: $selection) {
                Text("None").tag(Trailer?.none)
                ForEach(availableTrailers) { t in
                    Text(t.brandModel.isEmpty ? (t.plate.isEmpty ? "Trailer" : t.plate) : t.brandModel)
                        .tag(Trailer?.some(t))
                }
            }
            .pickerStyle(.menu)

            Button { showingNewTrailer = true } label: {
                Label("Add New Trailer", systemImage: "plus.circle")
            }
            .sheet(isPresented: $showingNewTrailer) {
                NavigationStack {
                    CreateTrailerView { newTrailer in
                        modelContext.insert(newTrailer)
                        selection = newTrailer
                        do { try modelContext.save() } catch { print("ERROR: failed saving new trailer: \(error)") }
                        refreshID = UUID()
                        showingNewTrailer = false
                    }
                }
            }
        }
        .id(refreshID)
        .onChange(of: trailers.count) { _, _ in refreshID = UUID() }
        .onChange(of: selection?.id) { _, _ in refreshID = UUID() }
    }
}
