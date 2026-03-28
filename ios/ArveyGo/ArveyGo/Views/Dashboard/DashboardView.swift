import SwiftUI
import MapKit

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Dashboard View (Redesigned — Card-Based, Apple HIG)
// ═══════════════════════════════════════════════════════════════════════════
struct DashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var dashVM = DashboardViewModel()
    @ObservedObject private var DL = DashboardStrings.shared
    @Binding var showSideMenu: Bool
    @Binding var selectedPage: AppPage
    @Binding var alarmsSearchText: String
    @State private var selectedVehicle: Vehicle?
    @State private var showFullScreenMap = false

    // Weekly distance sample data (7 days)
    private var weeklyDistances: [CGFloat] {
        guard !dashVM.vehicles.isEmpty else { return [0, 0, 0, 0, 0, 0, 0] }
        let todayTotal = CGFloat(dashVM.todayKm)
        // Simulate a natural week pattern from today's real data
        let base = max(todayTotal * 0.6, 50)
        return [
            base * 0.7,
            base * 1.1,
            base * 0.9,
            base * 1.3,
            base * 0.8,
            base * 1.05,
            todayTotal
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // 1 ─ Greeting header
                    greetingHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    // 2 ─ Summary metrics bar (horizontal scroll)
                    summaryBar

                    // 3 ─ Live Fleet Map card
                    liveMapCard
                        .padding(.horizontal, 20)

                    // 4 ─ Vehicle Fleet Overview card (moved up)
                    vehicleFleetCard
                        .padding(.horizontal, 20)

                    // 5 ─ Weekly Distance + Driver Safety (side-by-side)
                    HStack(spacing: 14) {
                        weeklyDistanceCard
                        driverSafetyCard
                    }
                    .padding(.horizontal, 20)

                    // 6 ─ Critical Alerts card
                    criticalAlertsCard
                        .padding(.horizontal, 20)

                    // 7 ─ AI Insights card
                    aiInsightsCard
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 24)
                }
                .padding(.top, 8)
            }
            .refreshable {
                dashVM.refreshData()
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) { showSideMenu.toggle() }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(DL.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(DL.subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { selectedPage = .alarms }) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 16))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.red, .secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
        .sheet(item: $selectedVehicle) { vehicle in
            VehicleDetailView(
                vehicle: vehicle,
                onNavigateToRouteHistory: { v in
                    selectedVehicle = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        selectedPage = .routeHistory
                    }
                },
                onNavigateToAlarms: { plateText in
                    selectedVehicle = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        alarmsSearchText = plateText
                        selectedPage = .alarms
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showFullScreenMap) {
            FullScreenMapView(vehicles: dashVM.vehicles, onDismiss: { showFullScreenMap = false })
        }
        .onAppear {
            authVM.connectWebSocket()
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: 1 — Greeting Header
    // ═══════════════════════════════════════════════════════════════════════
    var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greetingText), \(authVM.currentUser?.name ?? "Admin") 👋")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(DL.fleetSummaryDesc)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Date chip
            Text(shortDateString)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial)
                .clipShape(Capsule())
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return DL.goodMorning }
        if hour < 18 { return DL.goodAfternoon }
        return DL.goodEvening
    }

    private var shortDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMM, EEE"
        return f.string(from: Date())
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: 2 — Summary Metrics Bar
    // ═══════════════════════════════════════════════════════════════════════
    var summaryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Total Vehicles (Active / Inactive)
                SummaryPill(
                    icon: "car.fill",
                    iconColor: .blue,
                    title: "Araçlar",
                    value: "\(dashVM.totalVehicles)",
                    badge: "\(dashVM.kontakOnCount) aktif",
                    badgeColor: .green
                )

                // Ignition On
                SummaryPill(
                    icon: "key.fill",
                    iconColor: .green,
                    title: "Kontak Açık",
                    value: "\(dashVM.kontakOnCount)",
                    badge: nil,
                    badgeColor: .green
                )

                // Ignition Off
                SummaryPill(
                    icon: "key",
                    iconColor: .orange,
                    title: "Kontak Kapalı",
                    value: "\(dashVM.kontakOffCount)",
                    badge: nil,
                    badgeColor: .orange
                )

                // No Data
                SummaryPill(
                    icon: "antenna.radiowaves.left.and.right.slash",
                    iconColor: Color(.systemGray),
                    title: "Bilgi Yok",
                    value: "\(dashVM.bilgiYokCount)",
                    badge: nil,
                    badgeColor: .gray
                )

                // Avg Fuel
                SummaryPill(
                    icon: "fuelpump.fill",
                    iconColor: .purple,
                    title: "Ort. Yakıt",
                    value: avgFuelString,
                    badge: "L/100km",
                    badgeColor: .purple
                )

                // Critical Alerts
                SummaryPill(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .red,
                    title: "Kritik Alarm",
                    value: "\(criticalAlertCount)",
                    badge: criticalAlertCount > 0 ? "acil" : nil,
                    badgeColor: .red
                )

                // Today Km
                SummaryPill(
                    icon: "road.lanes",
                    iconColor: AppTheme.indigo,
                    title: "Bugün KM",
                    value: dashVM.formatKm(dashVM.todayKm),
                    badge: nil,
                    badgeColor: .blue
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private var avgFuelString: String {
        let rates = dashVM.vehicles.compactMap { v -> Double? in
            let r = v.dailyFuelPer100km > 0 ? v.dailyFuelPer100km : v.fuelPer100km
            return r > 0 ? r : nil
        }
        guard !rates.isEmpty else { return "—" }
        let avg = rates.reduce(0, +) / Double(rates.count)
        return String(format: "%.1f", avg)
    }

    private var criticalAlertCount: Int {
        dashVM.alerts.filter { $0.severity == .red }.count
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: 3 — Live Fleet Map Card
    // ═══════════════════════════════════════════════════════════════════════
    var liveMapCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label {
                    Text(DL.fleetMap)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.indigo)
                }

                Spacer()

                // Full screen toggle (disabled for now)
                // Button(action: { showFullScreenMap = true }) {
                //     HStack(spacing: 4) {
                //         Image(systemName: "arrow.up.left.and.arrow.down.right")
                //             .font(.system(size: 10, weight: .semibold))
                //         Text("Tam Ekran")
                //             .font(.system(size: 11, weight: .semibold))
                //     }
                //     .foregroundStyle(AppTheme.indigo)
                //     .padding(.horizontal, 10)
                //     .padding(.vertical, 6)
                //     .background(AppTheme.indigo.opacity(0.08))
                //     .clipShape(Capsule())
                // }
                // .frame(minWidth: 44, minHeight: 44)

                Button(action: { selectedPage = .liveMap }) {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(DL.liveMapAction)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppTheme.indigo)
                    .clipShape(Capsule())
                }
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Map
            ZStack(alignment: .bottomLeading) {
                Map {
                    ForEach(dashVM.vehicles) { vehicle in
                        Annotation(vehicle.plate, coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)) {
                            DashboardMapDot(status: vehicle.status)
                        }
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 12)

                // Legend overlay
                HStack(spacing: 10) {
                    mapLegend(color: AppTheme.online, label: "Açık")
                    mapLegend(color: AppTheme.offline, label: "Kapalı")
                    mapLegend(color: Color(.systemGray), label: "Bilgi Yok")
                    mapLegend(color: AppTheme.idle, label: "Uyku")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.leading, 22)
                .padding(.bottom, 10)
            }
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    func mapLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: 4a — Weekly Distance Card (Line Chart)
    // ═══════════════════════════════════════════════════════════════════════
    var weeklyDistanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("Haftalık Mesafe")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.indigo)
            }

            Text("\(dashVM.formatKm(dashVM.todayKm)) km")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("bugün")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            // Minimalist line chart
            MiniLineChart(values: weeklyDistances, lineColor: AppTheme.indigo)
                .frame(height: 50)

            // Day labels
            HStack {
                ForEach(dayLabels(), id: \.self) { day in
                    Text(day)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.quaternary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func dayLabels() -> [String] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            f.dateFormat = "EEE"
            return String(f.string(from: day).prefix(2))
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: 4b — Driver Safety Score Card (Circular)
    // ═══════════════════════════════════════════════════════════════════════
    var driverSafetyCard: some View {
        let score = dashVM.avgScore
        let grade: String = {
            if score >= 85 { return "A" }
            if score >= 70 { return "B" }
            if score >= 50 { return "C" }
            return "D"
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("Güvenlik Skoru")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }

            Spacer()

            // Circular progress
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 6)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100.0)
                        .stroke(
                            scoreGradient(score),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(score)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(grade)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text("\(dashVM.drivers.count) sürücü")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            Button(action: { selectedPage = .drivers }) {
                Text("Detaylar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.indigo)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(AppTheme.indigo.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(minHeight: 44)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func scoreGradient(_ score: Int) -> LinearGradient {
        if score >= 85 {
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if score >= 70 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: 5 — Vehicle Fleet Overview Card
    // ═══════════════════════════════════════════════════════════════════════
    var vehicleFleetCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label {
                    Text(DL.vehiclesTitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "car.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }

                Spacer()

                Text("\(dashVM.totalVehicles)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())

                Button(action: { selectedPage = .vehicles }) {
                    HStack(spacing: 3) {
                        Text(DL.viewAll)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.indigo)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            // Status distribution bar
            fleetDistributionBar
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            // Vehicle rows — show 5: oldest active/idle first, fill rest from others
            let displayVehicles: [Vehicle] = {
                // Active + idle vehicles sorted oldest first (by ts ascending)
                let activeIdle = dashVM.vehicles
                    .filter { $0.status == .ignitionOn || $0.status == .sleeping }
                    .sorted { $0.ts < $1.ts }
                let chosen = Array(activeIdle.suffix(5))
                if chosen.count >= 5 { return Array(chosen.prefix(5)) }
                // Fill remaining spots with other vehicles
                let remaining = dashVM.vehicles.filter { v in !chosen.contains(where: { $0.id == v.id }) }
                return Array((chosen + remaining).prefix(5))
            }()
            VStack(spacing: 0) {
                ForEach(Array(displayVehicles.enumerated()), id: \.element.id) { index, vehicle in
                    Button(action: { selectedVehicle = vehicle }) {
                        VehicleRow(vehicle: vehicle)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)

                    if index < displayVehicles.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }

            // See all
            if dashVM.vehicles.count > 5 {
                Button(action: { selectedPage = .vehicles }) {
                    Text("+\(dashVM.vehicles.count - 5) daha fazla araç")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.indigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .frame(minHeight: 44)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // Fleet distribution bar
    var fleetDistributionBar: some View {
        let total = max(dashVM.totalVehicles, 1)
        let on = dashVM.kontakOnCount
        let off = dashVM.kontakOffCount
        let noData = dashVM.bilgiYokCount
        let sleeping = dashVM.idleCount

        return VStack(spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if on > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.green)
                            .frame(width: max(geo.size.width * CGFloat(on) / CGFloat(total), 4))
                    }
                    if off > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.red)
                            .frame(width: max(geo.size.width * CGFloat(off) / CGFloat(total), 4))
                    }
                    if noData > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray3))
                            .frame(width: max(geo.size.width * CGFloat(noData) / CGFloat(total), 4))
                    }
                    if sleeping > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.orange)
                            .frame(width: max(geo.size.width * CGFloat(sleeping) / CGFloat(total), 4))
                    }
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())

            HStack(spacing: 12) {
                distributionLabel(color: .green, text: "Açık \(on)")
                distributionLabel(color: .red, text: "Kapalı \(off)")
                distributionLabel(color: Color(.systemGray3), text: "Bilgi Yok \(noData)")
                distributionLabel(color: .orange, text: "Uyku \(sleeping)")
                Spacer()
            }
        }
    }

    func distributionLabel(color: Color, text: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: 6 — Critical Alerts Card
    // ═══════════════════════════════════════════════════════════════════════
    var criticalAlertsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label {
                    Text(DL.recentAlarms)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }

                Spacer()

                if criticalAlertCount > 0 {
                    Text("\(criticalAlertCount) kritik")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.red.opacity(0.1))
                        .clipShape(Capsule())
                }

                Button(action: { selectedPage = .alarms }) {
                    HStack(spacing: 3) {
                        Text(DL.allLabel)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.indigo)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)

            if dashVM.isLoadingAlerts && dashVM.alerts.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(20)
                    Spacer()
                }
            } else if dashVM.alerts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.green.opacity(0.6))
                        Text("Alarm bulunmuyor")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dashVM.alerts.prefix(5).enumerated()), id: \.element.id) { index, alert in
                        AlertRow(alert: alert)
                        if index < min(dashVM.alerts.count, 5) - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: 7 — AI Insights Card
    // ═══════════════════════════════════════════════════════════════════════
    var aiInsightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(DL.aiAnalysis)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.purple)
            }

            Text(DL.aiSummary(online: dashVM.onlineCount, km: dashVM.formatKm(dashVM.todayKm)))
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(.secondary)
                .lineSpacing(4)

            VStack(spacing: 8) {
                InsightBubble(
                    text: DL.currentLang == "TR"
                        ? "En yüksek mesafe: \(topVehiclePlate) — \(topVehicleKm) km"
                        : "Highest distance: \(topVehiclePlate) — \(topVehicleKm) km",
                    dotColor: AppTheme.online,
                    tag: nil
                )
                InsightBubble(
                    text: DL.currentLang == "TR"
                        ? "\(dashVM.bilgiYokCount) araç çevrimdışı — bakım kontrolü önerilir"
                        : "\(dashVM.bilgiYokCount) vehicles offline — maintenance check recommended",
                    dotColor: AppTheme.offline,
                    tag: dashVM.bilgiYokCount > 0 ? (DL.highPriority, .red) : nil
                )
                InsightBubble(
                    text: DL.currentLang == "TR"
                        ? "Ortalama sürücü skoru \(dashVM.avgScore) — filo güvenliği iyi seviyede"
                        : "Average driver score \(dashVM.avgScore) — fleet safety in good standing",
                    dotColor: AppTheme.indigo,
                    tag: dashVM.avgScore >= 70 ? (DL.lowPriority, .green) : (DL.highPriority, .orange)
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var topVehiclePlate: String {
        dashVM.vehicles.max(by: { $0.todayKm < $1.todayKm })?.plate ?? "—"
    }
    private var topVehicleKm: String {
        let km = dashVM.vehicles.max(by: { $0.todayKm < $1.todayKm })?.todayKm ?? 0
        return dashVM.formatKm(km)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Summary Pill Component
// ═══════════════════════════════════════════════════════════════════════════
struct SummaryPill: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let badge: String?
    let badgeColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Simple icon row
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)

            // Value — clean and readable
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Title
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Optional badge
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(badgeColor)
            }
        }
        .frame(width: 100)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Dashboard Map Dot (lightweight pin for mini-map)
