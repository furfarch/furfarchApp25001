import SwiftUI
import SwiftData

struct DriveLogListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DriveLog.date, order: .reverse) private var logs: [DriveLog]
    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]

    @State private var showingNew = false

    var body: some View {
        List {
            if logs.isEmpty {
                ContentUnavailableView("No drive logs", systemImage: "car", description: Text("Tap + to add your first log."))
            } else {
                ForEach(logs) { log in
                    NavigationLink(value: log) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(log.vehicle.brandModel.isEmpty ? log.vehicle.type.displayName : log.vehicle.brandModel)
                                    .font(.headline)
                                if let plate = log.vehicle.plate.isEmpty ? nil : log.vehicle.plate {
                                    Text(plate).foregroundStyle(.secondary)
                                }
                            }
                            Text(log.date, style: .date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !log.reason.isEmpty {
                                Text(log.reason).lineLimit(1)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteLogs)
            }
        }
        .navigationTitle("Drive Log")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: { Image(systemName: "plus") }
                    .disabled(vehicles.isEmpty)
            }
        }
        .navigationDestination(for: DriveLog.self) { log in
            DriveLogEditorView(log: log)
        }
        .sheet(isPresented: $showingNew) {
            if let firstVehicle = vehicles.first {
                let newLog = DriveLog(vehicle: firstVehicle)
                DriveLogEditorView(log: newLog, isNew: true)
            } else {
                Text("Please add a vehicle first.").padding()
            }
        }
    }

    private func deleteLogs(at offsets: IndexSet) {
        for index in offsets { context.delete(logs[index]) }
        try? context.save()
    }
}

struct DriveLogEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var allChecklists: [Checklist]

    @State var log: DriveLog
    var isNew: Bool = false

    @State private var showChecklistRunner = false

    private var filteredChecklists: [Checklist] {
        allChecklists.filter { $0.vehicleType == log.vehicle.type }
    }

    var body: some View {
        Form {
            Section("Vehicle & Date") {
                Picker("Vehicle", selection: $log.vehicle) {
                    ForEach(vehicles) { v in
                        Text(v.brandModel.isEmpty ? v.type.displayName : v.brandModel)
                            .tag(v as Vehicle?)
                    }
                }
                DatePicker("Date", selection: $log.date, displayedComponents: [.date, .hourAndMinute])
            }

            Section("Details") {
                TextField("Reason", text: $log.reason)
                HStack {
                    TextField("Km start", value: $log.kmStart, format: .number)
                        .keyboardType(.numberPad)
                    TextField("Km end", value: $log.kmEnd, format: .number)
                        .keyboardType(.numberPad)
                }
                if log.kmEnd >= log.kmStart { Text("Distance: \(log.kmEnd - log.kmStart) km").foregroundStyle(.secondary) }
                TextField("Notes", text: $log.notes, axis: .vertical)
            }

            Section("Checklist") {
                Picker("Template", selection: Binding(get: { log.checklist }, set: { log.checklist = $0 })) {
                    Text("None").tag(nil as Checklist?)
                    ForEach(filteredChecklists) { cl in
                        Text(cl.title).tag(cl as Checklist?)
                    }
                }
                if let cl = log.checklist {
                    Button {
                        showChecklistRunner = true
                    } label: {
                        Label("Run Checklist (\(cl.items.count) items)", systemImage: "checklist")
                    }
                }
            }
        }
        .navigationTitle(isNew ? "New Drive Log" : "Edit Drive Log")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button("Save") { saveAndClose() }.bold() }
        }
        .sheet(isPresented: $showChecklistRunner) {
            if let cl = log.checklist {
                ChecklistRunnerView(checklist: cl)
            }
        }
        .onChange(of: log.vehicle) { _, _ in
            // Clear checklist when vehicle changes to avoid mismatch
            log.checklist = nil
        }
    }

    private func saveAndClose() {
        log.lastEdited = .now
        if isNew { context.insert(log) }
        try? context.save()
        dismiss()
    }
}

struct ChecklistRunnerView: View {
    @Environment(\.dismiss) private var dismiss
    @State var checklist: Checklist

    var body: some View {
        NavigationStack {
            List {
                ForEach(sectionedItems.keys.sorted(), id: \.self) { section in
                    Section(section) {
                        ForEach(items(in: section)) { item in
                            ChecklistItemRow(item: binding(for: item))
                        }
                    }
                }
            }
            .navigationTitle(checklist.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.bold() }
            }
        }
    }

    private var sectionedItems: [String: [ChecklistItem]] {
        Dictionary(grouping: checklist.items, by: { $0.section })
    }

    private func items(in section: String) -> [ChecklistItem] {
        sectionedItems[section] ?? []
    }

    private func binding(for item: ChecklistItem) -> Binding<ChecklistItem> {
        Binding(get: {
            checklist.items.first(where: { $0.id == item.id }) ?? item
        }, set: { updated in
            if let idx = checklist.items.firstIndex(where: { $0.id == item.id }) {
                checklist.items[idx] = updated
            }
        })
    }
}

struct DriveLogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var vehicle: Vehicle?

    @State private var date: Date = .now
    @State private var reason: String = ""
    @State private var kmStart: String = ""
    @State private var kmEnd: String = ""
    @State private var notes: String = ""

    var body: some View {
        Form {
            if let v = vehicle {
                Section("Vehicle") { HStack { Text(v.brandModel.isEmpty ? v.type.displayName : v.brandModel); Spacer(); Text(v.plate).foregroundStyle(.secondary) } }
            }
            Section("Details") {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                TextField("Reason", text: $reason)
                TextField("KM Start", text: $kmStart).keyboardType(.numberPad)
                TextField("KM End", text: $kmEnd).keyboardType(.numberPad)
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("Drive Log")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } } }
    }

    private func save() {
        let v = vehicle
        guard let v else { return }
        let start = Int(kmStart) ?? 0
        let end = Int(kmEnd) ?? 0
        let log = DriveLog(vehicle: v, date: date, reason: reason, kmStart: start, kmEnd: end, notes: notes, checklist: nil, lastEdited: .now)
        modelContext.insert(log)
        try? modelContext.save()
        dismiss()
    }
}

struct ChecklistPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selected: Checklist?
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var checklists: [Checklist]

    var body: some View {
        List {
            ForEach(checklists) { c in
                Button { selected = c } label: { Text(c.title) }
            }
        }
        .navigationTitle("Checklists")
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
                // Simple inline prompt for note
                promptForNote()
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

    private func promptForNote() {
        // This simplistic approach toggles through preset notes for demo purposes.
        // Replace with a proper editor if desired.
        if item.note == nil { item.note = "" }
        else if item.note == "" { item.note = "Add details…" }
        else { item.note = nil }
    }
}

#Preview { NavigationStack { DriveLogListView() } }
