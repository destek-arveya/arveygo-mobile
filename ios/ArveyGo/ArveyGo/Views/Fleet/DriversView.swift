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
                    DriversSkeletonView()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            statsStrip
                            searchBar
                            statusChips

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
            .sheet(item: $selectedDriver, onDismiss: { vm.loadDrivers() }) { driver in
                DriverDetailSheet(driver: driver, onRefresh: { vm.loadDrivers() })
            }
            .sheet(isPresented: $showAddDriver) {
                DriverFormSheet(editDriver: nil, onSave: { data in
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
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
            Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(AppTheme.navy)
            Text(label).font(.system(size: 10)).foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(AppTheme.surface).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.borderSoft, lineWidth: 1))
    }

    // MARK: - Search Bar
    var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundColor(AppTheme.textMuted)
            TextField("Sürücü ara...", text: $searchText).font(.system(size: 13)).foregroundColor(AppTheme.navy)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(AppTheme.textFaint)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(AppTheme.surface).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.borderSoft, lineWidth: 1))
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
                if let dot = dotColor { Circle().fill(dot).frame(width: 6, height: 6) }
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(isActive ? .white : AppTheme.textMuted)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(isActive ? AppTheme.navy : Color.clear).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(isActive ? AppTheme.navy : AppTheme.borderSoft, lineWidth: 1))
        }
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2").font(.system(size: 32)).foregroundColor(AppTheme.textFaint)
            Text("Sürücü bulunamadı").font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.textMuted)
        }.padding(.vertical, 40)
    }

    // MARK: - Driver Card
    func driverCard(_ driver: Driver) -> some View {
        let isSelected = selectedDriver?.id == driver.id
        return Button(action: { selectedDriver = driver }) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(driver.avatarColor.opacity(0.15)).frame(width: 44, height: 44)
                        Text(driver.initials).font(.system(size: 14, weight: .bold)).foregroundColor(driver.avatarColor)
                        Circle().fill(driver.statusColor).frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5)).offset(x: 15, y: 15)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(driver.name).font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.navy).lineLimit(1)
                            if !driver.driverCode.isEmpty {
                                Text(driver.driverCode).font(.system(size: 9, weight: .medium)).foregroundColor(AppTheme.textFaint)
                                    .padding(.horizontal, 5).padding(.vertical, 1).background(AppTheme.bg).cornerRadius(4)
                            }
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "car.fill").font(.system(size: 9)).foregroundColor(AppTheme.textFaint)
                            Text(driver.vehicle.isEmpty ? "Araç atanmamış" : driver.vehicle)
                                .font(.system(size: 11)).foregroundColor(driver.vehicle.isEmpty ? AppTheme.textFaint : AppTheme.textMuted).lineLimit(1)
                        }
                        if !driver.phone.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "phone.fill").font(.system(size: 9)).foregroundColor(AppTheme.textFaint)
                                Text(driver.phone).font(.system(size: 10)).foregroundColor(AppTheme.textMuted)
                            }
                        }
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        ZStack {
                            Circle().stroke(driver.scoreColor.opacity(0.2), lineWidth: 3).frame(width: 38, height: 38)
                            Circle().trim(from: 0, to: CGFloat(driver.scoreGeneral) / 100.0)
                                .stroke(driver.scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 38, height: 38).rotationEffect(.degrees(-90))
                            Text("\(driver.scoreGeneral)").font(.system(size: 12, weight: .bold)).foregroundColor(driver.scoreColor)
                        }
                        Text("Skor").font(.system(size: 8)).foregroundColor(AppTheme.textFaint)
                    }
                }.padding(14)
                HStack(spacing: 0) {
                    miniStat(icon: "road.lanes", value: String(format: "%.0f km", driver.totalDistanceKm))
                    miniStat(icon: "arrow.triangle.swap", value: "\(driver.tripCount) sefer")
                    miniStat(icon: "speedometer", value: "\(driver.overspeedCount) hız")
                    miniStat(icon: "bell.fill", value: "\(driver.alarmCount) alarm")
                }.padding(.horizontal, 14).padding(.bottom, 10)
            }
            .background(AppTheme.surface).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? AppTheme.indigo : AppTheme.borderSoft, lineWidth: isSelected ? 1.5 : 1))
        }.buttonStyle(.plain)
    }

    func miniStat(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8)).foregroundColor(AppTheme.textFaint)
            Text(value).font(.system(size: 9, weight: .medium)).foregroundColor(AppTheme.textMuted)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - Driver Detail Sheet
