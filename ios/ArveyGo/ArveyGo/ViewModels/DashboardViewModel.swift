import SwiftUI
import Combine

// MARK: - Dashboard ViewModel
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var drivers: [DriverScore] = []
    @Published var alerts: [AlarmEvent] = []
    @Published var vehiclesErrorMessage: String?
    @Published var alertsErrorMessage: String?
    @Published var selectedPeriod: String = "today"
    @Published var isLoading = true
    @Published var isRefreshing = false
    @Published var isLoadingDrivers = false
    @Published var isLoadingDailyKm = true
    @Published var isLoadingAlerts = false

    private var cancellables = Set<AnyCancellable>()
    private let wsManager = WebSocketManager.shared

    var totalVehicles: Int { vehicles.count }
    /// Kontak açık: ignition == true (online + idle)
    var kontakOnCount: Int { vehicles.filter { $0.ignition }.count }
    /// Kontak kapalı: isOnline ama ignition == false
    var kontakOffCount: Int { vehicles.filter { $0.isOnline && !$0.ignition }.count }
    /// Bilgi yok: isOnline == false (cihazdan veri gelmiyor)
    var bilgiYokCount: Int { vehicles.filter { !$0.isOnline }.count }
    var onlineCount: Int { vehicles.filter { $0.status == .ignitionOn }.count }
    var offlineCount: Int { vehicles.filter { $0.status == .ignitionOff || $0.status == .noData }.count }
    var idleCount: Int { vehicles.filter { $0.status == .sleeping }.count }
    var totalKm: Int { vehicles.reduce(0) { $0 + $1.totalKm } }
    var todayKm: Int { vehicles.reduce(0) { $0 + $1.todayKm } }
    var avgScore: Int {
        guard !drivers.isEmpty else { return 0 }
        return drivers.reduce(0) { $0 + $1.score } / drivers.count
    }

    var metrics: [DashboardMetric] {
        [
            DashboardMetric(
                title: "Toplam Araç",
                value: "\(totalVehicles)",
                icon: "car.fill",
                iconBg: AppTheme.navy.opacity(0.06),
                iconColor: AppTheme.navy,
                change: "Değişim yok",
                changeType: .flat
            ),
            DashboardMetric(
                title: "Kontak Açık",
                value: "\(kontakOnCount)",
                icon: "key.fill",
                iconBg: AppTheme.online.opacity(0.08),
                iconColor: AppTheme.online,
                change: "",
                changeType: .flat
            ),
            DashboardMetric(
                title: "Kontak Kapalı",
                value: "\(kontakOffCount)",
                icon: "key",
                iconBg: AppTheme.idle.opacity(0.08),
                iconColor: AppTheme.idle,
                change: "",
                changeType: .flat
            ),
            DashboardMetric(
                title: "Bilgi Yok",
                value: "\(bilgiYokCount)",
                icon: "questionmark.circle.fill",
                iconBg: AppTheme.offline.opacity(0.08),
                iconColor: AppTheme.offline,
                change: "",
                changeType: .flat
            ),
            DashboardMetric(
                title: "Bugün Km",
                value: formatKm(todayKm),
                icon: "road.lanes",
                iconBg: AppTheme.indigo.opacity(0.08),
                iconColor: AppTheme.indigo,
                change: "",
                changeType: .flat
            ),
        ]
    }

    init() {
        subscribeToWebSocket()
        loadVehiclesFromAPI()
        loadDriversFromAPI()
        loadAlertsFromAPI()
    }

    // MARK: - WebSocket Subscription
    private func subscribeToWebSocket() {
        // Observe vehicle list from WebSocketManager
        wsManager.$vehicleList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                guard let self = self else { return }
                if !list.isEmpty {
                    // Mevcut araç değerlerini koruyarak güncelle (null sıcaklık/nem için)
                    let currentMap = Dictionary(uniqueKeysWithValues: self.vehicles.map { ($0.id, $0) })
                    self.vehicles = list.map { newVehicle in
                        if var existing = currentMap[newVehicle.id] {
                            existing.mergeUpdate(from: newVehicle)
                            return existing
                        }
                        return newVehicle
                    }
                    self.vehiclesErrorMessage = nil
                    self.isLoading = false
                    self.isLoadingDailyKm = false
                }
            }
            .store(in: &cancellables)

        // Also listen for individual events
        wsManager.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .snapshot(let vehicles, _, _):
                    let currentMap = Dictionary(uniqueKeysWithValues: self.vehicles.map { ($0.id, $0) })
                    self.vehicles = vehicles.map { newVehicle in
                        if var existing = currentMap[newVehicle.id] {
                            existing.mergeUpdate(from: newVehicle)
                            return existing
                        }
                        return newVehicle
                    }
                    self.vehiclesErrorMessage = nil
                    self.isLoading = false
                    self.isLoadingDailyKm = false
                case .update(let vehicle, _):
                    if let idx = self.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
                        self.vehicles[idx].mergeUpdate(from: vehicle)
                    } else {
                        self.vehicles.append(vehicle)
                    }
                default: break
                }
            }
            .store(in: &cancellables)
    }

    func formatKm(_ km: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: km)) ?? "\(km)"
    }

    /// Fetch vehicle list from REST API and merge dailyKm data
    func loadVehiclesFromAPI() {
        isLoadingDailyKm = true
        vehiclesErrorMessage = nil
        Task {
            do {
                let apiVehicles = try await APIService.shared.fetchVehicles()
                // Merge: prefer WS live positions, but take dailyKm from API
                let currentMap = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id, $0) })
                let merged = apiVehicles.map { apiV -> Vehicle in
                    if var existing = currentMap[apiV.id] {
                        existing.mergeUpdate(from: apiV)
                        if apiV.dailyKm > existing.dailyKm { existing.dailyKm = apiV.dailyKm }
                        if apiV.todayKm > existing.todayKm { existing.todayKm = apiV.todayKm }
                        return existing
                    }
                    return apiV
                }
                vehicles = merged
                vehiclesErrorMessage = nil
                isLoading = false
                isLoadingDailyKm = false
            } catch {
                print("[DashboardVM] fetchVehicles error: \(error)")
                vehiclesErrorMessage = error.localizedDescription
                isLoading = false
                isLoadingDailyKm = false
            }
        }
    }

    /// Load drivers from API and convert to DriverScore for dashboard display
    func loadDriversFromAPI() {
        isLoadingDrivers = true
        Task {
            do {
                let response = try await APIService.shared.fetchDrivers()
                let avatarColors: [SwiftUI.Color] = [
                    AppTheme.navy, AppTheme.indigo, AppTheme.online, .blue,
                    AppTheme.idle, AppTheme.lavender, AppTheme.offline, .gray,
                    .purple, .orange, .teal, .pink
                ]
                let scores: [DriverScore] = response.drivers
                    .sorted { $0.scoreGeneral > $1.scoreGeneral }
                    .enumerated()
                    .map { (index, driver) in
                        DriverScore(
                            id: driver.id,
                            name: driver.name,
                            plate: driver.vehicle.isEmpty ? driver.lastVehicle : driver.vehicle,
                            score: driver.scoreGeneral,
                            totalKm: Int(driver.totalDistanceKm),
                            color: avatarColors[index % avatarColors.count]
                        )
                    }
                await MainActor.run {
                    self.drivers = scores
                    self.isLoadingDrivers = false
                }
            } catch {
                print("[DashboardVM] fetchDrivers error: \(error)")
                await MainActor.run {
                    self.isLoadingDrivers = false
                }
            }
        }
    }

    /// Load alerts from API
    func loadAlertsFromAPI() {
        isLoadingAlerts = true
        alertsErrorMessage = nil
        Task {
            do {
                let json = try await APIService.shared.get("/api/mobile/alarms?per_page=5")
                let dataArr = json["data"] as? [[String: Any]] ?? []
                let alertList = dataArr.enumerated().map { index, item in
                    AlarmEvent.from(json: item, index: index)
                }
                await MainActor.run {
                    self.alerts = alertList
                    self.alertsErrorMessage = nil
                    self.isLoadingAlerts = false
                }
            } catch {
                print("[DashboardVM] fetchAlarms error: \(error)")
                await MainActor.run {
                    self.alerts = []
                    self.alertsErrorMessage = "Alarm verisi şu anda alınamıyor."
                    self.isLoadingAlerts = false
                }
            }
        }
    }

    func setPeriod(_ period: String) {
        selectedPeriod = period
        // In real app, this would fetch data for the period
    }

    /// Pull-to-refresh: WS'yi yeniden bağla ve verileri yenile
    func refreshData() {
        isRefreshing = true
        wsManager.reconnect()
        loadVehiclesFromAPI()
        loadDriversFromAPI()
        loadAlertsFromAPI()
        // 2 saniye sonra refreshing durumunu kapat
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isRefreshing = false
        }
    }
}
