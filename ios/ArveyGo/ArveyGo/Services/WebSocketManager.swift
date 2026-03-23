import Foundation
import Combine

// MARK: - WebSocket Connection Status
enum WSConnectionStatus: Equatable {
    case idle
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case error(String)
    case disconnected

    var label: String {
        switch self {
        case .idle:                  return "Bağlantı bekleniyor"
        case .connecting:            return "Bağlanıyor…"
        case .connected:             return "Canlı"
        case .reconnecting(let n):   return "Yeniden bağlanıyor (\(n))…"
        case .error(let msg):        return "Hata: \(msg)"
        case .disconnected:          return "Bağlantı kesildi"
        }
    }

    var color: String {
        switch self {
        case .connected:    return "green"
        case .connecting, .reconnecting: return "orange"
        case .error:        return "red"
        default:            return "gray"
        }
    }
}

// MARK: - WebSocket Event
enum WSEvent {
    case snapshot(vehicles: [Vehicle], count: Int, ts: Int)
    case update(vehicle: Vehicle, ts: Int)
    case statusChanged(WSConnectionStatus)
    case pong(ts: Int)
}

// MARK: - WebSocket Manager
/// Manages a persistent WebSocket connection to the ATS vehicle tracking server.
/// Uses `URLSessionWebSocketTask` (iOS 13+). Designed as an `ObservableObject` so
/// SwiftUI views can observe connection status.
@MainActor
final class WebSocketManager: ObservableObject {

    // MARK: - Published state
    @Published private(set) var status: WSConnectionStatus = .idle
    @Published private(set) var vehicles: [String: Vehicle] = [:]  // imei → Vehicle
    @Published private(set) var vehicleList: [Vehicle] = []        // ordered array

    /// Combine subject for downstream consumers (LiveMapViewModel)
    let eventSubject = PassthroughSubject<WSEvent, Never>()

    // MARK: - Configuration
    private var wsURL: String = ""
    private var token: String = ""
    private var pingInterval: TimeInterval = AppConfig.wsPingInterval
    private var snapshotTimeout: TimeInterval = AppConfig.wsSnapshotTimeout
    private var maxReconnectDelay: TimeInterval = AppConfig.wsMaxReconnectDelay

    // MARK: - Internal state
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var snapshotTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempt = 0
    private var manualClose = false
    private var authFailed = false
    private var awaitingSnapshot = false
    private var orderList: [String] = []  // maintains insertion order by imei

    // MARK: - Singleton
    static let shared = WebSocketManager()
    private init() {}

    // MARK: - Public API

    /// Configure and connect to the WebSocket server.
    /// - Parameters:
    ///   - url: WebSocket server URL (e.g., `wss://websocket.arveygo.com/ws`)
    ///   - token: JWT authentication token
    func connect(url: String, token: String) {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURL.isEmpty, !trimmedToken.isEmpty else {
            status = .error("URL veya token eksik")
            return
        }

        // If already connected with same config, skip
        if wsURL == trimmedURL && self.token == trimmedToken,
           webSocketTask != nil {
            return
        }

        wsURL = trimmedURL
        self.token = trimmedToken
        manualClose = false
        authFailed = false

        openSocket(isReconnect: false)
    }

    /// Connect using AppConfig defaults + provided user info.
    func connect(sub: String, companyId: Int) {
        let jwt = JWTHelper.issueLiveMapToken(sub: sub, companyId: companyId)
        connect(url: AppConfig.wsURL, token: jwt)
    }

    /// Gracefully disconnect.
    func disconnect() {
        manualClose = true
        clearAllTimers()
        closeSocket()
        status = .disconnected
        eventSubject.send(.statusChanged(.disconnected))
    }

    /// Force reconnect (e.g., after app returns to foreground).
    func reconnect() {
        manualClose = false
        authFailed = false
        clearAllTimers()
        closeSocket()
        openSocket(isReconnect: true)
    }

    // MARK: - Socket Lifecycle