struct DriverDetailSheet: View {
    let driver: Driver
    var onRefresh: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(driver.avatarColor.opacity(0.15)).frame(width: 64, height: 64)
                            Text(driver.initials).font(.system(size: 22, weight: .bold)).foregroundColor(driver.avatarColor)
                        }
                        Text(driver.name).font(.system(size: 18, weight: .bold)).foregroundColor(AppTheme.navy)
                        HStack(spacing: 6) {
                            Circle().fill(driver.statusColor).frame(width: 8, height: 8)
                            Text(driver.status == "online" ? "Çevrimiçi" : driver.status == "idle" ? "Boşta" : "Çevrimdışı")
                                .font(.system(size: 12)).foregroundColor(AppTheme.textMuted)
                            Text("·").foregroundColor(AppTheme.textFaint)
                            Text(driver.role).font(.system(size: 12)).foregroundColor(AppTheme.textMuted)
                        }
                    }.padding(.top, 8)

                    infoSection(title: "İletişim") {
                        if !driver.phone.isEmpty { infoRow(icon: "phone.fill", label: "Telefon", value: driver.phone) }
                        if !driver.email.isEmpty { infoRow(icon: "envelope.fill", label: "E-posta", value: driver.email) }
                        if !driver.employeeNo.isEmpty { infoRow(icon: "number", label: "Sicil No", value: driver.employeeNo) }
                        if !driver.driverCode.isEmpty { infoRow(icon: "barcode", label: "Sürücü Kodu", value: driver.driverCode) }
                    }

                    infoSection(title: "Araç Bilgisi") {
                        infoRow(icon: "car.fill", label: "Mevcut Araç", value: driver.vehicle.isEmpty ? "Atanmamış" : driver.vehicle)
                        if !driver.model.isEmpty { infoRow(icon: "car.2.fill", label: "Model", value: driver.model) }
                        if !driver.city.isEmpty { infoRow(icon: "mappin.circle.fill", label: "Şehir", value: driver.city) }
                    }

                    infoSection(title: "Ehliyet") {
                        infoRow(icon: "creditcard.fill", label: "Sınıf", value: driver.license)
                        if !driver.licenseNo.isEmpty { infoRow(icon: "number.circle.fill", label: "Ehliyet No", value: driver.licenseNo) }
                    }

                    infoSection(title: "Performans Skorları") {
                        scoreRow(label: "Genel", score: driver.scoreGeneral)
                        scoreRow(label: "Hız", score: driver.scoreSpeed)
                        scoreRow(label: "Fren", score: driver.scoreBrake)
                        scoreRow(label: "Yakıt", score: driver.scoreFuel)
                        scoreRow(label: "Güvenlik", score: driver.scoreSafety)
                    }

                    infoSection(title: "İstatistikler") {
                        infoRow(icon: "road.lanes", label: "Toplam Mesafe", value: String(format: "%.1f km", driver.totalDistanceKm))
                        infoRow(icon: "arrow.triangle.swap", label: "Sefer Sayısı", value: "\(driver.tripCount)")
                        infoRow(icon: "speedometer", label: "Hız İhlali", value: "\(driver.overspeedCount)")
                        infoRow(icon: "bell.fill", label: "Alarm", value: "\(driver.alarmCount)")
                    }

                    if !driver.notes.isEmpty {
                        infoSection(title: "Notlar") {
                            Text(driver.notes).font(.system(size: 12)).foregroundColor(AppTheme.textSecondary)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                        }
                    }
                    Spacer().frame(height: 30)
                }.padding(.horizontal, 16)
            }
            .background(AppTheme.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { dismiss() }
                        .font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.indigo)
                }
                ToolbarItem(placement: .principal) {
                    Text("Sürücü Detayı").font(.system(size: 15, weight: .semibold)).foregroundColor(AppTheme.navy)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showEditSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil").font(.system(size: 13))
                            Text("Düzenle").font(.system(size: 13, weight: .medium))
                        }.foregroundColor(AppTheme.indigo)
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                DriverFormSheet(editDriver: driver, onSave: { data in
                    Task {
                        do {
                            _ = try await APIService.shared.updateDriver(id: driver.id, data: data)
                            onRefresh?()
                            showEditSheet = false
                            dismiss()
                        } catch {
                            print("[Driver] Update error: \(error)")
                        }
                    }
                })
            }
        }
    }

    @ViewBuilder
    func infoSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(AppTheme.textFaint)
                .tracking(0.5).padding(.horizontal, 16).padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(AppTheme.surface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.borderSoft, lineWidth: 1))
        }
    }

    func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(AppTheme.indigo).frame(width: 20)
            Text(label).font(.system(size: 12)).foregroundColor(AppTheme.textMuted)
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium)).foregroundColor(AppTheme.navy).lineLimit(1)
        }.padding(.horizontal, 16).padding(.vertical, 10)
    }

    func scoreRow(label: String, score: Int) -> some View {
        let color: Color = score >= 85 ? AppTheme.online : score >= 70 ? AppTheme.idle : AppTheme.offline
        return HStack(spacing: 10) {
            Text(label).font(.system(size: 12)).foregroundColor(AppTheme.textMuted).frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(AppTheme.bg).frame(height: 6)
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: geo.size.width * CGFloat(score) / 100, height: 6)
                }
            }.frame(height: 6)
            Text("\(score)").font(.system(size: 12, weight: .bold)).foregroundColor(color).frame(width: 28, alignment: .trailing)
        }.padding(.horizontal, 16).padding(.vertical, 8)
    }
}

