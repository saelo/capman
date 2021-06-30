import Foundation

public struct Trade {
    public let orderId: String
    public let date: Date
    public let asset: Asset
    public let side: OrderSide
    public let quantity: UInt
    public let price: Money
    public let exchange: String
    
    init(orderId: String, date: Date, asset: Asset, side: OrderSide, quantity: UInt, price: Money, exchange: String) {
        self.orderId = orderId
        self.date = date
        self.asset = asset
        self.side = side
        self.quantity = quantity
        self.price = price
        self.exchange = exchange
    }
    
    public var description: String {
        "Trade \(orderId) \(side.rawValue) \(quantity) x \(asset.name) @ \(price)"
    }
}
