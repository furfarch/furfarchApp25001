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

    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @State private var selectedVehicle: Vehicle? = nil
    @State private var useTemplate = true

    var body: some View {
        Form {
            Section("Vehicle") {
                Picker("Vehicle", selection: $selectedVehicle) {
                    Text("Select...").tag(Vehicle?.none)
                    ForEach(vehicles) { v in
                        Text(v.brandModel.isEmpty ? v.type.displayName : v.brandModel)
                            .tag(Vehicle?.some(v))
                    }
                }
            }

            Section {
                Toggle("Pre-fill from template (if available)", isOn: $useTemplate)
            }
        }
        .navigationTitle("New Checklist")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    guard let selectedVehicle else { return }
                    let df = DateFormatter()
                    df.dateStyle = .medium
                    df.timeStyle = .short
                    let finalTitle = df.string(from: .now)

                    let items = useTemplate ? ChecklistTemplates.items(for: selectedVehicle.type) : []
                    let new = Checklist(vehicleType: selectedVehicle.type, title: finalTitle, items: items, lastEdited: .now)
                    onCreate(new)
                }
                .disabled(selectedVehicle == nil)
            }
        }
    }
}

// Checklist editor (moved here so all references compile)
struct ChecklistEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var checklist: Checklist

    var body: some View {
        List {
            ForEach(Array(checklist.items.enumerated()), id: \.element.id) { idx, _ in
                HStack {
                    Button(action: {
                        let original = checklist.items[idx]
                        let updated: ChecklistItem = {
                            var v = original
                            switch v.state {
                            case .notSelected: v.state = .selected
                            case .selected: v.state = .notApplicable
                            case .notApplicable: v.state = .notSelected
                            }
                            return v
                        }()
                        checklist.items[idx] = updated
                        checklist.lastEdited = .now
                        do { try modelContext.save() } catch { print("ERROR: failed saving checklist: \(error)") }
                    }) {
                        Image(systemName: checklist.items[idx].state == .selected ? "checkmark.circle.fill" : (checklist.items[idx].state == .notApplicable ? "minus.circle" : "circle"))
                    }
                    VStack(alignment: .leading) {
                        Text(checklist.items[idx].title)
                        if let note = checklist.items[idx].note { Text(note).font(.footnote).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Button(action: {
                        // toggle a simple inline note for now
                        let original = checklist.items[idx]
                        let updated: ChecklistItem = {
                            var v = original
                            if v.note == nil { v.note = "" }
                            else if v.note == "" { v.note = "Add details…" }
                            else { v.note = nil }
                            return v
                        }()
                        checklist.items[idx] = updated
                        checklist.lastEdited = .now
                        do { try modelContext.save() } catch { print("ERROR: failed saving checklist: \(error)") }
                    }) { Image(systemName: "ellipsis") }
                }
            }
        }
        .navigationTitle(checklist.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    checklist.lastEdited = .now
                    do {
                        try modelContext.save()
                    } catch {
                        print("ERROR: failed saving checklist: \(error)")
                    }
                }
            }
        }
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
        }
    }

    private func icon(for state: ChecklistItemState) -> String {
        switch state {
        case .notSelected: return "circle"
        case .selected: return "checkmark.circle.fill"
        case .notApplicable: return "minus.circle"
        }
    }
}

#Preview { NavigationStack { ChecklistListView() } }
