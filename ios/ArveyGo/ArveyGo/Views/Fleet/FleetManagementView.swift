import SwiftUI

// MARK: - Fleet Management View
struct FleetManagementView: View {
    @Binding var showSideMenu: Bool
    @State private var selectedTab: FleetTab = .maintenance

    // Data
    @State private var maintenanceList: [FleetMaintenance] = []
    @State private var costsList: [FleetCost] = []
    @State private var documentsList: [FleetDocument] = []
    @State private var reminders: [FleetReminder] = []
    @State private var catalog: FleetCatalog? = nil

    @State private var maintenancePagination = PaginationMeta()
    @State private var costsPagination = PaginationMeta()
    @State private var documentsPagination = PaginationMeta()

    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    enum FleetTab: String, CaseIterable {
        case maintenance = "Bakım"
        case costs = "Masraflar"
        case documents = "Belgeler"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { withAnimation(.spring(response: 0.3)) { showSideMenu = true } }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.navy)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Filo Yönetimi")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                    if let catalog = catalog {
                        Text("\(catalog.vehicles.count) araç")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                Spacer()

                Button(action: { loadData() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.indigo)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)

            // Reminders banner
            if !reminders.isEmpty {
                remindersBanner
            }

            // Tab selector
            tabSelector

            // Content
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(AppTheme.indigo)
                Spacer()
            } else if let error = errorMessage {
                errorView(error)
            } else {
                switch selectedTab {
                case .maintenance:
                    maintenanceListTab
                case .costs:
                    costsListTab
                case .documents:
                    documentsListTab
                }
            }
        }
        .background(AppTheme.bg)
        .task { loadData() }
    }

    // MARK: - Load Data
    private func loadData() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let api = APIService.shared
                catalog = try await api.fetchFleetCatalog()
                reminders = (try? await api.fetchFleetReminders(days: 60)) ?? []

                let (mList, mPag) = try await api.fetchFleetMaintenance()
                maintenanceList = mList
                maintenancePagination = mPag

                let (cList, cPag) = try await api.fetchFleetCosts()
                costsList = cList
                costsPagination = cPag

                let (dList, dPag) = try await api.fetchFleetDocuments()
                documentsList = dList
                documentsPagination = dPag
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Reminders Banner
    var remindersBanner: some View {
        let urgent = reminders.filter { $0.daysLeft <= 7 }
        let upcoming = reminders.filter { $0.daysLeft > 7 && $0.daysLeft <= 30 }

        return VStack(spacing: 6) {
            if !urgent.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("\(urgent.count) acil hatırlatma (7 gün içinde)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(12)
                .background(Color.red.opacity(0.08))
                .cornerRadius(10)
            }
            if !upcoming.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("\(upcoming.count) yaklaşan hatırlatma (30 gün içinde)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Tab Selector
    var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(FleetTab.allCases, id: \.self) { tab in
                let isActive = tab == selectedTab
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: isActive ? .bold : .medium))
                        .foregroundColor(isActive ? AppTheme.indigo : AppTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isActive ? Color.white : Color.clear)
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(AppTheme.navy.opacity(0.04))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Maintenance List
    var maintenanceListTab: some View {
        Group {
            if maintenanceList.isEmpty {
                emptyState(icon: "wrench.and.screwdriver.fill", title: "Bakım Kaydı Yok", subtitle: "Henüz bakım kaydı bulunmamaktadır.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        Text("Toplam \(maintenancePagination.total) kayıt")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)

                        ForEach(maintenanceList) { item in
                            maintenanceCard(item)
                        }

                        if maintenancePagination.hasMore {
                            Button("Daha fazla yükle") {
                                Task {
                                    let (mList, mPag) = try await APIService.shared.fetchFleetMaintenance(page: maintenancePagination.currentPage + 1)
                                    maintenanceList.append(contentsOf: mList)
                                    maintenancePagination = mPag
                                }
                            }
                            .foregroundColor(AppTheme.indigo)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }

    func maintenanceCard(_ item: FleetMaintenance) -> some View {
        let statusColor: Color = {
            switch item.status {
            case "done": return .green
            case "scheduled": return .blue
            case "overdue": return .red
            default: return .orange
            }
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "wrench.fill")
                        .font(.system(size: 14))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.maintenanceType.isEmpty ? "Bakım" : item.maintenanceType)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.navy)
                    Text(item.plate)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }

                Spacer()

                Text(item.statusLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(20)
            }

            HStack(spacing: 8) {
                if let date = item.serviceDate {
                    infoChip(icon: "calendar", text: "Servis: \(date)")
                }
                if let next = item.nextServiceDate {
                    infoChip(icon: "calendar.badge.clock", text: "Sonraki: \(next)")
                }
                if let km = item.kmAtService {
                    let fmt = NumberFormatter()
                    let _ = (fmt.numberStyle = .decimal, fmt.locale = Locale(identifier: "tr_TR"))
                    infoChip(icon: "speedometer", text: "\(fmt.string(from: NSNumber(value: km)) ?? "\(km)") km")
                }
            }

            if !item.workshop.isEmpty {
                Text("Atölye: \(item.workshop)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }

            if let cost = item.cost, cost > 0 {
                Text("Tutar: \(item.formattedCost)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.navy)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Costs List
    var costsListTab: some View {
        Group {
            if costsList.isEmpty {
                emptyState(icon: "turkishlirasign.circle.fill", title: "Masraf Kaydı Yok", subtitle: "Henüz masraf kaydı bulunmamaktadır.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Summary
                        costSummaryCard

                        Text("Toplam \(costsPagination.total) kayıt")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        ForEach(costsList) { cost in
                            costCard(cost)
                        }

                        if costsPagination.hasMore {
                            Button("Daha fazla yükle") {
                                Task {
                                    let (cList, cPag) = try await APIService.shared.fetchFleetCosts(page: costsPagination.currentPage + 1)
                                    costsList.append(contentsOf: cList)
                                    costsPagination = cPag
                                }
                            }
                            .foregroundColor(AppTheme.indigo)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }

    var costSummaryCard: some View {
        let totalAmount = costsList.reduce(0.0) { $0 + $1.amount }
        let byCat = Dictionary(grouping: costsList, by: { $0.category }).mapValues { $0.reduce(0.0) { $0 + $1.amount } }
        let fmt = NumberFormatter()
        let _ = (fmt.numberStyle = .decimal, fmt.locale = Locale(identifier: "tr_TR"), fmt.maximumFractionDigits = 0)

        return VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.indigo)
                Text("MASRAF ÖZETİ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.textMuted)
                    .tracking(0.5)
                Spacer()
            }

            if !byCat.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(byCat.prefix(4)), id: \.key) { cat, amount in
                        VStack(spacing: 2) {
                            Text("₺\(fmt.string(from: NSNumber(value: amount)) ?? "0")")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.navy)
                            Text(categoryLabel(cat))
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            HStack {
                Text("TOPLAM")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.textMuted)
                Spacer()
                Text("₺\(fmt.string(from: NSNumber(value: totalAmount)) ?? "0")")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.navy)
            }
            .padding(12)
            .background(AppTheme.navy.opacity(0.04))
            .cornerRadius(10)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    func costCard(_ cost: FleetCost) -> some View {
        let color = categoryColor(cost.category)
        let icon = categoryIcon(cost.category)

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(categoryLabel(cost.category))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
                Text("\(cost.plate) • \(cost.costDate)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                if !cost.description.isEmpty {
                    Text(cost.description)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textFaint)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(cost.formattedAmount)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.navy)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Documents List
    var documentsListTab: some View {
        Group {
            if documentsList.isEmpty {
                emptyState(icon: "doc.text.fill", title: "Belge Kaydı Yok", subtitle: "Henüz belge kaydı bulunmamaktadır.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        Text("Toplam \(documentsPagination.total) kayıt")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)

                        ForEach(documentsList) { doc in
                            documentCard(doc)
                        }

                        if documentsPagination.hasMore {
                            Button("Daha fazla yükle") {
                                Task {
                                    let (dList, dPag) = try await APIService.shared.fetchFleetDocuments(page: documentsPagination.currentPage + 1)
                                    documentsList.append(contentsOf: dList)
                                    documentsPagination = dPag
                                }
                            }
                            .foregroundColor(AppTheme.indigo)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }

    func documentCard(_ doc: FleetDocument) -> some View {
        let statusColor: Color = {
            switch doc.status {
            case "active": return .green
            case "expiring_soon": return .orange
            case "expired": return .red
            default: return Color(red: 148/255, green: 163/255, blue: 184/255)
            }
        }()

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title.isEmpty ? doc.docTypeLabel : doc.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
                Text("\(doc.plate) • \(doc.docTypeLabel)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                if let expiry = doc.expiryDate {
                    Text("Bitiş: \(expiry)")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textFaint)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let daysLeft = doc.daysLeft {
                    Text("\(daysLeft) gün")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(statusColor)
                    Text("kalan")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textMuted)
                }
                Text(doc.statusLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(20)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Shared

    func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(AppTheme.textMuted)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(AppTheme.bg)
        .cornerRadius(6)
    }

    func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.indigo.opacity(0.08))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.indigo.opacity(0.5))
            }
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.navy)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(32)
    }

    func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 36))
                .foregroundColor(.red)
            Text("Veri yüklenirken hata oluştu")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.navy)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Tekrar Dene") { loadData() }
                .foregroundColor(AppTheme.indigo)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(32)
    }

    // MARK: - Helpers

    func categoryColor(_ cat: String) -> Color {
        switch cat.lowercased() {
        case "fuel": return .orange
        case "maintenance": return .blue
        case "tire": return Color(red: 96/255, green: 125/255, blue: 139/255)
        case "insurance": return .purple
        case "tax": return Color(red: 0, green: 150/255, blue: 136/255)
        case "fine": return .red
        default: return Color(red: 148/255, green: 163/255, blue: 184/255)
        }
    }

    func categoryIcon(_ cat: String) -> String {
        switch cat.lowercased() {
        case "fuel": return "fuelpump.fill"
        case "maintenance": return "wrench.fill"
        case "tire": return "circle.circle.fill"
        case "insurance": return "shield.fill"
        case "tax": return "building.columns.fill"
        case "fine": return "exclamationmark.triangle.fill"
        default: return "ellipsis"
        }
    }

    func categoryLabel(_ cat: String) -> String {
        switch cat.lowercased() {
        case "fuel": return "Yakıt"
        case "maintenance": return "Bakım"
        case "tire": return "Lastik"
        case "insurance": return "Sigorta"
        case "tax": return "Vergi"
        case "fine": return "Ceza"
        case "other": return "Diğer"
        default: return cat.prefix(1).uppercased() + cat.dropFirst()
        }
    }
}

#Preview {
    FleetManagementView(showSideMenu: .constant(false))
}