// MARK: - Driver Form Sheet (Create + Edit) — Redesigned
struct DriverFormSheet: View {
    let editDriver: Driver?
    let onSave: ([String: Any]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var driverCode = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var licenseClass = ""
    @State private var licenseNo = ""
    @State private var employeeNo = ""
    @State private var status = "active"
    @State private var notes = ""
    @State private var selectedVehicleId: Int?

    @State private var vehicles: [CatalogVehicle] = []
    @State private var isLoadingCatalog = false
    @State private var phoneError: String?

    var isEditing: Bool { editDriver != nil }

    var isPhoneValid: Bool {
        let digits = phone.filter { $0.isNumber }
        return phone.isEmpty || digits.count == 11
    }

    var canSave: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !driverCode.trimmingCharacters(in: .whitespaces).isEmpty &&
        isPhoneValid
    }

    var statusLabel: String {
        switch status {
        case "active": return "Aktif"
        case "inactive": return "Pasif"
        case "on_leave": return "İzinli"
        default: return status
        }
    }

    var statusColor: Color {
        switch status {
        case "active": return AppTheme.online
        case "inactive": return AppTheme.offline
        case "on_leave": return AppTheme.idle
        default: return AppTheme.textMuted
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header avatar
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.indigo.opacity(0.1))
                                .frame(width: 72, height: 72)
                            Text(fullName.isEmpty ? "?" : String(fullName.prefix(1)).uppercased())
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AppTheme.indigo)
                        }
                        if isEditing {
                            Text(editDriver?.driverCode ?? "")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.textMuted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppTheme.bgAlt, in: Capsule())
                        }
                    }
                    .padding(.top, 8)

                    // Basic info section
                    formSection(title: "Temel Bilgiler", icon: "person.fill") {
                        formField(label: "Ad Soyad", placeholder: "Ad Soyad *", text: $fullName, required: true)
                        formField(label: "Sürücü Kodu", placeholder: "Sürücü Kodu *", text: $driverCode, required: true, capitalize: true)

                        // Status picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Durum")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textMuted)
                            HStack(spacing: 8) {
                                statusButton("Aktif", value: "active", color: AppTheme.online)
                                statusButton("Pasif", value: "inactive", color: AppTheme.offline)
                                statusButton("İzinli", value: "on_leave", color: AppTheme.idle)
                            }
                        }
                    }

                    // Contact section
                    formSection(title: "İletişim", icon: "phone.fill") {
                        VStack(alignment: .leading, spacing: 4) {
                            formField(label: "Telefon", placeholder: "05XXXXXXXXX", text: $phone, keyboard: .numberPad)
                                .onChange(of: phone) { newValue in
                                    let digits = newValue.filter { $0.isNumber }
                                    if digits.count > 11 {
                                        phone = String(digits.prefix(11))
                                    } else if digits != newValue {
                                        phone = digits
                                    }
                                    if !phone.isEmpty {
                                        let d = phone.filter { $0.isNumber }
                                        if d.count != 11 {
                                            phoneError = "Telefon numarası 11 haneli olmalıdır"
                                        } else if !d.hasPrefix("0") {
                                            phoneError = "Telefon numarası 0 ile başlamalıdır"
                                        } else {
                                            phoneError = nil
                                        }
                                    } else {
                                        phoneError = nil
                                    }
                                }
                            if let err = phoneError {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 10))
                                    Text(err)
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.red)
                                .padding(.leading, 4)
                            }
                        }
                        formField(label: "E-posta", placeholder: "ornek@email.com", text: $email, keyboard: .emailAddress, capitalize: false)
                    }

                    // License section
                    formSection(title: "Ehliyet Bilgileri", icon: "creditcard.fill") {
                        HStack(spacing: 12) {
                            formField(label: "Ehliyet Sınıfı", placeholder: "B, C, D...", text: $licenseClass)
                            formField(label: "Ehliyet No", placeholder: "Ehliyet No", text: $licenseNo)
                        }
                    }

                    // Other section
                    formSection(title: "Diğer", icon: "doc.text.fill") {
                        formField(label: "Sicil No", placeholder: "Sicil numarası", text: $employeeNo)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notlar")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textMuted)
                            TextEditor(text: $notes)
                                .frame(minHeight: 60, maxHeight: 100)
                                .font(.system(size: 14))
                                .padding(8)
                                .background(AppTheme.bgAlt)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.borderSoft, lineWidth: 1)
                                )
                        }
                    }

                    // Vehicle assignment section
                    formSection(title: "Araç Ataması", icon: "car.fill") {
                        if isLoadingCatalog {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.8)
                                Text("Araçlar yükleniyor...")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .padding(.vertical, 4)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Araç Seç")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppTheme.textMuted)

                                // Selected vehicle display
                                if let id = selectedVehicleId, let v = vehicles.first(where: { $0.id == id }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "car.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(AppTheme.indigo)
                                        Text("\(v.plate) — \(v.name)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(AppTheme.navy)
                                        Spacer()
                                        Button { selectedVehicleId = nil } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppTheme.textMuted)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.indigo.opacity(0.06))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(AppTheme.indigo.opacity(0.2), lineWidth: 1)
                                    )
                                }

                                // Search field
                                SearchableVehiclePicker(
                                    vehicles: vehicles,
                                    selectedVehicleId: $selectedVehicleId
                                )
                            }
                        }
                    }

                    // Save button
                    Button(action: saveDriver) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                            Text("Kaydet")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSave ? AppTheme.indigo : AppTheme.textFaint.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSave)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(AppTheme.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.textMuted)
                        .padding(8)
                        .background(AppTheme.bgAlt, in: Circle())
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(isEditing ? "Sürücü Düzenle" : "Yeni Sürücü")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.navy)
                }
            }
            .onAppear {
                loadCatalog()
                if let d = editDriver {
                    fullName = d.name
                    driverCode = d.driverCode
                    phone = d.phone
                    email = d.email
                    licenseClass = d.license
                    licenseNo = d.licenseNo
                    employeeNo = d.employeeNo
                    status = (d.profileStatus == "no_profile" || d.profileStatus.isEmpty) ? "active" : d.profileStatus
                    notes = d.notes
                }
            }
        }
    }

    // MARK: - Section builder
    @ViewBuilder
    private func formSection(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.indigo)
                    .frame(width: 24, height: 24)
                    .background(AppTheme.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
            }
            content()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Field builder
    @ViewBuilder
    private func formField(label: String, placeholder: String, text: Binding<String>, required: Bool = false, keyboard: UIKeyboardType = .default, capitalize: Bool? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
                if required {
                    Text("*")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            TextField(placeholder, text: text)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.bgAlt)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.borderSoft, lineWidth: 1)
                )
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalize == true ? .characters : capitalize == false ? .never : .words)
        }
    }

    // MARK: - Status button
    @ViewBuilder
    private func statusButton(_ label: String, value: String, color: Color) -> some View {
        let isSelected = status == value
        Button { status = value } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.12) : AppTheme.bgAlt)
            .foregroundColor(isSelected ? color : AppTheme.textSecondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color.opacity(0.4) : AppTheme.borderSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func loadCatalog() {
        isLoadingCatalog = true
        Task {
            do {
                let raw = try await APIService.shared.fetchDriverCatalog()
                await MainActor.run {
                    vehicles = raw.compactMap { dict -> CatalogVehicle? in
                        guard let id = dict["id"] as? Int,
                              let plate = dict["plate"] as? String else { return nil }
                        return CatalogVehicle(id: id, imei: dict["imei"] as? String ?? "",
                                              plate: plate, name: dict["name"] as? String ?? "")
                    }
                    isLoadingCatalog = false
                }
            } catch {
                await MainActor.run { isLoadingCatalog = false }
                print("[DriverForm] Catalog error: \(error)")
            }
        }
    }

    private func saveDriver() {
        var data: [String: Any] = [
            "full_name": fullName.trimmingCharacters(in: .whitespaces),
            "driver_code": driverCode.trimmingCharacters(in: .whitespaces),
            "status": status
        ]
        if !phone.isEmpty { data["phone"] = phone }
        if !email.isEmpty { data["email"] = email }
        if !licenseClass.isEmpty { data["license_class"] = licenseClass }
        if !licenseNo.isEmpty { data["license_no"] = licenseNo }
        if !employeeNo.isEmpty { data["employee_no"] = employeeNo }
        if !notes.isEmpty { data["notes"] = notes }

        onSave(data)

        // Assign vehicle if selected
        if let vehicleId = selectedVehicleId {
            let dc = driverCode.trimmingCharacters(in: .whitespaces)
            let pid = editDriver?.profileId
            Task {
                do {
                    try await APIService.shared.assignDriverToVehicle(
                        vehicleId: vehicleId,
                        driverProfileId: pid,
                        driverCode: dc.isEmpty ? nil : dc
                    )
                } catch {
                    print("[DriverForm] Assign vehicle error: \(error)")
                }
            }
        }
    }
}

