import SwiftUI

// MARK: - Fleet Management View
struct FleetManagementView: View {
    @EnvironmentObject var authVM: AuthViewModel
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

    // CRUD states
    @State private var showMaintenanceSheet = false
    @State private var editingMaintenance: FleetMaintenance? = nil
    @State private var showCostSheet = false
    @State private var editingCost: FleetCost? = nil
    @State private var showDocumentSheet = false
    @State private var editingDocument: FleetDocument? = nil
    @State private var deleteTarget: DeleteTarget? = nil

    enum FleetTab: String, CaseIterable {
        case maintenance = "Bakım"
        case costs = "Masraflar"
        case documents = "Belgeler"
    }

    struct DeleteTarget: Identifiable {
        let id = UUID()
        let type: String // "maintenance", "cost", "document"
        let itemId: String
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) { showSideMenu.toggle() }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.navy)
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Bakım / Belgeler / Masraflar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                        Text("Filo Yönetimi")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        Button(action: { loadData() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        Button(action: {
                            switch selectedTab {
                            case .maintenance:
                                editingMaintenance = nil; showMaintenanceSheet = true
                            case .costs:
                                editingCost = nil; showCostSheet = true
                            case .documents:
                                editingDocument = nil; showDocumentSheet = true
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.indigo)
                        }
                        AvatarCircle(
                            initials: authVM.currentUser?.avatar ?? "A",
                            size: 30
                        )
                    }
                }
            }
        }
        .task { loadData() }
        .sheet(isPresented: $showMaintenanceSheet) {
            MaintenanceFormSheet(catalog: catalog, editing: editingMaintenance) {
                showMaintenanceSheet = false; loadData()
            } onCancel: {
                showMaintenanceSheet = false
            }
        }
        .sheet(isPresented: $showCostSheet) {
            CostFormSheet(catalog: catalog, editing: editingCost) {
                showCostSheet = false; loadData()
            } onCancel: {
                showCostSheet = false
            }
        }
        .sheet(isPresented: $showDocumentSheet) {
            DocumentFormSheet(catalog: catalog, editing: editingDocument) {
                showDocumentSheet = false; loadData()
            } onCancel: {
                showDocumentSheet = false
            }
        }
        .alert("Silme Onayı", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("İptal", role: .cancel) { deleteTarget = nil }
            Button("Sil", role: .destructive) { performDelete() }
        } message: {
            Text("Bu kaydı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.")
        }
    }

    // MARK: - Delete
    private func performDelete() {
        guard let target = deleteTarget else { return }
        Task {
            do {
                let api = APIService.shared
                switch target.type {
                case "maintenance":
                    try await api.deleteFleetMaintenance(id: Int(target.itemId) ?? 0)
                    maintenanceList.removeAll { $0.id == target.itemId }
                case "cost":
                    try await api.deleteFleetCost(id: Int(target.itemId) ?? 0)
                    costsList.removeAll { $0.id == target.itemId }
                case "document":
                    try await api.deleteFleetDocument(id: Int(target.itemId) ?? 0)
                    documentsList.removeAll { $0.id == target.itemId }
                default: break
                }
            } catch {
                // silently fail
            }
            deleteTarget = nil
        }
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

    // ═══════════════════════════════════════════════════════════
    // MARK: - Maintenance List
    // ═══════════════════════════════════════════════════════════

    var maintenanceListTab: some View {
        Group {
            if maintenanceList.isEmpty {
                emptyState(icon: "wrench.and.screwdriver.fill", title: "Bakım Kaydı Yok", subtitle: "Henüz bakım kaydı bulunmamaktadır.\nYeni kayıt eklemek için + butonuna dokunun.")
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
                                    if let (mList, mPag) = try? await APIService.shared.fetchFleetMaintenance(page: maintenancePagination.currentPage + 1) {
                                        maintenanceList.append(contentsOf: mList)
                                        maintenancePagination = mPag
                                    }
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

            // Edit / Delete buttons
            HStack {
                Spacer()
                Button(action: { editingMaintenance = item; showMaintenanceSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.system(size: 11))
                        Text("Düzenle").font(.system(size: 11))
                    }
                    .foregroundColor(AppTheme.indigo)
                }
                Button(action: { deleteTarget = DeleteTarget(type: "maintenance", itemId: item.id) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash").font(.system(size: 11))
                        Text("Sil").font(.system(size: 11))
                    }
                    .foregroundColor(.red.opacity(0.7))
                }
                .padding(.leading, 8)
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

    // ═══════════════════════════════════════════════════════════
    // MARK: - Costs List
    // ═══════════════════════════════════════════════════════════

    var costsListTab: some View {
        Group {
            if costsList.isEmpty {
                emptyState(icon: "turkishlirasign.circle.fill", title: "Masraf Kaydı Yok", subtitle: "Henüz masraf kaydı bulunmamaktadır.\nYeni kayıt eklemek için + butonuna dokunun.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
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
                                    if let (cList, cPag) = try? await APIService.shared.fetchFleetCosts(page: costsPagination.currentPage + 1) {
                                        costsList.append(contentsOf: cList)
                                        costsPagination = cPag
                                    }
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
                // Edit / Delete buttons
                HStack(spacing: 0) {
                    Button(action: { editingCost = cost; showCostSheet = true }) {
                        HStack(spacing: 2) {
                            Image(systemName: "pencil").font(.system(size: 10))
                            Text("Düzenle").font(.system(size: 10))
                        }
                        .foregroundColor(AppTheme.indigo)
                    }
                    Button(action: { deleteTarget = DeleteTarget(type: "cost", itemId: cost.id) }) {
                        HStack(spacing: 2) {
                            Image(systemName: "trash").font(.system(size: 10))
                            Text("Sil").font(.system(size: 10))
                        }
                        .foregroundColor(.red.opacity(0.7))
                    }
                    .padding(.leading, 8)
                }
                .padding(.top, 4)
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

    // ═══════════════════════════════════════════════════════════
    // MARK: - Documents List
    // ═══════════════════════════════════════════════════════════

    var documentsListTab: some View {
        Group {
            if documentsList.isEmpty {
                emptyState(icon: "doc.text.fill", title: "Belge Kaydı Yok", subtitle: "Henüz belge kaydı bulunmamaktadır.\nYeni kayıt eklemek için + butonuna dokunun.")
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
                                    if let (dList, dPag) = try? await APIService.shared.fetchFleetDocuments(page: documentsPagination.currentPage + 1) {
                                        documentsList.append(contentsOf: dList)
                                        documentsPagination = dPag
                                    }
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
                // Edit / Delete buttons
                HStack(spacing: 0) {
                    Button(action: { editingDocument = doc; showDocumentSheet = true }) {
                        HStack(spacing: 2) {
                            Image(systemName: "pencil").font(.system(size: 10))
                            Text("Düzenle").font(.system(size: 10))
                        }
                        .foregroundColor(AppTheme.indigo)
                    }
                    Button(action: { deleteTarget = DeleteTarget(type: "document", itemId: doc.id) }) {
                        HStack(spacing: 2) {
                            Image(systemName: "trash").font(.system(size: 10))
                            Text("Sil").font(.system(size: 10))
                        }
                        .foregroundColor(.red.opacity(0.7))
                    }
                    .padding(.leading, 8)
                }
                .padding(.top, 4)
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

    // ═══════════════════════════════════════════════════════════
    // MARK: - Shared Views
    // ═══════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════
// MARK: - Maintenance Form Sheet
// ═══════════════════════════════════════════════════════════

struct MaintenanceFormSheet: View {
    let catalog: FleetCatalog?
    let editing: FleetMaintenance?
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var isSaving = false
    @State private var errorMsg: String? = nil
    @State private var selectedImei: String
    @State private var maintenanceType: String
    @State private var serviceDate: String
    @State private var nextServiceDate: String
    @State private var kmAtService: String
    @State private var nextServiceKm: String
    @State private var cost: String
    @State private var workshop: String
    @State private var description: String
    @State private var status: String

    private let types: [(String, String)] = [
        ("periodic", "Periyodik Bakım"), ("oil_change", "Yağ Değişimi"), ("tire_change", "Lastik Değişimi"),
        ("brake_service", "Fren Bakımı"), ("filter_change", "Filtre Değişimi"), ("battery", "Akü Kontrolü"), ("other", "Diğer")
    ]
    private let statuses: [(String, String)] = [("done", "Tamamlandı"), ("scheduled", "Planlandı"), ("overdue", "Gecikmiş")]

    init(catalog: FleetCatalog?, editing: FleetMaintenance?, onSaved: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.catalog = catalog; self.editing = editing; self.onSaved = onSaved; self.onCancel = onCancel
        _selectedImei = State(initialValue: editing?.imei ?? "")
        _maintenanceType = State(initialValue: editing?.maintenanceType ?? "")
        _serviceDate = State(initialValue: editing?.serviceDate ?? Self.todayStr())
        _nextServiceDate = State(initialValue: editing?.nextServiceDate ?? "")
        _kmAtService = State(initialValue: editing?.kmAtService.map { "\($0)" } ?? "")
        _nextServiceKm = State(initialValue: editing?.nextServiceKm.map { "\($0)" } ?? "")
        _cost = State(initialValue: editing?.cost.map { String(format: "%.0f", $0) } ?? "")
        _workshop = State(initialValue: editing?.workshop ?? "")
        _description = State(initialValue: editing?.description ?? "")
        _status = State(initialValue: editing?.status ?? "done")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    formLabel("Araç *")
                    vehiclePicker(catalog: catalog, selected: $selectedImei)

                    formLabel("Bakım Türü *")
                    dropdownPicker(options: types, selected: $maintenanceType)

                    formLabel("Servis Tarihi *")
                    formTextField(text: $serviceDate, placeholder: "2026-03-28")

                    formLabel("Sonraki Servis Tarihi")
                    formTextField(text: $nextServiceDate, placeholder: "2026-06-28")

                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            formLabel("Servis KM")
                            formTextField(text: $kmAtService, placeholder: "45000", keyboard: .numberPad)
                        }
                        VStack(alignment: .leading) {
                            formLabel("Sonraki KM")
                            formTextField(text: $nextServiceKm, placeholder: "55000", keyboard: .numberPad)
                        }
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            formLabel("Tutar (₺)")
                            formTextField(text: $cost, placeholder: "1500", keyboard: .decimalPad)
                        }
                        VStack(alignment: .leading) {
                            formLabel("Atölye")
                            formTextField(text: $workshop, placeholder: "Oto Servis")
                        }
                    }

                    formLabel("Durum")
                    dropdownPicker(options: statuses, selected: $status)

                    formLabel("Açıklama")
                    formTextField(text: $description, placeholder: "Opsiyonel açıklama...", axis: .vertical)

                    if let err = errorMsg {
                        Text(err).font(.system(size: 12)).foregroundColor(.red)
                    }

                    saveButton(isEdit: editing != nil, isSaving: isSaving) { save() }
                }
                .padding(20)
            }
            .navigationTitle(editing != nil ? "Bakım Düzenle" : "Yeni Bakım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { onCancel() }
                }
            }
        }
    }

    private func save() {
        guard !selectedImei.isEmpty, !maintenanceType.isEmpty, !serviceDate.isEmpty else {
            errorMsg = "Araç, bakım türü ve servis tarihi zorunludur."; return
        }
        isSaving = true; errorMsg = nil
        Task {
            do {
                var body: [String: Any] = ["device_imei": selectedImei, "maintenance_type": maintenanceType, "service_date": serviceDate, "status": status]
                if !nextServiceDate.isEmpty { body["next_service_date"] = nextServiceDate }
                if let v = Int(kmAtService) { body["km_at_service"] = v }
                if let v = Int(nextServiceKm) { body["next_service_km"] = v }
                if let v = Double(cost.replacingOccurrences(of: ",", with: ".")) { body["cost"] = v }
                if !workshop.isEmpty { body["workshop"] = workshop }
                if !description.isEmpty { body["description"] = description }
                if let e = editing { let _ = try await APIService.shared.updateFleetMaintenance(id: Int(e.id) ?? 0, data: body) }
                else { let _ = try await APIService.shared.createFleetMaintenance(data: body) }
                onSaved()
            } catch { errorMsg = error.localizedDescription }
            isSaving = false
        }
    }

    static func todayStr() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
}

// ═══════════════════════════════════════════════════════════
// MARK: - Cost Form Sheet
// ═══════════════════════════════════════════════════════════

struct CostFormSheet: View {
    let catalog: FleetCatalog?
    let editing: FleetCost?
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var isSaving = false
    @State private var errorMsg: String? = nil
    @State private var selectedImei: String
    @State private var category: String
    @State private var amount: String
    @State private var costDate: String
    @State private var description: String
    @State private var referenceNo: String

    private let categories: [(String, String)] = [
        ("fuel", "Yakıt"), ("maintenance", "Bakım"), ("tire", "Lastik"),
        ("insurance", "Sigorta"), ("tax", "Vergi"), ("fine", "Ceza"), ("other", "Diğer")
    ]

    init(catalog: FleetCatalog?, editing: FleetCost?, onSaved: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.catalog = catalog; self.editing = editing; self.onSaved = onSaved; self.onCancel = onCancel
        _selectedImei = State(initialValue: editing?.imei ?? "")
        _category = State(initialValue: editing?.category ?? "")
        _amount = State(initialValue: (editing != nil && editing!.amount > 0) ? String(format: "%.0f", editing!.amount) : "")
        _costDate = State(initialValue: editing?.costDate ?? MaintenanceFormSheet.todayStr())
        _description = State(initialValue: editing?.description ?? "")
        _referenceNo = State(initialValue: editing?.referenceNo ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    formLabel("Araç *")
                    vehiclePicker(catalog: catalog, selected: $selectedImei)

                    formLabel("Kategori *")
                    dropdownPicker(options: categories, selected: $category)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            formLabel("Tutar (₺) *")
                            formTextField(text: $amount, placeholder: "2500", keyboard: .decimalPad)
                        }
                        VStack(alignment: .leading) {
                            formLabel("Tarih *")
                            formTextField(text: $costDate, placeholder: "2026-03-28")
                        }
                    }

                    formLabel("Referans No")
                    formTextField(text: $referenceNo, placeholder: "Fatura no, fiş no vb.")

                    formLabel("Açıklama")
                    formTextField(text: $description, placeholder: "Opsiyonel açıklama...", axis: .vertical)

                    if let err = errorMsg {
                        Text(err).font(.system(size: 12)).foregroundColor(.red)
                    }

                    saveButton(isEdit: editing != nil, isSaving: isSaving) { save() }
                }
                .padding(20)
            }
            .navigationTitle(editing != nil ? "Masraf Düzenle" : "Yeni Masraf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { onCancel() }
                }
            }
        }
    }

    private func save() {
        guard !selectedImei.isEmpty, !category.isEmpty, !amount.isEmpty, !costDate.isEmpty else {
            errorMsg = "Araç, kategori, tutar ve tarih zorunludur."; return
        }
        isSaving = true; errorMsg = nil
        Task {
            do {
                var body: [String: Any] = ["device_imei": selectedImei, "category": category, "amount": Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0, "cost_date": costDate]
                if !description.isEmpty { body["description"] = description }
                if !referenceNo.isEmpty { body["reference_no"] = referenceNo }
                if let e = editing { let _ = try await APIService.shared.updateFleetCost(id: Int(e.id) ?? 0, data: body) }
                else { let _ = try await APIService.shared.createFleetCost(data: body) }
                onSaved()
            } catch { errorMsg = error.localizedDescription }
            isSaving = false
        }
    }
}

