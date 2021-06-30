import Foundation

protocol TableFormattable {
    static var headers: [String]? { get }
    
    func formatRow() -> [String]
}

struct Table<E: TableFormattable> {
    private var entries: [E]
    
    init(_ entries: [E]) {
        self.entries = entries
    }
    
    func print() {
        var table = [[String]]()
        
        // Collect header
        if let headers = E.headers {
            // Add one space between each header item
            table.append(headers.map { $0 + " " })
        }
        
        // Collect all rows
        for entry in entries {
            let row = entry.formatRow()
            table.append(row)
            assert(table[0].count == row.count)
        }
        
        var widths = Array(repeating: 0, count: table[0].count)
        for row in table {
            for (i, entry) in row.enumerated() {
                widths[i] = max(widths[i], entry.count)
            }
        }

        for row in table {
            var s = ""
            for (i, entry) in row.enumerated() {
                s += entry.padding(toLength: widths[i], withPad: " ", startingAt: 0) + " "
            }
            Swift.print(s)
        }
    }
}