// MARK: - Searchable Vehicle Picker
struct SearchableVehiclePicker: View {
    let vehicles: [CatalogVehicle]
    @Binding var selectedVehicleId: Int?
    @State private var searchText = ""
    @State private var isExpanded = false

    var filteredVehicles: [CatalogVehicle] {
        if searchText.isEmpty { return vehicles }
        return vehicles.filter {
            $0.plate.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textMuted)
                TextField("Plaka veya araç adı ara...", text: $searchText)
                    .font(.system(size: 13))
                    .onTapGesture { isExpanded = true }
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.bgAlt)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.borderSoft, lineWidth: 1)
            )

            // Vehicle list
            if isExpanded || !searchText.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        // Unassign option
                        Button {
                            selectedVehicleId = nil
                            isExpanded = false
                            searchText = ""
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                                Text("Araç atanmamış")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textMuted)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        Divider()

                        ForEach(filteredVehicles) { v in
                            Button {
                                selectedVehicleId = v.id
                                isExpanded = false
                                searchText = ""
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.indigo)
                                    Text("\(v.plate) — \(v.name)")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.navy)
                                    Spacer()
                                    if selectedVehicleId == v.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(AppTheme.indigo)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(selectedVehicleId == v.id ? AppTheme.indigo.opacity(0.06) : Color.clear)
                            }
                            .buttonStyle(.plain)

                            Divider()
                        }

                        if filteredVehicles.isEmpty && !searchText.isEmpty {
                            Text("Araç bulunamadı")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)
                                .padding(16)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(AppTheme.surface)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.borderSoft, lineWidth: 1)
                )
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
        isLoading = true; error = nil
        Task {
            do {
                let response = try await APIService.shared.fetchDrivers()
                await MainActor.run { self.drivers = response.drivers; self.stats = response.stats; self.isLoading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
                print("[Drivers] Error: \(error)")
            }
        }
    }

    func createDriver(data: [String: Any]) {
        Task {
            do { let _ = try await APIService.shared.createDriver(data: data); loadDrivers() }
            catch { print("[Drivers] Create error: \(error)") }
        }
    }

    func updateDriver(id: String, data: [String: Any]) {
        Task {
            do { let _ = try await APIService.shared.updateDriver(id: id, data: data); loadDrivers() }
            catch { print("[Drivers] Update error: \(error)") }
        }
    }
}

