import Foundation

struct RESTApi {
    private let baseUrl: String
    private let session: URLSession
    
    init(_ baseUrl: String) {
        self.baseUrl = baseUrl + "/"
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        if #available(OSX 10.13, *) {
            config.waitsForConnectivity = false
        }
        self.session = URLSession(configuration: config)
    }
    
    private func sendSyncRequest(_ request: URLRequest) -> (Data?, URLResponse?, Error?) {
        var data: Data? = nil
        var response: URLResponse? = nil
        var error: Error? = nil
        
        let group = DispatchGroup()
        group.enter()
        
        let task = session.dataTask(with: request) { d, r, e in
            data = d
            response = r
            error = e
            group.leave()
        }
        
        task.resume()
        group.wait()
        
        return (data, response, error)
    }
    
    private func request<T: Decodable>(_ method: String, _ path: String, params: [String: String] = [:], body: Data? = nil) throws -> T {
        var components = URLComponents(string: baseUrl + path)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0, value: $1) }
        }
        let url = components.url!
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response, error) = sendSyncRequest(request)
        
        if let error = error {
            throw Err.clientError(path, error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            fatal("didn't receive a HTTPURLResponse?")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // TODO handle correct encoding?
            if let bodyData = data, let body = String(data: bodyData, encoding: .utf8), !body.isEmpty {
                throw Err.serverError(path, "Response failed with status \(httpResponse.statusCode): \(body)")
            } else {
                throw Err.serverError(path, "Response failed with status \(httpResponse.statusCode)")
            }
        }

        guard let mimeType = httpResponse.mimeType else {
            throw Err.invalidResponse(path, "Missing MIME type in response")
        }
        
        guard mimeType == "application/json" else {
            throw Err.invalidResponse(path, "Unexpected MIME type \(mimeType) in response")
        }

        guard let body = data else {
            throw Err.invalidResponse(path, "Empty response with status \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: body)
        } catch {
            throw Err.invalidResponse(path, "Failed to decode \(T.self) from \(String(data: body, encoding: .utf8)!): \(error)")
        }
    }

    func get<T: Decodable>(_ path: String, params: [String: String] = [:]) throws -> T {
        return try request("GET", path, params: params)
    }

    func post<T: Decodable, R: Encodable>(_ path: String, data: R) throws -> T {
        let encoder = JSONEncoder()
        let body = try! encoder.encode(data)
        return try request("POST", path, body: body)
    }

    func post<T: Decodable>(_ path: String) throws -> T {
        return try request("POST", path)
    }
}
