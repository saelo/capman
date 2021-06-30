import Foundation

public struct Portfolio {
    public private(set) var positions = [Position]()
    
    public mutating func add(_ position: Position) {
        positions.append(position)
    }

    public func find(_ asset: Asset) -> Position? {
        for position in positions {
            if position.asset == asset {
                return position
            }
        }
        return nil
    }
}
