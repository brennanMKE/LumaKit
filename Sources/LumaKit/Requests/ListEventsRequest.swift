import Foundation

public struct ListEventsRequest: LumaRequest {
    public typealias Response = [LumaEvent]
    
    public let path = "calendar/list-events"
    public let method = "GET"
    public var queryItems: [URLQueryItem]?
    
    public init(calendarID: String? = nil, limit: Int? = nil, cursor: String? = nil) {
        var items = [URLQueryItem]()
        if let calendarID = calendarID {
            items.append(URLQueryItem(name: "calendar_id", value: calendarID))
        }
        if let limit = limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let cursor = cursor {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        self.queryItems = items.isEmpty ? nil : items
    }
}
