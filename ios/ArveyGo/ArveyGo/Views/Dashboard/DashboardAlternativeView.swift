import SwiftUI
import MapKit

struct DashboardAlternativeView: View {
    @ObservedObject var vm: DashboardViewModel
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedPage: AppPage
    @Binding var alarmsSearchText: String
    @Binding var alarmsAutoOpenCreate: Bool
    @Binding var alarmsPrePlate: String
    @Binding var alarmsInitialEvent: AlarmEvent?

    @State private var selectedVehicle: Vehicle?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showVehiclesPage = false
    @State private var showRouteHistoryPage = false
    @State private var routeHistoryVehicle: Vehicle?
    @State private var hasPositionedMap = false

    private var isDark: Bool { colorScheme == .dark }
    private var backgroundTop: Color {
        isDark ? Color(red: 8/255, green: 14/255, blue: 31/255) : Color(red: 243/255, green: 245/255, blue: 251/255)
    }
    private var backgroundBottom: Color {
        isDark ? Color(red: 17/255, green: 24/255, blue: 46/255) : Color(red: 232/255, green: 238/255, blue: 249/255)
    }
    private var surface: Color {
        isDark ? Color(red: 17/255, green: 24/255, blue: 46/255) : Color.white.opacity(0.94)
    }
    private var elevatedSurface: Color {
        isDark ? Color(red: 24/255, green: 33/255, blue: 60/255) : Color.white
    }
    private var primaryText: Color {
        isDark ? AppTheme.darkText : AppTheme.textPrimary
    }
    private var secondaryText: Color {
        isDark ? AppTheme.darkTextSub : AppTheme.textSecondary
    }
    private var mutedText: Color {
        isDark ? AppTheme.darkTextMuted : AppTheme.textMuted
    }
    private var borderColor: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }
    private var shadowColor: Color {
        isDark ? Color.black.opacity(0.28) : Color(red: 9/255, green: 15/255, blue: 65/255).opacity(0.10)
    }

    private var highlightedVehicles: [Vehicle] {
        Array(vm.vehicles.sorted { lhs, rhs in
            if lhs.speed != rhs.speed { return lhs.speed > rhs.speed }
            return lhs.plate < rhs.plate
        }.prefix(3))
    }

    private var liveVehicles: [Vehicle] {
        vm.vehicles.filter { $0.isOnline || $0.ignition || $0.speed > 0 }
    }

    private var centerCoordinate: CLLocationCoordinate2D {
        if let vehicle = highlightedVehicles.first ?? vm.vehicles.first {
            return CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)
        }
        return CLLocationCoordinate2D(latitude: 41.0151, longitude: 28.9795)
    }

    private var mapVehicles: [Vehicle] {
        let preferred = liveVehicles.isEmpty ? highlightedVehicles : liveVehicles
        let valid = preferred.filter { vehicle in
            CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng))
                && !(vehicle.lat == 0 && vehicle.lng == 0)
        }
        return valid.isEmpty ? highlightedVehicles : valid
    }

    private var mapVehiclesSignature: String {
        mapVehicles
            .map { "\($0.id)-\($0.lat)-\($0.lng)" }
            .joined(separator: "|")
    }

    private var closedVehiclesCount: Int {
        vm.kontakOffCount
    }

    private var isInitialLoading: Bool {
        vm.isLoading && vm.vehicles.isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [backgroundTop, backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                Group {
                    if isInitialLoading {
                        DashboardSkeletonView()
                            .padding(.top, 8)
                    } else if let message = vm.vehiclesErrorMessage, vm.vehicles.isEmpty {
                        dashboardStateCard(
                            icon: "wifi.exclamationmark",
                            title: "Filo verisi alınamadı",
                            message: message
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                    } else if vm.vehicles.isEmpty {
                        dashboardStateCard(
                            icon: "car.2.slash",
                            title: "Araç bulunmuyor",
                            message: "Gerçek veri geldiğinde dashboard burada canlı olarak listelenecek."
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                    } else {
                        VStack(spacing: 18) {
                            dashboardTwoHero
                            dashboardTwoActions
                            dashboardTwoMapCard
                            dashboardTwoVehicleList
                            dashboardTwoAlerts
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .refreshable {
                vm.refreshData()
            }
            .clipped()
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(backgroundTop, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        .navigationDestination(isPresented: $showVehiclesPage) {
            VehiclesListView(
                showSideMenu: .constant(false),
                selectedPage: $selectedPage,
                alarmsSearchText: $alarmsSearchText,
                alarmsAutoOpenCreate: $alarmsAutoOpenCreate,
                alarmsPrePlate: $alarmsPrePlate,
                displayMode: .embedded
            )
        }
        .navigationDestination(isPresented: $showRouteHistoryPage) {
            RouteHistoryView(
                showSideMenu: .constant(false),
                displayMode: .embedded,
                initialVehicle: routeHistoryVehicle,
                autoLoadInitialVehicle: routeHistoryVehicle != nil
            )
        }
        .sheet(item: $selectedVehicle) { vehicle in
            NavigationStack {
                VehicleDetailFifthView(
                    vehicle: vehicle,
                    presentationMode: .modal,
                    onNavigateToRouteHistory: { routeVehicle in
                        selectedVehicle = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            routeHistoryVehicle = routeVehicle
                            showRouteHistoryPage = true
                        }
                    },
                    onNavigateToAlarms: { plateText in
                        selectedVehicle = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            alarmsSearchText = plateText
                            alarmsAutoOpenCreate = false
                            alarmsPrePlate = ""
                            alarmsInitialEvent = nil
                            switchMainTab(to: .alarms, page: .alarms)
                        }
                    },
                    onNavigateToAddAlarm: { plate in
                        selectedVehicle = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            alarmsSearchText = ""
                            alarmsAutoOpenCreate = true
                            alarmsPrePlate = plate
                            alarmsInitialEvent = nil
                            switchMainTab(to: .alarms, page: .alarms)
                        }
                    }
                )
            }
        }
        .onAppear {
            updateMapPositionIfNeeded()
        }
        .onChange(of: mapVehiclesSignature) { _, _ in
            updateMapPositionIfNeeded()
        }
    }

    private func dashboardStateCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .background(
            LinearGradient(
                colors: [AppTheme.navy, Color(red: 30/255, green: 54/255, blue: 126/255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var dashboardTwoHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kontrol Merkezi")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                    Text("Filo ritmini tek bakışta izle")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(Date().formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.74))
                    Text(Date().formatted(.dateTime.hour().minute()))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 10) {
                dashboardTwoStat(title: "Aktif", value: "\(vm.onlineCount)", tone: AppTheme.online)
                dashboardTwoStat(title: "Rölanti", value: "\(vm.idleCount)", tone: AppTheme.idle)
                dashboardTwoStat(title: "Kapalı", value: "\(closedVehiclesCount)", tone: AppTheme.offline)
            }

            HStack(spacing: 12) {
                dashboardTwoMetricTile(icon: "car.2.fill", title: "Toplam Araç", value: "\(vm.totalVehicles)")
                dashboardTwoMetricTile(icon: "road.lanes", title: "Bugün KM", value: vm.formatKm(vm.todayKm))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.navy,
                    Color(red: 30/255, green: 54/255, blue: 126/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 22, x: 0, y: 12)
    }

    private func dashboardTwoStat(title: String, value: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func dashboardTwoMetricTile(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
                Text(value)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var dashboardTwoActions: some View {
        HStack(spacing: 10) {
            dashboardTwoActionButton(title: "Canlı Harita", icon: "location.fill", tint: AppTheme.online) {
                switchMainTab(to: .liveMap, page: .liveMap)
            }
            dashboardTwoActionButton(title: "Araçlar", icon: "car.2.fill", tint: AppTheme.navy) {
                showVehiclesPage = true
            }
            dashboardTwoActionButton(title: "Alarmlar", icon: "bell.fill", tint: AppTheme.offline) {
                switchMainTab(to: .alarms, page: .alarms)
            }
            dashboardTwoActionButton(title: "Rotalar", icon: "point.topleft.down.curvedto.point.bottomright.up", tint: AppTheme.indigo) {
                routeHistoryVehicle = nil
                showRouteHistoryPage = true
            }
        }
    }

    private func dashboardTwoActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        let iconColor = (isDark && (title == "Araçlar" || title == "Rotalar")) ? Color.white : tint

        return Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 48, height: 48)
                    .background(elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var dashboardTwoMapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Canlı Akış")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                Text("\(liveVehicles.count) araç")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(mutedText)
            }

            Map(position: $mapPosition, interactionModes: .all) {
                ForEach(highlightedVehicles) { vehicle in
                    Annotation(vehicle.plate, coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)) {
                        VehicleMapPin(
                            vehicle: vehicle,
                            isSelected: false,
                            animatedDirection: vehicle.direction
                        )
                    }
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 16, x: 0, y: 8)
        .clipped()
    }

    private var dashboardTwoVehicleList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Öne Çıkan Araçlar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                Button {
                    showVehiclesPage = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Tüm araçları gör")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.indigo, AppTheme.navy],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule(style: .continuous)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(isDark ? 0.08 : 0.12), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.navy.opacity(isDark ? 0.28 : 0.18), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                ForEach(highlightedVehicles) { vehicle in
                    Button {
                        selectedVehicle = vehicle
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vehicle.plate)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(primaryText)
                                    Text(vehicle.model)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 12)
                                StatusBadge(status: vehicle.status)
                            }

                            HStack(spacing: 8) {
                                dashboardTwoCompactMetric(label: "Hız", value: vehicle.formattedSpeed)
                                dashboardTwoCompactMetric(label: "Bugün", value: vehicle.formattedTodayKm)
                                dashboardTwoCompactMetric(label: "Konum", value: vehicle.city.isEmpty ? "Bekleniyor" : vehicle.city)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(borderColor, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dashboardTwoInlineMetric(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(mutedText)
                .frame(width: 46, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }

    private func dashboardTwoCompactMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(mutedText)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface.opacity(isDark ? 0.9 : 0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var dashboardTwoAlerts: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Alarm Nabzı")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                Button {
                    alarmsSearchText = ""
                    alarmsAutoOpenCreate = false
                    alarmsPrePlate = ""
                    alarmsInitialEvent = nil
                    switchMainTab(to: .alarms, page: .alarms)
                }
                label: {
                    HStack(spacing: 7) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Alarm Merkezine Git")
                            .font(.system(size: 12, weight: .semibold))
                    }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.indigo, AppTheme.navy],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule(style: .continuous)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(isDark ? 0.08 : 0.12), lineWidth: 1)
                        )
                        .shadow(color: AppTheme.navy.opacity(isDark ? 0.28 : 0.18), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }

            if let message = vm.alertsErrorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(mutedText)
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
            } else if vm.alerts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(mutedText)
                    Text("Yeni alarm bulunmuyor")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(vm.alerts.prefix(4).enumerated()), id: \.offset) { _, alert in
                        Button {
                            alarmsSearchText = ""
                            alarmsAutoOpenCreate = false
                            alarmsPrePlate = ""
                            alarmsInitialEvent = alert
                            switchMainTab(to: .alarms, page: .alarms)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(alert.severity.color)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(alert.dashboardTitle)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(primaryText)
                                    Text(alert.dashboardDescription)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(secondaryText)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 8)

                                Text(alert.dashboardDisplayTime)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(mutedText)
                            }
                            .padding(14)
                            .background(surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(borderColor, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func updateMapPositionIfNeeded() {
        guard !hasPositionedMap else { return }

        let vehicles = mapVehicles
        guard !vehicles.isEmpty else {
            mapPosition = .region(
                MKCoordinateRegion(
                    center: centerCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.9, longitudeDelta: 0.9)
                )
            )
            hasPositionedMap = true
            return
        }

        let lats = vehicles.map(\.lat)
        let lngs = vehicles.map(\.lng)
        guard
            let minLat = lats.min(),
            let maxLat = lats.max(),
            let minLng = lngs.min(),
            let maxLng = lngs.max()
        else {
            return
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let latitudeDelta = max((maxLat - minLat) * 1.55, 0.08)
        let longitudeDelta = max((maxLng - minLng) * 1.55, 0.08)

        mapPosition = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            )
        )
        hasPositionedMap = true
    }

    private func switchMainTab(to tab: AppTab, page: AppPage) {
        selectedPage = page
        NotificationCenter.default.post(name: .arveygoSwitchMainTab, object: tab)
    }
}
