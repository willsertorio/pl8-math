import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import PlateKit

/// Pick a screenshot of PRs: Vision reads it, PRParser finds the lines, and they're saved (SPEC 3.7).
/// If some lines have no unit, it asks once for the whole screenshot.
struct PRScreenshotPicker<Label: View>: View {
    /// Called with how many PRs were saved.
    var onDone: (Int) -> Void = { _ in }
    @ViewBuilder let label: () -> Label

    @Environment(\.modelContext) private var context
    @Query private var records: [PersonalRecord]
    @State private var photo: PhotosPickerItem?
    @State private var isReading = false
    @State private var waitingForUnit: [PREntry] = []
    @State private var askUnit = false
    @State private var message: String?
    @State private var savedCount = 0
    /// What Vision read, to check (and copy) when a screenshot doesn't come through right.
    @State private var readText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PhotosPicker(selection: $photo, matching: .images) {
                label()
            }
            .buttonStyle(.plain)

            if isReading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Reading…")
                }
            }
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
            if let readText {
                DisclosureGroup("Show the text it read") {
                    Text(readText)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.footnote)
            }
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .onChange(of: photo) { _, item in
            guard let item else { return }
            photo = nil
            Task { await read(item) }
        }
        .confirmationDialog("Are these PRs in kg or lb?", isPresented: $askUnit, titleVisibility: .visible) {
            Button("Kilograms") { save(PRParser.assumingUnit(.kg, for: waitingForUnit)) }
            Button("Pounds") { save(PRParser.assumingUnit(.lb, for: waitingForUnit)) }
        }
    }

    private func read(_ item: PhotosPickerItem) async {
        isReading = true
        message = nil
        defer { isReading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                message = "Couldn't open that image."
                return
            }
            // Rows joined first (a box app's list puts the weight beside the lift); the plain lines if that finds nothing.
            var text = try await TextReader.lines(in: data, joiningRows: true).joined(separator: "\n")
            var entries = PRParser.parse(text)
            if entries.isEmpty {
                text = try await TextReader.lines(in: data).joined(separator: "\n")
                entries = PRParser.parse(text)
            }
            readText = text
            if entries.isEmpty {
                message = "No PRs found. Lines should look like \"Back Squat 140 kg\"."
            } else if PRParser.needsUnit(entries) {
                waitingForUnit = entries
                askUnit = true
            } else {
                save(entries)
            }
        } catch {
            message = "Couldn't read that image: \(error.localizedDescription)"
        }
    }

    /// Updates PRs that exist (keeping the old value in history) and adds new lifts.
    private func save(_ entries: [PREntry]) {
        for entry in entries {
            let unit = entry.unit ?? .kg
            if let record = Planner.record(for: entry.lift, in: records) {
                if record.value != entry.value || record.unit != unit {
                    record.update(value: entry.value, unit: unit)
                }
            } else {
                let record = PersonalRecord(lift: entry.lift)
                context.insert(record)
                record.update(value: entry.value, unit: unit)
            }
        }
        try? context.save()
        waitingForUnit = []
        message = "Saved \(entries.count) PR\(entries.count == 1 ? "" : "s")."
        savedCount += 1
        onDone(entries.count)
    }
}

/// The PR list: tap to edit, swipe to delete, and a screenshot import on top.
struct PRList: View {
    @Binding var editing: PRTarget?

    @Environment(\.modelContext) private var context
    @Query(sort: \PersonalRecord.lift) private var records: [PersonalRecord]

    var body: some View {
        List {
            Section {
                PRScreenshotPicker {
                    Label("Upload a screenshot", systemImage: "photo.on.rectangle")
                        .font(.headline)
                }
                .listRowBackground(Theme.paper)
            }

            Section {
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .sheet(item: $editing) { target in
            PREditor(lift: target.lift, record: target.record)
        }
    }
}