// ═══════════════════════════════════════════════════════════
// MARK: - Document Form Sheet
// ═══════════════════════════════════════════════════════════

struct DocumentFormSheet: View {
    let catalog: FleetCatalog?
    let editing: FleetDocument?
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var isSaving = false
    @State private var errorMsg: String? = nil
    @State private var selectedImei: String
    @State private var docType: String
    @State private var title: String
    @State private var issueDate: String
    @State private var expiryDate: String
    @State private var reminderDays: String
    @State private var notes: String

    private let docTypes: [(String, String)] = [
        ("ruhsat", "Ruhsat"), ("sigorta", "Sigorta"), ("muayene", "Muayene"),
        ("egzoz", "Egzoz"), ("fenni_muayene", "Fenni Muayene"), ("other", "Diğer")
    ]

    init(catalog: FleetCatalog?, editing: FleetDocument?, onSaved: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.catalog = catalog; self.editing = editing; self.onSaved = onSaved; self.onCancel = onCancel
        _selectedImei = State(initialValue: editing?.imei ?? "")
        _docType = State(initialValue: editing?.docType ?? "")
        _title = State(initialValue: editing?.title ?? "")
        _issueDate = State(initialValue: editing?.issueDate ?? "")
        _expiryDate = State(initialValue: editing?.expiryDate ?? "")
        _reminderDays = State(initialValue: "\(editing?.reminderDays ?? 30)")
        _notes = State(initialValue: editing?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    formLabel("Araç *")
                    vehiclePicker(catalog: catalog, selected: $selectedImei)

                    formLabel("Belge Türü *")
                    dropdownPicker(options: docTypes, selected: $docType)

                    formLabel("Başlık *")
                    formTextField(text: $title, placeholder: "Belge adı")

                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            formLabel("Düzenleme Tarihi")
                            formTextField(text: $issueDate, placeholder: "2026-01-01")
                        }
                        VStack(alignment: .leading) {
                            formLabel("Bitiş Tarihi")
                            formTextField(text: $expiryDate, placeholder: "2027-01-01")
                        }
                    }

