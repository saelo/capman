import Foundation

public class IBBroker: Broker {    
    private let api: IBAPI
    private let sessionId: String
    private var orderCounter = 0
    
    // While the contractInfoAndRules endpoint provides an "increment" value for a contract,
    // that doesn't (always) seem to match the minimum price increment enforced by e.g. the
    // limit order endpoint, leading to orders being rejected. Additionally, we usually display
    // prices with only 2 decimal places. Due to that, prices passed to methods of this
    // class are currently simply rounded using a fixed minimum price increment of one hundreth
    // of the respective currency.
    private let minPriceIncrement = 0.01
    
    public init(apiUrl: String) throws {
        self.api = try IBAPI(apiUrl)
        
        self.sessionId = String(format: "%8X", UInt.random(in: 0x10000000...0xffffffff))
        
        // Retrieve and display the currently active account.
        // Calling these two endpoints is also necessary here since they must be invoked prior to many other endpoints.
        let accounts = try api.accounts()
        let portfolioAccounts = try api.portfolioAccounts()
        let selectedAccount = accounts.selectedAccount
        guard let account = portfolioAccounts.first(where: { $0.accountId == selectedAccount }) else {
            fatal("API returned inconsistent account information")
        }
        info("brokerage session active for \(account.accountTitle) (\(account.accountId)), \(account.type.lowercased())")
        
        // It seems to help to also call these endpoints once when starting a new session
        let _ = try api.orders()
        let _ = try api.trades()
    }
    
    public func lookupStock(_ requestTicker: String) throws -> [Asset] {
        let reply = try api.trsrvStocks(symbols: [requestTicker])
        assert(reply.count <= 1)
        var results = [Asset]()
        for (replyTicker, securities) in reply {
            precondition(replyTicker == requestTicker)
            for security in securities {
                precondition(security.assetClass == .stk)
                for contract in security.contracts {
                    let asset = try makeAsset(for: contract.conid, ticker: replyTicker, primaryExchange: contract.exchange)
                    results.append(asset)
                }
            }
        }
        return results
    }
    
    public func lookupStock(_ ticker: String, listedAt exchange: String, denominatedIn currency: Currency) throws -> Asset? {
        let candidates = try lookupStock(ticker)
        let result = candidates.filter { $0.exchanges.contains(exchange.uppercased()) && $0.currency == currency }
        if result.count > 1 {
            fatal("ambigious stock lookup \(ticker) @ \(exchange) in \(currency): \(result)")
        }
        return result.first
    }
    
    public func fetchMarketDataSnapshot(for asset: Asset) throws -> MarketDataSnapshot? {
        let r = try api.marketData(for: [asset.conid], fields: [.lastPrice, .bid, .ask])
        assert(r.count == 1)
        let d = r[0]
        guard let lastPrice = Double(d.data[.lastPrice] ?? ""),
              let bid = Double(d.data[.bid] ?? ""),
              let ask = Double(d.data[.ask] ?? "") else {
            return nil
        }
        return MarketDataSnapshot(lastPrice: Money(amount: lastPrice, currency: asset.currency),
                                  bid: Money(amount: bid, currency: asset.currency),
                                  ask: Money(amount: ask, currency: asset.currency))
    }

    public func fetchPortfolio() throws -> Portfolio {
        var portfolio = Portfolio()
        for p in try api.portfolioPositions() {
            // Ignore cash positions
            guard p.assetClass == .stk else { continue }

            let asset = try makeAsset(for: p.conid, ticker: p.ticker ?? p.contractDesc, primaryExchange: p.listingExchange, currency: p.currency)

            let sharePrice = Money(amount: p.mktPrice, currency: p.currency)
            guard let quantity = UInt(exactly: p.position) else {
                fatal("fractional shares are not currently supported")
            }
            let position = Position(asset: asset, quantity: quantity, sharePrice: sharePrice)
            portfolio.add(position)
        }
        
        return portfolio
    }
    
    public func fetchOrders() throws -> [Order] {
        let reply = try api.orders()
        return try reply.orders.map { order in
            let totalQuantity = order.filledQuantity + order.remainingQuantity
            let asset = try makeAsset(for: order.conid, ticker: order.ticker, primaryExchange: order.listingExchange, currency: order.cashCcy)
            var price: Money?, auxPrice: Money? = nil
            if let amountStr = order.price {
                guard let amount = Double(amountStr) else { fatal("Received invalid price from API: \(amountStr)") }
                price = Money(amount: amount, currency: order.cashCcy)
            }
            if let amountStr = order.auxPrice {
                guard let amount = Double(amountStr) else { fatal("Received invalid auxPrice from API: \(amountStr)") }
                auxPrice = Money(amount: amount, currency: order.cashCcy)
            }
            
            return Order(id: order.order_ref ?? "ib_\(order.orderId)",
                         side: order.side,
                         totalQuantity: totalQuantity,
                         filledQuantity: order.filledQuantity,
                         asset: asset,
                         type: order.orderType,
                         tif: order.timeInForce,
                         status: order.status,
                         price: price,
                         auxPrice: auxPrice)
        }
    }
    