// MARK: - Vehicle Driver Assign Sheet (used from Vehicle Detail)
struct VehicleDriverAssignSheet: View {
    let vehicleId: Int
    let currentDriverName: String
    var onAssigned: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var drivers: [Driver] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var isAssigning = false

    var filteredDrivers: [Driver] {
        if searchText.isEmpty { return drivers }
        return drivers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.driverCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                if isLoading {
                    ProgressView()
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundColor(AppTheme.textMuted)
                            TextField("Sürücü ara...", text: $searchText).font(.system(size: 13))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(AppTheme.surface).cornerRadius(10)
                        .padding(.horizontal, 16).padding(.top, 8)

                        if !currentDriverName.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill.checkmark").font(.system(size: 12)).foregroundColor(AppTheme.online)
                                Text("Mevcut: \(currentDriverName)").font(.system(size: 12, weight: .medium)).foregroundColor(AppTheme.navy)
                                Spacer()
                                Button(action: { clearDriver() }) {
                                    Text("Kaldır").font(.system(size: 11, weight: .semibold)).foregroundColor(.red)
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(Color.red.opacity(0.1)).cornerRadius(6)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(AppTheme.online.opacity(0.05))
                        }

                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(filteredDrivers, id: \.id) { driver in
                                    Button(action: { assignDriver(driver) }) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle().fill(driver.avatarColor.opacity(0.15)).frame(width: 40, height: 40)
                                                Text(driver.initials).font(.system(size: 13, weight: .bold)).foregroundColor(driver.avatarColor)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(driver.name).font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.navy)
                                                HStack(spacing: 8) {
                                                    if !driver.driverCode.isEmpty {
                                                        Text(driver.driverCode).font(.system(size: 10)).foregroundColor(AppTheme.textFaint)
                                                    }
                                                    if !driver.phone.isEmpty {
                                                        Text(driver.phone).font(.system(size: 10)).foregroundColor(AppTheme.textMuted)
                                                    }
                                                }
                                            }
                                            Spacer()
                                            if !driver.vehicle.isEmpty {
                                                Text(driver.vehicle).font(.system(size: 10)).foregroundColor(AppTheme.textFaint)
                                            }
                                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(AppTheme.textFaint)
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(AppTheme.surface).cornerRadius(10)
                                    }
                                    .buttonStyle(.plain).disabled(isAssigning)
                                }
                            }.padding(.horizontal, 16).padding(.top, 8)
                        }
                    }
                }
                if isAssigning {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView().scaleEffect(1.2).tint(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") { dismiss() }.font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.indigo)
                }
                ToolbarItem(placement: .principal) {
                    Text("Sürücü Ata").font(.system(size: 15, weight: .semibold)).foregroundColor(AppTheme.navy)
                }
            }
            .onAppear { loadDrivers() }
        }
    }

    private func loadDrivers() {
        Task {
            do {
                let response = try await APIService.shared.fetchDrivers()
                await MainActor.run { drivers = response.drivers; isLoading = false }
            } catch { await MainActor.run { isLoading = false } }
        }
    }

    private func assignDriver(_ driver: Driver) {
        isAssigning = true
        Task {
            do {
                try await APIService.shared.assignDriverToVehicle(
                    vehicleId: vehicleId,
                    driverProfileId: driver.profileId,
                    driverCode: driver.driverCode.isEmpty ? nil : driver.driverCode
                )
                await MainActor.run { isAssigning = false; onAssigned?(); dismiss() }
            } catch {
                await MainActor.run { isAssigning = false }
                print("[VehicleDriverAssign] Error: \(error)")
            }
        }
    }

    private func clearDriver() {
        isAssigning = true
        Task {
            do {
                try await APIService.shared.clearDriverFromVehicle(vehicleId: vehicleId)
                await MainActor.run { isAssigning = false; onAssigned?(); dismiss() }
            } catch {
                await MainActor.run { isAssigning = false }
                print("[VehicleDriverAssign] Clear error: \(error)")
            }
        }
    }
}

