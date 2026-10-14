/// Where you are in a session (SPEC 2.3): the current set, its number within its group, and the group's sets for the
/// progress dots. The warm-up is its own group, separate from the lift it leads into.
public struct SessionCursor: Sendable {
    public struct Item: Hashable, Sendable {
        public let blockIndex: Int
        public let isWarmUp: Bool
        public let isDone: Bool

        public init(blockIndex: Int, isWarmUp: Bool, isDone: Bool) {
            self.blockIndex = blockIndex
            self.isWarmUp = isWarmUp
            self.isDone = isDone
        }
    }

    /// "Set 2 of 5"
    public struct Position: Hashable, Sendable {
        public let number: Int
        public let count: Int
    }

    public let items: [Item]

    public init(items: [Item]) {
        self.items = items
    }

    /// The first set not done yet; nil when everything is done.
    public var current: Int? {
        items.firstIndex { !$0.isDone }
    }

    public var isFinished: Bool {
        !items.isEmpty && current == nil
    }

    /// Indices of the sets in the same group (warm-up, or one lift's working sets).
    public func group(of index: Int) -> [Int] {
        guard items.indices.contains(index) else { return [] }
        let item = items[index]
        return items.indices.filter { items[$0].blockIndex == item.blockIndex && items[$0].isWarmUp == item.isWarmUp }
    }

    public func position(of index: Int) -> Position {
        let group = group(of: index)
        return Position(number: (group.firstIndex(of: index) ?? 0) + 1, count: group.count)
    }

    /// The last working set of a lift: where SPEC 2.3 step 6 asks "How much did you lift?".
    public func isLastOfLift(_ index: Int) -> Bool {
        guard items.indices.contains(index), !items[index].isWarmUp else { return false }
        return group(of: index).last == index
    }
}
