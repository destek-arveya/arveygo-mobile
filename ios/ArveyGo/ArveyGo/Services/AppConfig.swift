import Foundation

// MARK: - App Configuration
enum AppConfig {

    // MARK: - API / Backend
    /// Base URL for the Laravel backend (session-based auth)
    static let apiBaseURL = "https://arveygo.com"

    // MARK: - ATS WebSocket
    /// Secure WebSocket endpoint
    static let wsURL = "wss://websocket.arveygo.com/ws"
    /// Fallback plain WebSocket (local / dev)
    static let wsURLFallback = "ws://77.245.158.21:8765/ws"

    /// HS-256 shared secret – must match the server's ATS_WS_SECRET
    static let wsJWTSecret = "9af6e20fa3ad924f86e24905148a404523b219c50be3cc16e4b6e7dff53b7bb2"

    /// JWT time-to-live in seconds (default 1 hour)
    static let wsJWTTTL: Int = 3600

    /// Ping interval in seconds
    static let wsPingInterval: TimeInterval = 30

    /// Snapshot timeout – reconnect if no snapshot within this duration
    static let wsSnapshotTimeout: TimeInterval = 12

    /// Max reconnect delay in seconds
    static let wsMaxReconnectDelay: TimeInterval = 30
}
