import SwiftUI

struct SectionsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    VehiclesListView()
                } label: {
                    Label("Vehicles", systemImage: "car")
                }
                NavigationLink {
                    DriveLogListView()
                } label: {
                    Label("Drive Log", systemImage: "road.lanes")
                }
                NavigationLink {
                    ChecklistListView()
                } label: {
                    Label("Checklist", systemImage: "checklist")
                }
            }
            .navigationTitle("Sections")
        }
    }
}

struct VehiclesListView: View {
    var body: some View {
        Text("Vehicles List View")
            .navigationTitle("Vehicles")
    }
}

struct DriveLogListView: View {
    var body: some View {
        Text("Drive Log List View")
            .navigationTitle("Drive Log")
    }
}

struct ChecklistListView: View {
    var body: some View {
        Text("Checklist List View")
            .navigationTitle("Checklist")
    }
}

#Preview {
    SectionsView()
}