// ═══════════════════════════════════════════════════════════════════════════
struct DashboardMapDot: View {
    let status: VehicleStatus

    var body: some View {
        ZStack {
            Circle()
                .fill(status.color.opacity(0.25))
                .frame(width: 22, height: 22)
            Circle()
                .fill(status.color)
                .frame(width: 12, height: 12)
            Circle()
                .stroke(.white, lineWidth: 1.5)
                .frame(width: 12, height: 12)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Mini Line Chart
// ═══════════════════════════════════════════════════════════════════════════
struct MiniLineChart: View {
    let values: [CGFloat]
    let lineColor: Color

    var body: some View {
        GeometryReader { geo in
            let maxVal = max(values.max() ?? 1, 1)
            let w = geo.size.width
            let h = geo.size.height
            let step = w / CGFloat(max(values.count - 1, 1))

            ZStack {
                // Gradient fill
                Path { path in
                    for (i, val) in values.enumerated() {
                        let x = step * CGFloat(i)
                        let y = h - (val / maxVal) * h
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [lineColor.opacity(0.2), lineColor.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    for (i, val) in values.enumerated() {
                        let x = step * CGFloat(i)
                        let y = h - (val / maxVal) * h
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // End dot
                if let last = values.last {
                    let x = w
                    let y = h - (last / maxVal) * h
                    Circle()
                        .fill(lineColor)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Vehicle Row
// ═══════════════════════════════════════════════════════════════════════════
struct VehicleRow: View {
    let vehicle: Vehicle

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator + icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(vehicle.status.color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: vehicle.mapIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(vehicle.status.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.plate)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("\(vehicle.model) · \(vehicle.city)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(vehicle.formattedTodayKm)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                HStack(spacing: 3) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 8))
                    Text("\(Int(vehicle.speed)) km/h")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.tertiary)
            }

            // Status badge
            Text(vehicle.status.label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(vehicle.status.color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(vehicle.status.color.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Alert Row
// ═══════════════════════════════════════════════════════════════════════════
struct AlertRow: View {
    let alert: FleetAlert

    var iconName: String {
        switch alert.severity {
        case .red: return "exclamationmark.octagon.fill"
        case .amber: return "exclamationmark.triangle.fill"
        case .green: return "checkmark.circle.fill"
        case .blue: return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundStyle(alert.severity.color)
                .frame(width: 32, height: 32)
                .background(alert.severity.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(alert.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(alert.time)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Insight Bubble
// ═══════════════════════════════════════════════════════════════════════════
struct InsightBubble: View {
    let text: String
    let dotColor: Color
    let tag: (String, Color)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            if let tag = tag {
                Spacer()
                Text(tag.0)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(tag.1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(tag.1.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Full Screen Map View
// ═══════════════════════════════════════════════════════════════════════════
struct FullScreenMapView: View {
    let vehicles: [Vehicle]
    let onDismiss: () -> Void

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                ForEach(vehicles) { vehicle in
                    Annotation(vehicle.plate, coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)) {
                        DashboardMapDot(status: vehicle.status)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Filo Haritası")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        mapLegendChip(color: .green, label: "Açık")
                        mapLegendChip(color: .red, label: "Kapalı")
                        mapLegendChip(color: .gray, label: "Yok")
                        mapLegendChip(color: .orange, label: "Uyku")
                    }
                }
            }
        }
    }

    func mapLegendChip(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Preview
// ═══════════════════════════════════════════════════════════════════════════
#Preview {
    DashboardView(showSideMenu: .constant(false), selectedPage: .constant(.dashboard), alarmsSearchText: .constant(""))
        .environmentObject(AuthViewModel())
}
