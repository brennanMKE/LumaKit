# PRD: LumaKit

## Overview
LumaKit is a lightweight Swift package that provides a typed, async-friendly client for accessing **Luma's REST API**.
The package focuses on **read-only access** to calendar events and calendars using an API key supplied by the consumer.

The goal is simplicity:
- No persistence
- No UI
- No webhook support
- One responsibility: fetch and decode data from Luma
- Native Swift 6 Concurrency support (Sendable, Actors)

---

## Goals
- Provide a clean Swift API for `list-events` and `list-calendars`
- Use native Swift concurrency (`async/await`, `actor`)
- Strongly typed request/response models
- Minimal dependencies (Foundation only)
- Suitable for use in CLIs, servers, or background jobs
- Handle Rate Limiting information from API headers

---

## Non-Goals
- Event creation or mutation
- Webhooks
- Authentication flows beyond API key
- UI components
- Caching or storage

---

## Target Users
- Swift developers integrating Luma calendar data
- CLI tools
- MCP servers or automation pipelines
- Backend Swift services

---

## API Scope

### Supported Endpoints
- `GET /v1/calendar/list-events`
- `GET /v1/calendar/list-calendars`

### Authentication
- Bearer Token Auth via the `Authorization` header:
  - `Authorization: Bearer <API_KEY>`

### Rate Limiting
- Tracked via response headers:
  - `x-rate-limit-limit`
  - `x-rate-limit-remaining`
  - `x-rate-limit-reset`

---

## Package Structure

LumaKit/
- Package.swift
- Sources/
  - LumaKit/
    - LumaClient.swift (Actor)
    - LumaConfig.swift
    - Models/
      - LumaEvent.swift
      - LumaCalendar.swift
      - LumaResponse.swift (Generic wrapper)
    - Protocols/
      - LumaRequest.swift
    - Requests/
      - ListEventsRequest.swift
      - ListCalendarsRequest.swift
    - Errors/
      - LumaAPIError.swift
- Tests/
  - LumaKitTests/

---

## Public API Design

### Client Initialization
```swift
let client = LumaClient(apiKey: "<API_KEY>")
```

### List Events
```swift
let (events, rateLimit) = try await client.send(ListEventsRequest(calendarID: "cal_123"))
```

### List Calendars
```swift
let (calendars, rateLimit) = try await client.send(ListCalendarsRequest())
```

---

## Core Types

### LumaClient (Actor)
Responsibilities:
- Build HTTP requests from `LumaRequest` objects
- Attach authentication headers
- Handle networking via `URLSession`
- Decode JSON responses
- Extract rate limit metadata

### LumaRequest (Protocol)
- Defines path, method, and query items
- Provides default implementation for `URLRequest` construction

---

## Error Handling

### LumaAPIError
Cases:
- invalidURL
- requestFailed(statusCode: Int, message: String?)
- decodingFailed(Error)
- network(Error)

---

## Networking Requirements
- Use URLSession
- Use async/await
- Swift 6 strict concurrency compliance
- Set request headers:
  - Accept: application/json
  - Authorization: Bearer <API_KEY>

---

## Testing Strategy
- Unit tests for:
  - URL construction
  - JSON decoding (using fixture responses)
  - Rate limit extraction
- Network calls mocked via URLProtocol

---

## Success Criteria
- Developer can fetch events in fewer than 10 lines of Swift
- Zero external dependencies
- Full Swift 6 concurrency safety
- Clear, documented API surface
