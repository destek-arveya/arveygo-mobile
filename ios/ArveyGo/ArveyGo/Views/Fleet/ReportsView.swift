import SwiftUI

// ═══════════════════════════════════════════════════════════════
// REPORTS VIEW — Catalog + Detail with Charts
// ═══════════════════════════════════════════════════════════════

struct ReportsView: View {
    @Binding var showSideMenu: Bool
    @State private var selectedReportType: String? = nil

    var body: some View {
        ZStack {
            if let reportType = selectedReportType {
                ReportDetailPage(reportType: reportType, onBack: {
                    withAnimation(.spring(response: 0.3)) { selectedReportType = nil }
                })
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ReportsCatalogPage(showSideMenu: $showSideMenu, onSelectReport: { type in
                    withAnimation(.spring(response: 0.3)) { selectedReportType = type }
                })
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: selectedReportType)
    }
}

// ═══════════════════════════════════════════════════════════════
// 1) CATALOG PAGE — Grid of report types
// ═══════════════════════════════════════════════════════════════

private struct ReportsCatalogPage: View {
    @Binding var showSideMenu: Bool
    let onSelectReport: (String) -> Void

    @State private var catalogItems: [ReportCatalogItem] = []
    @State private var isLoading = true
    @State private var error: String? = nil

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            ReportsTopBar(title: "Raporlar", showSideMenu: $showSideMenu)

