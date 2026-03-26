import SwiftUI
import MapKit
import Combine

// MARK: - Live Vehicle Observer
/// Observes WebSocket updates for a specific vehicle and publishes changes.
@MainActor
class VehicleDetailObserver: ObservableObject {
    @Published var vehicle: Vehicle
    @Published var driverName: String = ""
    @Published var driverPhone: String = ""
    private var cancellables = Set<AnyCancellable>()

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        subscribeToUpdates()
        fetchDriverInfo()
    }

    func fetchDriverInfo() {
        guard vehicle.deviceId > 0 else { return }
        Task {
            do {
                let detail = try await APIService.shared.fetchVehicleDetail(deviceId: vehicle.deviceId)
                if let driverDict = detail["driver"] as? [String: Any] {
                    let name = driverDict["name"] as? String ?? ""
                    let phone = driverDict["phone"] as? String ?? ""
                    await MainActor.run {
                        self.driverName = name
                        self.driverPhone = phone
                    }
                }
            } catch {
                print("[VehicleDetail] fetchDriverInfo error: \(error)")
            }
        }
    }

    private func subscribeToUpdates() {
        let targetId = vehicle.id
        let targetImei = vehicle.imei

        WebSocketManager.shared.$vehicleList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] vehicles in
                guard let self = self else { return }
                if let updated = vehicles.first(where: { $0.id == targetId || (!targetImei.isEmpty && $0.imei == targetImei) }) {
                    self.vehicle = updated
                }
            }
            .store(in: &cancellables)

        WebSocketManager.shared.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                if case .update(let updatedVehicle, _) = event,
                   updatedVehicle.id == targetId || (!targetImei.isEmpty && updatedVehicle.imei == targetImei) {
                    self.vehicle = updatedVehicle
                }
            }
            .store(in: &cancellables)
    }
}

