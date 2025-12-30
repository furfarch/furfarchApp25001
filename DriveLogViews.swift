import SwiftUI
import SwiftData

struct DriveLogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var vehicle: Vehicle?

    @State private var selectedVehicle: Vehicle?
    @State private var date: Date = .now
    @State private var reason: String = ""
    @State private var kmStart: String = ""
    @State private var kmEnd: String = ""
    @State private var notes: String = ""
    @State private var checklist: Checklist? = nil

    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var checklists: [Checklist]

    var body: some View {
        Form {
            Section("Vehicle") {
                if let vehicle {
                    HStack {
                        Text(vehicle.brandModel.isEmpty ? vehicle.type.displayName : vehicle.brandModel)
                        Spacer()
                        Text(vehicle.plate)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Picker("Vehicle", selection: $selectedVehicle) {
                        ForEach(vehicles) { v in
                            Text(v.brandModel.isEmpty ? v.type.displayName : v.brandModel)
                                .tag(Optional(v))
                        }
                    }
                }
            }

            Section("Details") {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                TextField("Reason", text: $reason)
                TextField("KM Start", text: $kmStart)
                    .keyboardType(.numberPad)
                TextField("KM End", text: $kmEnd)
                    .keyboardType(.numberPad)
                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section("Checklist") {
                if let checklist {
                    NavigationLink("Edit Checklist") { ChecklistEditorView(checklist: checklist) }
                } else {
                    NavigationLink("Select or Create Checklist") {
                        ChecklistPickerView(selected: $checklist)
                    }
                }
            }
        }
        .navigationTitle("Drive Log")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
    }

    private func save() {
        let v = vehicle ?? selectedVehicle
        guard let v else { return }
        let start = Int(kmStart) ?? 0
        let end = Int(kmEnd) ?? 0
        let log = DriveLog(vehicle: v, date: date, reason: reason, kmStart: start, kmEnd: end, notes: notes, checklist: checklist, lastEdited: .now)
        modelContext.insert(log)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save drive log: \(error)")
        }
    }
}

// Minimal Checklist picker/editor
struct ChecklistPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selected: Checklist?
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var checklists: [Checklist]
    @State private var creating = false
    @State private var title = ""

    var body: some View {
        Form {
            Section("Existing") {
                List(checklists, id: \.id) { c in
                    Button { selected = c } label: { Text(c.title) }
                }
            }
            Section("Create") {
                TextField("Title", text: $title)
                Button("Create") {
                    let c = Checklist(vehicleType: .car, title: title)
                    modelContext.insert(c)
                    try? modelContext.save()
                    selected = c
                }
            }
        }
        .navigationTitle("Checklists")
    }
}

struct ChecklistEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @State var checklist: Checklist

    var body: some View {
        List {
            ForEach(Array(checklist.items.enumerated()), id: \.element.id) { idx, item in
                HStack {
                    Button(action: {
                        var it = checklist.items[idx]
                        switch it.state {
                        case .notSelected: it.state = .selected
                        case .selected: it.state = .notApplicable
                        case .notApplicable: it.state = .notSelected
                        }
                        checklist.items[idx] = it
                        try? modelContext.save()
                    }) {
                        Image(systemName: checklist.items[idx].state == .selected ? "checkmark.circle.fill" : (checklist.items[idx].state == .notApplicable ? "minus.circle" : "circle"))
                    }
                    VStack(alignment: .leading) {
                        Text(checklist.items[idx].title)
                        if let note = checklist.items[idx].note { Text(note).font(.footnote).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Button(action: {
                        // show note editor
                    }) { Image(systemName: "ellipsis") }
                }
            }
        }
        .navigationTitle(checklist.title)
    }
}
