import Testing
import Foundation
@testable import LumaKit

// MARK: - Thread-Safe Mock URL Storage

actor MockURLStorage {
    private var mockData: [String: (error: Error?, data: Data?, response: HTTPURLResponse?)] = [:]

    func setMock(for key: String, url: URL, statusCode: Int, httpVersion: String? = nil, headerFields: [String: String]? = nil, extraHeaders: [String: String]? = nil, error: Error? = nil, data: Data? = nil) {
        var combinedHeaders = headerFields ?? [:]
        if let extraHeaders = extraHeaders {
            for (key, value) in extraHeaders {
                combinedHeaders[key] = value
            }
        }
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: httpVersion, headerFields: combinedHeaders)
        let tuple = (error: error, data: data, response: response)
        mockData[key] = tuple
    }

    func getMock(for key: String) -> (error: Error?, data: Data?, response: HTTPURLResponse?)? {
        return mockData[key]
    }

    func clearAll() {
        mockData.removeAll()
    }
}

// MARK: - Mock URL Protocol

class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static let storage = MockURLStorage()

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        Task {
            await handleRequest()
        }
    }

    override func stopLoading() {
        // No-op for mock
    }

    private func handleRequest() async {
        guard request.url != nil else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        // Extract the mock key from headers
        let mockKey = request.allHTTPHeaderFields?["X-Luma-Mock"] ?? "default"
        let mock = await Self.storage.getMock(for: mockKey)

        if let error = mock?.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        if let response = mock?.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        if let data = mock?.data {
            client?.urlProtocol(self, didLoad: data)
        }

        client?.urlProtocolDidFinishLoading(self)
    }
}

// MARK: - Tests

@Suite("LumaAPIError Tests")
struct LumaAPIErrorTests {
    @Test func testErrorDescription() {
        let invalidURL = LumaAPIError.invalidURL
        #expect(invalidURL.errorDescription == "Invalid URL")
        
        let requestFailed = LumaAPIError.requestFailed(statusCode: 404, message: "Not Found")
        #expect(requestFailed.errorDescription == "API error (404): Not Found")
        
        let requestFailedNoMsg = LumaAPIError.requestFailed(statusCode: 500, message: nil)
        #expect(requestFailedNoMsg.errorDescription == "API error (500)")
        
        let decodingError = LumaAPIError.decodingFailed(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "fail"]))
        #expect(decodingError.errorDescription == "Decoding error: fail")
        
        let networkError = LumaAPIError.network(NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "offline"]))
        #expect(networkError.errorDescription == "Network error: offline")
    }
}

@Suite("LumaConfig Tests")
struct LumaConfigTests {
    @Test func testBaseURL() {
        #expect(LumaConfig.baseURL.absoluteString == "https://api.lu.ma/v1")
    }
}

@Suite("LumaClient Infrastructure Tests")
struct LumaClientInfrastructureTests {
    @Test func testCustomURLSessionInjection() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        _ = LumaClient(apiKey: "test_key", session: session)
        
        // This test indirectly verifies session injection by using a mock that only works if the session is correctly injected.
        let mockKey = #function
        let url = URL(string: "https://api.lu.ma/v1/calendar/list-calendars")!
        
        await MockURLProtocol.storage.setMock(
            for: mockKey,
            url: url,
            statusCode: 200,
            data: "{\"entries\": []}".data(using: .utf8)
        )
        
        let config2 = URLSessionConfiguration.ephemeral
        config2.protocolClasses = [MockURLProtocol.self]
        config2.httpAdditionalHeaders = ["X-Luma-Mock": mockKey]
        let session2 = URLSession(configuration: config2)
        let client2 = LumaClient(apiKey: "test_key", session: session2)
        
        let _ = try await client2.send(ListCalendarsRequest())
        await MockURLProtocol.storage.clearAll()
    }
}

