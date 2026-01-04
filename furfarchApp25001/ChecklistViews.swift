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

// Checklist editor (single implementation)
struct ChecklistEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var checklist: Checklist

    @State private var noteEditItemID: UUID? = nil
    @State private var noteDraft: String = ""

    private var grouped: [(section: String, indices: [Int])] {
        var dict: [String: [Int]] = [:]
        for (idx, item) in checklist.items.enumerated() {
            dict[item.section, default: []].append(idx)
        }
        return dict.keys.sorted().map { (section: $0, indices: dict[$0] ?? []) }
    }

    private func stateSymbol(for state: ChecklistItemState) -> String {
        switch state {
        case .notSelected: return "circle"
        case .selected: return "checkmark.circle.fill"
        case .notApplicable: return "minus.circle"
        case .notOk: return "xmark.octagon.fill"
        }
    }

    private func cycleItem(at idx: Int) {
        var updated = checklist.items[idx]
        updated.state.cycle()
        checklist.items[idx] = updated
        checklist.lastEdited = .now
        try? modelContext.save()
    }

    private func openNoteEditor(for idx: Int) {
        let item = checklist.items[idx]
        noteEditItemID = item.id
        noteDraft = item.note ?? ""
    }

    private func saveNote() {
        guard let id = noteEditItemID,
              let idx = checklist.items.firstIndex(where: { $0.id == id }) else {
            noteEditItemID = nil
            noteDraft = ""
            return
        }

        var updated = checklist.items[idx]
        let trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = trimmed.isEmpty ? nil : trimmed
        checklist.items[idx] = updated
        checklist.lastEdited = .now
        try? modelContext.save()

        noteEditItemID = nil
        noteDraft = ""
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

            ForEach(grouped, id: \.section) { group in
                Section(group.section) {
                    ForEach(group.indices, id: \.self) { idx in
                        HStack(spacing: 12) {
                            Image(systemName: stateSymbol(for: checklist.items[idx].state))
                                .imageScale(.large)
                                .foregroundStyle(checklist.items[idx].state == .notOk ? .red : .primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(checklist.items[idx].title)
                                if let note = checklist.items[idx].note, !note.isEmpty {
                                    Text(note)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                openNoteEditor(for: idx)
                            } label: {
                                Image(systemName: "note.text")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { cycleItem(at: idx) }
                    }
                }
            }
        }
        .navigationTitle("Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { noteEditItemID != nil }, set: { if !$0 { noteEditItemID = nil } })) {
            NavigationStack {
                Form {
                    Section("Note") {
                        TextEditor(text: $noteDraft)
                            .frame(minHeight: 140)
                    }
                }
                .navigationTitle("Item Note")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { noteEditItemID = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveNote() }
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
