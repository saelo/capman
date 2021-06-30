import Foundation

class IBAPI {
    private let api: RESTApi
    private let accountId: String

    init(_ apiUrl: String) throws {
        self.api = RESTApi(apiUrl + "/v1/api/")
        let status: StatusReply = try api.post("iserver/auth/status")
        guard status.connected else {
            throw Err.apiError("IBAPI not connected")
        }
        guard status.authenticated else {
            throw Err.apiError("IBAPI not authenticated")
        }
        let accounts: AccountsReply = try api.get("iserver/accounts")
        self.accountId = accounts.selectedAccount
    }
    
    // Asset class enum returned by various endpoints.
    enum AssetClass: String, Decodable {
        case stk = "STK"
        case cash = "CASH"
    }
    
    /// https://www.interactivebrokers.com/api/doc.html#tag/Session/paths/~1sso~1validate/get
    struct SsoValidateReply: Decodable {
        let USER_NAME: String
        let USER_ID: UInt
        let RESULT: Bool
        let AUTH_TIME: UInt
        let IP: String
    }
    func validateSso() throws -> SsoValidateReply {
        return try api.get("sso/validate")
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Account/paths/~1iserver~1accounts/get
    struct AccountsReply: Decodable {
        let accounts: [String]
        let selectedAccount: String
    }
    func accounts() throws -> AccountsReply {
        return try api.get("iserver/accounts")
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Trades/paths/~1iserver~1account~1trades/get
    struct TradesReply: Decodable {
        let execution_id: String
        let symbol: String
        let side: OrderSide
        let order_description: String
        let trade_time: String
        let size: UInt
        let price: String
        let submitter: String?
        let exchange: String
        let comission: Double?
        let net_amount: Double
        let account: String
        let company_name: String
        let contract_description_1: String
        let sec_type: AssetClass
        let conid: UInt
        let clearing_id: String
        let clearing_name: String
        let order_ref: String?
    }
    func trades() throws -> [TradesReply] {
        return try api.get("iserver/account/trades")
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Order/paths/~1iserver~1account~1orders/get
    struct OrdersReply: Decodable {
        struct OrderReply: Decodable {
            let conid: UInt
            let orderId: UInt
            let cashCcy: Currency
            // Quantity outstanding and total quantity separated by a forward slash
            let sizeAndFills: String
            let orderDesc: String
            let ticker: String
            let listingExchange: String
            let remainingQuantity: UInt
            let filledQuantity: UInt
            let companyName: String
            let status: OrderStatus
            let orderType: OrderType
            let order_ref: String?      // Only available for orders created through the API
            let side: OrderSide
            let timeInForce: OrderTiF
            let price: String?          // Only available for LMT orders and similar
            let auxPrice: String?       // Only available for e.g. MIT orders
        }
        let orders: [OrderReply]
        let snapshot: Bool
    }
    func orders() throws -> OrdersReply {
        return try api.get("iserver/account/orders")
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Order/paths/~1iserver~1account~1{accountId}~1order/post
    private struct PlaceOrderRequest: Encodable {
        let accId: String
        let conid: UInt
        let orderType: OrderType
        let price: Double?
        let side: OrderSide
        let cOID: String
        let tif: OrderTiF
        let quantity: Double
        let outsideRTH: Bool
        let useAdaptive: Bool
    }
    // Placing an order either returns a question that must be answered, or an order confirmation.
    struct PlaceOrderConfirmation {
        let order_id: String
        let order_status: OrderStatus
        let local_order_id: String
    }
    struct PlaceOrderQuestion {
        let id: String
        let message: [String]
    }
    enum PlaceOrderReply: Decodable {
        case question(PlaceOrderQuestion)
        case confirmation(PlaceOrderConfirmation)
        
        init(from decoder: Decoder) throws {
            enum Keys: CodingKey {
                case order_id
                case order_status
                case local_order_id
                case id
                case message
            }
            let container = try decoder.container(keyedBy: Keys.self)
            if let order_id = try container.decodeIfPresent(String.self, forKey: .order_id) {
                let c = PlaceOrderConfirmation(order_id: order_id,
                                               order_status: try container.decode(OrderStatus.self, forKey: .order_status),
                                               local_order_id: try container.decode(String.self, forKey: .local_order_id))
                self = .confirmation(c)
            } else {
                let q = PlaceOrderQuestion(id: try container.decode(String.self, forKey: .id),
                                           message: try container.decode([String].self, forKey: .message))
                self = .question(q)
            }
        }
    }

    func placeOrder(orderId: String, conid: UInt, type: OrderType, side: OrderSide, quantity: UInt, price: Double? = nil, tif: OrderTiF) throws -> [PlaceOrderReply] {
        precondition(type == .mkt ? price == nil : price != nil)
        let request = PlaceOrderRequest(accId: String(accountId),
                                        conid: conid,
                                        orderType: type,
                                        price: price,
                                        side: side,
                                        cOID: orderId,
                                        tif: tif,
                                        quantity: Double(quantity),
                                        outsideRTH: false,
                                        useAdaptive: false)
        return try api.post("iserver/account/\(accountId)/order", data: request)
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Order/paths/~1iserver~1reply~1{replyid}/post
    struct ConfirmRequest: Encodable {
        let confirmed = true
    }
    func confirm(replyId: String) throws -> [PlaceOrderReply] {
        return try api.post("iserver/reply/\(replyId)", data: ConfirmRequest())
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Contract/paths/~1iserver~1secdef~1search/post
    private struct SearchRequest: Encodable {
        let symbol: String
        let name: Bool = false
        // let secType: String
    }
    struct SearchReply: Decodable {
        let conid: UInt
        let companyName: String
        let symbol: String
        // The exchange
        let description: String
    }
    func search(_ symbol: String) throws -> [SearchReply] {
        return try api.post("iserver/secdef/search", data: SearchRequest(symbol: symbol))
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Contract/paths/~1iserver~1contract~1{conid}~1info/get
    struct ContractInfoReply: Decodable {
        struct ContractRules: Decodable {
            let algoEligible: Bool
            let orderTypes: [OrderType]
            let ibAlgoTypes: [String]
            let orderTypesOutside: [OrderType]
            let defaultSize: Double
            let sizeIncrement: Double
            let tifTypes: [String]    // TODO turn into enum
            let defaultTIF: String    // TODO turn into enum
            let preview: Bool
            let increment: Double
        }
        let con_id: UInt
        let company_name: String
        let exchange: String
        let valid_exchanges: String
        let local_symbol: String
        let instrument_type: AssetClass
        let currency: Currency
        let rules: ContractRules?
        
        func parseExchanges() -> [String] {
            return valid_exchanges.split(separator: ",").filter { $0 != "SMART" }.map(String.init)
        }
        func parsePrimaryExchange() -> String {
            if exchange != "SMART" {
                return exchange
            }
            return parseExchanges()[0]
        }
    }
    func contractInfo(for conid: UInt) throws -> ContractInfoReply {
        return try api.get("iserver/contract/\(conid)/info")
    }
    
    func contractInfoAndRules(for conid: UInt, orderSide: OrderSide) throws -> ContractInfoReply {
        let params = ["isBuy": String(orderSide == .buy)]
        return try api.get("iserver/contract/\(conid)/info-and-rules", params: params)
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Session/paths/~1iserver~1auth~1status/post
    struct StatusReply: Decodable {
        let authenticated: Bool
        let connected: Bool
        let competing: Bool
    }
    func status() throws -> StatusReply {
        return try api.post("iserver/auth/status")
    }

    /// https://www.interactivebrokers.com/api/doc.html#tag/Session/paths/~1iserver~1reauthenticate/post
    struct ReauthenticateReply: Decodable {
        let message: String
    }
    func reauthenticate() throws -> StatusReply {
        return try api.post("iserver/reauthenticate")
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Market-Data/paths/~1iserver~1marketdata~1snapshot/get
    enum MarketDataField: String, CodingKey, CaseIterable {
        case lastPrice = "31"
        case bid       = "84"
        case ask       = "86"
    }

    struct MarketDataReply: Decodable {
        let conid: UInt
        let data: [MarketDataField: String]
        
        init(from decoder: Decoder) throws {
            // This is a bit weird, but ok
            enum Helper: CodingKey {
                case conid
            }
            self.conid = try decoder.container(keyedBy: Helper.self).decode(UInt.self, forKey: .conid)
            
            let container = try decoder.container(keyedBy: MarketDataField.self)
            var fields = [MarketDataField: String]()
            for field in MarketDataField.allCases {
                if let value = try container.decodeIfPresent(String.self, forKey: field) {
                    fields[field] = value
                }
            }
            
            self.data = fields
        }
    }
    func marketData(for conids: [UInt], fields: [MarketDataField]) throws -> [MarketDataReply] {
        let params = [
            "conids": conids.map({ String($0) }).joined(separator: ","),
            "fields": fields.map({ $0.rawValue }).joined(separator: ",")
        ]
        return try api.get("iserver/marketdata/snapshot", params: params)
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Contract/paths/~1trsrv~1futures/get
    struct TrsrvFuturesReply: Decodable {
        let symbol: String
        let conid: UInt
        let underlyingConid: UInt
        let expirationDate: UInt
        let ltd: UInt
    }
    func trsrvFutures(symbols: [String]) throws -> [String: [TrsrvFuturesReply]] {
        let params = ["symbols": symbols.joined(separator: ",")]
        return try api.get("trsrv/futures", params: params)
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Contract/paths/~1trsrv~1stocks/get
    struct TrsrvStocksReply: Decodable {
        struct Contract: Codable {
            let conid: UInt
            let exchange: String
        }
        let name: String
        let assetClass: AssetClass
        let contracts: [Contract]
    }
    func trsrvStocks(symbols: [String]) throws -> [String: [TrsrvStocksReply]] {
        let params = ["symbols": symbols.joined(separator: ",")]
        return try api.get("trsrv/stocks", params: params)
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Portfolio/paths/~1portfolio~1accounts/get
    struct PortfolioAccountsReply: Decodable {
        let id: String
        let accountId: String
        let accountTitle: String
        let accountStatus: Int
        let currency: String
        let type: String
    }
    func portfolioAccounts() throws -> [PortfolioAccountsReply] {
        return try api.get("portfolio/accounts")
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Portfolio/paths/~1portfolio~1{accountId}~1positions~1invalidate/post
    struct InvalidatePortfolioCacheReply: Decodable {}
    func invalidatePortfolioCache() throws -> InvalidatePortfolioCacheReply {
        return try api.post("/portfolio/\(accountId)/positions/invalidate")
    }
    
    /// https://interactivebrokers.com/api/doc.html#tag/Portfolio/paths/~1portfolio~1{accountId}~1positions~1{pageId}/get
    ///
    /// Must call portfolioAccounts() prior to this endpoint.
    struct PortfolioPositionsReply: Decodable {
        let conid: UInt
        // Only sometimes seems to be present?
        let ticker: String?
        // Cash assets don't have a listingExchange field. Also apparently sometimes missing for stocks...
        let listingExchange: String?
        // Seems to also be the ticker
        let contractDesc: String
        let name: String?
        let position: Double
        let mktPrice: Double
        let mktValue: Double
        let currency: Currency
        let avgCost: Double
        let avgPrice: Double
        let assetClass: AssetClass
    }
    func portfolioPositions() throws -> [PortfolioPositionsReply] {
        var page = 0
        var positions = [PortfolioPositionsReply]()
        while true {
            let reply: [PortfolioPositionsReply] = try api.get("portfolio/\(accountId)/positions/\(page)")
            if reply.isEmpty {
                return positions
            }
            positions += reply
            page += 1
        }
    }
}

extension Currency: Codable {}

extension OrderType: Codable {
    public func encode(to encoder: Encoder) throws {
        let value: String
        switch self {
        case .mkt:
            value = "MKT"
        case .lmt:
            value = "LMT"
        case .stp:
            value = "STP"
        case .stplmt:
            value = "STP_LIMIT"
        case .mit,
             .lit,
             .trlstp,
             .moc,
             .loc,
             .rel,
             .mid:
            fatal("Unsupported order type \(self)")
        }
        try value.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        let value = try String(from: decoder)
        switch value {
        case "LMT",
             "Limit",
             "limit":
            self = .lmt
        case "MKT",
             "Market",
             "market":
            self = .mkt
        case "MIT",
             "mit":
            self = .mit
        case "LIT",
             "lit":
            self = .lit
        case "STP",
             "Stop",
             "stop":
            self = .stp
        case "STPLMT",
             "StopLimit",
             "stop_limit":
            self = .stplmt
        case "trailing_stop":
            self = .trlstp
        case "marketonclose":
            self = .moc
        case "limitonclose":
            self = .loc
        case "relative":
            self = .rel
        case "midprice":
            self = .mid
        default:
            fatal("Unknown order type received from IB API: \(value)")
        }
    }
}

extension OrderStatus: Decodable {
    public init(from decoder: Decoder) throws {
        let value = try String(from: decoder)
        switch value {
        case "PendingSubmit":
            self = .pendingSubmit
        case "PreSubmitted":
            self = .preSubmitted
        case "Submitted":
            self = .submitted
        case "Filled":
            self = .filled
        case "PendingCancel":
            self = .pendingCancel
        case "Cancelled":
            self = .cancelled
        default:
            fatal("Unknown order status received from IB API: \(value)")
        }
    }
}

extension OrderSide: Codable {
    public func encode(to encoder: Encoder) throws {
        let value: String
        switch self {
        case .buy:
            value = "BUY"
        case .sell:
            value = "SELL"
        }
        try value.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        let value = try String(from: decoder)
        switch value {
        case "BUY",
             "B":
            self = .buy
        case "SELL",
             "S":
            self = .sell
        default:
            fatal("Unknown order side received from IB API: \(value)")
        }
    }
}

extension OrderTiF: Codable {
    public func encode(to encoder: Encoder) throws {
        let value: String
        switch self {
        case .day:
            value = "DAY"
        case .gtc:
            value = "GTC"
        case .gtd:
            value = "GTD"
        }
        try value.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        let value = try String(from: decoder)
        switch value {
        case "DAY",
             "CLOSE":
            self = .day
        case "GTC":
            self = .gtc
        default:
            fatal("Unknown order TiF received from IB API: \(value)")
        }
    }
}
