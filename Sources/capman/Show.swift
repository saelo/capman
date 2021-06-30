import Foundation
import ArgumentParser
import LibInvesting

extension Capman {
    struct Show: ParsableCommand {
        static var configuration =
            CommandConfiguration(abstract: "Fetch and display various information.")
        
        enum What: String, ExpressibleByArgument {
            case exchangerates
            case portfolio
            case orders
            case trades
        }
        
        @Argument(help: ArgumentHelp(
                    "What to show.",
                    discussion: "Options: exchangerates, portfolio, orders, trades"))
        var what: What
        
        @OptionGroup
        var brokerOptions: BrokerOptions

        mutating func run() throws {
            let broker = try IBBroker(apiUrl: brokerOptions.apiurl)
            print("Showing \(what)")
            switch what {
            case .exchangerates:
                let forex = try ExchangeRates.fetch()
                print("As of \(forex.date), \(Money(amount: 1, currency: forex.base)) equals:")
                for (currency, amount) in forex.rates {
                    print("\(Money(amount: amount, currency: currency))")
                }
            case .portfolio:
                let portfolio = try broker.fetchPortfolio()
                let table = Table(portfolio.positions)
                table.print()
            case .orders:
                let orders = try broker.fetchOrders()
                let table = Table(orders)
                table.print()
            case .trades:
                let trades = try broker.fetchTrades()
                let table = Table(trades)
                table.print()
            }
        }
    }
}
