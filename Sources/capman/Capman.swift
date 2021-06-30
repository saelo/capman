import Foundation
import ArgumentParser

struct Capman: ParsableCommand {
    static var configuration = CommandConfiguration(
        version: "0.1",
        subcommands: [Invest.self, Show.self, Lookup.self, Close.self]
    )
}

struct BrokerOptions: ParsableArguments {
    @Option(help: ArgumentHelp(
                "The URL of the IB Web Client API.",
                valueName: "url"))
    var apiurl: String = "https://localhost:5000"
}
