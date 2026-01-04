import SwiftUI
import SwiftData

struct ChecklistListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var checklists: [Checklist]

    @State private var showingCreate = false
    @State private var editChecklist: Checklist? = nil

    var body: some View {
        List {
            if checklists.isEmpty {
                
                ContentUnavailableView("No checklists", systemImage: "checklist", description: Text("Tap + to create a checklist from a template or blank."))
            } else {
                ForEach(checklists) { cl in
                    NavigationLink(destination: ChecklistEditorView(checklist: cl)) {
                        VStack(alignment: .leading) {
                            Text(cl.title).font(.headline)
                            Text(cl.vehicleType.displayName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Checklists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingCreate) {
            NavigationStack {
                CreateChecklistView { new in
                    modelContext.insert(new)
                    try? modelContext.save()
                    showingCreate = false
                    // open editor for created checklist
                    editChecklist = new
                }
                .environment(\.modelContext, modelContext)
            }
        }
        .sheet(item: $editChecklist) { cl in
            NavigationStack { ChecklistEditorView(checklist: cl) }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(checklists[i]) }
        try? modelContext.save()
    }
}

struct CreateChecklistView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (Checklist) -> Void

    /// When provided, the checklist is created for this vehicle (no extra selection required).
    var preselectedVehicle: Vehicle? = nil

    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @State private var selectedVehicle: Vehicle? = nil

    var body: some View {
        Form {
            Section("Vehicle") {
                if let preselectedVehicle {
                    HStack {
                        Text("Vehicle")
                        Spacer()
                        Text(preselectedVehicle.brandModel.isEmpty ? preselectedVehicle.type.displayName : preselectedVehicle.brandModel)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Picker("Vehicle", selection: $selectedVehicle) {
                        Text("Select...").tag(Vehicle?.none)
                        ForEach(vehicles) { v in
                            Text(v.brandModel.isEmpty ? v.type.displayName : v.brandModel)
                                .tag(Vehicle?.some(v))
                        }
                    }
                }
            }
        }
        .navigationTitle("New Checklist")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let effectiveVehicle = preselectedVehicle ?? selectedVehicle
                    guard let selectedVehicle = effectiveVehicle else { return }
                    let finalTitle = ChecklistTitle.make(for: selectedVehicle.type, date: .now)

                    // Always prefill based on the vehicle's type.
                    let items = ChecklistTemplates.items(for: selectedVehicle.type)
                    let new = Checklist(vehicleType: selectedVehicle.type,
                                        title: finalTitle,
                                        items: items,
                                        lastEdited: .now,
                                        vehicle: selectedVehicle)
                    onCreate(new)
                }
                .disabled(preselectedVehicle == nil && selectedVehicle == nil)
            }
        }
        .onAppear {
            if let preselectedVehicle {
                selectedVehicle = preselectedVehicle
            }
        }
    }
}

// Checklist editor (single source of truth)
struct ChecklistEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var checklist: Checklist

    private var sectionedItems: [(String, [ChecklistItem])] {
        let dict = Dictionary(grouping: checklist.items, by: { $0.section })
        return dict.keys.sorted().map { ($0, dict[$0] ?? []) }
    }

    private func binding(for item: ChecklistItem) -> Binding<ChecklistItem> {
        Binding(get: {
            checklist.items.first(where: { $0.id == item.id }) ?? item
        }, set: { updated in
            if let idx = checklist.items.firstIndex(where: { $0.id == item.id }) {
                checklist.items[idx] = updated
                checklist.lastEdited = .now
                try? modelContext.save()
            }
        })
    }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 4) {
                Text(checklist.title)
                    .font(.subheadline)
                    .lineLimit(2)
                Text("Auto-saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowSeparator(.hidden)

            ForEach(sectionedItems, id: \.0) { section, items in
                Section(section) {
                    ForEach(items) { item in
                        ChecklistItemRow(item: binding(for: item))
                    }
                }
            }
        }
        .navigationTitle("Checklist")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ChecklistItemRow: View {
    @Binding var item: ChecklistItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                Spacer()
                Menu {
                    Button("Not selected") { item.state = .notSelected }
                    Button("Selected") { item.state = .selected }
                    Button("Not applicable") { item.state = .notApplicable }
                    Button("Not OK") { item.state = .notOk }
                } label: {
                    Label(label(for: item.state), systemImage: icon(for: item.state))
                        .labelStyle(.titleAndIcon)
                }
            }
            if let note = item.note {
                Text(note).font(.footnote).foregroundStyle(.secondary)
            }
            Button("Add/Edit note") {
                // Simple inline toggle note for demo
                if item.note == nil { item.note = "" }
                else if item.note == "" { item.note = "Add details…" }
                else { item.note = nil }
            }
            .buttonStyle(.borderless)
        }
    }

    private func label(for state: ChecklistItemState) -> String {
        switch state {
        case .notSelected: return "Not selected"
        case .selected: return "Selected"
        case .notApplicable: return "Not applicable"
        case .notOk: return "Not OK"
        }
    }

    private func icon(for state: ChecklistItemState) -> String {
        switch state {
        case .notSelected: return "circle"
        case .selected: return "checkmark.circle.fill"
        case .notApplicable: return "minus.circle"
        case .notOk: return "xmark.octagon.fill"
        }
    }
}

#Preview { NavigationStack { ChecklistListView() } }
