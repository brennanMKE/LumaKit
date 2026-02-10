import Foundation

public actor LumaClient {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    
    public init(apiKey: String, baseURL: URL = LumaConfig.baseURL, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Fallback for non-fractional seconds
            let fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter.formatOptions = [.withInternetDateTime]
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
        }
    }
    
    public func send<T: LumaRequest>(_ request: T) async throws -> (T.Response, RateLimitInfo?) {
        let urlRequest = request.makeURLRequest(baseURL: baseURL, apiKey: apiKey)
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw LumaAPIError.network(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LumaAPIError.network(URLError(.badServerResponse))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw LumaAPIError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
        
        let decoded: T.Response
        do {
            // Luma API often returns the actual model directly or wrapped.
            // Let's assume the wrapper for now as per my LumaResponse definition.
            let wrapper = try decoder.decode(LumaResponse<T.Response>.self, from: data)
            decoded = wrapper.entries
        } catch {
            // If decoding as wrapper fails, try decoding the response type directly as a fallback
            do {
                decoded = try decoder.decode(T.Response.self, from: data)
            } catch {
                throw LumaAPIError.decodingFailed(error)
            }
        }
        
        let rateLimit = extractRateLimit(from: httpResponse)
        
        return (decoded, rateLimit)
    }
    
    private func extractRateLimit(from response: HTTPURLResponse) -> RateLimitInfo? {
        guard let limitString = response.value(forHTTPHeaderField: "x-rate-limit-limit"),
              let remainingString = response.value(forHTTPHeaderField: "x-rate-limit-remaining"),
              let resetString = response.value(forHTTPHeaderField: "x-rate-limit-reset"),
              let limit = Int(limitString),
              let remaining = Int(remainingString),
              let resetInterval = TimeInterval(resetString) else {
            return nil
        }
        
        return RateLimitInfo(
            limit: limit,
            remaining: remaining,
            reset: Date(timeIntervalSince1970: resetInterval)
        )
    }
}
