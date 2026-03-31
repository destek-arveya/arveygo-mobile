import SwiftUI
import MapKit

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Design System (Dark Mode aware)
// ═══════════════════════════════════════════════════════════════════════════
struct DS {
    let isDark: Bool

    // Primary
    var primary: Color      { isDark ? Color(red: 139/255, green: 149/255, blue: 224/255) : Color(red: 9/255, green: 15/255, blue: 65/255) }
    var primaryLight: Color  { Color(red: 74/255, green: 83/255, blue: 160/255) }
    var primarySoft: Color   { primary.opacity(isDark ? 0.15 : 0.07) }

    // Backgrounds
    var pageBg: Color  { isDark ? Color(red: 13/255, green: 16/255, blue: 36/255) : Color(red: 245/255, green: 246/255, blue: 250/255) }
    var cardBg: Color  { isDark ? Color(red: 22/255, green: 26/255, blue: 55/255) : Color.white }

    // Status
    static let green = Color(red: 34/255, green: 197/255, blue: 94/255)
    static let red   = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let sky   = Color(red: 56/255, green: 147/255, blue: 241/255)

    // Text
    var text1: Color { isDark ? Color(red: 240/255, green: 241/255, blue: 250/255) : Color(red: 26/255, green: 26/255, blue: 26/255) }
    var text2: Color { isDark ? Color(red: 170/255, green: 175/255, blue: 200/255) : Color(red: 100/255, green: 100/255, blue: 112/255) }
    var text3: Color { isDark ? Color(red: 110/255, green: 115/255, blue: 145/255) : Color(red: 160/255, green: 160/255, blue: 175/255) }

