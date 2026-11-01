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
                HStack(spacing: 12) {
                    PlateSpinner()
                    Text("Reading your PRs…").font(Theme.text(17))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            if let message {
                Text(message).font(Theme.text(15)).padding(.horizontal, 16)
            }
            if let readText {
                DisclosureGroup("Show the text it read") {
                    Text(readText)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(Theme.text(13))
                .padding(.horizontal, 16)
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
        message = nil
        savedCount += 1
        onDone(entries.count)
    }
}

/// The PR list, like the prototype's prList: one row per lift with its PR in grey (or "Add"); tap to change it.
/// Below: + Add PR and a screenshot import.
struct PRList: View {
    @Query(sort: \PersonalRecord.lift) private var records: [PersonalRecord]
    @State private var editing: PRTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(records) { record in
                Button { editing = PRTarget(lift: record.lift, record: record) } label: {
                    ListRow(label: record.lift,
                            value: record.value.map { "\(WeightUnit.trimmed($0)) \(record.unit.rawValue)" } ?? "Add",
                            valueIsHint: record.value == nil, chevron: true)
                }
                .buttonStyle(.pressable)
            }
            Button { editing = PRTarget(lift: nil, record: nil) } label: {
                ListRow(label: "+  Add PR")
            }
            .buttonStyle(.pressable)
            PRScreenshotPicker {
                OptionRow(title: "Upload a screenshot", icon: .photo, tag: "Fastest")
            }
            .padding(.top, 8)
        }
        .sheet(item: $editing) { target in
            PREditor(lift: target.lift, record: target.record)
        }
    }
}
