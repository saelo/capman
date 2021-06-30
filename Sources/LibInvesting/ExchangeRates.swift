import Foundation

public struct ExchangeRates {
    public let base: Currency
    public let rates: [Currency: Double]
    public let date: String

    public static func fetch() throws -> ExchangeRates {
        struct ExchangeRatesResponse: Codable {
            let rates: [String: Double]
            let date: String
            let success: Bool
        }
        let api = RESTApi("https://api.exchangerate.host")
        let response: ExchangeRatesResponse = try api.get("latest?base=USD")
        if !response.success {
            throw Err.apiError("Request to https://api.exchangerate.host/latest did not succeed: \(response)")
        }
        
        var rates: [Currency: Double] = [:]
        for (currencyName, value) in response.rates {
            if let currency = Currency(rawValue: currencyName) {
                rates[currency] = value
            }
        }
        
        return ExchangeRates(base: .usd, rates: rates, date: response.date)
    }

    init(base: Currency, rates: [Currency: Double], date: String) {
        assert(rates[base] == 1.0)
        self.base = base
        self.rates = rates
        self.date = date
    }

    public func convert(_ input: Money, to targetCurrency: Currency) -> Money {
        guard let fromRate = rates[input.currency] else { fatal("Missing exchange rate for \(input.currency)") }
        guard let toRate = rates[targetCurrency] else { fatal("Missing exchange rate for \(targetCurrency)") }
        let amount = input.amount * toRate / fromRate
        return Money(amount: amount, currency: targetCurrency)
    }
}
