import Foundation
import ArgumentParser
import LibInvesting

extension Currency: ExpressibleByArgument {}

extension Money: ExpressibleByArgument {
    public init?(argument: String) {
        // Try parsing with format "500 USD"
        var parts = argument.split(separator: " ")
        if parts.count == 1 {
            // Try parsing with format "500USD"
            guard let i = argument.firstIndex(where: { !$0.isNumber }) else { return nil }
            parts = [argument[..<i], argument[i...]]
        }
        guard parts.count == 2 else { return nil }

        guard let amount = Double(parts[0]) else { return nil }
        guard let currency = Currency(rawValue: String(parts[1])) else { return nil }
        self.init(amount: amount, currency: currency)
    }
}