    private func openSocket(isReconnect: Bool) {
        clearAllTimers()
        closeSocket()

        // Build URL with token query parameter
        guard var urlComponents = URLComponents(string: wsURL) else {
            status = .error("Geçersiz WebSocket URL")
            return
        }

        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "token", value: token))
        urlComponents.queryItems = queryItems

        // Convert http(s) to ws(s)
        if urlComponents.scheme == "http" { urlComponents.scheme = "ws" }
        if urlComponents.scheme == "https" { urlComponents.scheme = "wss" }

        guard let url = urlComponents.url else {
            status = .error("URL oluşturulamadı")
            return
        }

        awaitingSnapshot = true
        status = isReconnect ? .reconnecting(attempt: reconnectAttempt) : .connecting
        eventSubject.send(.statusChanged(status))

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)

        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()

        // Start listening for messages
        listenForMessages()

        // Start ping loop
        startPingLoop()

        // Arm snapshot timeout
        armSnapshotTimeout()
    }

    private func closeSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
    }

    // MARK: - Message Handling

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self, self.webSocketTask != nil else { return }

                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    // Continue listening
                    self.listenForMessages()

                case .failure(let error):
                    // Socket disconnected
                    if !self.manualClose {
                        self.handleDisconnect(error: error)
                    }
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let d):
            data = d
        @unknown default:
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "snapshot":
            handleSnapshot(json)
        case "update":
            handleUpdate(json)
        case "pong":
            let ts = (json["ts"] as? Int) ?? 0
            eventSubject.send(.pong(ts: ts))
        case "auth_error":
            authFailed = true
            let msg = (json["message"] as? String) ?? "Yetkilendirme hatası"
            status = .error(msg)
            eventSubject.send(.statusChanged(status))
            closeSocket()
        case "error":
            let msg = (json["message"] as? String) ?? "Sunucu hatası"
            status = .error(msg)
            eventSubject.send(.statusChanged(status))
            closeSocket()
            scheduleReconnect()
        default:
            break
        }
    }

    private func handleSnapshot(_ json: [String: Any]) {
        awaitingSnapshot = false
        clearSnapshotTimer()
        reconnectAttempt = 0

        guard let vehiclesArray = json["vehicles"] as? [[String: Any]] else { return }
        let ts = (json["ts"] as? Int) ?? 0

        // Replace all
        var newVehicles: [String: Vehicle] = [:]
        var newOrder: [String] = []

        for vehicleJson in vehiclesArray {
            if var vehicle = Vehicle.fromWSPayload(vehicleJson) {
                // Merge with existing data if we have it (preserves extra info)
                if let existing = vehicles[vehicle.imei] {
                    var merged = existing
                    merged.mergeUpdate(from: vehicle)
                    vehicle = merged
                }
                newVehicles[vehicle.imei] = vehicle
                newOrder.append(vehicle.imei)
            }
        }

        vehicles = newVehicles
        orderList = newOrder
        rebuildVehicleList()

        status = .connected
        eventSubject.send(.statusChanged(.connected))
        eventSubject.send(.snapshot(vehicles: vehicleList, count: vehicleList.count, ts: ts))
    }

    private func handleUpdate(_ json: [String: Any]) {
        let vehicleJson = (json["vehicle"] as? [String: Any]) ?? json
        let ts = (json["ts"] as? Int) ?? 0

        guard let patch = Vehicle.fromWSPayload(vehicleJson) else { return }

        awaitingSnapshot = false
        clearSnapshotTimer()

        if var existing = vehicles[patch.imei] {
            existing.mergeUpdate(from: patch)
            vehicles[patch.imei] = existing
        } else {
            vehicles[patch.imei] = patch
            orderList.append(patch.imei)
        }

        rebuildVehicleList()

        if status != .connected {
            status = .connected
            eventSubject.send(.statusChanged(.connected))
        }

        if let updated = vehicles[patch.imei] {
            eventSubject.send(.update(vehicle: updated, ts: ts))
        }
    }

    private func rebuildVehicleList() {
        vehicleList = orderList.compactMap { vehicles[$0] }
    }

    // MARK: - Disconnect & Reconnect

    private func handleDisconnect(error: Error?) {
        clearPingTimer()
        clearSnapshotTimer()

        if authFailed {
            status = .error("Yetkilendirme hatası")
            eventSubject.send(.statusChanged(status))
            return
        }

        status = .reconnecting(attempt: reconnectAttempt + 1)
        eventSubject.send(.statusChanged(status))
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard !manualClose, !authFailed, !wsURL.isEmpty, !token.isEmpty else { return }
        guard reconnectTimer == nil else { return }

        reconnectAttempt += 1

        // Exponential backoff: 1s * 2^attempt, capped at maxReconnectDelay, with jitter
        let base = min(maxReconnectDelay, pow(2.0, Double(min(reconnectAttempt - 1, 5))))
        let jitter = Double.random(in: 0...0.75)
        let delay = base + jitter

        status = .reconnecting(attempt: reconnectAttempt)
        eventSubject.send(.statusChanged(status))

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.reconnectTimer = nil
                self?.openSocket(isReconnect: true)
            }
        }
    }

    // MARK: - Ping / Pong

    private func startPingLoop() {
        clearPingTimer()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendPing()
            }
        }
    }

    private func sendPing() {
        guard let task = webSocketTask else { return }
        let pingData = try? JSONSerialization.data(withJSONObject: ["type": "ping"])
        if let data = pingData, let text = String(data: data, encoding: .utf8) {
            task.send(.string(text)) { error in
                if let error = error {
                    print("[WS] Ping failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Snapshot Timeout

    private func armSnapshotTimeout() {
        clearSnapshotTimer()
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: snapshotTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.awaitingSnapshot else { return }
                self.status = .error("Snapshot zaman aşımı")
                self.eventSubject.send(.statusChanged(self.status))
                self.closeSocket()
                self.scheduleReconnect()
            }
        }
    }

    // MARK: - Timer Cleanup

    private func clearPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func clearSnapshotTimer() {
        snapshotTimer?.invalidate()
        snapshotTimer = nil
    }

    private func clearReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    private func clearAllTimers() {
        clearPingTimer()
        clearSnapshotTimer()
        clearReconnectTimer()
    }
}
