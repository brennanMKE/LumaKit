import Foundation

public struct LumaEvent: Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let startAt: Date
    public let endAt: Date?
    public let timezone: String?
    public let url: URL?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case startAt = "start_at"
        case endAt = "end_at"
        case timezone
        case url
    }
}
