import Foundation
import ArgumentParser
import LibInvesting

extension Capman {
    struct Invest: ParsableCommand {
        static var configuration =
            CommandConfiguration(abstract: "Invest a given amount.")
        
        @Argument(help: "The amount to invest, for example 1000USD.")
        var amount: Money
        
        enum OrderType: String, ExpressibleByArgument {
            case market
            case limit
        }
        @Option(help: "The type of order to place: \"market\" or \"limit\". For limit orders, the last price is used as limit price")
        var orderType: OrderType = .limit
        
        @Option(help: "The maximum number of orders to submit. Helps keep transaction costs low in absolute terms.")
        var maxOrders = 5
        
        @Option(help: "The minimum value of an order. Helps keep transaction costs low in relative terms.")
        var minOrderAmount = USD(500)
        
        @Option(help: "The maximum weight adjustment. A position's weight is adjusted by at most this much. A value between 1.0 and 2.0 is usually reasonable here.")
        var maxWeightAdjustment = 2.0
        
        @Option(help: "Allow the final investment amount to overshoot the specified amount by this percentage. Helps to better divide the investment amount into an integer number of shares.")
        var tolerance = 0.05
        
        @Option(help: "The path to the portfolio specification file.")
        var portfolioPath = "./portfolio.json"
        
        @OptionGroup
        var brokerOptions: BrokerOptions

        mutating func run() throws {
            // Savings plan investment logic.
            // Roughly, if a position should be X% of the portfolio, but currently it only is X/2%,
            // then we'll purchase 2x as many shares of it as we would normally do (i.e. roughly 2*X%).
            
            guard amount.amount > 0 else {
                return print("amount must be > 0")
            }
            guard maxOrders > 0 else {
                return print("maxOrders must be > 0")
            }
            guard minOrderAmount.amount > 0 else {
                return print("minOrderAmount must be > 0")
            }
            guard maxWeightAdjustment >= 1.0 else {
                return print("maxWeightAdjustment must be >= 1.0")
            }
            
            print("Preparing to invest \(amount)")
            print("Constraints:")
            print("    Tolerance: \(tolerance * 100)%")
            print("    Max orders: \(maxOrders)")
            print("    Min order price: \(minOrderAmount)")
            print("    Max weight adjustment: \(maxWeightAdjustment)x")
            
            // Fetch current exchange rates
            let forex = try ExchangeRates.fetch()
            let baseCurrency = amount.currency
            minOrderAmount = forex.convert(minOrderAmount, to: baseCurrency)
            guard amount >= minOrderAmount else {
                return print("Cannot invest less than the minimum order amount (\(minOrderAmount))")
            }
            
            // Create broker interface
            let broker = try IBBroker(apiUrl: brokerOptions.apiurl)
            
            // Parse provided portfolio specification
            struct PositionSpecification: Decodable {
                let ticker: String
                let exchange: String
                let conid: UInt?
                let currency: Currency
                let weight: Double
            }
            let data = try Data(contentsOf: URL(fileURLWithPath: portfolioPath))
            let decoder = JSONDecoder()
            let portfolioSpecification = try decoder.decode([PositionSpecification].self, from: data)

            // Create investment candidates from portfolio specification
            var candidates: [InvestmentCandidate] = []
            let totalPortfolioWeight = portfolioSpecification.map({ $0.weight }).reduce(0, +)
            for entry in portfolioSpecification {
                guard let asset = try broker.lookupStock(entry.ticker, listedAt: entry.exchange, denominatedIn: entry.currency) else {
                    return print("Could not find asset \(entry.ticker)")
                }
                if let expectedConid = entry.conid {
                    guard asset.conid == expectedConid else {
                        return print("IB contract ID mismatch for \(asset.ticker): expected \(expectedConid), got \(asset.conid). Please check \(portfolioPath)")
                    }
                }

                let candidate = InvestmentCandidate(asset: asset)
                candidate.targetWeight = entry.weight / totalPortfolioWeight
                candidates.append(candidate)
            }

            // Fetch current portfolio
            let portfolio = try broker.fetchPortfolio()
            for position in portfolio.positions {
                if !candidates.contains(where: { $0.asset == position.asset }) {
                    print("Ignoring position \(position.asset.name) as it is not part of the specified portfolio")
                }
            }

            // Compute the value of the existing positions and the total value of the managed portfolio
            var totalManagedPortfolioValue = Money(amount: 0, currency: baseCurrency)
            for candidate in candidates {
                // For the calculation basis, use the market price (where available) as provided by IB.
                // Probably that's the last price...
                if let position = portfolio.find(candidate.asset) {
                    candidate.sharePrice = forex.convert(position.sharePrice, to: baseCurrency)
                    candidate.currentValue = position.quantity * candidate.sharePrice
                } else {
                    guard let data = try broker.fetchMarketDataSnapshot(for: candidate.asset) else {
                        return print("Could not fetch market data for \(candidate.asset.ticker)")
                    }
                    candidate.sharePrice = forex.convert(data.lastPrice, to: baseCurrency)
                    candidate.currentValue = 0 * candidate.sharePrice
                }
                totalManagedPortfolioValue += candidate.currentValue
            }

            // Compute the purchase weight of each candidate. The purchase weight is larger for positions that are currently below their target weight.
            // The purchase weight is initially unnormalized and will be normalized later.
            for candidate in candidates {
                // Compute the actual weight of the corresponding position in the portfolio,
                candidate.actualWeight = candidate.currentValue / totalManagedPortfolioValue

                // then compute the deviation factor, expressing how much a position deviates from its target weight.
                // This factor is > 1 if the position's weight in the portfolio is less than it should be and is < 1 if
                // it is more than it should be.
                // Note, if an asset is not yet present in the portfolio, its deviation will be inf (targetWeight / 0).
                // This is fine, as the purchaseWeight will then just end up as targetWeight * maxWeightAdjustment.
                candidate.deviation = candidate.targetWeight / candidate.actualWeight

                // For determining the weight of the candidate in the orders, clamp the deviation to a reasonable range, e.g. [0.5, 2].
                func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
                    return min(range.upperBound, max(range.lowerBound, value))
                }
                let boost = clamp(candidate.deviation, to: (1.0 / maxWeightAdjustment) ... maxWeightAdjustment)
                candidate.adjustedWeight = boost * candidate.targetWeight
            }

