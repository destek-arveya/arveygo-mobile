import Foundation
import UIKit
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

    /// Cache: driverCode → driverName (fetched from API once)
    private var driverNameCache: [String: String] = [:]
    /// Cache: imei → deviceId (fetched from catalog API)
    private var deviceIdCache: [String: Int] = [:]

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

    /// Consecutive failure count — published so UI can observe
    @Published private(set) var consecutiveFailures: Int = 0
    /// Max failures before triggering support redirect
    static let maxConsecutiveFailures = 5

    // Background/foreground tracking
    private var backgroundDate: Date?
    private var healthCheckTimer: Timer?
    /// How long the app can be in background before we force a full reconnect (seconds)
    private let backgroundGracePeriod: TimeInterval = 30

    // MARK: - Singleton
    static let shared = WebSocketManager()
    private init() {
        setupLifecycleObservers()
    }

    // MARK: - Lifecycle Observers
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleDidEnterBackground()
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleWillEnterForeground()
        }
    }

    private func handleDidEnterBackground() {
        backgroundDate = Date()
        // Stop ping timer to save battery — the connection may silently die
        clearPingTimer()
        clearSnapshotTimer()
        stopHealthCheckTimer()
        print("[WS] App entered background, stopped ping")
    }

    private func handleWillEnterForeground() {
        let elapsed = -(backgroundDate ?? Date()).timeIntervalSinceNow
        backgroundDate = nil
        print("[WS] App entering foreground after \(Int(elapsed))s")

        if elapsed > backgroundGracePeriod || status != .connected {
            // Connection likely dead — force full reconnect
            print("[WS] Background exceeded \(Int(backgroundGracePeriod))s or status=\(status.label), forcing reconnect")
            reconnect()
        } else {
            // Short background — just restart ping and verify health
            startPingLoop()
            startHealthCheckTimer()
        }
    }

    // MARK: - Health Check Timer
    /// Periodically verifies the connection is alive by checking task state
    private func startHealthCheckTimer() {
        stopHealthCheckTimer()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkConnectionHealth()
            }
        }
    }

    private func stopHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    private func checkConnectionHealth() {
        guard !manualClose, !wsURL.isEmpty, !token.isEmpty else { return }
        guard status == .connected || status == .connecting else { return }

        // Check if URLSessionWebSocketTask is still in a good state
        if let task = webSocketTask {
            switch task.state {
            case .running:
                break // healthy
            case .canceling, .completed, .suspended:
                print("[WS] Health check: task state is \(task.state.rawValue), reconnecting")
                reconnect()
            @unknown default:
                break
            }
        } else if status == .connected {
            print("[WS] Health check: no task but status is connected, reconnecting")
            reconnect()
        }
    }

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
        guard !wsURL.isEmpty, !token.isEmpty else {
            print("[WS] Reconnect skipped — no URL/token configured yet")
            return
        }
        manualClose = false
        authFailed = false
        consecutiveFailures = 0
        clearAllTimers()
        closeSocket()
        openSocket(isReconnect: true)
    }

    // MARK: - Socket Lifecycle

    private func openSocket(isReconnect: Bool) {
        clearAllTimers()
        closeSocket()

        // Build WebSocket URL as raw string.
        // IMPORTANT: URLComponents converts wss:// → https:// which breaks
        // WebSocket handshake. We must build the URL string manually.
        let separator = wsURL.contains("?") ? "&" : "?"
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        let fullURLString = "\(wsURL)\(separator)token=\(encodedToken)"

        guard let url = URL(string: fullURLString) else {
            status = .error("Geçersiz WebSocket URL")
            return
        }

        awaitingSnapshot = true
        status = isReconnect ? .reconnecting(attempt: reconnectAttempt) : .connecting
        eventSubject.send(.statusChanged(status))

        print("[WS] Connecting to: \(fullURLString)")

        // Use URLRequest so we can set proper headers
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)

        webSocketTask = session?.webSocketTask(with: request)
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
                    print("[WS] Socket error: \(error.localizedDescription)")
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
            print("[WS] Received snapshot")
            handleSnapshot(json)
        case "update":
            handleUpdate(json)
        case "pong":
            let ts = (json["ts"] as? Int) ?? 0
            eventSubject.send(.pong(ts: ts))
        case "auth_error":
            authFailed = true
            let msg = (json["message"] as? String) ?? "Yetkilendirme hatası"
            print("[WS] Auth error: \(msg)")
            status = .error(msg)
            eventSubject.send(.statusChanged(status))
            closeSocket()
        case "error":
            let msg = (json["message"] as? String) ?? "Sunucu hatası"
            print("[WS] Server error: \(msg)")
            status = .error(msg)
            eventSubject.send(.statusChanged(status))
            closeSocket()
            scheduleReconnect()
        default:
            print("[WS] Unknown message type: \(type)")
            break
        }
    }

    private func handleSnapshot(_ json: [String: Any]) {
        awaitingSnapshot = false
        clearSnapshotTimer()
        reconnectAttempt = 0
        consecutiveFailures = 0

        guard let vehiclesArray = json["vehicles"] as? [[String: Any]] else {
            print("[WS] Snapshot has no vehicles array")
            return
        }
        let ts = (json["ts"] as? Int) ?? 0
        print("[WS] Snapshot: \(vehiclesArray.count) vehicles, ts=\(ts)")

        // snapshot: local araç cache tamamen yenilensin (merge yok)
        let oldVehicles = vehicles
        var newVehicles: [String: Vehicle] = [:]
        var newOrder: [String] = []

        for vehicleJson in vehiclesArray {
            if var vehicle = Vehicle.fromWSPayload(vehicleJson) {
                // Carry over API-enriched fields from previous cache (WS doesn't provide these)
                if let old = oldVehicles[vehicle.imei] {
                    if vehicle.driverName.isEmpty && !old.driverName.isEmpty { vehicle.driverName = old.driverName }
                    if vehicle.groupName.isEmpty && !old.groupName.isEmpty { vehicle.groupName = old.groupName }
                    if vehicle.vehicleBrand.isEmpty && !old.vehicleBrand.isEmpty { vehicle.vehicleBrand = old.vehicleBrand }
                    if vehicle.vehicleModel.isEmpty && !old.vehicleModel.isEmpty { vehicle.vehicleModel = old.vehicleModel }
                    if vehicle.address.isEmpty && !old.address.isEmpty { vehicle.address = old.address }
                    if vehicle.city.isEmpty && !old.city.isEmpty { vehicle.city = old.city }
                    if vehicle.fuelType.isEmpty && !old.fuelType.isEmpty { vehicle.fuelType = old.fuelType }
                    if vehicle.dailyFuelLiters <= 0 && old.dailyFuelLiters > 0 { vehicle.dailyFuelLiters = old.dailyFuelLiters }
                    if vehicle.dailyFuelPer100km <= 0 && old.dailyFuelPer100km > 0 { vehicle.dailyFuelPer100km = old.dailyFuelPer100km }
                    if vehicle.fuelPer100km <= 0 && old.fuelPer100km > 0 { vehicle.fuelPer100km = old.fuelPer100km }
                    if vehicle.deviceId == 0 && old.deviceId > 0 { vehicle.deviceId = old.deviceId }
                    // Re-apply cached driver name
                    if let code = vehicle.driverId, !code.isEmpty,
                       let name = driverNameCache[code], !name.isEmpty {
                        vehicle.driverName = name
                    }
                }
                newVehicles[vehicle.imei] = vehicle
                newOrder.append(vehicle.imei)
            }
        }

        vehicles = newVehicles
        orderList = newOrder

        rebuildVehicleList()

        status = .connected
        startHealthCheckTimer()
        eventSubject.send(.statusChanged(.connected))
        eventSubject.send(.snapshot(vehicles: vehicleList, count: vehicleList.count, ts: ts))

        // Fetch driver names + device IDs from API and enrich vehicles
        enrichVehicleData()
    }

    /// Fetches driver names and device IDs from API, then enriches all vehicles
    private func enrichVehicleData() {
        Task {
            // Fetch drivers and catalog in parallel
            async let driversResult = APIService.shared.fetchDrivers()
            async let catalogResult = APIService.shared.fetchDriverCatalog()

            // Driver names
            do {
                let response = try await driversResult
                var cache: [String: String] = [:]
                for driver in response.drivers {
                    if !driver.driverCode.isEmpty && !driver.name.isEmpty {
                        cache[driver.driverCode] = driver.name
                    }
                }
                self.driverNameCache = cache
            } catch {
                print("[WS] fetchDrivers error: \(error)")
            }

            // Device IDs (catalog returns [{id: Int, imei: String, ...}])
            do {
                let vehicles = try await catalogResult
                var cache: [String: Int] = [:]
                for v in vehicles {
                    if let id = v["id"] as? Int, let imei = v["imei"] as? String, !imei.isEmpty {
                        cache[imei] = id
                    }
                }
                self.deviceIdCache = cache
            } catch {
                print("[WS] fetchCatalog error: \(error)")
            }

            // Apply enrichment to all vehicles
            applyEnrichment()
        }
    }

    /// Apply cached driver names and device IDs to all vehicles
    private func applyEnrichment() {
        var changed = false
        for (imei, vehicle) in vehicles {
            var updated = vehicle
            var modified = false

            // Apply driver name
            if let code = vehicle.driverId, !code.isEmpty,
               let name = driverNameCache[code], !name.isEmpty,
               vehicle.driverName != name {
                updated.driverName = name
                modified = true
            }

            // Apply device ID
            if vehicle.deviceId == 0, let deviceId = deviceIdCache[imei], deviceId > 0 {
                updated.deviceId = deviceId
                modified = true
            }

            if modified {
                vehicles[imei] = updated
                changed = true
            }
        }
        if changed {
            rebuildVehicleList()
        }
    }

    private func handleUpdate(_ json: [String: Any]) {
        let vehicleJson = (json["vehicle"] as? [String: Any]) ?? json
        let ts = (json["ts"] as? Int) ?? 0

        guard let patch = Vehicle.fromWSPayload(vehicleJson) else { return }

        awaitingSnapshot = false
        clearSnapshotTimer()

        if var existing = vehicles[patch.imei] {
            existing.mergeUpdate(from: patch)
            // Preserve/apply cached driver name
            if let code = existing.driverId, !code.isEmpty,
               let name = driverNameCache[code], !name.isEmpty {
                existing.driverName = name
            }
            // Apply cached device ID
            if existing.deviceId == 0, let deviceId = deviceIdCache[patch.imei], deviceId > 0 {
                existing.deviceId = deviceId
            }
            vehicles[patch.imei] = existing
        } else {
            var newVehicle = patch
            if let code = newVehicle.driverId, !code.isEmpty,
               let name = driverNameCache[code], !name.isEmpty {
                newVehicle.driverName = name
            }
            if newVehicle.deviceId == 0, let deviceId = deviceIdCache[patch.imei], deviceId > 0 {
                newVehicle.deviceId = deviceId
            }
            vehicles[patch.imei] = newVehicle
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

        consecutiveFailures += 1

        // After too many consecutive failures, stop reconnecting
        if consecutiveFailures >= Self.maxConsecutiveFailures {
            status = .error("Bağlantı kurulamadı")
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
        stopHealthCheckTimer()
    }
}
