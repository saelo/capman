import Foundation

/// An investable asset.
///
/// An asset is uniquely identified through its InteractiveBrokers contract ID.
/// Furthermore, the (ticker, exchange) pair should also uniquely identify an asset.
/// However, an ISIN does not uniquely identify an asset, as for example the same ETF
/// (same ISIN) may trade with different denominated currencies on different exchanges.
public struct Asset: Equatable, CustomStringConvertible {
    public let ticker: String
    // The (sometimes arbitrarily chosen) primary exchange for this asset.
    // This can also be a trading system such as the National Market System in the US.
    public let primaryExchange: String
    // All exchanges that this asset trades on. Will always include the primary exchange.
    public let exchanges: [String]
    public let descr: String
    public let conid: UInt
    public let currency: Currency

    init(ticker: String, primaryExchange: String? = nil, exchanges: [String], description: String, conid: UInt, currency: Currency) {
        precondition(!exchanges.isEmpty)
        precondition(primaryExchange == nil || exchanges.contains(primaryExchange!))
        self.ticker = ticker
        self.primaryExchange = primaryExchange ?? exchanges[0]
        self.exchanges = exchanges
        self.descr = description
        self.conid = conid
        self.currency = currency
    }

    public var name: String {
        ticker + "." + primaryExchange
    }

    public var description: String {
        "\(name) (IB contract \(conid)): \(descr)"
    }
 
    public static func == (lhs: Asset, rhs: Asset) -> Bool {
        assert(lhs.conid != rhs.conid || lhs.ticker == rhs.ticker)
        assert(lhs.conid != rhs.conid || lhs.currency == rhs.currency)
        return lhs.conid == rhs.conid
    }
}
