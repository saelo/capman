import XCTest
import class Foundation.Bundle

@testable import LibInvesting

final class ForexTests: XCTestCase {
    func testBasicCurrencyConversion() {
        let forex = ExchangeRates(base: .usd,
                                  rates: [.usd: 1.0, .eur: 2.0, .chf: 0.5],
                                  date: "2050-01-02")
        
        XCTAssertEqual(forex.convert(USD(10), to: .eur), EUR(20))
        XCTAssertEqual(forex.convert(USD(10), to: .usd), USD(10))
        XCTAssertEqual(forex.convert(USD(10), to: .chf), CHF(5))
    }
    
    static var allTests = [
        ("testBasicCurrencyConversion", testBasicCurrencyConversion),
    ]
}
