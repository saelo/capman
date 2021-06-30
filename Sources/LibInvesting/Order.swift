import Foundation

public struct Order: CustomStringConvertible {
    public let id: String
    public let side: OrderSide
    /// The total quantity
    public let totalQuantity: UInt
    /// How many shares have already been filled
    public var filledQuantity: UInt
    public let asset: Asset
    public let type: OrderType
    public let tif: OrderTiF
    public var status: OrderStatus
    // Price, for e.g. Limit orders
    public let price: Money?
    // Auxiliary price, for e.g. Market-if-Touched orders
    public let auxPrice: Money?

    init(id: String, side: OrderSide, totalQuantity: UInt, filledQuantity: UInt = 0, asset: Asset, type: OrderType, tif: OrderTiF, status: OrderStatus, price: Money? = nil, auxPrice: Money? = nil) {
        self.id = id
        self.side = side
        self.totalQuantity = totalQuantity
        self.filledQuantity = filledQuantity
        self.asset = asset
        self.type = type
        self.tif = tif
        self.status = status
        self.price = price
        self.auxPrice = auxPrice
    }

    public var description: String {
        "Order \(id) \(side.rawValue) \(totalQuantity) x \(asset.name) \(type.rawValue): \(status.rawValue)"
    }
}

public enum OrderType: String, CustomStringConvertible {
    // Market order
    case mkt = "MKT"
    // Limit order
    case lmt = "LMT"
    // Market-if-touched order
    case mit = "MIT"
    // Limit-if-touched order
    case lit = "LIT"
    // Stop-loss order
    case stp = "STP"
    // Stop-loss-limit order
    case stplmt = "STPLMT"
    // Trailing-stop order
    case trlstp = "TRLSTP"
    // Market-on-close order
    case moc = "MOC"
    // Limit-on-close order
    case loc = "LOC"
    // Relative order (https://www.interactivebrokers.com/php/whiteLabel/Making_Trades/Create_Order_Types/relative.htm)
    case rel = "REL"
    // Midprice order (https://www.interactivebrokers.com/en/software/tws/usersguidebook/ordertypes/midprice.htm)
    case mid = "MID"

    public var description: String {
        return self.rawValue
    }
    
}

public enum OrderStatus: String, CustomStringConvertible {
    // The order was not yet submitted to the broker
    case none = "None"
    // The broker has received the order, but hasn't submitted it to an exchange yet
    case pendingSubmit = "PendingSubmit"
    // The order was received by the broker but isn't ready for submission yet, for example
    // because the market is currently closed or because the price for a Market-if-Touched
    // order wasn't yet reached.
    case preSubmitted = "PreSubmitted"
    // The order was submitted to an exchange
    case submitted = "Submitted"
    // The order has filled
    case filled = "Filled"
    // The order is scheduled to be cancelled
    case pendingCancel = "PendingCancel"
    // The order was cancelled
    case cancelled = "Cancelled"

    public var description: String {
        return self.rawValue
    }
}

public enum OrderSide: String, CustomStringConvertible {
    case buy = "BUY"
    case sell = "SELL"

    public var description: String {
        return self.rawValue
    }
}

public enum OrderTiF: String, CustomStringConvertible {
    // End-of-day
    case day = "DAY"
    // Good-til-cancel
    case gtc = "GTC"
    // Good-til-date
    case gtd = "GTD"

    public var description: String {
        return self.rawValue
    }
}