    // Divider
    var divider: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06) }

    // Shadow
    var cardShadow: Color { isDark ? Color.clear : Color.black.opacity(0.04) }

    // Squircle radius
    static let r: CGFloat = 16
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Dashboard View
// ═══════════════════════════════════════════════════════════════════════════
struct DashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var dashVM = DashboardViewModel()
    @ObservedObject private var DL = DashboardStrings.shared

    @Binding var showSideMenu: Bool
    @Binding var selectedPage: AppPage
    @Binding var alarmsSearchText: String
    @Binding var alarmsAutoOpenCreate: Bool
    @Binding var alarmsPrePlate: String

    @State private var selectedVehicle: Vehicle?
    @State private var showFullScreenMap = false

    private var ds: DS { DS(isDark: colorScheme == .dark) }
    private var isDark: Bool { colorScheme == .dark }

    // En hızlı 3 araç
    private var fastestVehicles: [Vehicle] {
        Array(dashVM.vehicles.sorted { $0.speed > $1.speed }.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // ── 1. Header ──
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    // ── 2. Fleet Status ──
                    fleetStatusCard
                        .padding(.horizontal, 20)

                    // ── 4. En Hızlı 3 Araç ──
                    fastestVehiclesCard
                        .padding(.horizontal, 20)

                    // ── 4. Sürücü Skoru & Bugün KM (side-by-side) ──
                    HStack(spacing: 12) {
                        driverScoreCard
                        dailyKmCard
                    }
                    .padding(.horizontal, 20)

                    // ── 6. Son 5 Alarm ──
                    recentAlarmsCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
                .padding(.top, 2)
            }
            .refreshable {
                dashVM.refreshData()
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
            .background(ds.pageBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("ArveyGo")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ds.text1)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { selectedPage = .alarms } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(ds.text2)
                                .frame(width: 36, height: 36)
                                .background(ds.cardBg)
                                .clipShape(Circle())
                                .shadow(color: ds.cardShadow, radius: 4, x: 0, y: 2)
                            if dashVM.alerts.contains(where: { $0.severity == .red }) {
                                Circle()
                                    .fill(DS.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: -2, y: 2)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .toolbarBackground(ds.pageBg, for: .navigationBar)
        }
        .sheet(item: $selectedVehicle) { vehicle in
            VehicleDetailView(
                vehicle: vehicle,
                onNavigateToRouteHistory: { _ in
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
                },
                onNavigateToAddAlarm: { plate in
                    selectedVehicle = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        alarmsSearchText = ""
                        alarmsAutoOpenCreate = true
                        alarmsPrePlate = plate
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
    // MARK: — 1. Header
    // ═══════════════════════════════════════════════════════════════════════
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(greetingIcon)
                        .font(.system(size: 13))
                    Text(greetingText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ds.text3)
                }
                Text(authVM.currentUser?.name ?? "Admin")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ds.text1)
            }
            Spacer()
            Text(shortDateString)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ds.text3)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ds.primarySoft)
                .clipShape(Capsule())
        }
    }

    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return DL.goodMorning }
        if h < 18 { return DL.goodAfternoon }
        return DL.goodEvening
    }

    private var greetingIcon: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 6 { return "🌙" }
        if h < 12 { return "☀️" }
        if h < 18 { return "🌤️" }
        return "🌙"
    }

    private var shortDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMM, EEE"
        return f.string(from: Date())
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — 3. Fleet Status Card
    // ═══════════════════════════════════════════════════════════════════════
    private var fleetStatusCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Filo Durumu")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ds.text1)
                Spacer()
                Text("\(dashVM.totalVehicles) araç")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ds.text3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Status bar
            if dashVM.totalVehicles > 0 {
                GeometryReader { geo in
                    let total = max(CGFloat(dashVM.totalVehicles), 1)
                    let onW = geo.size.width * CGFloat(dashVM.kontakOnCount) / total
                    let offW = geo.size.width * CGFloat(dashVM.kontakOffCount) / total
                    let noW = geo.size.width * CGFloat(dashVM.bilgiYokCount) / total

                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3).fill(DS.green)
                            .frame(width: max(onW, 4))
                        RoundedRectangle(cornerRadius: 3).fill(DS.red)
                            .frame(width: max(offW, 4))
                        RoundedRectangle(cornerRadius: 3).fill(ds.text3.opacity(0.4))
                            .frame(width: max(noW, 4))
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }

            // Legend rows
            Divider().overlay(ds.divider).padding(.horizontal, 16)

            HStack(spacing: 0) {
                statusLegend(
                    color: DS.green,
                    value: "\(dashVM.kontakOnCount)",
                    label: "Kontak Açık"
                )
                dividerVert
                statusLegend(
                    color: DS.red,
                    value: "\(dashVM.kontakOffCount)",
                    label: "Kontak Kapalı"
                )
                dividerVert
                statusLegend(
                    color: ds.text3.opacity(0.6),
                    value: "\(dashVM.bilgiYokCount)",
                    label: "Bilgi Yok"
                )
            }
            .padding(.vertical, 12)
        }
        .background(ds.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.r, style: .continuous))
        .shadow(color: ds.cardShadow, radius: 8, x: 0, y: 3)
    }

    private func statusLegend(color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(ds.text1)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ds.text3)
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerVert: some View {
        Rectangle()
            .fill(ds.divider)
            .frame(width: 1, height: 36)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — 4. En Hızlı 3 Araç
    // ═══════════════════════════════════════════════════════════════════════
    private var fastestVehiclesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("En Hızlı Araçlar")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ds.text1)
                Spacer()
                Button { selectedPage = .vehicles } label: {
                    Text(DL.viewAll)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ds.primary)
                }
                .frame(minHeight: 36)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if fastestVehicles.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "gauge.with.dots.needle.0percent")
                            .font(.system(size: 24))
                            .foregroundStyle(ds.text3.opacity(0.4))
                        Text("Henüz araç verisi yok")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ds.text3)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(fastestVehicles.enumerated()), id: \.element.id) { index, vehicle in
                        Button { selectedVehicle = vehicle } label: {
                            fastRow(vehicle: vehicle, rank: index + 1)
                        }
                        .buttonStyle(BounceButtonStyle())

                        if index < fastestVehicles.count - 1 {
                            Divider()
                                .overlay(ds.divider)
                                .padding(.leading, 52)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .background(ds.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.r, style: .continuous))
        .shadow(color: ds.cardShadow, radius: 8, x: 0, y: 3)
    }

    private func fastRow(vehicle: Vehicle, rank: Int) -> some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(rank == 1 ? .white : ds.primary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(rank == 1 ? ds.primary : ds.primarySoft)
                )

            // Info
            VStack(alignment: .leading, spacing: 1) {
                Text(vehicle.plate)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ds.text1)
                Text(vehicle.model)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(ds.text3)
            }

            Spacer()

            // Speed
            Text("\(Int(vehicle.speed)) km/h")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(vehicle.speed > 120 ? DS.red : ds.text1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — 4a. Sürücü Skoru (compact, half-width)
    // ═══════════════════════════════════════════════════════════════════════
    private var driverScoreCard: some View {
        let score = dashVM.avgScore
        let ringColor = score >= 85 ? DS.green : score >= 70 ? DS.amber : DS.red

        return VStack(spacing: 0) {
            // Header
            HStack {
                Text(DL.driverScores)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ds.text1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Ring
            ZStack {
                Circle()
                    .stroke(ds.pageBg, lineWidth: 5)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(ds.text1)
            }
            .padding(.bottom, 8)

            // Footer
            HStack(spacing: 8) {
                miniStat(label: "Sürücü", value: "\(dashVM.drivers.count)")
                miniStat(label: "Araç", value: "\(dashVM.totalVehicles)")
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // Detail button
            Button { selectedPage = .drivers } label: {
                Text(DL.detailLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ds.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(ds.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(ds.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.r, style: .continuous))
        .shadow(color: ds.cardShadow, radius: 8, x: 0, y: 3)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — 4b. Bugün Toplam KM (compact, half-width)
    // ═══════════════════════════════════════════════════════════════════════
    private var dailyKmCard: some View {
        let totalDailyKm = dashVM.vehicles.reduce(0.0) { $0 + $1.dailyKm }
        let formattedKm = dashVM.formatKm(Int(totalDailyKm))

        return VStack(spacing: 0) {
            // Header
            HStack {
                Text("Bugün Mesafe")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ds.text1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Big KM value
            ZStack {
                Circle()
                    .stroke(ds.pageBg, lineWidth: 5)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: min(CGFloat(totalDailyKm) / max(CGFloat(dashVM.totalVehicles * 100), 1), 1.0))
                    .stroke(DS.sky, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(formattedKm)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(ds.text1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("km")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(ds.text3)
                }
            }
            .padding(.bottom, 8)

            // Footer stats
            HStack(spacing: 8) {
                miniStat(label: "Araç", value: "\(dashVM.totalVehicles)")
                miniStat(label: "Aktif", value: "\(dashVM.kontakOnCount)")
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // View all button
            Button { selectedPage = .vehicles } label: {
                Text(DL.viewAll)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.sky)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(DS.sky.opacity(isDark ? 0.15 : 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(ds.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.r, style: .continuous))
        .shadow(color: ds.cardShadow, radius: 8, x: 0, y: 3)
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ds.text1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ds.text3)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — 6. Son 5 Alarm
    // ═══════════════════════════════════════════════════════════════════════
    private var recentAlarmsCard: some View {
        let criticalCount = dashVM.alerts.filter { $0.severity == .red }.count

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(DL.recentAlarms)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ds.text1)

                if criticalCount > 0 {
                    Text("\(criticalCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(DS.red)
                        .clipShape(Circle())
                }

                Spacer()

                Button { selectedPage = .alarms } label: {
                    Text(DL.allLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ds.primary)
                }
                .frame(minHeight: 36)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 6)

            if dashVM.isLoadingAlerts && dashVM.alerts.isEmpty {
                HStack { Spacer(); ProgressView().padding(24); Spacer() }
            } else if dashVM.alerts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 24))
                            .foregroundStyle(DS.green.opacity(0.5))
                        Text("Alarm yok")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ds.text3)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dashVM.alerts.prefix(5).enumerated()), id: \.element.id) { i, alert in
                        alarmRow(alert: alert)
                        if i < min(dashVM.alerts.count, 5) - 1 {
                            Divider()
                                .overlay(ds.divider)
                                .padding(.leading, 52)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .background(ds.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.r, style: .continuous))
        .shadow(color: ds.cardShadow, radius: 8, x: 0, y: 3)
    }

    private func alarmRow(alert: FleetAlert) -> some View {
        let iconName: String = {
            switch alert.severity {
            case .red:   return "exclamationmark.octagon.fill"
            case .amber: return "exclamationmark.triangle.fill"
            case .green: return "checkmark.circle.fill"
            case .blue:  return "info.circle.fill"
            }
        }()

        return HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 15))
                .foregroundStyle(alert.severity.color)
                .frame(width: 32, height: 32)
                .background(alert.severity.color.opacity(isDark ? 0.18 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ds.text1)
                Text(alert.description)
                    .font(.system(size: 11))
                    .foregroundStyle(ds.text3)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(alert.dateString)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(ds.text3)
                Text(alert.timeString)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(ds.text3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Bounce Button Style
// ═══════════════════════════════════════════════════════════════════════════
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Alert Row (standalone — kept for other views)
// ═══════════════════════════════════════════════════════════════════════════
struct AlertRow: View {
    let alert: FleetAlert

    private var iconName: String {
        switch alert.severity {
        case .red:   return "exclamationmark.octagon.fill"
        case .amber: return "exclamationmark.triangle.fill"
        case .green: return "checkmark.circle.fill"
        case .blue:  return "info.circle.fill"
        }
    }

    var body: some View {
        let dsLight = DS(isDark: false)
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundStyle(alert.severity.color)
                .frame(width: 38, height: 38)
                .background(alert.severity.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(dsLight.text1)
                Text(alert.description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(dsLight.text2)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(alert.dateString)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(dsLight.text3)
                Text(alert.timeString)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(dsLight.text3)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Vehicle Row (kept for compatibility)
// ═══════════════════════════════════════════════════════════════════════════
struct VehicleRow: View {
    let vehicle: Vehicle
    var body: some View {
        let dsLight = DS(isDark: false)
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(vehicle.status.color.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: vehicle.mapIcon)
                    .font(.system(size: 15))
                    .foregroundStyle(vehicle.status.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.plate)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(dsLight.text1)
                Text("\(vehicle.model) · \(vehicle.city)")
                    .font(.system(size: 12))
                    .foregroundStyle(dsLight.text2)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(vehicle.formattedTodayKm)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(dsLight.text1)
                HStack(spacing: 3) {
                    Image(systemName: "speedometer").font(.system(size: 9))
                    Text("\(Int(vehicle.speed)) km/h").font(.system(size: 11))
                }
                .foregroundStyle(dsLight.text3)
            }
            Text(vehicle.status.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(vehicle.status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(vehicle.status.color.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Summary Pill (kept for compatibility)
// ═══════════════════════════════════════════════════════════════════════════
struct SummaryPill: View {
    let icon: String; let iconColor: Color; let title: String
    let value: String; let badge: String?; let badgeColor: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(iconColor)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
            if let b = badge { Text(b).font(.system(size: 9, weight: .semibold)).foregroundStyle(badgeColor) }
        }
        .frame(width: 100).padding(.vertical, 12).padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Dashboard Map Dot
// ═══════════════════════════════════════════════════════════════════════════
struct DashboardMapDot: View {
    let status: VehicleStatus
    var body: some View {
        ZStack {
            Circle().fill(status.color.opacity(0.25)).frame(width: 22, height: 22)
            Circle().fill(status.color).frame(width: 12, height: 12)
            Circle().stroke(.white, lineWidth: 1.5).frame(width: 12, height: 12)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Mini Line Chart (kept for other views)
// ═══════════════════════════════════════════════════════════════════════════
struct MiniLineChart: View {
    let values: [CGFloat]
    let lineColor: Color

    var body: some View {
        GeometryReader { geo in
            let maxVal = max(values.max() ?? 1, 1)
            let w = geo.size.width, h = geo.size.height
            let step = w / CGFloat(max(values.count - 1, 1))

            ZStack {
                Path { p in
                    for (i, val) in values.enumerated() {
                        let x = step * CGFloat(i), y = h - (val / maxVal) * h
                        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [lineColor.opacity(0.25), lineColor.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))

                Path { p in
                    for (i, val) in values.enumerated() {
                        let x = step * CGFloat(i), y = h - (val / maxVal) * h
                        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if let last = values.last {
                    Circle().fill(lineColor).frame(width: 7, height: 7)
                        .position(x: w, y: h - (last / maxVal) * h)
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Insight Bubble (kept for compatibility)
// ═══════════════════════════════════════════════════════════════════════════
struct InsightBubble: View {
    let text: String; let dotColor: Color; let tag: (String, Color)?
    var body: some View {
        let dsLight = DS(isDark: false)
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(dotColor).frame(width: 7, height: 7).padding(.top, 6)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(dsLight.text2)
                .lineSpacing(3)
            if let tag = tag {
                Spacer()
                Text(tag.0)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(tag.1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tag.1.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(dsLight.pageBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                ForEach(vehicles) { v in
                    Annotation(v.plate, coordinate: CLLocationCoordinate2D(latitude: v.lat, longitude: v.lng)) {
                        DashboardMapDot(status: v.status)
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
                        mapChip(color: .green, label: "Açık")
                        mapChip(color: .red, label: "Kapalı")
                        mapChip(color: .gray, label: "Yok")
                        mapChip(color: .orange, label: "Uyku")
                    }
                }
            }
        }
    }

    func mapChip(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Preview
// ═══════════════════════════════════════════════════════════════════════════
#Preview {
    DashboardView(
        showSideMenu: .constant(false),
        selectedPage: .constant(.dashboard),
        alarmsSearchText: .constant(""),
        alarmsAutoOpenCreate: .constant(false),
        alarmsPrePlate: .constant("")
    )
    .environmentObject(AuthViewModel())
}