// MARK: - Drivers Skeleton View
struct DriversSkeletonView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        let shimmer = LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(.systemGray5), location: max(0, phase - 0.3)),
                .init(color: Color(.systemGray4).opacity(0.6), location: phase),
                .init(color: Color(.systemGray5), location: min(1, phase + 0.3))
            ]),
            startPoint: .leading, endPoint: .trailing
        )

        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // Stats strip skeleton
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 20).fill(shimmer).frame(width: 80, height: 34)
                    }
                }

                // Search bar skeleton
                RoundedRectangle(cornerRadius: 10).fill(shimmer).frame(height: 40)

                // Filter chips skeleton
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 20).fill(shimmer).frame(width: i == 0 ? 50 : 80, height: 30)
                    }
                    Spacer()
                }

                // Driver card skeletons
                ForEach(0..<6, id: \.self) { _ in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            // Avatar
                            Circle().fill(shimmer).frame(width: 44, height: 44)
                            // Name & info
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4).fill(shimmer).frame(width: 130, height: 13)
                                RoundedRectangle(cornerRadius: 4).fill(shimmer).frame(width: 90, height: 11)
                                RoundedRectangle(cornerRadius: 4).fill(shimmer).frame(width: 70, height: 10)
                            }
                            Spacer()
                            // Score circle
                            Circle().fill(shimmer).frame(width: 42, height: 42)
                        }.padding(14)

                        // Mini stats row
                        HStack(spacing: 0) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 4).fill(shimmer).frame(height: 10).frame(maxWidth: .infinity).padding(.horizontal, 4)
                            }
                        }.padding(.horizontal, 14).padding(.bottom, 10)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5), lineWidth: 1))
                }

                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1.3
            }
        }
    }
}

#Preview {
    DriversView(showSideMenu: .constant(false))
        .environmentObject(AuthViewModel())
}
