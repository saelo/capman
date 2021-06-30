import Foundation

/// Positions are the basis of a portfolio.
///
/// A position is a number of shares of an asset together with the current share price.
public class Position: CustomStringConvertible {
    public let asset: Asset
    public let quantity: UInt
    public let sharePrice: Money

    public init(asset: Asset, quantity: UInt, sharePrice: Money) {
        precondition(asset.currency == sharePrice.currency)
        self.asset = asset
        self.quantity = quantity
        self.sharePrice = sharePrice
    }

    public var description: String {
        "\(asset.name): \(quantity) @ \(sharePrice)"
    }
}
