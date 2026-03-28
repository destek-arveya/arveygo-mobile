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
    @State private var tiresList: [FleetTire] = []
    @State private var reminders: [FleetReminder] = []
    @State private var catalog: FleetCatalog? = nil

    @State private var maintenancePagination = PaginationMeta()
    @State private var costsPagination = PaginationMeta()
    @State private var documentsPagination = PaginationMeta()

    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil

    // Search & Filter
    @State private var searchText = ""
    @State private var selectedVehicleFilter: String? = nil // nil = all, else imei

    // CRUD states
    @State private var showFormSheet = false
    @State private var editingMaintenance: FleetMaintenance? = nil
    @State private var editingCost: FleetCost? = nil
    @State private var editingDocument: FleetDocument? = nil
    @State private var editingTire: FleetTire? = nil
    @State private var deleteTarget: DeleteTarget? = nil

    enum FleetTab: String, CaseIterable {
        case maintenance = "Bakım"
        case costs = "Masraf"
        case documents = "Belge"
        case tires = "Lastik"

        var icon: String {
            switch self {
            case .maintenance: return "wrench.and.screwdriver"
            case .costs: return "turkishlirasign.circle"
            case .documents: return "doc.text"
            case .tires: return "circle.circle"
            }
        }
    }

    struct DeleteTarget: Identifiable {
        let id = UUID()
        let type: String
        let itemId: String
    }

    // MARK: - Filtered Data
    private func matchesFilter(_ imei: String, _ plate: String) -> Bool {
        let matchesVehicle = selectedVehicleFilter == nil || imei == selectedVehicleFilter
        let matchesSearch = searchText.isEmpty ||
            plate.localizedCaseInsensitiveContains(searchText) ||
            imei.localizedCaseInsensitiveContains(searchText)
        return matchesVehicle && matchesSearch
    }

    var filteredMaintenance: [FleetMaintenance] { maintenanceList.filter { matchesFilter($0.imei, $0.plate) } }
    var filteredCosts: [FleetCost] { costsList.filter { matchesFilter($0.imei, $0.plate) } }
    var filteredDocuments: [FleetDocument] { documentsList.filter { matchesFilter($0.imei, $0.plate) } }
    var filteredTires: [FleetTire] { tiresList.filter { matchesFilter($0.imei, $0.plate) } }

    var selectedPlateLabel: String {
        guard let imei = selectedVehicleFilter else { return "Tüm Araçlar" }
        return catalog?.vehicles.first(where: { $0.imei == imei })?.plate ?? "Araç"
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

                // Search & Filter Bar
                searchFilterBar

                // Content
                if isLoading && maintenanceList.isEmpty {
                    Spacer()
                    ProgressView().tint(AppTheme.indigo)
                    Spacer()
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    switch selectedTab {
                    case .maintenance: maintenanceListTab
                    case .costs: costsListTab
                    case .documents: documentsListTab
                    case .tires: tiresListTab
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
                    Text("Filo Yönetimi")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.navy)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        editingMaintenance = nil; editingCost = nil; editingDocument = nil; editingTire = nil
                        showFormSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.indigo)
                    }
                }
            }
            .refreshable { await loadDataAsync() }
        }
        .task { loadData() }
        .sheet(isPresented: $showFormSheet) {
            switch selectedTab {
            case .maintenance:
                MaintenanceFormSheet(catalog: catalog, editing: editingMaintenance) {
                    showFormSheet = false; loadData()
                } onCancel: { showFormSheet = false }
            case .costs:
                CostFormSheet(catalog: catalog, editing: editingCost) {
                    showFormSheet = false; loadData()
                } onCancel: { showFormSheet = false }
            case .documents:
                DocumentFormSheet(catalog: catalog, editing: editingDocument) {
                    showFormSheet = false; loadData()
                } onCancel: { showFormSheet = false }
            case .tires:
                TireFormSheet(catalog: catalog, editing: editingTire) {
                    showFormSheet = false; loadData()
                } onCancel: { showFormSheet = false }
            }
        }
        .alert("Silme Onayı", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("İptal", role: .cancel) { deleteTarget = nil }
            Button("Sil", role: .destructive) { performDelete() }
        } message: {
            Text("Bu kaydı silmek istediğinize emin misiniz?")
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
                case "tire":
                    let _ = try await api.httpDelete("/api/mobile/fleet/tires/\(target.itemId)")
                    tiresList.removeAll { $0.id == target.itemId }
                default: break
                }
            } catch { /* silent */ }
            deleteTarget = nil
        }
    }

    // MARK: - Load Data
    private func loadData() {
        Task { await loadDataAsync() }
    }

    private func loadDataAsync() async {
        isLoading = true
        errorMessage = nil
        do {
            let api = APIService.shared
            catalog = try await api.fetchFleetCatalog()
            reminders = (try? await api.fetchFleetReminders(days: 60)) ?? []

            let (mList, mPag) = try await api.fetchFleetMaintenance()
            maintenanceList = mList; maintenancePagination = mPag

            let (cList, cPag) = try await api.fetchFleetCosts()
            costsList = cList; costsPagination = cPag

            let (dList, dPag) = try await api.fetchFleetDocuments()
            documentsList = dList; documentsPagination = dPag

            // Tires — endpoint may not exist
            do {
                let tiresJson = try await api.get("/api/mobile/fleet/tires?per_page=100")
                if let dataArr = tiresJson["data"] as? [[String: Any]] {
                    tiresList = dataArr.compactMap { FleetTire.fromDict($0) }
                }
            } catch { tiresList = [] }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Search & Filter Bar
    // ═══════════════════════════════════════════════════════════
    var searchFilterBar: some View {
        VStack(spacing: 8) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textMuted)
                TextField("Plaka ara...", text: $searchText)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.navy)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.borderSoft, lineWidth: 1))

            // Vehicle filter
            HStack(spacing: 8) {
                Menu {
                    Button(action: { selectedVehicleFilter = nil }) {
                        Label("Tüm Araçlar", systemImage: "car.2")
                    }
                    Divider()
                    ForEach(catalog?.vehicles ?? []) { v in
                        Button(action: { selectedVehicleFilter = v.imei }) {
                            Label(v.plate.isEmpty ? v.name : v.plate, systemImage: "car")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "car")
                            .font(.system(size: 10))
                        Text(selectedPlateLabel)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(selectedVehicleFilter != nil ? AppTheme.indigo : AppTheme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedVehicleFilter != nil ? AppTheme.indigo.opacity(0.1) : Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.borderSoft, lineWidth: 1))
                }

                if selectedVehicleFilter != nil {
                    Button(action: { selectedVehicleFilter = nil }) {
                        HStack(spacing: 2) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                            Text("Temizle")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
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
                    Text("\(urgent.count) acil hatırlatma")
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
                    Text("\(upcoming.count) yaklaşan hatırlatma")
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
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: isActive ? .bold : .medium))
                    }
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
            if filteredMaintenance.isEmpty {
                emptyState(icon: "wrench.and.screwdriver.fill", title: "Bakım Kaydı Yok", subtitle: "Henüz bakım kaydı bulunmamaktadır.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredMaintenance) { item in
                            fleetCard(
                                topLabel: item.plate,
                                title: item.maintenanceType.isEmpty ? "Bakım" : item.maintenanceType,
                                subtitle: item.workshop.isEmpty ? nil : item.workshop,
                                badge: item.statusLabel,
                                badgeColor: maintenanceStatusColor(item.status),
                                line1Icon: "calendar", line1: item.serviceDate ?? "—",
                                line2Icon: "speedometer", line2: item.kmAtService.map { "\(NumberFormatter.localizedString(from: NSNumber(value: $0), number: .decimal)) km" } ?? "—",
                                line3Icon: "turkishlirasign", line3: item.formattedCost,
                                onEdit: { editingMaintenance = item; showFormSheet = true },
                                onDelete: { deleteTarget = DeleteTarget(type: "maintenance", itemId: item.id) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Costs List
    // ═══════════════════════════════════════════════════════════
    var costsListTab: some View {
        Group {
            if filteredCosts.isEmpty {
                emptyState(icon: "turkishlirasign.circle.fill", title: "Masraf Kaydı Yok", subtitle: "Henüz masraf kaydı bulunmamaktadır.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredCosts) { cost in
                            fleetCard(
                                topLabel: cost.plate,
                                title: categoryLabel(cost.category),
                                subtitle: cost.description.isEmpty ? nil : cost.description,
                                badge: cost.formattedAmount,
                                badgeColor: AppTheme.indigo,
                                line1Icon: "calendar", line1: cost.costDate.isEmpty ? "—" : cost.costDate,
                                line2Icon: "number", line2: cost.referenceNo.isEmpty ? "—" : cost.referenceNo,
                                onEdit: { editingCost = cost; showFormSheet = true },
                                onDelete: { deleteTarget = DeleteTarget(type: "cost", itemId: cost.id) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Documents List
    // ═══════════════════════════════════════════════════════════
    var documentsListTab: some View {
        Group {
            if filteredDocuments.isEmpty {
                emptyState(icon: "doc.text.fill", title: "Belge Kaydı Yok", subtitle: "Henüz belge kaydı bulunmamaktadır.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredDocuments) { doc in
                            let daysText: String = {
                                guard let d = doc.daysLeft else { return "—" }
                                if d < 0 { return "Süresi \(-d) gün geçmiş" }
                                if d == 0 { return "Bugün doluyor" }
                                return "\(d) gün kaldı"
                            }()
                            fleetCard(
                                topLabel: doc.plate,
                                title: doc.docTypeLabel,
                                subtitle: doc.title.isEmpty ? nil : doc.title,
                                badge: doc.statusLabel,
                                badgeColor: documentStatusColor(doc.status),
                                line1Icon: "calendar", line1: doc.expiryDate ?? "—",
                                line2Icon: "timer", line2: daysText,
                                onEdit: { editingDocument = doc; showFormSheet = true },
                                onDelete: { deleteTarget = DeleteTarget(type: "document", itemId: doc.id) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Tires List
    // ═══════════════════════════════════════════════════════════
    var tiresListTab: some View {
        Group {
            if filteredTires.isEmpty {
                emptyState(icon: "circle.circle.fill", title: "Lastik Kaydı Yok", subtitle: "Henüz lastik kaydı bulunmamaktadır.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredTires) { tire in
                            fleetCard(
                                topLabel: tire.plate,
                                title: "\(tire.brand) \(tire.model)".trimmingCharacters(in: .whitespaces).isEmpty ? "Lastik" : "\(tire.brand) \(tire.model)".trimmingCharacters(in: .whitespaces),
                                subtitle: tire.positionLabel.isEmpty ? nil : tire.positionLabel,
                                badge: tire.statusLabel,
                                badgeColor: tireStatusColor(tire.status),
                                line1Icon: "ruler", line1: tire.size.isEmpty ? "—" : tire.size,
                                line2Icon: "speedometer", line2: tire.kmAtInstall > 0 ? "\(NumberFormatter.localizedString(from: NSNumber(value: tire.kmAtInstall), number: .decimal)) km" : "—",
                                line3Icon: "calendar", line3: tire.installDate.isEmpty ? "—" : tire.installDate,
                                onEdit: { editingTire = tire; showFormSheet = true },
                                onDelete: { deleteTarget = DeleteTarget(type: "tire", itemId: tire.id) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Fleet Card (Shared)
    // ═══════════════════════════════════════════════════════════
    func fleetCard(
        topLabel: String, title: String, subtitle: String?,
        badge: String, badgeColor: Color,
        line1Icon: String, line1: String,
        line2Icon: String? = nil, line2: String? = nil,
        line3Icon: String? = nil, line3: String? = nil,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text(topLabel.isEmpty ? "—" : topLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.indigo.opacity(0.08))
                    .cornerRadius(6)
                Spacer()
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.12))
                    .cornerRadius(6)
            }

            // Title
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.navy)
            if let sub = subtitle, !sub.isEmpty {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
            }

            // Info lines
            HStack(spacing: 12) {
                infoChip(icon: line1Icon, text: line1)
                if let l2 = line2, let l2Icon = line2Icon { infoChip(icon: l2Icon, text: l2) }
                if let l3 = line3, let l3Icon = line3Icon { infoChip(icon: l3Icon, text: l3) }
            }

            Divider()

            // Actions
            HStack {
                Spacer()
                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.system(size: 11))
                        Text("Düzenle").font(.system(size: 12))
                    }
                    .foregroundColor(AppTheme.indigo)
                }
                Button(action: onDelete) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash").font(.system(size: 11))
                        Text("Sil").font(.system(size: 12))
                    }
                    .foregroundColor(.red)
                }
                .padding(.leading, 8)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.borderSoft, lineWidth: 1))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.textMuted)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MARK: - Empty / Error
    // ═══════════════════════════════════════════════════════════
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
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppTheme.navy)
            Text(subtitle).font(.system(size: 13)).foregroundColor(AppTheme.textMuted).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(32)
    }

    func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.circle").font(.system(size: 36)).foregroundColor(.red)
            Text(message).font(.system(size: 13)).foregroundColor(AppTheme.textMuted).multilineTextAlignment(.center)
            Button("Tekrar Dene") { loadData() }.foregroundColor(AppTheme.indigo).fontWeight(.semibold)
            Spacer()
        }
        .padding(32)
    }

    // MARK: - Helpers
    func maintenanceStatusColor(_ status: String) -> Color {
        switch status { case "done": return .green; case "scheduled": return .blue; case "overdue": return .red; default: return .orange }
    }
    func documentStatusColor(_ status: String) -> Color {
        switch status { case "active": return .green; case "expiring_soon": return .orange; case "expired": return .red; default: return Color(red: 148/255, green: 163/255, blue: 184/255) }
    }
    func tireStatusColor(_ status: String) -> Color {
        switch status { case "active": return .green; case "worn": return .orange; case "replaced": return Color(red: 148/255, green: 163/255, blue: 184/255); case "critical": return .red; default: return Color(red: 148/255, green: 163/255, blue: 184/255) }
    }
    func categoryLabel(_ cat: String) -> String {
        switch cat.lowercased() {
        case "fuel": return "Yakıt"; case "maintenance": return "Bakım"; case "tire": return "Lastik"
        case "insurance": return "Sigorta"; case "tax": return "Vergi"; case "fine": return "Ceza"
        case "other": return "Diğer"; default: return cat.prefix(1).uppercased() + cat.dropFirst()
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
                    sectionHeader("Araç Bilgileri", icon: "car")
                    formLabel("Araç *")
                    vehiclePicker(catalog: catalog, selected: $selectedImei)

                    sectionHeader("Bakım Detayları", icon: "wrench")
                    formLabel("Bakım Türü *")
                    formTextField(text: $maintenanceType, placeholder: "Yağ değişimi, fren bakımı...")
                    formLabel("Durum")
                    dropdownPicker(options: statuses, selected: $status)
                    formLabel("Servis Tarihi *")
                    formTextField(text: $serviceDate, placeholder: "2025-01-15")
                    formLabel("Sonraki Servis Tarihi")
                    formTextField(text: $nextServiceDate, placeholder: "2025-07-15")

                    sectionHeader("Kilometre & Maliyet", icon: "speedometer")
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) { formLabel("Servis KM"); formTextField(text: $kmAtService, placeholder: "45000", keyboard: .numberPad) }
                        VStack(alignment: .leading) { formLabel("Sonraki KM"); formTextField(text: $nextServiceKm, placeholder: "55000", keyboard: .numberPad) }
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) { formLabel("Tutar (₺)"); formTextField(text: $cost, placeholder: "1500", keyboard: .decimalPad) }
                        VStack(alignment: .leading) { formLabel("Atölye"); formTextField(text: $workshop, placeholder: "Oto Servis") }
                    }

                    sectionHeader("Notlar", icon: "note.text")
                    formLabel("Açıklama")
                    formTextField(text: $description, placeholder: "Opsiyonel açıklama...", axis: .vertical)

                    if let err = errorMsg { Text(err).font(.system(size: 12)).foregroundColor(.red) }
                    saveButton(isEdit: editing != nil, isSaving: isSaving) { save() }
                }
                .padding(20)
            }
            .navigationTitle(editing != nil ? "Bakım Düzenle" : "Yeni Bakım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("İptal") { onCancel() } } }
        }
    }

    private func save() {
        guard !selectedImei.isEmpty, !maintenanceType.isEmpty, !serviceDate.isEmpty else { errorMsg = "Araç, bakım türü ve servis tarihi zorunludur."; return }
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
    static func todayStr() -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }
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
                    sectionHeader("Araç Bilgileri", icon: "car")
                    formLabel("Araç *")
                    vehiclePicker(catalog: catalog, selected: $selectedImei)

                    sectionHeader("Masraf Detayları", icon: "turkishlirasign.circle")
                    formLabel("Kategori *")
                    dropdownPicker(options: categories, selected: $category)
                    formLabel("Tarih *")
                    formTextField(text: $costDate, placeholder: "2025-01-15")

                    sectionHeader("Tutar", icon: "banknote")
                    formLabel("Tutar (₺) *")
                    formTextField(text: $amount, placeholder: "2500", keyboard: .decimalPad)

                    sectionHeader("Ek Bilgiler", icon: "info.circle")
                    formLabel("Referans No")
                    formTextField(text: $referenceNo, placeholder: "Fatura no, fiş no vb.")
                    formLabel("Açıklama")
                    formTextField(text: $description, placeholder: "Opsiyonel açıklama...", axis: .vertical)

                    if let err = errorMsg { Text(err).font(.system(size: 12)).foregroundColor(.red) }
                    saveButton(isEdit: editing != nil, isSaving: isSaving) { save() }
                }
                .padding(20)
            }
            .navigationTitle(editing != nil ? "Masraf Düzenle" : "Yeni Masraf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("İptal") { onCancel() } } }
        }
    }

    private func save() {
        guard !selectedImei.isEmpty, !category.isEmpty, !amount.isEmpty, !costDate.isEmpty else { errorMsg = "Araç, kategori, tutar ve tarih zorunludur."; return }
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
                    sectionHeader("Araç Bilgileri", icon: "car")
                    formLabel("Araç *")
                    vehiclePicker(catalog: catalog, selected: $selectedImei)

                    sectionHeader("Belge Bilgileri", icon: "doc.text")
                    formLabel("Belge Türü *")
                    dropdownPicker(options: docTypes, selected: $docType)
                    formLabel("Başlık *")
                    formTextField(text: $title, placeholder: "Belge adı")

                    sectionHeader("Tarihler", icon: "calendar")
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) { formLabel("Düzenleme Tarihi"); formTextField(text: $issueDate, placeholder: "2025-01-15") }
                        VStack(alignment: .leading) { formLabel("Bitiş Tarihi"); formTextField(text: $expiryDate, placeholder: "2026-01-15") }
                    }
                    formLabel("Hatırlatma (gün)")
                    formTextField(text: $reminderDays, placeholder: "30", keyboard: .numberPad)

                    sectionHeader("Notlar", icon: "note.text")
                    formLabel("Notlar")
                    formTextField(text: $notes, placeholder: "Opsiyonel notlar...", axis: .vertical)

                    if let err = errorMsg { Text(err).font(.system(size: 12)).foregroundColor(.red) }
                    saveButton(isEdit: editing != nil, isSaving: isSaving) { save() }
                }
                .padding(20)
            }
            .navigationTitle(editing != nil ? "Belge Düzenle" : "Yeni Belge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("İptal") { onCancel() } } }
        }
    }

    private func save() {
        guard !selectedImei.isEmpty, !docType.isEmpty, !title.isEmpty else { errorMsg = "Araç, belge türü ve başlık zorunludur."; return }
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
// MARK: - Tire Form Sheet
// ═══════════════════════════════════════════════════════════
struct TireFormSheet: View {
    let catalog: FleetCatalog?
    let editing: FleetTire?
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var isSaving = false
    @State private var errorMsg: String? = nil
    @State private var selectedImei: String
    @State private var position: String
    @State private var brand: String
    @State private var model: String
    @State private var size: String
    @State private var dotCode: String
    @State private var installDate: String
    @State private var kmAtInstall: String
    @State private var kmLimit: String
    @State private var status: String
    @State private var notes: String

    private let positions: [(String, String)] = [
        ("sol_on", "Sol Ön"), ("sag_on", "Sağ Ön"),
        ("sol_arka", "Sol Arka"), ("sag_arka", "Sağ Arka"),
        ("yedek", "Yedek")
    ]
    private let statuses: [(String, String)] = [
        ("active", "Aktif"), ("worn", "Aşınmış"),
        ("replaced", "Değiştirildi"), ("critical", "Kritik")
    ]

    init(catalog: FleetCatalog?, editing: FleetTire?, onSaved: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.catalog = catalog; self.editing = editing; self.onSaved = onSaved; self.onCancel = onCancel
        _selectedImei = State(initialValue: editing?.imei ?? "")
        _position = State(initialValue: editing?.position ?? "")
        _brand = State(initialValue: editing?.brand ?? "")
        _model = State(initialValue: editing?.model ?? "")
        _size = State(initialValue: editing?.size ?? "")
        _dotCode = State(initialValue: editing?.dotCode ?? "")
        _installDate = State(initialValue: editing?.installDate ?? MaintenanceFormSheet.todayStr())
        _kmAtInstall = State(initialValue: (editing != nil && editing!.kmAtInstall > 0) ? "\(editing!.kmAtInstall)" : "")
        _kmLimit = State(initialValue: (editing != nil && editing!.kmLimit > 0) ? "\(editing!.kmLimit)" : "")
        _status = State(initialValue: editing?.status ?? "active")
        _notes = State(initialValue: editing?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader("Araç Bilgileri", icon: "car")
                    formLabel("Araç *")
                    vehiclePicker(catalog: catalog, selected: $selectedImei)

                    sectionHeader("Lastik Bilgileri", icon: "circle.circle")
                    formLabel("Pozisyon")
                    dropdownPicker(options: positions, selected: $position)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) { formLabel("Marka"); formTextField(text: $brand, placeholder: "Michelin") }
                        VStack(alignment: .leading) { formLabel("Model"); formTextField(text: $model, placeholder: "Primacy 4") }
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) { formLabel("Ebat"); formTextField(text: $size, placeholder: "205/55R16") }
                        VStack(alignment: .leading) { formLabel("DOT Kodu"); formTextField(text: $dotCode, placeholder: "2024") }
                    }

                    sectionHeader("Kilometre & Tarih", icon: "speedometer")
                    formLabel("Montaj Tarihi")
                    formTextField(text: $installDate, placeholder: "2025-01-15")
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) { formLabel("Montaj KM"); formTextField(text: $kmAtInstall, placeholder: "45000", keyboard: .numberPad) }
                        VStack(alignment: .leading) { formLabel("KM Limiti"); formTextField(text: $kmLimit, placeholder: "80000", keyboard: .numberPad) }
                    }
                    formLabel("Durum")
                    dropdownPicker(options: statuses, selected: $status)

                    sectionHeader("Notlar", icon: "note.text")
                    formLabel("Notlar")
                    formTextField(text: $notes, placeholder: "Opsiyonel notlar...", axis: .vertical)

                    if let err = errorMsg { Text(err).font(.system(size: 12)).foregroundColor(.red) }
                    saveButton(isEdit: editing != nil, isSaving: isSaving) { save() }
                }
                .padding(20)
            }
            .navigationTitle(editing != nil ? "Lastik Düzenle" : "Yeni Lastik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("İptal") { onCancel() } } }
        }
    }

    private func save() {
        guard !selectedImei.isEmpty else { errorMsg = "Araç seçimi zorunludur."; return }
        isSaving = true; errorMsg = nil
        Task {
            do {
                var body: [String: Any] = ["device_imei": selectedImei, "position": position, "brand": brand, "model": model, "size": size, "dot_code": dotCode, "install_date": installDate, "status": status, "notes": notes]
                if let v = Int(kmAtInstall) { body["km_at_install"] = v }
                if let v = Int(kmLimit) { body["km_limit"] = v }
                if let e = editing {
                    let _ = try await APIService.shared.put("/api/mobile/fleet/tires/\(e.id)", body: body)
                } else {
                    let _ = try await APIService.shared.post("/api/mobile/fleet/tires", body: body)
                }
                onSaved()
            } catch { errorMsg = error.localizedDescription }
            isSaving = false
        }
    }
}

