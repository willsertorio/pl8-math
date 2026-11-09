import Testing
@testable import PlateKit

/// A beta tester's workout (Fixtures/workouts/2026-11-07): nothing was read. Expected results decided with Will
/// on 2026-11-09 (Fixtures/README.md).
@Suite("Workout 07/11: letters with ), Every 2:00, bullets, a complex's % on its own line")
struct Workout0711Tests {
    @Test func everyStrengthBlockIsRead() throws {
        let blocks = WorkoutParser.parse(try fixture("2026-11-07.screen.txt"))
        #expect(blocks.map(\.letter) == ["A", "B", "C", "E"])
    }

    @Test func aComplexClimbsFromTheHeadersLift() throws {
        let a = try #require(WorkoutParser.parse(try fixture("2026-11-07.screen.txt")).first)
        #expect(a.name == "Snatch Complex")
        #expect(a.prLift == "Snatch")
        #expect(a.format == "E2MOM")
        #expect(a.sets.map(\.reps) == [1, 1, 1, 1, 1, 1])
        #expect(targets(a) == [60, 64, 68, 72, 76, 80].map { .single($0) })
        #expect(a.note == "1 Snatch Pull + 1 Hang Snatch + 1 Squat Snatch")
        #expect(!a.pctMissing)
    }

    @Test func aBulletedLineUnderEveryTwoMinutes() throws {
        let b = WorkoutParser.parse(try fixture("2026-11-07.screen.txt"))[1]
        #expect(b.name == "Squat Snatch")
        #expect(b.format == "E2MOM")
        #expect(b.sets.map(\.reps) == [2, 2, 2, 2, 2])
        #expect(targets(b) == Array(repeating: .range(75, 80), count: 5))
    }

    @Test func aLoadIsNotAProgression() throws {
        let c = WorkoutParser.parse(try fixture("2026-11-07.screen.txt"))[2]
        #expect(c.name == "Clean & Jerk Complex")
        #expect(c.prLift == "Clean & Jerk")
        #expect(targets(c) == Array(repeating: .range(70, 80), count: 6))
        #expect(c.note == "1 Clean + 1 Hang Clean + 1 Split Jerk")
    }

    @Test func emomWithAMinuteMark() throws {
        let e = WorkoutParser.parse(try fixture("2026-11-07.screen.txt"))[3]
        #expect(e.label == "FINAL BOSS")
        #expect(e.name == "Clean & Jerk")
        #expect(e.format == "EMOM")
        #expect(targets(e) == Array(repeating: .range(75, 80), count: 6))
    }

    @Test func theSameWithoutBullets() {
        // Vision may drop the "*": the % line must not be joined onto the last movement.
        let text = "A) SNATCH COMPLEX\nEvery 2:00 x 3 sets\n1 Snatch Pull\n1 Squat Snatch\nProgression: 70-80%"
        let a = WorkoutParser.parse(text).first
        #expect(a?.prLift == "Snatch")
        #expect(a.map(targets) == [70, 75, 80].map { .single($0) })
    }

    @Test func movementsWithoutAPercentStayIgnored() {
        // Technique work (Fixtures 05/10 block A) is still not strength.
        #expect(WorkoutParser.parse("A) WARM-UP\nEvery 2:00 x 3 sets\n* 3 Snatch Deadlift\n* 3 Hang Snatch").isEmpty)
    }
}