struct VehicleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var observer: VehicleDetailObserver
    @State private var selectedTab: DetailTab = .overview
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var showDriverAssign = false

    /// Navigation callbacks for quick actions
    var onNavigateToRouteHistory: ((Vehicle) -> Void)?
    var onNavigateToAlarms: (() -> Void)?

    private var vehicle: Vehicle { observer.vehicle }

    init(vehicle: Vehicle, onNavigateToRouteHistory: ((Vehicle) -> Void)? = nil, onNavigateToAlarms: (() -> Void)? = nil) {
        _observer = StateObject(wrappedValue: VehicleDetailObserver(vehicle: vehicle))
        self.onNavigateToRouteHistory = onNavigateToRouteHistory
        self.onNavigateToAlarms = onNavigateToAlarms
    }

    enum DetailTab: String, CaseIterable {
        case overview = "Genel"
        case maintenance = "Bakım"
        case costs = "Masraf"
        case events = "Olaylar"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Map Header
                        mapHeader

                        // Vehicle Identity Card
                        vehicleIdentityCard
                            .padding(.horizontal, 16)
                            .offset(y: -30)

                        // Tab Selector
                        tabSelector
                            .padding(.horizontal, 16)
                            .padding(.top, -14)

                        // Tab Content
                        Group {
                            switch selectedTab {
                            case .overview:
                                overviewTab
                            case .maintenance:
                                maintenanceTab
                            case .costs:
                                costsTab
                            case .events:
                                eventsTab
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Geri")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppTheme.navy)
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(vehicle.plate)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                        Text("Araç Detayı")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if vehicle.isMotorcycle {
                        NavigationLink(destination: MotorcycleSettingsView(vehicle: vehicle)) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.online)
                        }
                    }
                }
            }
            .onAppear {
                mapCameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
        }
    }

    // MARK: - Map Header
    var mapHeader: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $mapCameraPosition) {
                Annotation(vehicle.plate, coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)) {
                    VehicleMapPinDetail(vehicle: vehicle)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .frame(height: 200)
            .allowsHitTesting(false)

            // Status overlay
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(vehicle.status.color)
                        .frame(width: 7, height: 7)
                    Text(vehicle.status == .online ? "Canlı" : vehicle.status.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(vehicle.status.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .cornerRadius(20)

                HStack(spacing: 5) {
                    Image(systemName: vehicle.kontakOn ? "key.fill" : "key")
                        .font(.system(size: 9))
                    Text(vehicle.kontakOn ? "Kontak Açık" : "Kontak Kapalı")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(vehicle.kontakOn ? AppTheme.online : AppTheme.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }
            .padding(12)
        }
    }

    // MARK: - Vehicle Identity Card
    var vehicleIdentityCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(vehicle.status.color.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: vehicle.isMotorcycle ? "bicycle" : "car.fill")
                        .font(.system(size: 22))
                        .foregroundColor(vehicle.status.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(vehicle.plate)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.navy)
                        StatusBadge(status: vehicle.status)
                    }
                    Text(vehicle.model)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textMuted)

                    HStack(spacing: 6) {
                        vehicleTag(vehicle.group, icon: "folder.fill", color: .blue)
                        vehicleTag(vehicle.vehicleType, icon: vehicle.isMotorcycle ? "bicycle" : "car.2.fill", color: .purple)
                    }
                    .padding(.top, 2)
                }
                Spacer()
            }
            .padding(16)

            Divider()

            HStack(spacing: 0) {
                quickStatItem(icon: "speedometer", value: vehicle.formattedTotalKm, label: "Toplam Km", color: AppTheme.navy)
                Divider().frame(height: 40)
                quickStatItem(icon: "road.lanes", value: vehicle.formattedTodayKm, label: "Bugün", color: AppTheme.indigo)
                Divider().frame(height: 40)
                quickStatItem(icon: "person.fill", value: !observer.driverName.isEmpty ? observer.driverName.components(separatedBy: " ").first ?? "—" : (vehicle.driver.isEmpty ? "—" : vehicle.driver.components(separatedBy: " ").first ?? "—"), label: "Sürücü", color: AppTheme.online)
                Divider().frame(height: 40)
                quickStatItem(icon: "mappin.circle.fill", value: vehicle.city, label: "Konum", color: .orange)
            }
            .padding(.vertical, 12)
        }
        .background(AppTheme.surface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    func vehicleTag(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.08))
        .cornerRadius(20)
    }

    func quickStatItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab Selector
    var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                }) {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedTab == tab ? AppTheme.navy : AppTheme.textMuted)

                        Rectangle()
                            .fill(selectedTab == tab ? AppTheme.indigo : Color.clear)
                            .frame(height: 2.5)
                            .cornerRadius(2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .background(AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Overview Tab
    var overviewTab: some View {
        VStack(spacing: 16) {
            // Device Time (matching vehicles list style)
            if vehicle.deviceTime != nil {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.indigo)
                    Text("Son Bilgi Tarihi")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.navy)
                    Spacer()
                    Text("⏱ \(vehicle.formattedDeviceTime)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.bg)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.borderSoft, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.borderSoft, lineWidth: 1)
                )
            }

            sectionCard(title: "ARAÇ BİLGİLERİ", icon: "car.fill") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    infoCell(icon: "folder.fill", label: "GRUP", value: vehicle.group)
                    infoCell(icon: "speedometer", label: "KİLOMETRE", value: vehicle.formattedTotalKm + " km")
                    infoCell(icon: "gauge.open.with.lines.needle.33percent", label: "HIZ", value: vehicle.formattedSpeed)
                    infoCell(icon: "mappin.circle.fill", label: "KONUM", value: vehicle.city)
                    infoCell(icon: "car.2.fill", label: "ARAÇ TİPİ", value: vehicle.vehicleType)
                }
            }

            // Kontak / Ignition Details
            sectionCard(title: "KONTAK BİLGİLERİ", icon: "key.fill") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    infoCell(
                        icon: vehicle.kontakOn ? "key.fill" : "key",
                        label: "KONTAK DURUMU",
                        value: vehicle.kontakLabel,
                        valueColor: vehicle.kontakOn ? AppTheme.online : AppTheme.offline
                    )
                    infoCell(icon: "sunrise.fill", label: "İLK KONTAK (BUGÜN)", value: vehicle.formattedFirstIgnitionToday)
                    infoCell(icon: "key.fill", label: "SON KONTAK AÇMA", value: vehicle.formattedLastIgnitionOn)
                    infoCell(icon: "key", label: "SON KONTAK KAPAMA", value: vehicle.formattedLastIgnitionOff)
                }
            }

            // Sıcaklık & Sensör Bilgileri
            if vehicle.temperatureC != nil || vehicle.humidityPct != nil {
                sectionCard(title: "SICAKLIK & SENSÖR", icon: "thermometer.medium") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        if let temp = vehicle.temperatureC {
                            infoCell(icon: "thermometer.medium", label: "SICAKLIK", value: String(format: "%.1f°C", temp))
                        }
                        if let hum = vehicle.humidityPct {
                            infoCell(icon: "humidity.fill", label: "NEM", value: "%\(Int(hum))")
                        }
                    }
                }
            }

            sectionCard(title: "SÜRÜCÜ BİLGİLERİ", icon: "person.fill") {
                let displayName = !observer.driverName.isEmpty ? observer.driverName : (vehicle.driver.isEmpty ? "" : vehicle.driver)
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.indigo.opacity(0.1))
                            .frame(width: 50, height: 50)
                        Text(String(displayName.prefix(1)))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.indigo)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName.isEmpty ? "Sürücü Atanmamış" : displayName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.navy)
                        Text("Atanmış Sürücü")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }

                    Spacer()

                    Button(action: { showDriverAssign = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                            Text("Değiştir")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.indigo)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.indigo.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(14)
                .background(AppTheme.bg)
                .cornerRadius(10)
            }
            .sheet(isPresented: $showDriverAssign) {
                VehicleDriverAssignSheet(
                    vehicleId: vehicle.deviceId,
                    currentDriverName: !observer.driverName.isEmpty ? observer.driverName : vehicle.driver,
                    onAssigned: {
                        observer.fetchDriverInfo()
                    }
                )
            }

            sectionCard(title: "HIZLI İŞLEMLER", icon: "bolt.fill") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    actionButton(icon: "location.fill", label: "Konuma\nGit", color: .blue) {
                        openMapsDirections(lat: vehicle.lat, lng: vehicle.lng, label: vehicle.plate)
                    }
                    actionButton(icon: "clock.arrow.circlepath", label: "Rota\nGeçmişi", color: AppTheme.indigo) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            onNavigateToRouteHistory?(vehicle)
                        }
                    }
                    actionButton(icon: "bell.fill", label: "Alarm\nKur", color: .orange) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            onNavigateToAlarms?()
                        }
                    }
                    actionButton(icon: "lock.fill", label: "Blokaj\nGönder", color: .red) {}
                    actionButton(icon: "wrench.fill", label: "Bakım\nEkle", color: AppTheme.online) {}
                    actionButton(icon: "doc.text.fill", label: "Belge\nEkle", color: .purple) {}
                    actionButton(icon: "fuelpump.fill", label: "Yakıt\nKayıt", color: .cyan) {}
                    actionButton(icon: "square.and.arrow.up", label: "Paylaş", color: AppTheme.textMuted) {
                        shareVehicleLocation(vehicle: vehicle)
                    }
                }
            }
        }
    }

    // MARK: - Maintenance Tab
    var maintenanceTab: some View {
        VStack(spacing: 16) {
            sectionCard(title: "BAKIM TAKVİMİ", icon: "wrench.and.screwdriver.fill") {
                VStack(spacing: 0) {
                    maintenanceRow(icon: "wrench.fill", title: "Periyodik Bakım", date: vehicle.nextService, status: .upcoming, km: "Her 10.000 km")
                    Divider().padding(.leading, 44)
                    maintenanceRow(icon: "circle.circle.fill", title: "Lastik Değişimi", date: "15.06.2026", status: .normal, km: "Her 40.000 km")
                    Divider().padding(.leading, 44)
                    maintenanceRow(icon: "drop.fill", title: "Yağ Değişimi", date: vehicle.lastService, status: .completed, km: "Her 15.000 km")
                    Divider().padding(.leading, 44)
                    maintenanceRow(icon: "bolt.fill", title: "Akü Kontrolü", date: "20.07.2026", status: .normal, km: "Yıllık")
                }
            }

            sectionCard(title: "BELGELER", icon: "doc.text.fill") {
                VStack(spacing: 0) {
                    documentRow(title: "Muayene", date: vehicle.muayeneDate, daysLeft: 85, status: .normal)
                    Divider().padding(.leading, 14)
                    documentRow(title: "Kasko", date: vehicle.insuranceDate, daysLeft: 120, status: .normal)
                    Divider().padding(.leading, 14)
                    documentRow(title: "Trafik Sigortası", date: "10.05.2026", daysLeft: 48, status: .warning)
                    Divider().padding(.leading, 14)
                    documentRow(title: "K Belgesi", date: "01.04.2026", daysLeft: 9, status: .critical)
                }
            }
        }
    }

    // MARK: - Costs Tab
    var costsTab: some View {
        VStack(spacing: 16) {
            sectionCard(title: "MASRAF ÖZETİ (2026)", icon: "chart.bar.fill") {
                HStack(spacing: 0) {
                    costSummaryItem(label: "Yakıt", amount: "₺14.200", color: .orange, percent: 45)
                    costSummaryItem(label: "Bakım", amount: "₺8.500", color: .blue, percent: 27)
                    costSummaryItem(label: "Sigorta", amount: "₺5.800", color: .purple, percent: 18)
                    costSummaryItem(label: "Diğer", amount: "₺3.100", color: AppTheme.textMuted, percent: 10)
                }
                .padding(.vertical, 8)

                HStack {
                    Text("TOPLAM")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                    Text("₺31.600")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                }
                .padding(14)
                .background(AppTheme.navy.opacity(0.04))
                .cornerRadius(10)
            }

            sectionCard(title: "SON MASRAFLAR", icon: "list.bullet.rectangle") {
                VStack(spacing: 0) {
                    ForEach(vehicle.recentCosts) { cost in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(costCategoryColor(cost.category).opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Image(systemName: costCategoryIcon(cost.category))
                                    .font(.system(size: 14))
                                    .foregroundColor(costCategoryColor(cost.category))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(cost.category)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.navy)
                                Text(cost.date)
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textMuted)
                            }

                            Spacer()

                            Text(cost.amount)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.navy)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)

                        if cost.id != vehicle.recentCosts.last?.id {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Events Tab
    var eventsTab: some View {
        VStack(spacing: 16) {
            sectionCard(title: "SON OLAYLAR", icon: "clock.fill") {
                VStack(spacing: 0) {
                    eventRow(icon: "location.fill", title: "Geofence Çıkışı", subtitle: "İstanbul → Ankara yolu", time: "Bugün 14:32", severity: .amber)
                    Divider().padding(.leading, 48)
                    eventRow(icon: "speedometer", title: "Hız İhlali", subtitle: "132 km/h (Limit: 110 km/h)", time: "Bugün 11:45", severity: .red)
                    Divider().padding(.leading, 48)
                    eventRow(icon: "key.fill", title: "Kontak Açıldı", subtitle: vehicle.city, time: "Bugün 08:15", severity: .green)
                    Divider().padding(.leading, 48)
                    eventRow(icon: "key", title: "Kontak Kapatıldı", subtitle: vehicle.city, time: "Dün 19:30", severity: .blue)
                    Divider().padding(.leading, 48)
                    eventRow(icon: "pause.circle.fill", title: "5 dk Rölanti", subtitle: "Ankara - Çankaya", time: "Dün 15:12", severity: .amber)
                    Divider().padding(.leading, 48)
                    eventRow(icon: "fuelpump.fill", title: "Yakıt Doldurma", subtitle: "45 Lt Dizel", time: "Dün 09:40", severity: .blue)
                    Divider().padding(.leading, 48)
                    eventRow(icon: "exclamationmark.triangle.fill", title: "Ani Fren", subtitle: "E-5 Karayolu", time: "22.03.2026 16:20", severity: .red)
                }
            }
        }
    }

    // MARK: - Helper Views

    func sectionCard(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.indigo)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.textMuted)
                    .tracking(0.5)
                Spacer()
            }
            content()
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }

    func infoCell(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.indigo)
                .frame(width: 26, height: 26)
                .background(AppTheme.indigo.opacity(0.08))
                .cornerRadius(7)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppTheme.textFaint)
                    .tracking(0.3)
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(valueColor ?? AppTheme.navy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(10)
        .background(AppTheme.bg)
        .cornerRadius(10)
    }

    func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.08))
                    .cornerRadius(12)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // Maintenance helpers
    enum MaintenanceStatus {
        case completed, upcoming, normal, overdue

        var color: Color {
            switch self {
            case .completed: return AppTheme.online
            case .upcoming: return .orange
            case .normal: return .blue
            case .overdue: return .red
            }
        }

        var label: String {
            switch self {
            case .completed: return "Tamamlandı"
            case .upcoming: return "Yaklaşıyor"
            case .normal: return "Planlandı"
            case .overdue: return "Gecikmiş"
            }
        }
    }

    func maintenanceRow(icon: String, title: String, date: String, status: MaintenanceStatus, km: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(status.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
                HStack(spacing: 8) {
                    Text(date)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(AppTheme.textFaint)
                    Text(km)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
            }

            Spacer()

            Text(status.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(status.color.opacity(0.1))
                .cornerRadius(20)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }

    enum DocStatus {
        case normal, warning, critical

        var color: Color {
            switch self {
            case .normal: return AppTheme.online
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }

    func documentRow(title: String, date: String, daysLeft: Int, status: DocStatus) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
                Text("Bitiş: \(date)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(daysLeft) gün")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(status.color)
                Text("kalan")
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.textMuted)
            }

            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }

    func costSummaryItem(label: String, amount: String, color: Color, percent: Int) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 60)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 32, height: CGFloat(percent) / 100.0 * 60.0)
            }
            Text(amount)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.navy)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    func costCategoryColor(_ category: String) -> Color {
        switch category {
        case "Yakıt": return .orange
        case "Bakım": return .blue
        case "Sigorta": return .purple
        default: return AppTheme.textMuted
        }
    }

    func costCategoryIcon(_ category: String) -> String {
        switch category {
        case "Yakıt": return "fuelpump.fill"
        case "Bakım": return "wrench.fill"
        case "Sigorta": return "shield.fill"
        default: return "ellipsis"
        }
    }

    // MARK: - Open Maps Directions
    private func openMapsDirections(lat: Double, lng: Double, label: String) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = label
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: - Share Vehicle Location
    private func shareVehicleLocation(vehicle: Vehicle) {
        let mapsURL = "https://www.google.com/maps?q=\(vehicle.lat),\(vehicle.lng)"
        let message = """
        📍 \(vehicle.plate) - Anlık Konum
        🚗 \(vehicle.model)
        📊 Hız: \(vehicle.formattedSpeed)
        🔑 \(vehicle.kontakLabel)
        🗺️ \(mapsURL)
        """
        let activityVC = UIActivityViewController(activityItems: [message.trimmingCharacters(in: .whitespaces)], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }

    func eventRow(icon: String, title: String, subtitle: String, time: String, severity: AlertSeverity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(severity.color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(severity.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }

            Spacer()

            Text(time)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textFaint)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}

// MARK: - Vehicle Map Pin for Detail
struct VehicleMapPinDetail: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(vehicle.status.color)
                    .frame(width: 36, height: 36)
                    .shadow(color: vehicle.status.color.opacity(0.4), radius: 6, y: 2)
                Image(systemName: "car.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }

            Text(vehicle.plate)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.navy)
                .cornerRadius(4)
                .offset(y: 2)
        }
    }
}

#Preview {
    VehicleDetailView(vehicle: Vehicle(
        id: "1", plate: "34 ABC 123", model: "Ford Transit",
        status: .online, kontakOn: true, totalKm: 48320, todayKm: 312,
        driver: "Ahmet Yılmaz", city: "İstanbul", lat: 41.0082, lng: 28.9784
    ))
}
