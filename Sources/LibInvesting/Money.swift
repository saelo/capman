import Foundation

public struct Money: Comparable, CustomStringConvertible {
    public private(set) var amount: Double
    public let currency: Currency
    
    public init(amount: Double, currency: Currency) {
        self.amount = amount
        self.currency = currency
    }
    
    public var description: String {
        return String(format: "%.2f %@", amount, currency.rawValue)
    }
    
    public func rounded(to minIncrement: Double) -> Money {
        return Money(amount: (amount / minIncrement).rounded() * minIncrement, currency: currency)
    }
    
    public static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency)
        return lhs.amount < rhs.amount
    }
    
    public static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency)
        return Money(amount: lhs.amount + rhs.amount, currency: lhs.currency)
    }
    
    public static func += (lhs: inout Money, rhs: Money) {
        precondition(lhs.currency == rhs.currency)
        lhs.amount += rhs.amount
    }
    
    public static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency)
        return Money(amount: lhs.amount - rhs.amount, currency: lhs.currency)
    }
    
    public static func -= (lhs: inout Money, rhs: Money) {
        precondition(lhs.currency == rhs.currency)
        lhs.amount -= rhs.amount
    }
    
    public static func * (lhs: Money, rhs: Double) -> Money {
        return Money(amount: lhs.amount * rhs, currency: lhs.currency)
    }
    
    public static func * <I: BinaryInteger>(lhs: Money, rhs: I) -> Money {
        return lhs * Double(rhs)
    }

    public static func * (lhs: Double, rhs: Money) -> Money {
        return Money(amount: lhs * rhs.amount, currency: rhs.currency)
    }
    
    public static func * <I: BinaryInteger>(lhs: I, rhs: Money) -> Money {
        return Double(lhs) * rhs
    }
    
    public static func / (lhs: Money, rhs: Money) -> Double {
        precondition(lhs.currency == rhs.currency)
        return lhs.amount / rhs.amount
    }
    
    public static func / (lhs: Money, rhs: Double) -> Money {
        return Money(amount: lhs.amount / rhs, currency: lhs.currency)
    }
}

// Convenience Money constructors
public func USD(_ amount: Double) -> Money {
    return Money(amount: amount, currency: .usd)
}

public func EUR(_ amount: Double) -> Money {
    return Money(amount: amount, currency: .eur)
}

public func CHF(_ amount: Double) -> Money {
    return Money(amount: amount, currency: .chf)
}
