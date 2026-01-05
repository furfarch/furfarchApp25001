import Foundation
import SwiftData

/// One-time migration to assign legacy (type-only) checklists to a specific Vehicle or Trailer.
///
/// Old behavior: `Checklist` was effectively global-per-type.
/// New behavior: checklists are unique to a specific vehicle (or trailer).
///
/// We assign each unowned checklist to the most recently edited matching owner.
/// If no owner exists, we leave it unassigned so no data is destroyed.
enum ChecklistOwnershipMigration {
    private static let defaultsKey = "didMigrateChecklistOwnership_v1"

    static func runIfNeeded(using container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: defaultsKey) else { return }

        let context = ModelContext(container)

        do {
            let vehicles = try context.fetch(FetchDescriptor<Vehicle>(sortBy: [SortDescriptor(\.lastEdited, order: .reverse)]))
            let trailers = try context.fetch(FetchDescriptor<Trailer>(sortBy: [SortDescriptor(\.lastEdited, order: .reverse)]))

            // Only legacy/unassigned checklists
            let unownedDescriptor = FetchDescriptor<Checklist>(predicate: #Predicate { $0.vehicle == nil && $0.trailer == nil })
            let unowned = try context.fetch(unownedDescriptor)

            if unowned.isEmpty {
                defaults.set(true, forKey: defaultsKey)
                return
            }

            for cl in unowned {
                switch cl.vehicleType {
                case .trailer:
                    if let t = trailers.first {
                        cl.trailer = t
                    }
                default:
                    if let v = vehicles.first(where: { $0.type == cl.vehicleType }) {
                        cl.vehicle = v
                    }
                }
            }

            try context.save()
            defaults.set(true, forKey: defaultsKey)
            print("MIGRATION: assigned \(unowned.count) legacy checklists to vehicles/trailers")
        } catch {
            // If something goes wrong, do NOT set the flag so we can retry.
            print("MIGRATION ERROR: checklist ownership migration failed: \(error)")
        }
    }
}