    public func fetchTrades() throws -> [Trade] {
        let reply = try api.trades()
        
        return try reply.map { trade in
            guard let priceAmount = Double(trade.price) else {
                fatal("invalid price received from trades endpoint: \(trade.price)")
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HH:mm:ss"
            guard let date = dateFormatter.date(from: trade.trade_time) else {
                fatal("invalid date received from trades endpoint: \(trade.trade_time)")
            }

            let asset = try makeAsset(for: trade.conid, ticker: trade.symbol)
            
            let price = Money(amount: priceAmount, currency: asset.currency)
            return Trade(orderId: trade.order_ref ?? "N/A", date: date, asset: asset, side: trade.side, quantity: trade.size, price: price, exchange: trade.exchange)
        }
    }
    
    public func submitMarketOrder(for asset: Asset, side: OrderSide, quantity: UInt, tif: OrderTiF) throws -> Order {
        var order = Order(id: nextOrderId(),
                          side: side,
                          totalQuantity: quantity,
                          asset: asset,
                          type: .mkt,
                          tif: tif,
                          status: .none)

        try submitOrder(&order)
        return order
    }

    public func submitLimitOrder(for asset: Asset, side: OrderSide, quantity: UInt, price: Money, tif: OrderTiF) throws -> Order {
        precondition(price.currency == asset.currency)
        
        var order = Order(id: nextOrderId(),
                          side: side,
                          totalQuantity: quantity,
                          asset: asset,
                          type: .lmt,
                          tif: tif,
                          status: .none,
                          price: price.rounded(to: minPriceIncrement))

        try submitOrder(&order)
        return order
    }
    
    private func makeAsset(for conid: UInt, ticker: String? = nil, primaryExchange: String? = nil, currency: Currency? = nil) throws -> Asset {
        let info = try api.contractInfo(for: conid)

        // Some consistency checks, first for the ticker ...
        if ticker != nil && ticker != info.local_symbol {
            // This does seem to happen for some contracts, so warn once to inform the user, then continue
            warnOnce("ticker mismatch: \(ticker!) vs \(info.local_symbol) for contract \(conid). Using \(info.local_symbol)")
        }
        
        // ... then the exchange ...
        let primaryExchange = primaryExchange ?? info.parsePrimaryExchange()
        var exchanges = info.parseExchanges()
        if !exchanges.contains(primaryExchange) {
            // One example where this happens is the National Market System (NMS)
            // which is used as the primary exchange by the API, but does not refer to
            // any specific exchange (rather, it is apparently a system for trading
            // equities in the US, which includes the major exchanges), and thus isn't
            // in the exchanges list.
            exchanges = [primaryExchange] + exchanges
        }
        
        // ... and finally the currency. This one has to be an exact match
        precondition(currency == nil || currency == info.currency)
        
        return Asset(ticker: info.local_symbol,
                     primaryExchange: primaryExchange,
                     exchanges: exchanges,
                     description: info.company_name,
                     conid: info.con_id,
                     currency: info.currency)
    }
    
    private func submitOrder(_ order: inout Order) throws {
        precondition(order.status == .none)
        precondition(order.filledQuantity == 0)

        guard confirm("About to submit order: \(order.side.rawValue) \(order.type.rawValue) \(order.totalQuantity) x \(order.asset.ticker)\(order.price != nil ? " @ \(order.price!)" : "")") else {
            order.status = .cancelled
            return
        }

        let reply = try api.placeOrder(orderId: order.id,
                                       conid: order.asset.conid,
                                       type: order.type,
                                       side: order.side,
                                       quantity: order.totalQuantity,
                                       price: order.price?.amount,
                                       tif: order.tif)

        order.status = try handleOrderQuestions(reply: reply)
        if order.status == .filled {
            order.filledQuantity = order.totalQuantity
        }
    }
    
    private func nextOrderId() -> String {
        let id = "cpm_" + sessionId + "_" + String(orderCounter)
        orderCounter += 1
        return id
    }

    private func handleOrderQuestions(reply: [IBAPI.PlaceOrderReply]) throws -> OrderStatus {
        var pendingReplies = reply
        while let reply = pendingReplies.popLast() {
            switch reply {
            case .confirmation(let c):
                assert(pendingReplies.isEmpty)
                return c.order_status
            case .question(let q):
                // Prompt the user
                for message in q.message {
                    guard confirm("IB Question:\n" + message) else { return .cancelled }
                }

                // Send confirmation to backend and append replies
                pendingReplies += try api.confirm(replyId: q.id)
            }
        }

        fatalError("Unreachable")
    }
    
    private func confirm(_ question: String) -> Bool {
        print(question)
        while true {
            print("Confirm? (y/n)")
            if let response = readLine() {
                switch response.lowercased() {
                case "y":
                    return true
                case "n":
                    return false
                default:
                    // Try again
                    continue
                }
            } else {
                return false
            }
        }
    }
}
