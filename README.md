# LumaKit 📆

> [!WARNING]
> **ALPHA QUALITY**: This package is in early development. APIs are subject to change without notice.

LumaKit is a lightweight, async-friendly Swift package for accessing the [Luma REST API](https://docs.lu.ma/reference/getting-started-with-your-api). It is built with **Swift 6 Strict Concurrency** and uses native `async/await` and `actor` models.

## Features

- ✅ **Read-Only Access**: Fetch events and calendars from Luma.
- ✅ **Swift 6 Ready**: Full compliance with strict concurrency (Sendable, Actors).
- ✅ **Rate Limit Support**: Automatically extracts and provides `x-rate-limit` metadata.
- ✅ **Zero Dependencies**: Uses only Foundation and URLSession.
- ✅ **Modern Architecture**: Protocol-oriented request design.

## Installation

Add LumaKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brennanMKE/LumaKit", from: "0.1.0")
]
```

## Quick Start

### Initialize Client

```swift
import LumaKit

let client = LumaClient(apiKey: "your_luma_api_key")
```

### List Events

```swift
let request = ListEventsRequest(calendarID: "cal_123", limit: 50)
let (events, rateLimit) = try await client.send(request)

for event in events {
    print("Event: \(event.name) at \(event.startAt)")
}

if let rate = rateLimit {
    print("Remaining API requests: \(rate.remaining)")
}
```

### List Calendars

```swift
let (calendars, _) = try await client.send(ListCalendarsRequest())
```

## Requirements

- macOS 12.0+ / iOS 15.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 6.0+

## Development & Testing

LumaKit includes a comprehensive test suite using the new **Swift Testing** framework. It uses a `MockURLProtocol` to ensure no real network requests are made during testing.

```bash
swift test
```

## License

This project is licensed under the MIT License.
