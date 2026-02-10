import Foundation

public struct LumaResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let entries: T
    
    enum CodingKeys: String, CodingKey {
        case entries
    }
}

public struct RateLimitInfo: Sendable {
    public let limit: Int
    public let remaining: Int
    public let reset: Date
}