            // Sort the candidates by their deviation factor. The candidates deviating the most are at the end now.
            candidates.sort(by: { $0.deviation < $1.deviation })

            print("Current portfolio allocation:")
            // Print the candidates in reversed order, so the ones deviating the most are at the top
            let t = Table(candidates.reversed())
            t.print()

            // Select investments starting from the most underrepresented one until either maxOrders or minOrderAmount is reached, or no more candidates are left
            var selected: [InvestmentCandidate] = []
            var totalWeight = 0.0
            var minWeight = Double.infinity
            while let candidate = candidates.popLast() {
                let newTotalWeight = totalWeight + candidate.adjustedWeight
                minWeight = min(minWeight, candidate.adjustedWeight)
                let minAmount = (minWeight / newTotalWeight) * amount
                if minAmount < minOrderAmount {
                    // Attempt to fit in the current candidate with a lower weight.
                    // For that, compute the max total weight so that minWeight * amount >= minOrderAmount
                    let maxWeight = (amount / minOrderAmount) * minWeight
                    if maxWeight >= totalWeight + minWeight {
                        // It fits, so compute the new weight of this candidate and include it
                        candidate.adjustedWeight = maxWeight - totalWeight
                        totalWeight += candidate.adjustedWeight
                        
                        assert(maxWeight <= newTotalWeight)
                        assert(candidate.adjustedWeight >= minWeight)
                        assert((minWeight / totalWeight) * amount >= minOrderAmount)
                        
                        selected.append(candidate)
                    }
                    break
                }
                totalWeight = newTotalWeight
                selected.append(candidate)
                if selected.count >= maxOrders {
                    break
                }
            }

