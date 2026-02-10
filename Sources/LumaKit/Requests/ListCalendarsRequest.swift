import Foundation

public struct ListCalendarsRequest: LumaRequest {
    public typealias Response = [LumaCalendar]
    
    public let path = "calendar/list-calendars"
    public let method = "GET"
    public var queryItems: [URLQueryItem]?
    
    public init() {
        self.queryItems = nil
    }
}
