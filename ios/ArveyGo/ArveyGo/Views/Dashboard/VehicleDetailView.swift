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
                await MainActor.run {
                    self.enrichVehicleFromDetail(detail)
                }
            } catch {
                print("[VehicleDetail] fetchDriverInfo error: \(error)")
            }
        }
    }

    func enrichVehicleFromDetail(_ detail: [String: Any]) {
        let todayKmVal = (detail["todayKm"] as? Double) ?? (detail["todayKm"] as? Int).map { Double($0) } ?? 0
        let todayDistanceM = (detail["todayDistanceM"] as? Double) ?? (detail["todayDistanceM"] as? Int).map { Double($0) } ?? 0
        let dailyKmApi = (detail["dailyKm"] as? Double) ?? (detail["daily_km"] as? Double) ?? (detail["dailyKm"] as? Int).map { Double($0) } ?? (detail["daily_km"] as? Int).map { Double($0) } ?? 0
        let dailyKmVal = dailyKmApi > 0 ? dailyKmApi : (todayKmVal > 0 ? todayKmVal : (todayDistanceM > 0 ? todayDistanceM / 1000.0 : 0))
        let groupNameVal = detail["groupName"] as? String ?? ""
        let vehicleBrandVal = detail["vehicleBrand"] as? String ?? ""
        let vehicleModelVal = detail["vehicleModel"] as? String ?? ""
        let addressVal = detail["address"] as? String ?? ""
        let cityVal = detail["city"] as? String ?? ""
        let fuelTypeVal = detail["fuelType"] as? String ?? ""
        let dailyFuelLitersVal = (detail["dailyFuelLiters"] as? Double) ?? (detail["dailyFuelLiters"] as? Int).map { Double($0) } ?? 0
        let dailyFuelPer100kmVal = (detail["dailyFuelPer100km"] as? Double) ?? (detail["dailyFuelPer100km"] as? Int).map { Double($0) } ?? 0
        let fuelPer100kmVal = (detail["fuelPer100km"] as? Double) ?? (detail["fuelPer100km"] as? Int).map { Double($0) } ?? 0
        let odometerVal = (detail["odometer"] as? Double) ?? (detail["odometer"] as? Int).map { Double($0) } ?? 0
        let kmVal = (detail["km"] as? Double) ?? (detail["km"] as? Int).map { Double($0) } ?? 0
        let batteryVal = (detail["battery"] as? Double)
            ?? (detail["battery_voltage"] as? Double)
            ?? (detail["battery"] as? Int).map { Double($0) }
            ?? (detail["battery_voltage"] as? Int).map { Double($0) }
        let externalVoltageVal = (detail["externalVoltage"] as? Double)
            ?? (detail["external_voltage"] as? Double)
            ?? (detail["externalVoltage"] as? Int).map { Double($0) }
            ?? (detail["external_voltage"] as? Int).map { Double($0) }
        let powerObj = detail["power"] as? [String: Any]
        let deviceBatteryVal: Double? = {
            if let v = detail["deviceBatteryLevelPct"] as? Double { return v }
            if let v = (detail["deviceBatteryLevelPct"] as? Int).map({ Double($0) }) { return v }
            if let v = detail["battery_level_pct"] as? Double { return v }
            if let v = (detail["battery_level_pct"] as? Int).map({ Double($0) }) { return v }
            if let v = detail["deviceBattery"] as? Double { return v }
            if let v = detail["device_battery"] as? Double { return v }
            if let v = (detail["deviceBattery"] as? Int).map({ Double($0) }) { return v }
            if let v = (detail["device_battery"] as? Int).map({ Double($0) }) { return v }
            if let pw = powerObj, let v = pw["device_battery_level_pct"] as? Double { return v }
            if let pw = powerObj, let v = (pw["device_battery_level_pct"] as? Int).map({ Double($0) }) { return v }
            return nil
        }()

        if dailyKmVal > 0 { vehicle.todayKm = Int(dailyKmVal); vehicle.dailyKm = dailyKmVal }
        if !groupNameVal.isEmpty && groupNameVal != "<null>" { vehicle.groupName = groupNameVal }
        if !vehicleBrandVal.isEmpty && vehicleBrandVal != "<null>" { vehicle.vehicleBrand = vehicleBrandVal }
        if !vehicleModelVal.isEmpty && vehicleModelVal != "<null>" { vehicle.vehicleModel = vehicleModelVal }
        if !addressVal.isEmpty && addressVal != "<null>" { vehicle.address = addressVal }
        if !cityVal.isEmpty && cityVal != "<null>" { vehicle.city = cityVal }
        if !fuelTypeVal.isEmpty && fuelTypeVal != "<null>" { vehicle.fuelType = fuelTypeVal }
        if dailyFuelLitersVal > 0 { vehicle.dailyFuelLiters = dailyFuelLitersVal }
        if dailyFuelPer100kmVal > 0 { vehicle.dailyFuelPer100km = dailyFuelPer100kmVal }
        if fuelPer100kmVal > 0 { vehicle.fuelPer100km = fuelPer100kmVal }
        if odometerVal > 0 { vehicle.totalKm = Int(odometerVal); vehicle.odometer = odometerVal }
        else if kmVal > 0 { vehicle.totalKm = Int(kmVal); vehicle.odometer = kmVal }
        if let v = batteryVal { vehicle.batteryVoltage = v }
        if let v = externalVoltageVal { vehicle.externalVoltage = v }
        if let v = deviceBatteryVal { vehicle.deviceBattery = v }

        // Ignition timestamps from API
        if let v = detail["first_ignition_on_at_today"] as? String, !v.isEmpty, v != "<null>" { vehicle.firstIgnitionOnAtToday = v }
        if let v = detail["last_ignition_on_at"] as? String, !v.isEmpty, v != "<null>" { vehicle.lastIgnitionOnAt = v }
        if let v = detail["last_ignition_off_at"] as? String, !v.isEmpty, v != "<null>" { vehicle.lastIgnitionOffAt = v }
    }

    private var hasFetchedDriverInfo = false

    private func subscribeToUpdates() {
        let targetId = vehicle.id
        let targetImei = vehicle.imei

        WebSocketManager.shared.$vehicleList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] vehicles in
                guard let self = self else { return }
                if let updated = vehicles.first(where: { $0.id == targetId || (!targetImei.isEmpty && $0.imei == targetImei) }) {
                    // Merge WS update but preserve API-enriched fields
                    self.vehicle.mergeUpdate(from: updated)
                    // Use enriched driverName from WS manager if available
                    if !updated.driverName.isEmpty && self.driverName.isEmpty {
                        self.driverName = updated.driverName
                    }
                    // If deviceId became available and we haven't fetched yet, do it now
                    if !self.hasFetchedDriverInfo && updated.deviceId > 0 && self.driverName.isEmpty {
                        self.hasFetchedDriverInfo = true
                        self.fetchDriverInfo()
                    }
                }
            }
            .store(in: &cancellables)

        WebSocketManager.shared.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                if case .update(let updatedVehicle, _) = event,
                   updatedVehicle.id == targetId || (!targetImei.isEmpty && updatedVehicle.imei == targetImei) {
                    self.vehicle.mergeUpdate(from: updatedVehicle)
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
    @State private var showEditSheet = false
    @State private var showBlockageModal = false
    @State private var blockageLoading = false
    @State private var blockageError: String?
    @State private var blockageSuccess: String?

    // Fleet data states
    @State private var fleetMaintenances: [FleetMaintenance] = []
    @State private var fleetDocuments: [FleetDocument] = []
    @State private var fleetCosts: [FleetCost] = []
    @State private var isLoadingMaintenance = false
    @State private var isLoadingCosts = false

    /// Navigation callbacks for quick actions
    var onNavigateToRouteHistory: ((Vehicle) -> Void)?
    var onNavigateToAlarms: ((String) -> Void)?
    var onNavigateToAddAlarm: ((String) -> Void)?

    private var vehicle: Vehicle { observer.vehicle }

    init(vehicle: Vehicle, onNavigateToRouteHistory: ((Vehicle) -> Void)? = nil, onNavigateToAlarms: ((String) -> Void)? = nil, onNavigateToAddAlarm: ((String) -> Void)? = nil) {
        _observer = StateObject(wrappedValue: VehicleDetailObserver(vehicle: vehicle))
        self.onNavigateToRouteHistory = onNavigateToRouteHistory
        self.onNavigateToAlarms = onNavigateToAlarms
        self.onNavigateToAddAlarm = onNavigateToAddAlarm
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
                AppTheme.darkBg.ignoresSafeArea()

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
            .toolbarBackground(AppTheme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Geri")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppTheme.darkText)
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(vehicle.plate)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.darkText)
                        Text("Araç Detayı")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.darkTextMuted)
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
                    Text(!vehicle.livenessStatus.isEmpty ? vehicle.livenessLabel : vehicle.status.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(vehicle.status.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                // Kontak durumu badge kaldırıldı
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
                            .foregroundColor(AppTheme.darkText)
                        StatusBadge(status: vehicle.status)
                    }
                    // name fieldı yorum satırına alındı
                    // Text(vehicle.model)
                    //     .font(.system(size: 13))
                    //     .foregroundColor(AppTheme.textMuted)

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
                quickStatItem(icon: "person.fill", value: {
                    let name = !observer.driverName.isEmpty ? observer.driverName : (!vehicle.driverName.isEmpty ? vehicle.driverName : vehicle.driver)
                    return name.isEmpty ? "—" : (name.components(separatedBy: " ").first ?? "—")
                }(), label: "Sürücü", color: AppTheme.online)
                Divider().frame(height: 40)
                quickStatItem(icon: "mappin.circle.fill", value: vehicle.locationDisplay, label: "Konum", color: .orange)
            }
            .padding(.vertical, 12)
        }
        .background(AppTheme.darkSurface)
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
                .foregroundColor(AppTheme.darkText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.darkTextMuted)
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
                            .foregroundColor(selectedTab == tab ? AppTheme.darkText : AppTheme.darkTextMuted)

                        Rectangle()
                            .fill(selectedTab == tab ? AppTheme.lavender : Color.clear)
                            .frame(height: 2.5)
                            .cornerRadius(2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .background(AppTheme.darkSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.darkBorder, lineWidth: 1)
        )
    }

    // MARK: - Overview Tab
    var overviewTab: some View {
        VStack(spacing: 16) {
            // ── Quick Actions Row (top, prominent) ──
            HStack(spacing: 10) {
                quickActionButton(icon: "location.fill", label: "Yol Tarifi", color: Color(hex: "#3B82F6")) {
                    openMapsDirections(lat: vehicle.lat, lng: vehicle.lng, label: vehicle.plate)
                }
                quickActionButton(icon: "clock.arrow.circlepath", label: "Rota Geçmişi", color: AppTheme.lavender) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        onNavigateToRouteHistory?(vehicle)
                    }
                }
                quickActionButton(icon: "pencil.circle.fill", label: "Düzenle", color: Color(hex: "#8B5CF6")) {
                    showEditSheet = true
                }
                quickActionButton(icon: "lock.shield.fill", label: "Blokaj", color: .red) {
                    blockageError = nil
                    blockageSuccess = nil
                    showBlockageModal = true
                }
            }
            .padding(14)
            .background(AppTheme.darkSurface)
            .cornerRadius(14)
            .sheet(isPresented: $showEditSheet) {
                VehicleEditSheet(vehicle: vehicle) { updatedVehicle in
                    observer.vehicle.plate = updatedVehicle.plate
                    if !updatedVehicle.name.isEmpty { observer.vehicle.name = updatedVehicle.name }
                }
            }
            .sheet(isPresented: $showBlockageModal) {
                BlockageSheet(
                    vehicle: vehicle,
                    isLoading: $blockageLoading,
                    errorMessage: $blockageError,
                    successMessage: $blockageSuccess
                )
            }

            // ── Vehicle Info ──
            cleanListCard {
                detailRow(icon: "gauge.open.with.lines.needle.33percent", label: "Hız", value: vehicle.formattedSpeed)
                listDivider
                detailRow(icon: "mappin.circle.fill", label: "Konum", value: vehicle.locationDisplay)
                if vehicle.deviceTime != nil {
                    listDivider
                    detailRow(icon: "clock.fill", label: "Son Güncelleme", value: vehicle.formattedDeviceTime)
                }
                if vehicle.lastPacketAt != nil {
                    listDivider
                    detailRow(icon: "arrow.triangle.2.circlepath", label: "Son Paket", value: vehicle.formattedLastPacketAt)
                }
            }

            // ── Kontak & Güç ──
            cleanListCard {
                detailRow(
                    icon: vehicle.kontakOn ? "key.fill" : "key",
                    label: "Kontak",
                    value: vehicle.kontakLabel,
                    valueColor: vehicle.kontakOn ? AppTheme.online : AppTheme.offline
                )
                listDivider
                detailRow(icon: "sunrise.fill", label: "İlk Kontak (Bugün)", value: vehicle.formattedFirstIgnitionToday)
                listDivider
                detailRow(icon: "key.fill", label: "Son Kontak Açma", value: vehicle.formattedLastIgnitionOn)
                listDivider
                detailRow(icon: "key", label: "Son Kontak Kapama", value: vehicle.formattedLastIgnitionOff)
                listDivider
                
                if vehicle.deviceBattery != nil {
                    listDivider
                    detailRow(icon: "iphone", label: "Cihaz Bataryası", value: formatDeviceBattery(vehicle.deviceBattery))
                }
                if vehicle.externalVoltage != nil {
                    listDivider
                    detailRow(icon: "bolt.fill", label: "Harici Voltaj", value: formatVoltage(vehicle.externalVoltage))
                }
            }

            // ── Temperature & Sensors (conditional) ──
            if vehicle.temperatureC != nil || vehicle.humidityPct != nil {
                cleanListCard {
                    if let temp = vehicle.temperatureC {
                        detailRow(icon: "thermometer.medium", label: "Sıcaklık", value: String(format: "%.1f°C", temp))
                    }
                    if vehicle.temperatureC != nil && vehicle.humidityPct != nil {
                        listDivider
                    }
                    if let hum = vehicle.humidityPct {
                        detailRow(icon: "humidity.fill", label: "Nem", value: "%\(Int(hum))")
                    }
                }
            }

            // ── Yakıt & Maliyet ──
            if !vehicle.fuelType.isEmpty || vehicle.dailyFuelPer100km > 0 || vehicle.fuelPer100km > 0 {
                cleanListCard {
                    if !vehicle.fuelType.isEmpty {
                        detailRow(icon: "fuelpump.fill", label: "Yakıt Tipi", value: vehicle.fuelType)
                        listDivider
                    }
                    let rate = vehicle.dailyFuelPer100km > 0 ? vehicle.dailyFuelPer100km : vehicle.fuelPer100km
                    if rate > 0 {
                        detailRow(icon: "gauge.open.with.lines.needle.33percent", label: "Tüketim", value: String(format: "%.1f L/100km", rate))
                        listDivider
                    }
                    detailRow(icon: "drop.fill", label: "Bugün Tahmini Yakıt", value: vehicle.formattedDailyFuelLiters)
                    listDivider
                    detailRow(icon: "turkishlirasign.circle.fill", label: "Bugün Tahmini Maliyet", value: vehicle.formattedDailyFuelCost)
                }
            }

            // ── Driver ──
            let displayName = !observer.driverName.isEmpty ? observer.driverName : (!vehicle.driverName.isEmpty ? vehicle.driverName : "")
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.lavender.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Text(displayName.isEmpty ? "?" : String(displayName.prefix(1)))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.lavender)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName.isEmpty ? "Sürücü Atanmamış" : displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.darkText)
                    Text("Sürücü")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.darkTextMuted)
                }

                Spacer()

                Button(action: { showDriverAssign = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                        Text("Değiştir")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AppTheme.lavender)
                }
            }
            .padding(16)
            .background(AppTheme.darkSurface)
            .cornerRadius(14)
            .sheet(isPresented: $showDriverAssign) {
                VehicleDriverAssignSheet(
                    vehicleId: vehicle.deviceId,
                    currentDriverName: !observer.driverName.isEmpty ? observer.driverName : vehicle.driverName,
                    onAssigned: {
                        observer.fetchDriverInfo()
                    }
                )
            }
        }
    }

    // ── Clean List Card ──
    func cleanListCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(AppTheme.darkSurface)
        .cornerRadius(14)
    }

    var listDivider: some View {
        Divider()
            .padding(.leading, 48)
            .padding(.trailing, 16)
    }

    func detailRow(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.lavender.opacity(0.8))
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.darkTextSub)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(valueColor ?? AppTheme.darkText)
                .lineLimit(1)
                .frame(maxWidth: 180, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.1))
                    .cornerRadius(12)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.darkTextMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Maintenance Tab
    var maintenanceTab: some View {
        VStack(spacing: 16) {
            if isLoadingMaintenance {
                ProgressView("Yükleniyor...")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                // Maintenance section
                sectionCard(title: "BAKIM TAKVİMİ", icon: "wrench.and.screwdriver.fill") {
                    if fleetMaintenances.isEmpty {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(AppTheme.darkTextMuted)
                            Text("Bu araç için bakım kaydı bulunmuyor")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.darkTextMuted)
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(fleetMaintenances.enumerated()), id: \.element.id) { index, m in
                                let mStatus: MaintenanceStatus = m.status == "completed" ? .completed : (m.status == "overdue" ? .overdue : .upcoming)
                                maintenanceRow(
                                    icon: m.maintenanceType == "oil_change" ? "drop.fill" : (m.maintenanceType == "tire_change" ? "circle.circle.fill" : "wrench.fill"),
                                    title: m.title,
                                    date: m.scheduledDate,
                                    status: mStatus,
                                    km: m.currentKm > 0 ? "\(m.currentKm) km" : "—"
                                )
                                if index < fleetMaintenances.count - 1 {
                                    Divider().padding(.leading, 44)
                                }
                            }
                        }
                    }
                }

                // Documents section
                sectionCard(title: "BELGELER", icon: "doc.text.fill") {
                    if fleetDocuments.isEmpty {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(AppTheme.darkTextMuted)
                            Text("Bu araç için belge kaydı bulunmuyor")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.darkTextMuted)
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(fleetDocuments.enumerated()), id: \.element.id) { index, doc in
                                let dStatus: DocStatus = doc.status == "expired" ? .critical : (doc.status == "expiring_soon" ? .warning : .normal)
                                let daysLeft = doc.daysUntilExpiry
                                documentRow(title: doc.docTypeLabel, date: doc.expiryDate ?? "—", daysLeft: daysLeft, status: dStatus)
                                if index < fleetDocuments.count - 1 {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            guard !isLoadingMaintenance else { return }
            isLoadingMaintenance = true
            do {
                let (maintenances, _) = try await APIService.shared.fetchFleetMaintenance(imei: vehicle.imei)
                fleetMaintenances = maintenances
                let (documents, _) = try await APIService.shared.fetchFleetDocuments(imei: vehicle.imei)
                fleetDocuments = documents
            } catch {
                print("[VehicleDetail] fleet maintenance/docs error: \(error)")
            }
            isLoadingMaintenance = false
        }
    }

    // MARK: - Costs Tab
    var costsTab: some View {
        VStack(spacing: 16) {
            if isLoadingCosts {
                ProgressView("Yükleniyor...")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if fleetCosts.isEmpty {
                sectionCard(title: "MASRAFLAR", icon: "chart.bar.fill") {
                    HStack {
                        Image(systemName: "banknote")
                            .foregroundColor(AppTheme.darkTextMuted)
                        Text("Bu araç için masraf kaydı bulunmuyor")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.darkTextMuted)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Cost summary by category
                let categoryTotals = Dictionary(grouping: fleetCosts, by: { $0.category })
                    .mapValues { costs in costs.reduce(0.0) { $0 + $1.amount } }
                let totalAmount = fleetCosts.reduce(0.0) { $0 + $1.amount }
                let currency = fleetCosts.first?.currency ?? "TRY"

                sectionCard(title: "MASRAF ÖZETİ", icon: "chart.bar.fill") {
                    let sortedCats = categoryTotals.sorted { $0.value > $1.value }
                    HStack(spacing: 0) {
                        ForEach(sortedCats.prefix(4), id: \.key) { cat, amt in
                            let pct = totalAmount > 0 ? Int(amt / totalAmount * 100) : 0
                            costSummaryItem(
                                label: cat.capitalized,
                                amount: FleetCost.formatAmount(amt, currency: currency),
                                color: costCategoryColor(cat),
                                percent: pct
                            )
                        }
                    }
                    .padding(.vertical, 8)

                    HStack {
                        Text("TOPLAM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.darkTextMuted)
                        Spacer()
                        Text(FleetCost.formatAmount(totalAmount, currency: currency))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.darkText)
                    }
                    .padding(14)
                    .background(AppTheme.darkCard)
                    .cornerRadius(10)
                }

                sectionCard(title: "SON MASRAFLAR", icon: "list.bullet.rectangle") {
                    VStack(spacing: 0) {
                        ForEach(Array(fleetCosts.enumerated()), id: \.element.id) { index, cost in
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
                                    Text(cost.category.capitalized)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.darkText)
                                    Text(cost.costDate)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.darkTextSub)
                                }

                                Spacer()

                                Text(cost.formattedAmount)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.darkText)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)

                            if index < fleetCosts.count - 1 {
                                Divider().padding(.leading, 62)
                            }
                        }
                    }
                }
            }
        }
        .task {
            guard !isLoadingCosts else { return }
            isLoadingCosts = true
            do {
                let (costs, _) = try await APIService.shared.fetchFleetCosts(imei: vehicle.imei)
                fleetCosts = costs
            } catch {
                print("[VehicleDetail] fleet costs error: \(error)")
            }
            isLoadingCosts = false
        }
    }

    // MARK: - Events Tab
    var eventsTab: some View {
        EventsTabContent(vehicle: observer.vehicle, onNavigateToAlarms: onNavigateToAlarms)
    }

    // MARK: - Helper Views

    func formatVoltage(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f V", value)
    }

    func formatDeviceBattery(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value <= 100 ? "%\(Int(value))" : String(format: "%.2f V", value)
    }

    func sectionCard(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.lavender)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.darkTextMuted)
                    .tracking(0.5)
                Spacer()
            }
            content()
        }
        .padding(16)
        .background(AppTheme.darkSurface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.darkBorder, lineWidth: 1)
        )
    }

    func infoCell(icon: String, label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.lavender)
                .frame(width: 26, height: 26)
                .background(AppTheme.lavender.opacity(0.12))
                .cornerRadius(7)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppTheme.darkTextMuted)
                    .tracking(0.3)
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(valueColor ?? AppTheme.darkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(10)
        .background(AppTheme.darkCard)
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
                    .foregroundColor(AppTheme.darkTextMuted)
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
                    .foregroundColor(AppTheme.darkText)
                HStack(spacing: 8) {
                    Text(date)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.darkTextSub)
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(AppTheme.darkTextMuted)
                    Text(km)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.darkTextSub)
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
                    .foregroundColor(AppTheme.darkText)
                Text("Bitiş: \(date)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.darkTextSub)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(daysLeft) gün")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(status.color)
                Text("kalan")
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.darkTextMuted)
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
                .foregroundColor(AppTheme.darkText)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.darkTextMuted)
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
                    .foregroundColor(AppTheme.darkText)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.darkTextSub)
            }

            Spacer()

            Text(time)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.darkTextMuted)
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