@Suite("RateLimitHeaderParsing Edge Case Tests")
struct RateLimitHeaderParsingEdgeTests {
    @Test func testMissingHeaders() async throws {
        let mockKey = #function
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.httpAdditionalHeaders = ["X-Luma-Mock": mockKey]
        let session = URLSession(configuration: config)
        let client = LumaClient(apiKey: "test_key", session: session)
        
        await MockURLProtocol.storage.setMock(
            for: mockKey,
            url: URL(string: "https://api.lu.ma/v1/calendar/list-calendars")!,
            statusCode: 200,
            headerFields: [:], // Missing rate limit headers
            data: "{\"entries\": []}".data(using: .utf8)
        )
        
        let (_, rateLimit) = try await client.send(ListCalendarsRequest())
        #expect(rateLimit == nil)
        
        await MockURLProtocol.storage.clearAll()
    }
    
    @Test func testMalformedHeaders() async throws {
        let mockKey = #function
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.httpAdditionalHeaders = ["X-Luma-Mock": mockKey]
        let session = URLSession(configuration: config)
        let client = LumaClient(apiKey: "test_key", session: session)
        
        await MockURLProtocol.storage.setMock(
            for: mockKey,
            url: URL(string: "https://api.lu.ma/v1/calendar/list-calendars")!,
            statusCode: 200,
            headerFields: [
                "x-rate-limit-limit": "abc", // Malformed
                "x-rate-limit-remaining": "10",
                "x-rate-limit-reset": "1700000000"
            ],
            data: "{\"entries\": []}".data(using: .utf8)
        )
        
        let (_, rateLimit) = try await client.send(ListCalendarsRequest())
        #expect(rateLimit == nil)
        
        await MockURLProtocol.storage.clearAll()
    }
}
@Suite("RateLimitInfo Tests")
struct RateLimitInfoTests {
    @Test func testRateLimitInfoInitialization() {
        let reset = Date(timeIntervalSince1970: 1000)
        let info = RateLimitInfo(limit: 100, remaining: 50, reset: reset)
        #expect(info.limit == 100)
        #expect(info.remaining == 50)
        #expect(info.reset == reset)
    }
}

@Suite("LumaRequest Tests")
struct LumaRequestTests {
    @Test func testListEventsRequestURL() throws {
        let request = ListEventsRequest(calendarID: "cal_123", limit: 50)
        let urlRequest = request.makeURLRequest(baseURL: URL(string: "https://api.lu.ma/v1")!, apiKey: "test_key")
        
        #expect(urlRequest.url?.absoluteString.contains("calendar/list-events") == true)
        #expect(urlRequest.url?.absoluteString.contains("calendar_id=cal_123") == true)
        #expect(urlRequest.url?.absoluteString.contains("limit=50") == true)
        #expect(urlRequest.allHTTPHeaderFields?["Authorization"] == "Bearer test_key")
        #expect(urlRequest.allHTTPHeaderFields?["Accept"] == "application/json")
    }
    
    @Test func testListCalendarsRequestURL() throws {
        let request = ListCalendarsRequest()
        let urlRequest = request.makeURLRequest(baseURL: URL(string: "https://api.lu.ma/v1")!, apiKey: "test_key")
        
        #expect(urlRequest.url?.absoluteString.contains("calendar/list-calendars") == true)
        #expect(urlRequest.allHTTPHeaderFields?["Authorization"] == "Bearer test_key")
    }

    @Test func testRequestWithQueryItems() throws {
        struct CustomRequest: LumaRequest {
            typealias Response = [LumaCalendar]
            let path = "test"
            let method = "GET"
            var queryItems: [URLQueryItem]?
        }
        
        let request = CustomRequest(queryItems: [URLQueryItem(name: "a", value: "b")])
        let urlRequest = request.makeURLRequest(baseURL: URL(string: "https://api.lu.ma/v1")!, apiKey: "key")
        #expect(urlRequest.url?.query == "a=b")
    }
}

