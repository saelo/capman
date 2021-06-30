import Foundation
import LibInvesting

extension Asset: TableFormattable {
    static var headers: [String]? {
        ["Ticker", "Primary Exchange", "Description", "Conid", "Currency", "Listed Exchanges"]
    }

    func formatRow() -> [String] {
        return [ticker, primaryExchange, descr, String(conid), String(describing: currency), exchanges.joined(separator: ",")]
    }
}

extension Position: TableFormattable {
    static var headers: [String]? {
        ["Asset", "Quantity", "Share Price", "Market Value"]
    }

    func formatRow() -> [String] {
        let quantity = String(quantity)
        let sharePrice = String(describing: sharePrice)
        let marketValue = String(describing: self.quantity * self.sharePrice)
        return [asset.name, quantity, sharePrice, marketValue]
    }
}

extension Order: TableFormattable {
    static var headers: [String]? {
        ["Id", "Side", "Quantity", "Asset", "Type", "TiF", "Status", "Price", "Aux. Price"]
    }
    
    func formatRow() -> [String] {
        let id = id
        let side = String(describing: side)
        let quantity = String(totalQuantity)
        let asset = asset.name
        let type = String(describing: type)
        let tif = String(describing: tif)
        let status = String(describing: status)
        let price = price != nil ? String(describing: price!) : "-"
        let auxPrice = auxPrice != nil ? String(describing: auxPrice!) : "-"
        return [id, side, quantity, asset, type, tif, status, price, auxPrice]
    }
}

extension Trade: TableFormattable {
    static var headers: [String]? {
        ["OrderId", "Date", "Side", "Quantity", "Asset", "Price", "Exchange"]
    }
    
    func formatRow() -> [String] {
        let orderId = orderId
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = dateFormatter.string(from: date)
        let side = String(describing: side)
        let quantity = String(quantity)
        let asset = asset.name
        let price = String(describing: price)
        let exchange = exchange
        return [orderId, date, side, quantity, asset, price, exchange]
    }
}

