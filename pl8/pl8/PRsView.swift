import SwiftData
import SwiftUI
import PlateKit

/// PRs tab: every PR, tap to edit, swipe to delete, + to add (SPEC 2.4).
struct PRsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PersonalRecord.lift) private var records: [PersonalRecord]
    @State private var editing: PRTarget?

    var body: some View {
        NavigationStack {
            List {
                ForEach(records) { record in
                    Button {
                        editing = PRTarget(lift: record.lift, record: record)
                    } label: {
                        HStack {
                            Text(record.lift).font(.headline)
                            Spacer()
                            if let value = record.value {
                                Text("\(WeightUnit.trimmed(value)) \(record.unit.rawValue)")
                                    .font(.headline)
                                    .monospacedDigit()
                            } else {
                                Text("Add").foregroundStyle(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .tint(Theme.ink)
                    .listRowBackground(Theme.paper)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(records[index]) }
                    try? context.save()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("PRs")
            .toolbar {
                Button {
                    editing = PRTarget(lift: nil, record: nil)
                } label: {
                    Label("Add PR", systemImage: "plus")
                }
            }
            .sheet(item: $editing) { target in
                PREditor(lift: target.lift, record: target.record)
            }
        }
    }
}

/// Which PR the editor is open for; `lift == nil` means a new lift.
struct PRTarget: Identifiable {
    let lift: String?
    let record: PersonalRecord?
    var id: String { lift ?? "new" }
}

/// Sheet to enter or change one PR. Saving keeps the old value in its history.
struct PREditor: View {
    /// Nil: ask for the lift's name too.
    let lift: String?
    let record: PersonalRecord?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var records: [PersonalRecord]
    @State private var name = ""
    @State private var value: Double?
    @State private var unit: WeightUnit = .kg

    private var liftName: String { LiftNames.canonical(lift ?? name) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if lift == nil {
                        TextField("Lift, e.g. Push Press", text: $name)
                            .textInputAutocapitalization(.words)
                    }
                    TextField("PR", value: $value, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $unit) {
                        Text("kg").tag(WeightUnit.kg)
                        Text("lb").tag(WeightUnit.lb)
                    }
                    .pickerStyle(.segmented)
                }

                if let record, !record.history.isEmpty {
                    Section("Earlier") {
                        ForEach(record.history.sorted { $0.date > $1.date }) { entry in
                            LabeledContent(
                                "\(WeightUnit.trimmed(entry.value)) \(entry.unit.rawValue)",
                                value: entry.date.formatted(date: .abbreviated, time: .shortened)
                            )
                        }
                    }
                }
            }
            .navigationTitle(lift.map { "\($0) PR" } ?? "New PR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled((value ?? 0) <= 0 || liftName.isEmpty)
                }
            }
            .onAppear {
                value = record?.value
                unit = record?.unit ?? .kg
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let value, value > 0, !liftName.isEmpty else { return }
        // A "new" lift that already exists updates that PR instead of making a second one.
        if let target = record ?? records.first(where: { $0.lift == liftName }) {
            if target.value != value || target.unit != unit {
                target.update(value: value, unit: unit)
            }
        } else {
            let newRecord = PersonalRecord(lift: liftName)
            context.insert(newRecord)
            newRecord.update(value: value, unit: unit)
        }
        try? context.save()
    }
}