// MARK: - Events Tab Content (fetches real alarms)
struct EventsTabContent: View {
    let vehicle: Vehicle
    var onNavigateToAlarms: ((String) -> Void)?
    @State private var alarms: [AlarmEvent] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 16) {
            sectionCard(title: "SON OLAYLAR", icon: "clock.fill") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(24)
                        Spacer()
                    }
                } else if alarms.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.darkTextMuted)
                        Text("Bu araç için alarm bulunamadı")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.darkTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(alarms.enumerated()), id: \.element.id) { index, alarm in
                            eventRow(
                                icon: alarm.icon,
                                title: alarm.typeLabel,
                                subtitle: alarm.description.isEmpty ? alarm.plate : alarm.description,
                                time: alarm.formattedDate,
                                severity: alarmSeverity(alarm)
                            )
                            if index < alarms.count - 1 {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }

                    // "Tümünü Gör" button
                    if let onNavigateToAlarms = onNavigateToAlarms {
                        Button(action: {
                            onNavigateToAlarms(vehicle.plate)
                        }) {
                            HStack(spacing: 6) {
                                Text("Tümünü Gör")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(AppTheme.lavender)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.lavender.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .task {
            await fetchAlarms()
        }
    }

    private func alarmSeverity(_ alarm: AlarmEvent) -> AlertSeverity {
        let key = alarm.alarmKey.lowercased()
        if key.contains("gf_") || key.contains("geofence") { return .green }
        if key.contains("t_towing") || key.contains("sos") { return .red }
        if key.contains("t_movement") { return .amber }
        return .blue
    }

    private func fetchAlarms() async {
        do {
            let json = try await APIService.shared.get("/api/mobile/alarms?page=1&per_page=50")
            let dataArr = json["data"] as? [[String: Any]] ?? []
            let results = dataArr.enumerated().compactMap { (i, dict) -> AlarmEvent? in
                let a = AlarmEvent.from(json: dict, index: i)
                guard a.imei == vehicle.imei || a.plate == vehicle.plate else { return nil }
                return a
            }
            alarms = Array(results.prefix(10))
        } catch {
            alarms = []
        }
        isLoading = false
    }

    func sectionCard(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.lavender)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.darkTextMuted)
                    .tracking(0.5)
                Spacer()
            }
            content()
        }
        .padding(16)
        .background(AppTheme.darkSurface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.darkBorder, lineWidth: 1)
        )
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
                    .foregroundColor(AppTheme.darkText)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.darkTextSub)
            }
            Spacer()
            Text(time)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.darkTextMuted)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}

#Preview {
    VehicleDetailView(vehicle: Vehicle(
        id: "1", plate: "34 ABC 123", model: "Ford Transit",
        status: .ignitionOn, kontakOn: true, totalKm: 48320, todayKm: 312,
        driver: "Ahmet Yılmaz", city: "İstanbul", lat: 41.0082, lng: 28.9784
    ))
}
