import Foundation

enum LogLevel: String {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case fatal = "Fatal"
}

fileprivate func log(_ msg: String, at level: LogLevel) {
    print("\(level.rawValue): \(msg)")
}

func info(_ msg: String) {
    log(msg, at: .info)
}

func warning(_ msg: String) {
    log(msg, at: .warning)
}

fileprivate var warnings = Set<String>()
func warnOnce(_ msg: String) {
    guard !warnings.contains(msg) else { return }
    warnings.insert(msg)
    warning(msg)
}

func error(_ msg: String) {
    log(msg, at: .error)
}

func fatal(_ msg: String) -> Never {
    log(msg, at: .fatal)
    abort()
}
