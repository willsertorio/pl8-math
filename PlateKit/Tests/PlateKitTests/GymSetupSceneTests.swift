import Testing
@testable import PlateKit

@Suite("Gym setup in 3D: the room follows the answers (SPEC 2.2, M6 step 3)")
struct GymSetupSceneTests {
    @Test func everySizeOfTheUnitHasAPegWhetherOrNotTheGymHasIt() {
        // The prototype builds a peg per plate size and pops piles on and off them.
        let kgPegs = PropModels.shelf(unit: .kg).filter { if case .dark = $0.tone { true } else { false } }
        let lbPegs = PropModels.shelf(unit: .lb).filter { if case .dark = $0.tone { true } else { false } }
        #expect(kgPegs.count == 2 + 2 * Plate.catalog(.kg).count)            // 2 rails, a peg and its base per size
        #expect(lbPegs.count == 2 + 2 * Plate.catalog(.lb).count)
    }

    @Test func aPileStaysOnItsPegWhateverElseIsOwned() {
        let twenty = Plate.find(20, .kg)!
        let alone = PropModels.pile(twenty)
        #expect(alone.parts.count == 5 * 4)                                   // 5 plates, 4 parts each
        let centre = alone.pivot
        #expect(abs(centre.x - (RoomLayout.room.minX + 0.12)) < 0.01)         // by the wall, where the first plate hangs
        #expect(PropModels.pile(twenty).pivot == centre)
        // Parts are around the pivot, so the pile can pop from there.
        let xs = alone.parts.flatMap { $0.mesh.positions.map(\.x) }
        #expect((xs.min() ?? -9) > -0.01)
    }

    @Test func shelfPartsAreRailsPlusTheGymsPiles() {
        let parts = PropModels.parts(for: .shelf, plates: [Plate.find(20, .kg)!])
        #expect(parts.filter { $0.tone == .picture(.plateFace(Plate.find(20, .kg)!)) }.count == 5)
    }

    @Test func lighterBarsAreShorterAndThinner() {
        #expect(PropModels.barScale(20, unit: .kg) == SIMD2(1, 1))
        #expect(PropModels.barScale(15, unit: .kg) == SIMD2(0.914, 0.88))
        #expect(PropModels.barScale(10, unit: .kg) == SIMD2(0.8, 0.8))
        #expect(PropModels.barScale(35, unit: .lb) == SIMD2(0.914, 0.88))
        let full = PropModels.parts(for: .rack, plates: [], barWeight: 20, unit: .kg)
        let technique = PropModels.parts(for: .rack, plates: [], barWeight: 10, unit: .kg)
        func barLength(_ parts: [PropPart]) -> Float {
            let xs = parts.filter { if case .metal = $0.tone { true } else { false } }.flatMap { $0.mesh.positions.map(\.x) }
            return (xs.max() ?? 0) - (xs.min() ?? 0)
        }
        #expect(abs(barLength(technique) - barLength(full) * 0.8) < 0.001)
        // Only the sleeves get shorter: the collars stay where the full bar's are, outside the J-hooks.
        #expect(PropModels.barX(0.67, length: 0.8) == 0.67)
        #expect(abs(PropModels.barX(1.1, length: 0.914) - 1.1 * 0.914) < 0.0001)
    }

    @Test func bakingAGroupGivesItsOwnPiecesAndShadows() {
        let flag = SceneBake.bake(PropModels.parts(for: .flag, plates: [], gymName: "SS"),
                                  placement: PropModels.placement(for: .flag), wall: nil)
        #expect(flag.contains { if case .picture(.flag("SS"), _) = $0.paint { true } else { false } })
        #expect(flag.contains { piece in piece.walls == [.back] })            // its shadow lies on the back wall
        // The whole room still comes out the same way.
        #expect(SceneBake.pieces(plates: Plate.catalog(.kg), gymName: "SS").count > 50)
    }
}

@Suite("Baking the room without the props the setup changes")
struct StaticBakeTests {
    @Test func leavesOutWhatTheSetupBakesItself() {
        let all = SceneBake.pieces(plates: Plate.catalog(.kg), gymName: "SS")
        let rest = SceneBake.pieces(plates: Plate.catalog(.kg), gymName: "SS", except: [.flag, .rack, .shelf])
        #expect(!rest.contains { if case .picture(.flag, _) = $0.paint { true } else { false } })
        #expect(!rest.contains { if case .picture(.plateFace, _) = $0.paint { true } else { false } })
        #expect(rest.map(\.mesh.triangleCount).reduce(0, +) < all.map(\.mesh.triangleCount).reduce(0, +))
    }
}