                    formLabel("Hatırlatma (gün)")
                    formTextField(text: $reminderDays, placeholder: "30", keyboard: .numberPad)

                    formLabel("Notlar")
                    formTextField(text: $notes, placeholder: "Opsiyonel notlar...", axis: .vertical)

                    if let err = errorMsg {
                        Text(err).font(.system(size: 12)).foregroundColor(.red)
                    }

                    saveButton(isEdit: editing != nil, isSaving: isSaving) { save() }
                }
                .padding(20)
            }
            .navigationTitle(editing != nil ? "Belge Düzenle" : "Yeni Belge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { onCancel() }
                }
            }
        }
    }

    private func save() {
        guard !selectedImei.isEmpty, !docType.isEmpty, !title.isEmpty else {
            errorMsg = "Araç, belge türü ve başlık zorunludur."; return
        }
        isSaving = true; errorMsg = nil
        Task {
            do {
                var body: [String: Any] = ["device_imei": selectedImei, "doc_type": docType, "title": title]
                if !issueDate.isEmpty { body["issue_date"] = issueDate }
                if !expiryDate.isEmpty { body["expiry_date"] = expiryDate }
                if let v = Int(reminderDays) { body["reminder_days"] = v }
                if !notes.isEmpty { body["notes"] = notes }
                if let e = editing { let _ = try await APIService.shared.updateFleetDocument(id: Int(e.id) ?? 0, data: body) }
                else { let _ = try await APIService.shared.createFleetDocument(data: body) }
                onSaved()
            } catch { errorMsg = error.localizedDescription }
            isSaving = false
        }
    }
}

