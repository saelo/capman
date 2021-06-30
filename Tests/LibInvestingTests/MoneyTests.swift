import XCTest
import class Foundation.Bundle

@testable import LibInvesting

final class MoneyTests: XCTestCase {
    func testMoneyArithmetic() {
        let m1 = USD(20)
        let m2 = USD(10)
        
        XCTAssertEqual(m1 + m2, USD(30))
        XCTAssertEqual(m1 - m2, USD(10))
        XCTAssertEqual(m1 * 5, USD(100))
        XCTAssertEqual(m1 / m2, 2.0)
        XCTAssertEqual(m1 / 5, USD(4))
        XCTAssertEqual(0 * m1, USD(0))
    }
        
    static var allTests = [
        ("testMoneyArithmetic", testMoneyArithmetic),
    ]
}
