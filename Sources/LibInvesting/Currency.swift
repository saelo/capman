import Foundation

public enum Currency: String, CaseIterable, Equatable, CustomStringConvertible {
    case aud = "AUD"
    case cad = "CAD"
    case chf = "CHF"
    case eur = "EUR"
    case gbp = "GBP"
    case hkd = "HKD"
    case jpy = "JPY"
    case mxn = "MXN"
    case nok = "NOK"
    case pln = "PLN"
    case rub = "RUB"
    case sek = "SEK"
    case usd = "USD"

    public var description: String {
        return self.rawValue
    }
}
