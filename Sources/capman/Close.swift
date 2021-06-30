import Foundation
import ArgumentParser
import LibInvesting

extension Capman {
    struct Close: ParsableCommand {
        static var configuration =
            CommandConfiguration(abstract: "Close an existing position.")
        
        @Argument(help: "The position to close.")
        var ticker: String
        
        @Option(help: "The current step, for example 2/5.")
        var step: String = "1/1"
        
        @OptionGroup
        var brokerOptions: BrokerOptions

        mutating func run() throws {
            let stepParts = step.split(separator: "/")
            guard stepParts.count == 2,
                  let currentStep = UInt(stepParts[0]),
                  let totalSteps = UInt(stepParts[1]),
                  currentStep >= 1, totalSteps >= currentStep else {
                print("Invalid step. Must be in format \"X/Y\", with 1 <= X <= Y")
                return
            }
            
            let broker = try IBBroker(apiUrl: brokerOptions.apiurl)

            let portfolio = try broker.fetchPortfolio()

            let candidates = portfolio.positions.filter({ $0.asset.ticker == ticker.uppercased() })
            guard !candidates.isEmpty else {
                print("Could not find \(ticker) in portfolio. Current positions:")
                Table(portfolio.positions).print()
                return
            }
            guard candidates.count == 1 else {
                // TODO what to do in this (rare) case?
                print("Ambigious ticker \(ticker). Candidates:")
                Table(candidates).print()
                return
            }
            
            let position = candidates[0]

            let prevStep = (Double(currentStep) - 1) / Double(totalSteps)
            //     CurNumShares = OrigNumShares - OrigNumShares * PrevStep
            // <=> CurNumShares = OrigNumShares * (1.0 - PrevStep)
            // <=> CurNumShares / (1.0 - PrevStep) = OrigNumShares
            let origNumShares = Double(position.quantity) / (1.0 - prevStep)
            let sharesToSell = UInt(origNumShares * (1.0 / Double(totalSteps)))

            print("Closing position \(position.quantity) x \(position.asset.name) (worth approximately \(position.quantity * position.sharePrice)) at step \(currentStep) of \(totalSteps) by selling \(sharesToSell) shares @ \(position.sharePrice)")
 
            let result = try broker.submitLimitOrder(for: position.asset, side: .sell, quantity: sharesToSell, price: position.sharePrice, tif: .day)
            print(result)
        }
    }
}