            if isLoading {
                Spacer()
                ProgressView().tint(AppTheme.indigo)
                Spacer()
            } else if let error = error {
                Spacer()
                ErrorCardView(message: error) { loadCatalog() }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(catalogItems) { item in
                            ReportCatalogCard(item: item) {
                                onSelectReport(item.type)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(AppTheme.bg)
        .task { loadCatalog() }
    }

    func loadCatalog() {
        Task {
            isLoading = true
            error = nil
            do {
                let json = try await APIService.shared.get("/api/mobile/reports/catalog")
                guard let dataArr = json["data"] as? [[String: Any]] else { return }
                catalogItems = dataArr.map { dict in
                    ReportCatalogItem(
                        type: dict["type"] as? String ?? "",
                        label: dict["label"] as? String ?? "",
                        description: dict["description"] as? String ?? "",
                        accent: dict["accent"] as? String ?? "#6366F1"
                    )
                }
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

private struct ReportCatalogCard: View {
    let item: ReportCatalogItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(Color(hex: item.accent).opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: reportIcon(item.type))
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: item.accent))
                }

                Spacer()

                Text(item.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
                    .lineLimit(1)

                Text(item.description)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(AppTheme.surface)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════════════
// 2) REPORT DETAIL PAGE
// ═══════════════════════════════════════════════════════════════

private struct ReportDetailPage: View {
    let reportType: String
    let onBack: () -> Void

    @State private var reportData: [String: Any]? = nil
    @State private var isLoading = true
    @State private var error: String? = nil
    @State private var currentPage = 1

    // Filters
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedVehicles: Set<String> = []
    @State private var vehicleOptions: [FilterOption] = []
    @State private var showDatePicker = false
    @State private var showVehiclePicker = false

    var body: some View {
        VStack(spacing: 0) {
            ReportsTopBar(
                title: (reportData?["title"] as? String) ?? reportType.capitalized,
                showBack: true,
                onBack: onBack,
                accent: Color(hex: (reportData?["accent"] as? String) ?? "#6366F1")
            )

            if isLoading && reportData == nil {
                Spacer()
                ProgressView().tint(AppTheme.indigo)
                Spacer()
            } else if let error = error, reportData == nil {
                Spacer()
                ErrorCardView(message: error) { loadReport() }
                Spacer()
            } else if let data = reportData {
                let accent = Color(hex: (data["accent"] as? String) ?? "#6366F1")

                ScrollView {
                    VStack(spacing: 14) {
                        // Subtitle
                        if let subtitle = data["subtitle"] as? String, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Filters
                        FiltersBarView(
                            reportType: reportType,
                            startDate: $startDate,
                            endDate: $endDate,
                            vehicleOptions: vehicleOptions,
                            selectedVehicles: $selectedVehicles,
                            showDatePicker: $showDatePicker,
                            showVehiclePicker: $showVehiclePicker,
                            onApply: { currentPage = 1; loadReport() }
                        )

                        // Summary Cards
                        if let cards = data["summary_cards"] as? [[String: Any]], !cards.isEmpty {
                            SummaryCardsGrid(cards: cards, accent: accent)
                        }

                        // Charts
                        if let charts = data["charts"] as? [[String: Any]] {
                            ForEach(Array(charts.enumerated()), id: \.offset) { _, chart in
                                ChartCardView(chart: chart, accent: accent)
                            }
                        }

                        // Leaderboards (driver score)
                        if let leaderboards = data["leaderboards"] as? [String: Any] {
                            LeaderboardSectionView(leaderboards: leaderboards, accent: accent)
                        }

                        // Selected Driver Detail
                        if let selectedDriver = data["selected_driver"] as? [String: Any] {
                            DriverScoreDetailCardView(driver: selectedDriver, accent: accent)
                        }

                        // Data Table
                        if let table = data["table"] as? [String: Any] {
                            DataTableCardView(table: table)
                        }

                        // Pagination
                        if let pagination = data["pagination"] as? [String: Any],
                           let lastPage = pagination["last_page"] as? Int, lastPage > 1 {
                            PaginationBarView(
                                page: pagination["page"] as? Int ?? 1,
                                lastPage: lastPage,
                                total: pagination["total"] as? Int ?? 0,
                                onPageChange: { p in currentPage = p; loadReport() }
                            )
                        }

                        if isLoading {
                            ProgressView().tint(accent).padding(24)
                        }

                        Spacer().frame(height: 80)
                    }
                    .padding(16)
                }
            }
        }
        .background(AppTheme.bg)
        .task { loadReport() }
        .sheet(isPresented: $showDatePicker) {
            DateRangeSheetView(
                startDate: $startDate,
                endDate: $endDate,
                onConfirm: { currentPage = 1; loadReport() }
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showVehiclePicker) {
            VehicleMultiSelectSheetView(
                options: vehicleOptions,
                selectedVehicles: $selectedVehicles,
                onConfirm: { currentPage = 1; loadReport() }
            )
            .presentationDetents([.large])
        }
    }

    func buildPath() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let base = reportType == "fuel_prices"
            ? "/api/mobile/reports/fuel/prices"
            : "/api/mobile/reports/\(reportType)"

        var params: [String] = []
        if reportType != "fuel_prices" {
            params.append("start_date=\(fmt.string(from: startDate))")
            params.append("end_date=\(fmt.string(from: endDate))")
        }
        for v in selectedVehicles { params.append("vehicles[]=\(v)") }
        params.append("page=\(currentPage)")
        params.append("per_page=25")
        return "\(base)?\(params.joined(separator: "&"))"
    }

    func loadReport() {
        Task {
            isLoading = true
            error = nil
            do {
                let json = try await APIService.shared.get(buildPath())
                reportData = (json["data"] as? [String: Any]) ?? json

                // Extract vehicle options
                if let filters = reportData?["filters"] as? [String: Any],
                   let opts = filters["vehicle_options"] as? [[String: Any]] {
                    vehicleOptions = opts.map {
                        FilterOption(value: $0["value"] as? String ?? "", label: $0["label"] as? String ?? "")
                    }
                }
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 3) SUMMARY CARDS
// ═══════════════════════════════════════════════════════════════

private struct SummaryCardsGrid: View {
    let cards: [[String: Any]]
    let accent: Color

    let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                let tone = card["tone"] as? String ?? "navy"
                let fg = toneColor(tone)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(fg)
                            .frame(width: 8, height: 8)
                        Text(card["label"] as? String ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .lineLimit(1)
                    }
                    Text(card["value"] as? String ?? "")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surface)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 4) CHART COMPONENTS
// ═══════════════════════════════════════════════════════════════

private struct ChartCardView: View {
    let chart: [String: Any]
    let accent: Color

    var body: some View {
        let type = chart["type"] as? String ?? "bars"
        let title = chart["title"] as? String ?? ""

        VStack(alignment: .leading, spacing: 14) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
            }

            switch type {
            case "bars":
                BarChartView(chart: chart, accent: accent)
            case "trend":
                TrendChartView(chart: chart, accent: accent)
            case "ranking":
                RankingListView(chart: chart, accent: accent)
            case "stacked":
                StackedBarChartView(chart: chart)
            case "heatmap":
                HeatmapChartView(chart: chart, accent: accent)
            default:
                BarChartView(chart: chart, accent: accent)
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

// ── Bar Chart ──
private struct BarChartView: View {
    let chart: [String: Any]
    let accent: Color

    var body: some View {
        let bars = chart["bars"] as? [[String: Any]] ?? []
        let maxVal = bars.map { extractNumeric($0["value"]) }.max() ?? 1.0

        VStack(spacing: 10) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                let label = bar["label"] as? String ?? ""
                let valueStr = bar["value"] as? String ?? "\(bar["value"] ?? 0)"
                let numVal = extractNumeric(bar["value"])
                let pct = maxVal > 0 ? max(0.05, min(1, numVal / maxVal)) : 0.1

                VStack(spacing: 4) {
                    HStack {
                        Text(label)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text(valueStr)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(accent.opacity(0.08))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * pct, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
    }
}

// ── Trend Chart ──
private struct TrendChartView: View {
    let chart: [String: Any]
    let accent: Color

    var body: some View {
        let points = chart["points"] as? [[String: Any]] ?? []
        let values = points.map { extractNumeric($0["value"]) }
        let maxVal = max(values.max() ?? 1, 1)

        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(points.enumerated()), id: \.offset) { idx, pt in
                    let v = values[idx]
                    let hFrac = max(0.02, min(1, v / maxVal))
                    let barColor = (pt["color"] as? String).map { Color(hex: $0) } ?? accent

                    VStack(spacing: 2) {
                        Text(pt["value"] as? String ?? "")
                            .font(.system(size: 8))
                            .foregroundColor(AppTheme.textMuted)

                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(barColor.opacity(0.85))
                                    .frame(height: geo.size.height * hFrac)
                            }
                        }
                    }
                }
            }
            .frame(height: 100)

            HStack(spacing: 3) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                    Text(pt["label"] as? String ?? "")
                        .font(.system(size: 8))
                        .foregroundColor(AppTheme.textFaint)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// ── Ranking List ──
private struct RankingListView: View {
    let chart: [String: Any]
    let accent: Color

    var body: some View {
        let items = chart["items"] as? [[String: Any]] ?? []

        VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(spacing: 12) {
                    // Rank badge
                    ZStack {
                        Circle()
                            .fill(idx == 0 ? accent.opacity(0.15) : Color.gray.opacity(0.1))
                            .frame(width: 28, height: 28)
                        Text("\(idx + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(idx == 0 ? accent : AppTheme.textMuted)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item["label"] as? String ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.navy)
                            .lineLimit(1)
                        if let sub = item["sub"] as? String, !sub.isEmpty {
                            Text(sub)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }

                    Spacer()

                    Text(item["value"] as? String ?? "")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(accent)
                }
                .padding(12)
                .background(AppTheme.bg)
                .cornerRadius(10)
            }
        }
    }
}

// ── Stacked Bar Chart ──
private struct StackedBarChartView: View {
    let chart: [String: Any]
    let colors: [Color] = [Color(hex: "#d97706"), Color(hex: "#16a34a"), Color(hex: "#6366F1"), Color(hex: "#0ea5e9")]

    var body: some View {
        let rows = chart["rows"] as? [[String: Any]] ?? []

        VStack(spacing: 14) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(spacing: 6) {
                    HStack {
                        Text(row["label"] as? String ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.navy)
                        Spacer()
                        Text(row["total_label"] as? String ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                    }

                    if let segments = row["segments"] as? [[String: Any]] {
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                ForEach(Array(segments.enumerated()), id: \.offset) { j, seg in
                                    let pct = CGFloat((seg["percent"] as? Double ?? 0) / 100.0)
                                    Rectangle()
                                        .fill(colors[j % colors.count].opacity(0.8))
                                        .frame(width: max(1, geo.size.width * pct))
                                }
                            }
                            .cornerRadius(6)
                        }
                        .frame(height: 12)

                        // Legend
                        HStack(spacing: 12) {
                            ForEach(Array(segments.enumerated()), id: \.offset) { j, seg in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(colors[j % colors.count])
                                        .frame(width: 8, height: 8)
                                    Text("\(seg["label"] as? String ?? "") %\(Int(seg["percent"] as? Double ?? 0))")
                                        .font(.system(size: 10))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                        }
                    }

                    if let meta = row["meta"] as? String, !meta.isEmpty {
                        Text(meta)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textFaint)
                    }
                }
            }
        }
    }
}

// ── Heatmap Chart ──
private struct HeatmapChartView: View {
    let chart: [String: Any]
    let accent: Color

    var body: some View {
        let matrix = chart["matrix"] as? [String: Any] ?? [:]
        let cols = matrix["columns"] as? [String] ?? []
        let rows = matrix["rows"] as? [[String: Any]] ?? []

        VStack(spacing: 4) {
            // Header
            HStack {
                Text("").frame(width: 50)
                ForEach(cols, id: \.self) { col in
                    Text(col)
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row["label"] as? String ?? "")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 50, alignment: .leading)

                    let vals = row["values"] as? [Int] ?? []
                    ForEach(Array(vals.enumerated()), id: \.offset) { _, v in
                        let intensity = min(1.0, Double(v) / 10.0)
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(v == 0 ? AppTheme.bg : accent.opacity(0.1 + intensity * 0.7))
                                .aspectRatio(1.6, contentMode: .fit)
                            if v > 0 {
                                Text("\(v)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(intensity > 0.5 ? .white : accent)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 5) LEADERBOARD (Driver Score Report)
// ═══════════════════════════════════════════════════════════════

private struct LeaderboardSectionView: View {
    let leaderboards: [String: Any]
    let accent: Color

    var body: some View {
        let best = leaderboards["best"] as? [[String: Any]] ?? []

        VStack(alignment: .leading, spacing: 12) {
            Text("Sürücü Sıralaması")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.navy)

            ForEach(Array(best.enumerated()), id: \.offset) { idx, d in
                LeaderboardRowView(
                    rank: idx + 1,
                    name: d["driver_name"] as? String ?? "",
                    score: d["total_score"] as? Int ?? 0,
                    label: d["status_label"] as? String ?? "",
                    accent: accent
                )
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

private struct LeaderboardRowView: View {
    let rank: Int
    let name: String
    let score: Int
    let label: String
    let accent: Color

    var scoreColor: Color {
        score >= 80 ? Color(hex: "#16a34a") : score >= 60 ? Color(hex: "#d97706") : Color(hex: "#dc2626")
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.1))
                    .frame(width: 30, height: 30)
                Text("#\(rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.navy)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Text("\(score)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(scoreColor)
            }
        }
        .padding(12)
        .background(AppTheme.bg)
        .cornerRadius(10)
    }
}

// ═══════════════════════════════════════════════════════════════
// 6) DRIVER SCORE DETAIL CARD
// ═══════════════════════════════════════════════════════════════

private struct DriverScoreDetailCardView: View {
    let driver: [String: Any]
    let accent: Color

    var body: some View {
        let totalScore = driver["total_score"] as? Int ?? 0
        let safetyScore = driver["safety_score"] as? Int ?? 0
        let efficiencyScore = driver["efficiency_score"] as? Int ?? 0
        let disciplineScore = driver["discipline_score"] as? Int ?? 0
        let driverName = driver["driver_name"] as? String ?? ""

        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Text(String(driverName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(driverName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.navy)
                    Text("Genel Skor: \(totalScore) / 100")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
            }

            // Score bars
            ScoreBarView(label: "Güvenlik", score: safetyScore, color: Color(hex: "#16a34a"))
            ScoreBarView(label: "Verimlilik", score: efficiencyScore, color: Color(hex: "#6366F1"))
            ScoreBarView(label: "Disiplin", score: disciplineScore, color: Color(hex: "#d97706"))

            // AI Analysis
            if let ai = driver["ai_analysis"] as? [String: Any] {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#d97706"))
                        Text("AI Analiz")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#92400e"))
                    }
                    Text(ai["summary"] as? String ?? ai["headline"] as? String ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#78350f"))
                }
                .padding(12)
                .background(Color(hex: "#FEF3C7"))
                .cornerRadius(10)
            }

            // Trend chart
            if let trend = driver["trend_chart"] as? [[String: Any]], !trend.isEmpty {
                Text("Günlük Skor Trendi")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
                TrendChartView(chart: ["points": trend], accent: accent)
            }

            // Behavior counts
            if let behaviors = driver["behavior_counts"] as? [String: Any] {
                Text("Davranış Detayları")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.navy)

                let behaviorMap: [(String, String)] = [
                    ("harsh_braking_count", "Sert Fren"),
                    ("harsh_cornering_count", "Sert Direksiyon"),
                    ("harsh_acceleration_count", "Sert Hızlanma"),
                    ("off_hours_usage_count", "Mesai Dışı"),
                    ("towing_count", "Taşıma/Çekme"),
                    ("speed_violation_count", "Hız İhlali")
                ]

                ForEach(behaviorMap, id: \.0) { key, label in
                    let count = behaviors[key] as? Int ?? 0
                    if count > 0 {
                        HStack {
                            Text(label)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(count > 5 ? Color(hex: "#dc2626") : AppTheme.navy)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

private struct ScoreBarView: View {
    let label: String
    let score: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("\(score)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.1))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 7) DATA TABLE
// ═══════════════════════════════════════════════════════════════

private struct DataTableCardView: View {
    let table: [String: Any]

    var body: some View {
        let columns = table["columns"] as? [String] ?? []
        let rows = table["rows"] as? [[String: Any]] ?? []

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "tablecells")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.indigo)
                Text("Detay Tablosu")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
                Spacer()
                Text("\(rows.count) kayıt")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        ForEach(columns, id: \.self) { col in
                            Text(col)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppTheme.navy)
                                .frame(width: 100, alignment: .leading)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(AppTheme.navy.opacity(0.06))
                    .cornerRadius(8)

                    // Rows
                    ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                        HStack(spacing: 0) {
                            ForEach(Array(columns.enumerated()), id: \.offset) { colIdx, col in
                                let value = row[col] as? String ?? findValueByIndex(row: row, index: colIdx)
                                Text(value)
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 100, alignment: .leading)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .background(idx % 2 == 0 ? Color.clear : AppTheme.bg.opacity(0.5))
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

// ═══════════════════════════════════════════════════════════════
// 8) FILTERS BAR
// ═══════════════════════════════════════════════════════════════

private struct FiltersBarView: View {
    let reportType: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    let vehicleOptions: [FilterOption]
    @Binding var selectedVehicles: Set<String>
    @Binding var showDatePicker: Bool
    @Binding var showVehiclePicker: Bool
    let onApply: () -> Void

    var body: some View {
        let dateFmt = DateFormatter()
        let _ = dateFmt.dateFormat = "dd MMM"

        HStack(spacing: 8) {
            if reportType != "fuel_prices" {
                Button(action: { showDatePicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text("\(dateFmt.string(from: startDate)) – \(dateFmt.string(from: endDate))")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.indigo.opacity(0.08))
                    .foregroundColor(AppTheme.indigo)
                    .cornerRadius(10)
                }
            }

            if !vehicleOptions.isEmpty {
                let vehicleLabel: String = {
                    if selectedVehicles.isEmpty { return "Tüm Araçlar" }
                    if selectedVehicles.count == 1,
                       let first = selectedVehicles.first,
                       let opt = vehicleOptions.first(where: { $0.value == first }) {
                        return opt.label
                    }
                    return "\(selectedVehicles.count) Araç"
                }()

                Button(action: { showVehiclePicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 12))
                        Text(vehicleLabel)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedVehicles.isEmpty ? Color.gray.opacity(0.08) : AppTheme.indigo.opacity(0.08))
                    .foregroundColor(selectedVehicles.isEmpty ? AppTheme.textSecondary : AppTheme.indigo)
                    .cornerRadius(10)
                }
            }

            Spacer()
        }
    }
}

// ── Date Range Sheet (Custom Range + Presets, max 3 months) ──
private struct DateRangeSheetView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var tempStart: Date = Date()
    @State private var tempEnd: Date = Date()
    @State private var pickingStart = true
    @State private var validationError: String? = nil

    private let maxMonths = 3
    private let cal = Calendar.current

    var presets: [(String, Date, Date)] {
        let now = Date()
        return [
            ("Bugün", now, now),
            ("Dün", cal.date(byAdding: .day, value: -1, to: now)!, cal.date(byAdding: .day, value: -1, to: now)!),
            ("Son 7 Gün", cal.date(byAdding: .day, value: -6, to: now)!, now),
            ("Son 30 Gün", cal.date(byAdding: .day, value: -29, to: now)!, now),
            ("Bu Ay", cal.date(from: cal.dateComponents([.year, .month], from: now))!, now),
            ("Geçen Ay", {
                let prev = cal.date(byAdding: .month, value: -1, to: now)!
                let start = cal.date(from: cal.dateComponents([.year, .month], from: prev))!
                let end = cal.date(byAdding: .day, value: -1, to: cal.date(from: cal.dateComponents([.year, .month], from: now))!)!
                return (start, end)
            }().0, {
                let prev = cal.date(byAdding: .month, value: -1, to: now)!
                let start = cal.date(from: cal.dateComponents([.year, .month], from: prev))!
                let end = cal.date(byAdding: .day, value: -1, to: cal.date(from: cal.dateComponents([.year, .month], from: now))!)!
                return (start, end)
            }().1),
            ("Son 3 Ay", cal.date(byAdding: .month, value: -3, to: now)!, now)
        ]
    }

    func validate(_ s: Date, _ e: Date) -> Bool {
        if e < s {
            validationError = "Bitiş tarihi başlangıçtan önce olamaz"
            return false
        }
        if let maxDate = cal.date(byAdding: .month, value: maxMonths, to: s), e > maxDate {
            validationError = "Maksimum 3 aylık aralık seçilebilir"
            return false
        }
        if s > Date() {
            validationError = "Gelecek tarih seçilemez"
            return false
        }
        validationError = nil
        return true
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Subtitle
                    Text("Maksimum 3 ay seçilebilir")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 20)

                    // ── Quick Presets ──
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hızlı Seçim")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(presets, id: \.0) { label, s, e in
                                let isActive = cal.isDate(tempStart, inSameDayAs: s) && cal.isDate(tempEnd, inSameDayAs: e)
                                Button(action: {
                                    tempStart = s; tempEnd = e
                                    if validate(s, e) {
                                        startDate = s; endDate = e
                                        dismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onConfirm() }
                                    }
                                }) {
                                    Text(label)
                                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                                        .foregroundColor(isActive ? AppTheme.indigo : AppTheme.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(isActive ? AppTheme.indigo.opacity(0.12) : AppTheme.bg)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isActive ? AppTheme.indigo.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Divider().padding(.horizontal, 20)

                    // ── Custom Date Section ──
                    Text("Özel Tarih Seçimi")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal, 20)

                    // Start / End toggle
                    HStack(spacing: 0) {
                        ForEach([(true, "Başlangıç"), (false, "Bitiş")], id: \.0) { isStart, label in
                            let active = pickingStart == isStart
                            let dateVal = isStart ? tempStart : tempEnd
                            let fmt = DateFormatter()
                            let _ = fmt.dateFormat = "dd MMM yyyy"

                            Button(action: { withAnimation { pickingStart = isStart } }) {
                                VStack(spacing: 2) {
                                    Text(label)
                                        .font(.system(size: 11))
                                        .foregroundColor(active ? .white.opacity(0.8) : AppTheme.textMuted)
                                    Text(fmt.string(from: dateVal))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(active ? .white : AppTheme.navy)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(active ? AppTheme.indigo : Color.clear)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(AppTheme.bg)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)

                    // DatePicker
                    DatePicker(
                        pickingStart ? "Başlangıç" : "Bitiş",
                        selection: pickingStart ? $tempStart : $tempEnd,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(AppTheme.indigo)
                    .padding(.horizontal, 12)
                    .onChange(of: tempStart) { _ in
                        if tempStart > tempEnd { tempEnd = tempStart }
                        let _ = validate(tempStart, tempEnd)
                    }
                    .onChange(of: tempEnd) { _ in
                        if tempEnd < tempStart { tempStart = tempEnd }
                        let _ = validate(tempStart, tempEnd)
                    }

                    // Validation error
                    if let err = validationError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 12))
                            Text(err)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(Color(hex: "#DC2626"))
                        .padding(.horizontal, 20)
                    }

                    // Confirm button
                    Button(action: {
                        if validate(tempStart, tempEnd) {
                            startDate = tempStart; endDate = tempEnd
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onConfirm() }
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Uygula")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(validationError == nil ? AppTheme.indigo : AppTheme.indigo.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(validationError != nil)
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 20)
                }
            }
            .navigationTitle("Tarih Aralığı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
        .onAppear {
            tempStart = startDate
            tempEnd = endDate
        }
    }
}

// ── Vehicle Multi-Select Sheet (Searchable + Checkboxes) ──
private struct VehicleMultiSelectSheetView: View {
    let options: [FilterOption]
    @Binding var selectedVehicles: Set<String>
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var tempSelected: Set<String> = []
    @State private var searchQuery = ""

    var filtered: [FilterOption] {
        if searchQuery.isEmpty { return options }
        return options.filter { $0.label.localizedCaseInsensitiveContains(searchQuery) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header info
                HStack {
                    Text(tempSelected.isEmpty ? "Tüm araçlar gösterilecek" : "\(tempSelected.count) araç seçili")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                    Spacer()
                    if !tempSelected.isEmpty {
                        Button(action: { tempSelected = [] }) {
                            Text("Temizle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#DC2626"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(hex: "#DC2626").opacity(0.08))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textMuted)
                    TextField("Araç ara…", text: $searchQuery)
                        .font(.system(size: 14))
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.bg)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderSoft, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                // Select all
                Button(action: {
                    if tempSelected.count == options.count {
                        tempSelected = []
                    } else {
                        tempSelected = Set(options.map { $0.value })
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: tempSelected.count == options.count ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundColor(tempSelected.count == options.count ? AppTheme.indigo : AppTheme.textMuted)
                        Text("Tümünü Seç")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.navy)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Divider().padding(.horizontal, 20)

                // Vehicle list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { opt in
                            let isChecked = tempSelected.contains(opt.value)
                            Button(action: {
                                if isChecked {
                                    tempSelected.remove(opt.value)
                                } else {
                                    tempSelected.insert(opt.value)
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 18))
                                        .foregroundColor(isChecked ? AppTheme.indigo : AppTheme.textMuted)
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(isChecked ? AppTheme.indigo : AppTheme.textMuted)
                                    Text(opt.label)
                                        .font(.system(size: 14, weight: isChecked ? .medium : .regular))
                                        .foregroundColor(isChecked ? AppTheme.navy : AppTheme.textSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(isChecked ? AppTheme.indigo.opacity(0.06) : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }

                        if filtered.isEmpty {
                            Text("Araç bulunamadı")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textMuted)
                                .padding(24)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                // Confirm button
                Button(action: {
                    selectedVehicles = tempSelected
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onConfirm() }
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text(tempSelected.isEmpty ? "Tüm Araçları Göster" : "\(tempSelected.count) Araç Seçildi — Uygula")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .navigationTitle("Araç Seçin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
        .onAppear { tempSelected = selectedVehicles }
    }
}

// ═══════════════════════════════════════════════════════════════
// 9) PAGINATION
// ═══════════════════════════════════════════════════════════════

private struct PaginationBarView: View {
    let page: Int
    let lastPage: Int
    let total: Int
    let onPageChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: { if page > 1 { onPageChange(page - 1) } }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(page > 1 ? AppTheme.indigo : AppTheme.textFaint)
            }
            .disabled(page <= 1)

            Text("\(page) / \(lastPage)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.navy)

            Text("(\(total) kayıt)")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textMuted)

            Button(action: { if page < lastPage { onPageChange(page + 1) } }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(page < lastPage ? AppTheme.indigo : AppTheme.textFaint)
            }
            .disabled(page >= lastPage)
        }
        .frame(maxWidth: .infinity)
    }
}

// ═══════════════════════════════════════════════════════════════
// 10) COMMON UI COMPONENTS
// ═══════════════════════════════════════════════════════════════

private struct ReportsTopBar: View {
    let title: String
    var showBack: Bool = false
    var onBack: (() -> Void)? = nil
    var showSideMenu: Binding<Bool>? = nil
    var accent: Color = AppTheme.indigo

    var body: some View {
        HStack(spacing: 8) {
            if showBack {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
            } else if let binding = showSideMenu {
                Button(action: { withAnimation(.spring(response: 0.3)) { binding.wrappedValue = true } }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
            }

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(red: 10/255, green: 17/255, blue: 88/255), Color(red: 9/255, green: 15/255, blue: 65/255)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct ErrorCardView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "#dc2626"))
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Tekrar Dene", action: onRetry)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(AppTheme.indigo)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(32)
    }
}

// ═══════════════════════════════════════════════════════════════
// DATA MODELS & HELPERS
// ═══════════════════════════════════════════════════════════════

private struct ReportCatalogItem: Identifiable {
    let type: String
    let label: String
    let description: String
    let accent: String
    var id: String { type }
}

private struct FilterOption: Identifiable {
    let value: String
    let label: String
    var id: String { value }
}

private func reportIcon(_ type: String) -> String {
    switch type {
    case "distance": return "road.lanes"
    case "speed": return "speedometer"
    case "stops": return "pause.circle.fill"
    case "fuel": return "fuelpump.fill"
    case "fuel_prices": return "dollarsign.circle.fill"
    case "off_hours": return "moon.fill"
    case "drivers": return "person.fill"
    case "temperature": return "thermometer.medium"
    case "alarms": return "bell.badge.fill"
    case "geofence": return "hexagon.fill"
    default: return "chart.bar.fill"
    }
}

private func toneColor(_ tone: String) -> Color {
    switch tone {
    case "navy": return Color(hex: "#0F172A")
    case "soft-blue": return Color(hex: "#3B82F6")
    case "success": return Color(hex: "#16A34A")
    case "warning": return Color(hex: "#D97706")
    case "danger": return Color(hex: "#DC2626")
    case "soft-red": return Color(hex: "#EF4444")
    default: return Color(hex: "#6366F1")
    }
}

private func extractNumeric(_ value: Any?) -> Double {
    guard let v = value else { return 0 }
    if let d = v as? Double { return d }
    if let i = v as? Int { return Double(i) }
    if let s = v as? String {
        let cleaned = s.replacingOccurrences(of: "[^0-9.,\\-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0
    }
    return 0
}

private func findValueByIndex(row: [String: Any], index: Int) -> String {
    let keys = Array(row.keys)
    if index < keys.count {
        return "\(row[keys[index]] ?? "")"
    }
    return ""
}

// Color(hex:) extension is defined in RouteHistoryView.swift