@Suite("Model Decoding Tests")
struct ModelDecodingTests {
    @Test func testLumaEventDecoding() throws {
        let json = """
        {
            "id": "evt_123",
            "name": "Test Event",
            "description": "Test Description",
            "start_at": "2024-02-10T10:00:00Z",
            "timezone": "UTC",
            "url": "https://lu.ma/e/evt_123"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(LumaEvent.self, from: json)
        
        #expect(event.id == "evt_123")
        #expect(event.name == "Test Event")
        #expect(event.timezone == "UTC")
        #expect(event.url?.absoluteString == "https://lu.ma/e/evt_123")
    }

    @Test func testLumaCalendarDecoding() throws {
        let json = """
        {
            "id": "cal_123",
            "name": "My Calendar",
            "description": "A test calendar"
        }
        """.data(using: .utf8)!
        
        let calendar = try JSONDecoder().decode(LumaCalendar.self, from: json)
        #expect(calendar.id == "cal_123")
        #expect(calendar.name == "My Calendar")
        #expect(calendar.description == "A test calendar")
    }

    @Test func testLumaResponseWrapperDecoding() throws {
        let json = """
        {
            "entries": [
                {"id": "cal_1", "name": "C1"}
            ]
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LumaResponse<[LumaCalendar]>.self, from: json)
        #expect(response.entries.count == 1)
        #expect(response.entries[0].name == "C1")
    }
}

@Suite("LumaClient Mock Tests")
struct LumaClientMockTests {
    
    private func createMockClient(mockKey: String) -> LumaClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.httpAdditionalHeaders = ["X-Luma-Mock": mockKey]
        let session = URLSession(configuration: config)
        return LumaClient(apiKey: "test_key", session: session)
    }
    
    @Test func testSuccessfulListEvents() async throws {
        let mockKey = #function
        let client = createMockClient(mockKey: mockKey)
        let url = URL(string: "https://api.lu.ma/v1/calendar/list-events")!
        
        let jsonData = """
        {
            "entries": [
                {
                    "id": "evt_1",
                    "name": "Event 1",
                    "start_at": "2024-02-10T10:00:00Z"
                }
            ]
        }
        """.data(using: .utf8)!
        
        await MockURLProtocol.storage.setMock(
            for: mockKey,
            url: url,
            statusCode: 200,
            headerFields: [
                "Content-Type": "application/json",
                "x-rate-limit-limit": "100",
                "x-rate-limit-remaining": "99",
                "x-rate-limit-reset": "1234567890"
            ],
            data: jsonData
        )
        
        let (events, rateLimit) = try await client.send(ListEventsRequest())
        
        #expect(events.count == 1)
        #expect(events[0].id == "evt_1")
        #expect(rateLimit?.limit == 100)
        #expect(rateLimit?.remaining == 99)
        
        await MockURLProtocol.storage.clearAll()
    }
    
    @Test func testRateLimitParsing() async throws {
        let mockKey = #function
        let client = createMockClient(mockKey: mockKey)
        let url = URL(string: "https://api.lu.ma/v1/calendar/list-calendars")!
        
        let jsonData = """
        {
            "entries": []
        }
        """.data(using: .utf8)!
        
        await MockURLProtocol.storage.setMock(
            for: mockKey,
            url: url,
            statusCode: 200,
            headerFields: [
                "x-rate-limit-limit": "50",
                "x-rate-limit-remaining": "10",
                "x-rate-limit-reset": "1700000000"
            ],
            data: jsonData
        )
        
        let (_, rateLimit) = try await client.send(ListCalendarsRequest())
        
        #expect(rateLimit?.limit == 50)
        #expect(rateLimit?.remaining == 10)
        #expect(rateLimit?.reset == Date(timeIntervalSince1970: 1700000000))
        
        await MockURLProtocol.storage.clearAll()
    }
    
    @Test func testRequestFailure() async throws {
        let mockKey = #function
        let client = createMockClient(mockKey: mockKey)
        let url = URL(string: "https://api.lu.ma/v1/calendar/list-events")!
        
        await MockURLProtocol.storage.setMock(
            for: mockKey,
            url: url,
            statusCode: 401,
            data: "Unauthorized access".data(using: .utf8)
        )
        
        do {
            _ = try await client.send(ListEventsRequest())
            #expect(Bool(false), "Should have thrown an error")
        } catch let LumaAPIError.requestFailed(statusCode, message) {
            #expect(statusCode == 401)
            #expect(message == "Unauthorized access")
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
        
        await MockURLProtocol.storage.clearAll()
    }
}
