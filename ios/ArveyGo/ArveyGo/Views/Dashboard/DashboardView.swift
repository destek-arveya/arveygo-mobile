import SwiftUI
import MapKit

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Design System
// ═══════════════════════════════════════════════════════════════════════════
private enum DS {
    // Primary — #090F41 "sistemi patlatacak renk"
    static let primary      = Color(red: 9/255, green: 15/255, blue: 65/255)       // #090F41
    static let primaryLight = Color(red: 74/255, green: 83/255, blue: 160/255)     // #4A53A0
    static let primarySoft  = Color(red: 9/255, green: 15/255, blue: 65/255).opacity(0.07)

    // Backgrounds — temiz, hafif soğuk beyaz
    static let pageBg  = Color(red: 245/255, green: 246/255, blue: 250/255) // #F5F6FA
    static let cardBg  = Color.white

    // Status
    static let green  = Color(red: 34/255, green: 197/255, blue: 94/255)   // #22C55E
    static let red    = Color(red: 239/255, green: 68/255, blue: 68/255)   // #EF4444
    static let amber  = Color(red: 245/255, green: 158/255, blue: 11/255)  // #F59E0B
    static let sky    = Color(red: 56/255, green: 147/255, blue: 241/255)

    // Text — no pure black
    static let text1 = Color(red: 26/255, green: 26/255, blue: 26/255)     // #1A1A1A
    static let text2 = Color(red: 100/255, green: 100/255, blue: 112/255)
    static let text3 = Color(red: 160/255, green: 160/255, blue: 175/255)

    // Squircle radius (20-30px per UI rules)
    static let r: CGFloat = 22
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Dashboard View
// ═══════════════════════════════════════════════════════════════════════════
struct DashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var dashVM = DashboardViewModel()
    @ObservedObject private var DL = DashboardStrings.shared

    @Binding var showSideMenu: Bool
    @Binding var selectedPage: AppPage
    @Binding var alarmsSearchText: String
    @Binding var alarmsAutoOpenCreate: Bool
    @Binding var alarmsPrePlate: String

    @State private var selectedVehicle: Vehicle?
    @State private var showFullScreenMap = false

