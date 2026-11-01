/// Chooses how to make each set's load so the session needs the fewest plates in its kit (SPEC 3.5).
///
/// Each set still uses its fewest plates (Will's choice, 2026-10-16: loading stays quick), but where two
/// combinations are equally short the session picks ones that share plates: 25+15, 25+10 and 25+20 a side need
/// four sizes, 20+15, 25+15 and 25+20 only three. The totals never change.
/// Among kits with the fewest plates: fewest plates to change between sets, then fewest plates on the bar.
/// `extraPlates` > 0 lets a set carry that many more plates than its fewest to shrink the kit further.
public enum KitOptimizer {
    /// `loads` in session order (warm-up first), rearranged. `plates` are the gym's sizes.
    public static func arrange(_ loads: [Load], plates: [Double], extraPlates: Int = 0) -> [Load] {
        let sizes = plates.map(units).filter { $0 > 0 }.sorted(by: >)
        guard !sizes.isEmpty else { return loads }
        let amounts = loads.map { units($0.perSide.reduce(0, +)) }

        // Every way to make each distinct amount with the fewest plates (+ `extraPlates`).
        var ways: [Int: [[Int]]] = [:]
        for amount in Set(amounts) where amount > 0 {
            let found = combinations(amount, sizes: sizes, extra: extraPlates)
            guard !found.isEmpty else { return loads }                         // can't make it: leave as is
            ways[amount] = found
        }

        // The smallest kits (plates per side of each size) that make every amount.
        let kits = smallestKits(amounts: Set(amounts).filter { $0 > 0 }.sorted(by: >), ways: ways, sizes: sizes)
        guard !kits.isEmpty else { return loads }

        // For each, the arrangement with the fewest changes; keep the best.
        var best: (cost: (Int, Int), arrangement: [[Int]])?
        for kit in kits {
            guard let arranged = fewestChanges(amounts: amounts, ways: ways, kit: kit, sizes: sizes) else { continue }
            if best == nil || arranged.cost < best!.cost { best = arranged }
        }
        guard let arrangement = best?.arrangement else { return loads }
        return zip(loads, arrangement).map { load, side in
            Load(total: load.total, perSide: side.map(weight), isLighterThanBar: load.isLighterThanBar)
        }
    }

    // MARK: - Private

    private static let quarter = 0.25
    private static func units(_ weight: Double) -> Int { Int((weight / quarter).rounded()) }
    private static func weight(_ units: Int) -> Double { Double(units) * quarter }

    /// Ways to make `amount`, heaviest first, using at most the fewest + `extra` plates.
    private static func combinations(_ amount: Int, sizes: [Int], extra: Int) -> [[Int]] {
        var fewest = Int.max
        var all: [[Int]] = []
        func walk(_ left: Int, from index: Int, _ current: [Int], limit: Int) {
            if left == 0 { all.append(current); fewest = min(fewest, current.count); return }
            guard current.count < limit, all.count < 400 else { return }
            for i in index..<sizes.count where sizes[i] <= left {
                walk(left - sizes[i], from: i, current + [sizes[i]], limit: limit)
            }
        }
        // First the fewest, then everything within `extra` of it.
        for limit in 1...60 {
            walk(amount, from: 0, [], limit: limit)
            if !all.isEmpty { break }
        }
        guard !all.isEmpty else { return [] }
        all = []
        walk(amount, from: 0, [], limit: fewest + extra)
        return all
    }

    private static func counts(_ side: [Int], sizes: [Int]) -> [Int] {
        sizes.map { size in side.filter { $0 == size }.count }
    }

    /// Branch and bound over the amounts (largest first): the kits with the fewest plates, up to 24 of them.
    private static func smallestKits(amounts: [Int], ways: [Int: [[Int]]], sizes: [Int]) -> [[Int]] {
        var bestSize = Int.max
        var kits: [[Int]] = []
        var visited = 0
        func search(_ index: Int, _ kit: [Int]) {
            visited += 1
            guard visited < 300_000 else { return }
            let size = kit.reduce(0, +)
            if size > bestSize { return }
            if index == amounts.count {
                if size < bestSize { bestSize = size; kits = [] }
                if kits.count < 24, !kits.contains(kit) { kits.append(kit) }
                return
            }
            // Cheapest additions first, so good kits are found early.
            let options = ways[amounts[index]]!.map { way -> [Int] in
                zip(kit, counts(way, sizes: sizes)).map { max($0, $1) }
            }.sorted { $0.reduce(0, +) < $1.reduce(0, +) }
            for next in options { search(index + 1, next) }
        }
        search(0, Array(repeating: 0, count: sizes.count))
        return kits
    }

    /// Per set, the way that fits `kit`, minimising (plates changed between sets, plates on the bar).
    private static func fewestChanges(amounts: [Int], ways: [Int: [[Int]]], kit: [Int], sizes: [Int]) -> (cost: (Int, Int), arrangement: [[Int]])? {
        let options: [[[Int]]] = amounts.map { amount in
            amount == 0 ? [[]] : ways[amount]!.filter { way in
                zip(counts(way, sizes: sizes), kit).allSatisfy { $0 <= $1 }
            }
        }
        guard options.allSatisfy({ !$0.isEmpty }) else { return nil }
        // Dynamic programming over the sets, starting from an empty bar.
        var costs: [(change: Int, plates: Int, path: [[Int]])] = [(0, 0, [])]
        var previous: [[Int]] = [[]]
        for choices in options {
            var next: [(change: Int, plates: Int, path: [[Int]])] = []
            for way in choices {
                var best: (change: Int, plates: Int, path: [[Int]])?
                for (j, before) in previous.enumerated() {
                    let change = SetChange(from: before.map(weight), to: way.map(weight))
                    let candidate = (costs[j].change + change.takeOff.count + change.add.count, costs[j].plates + way.count, costs[j].path + [way])
                    if best == nil || (candidate.0, candidate.1) < (best!.change, best!.plates) { best = candidate }
                }
                next.append(best!)
            }
            costs = next
            previous = choices
        }
        let end = costs.min { ($0.change, $0.plates) < ($1.change, $1.plates) }!
        return ((end.change, end.plates), end.path)
    }
}