// ═══════════════════════════════════════════════════════════
// MARK: - Shared Form Components
// ═══════════════════════════════════════════════════════════

private func formLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(AppTheme.navy)
}

private func formTextField(text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default, axis: Axis = .horizontal) -> some View {
    TextField(placeholder, text: text, axis: axis == .vertical ? .vertical : .horizontal)
        .font(.system(size: 13))
        .foregroundColor(AppTheme.navy)
        .padding(10)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
        .keyboardType(keyboard)
        .frame(minHeight: axis == .vertical ? 60 : nil, alignment: .top)
}

private func vehiclePicker(catalog: FleetCatalog?, selected: Binding<String>) -> some View {
    let vehicles = catalog?.vehicles ?? []
    let sel = vehicles.first(where: { $0.imei == selected.wrappedValue })
    let label = sel.map { "\($0.plate) (\($0.name))" } ?? (selected.wrappedValue.isEmpty ? "Araç seçiniz" : selected.wrappedValue)

    return Menu {
        ForEach(vehicles) { v in
            Button("\(v.plate) - \(v.name)") {
                selected.wrappedValue = v.imei
            }
        }
    } label: {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(sel != nil ? AppTheme.navy : AppTheme.textMuted)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }
}

private func dropdownPicker(options: [(String, String)], selected: Binding<String>) -> some View {
    let label = options.first(where: { $0.0 == selected.wrappedValue })?.1 ?? "Seçiniz"
    return Menu {
        ForEach(options, id: \.0) { key, lbl in
            Button(lbl) { selected.wrappedValue = key }
        }
    } label: {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(selected.wrappedValue.isEmpty ? AppTheme.textMuted : AppTheme.navy)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }
}

private func saveButton(isEdit: Bool, isSaving: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Group {
            if isSaving {
                ProgressView()
                    .tint(.white)
            } else {
                Text(isEdit ? "Güncelle" : "Kaydet")
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
    }
    .buttonStyle(.borderedProminent)
    .tint(AppTheme.indigo)
    .cornerRadius(10)
    .disabled(isSaving)
}

#Preview {
    FleetManagementView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