    // En hızlı 3 araç
    private var fastestVehicles: [Vehicle] {
        Array(dashVM.vehicles.sorted { $0.speed > $1.speed }.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── 1. Greeting ──
                    greetingSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // ── 2. Araç Durumu — Bento Grid ──
                    fleetStatusGrid
                        .padding(.horizontal, 20)

                    // ── 3. En Hızlı 3 Araç ──
                    fastestVehiclesCard
                        .padding(.horizontal, 20)

                    // ── 4. Sürücü Ortalama Skoru ──
                    driverScoreCard
                        .padding(.horizontal, 20)

                    // ── 5. Son 5 Alarm ──
                    recentAlarmsCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
                .padding(.top, 4)
            }
            .refreshable {
                dashVM.refreshData()
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
            .background(DS.pageBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            showSideMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DS.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(DL.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { selectedPage = .alarms } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(DS.primary.opacity(0.7))
                                .frame(width: 44, height: 44)
                            if dashVM.alerts.contains(where: { $0.severity == .red }) {
                                Circle()
                                    .fill(DS.red)
                                    .frame(width: 9, height: 9)
                                    .offset(x: -10, y: 12)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
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
    // MARK: — 1. Greeting
    // ═══════════════════════════════════════════════════════════════════════
    private var greetingSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greetingText) 👋")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.text2)
                Text(authVM.currentUser?.name ?? "Admin")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.primary)
            }
            Spacer()
            Text(shortDateString)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(DS.primarySoft)
                .clipShape(Capsule())
        }
    }

    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return DL.goodMorning }
        if h < 18 { return DL.goodAfternoon }
        return DL.goodEvening
    }

    private var shortDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMM, EEEE"
        return f.string(from: Date())
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — 2. Fleet Status Bento Grid
    // ═══════════════════════════════════════════════════════════════════════
    private var fleetStatusGrid: some View {
        VStack(spacing: 12) {
            // Row 1: Büyük "Toplam Araç" + iki küçük stacked
            HStack(spacing: 12) {
                // HERO — Toplam Araç
                heroStatCard(
                    icon: "car.2.fill",
                    value: "\(dashVM.totalVehicles)",
                    label: DL.vehiclesTitle,
                    color: DS.primary
                )
                .frame(maxWidth: .infinity)
                .frame(height: 140)

                // Kontak Açık + Kontak Kapalı
                VStack(spacing: 12) {
                    miniStatCard(
                        icon: "power",
                        value: "\(dashVM.kontakOnCount)",
                        label: DL.kontakOnChip(dashVM.kontakOnCount)
                            .replacingOccurrences(of: "\(dashVM.kontakOnCount) ", with: ""),
                        color: DS.green
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)

                    miniStatCard(
                        icon: "poweroff",
                        value: "\(dashVM.kontakOffCount)",
                        label: DL.kontakOffChip(dashVM.kontakOffCount)
                            .replacingOccurrences(of: "\(dashVM.kontakOffCount) ", with: ""),
                        color: DS.red
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                }
                .frame(maxWidth: .infinity)
            }

            // Row 2: Bilgi Yok — full width
            miniStatCard(
                icon: "wifi.slash",
                value: "\(dashVM.bilgiYokCount)",
                label: DL.bilgiYokChip(dashVM.bilgiYokCount)
                    .replacingOccurrences(of: "\(dashVM.bilgiYokCount) ", with: ""),
                color: DS.text3
            )
            .frame(height: 64)
        }
    }

    // Hero stat — big number card with gradient accent
    private func heroStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: DS.r, style: .continuous)
                .fill(DS.cardBg)

            // Gradient accent bar at top
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(
                    colors: [color, color.opacity(0.5)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(width: 44, height: 4)
                .padding(.top, 14)
                .padding(.leading, 18)

            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)
                    .padding(.top, 28)

                Spacer()

                Text(value)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.text1)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.text2)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 18)
        }
        .shadow(color: color.opacity(0.08), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // Mini stat — compact horizontal card
    private func miniStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.text1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.text3)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — 3. En Hızlı 3 Araç
    // ═══════════════════════════════════════════════════════════════════════
    private var fastestVehiclesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gauge.open.with.lines.needle.84percent.exclamation")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.primary)
                    Text("En Hızlı Araçlar")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.text1)
                }
                Spacer()
                Button { selectedPage = .vehicles } label: {
                    HStack(spacing: 4) {
                        Text(DL.viewAll)
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(DS.primary)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 8)

            if fastestVehicles.isEmpty {
                // Friendly empty state
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(DS.text3.opacity(0.5))
                        Text("Henüz araç verisi yok")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.text2)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(fastestVehicles.enumerated()), id: \.element.id) { index, vehicle in
                        Button { selectedVehicle = vehicle } label: {
                            fastVehicleRow(vehicle: vehicle, rank: index + 1)
                        }
                        .buttonStyle(BounceButtonStyle())

                        if index < fastestVehicles.count - 1 {
                            Divider()
                                .padding(.leading, 62)
                                .padding(.trailing, 18)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.r, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    private func fastVehicleRow(vehicle: Vehicle, rank: Int) -> some View {
        HStack(spacing: 14) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rank == 1 ? DS.primary : DS.primary.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text("\(rank)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(rank == 1 ? .white : DS.primary)
            }

            // Vehicle info
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.plate)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.text1)
                Text("\(vehicle.model) · \(vehicle.city)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(DS.text2)
                    .lineLimit(1)
            }

            Spacer()

            // Speed — prominent
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(vehicle.speed > 120 ? DS.red : DS.primary)
                Text("\(Int(vehicle.speed))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(vehicle.speed > 120 ? DS.red : DS.text1)
                Text("km/h")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.text3)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — 4. Sürücü Ortalama Skoru
    // ═══════════════════════════════════════════════════════════════════════
    private var driverScoreCard: some View {
        let score = dashVM.avgScore
        let grade = score >= 85 ? "A" : score >= 70 ? "B" : score >= 50 ? "C" : "D"
        let ringColor = score >= 85 ? DS.green : score >= 70 ? DS.amber : DS.red

        return HStack(spacing: 20) {
            // Ring
            ZStack {
                Circle()
                    .stroke(DS.pageBg, lineWidth: 8)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: -2) {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.text1)
                    Text(grade)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ringColor)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.primary)
                    Text(DL.driverScores)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.text1)
                }

                Text(DL.driverPerformance)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DS.text2)
                    .lineSpacing(2)

                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.text3)
                    Text("\(dashVM.drivers.count) sürücü")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.text3)
                }

                Button { selectedPage = .drivers } label: {
                    Text(DL.detailLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [DS.primary, DS.primaryLight],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(minHeight: 44)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.r, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: — 5. Son 5 Alarm
    // ═══════════════════════════════════════════════════════════════════════
    private var recentAlarmsCard: some View {
        let criticalCount = dashVM.alerts.filter { $0.severity == .red }.count

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.red)
                    Text(DL.recentAlarms)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.text1)
                }

                Spacer()

                if criticalCount > 0 {
                    Text("\(criticalCount) kritik")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DS.red.opacity(0.1))
                        .clipShape(Capsule())
                }

                Button { selectedPage = .alarms } label: {
                    HStack(spacing: 4) {
                        Text(DL.allLabel)
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(DS.primary)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 6)

            // Content
            if dashVM.isLoadingAlerts && dashVM.alerts.isEmpty {
                HStack { Spacer(); ProgressView().padding(28); Spacer() }
            } else if dashVM.alerts.isEmpty {
                // Friendly empty state
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(DS.green.opacity(0.6))
                        Text("Her şey yolunda, alarm yok! 🎉")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DS.text2)
                    }
                    .padding(.vertical, 28)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dashVM.alerts.prefix(5).enumerated()), id: \.element.id) { i, alert in
                        AlertRow(alert: alert)
                        if i < min(dashVM.alerts.count, 5) - 1 {
                            Divider()
                                .padding(.leading, 62)
                                .padding(.trailing, 18)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.r, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Bounce Button Style (micro-interaction)
// ═══════════════════════════════════════════════════════════════════════════
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Alert Row
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
                    .foregroundStyle(DS.text1)
                Text(alert.description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(DS.text2)
                    .lineLimit(1)
            }

            Spacer()

            Text(alert.time)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(DS.text3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Vehicle Row (kept for compatibility — VehicleDetailView etc.)
// ═══════════════════════════════════════════════════════════════════════════
struct VehicleRow: View {
    let vehicle: Vehicle
    var body: some View {
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
                    .foregroundStyle(DS.text1)
                Text("\(vehicle.model) · \(vehicle.city)")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.text2)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(vehicle.formattedTodayKm)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.text1)
                HStack(spacing: 3) {
                    Image(systemName: "speedometer").font(.system(size: 9))
                    Text("\(Int(vehicle.speed)) km/h").font(.system(size: 11))
                }
                .foregroundStyle(DS.text3)
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
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(dotColor).frame(width: 7, height: 7).padding(.top, 6)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(DS.text2)
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
        .background(DS.pageBg)
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