            // Normalize purchase weight and compute the number of shares that will be purchased
            var remaining = amount
            for investment in selected {
                investment.adjustedWeight = investment.adjustedWeight / totalWeight
                let targetAmount = investment.adjustedWeight * amount
                let maximumAmount = targetAmount * (1.0 + tolerance)
                investment.sharesToPurchase = UInt(targetAmount / investment.sharePrice)
                if investment.sharePrice * (investment.sharesToPurchase + 1) <= maximumAmount {
                    investment.sharesToPurchase += 1
                }
                remaining -= Double(investment.sharesToPurchase) * investment.sharePrice
            }

            // Attempt to squeeze in some more shares to get closer to the total investment amount
            var changed = true
            var copy = selected     // Make a copy to keep the order of the selected positions
            while changed {
                changed = false
                copy.shuffle()
                for investment in copy {
                    if investment.sharePrice < remaining {
                        investment.sharesToPurchase += 1
                        remaining -= investment.sharePrice
                        changed = true
                    }
                }
            }

            // Done, print result and create orders
            print("Investing roughly \(amount - remaining) in \(selected.count) assets:")
            for investment in selected {
                print("\(investment.sharesToPurchase) shares of \(investment.asset.ticker) (\(investment.asset.descr), \(investment.asset.currency)), for roughly \(Double(investment.sharesToPurchase) * investment.sharePrice) (\(investment.sharePrice) per share)")
            }

            for investment in selected {
                investment.sharePrice = forex.convert(investment.sharePrice, to: investment.asset.currency)
                
                let order: Order
                switch orderType {
                case .limit:
                    order = try broker.submitLimitOrder(for: investment.asset, side: .buy, quantity: investment.sharesToPurchase, price: investment.sharePrice, tif: .day)
                case .market:
                    order = try broker.submitMarketOrder(for: investment.asset, side: .buy, quantity: investment.sharesToPurchase, tif: .day)
                }
                print(order)
            }
        }
    }
}

// Helper class used by the investment algorithm.
fileprivate class InvestmentCandidate: TableFormattable {
    /// The asset that is considered for investment.
    let asset: Asset

    /// The desired weight that the asset should have in the managed portfolio.
    var targetWeight = 0.0

    /// The actual weight that the asset currently has.
    var actualWeight = 0.0

    /// The deviation of the asset's actual weight from its target weight.
    /// This is computed as targetWeight / actualWeight.
    var deviation = 0.0

    /// The adjusted weight used when deciding how many shares to purchase when investing.
    /// This is computed as targetWeight * boost, where the boost is the deviation clamped to the maximum weight adjustment.
    var adjustedWeight = 0.0

    /// The current market price of one share of the asset in the base currency.
    var sharePrice: Money = USD(0)

    /// The current market value of the existing position in the asset in the managed portfolio, in the base currency.
    var currentValue: Money = USD(0)

    /// How many shares to purchase of this asset.
    var sharesToPurchase: UInt = 0

    init(asset: Asset) {
        self.asset = asset
    }
    
    static var headers: [String]? {
        ["Ticker", "Target Weight", "Current Weight", "Deviation", "Adjusted Weight"]
    }
    
    func formatRow() -> [String] {
        let ticker = self.asset.ticker
        // The target weight and current weight are really percentages (they are normalized),
        // but the purchase/adjusted weight isn't normalized, so print all three as abstract weights
        let targetWeight = String(format: "%.2f", self.targetWeight * 100)
        let currentWeight = String(format: "%.2f", self.actualWeight * 100)
        // self.deviation is target / actual, which is needed for the computations, but the inverse,
        // actual / target, is more intuitive to display.
        let deviation = String(format: "%+.2f%%", (self.actualWeight / self.targetWeight - 1.0) * 100)
        let adjustedWeight = String(format: "%.2f", self.adjustedWeight * 100)
        return [ticker, targetWeight, currentWeight, deviation, adjustedWeight]
    }
}
