import Foundation

public protocol LumaRequest: Sendable {
    associatedtype Response: Decodable & Sendable
    
    var path: String { get }
    var method: String { get }
    var queryItems: [URLQueryItem]? { get }
}

extension LumaRequest {
    public func makeURLRequest(baseURL: URL, apiKey: String) -> URLRequest {
        var url = baseURL.appendingPathComponent(path)
        
        if let queryItems = queryItems, !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = queryItems
            url = components.url!
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
