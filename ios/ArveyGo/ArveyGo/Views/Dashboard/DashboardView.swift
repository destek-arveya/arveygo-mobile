import SwiftUI
import MapKit

struct DashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var dashVM = DashboardViewModel()
    @Binding var showSideMenu: Bool
    @State private var selectedVehicle: Vehicle?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            // Greeting Section
                            greetingSection

                            // Period Filter
                            periodFilter

                            // Metrics Strip
                            metricsStrip

                            // Main Grid
                            VStack(spacing: 14) {
                                // Vehicle List Card
                                vehicleListCard

                                // Driver Scores Card
                                driverScoresCard

                                // Mini Map Card
                                mapCard

                                // Alerts Card
                                alertsCard

                                // AI Insights Card
                                aiInsightsCard
                            }

                            Spacer().frame(height: 16)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { withAnimation(.spring(response: 0.3)) { showSideMenu.toggle() } }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.navy)
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 1) {
                            Text("Dashboard")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.navy)
                            Text("Araç Takip / Genel Bakış")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            Button(action: {}) {
                                Image(systemName: "bell")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.textMuted)
                                    .overlay(
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 7, height: 7)
                                            .offset(x: 6, y: -6)
                                    )
                            }
                            AvatarCircle(
                                initials: authVM.currentUser?.avatar ?? "A",
                                size: 30
                            )
                        }
                    }
                }
            }
        .sheet(item: $selectedVehicle) { vehicle in
            VehicleDetailView(vehicle: vehicle)
        }
    }

    // MARK: - Greeting
    var greetingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(greetingText + ", \(authVM.currentUser?.name ?? "Admin") 👋")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.navy)
                Spacer()
                // Date pill
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(dateString)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(AppTheme.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.surface)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.borderSoft, lineWidth: 1)
                )
            }
            Text("Filonuzun güncel durumu aşağıda özetlenmiştir.")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
        }
    }

    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Günaydın" }
        if hour < 18 { return "İyi Günler" }
        return "İyi Akşamlar"
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM yyyy, EEEE"
        return formatter.string(from: Date())
    }

    // MARK: - Period Filter
    var periodFilter: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Filo Özeti")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.navy)
                }
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(["today", "week", "month", "quarter"], id: \.self) { period in
                        Button(action: { dashVM.setPeriod(period) }) {
                            Text(periodLabel(period))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(dashVM.selectedPeriod == period ? .white : AppTheme.textMuted)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(dashVM.selectedPeriod == period ? AppTheme.navy : Color.clear)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(dashVM.selectedPeriod == period ? AppTheme.navy : AppTheme.borderSoft, lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }

    func periodLabel(_ period: String) -> String {
        switch period {
        case "today": return "Bugün"
        case "week": return "Hafta"
        case "month": return "Ay"
        case "quarter": return "3 Ay"
        default: return period
        }
    }

    // MARK: - Metrics Strip
    var metricsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(dashVM.metrics) { metric in
                    MetricCard(metric: metric)
                        .frame(width: 140)
                }
            }
            .background(AppTheme.borderSoft)
            .cornerRadius(12)
            .shadow(color: AppTheme.navy.opacity(0.04), radius: 8, y: 4)
        }
    }

    // MARK: - Vehicle List Card
    var vehicleListCard: some View {
        CardView(title: "Araçlar", count: "\(dashVM.totalVehicles)", actionLabel: "Tümünü Gör") {
            // Action
        } content: {
            VStack(spacing: 0) {
                ForEach(dashVM.vehicles) { vehicle in
                    Button(action: { selectedVehicle = vehicle }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(vehicle.status.color)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(vehicle.plate)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(AppTheme.navy)
                                Text("\(vehicle.model) · \(vehicle.city)")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(AppTheme.textMuted)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(vehicle.formattedTotalKm)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.navy)
                                Text("km")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textFaint)
                            }
                            .frame(minWidth: 55)

                            StatusBadge(status: vehicle.status)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.clear)
                    }
                    .buttonStyle(.plain)

                    if vehicle.id != dashVM.vehicles.last?.id {
                        Divider()
                            .padding(.leading, 36)
                    }
                }
            }
        }
    }

    // MARK: - Driver Scores Card
    var driverScoresCard: some View {
        CardView(title: "Sürücü Skorları", count: "Ort: \(dashVM.avgScore)", actionLabel: "Detay") {
        } content: {
            VStack(spacing: 0) {
                ForEach(Array(dashVM.drivers.enumerated()), id: \.element.id) { index, driver in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textFaint)
                            .frame(width: 20, alignment: .center)

                        AvatarCircle(
                            initials: String(driver.name.prefix(1)),
                            color: driver.color,
                            size: 28
                        )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(driver.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.navy)
                                .lineLimit(1)
                            Text(driver.plate)
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                        }

                        Spacer()

                        // Score bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppTheme.bgAlt)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(driver.scoreColor)
                                    .frame(width: geo.size.width * CGFloat(driver.score) / 100, height: 4)
                            }
                        }
                        .frame(width: 50, height: 4)

                        Text("\(driver.score)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(driver.scoreColor)
                            .frame(width: 28, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)

                    if index < dashVM.drivers.count - 1 {
                        Divider()
                            .padding(.leading, 46)
                    }
                }
            }
        }
    }

    // MARK: - Map Card
    var mapCard: some View {
        CardView(title: "Filo Haritası", actionLabel: "Canlı Harita") {
        } content: {
            ZStack(alignment: .bottomLeading) {
                Map {
                    ForEach(dashVM.vehicles) { vehicle in
                        Annotation(vehicle.plate, coordinate: CLLocationCoordinate2D(latitude: vehicle.lat, longitude: vehicle.lng)) {
                            ZStack {
                                Circle()
                                    .fill(vehicle.status.color)
                                    .frame(width: 12, height: 12)
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 0))

                // Legend
                HStack(spacing: 12) {
                    legendItem(color: AppTheme.online, text: "Aktif")
                    legendItem(color: AppTheme.offline, text: "Çevrimdışı")
                    legendItem(color: AppTheme.idle, text: "Rölanti")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
                .padding(10)
            }
        }
    }

    func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textMuted)
        }
    }

    // MARK: - Alerts Card
    var alertsCard: some View {
        CardView(title: "Son Alarmlar", count: "\(dashVM.alerts.count)", actionLabel: "Tümü") {
        } content: {
            VStack(spacing: 0) {
                ForEach(dashVM.alerts) { alert in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(alert.severity.color)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.navy)
                            Text(alert.description)
                                .font(.system(size: 10.5))
                                .foregroundColor(AppTheme.textMuted)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(alert.time)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textFaint)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if alert.id != dashVM.alerts.last?.id {
                        Divider()
                            .padding(.leading, 34)
                    }
                }
            }
        }
    }

    // MARK: - AI Insights Card
    var aiInsightsCard: some View {
        CardView(title: "AI Filo Analizi", actionLabel: nil) {
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Filonuzda **\(dashVM.onlineCount)** araç aktif durumda. Günlük toplam **\(dashVM.formatKm(dashVM.todayKm)) km** yol katedildi.")
                    .font(.system(size: 12.5))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(4)

                VStack(spacing: 8) {
                    insightRow(
                        text: "34 ABC 123 plakalı araç bugün en yüksek mesafeyi kat etti (312 km)",
                        dotColor: AppTheme.online,
                        tag: nil
                    )
                    insightRow(
                        text: "2 araç çevrimdışı — bakım kontrolü önerilir",
                        dotColor: AppTheme.offline,
                        tag: ("Yüksek", Color.red)
                    )
                    insightRow(
                        text: "Ortalama sürücü skoru 78 — geçen aya göre %3 artış",
                        dotColor: AppTheme.indigo,
                        tag: ("Düşük", AppTheme.online)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    func insightRow(text: String, dotColor: Color, tag: (String, Color)?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            Text(text)
                .font(.system(size: 11.5))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(2)

            if let tag = tag {
                Spacer()
                Text(tag.0)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(tag.1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tag.1.opacity(0.1))
                    .cornerRadius(20)
            }
        }
        .padding(10)
        .background(AppTheme.bg)
        .cornerRadius(8)
    }
}

#Preview {
    DashboardView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
