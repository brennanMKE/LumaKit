import Foundation

public enum LumaAPIError: Error, Sendable, LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int, message: String?)
    case decodingFailed(Error)
    case network(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let statusCode, let message):
            var desc = "API error (\(statusCode))"
            if let message = message {
                desc += ": \(message)"
            }
            return desc
        case .decodingFailed(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
