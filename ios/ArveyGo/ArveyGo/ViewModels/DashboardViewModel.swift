import SwiftUI
import Combine

// MARK: - Dashboard ViewModel
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var drivers: [DriverScore] = []
    @Published var alerts: [FleetAlert] = []
    @Published var selectedPeriod: String = "today"
    @Published var isLoading = false
    @Published var isRefreshing = false

    private var cancellables = Set<AnyCancellable>()
    private let wsManager = WebSocketManager.shared

    var totalVehicles: Int { vehicles.count }
    /// Kontak açık: ignition == true (online + idle)
    var kontakOnCount: Int { vehicles.filter { $0.ignition }.count }
    /// Kontak kapalı: isOnline ama ignition == false
    var kontakOffCount: Int { vehicles.filter { $0.isOnline && !$0.ignition }.count }
    /// Bilgi yok: isOnline == false (cihazdan veri gelmiyor)
    var bilgiYokCount: Int { vehicles.filter { !$0.isOnline }.count }
    var onlineCount: Int { vehicles.filter { $0.status == .online }.count }
    var offlineCount: Int { vehicles.filter { $0.status == .offline }.count }
    var idleCount: Int { vehicles.filter { $0.status == .idle }.count }
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
        loadDriversFromAPI()
        loadDummyAlerts()
    }

    // MARK: - WebSocket Subscription
    private func subscribeToWebSocket() {
        // Observe vehicle list from WebSocketManager
        wsManager.$vehicleList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                guard let self = self else { return }
                if !list.isEmpty {
                    self.vehicles = list
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
                    self.vehicles = vehicles
                case .update(let vehicle, _):
                    if let idx = self.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
                        self.vehicles[idx] = vehicle
                    } else {
                        self.vehicles.append(vehicle)
                    }
                default: break
                }
            }
            .store(in: &cancellables)

        // Fallback: load dummy vehicle data after 3 seconds if no WS data
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self, self.vehicles.isEmpty else { return }
            self.loadDummyData()
        }
    }

    func formatKm(_ km: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: km)) ?? "\(km)"
    }

    func loadDummyData() {
        // Same dummy data as the Laravel dashboard (vehicle fallback)
        vehicles = [
            Vehicle(id: "1", plate: "34 ABC 123", model: "Ford Transit", status: .online, kontakOn: true, totalKm: 48320, todayKm: 312, driver: "Ahmet Yılmaz", city: "İstanbul", lat: 41.0082, lng: 28.9784),
            Vehicle(id: "2", plate: "06 XYZ 789", model: "Mercedes Sprinter", status: .offline, kontakOn: false, totalKm: 92100, todayKm: 0, driver: "Mehmet Demir", city: "Ankara", lat: 39.9334, lng: 32.8597),
            Vehicle(id: "3", plate: "35 DEF 456", model: "Renault Master", status: .online, kontakOn: true, totalKm: 31540, todayKm: 187, driver: "Ayşe Kaya", city: "İzmir", lat: 38.4192, lng: 27.1287),
            Vehicle(id: "4", plate: "16 GHI 321", model: "Volkswagen Crafter", status: .idle, kontakOn: false, totalKm: 67890, todayKm: 0, driver: "Can Öztürk", city: "Bursa", lat: 40.1885, lng: 29.0610),
            Vehicle(id: "5", plate: "41 JKL 654", model: "Fiat Ducato", status: .online, kontakOn: true, totalKm: 22430, todayKm: 95, driver: "Zeynep Şahin", city: "Kocaeli", lat: 40.7654, lng: 29.9408),
            Vehicle(id: "6", plate: "07 MNO 987", model: "Peugeot Boxer", status: .offline, kontakOn: false, totalKm: 55670, todayKm: 0, driver: "Ali Çelik", city: "Antalya", lat: 36.8969, lng: 30.7133),
            Vehicle(id: "7", plate: "34 PRS 111", model: "Iveco Daily", status: .online, kontakOn: true, totalKm: 14220, todayKm: 241, driver: "Fatma Arslan", city: "İstanbul", lat: 41.0422, lng: 29.0083),
            Vehicle(id: "8", plate: "06 TUV 222", model: "Ford Transit Custom", status: .idle, kontakOn: false, totalKm: 38900, todayKm: 0, driver: "Hasan Koç", city: "Ankara", lat: 39.9208, lng: 32.8541),
        ]
    }

    /// Load drivers from API and convert to DriverScore for dashboard display
    func loadDriversFromAPI() {
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
                }
            } catch {
                print("[DashboardVM] fetchDrivers error: \(error)")
                // Fallback: keep empty (no dummy data)
            }
        }
    }

    /// Load dummy alerts (alerts API not yet available)
    func loadDummyAlerts() {
        alerts = [
            FleetAlert(id: "1", title: "Hız İhlali", description: "34 ABC 123 — 142 km/h, E-5 Karayolu", time: "3 dk", severity: .red),
            FleetAlert(id: "2", title: "Geofence Çıkış", description: "35 DEF 456 — İzmir bölge dışına çıktı", time: "18 dk", severity: .amber),
            FleetAlert(id: "3", title: "Bakım Hatırlatma", description: "07 MNO 987 — Yağ değişim zamanı", time: "1 sa", severity: .blue),
            FleetAlert(id: "4", title: "Seyahat Tamamlandı", description: "41 JKL 654 — Kocaeli → İstanbul", time: "2 sa", severity: .green),
            FleetAlert(id: "5", title: "Ani Fren", description: "34 PRS 111 — Kadıköy civarı", time: "35 dk", severity: .amber),
            FleetAlert(id: "6", title: "Motor Arızası", description: "06 TUV 222 — Check Engine uyarısı", time: "4 sa", severity: .red),
        ]
    }

    func setPeriod(_ period: String) {
        selectedPeriod = period
        // In real app, this would fetch data for the period
    }

    /// Pull-to-refresh: WS'yi yeniden bağla ve verileri yenile
    func refreshData() {
        isRefreshing = true
        wsManager.reconnect()
        loadDriversFromAPI()
        // 2 saniye sonra refreshing durumunu kapat
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isRefreshing = false
        }
    }
}
