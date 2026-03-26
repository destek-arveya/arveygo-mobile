import SwiftUI

// MARK: - Drivers View
struct DriversView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var showSideMenu: Bool
    @StateObject private var vm = DriversViewModel()

    @State private var selectedDriver: Driver?
    @State private var searchText = ""
    @State private var filterStatus = "all" // all, online, offline, idle
    @State private var showAddDriver = false

    var filteredDrivers: [Driver] {
        var result = vm.drivers
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.driverCode.localizedCaseInsensitiveContains(searchText) ||
                $0.vehicle.localizedCaseInsensitiveContains(searchText) ||
                $0.phone.localizedCaseInsensitiveContains(searchText)
            }
        }
        if filterStatus != "all" {
            result = result.filter { $0.status == filterStatus }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                if vm.isLoading && vm.drivers.isEmpty {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            // Stats strip
                            statsStrip

                            // Search + filter
                            searchBar

                            // Status filter chips
                            statusChips

                            // Driver list
                            if filteredDrivers.isEmpty {
                                emptyState
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(filteredDrivers, id: \.id) { driver in
                                        driverCard(driver)
                                    }
                                }
                            }

                            Spacer().frame(height: 16)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                    }
                    .refreshable {
                        vm.loadDrivers()
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
            }
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
                        Text("Sürücüler")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                        Text("Sürücü Yönetimi")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        Button(action: { showAddDriver = true }) {
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
            .onAppear { vm.loadDrivers() }
            .sheet(item: $selectedDriver) { driver in
                DriverDetailSheet(driver: driver)
            }
            .sheet(isPresented: $showAddDriver) {
                AddDriverSheet(onSave: { data in
                    vm.createDriver(data: data)
                    showAddDriver = false
                })
            }
        }
    }

    // MARK: - Stats Strip
    var statsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statChip(icon: "person.2.fill", label: "Toplam", value: "\(vm.stats.total)", color: AppTheme.navy)
                statChip(icon: "checkmark.circle.fill", label: "Aktif", value: "\(vm.stats.active)", color: AppTheme.online)
                statChip(icon: "antenna.radiowaves.left.and.right", label: "Takipli", value: "\(vm.stats.tracked)", color: AppTheme.indigo)
                statChip(icon: "hand.thumbsup.fill", label: "İyi", value: "\(vm.stats.good)", color: AppTheme.online)
                statChip(icon: "exclamationmark.triangle.fill", label: "Düşük", value: "\(vm.stats.low)", color: .red)
            }
        }
    }

    func statChip(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.navy)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Search Bar
    var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textMuted)
            TextField("Sürücü ara...", text: $searchText)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.navy)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textFaint)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Status Chips
    var statusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                statusChip("all", "Tümü", nil)
                statusChip("online", "Çevrimiçi", AppTheme.online)
                statusChip("idle", "Boşta", AppTheme.idle)
                statusChip("offline", "Çevrimdışı", AppTheme.offline)
            }
        }
    }

    func statusChip(_ key: String, _ label: String, _ dotColor: Color?) -> some View {
        let isActive = filterStatus == key
        return Button(action: { filterStatus = key }) {
            HStack(spacing: 4) {
                if let dot = dotColor {
                    Circle().fill(dot).frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(isActive ? .white : AppTheme.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? AppTheme.navy : Color.clear)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isActive ? AppTheme.navy : AppTheme.borderSoft, lineWidth: 1)
            )
        }
    }

    // MARK: - Empty State
    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2")
                .font(.system(size: 32))
                .foregroundColor(AppTheme.textFaint)
            Text("Sürücü bulunamadı")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Driver Card
    func driverCard(_ driver: Driver) -> some View {
        let isSelected = selectedDriver?.id == driver.id
        return Button(action: { selectedDriver = driver }) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(driver.avatarColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Text(driver.initials)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(driver.avatarColor)
                        // Status dot
                        Circle()
                            .fill(driver.statusColor)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .offset(x: 15, y: 15)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(driver.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.navy)
                                .lineLimit(1)
                            if !driver.driverCode.isEmpty {
                                Text(driver.driverCode)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(AppTheme.textFaint)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(AppTheme.bg)
                                    .cornerRadius(4)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 9))
                                .foregroundColor(AppTheme.textFaint)
                            Text(driver.vehicle)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                                .lineLimit(1)
                        }

                        if !driver.phone.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(AppTheme.textFaint)
                                Text(driver.phone)
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                        }
                    }

                    Spacer()

                    // Score badge
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .stroke(driver.scoreColor.opacity(0.2), lineWidth: 3)
                                .frame(width: 38, height: 38)
                            Circle()
                                .trim(from: 0, to: CGFloat(driver.scoreGeneral) / 100.0)
                                .stroke(driver.scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 38, height: 38)
                                .rotationEffect(.degrees(-90))
                            Text("\(driver.scoreGeneral)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(driver.scoreColor)
                        }
                        Text("Skor")
                            .font(.system(size: 8))
                            .foregroundColor(AppTheme.textFaint)
                    }
                }
                .padding(14)

                // Bottom stats row
                HStack(spacing: 0) {
                    miniStat(icon: "road.lanes", value: String(format: "%.0f km", driver.totalDistanceKm))
                    miniStat(icon: "arrow.triangle.swap", value: "\(driver.tripCount) sefer")
                    miniStat(icon: "speedometer", value: "\(driver.overspeedCount) hız")
                    miniStat(icon: "bell.fill", value: "\(driver.alarmCount) alarm")
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .background(AppTheme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.indigo : AppTheme.borderSoft, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    func miniStat(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(AppTheme.textFaint)
            Text(value)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Driver Detail Sheet
struct DriverDetailSheet: View {
    let driver: Driver
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(driver.avatarColor.opacity(0.15))
                                .frame(width: 64, height: 64)
                            Text(driver.initials)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(driver.avatarColor)
                        }
                        Text(driver.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.navy)
                        HStack(spacing: 6) {
                            Circle().fill(driver.statusColor).frame(width: 8, height: 8)
                            Text(driver.status == "online" ? "Çevrimiçi" : driver.status == "idle" ? "Boşta" : "Çevrimdışı")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)
                            Text("·")
                                .foregroundColor(AppTheme.textFaint)
                            Text(driver.role)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    .padding(.top, 8)

                    // Contact Info
                    infoSection(title: "İletişim") {
                        if !driver.phone.isEmpty { infoRow(icon: "phone.fill", label: "Telefon", value: driver.phone) }
                        if !driver.email.isEmpty { infoRow(icon: "envelope.fill", label: "E-posta", value: driver.email) }
                        if !driver.employeeNo.isEmpty { infoRow(icon: "number", label: "Sicil No", value: driver.employeeNo) }
                        if !driver.driverCode.isEmpty { infoRow(icon: "barcode", label: "Sürücü Kodu", value: driver.driverCode) }
                    }

                    // Vehicle Info
                    infoSection(title: "Araç Bilgisi") {
                        infoRow(icon: "car.fill", label: "Mevcut Araç", value: driver.vehicle)
                        if !driver.model.isEmpty { infoRow(icon: "car.2.fill", label: "Model", value: driver.model) }
                        if !driver.city.isEmpty { infoRow(icon: "mappin.circle.fill", label: "Şehir", value: driver.city) }
                    }

                    // License Info
                    infoSection(title: "Ehliyet") {
                        infoRow(icon: "creditcard.fill", label: "Sınıf", value: driver.license)
                        if !driver.licenseNo.isEmpty { infoRow(icon: "number.circle.fill", label: "Ehliyet No", value: driver.licenseNo) }
                    }

                    // Performance Scores
                    infoSection(title: "Performans Skorları") {
                        scoreRow(label: "Genel", score: driver.scoreGeneral)
                        scoreRow(label: "Hız", score: driver.scoreSpeed)
                        scoreRow(label: "Fren", score: driver.scoreBrake)
                        scoreRow(label: "Yakıt", score: driver.scoreFuel)
                        scoreRow(label: "Güvenlik", score: driver.scoreSafety)
                    }

                    // Stats
                    infoSection(title: "İstatistikler") {
                        infoRow(icon: "road.lanes", label: "Toplam Mesafe", value: String(format: "%.1f km", driver.totalDistanceKm))
                        infoRow(icon: "arrow.triangle.swap", label: "Sefer Sayısı", value: "\(driver.tripCount)")
                        infoRow(icon: "speedometer", label: "Hız İhlali", value: "\(driver.overspeedCount)")
                        infoRow(icon: "bell.fill", label: "Alarm", value: "\(driver.alarmCount)")
                    }

                    if !driver.notes.isEmpty {
                        infoSection(title: "Notlar") {
                            Text(driver.notes)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 16)
            }
            .background(AppTheme.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.indigo)
                }
                ToolbarItem(placement: .principal) {
                    Text("Sürücü Detayı")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.navy)
                }
            }
        }
    }

    @ViewBuilder
    func infoSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.textFaint)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.surface)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.borderSoft, lineWidth: 1)
            )
        }
    }

    func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.indigo)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.navy)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    func scoreRow(label: String, score: Int) -> some View {
        let color: Color = score >= 85 ? AppTheme.online : score >= 70 ? AppTheme.idle : AppTheme.offline
        return HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.bg)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / 100, height: 6)
                }
            }
            .frame(height: 6)
            Text("\(score)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Add Driver Sheet
struct AddDriverSheet: View {
    let onSave: ([String: Any]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var driverCode = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var status = "active"

    var body: some View {
        NavigationStack {
            Form {
                Section("Temel Bilgiler") {
                    TextField("Ad Soyad *", text: $fullName)
                    TextField("Sürücü Kodu", text: $driverCode)
                    Picker("Durum", selection: $status) {
                        Text("Aktif").tag("active")
                        Text("Pasif").tag("inactive")
                    }
                }
                Section("İletişim") {
                    TextField("Telefon", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("E-posta", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppTheme.textMuted)
                }
                ToolbarItem(placement: .principal) {
                    Text("Yeni Sürücü")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.navy)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        var data: [String: Any] = [
                            "full_name": fullName,
                            "status": status
                        ]
                        if !driverCode.isEmpty { data["driver_code"] = driverCode }
                        if !phone.isEmpty { data["phone"] = phone }
                        if !email.isEmpty { data["email"] = email }
                        onSave(data)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(fullName.isEmpty ? AppTheme.textFaint : AppTheme.indigo)
                    .disabled(fullName.isEmpty)
                }
            }
        }
    }
}

// MARK: - ViewModel
class DriversViewModel: ObservableObject {
    @Published var drivers: [Driver] = []
    @Published var stats = DriverStats(total: 0, active: 0, tracked: 0, good: 0, mid: 0, low: 0)
    @Published var isLoading = false
    @Published var error: String?

    func loadDrivers() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        Task {
            do {
                let response = try await APIService.shared.fetchDrivers()
                await MainActor.run {
                    self.drivers = response.drivers
                    self.stats = response.stats
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
                print("[Drivers] Error: \(error)")
            }
        }
    }

    func createDriver(data: [String: Any]) {
        Task {
            do {
                let _ = try await APIService.shared.createDriver(data: data)
                loadDrivers() // Refresh list
            } catch {
                print("[Drivers] Create error: \(error)")
            }
        }
    }
}

#Preview {
    DriversView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