// ═══════════════════════════════════════════════════════════
// MARK: - Shared Form Components
// ═══════════════════════════════════════════════════════════
private func sectionHeader(_ title: String, icon: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon)
            .font(.system(size: 11))
            .foregroundColor(AppTheme.indigo)
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppTheme.textMuted)
            .tracking(0.5)
    }
    .padding(.top, 12)
}

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
        .background(Color(red: 250/255, green: 251/255, blue: 254/255))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.borderSoft, lineWidth: 1))
        .keyboardType(keyboard)
        .frame(minHeight: axis == .vertical ? 60 : nil, alignment: .top)
}

private func vehiclePicker(catalog: FleetCatalog?, selected: Binding<String>) -> some View {
    let vehicles = catalog?.vehicles ?? []
    let sel = vehicles.first(where: { $0.imei == selected.wrappedValue })
    let label = sel.map { "\($0.plate) (\($0.name))" } ?? (selected.wrappedValue.isEmpty ? "Araç seçiniz" : selected.wrappedValue)

    return Menu {
        ForEach(vehicles) { v in
            Button("\(v.plate) - \(v.name)") { selected.wrappedValue = v.imei }
        }
    } label: {
        HStack {
            Image(systemName: "car").font(.system(size: 12)).foregroundColor(AppTheme.indigo)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(sel != nil ? AppTheme.navy : AppTheme.textMuted)
            Spacer()
            Image(systemName: "chevron.down").font(.system(size: 11)).foregroundColor(AppTheme.textMuted)
        }
        .padding(10)
        .background(Color(red: 250/255, green: 251/255, blue: 254/255))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.borderSoft, lineWidth: 1))
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
            Image(systemName: "chevron.down").font(.system(size: 11)).foregroundColor(AppTheme.textMuted)
        }
        .padding(10)
        .background(Color(red: 250/255, green: 251/255, blue: 254/255))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.borderSoft, lineWidth: 1))
    }
}

private func saveButton(isEdit: Bool, isSaving: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Group {
            if isSaving {
                ProgressView().tint(.white)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: isEdit ? "checkmark" : "plus")
                    Text(isEdit ? "Güncelle" : "Kaydet").fontWeight(.semibold)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
    }
    .buttonStyle(.borderedProminent)
    .tint(AppTheme.indigo)
    .cornerRadius(12)
    .disabled(isSaving)
    .padding(.top, 8)
}

#Preview {
    FleetManagementView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
