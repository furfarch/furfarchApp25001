import SwiftUI
import SwiftData

struct SectionsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showingAbout = false
    @State private var showingAddVehicle = false

    @State private var showingExport = false
    @State private var exportScope: ExportScope = .all
    @State private var exportFormat: ExportFormat = .json

    @State private var shareURL: URL? = nil
    @State private var showingShareSheet = false

    @State private var isExporting = false
    @State private var exportErrorMessage: String? = nil

    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @Query(sort: \Trailer.lastEdited, order: .reverse) private var trailers: [Trailer]
    @Query(sort: \DriveLog.date, order: .reverse) private var logs: [DriveLog]
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var checklists: [Checklist]

    var body: some View {
        NavigationStack {
            VehiclesListView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Left: About
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingAbout = true } label: { Image(systemName: "info.circle") }
                            .accessibilityLabel("About")
                    }

                    // Right: Export + Add
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { showingExport = true } label: { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel("Export")
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
                .sheet(isPresented: $showingExport) {
                    NavigationStack {
                        Form {
                            Section("What to export") {
                                Picker("Scope", selection: $exportScope) {
                                    ForEach(ExportScope.allCases) { s in
                                        Text(s.title).tag(s)
                                    }
                                }
                            }

                            Section("Format") {
                                Picker("Format", selection: $exportFormat) {
                                    ForEach(ExportFormat.allCases) { f in
                                        Text(f.displayName).tag(f)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            if isExporting {
                                Section {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                        Text("Generating export…")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Section {
                                Button {
                                    guard !isExporting else { return }
                                    isExporting = true
                                    exportErrorMessage = nil

                                    DispatchQueue.main.async {
                                        do {
                                            let (name, data) = try ExportService.exportData(
                                                scope: exportScope,
                                                format: exportFormat,
                                                vehicles: vehicles,
                                                trailers: trailers,
                                                logs: logs,
                                                checklists: checklists
                                            )

                                            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                                            try data.write(to: url, options: [.atomic])
                                            shareURL = url
                                            showingShareSheet = true
                                        } catch {
                                            exportErrorMessage = "Export failed: \(error.localizedDescription)"
                                        }
                                        isExporting = false
                                    }
                                } label: {
                                    Label(isExporting ? "Generating…" : "Generate Export", systemImage: "doc.badge.plus")
                                }
                                .disabled(isExporting)
                            }
                        }
                        .navigationTitle("Export")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showingExport = false }
                                    .disabled(isExporting)
                            }
                        }
                        .alert("Export", isPresented: Binding(get: { exportErrorMessage != nil }, set: { if !$0 { exportErrorMessage = nil } })) {
                            Button("OK", role: .cancel) { exportErrorMessage = nil }
                        } message: {
                            Text(exportErrorMessage ?? "")
                        }
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    if let url = shareURL {
                        ShareSheet(items: [url])
                    }
                }
        }
    }
}

#Preview {
    SectionsView()
}
