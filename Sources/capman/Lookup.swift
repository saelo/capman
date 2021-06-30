import Foundation
import ArgumentParser
import LibInvesting

extension Capman {
    struct Lookup: ParsableCommand {
        static var configuration =
            CommandConfiguration(abstract: "Look up an asset by its ticker symbol.")

        @Argument(help: "The ticker to look up.")
        var ticker: String
        
        @OptionGroup
        var brokerOptions: BrokerOptions

        mutating func run() throws {
            let broker = try IBBroker(apiUrl: brokerOptions.apiurl)
            let results = try broker.lookupStock(ticker)
            Table(results).print()
        }
    }
}
