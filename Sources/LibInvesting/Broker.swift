import Foundation

public protocol Broker {
    func lookupStock(_ ticker: String) throws -> [Asset]
    func lookupStock(_ ticker: String, listedAt exchange: String, denominatedIn currency: Currency) throws -> Asset?

    func fetchMarketDataSnapshot(for asset: Asset) throws -> MarketDataSnapshot?

    func fetchPortfolio() throws -> Portfolio
    
    func fetchOrders() throws -> [Order]
    
    func fetchTrades() throws -> [Trade]
            
    func submitMarketOrder(for asset: Asset, side: OrderSide, quantity: UInt, tif: OrderTiF) throws -> Order
    
    func submitLimitOrder(for asset: Asset, side: OrderSide, quantity: UInt, price: Money, tif: OrderTiF) throws -> Order
}

public struct MarketDataSnapshot {
    public let lastPrice: Money
    public let bid: Money
    public let ask: Money
}
