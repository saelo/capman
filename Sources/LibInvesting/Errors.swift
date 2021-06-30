import Foundation

enum Err: Error {
    case clientError(_ path: String, _ description: String)
    case serverError(_ path: String, _ description: String)
    case invalidResponse(_ path: String, _ description: String)
    case apiError(_ description: String)
}
