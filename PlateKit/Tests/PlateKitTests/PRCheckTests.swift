import Testing
@testable import PlateKit

@Suite("New PR (SPEC 3.8)")
struct PRCheckTests {
    @Test func heavierThanThePRInItsUnit() throws {
        // 200 lb lifted in a lb gym, PR 90 kg: 90.7 kg is a new PR, kept in kg.
        let value = try #require(PRCheck.newPR(lifted: 200, in: .lb, pr: 90, prUnit: .kg))
        #expect(abs(value - 90.718) < 0.001)
    }

    @Test func notHeavierIsNotAPR() {
        #expect(PRCheck.newPR(lifted: 198, in: .lb, pr: 90, prUnit: .kg) == nil)    // 89.8 kg
        #expect(PRCheck.newPR(lifted: 90, in: .kg, pr: 90, prUnit: .kg) == nil)     // equal isn't new
    }

    @Test func noPRYetMeansAnyLiftIsOne() {
        #expect(PRCheck.newPR(lifted: 60, in: .kg, pr: nil, prUnit: .kg) == 60)
        #expect(PRCheck.newPR(lifted: 0, in: .kg, pr: nil, prUnit: .kg) == nil)
    }

    @Test func askAfterTheLastSetOfALiftOrAPlusSet() {
        #expect(PRCheck.asksWhatWasLifted(isLastOfLift: true, isWarmUp: false, pctText: "75–78%"))
        #expect(PRCheck.asksWhatWasLifted(isLastOfLift: false, isWarmUp: false, pctText: "80%+"))
        #expect(!PRCheck.asksWhatWasLifted(isLastOfLift: false, isWarmUp: false, pctText: "80%"))
        #expect(!PRCheck.asksWhatWasLifted(isLastOfLift: false, isWarmUp: true, pctText: "≈66% 1RM"))
    }
}
