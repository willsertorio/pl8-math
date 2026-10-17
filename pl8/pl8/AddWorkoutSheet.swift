import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import PlateKit

/// "Add today's workout": scan the whiteboard, upload a screenshot, or type it in (SPEC 2.2 step 3).
struct AddWorkoutSheet: View {
    var onAdded: (Workout) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [PhotosPickerItem] = []
    @State private var showScanner = false
    @State private var isReading = false
    @State private var message: String?
    @State private var readCount = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add today's workout").font(Theme.heading)

                if isReading {
                    HStack(spacing: 16) {
                        PlateSpinner()
                        Text("Reading the workout…").font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    Button { showScanner = true } label: {
                        OptionRow(title: "Scan the whiteboard", systemImage: "camera")
                    }
                    .buttonStyle(.plain)
                    .disabled(!WhiteboardScanner.isAvailable)
                    .opacity(WhiteboardScanner.isAvailable ? 1 : 0.4)

                    VStack(alignment: .leading, spacing: 6) {
                        PhotosPicker(selection: $photos, maxSelectionCount: 5, selectionBehavior: .ordered, matching: .images) {
                            OptionRow(title: "Upload screenshots", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.plain)
                    }

                    NavigationLink {
                        TypedWorkoutForm(onSave: onAdded)
                    } label: {
                        OptionRow(title: "Type it in", systemImage: "keyboard")
                    }
                    .buttonStyle(.plain)
                }

                if let message {
                    Text(message).font(.footnote).foregroundStyle(.orange)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(Theme.ink)
            .background(Theme.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sensoryFeedback(.success, trigger: readCount)
        .fullScreenCover(isPresented: $showScanner) {
            WhiteboardScanner { image in
                Task { await read { [try await TextReader.lines(in: image).joined(separator: "\n")] } }
            }
        }
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            photos = []
            Task {
                // Several screenshots of one workout are read in order and joined (SPEC 3.6 rule 8).
                await read {
                    var texts: [String] = []
                    for item in items {
                        if let data = try await item.loadTransferable(type: Data.self) {
                            texts.append(try await TextReader.lines(in: data).joined(separator: "\n"))
                        }
                    }
                    return texts
                }
            }
        }
    }

    /// Reads each screenshot's text, keeps the strength work, saves it as today's workout.
    private func read(_ screenshots: () async throws -> [String]) async {
        isReading = true
        message = nil
        defer { isReading = false }
        do {
            let texts = try await screenshots()
            let text = texts.joined(separator: "\n\n")
            let blocks = WorkoutParser.parse(screenshots: texts)
            guard !blocks.isEmpty else {
                message = "No strength work found. Try again, or type it in."
                return
            }
            let workout = Workout(sourceText: text, blocks: blocks)
            context.insert(workout)
            try? context.save()
            readCount += 1
            onAdded(workout)
        } catch {
            message = "Couldn't read that: \(error.localizedDescription)"
        }
    }
}

/// "Type it in", simple form: lift, sets, reps, one % (SPEC Open decision 3). Add as many lifts as needed.
struct TypedWorkoutForm: View {
    var onSave: (Workout) -> Void

    private struct Draft {
        let lift: String
        let sets: Int
        let reps: Int
        let target: Target
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \PersonalRecord.lift) private var records: [PersonalRecord]
    @State private var drafts: [Draft] = []
    @State private var lift = ""
    @State private var sets = 5
    @State private var reps = 3
    @State private var percent = ""

    private var target: Target? { Target(parsing: percent) }
    private var currentIsValid: Bool { !LiftNames.canonical(lift).isEmpty && target != nil }

    var body: some View {
        Form {
            if !drafts.isEmpty {
                Section("Added") {
                    ForEach(Array(drafts.enumerated()), id: \.offset) { index, draft in
                        Text("\(letter(index)). \(LiftNames.canonical(draft.lift)) · \(draft.sets) × \(draft.reps) @ \(draft.target.text)")
                    }
                    .onDelete { drafts.remove(atOffsets: $0) }
                }
            }

            Section("Lift") {
                TextField("Lift, e.g. Back Squat", text: $lift)
                    .textInputAutocapitalization(.words)
                if lift.isEmpty, !records.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(records) { record in
                                Chip(isOn: false, action: { lift = record.lift }) {
                                    Text(record.lift)
                                }
                                .fixedSize()
                            }
                        }
                        .padding(2)
                    }
                }
                Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                Stepper("Reps: \(reps)", value: $reps, in: 1...20)
                TextField("% of 1RM: 75-78, 80 or 80+", text: $percent)
                    .keyboardType(.numbersAndPunctuation)
                if !percent.isEmpty, target == nil {
                    Text("Try 75-78, 80 or 80+").font(.footnote).foregroundStyle(.orange)
                }
            }

            Section {
                Button("Add another lift") { addCurrent() }
                    .disabled(!currentIsValid)
            }
        }
        .navigationTitle("Type it in")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: sets)
        .sensoryFeedback(.selection, trigger: reps)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(drafts.isEmpty && !currentIsValid)
            }
        }
    }

    private func letter(_ index: Int) -> String {
        String(UnicodeScalar(UInt8(65 + index % 26)))
    }

    private func addCurrent() {
        guard let target, currentIsValid else { return }
        drafts.append(Draft(lift: lift, sets: sets, reps: reps, target: target))
        lift = ""
        percent = ""
    }

    private func save() {
        if currentIsValid { addCurrent() }
        let blocks = drafts.enumerated().map { index, draft in
            StrengthBlock.typed(letter: letter(index), lift: draft.lift, sets: draft.sets, reps: draft.reps, target: draft.target)
        }
        let text = blocks.map { "\($0.letter). \($0.sets.count)x\($0.sets.first?.reps ?? 0) \($0.name) @\($0.sets.first?.target?.text ?? "")" }
            .joined(separator: "\n")
        let workout = Workout(sourceText: text, blocks: blocks)
        context.insert(workout)
        try? context.save()
        onSave(workout)
    }
}
