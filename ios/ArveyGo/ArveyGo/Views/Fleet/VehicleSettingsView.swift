import SwiftUI

private let vehicleSettingsHiddenIgnitionPrefix = "__mobile_private_ign__"

struct VehicleSettingsView: View {
    let vehicle: Vehicle

    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var ignitionOnNotificationEnabled = false
    @State private var ignitionOffNotificationEnabled = false
    @State private var ignitionPushEnabled = true
    @State private var ignitionSmsEnabled = false
    @State private var ignitionMailEnabled = false
    @State private var ignitionSettingsLoaded = false
    @State private var ignitionSettingsSyncing = false
    @State private var ignitionSettingsMessage: String?
    @State private var movementAlarm = false
    @State private var overspeedEnabled = false
    @State private var overspeedLimit = 110
    @State private var idleAlertEnabled = false
    @State private var idleMinutes = 10
    @State private var blockageProtection = false
    @State private var weeklyHealthSummary = false
    @State private var lowBatteryWarning = false
    @State private var reportIntervalMinutes = 5
    @State private var sleepIntervalHours = 6
    @State private var showKontakWarning = false

    private var isDark: Bool { colorScheme == .dark }
    private var pageBackground: Color {
        isDark ? Color(red: 14/255, green: 19/255, blue: 34/255) : Color(UIColor.systemGroupedBackground)
    }
    private var surface: Color {
        isDark ? Color(red: 23/255, green: 29/255, blue: 54/255) : Color(UIColor.secondarySystemGroupedBackground)
    }
    private var primaryText: Color {
        Color(UIColor.label)
    }
    private var secondaryText: Color {
        Color(UIColor.secondaryLabel)
    }
    private var accent: Color {
        Color(red: 37/255, green: 99/255, blue: 235/255)
    }
    private var borderColor: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(vehicle.status.color.opacity(0.14))
                            .frame(width: 50, height: 50)
                        Image(systemName: vehicle.mapIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(vehicle.status.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(vehicle.plate)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(primaryText)
                        Text(vehicle.model.isEmpty ? "Araç ayar merkezi" : vehicle.model)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(secondaryText)
                    }

                    Spacer()

                    StatusBadge(status: vehicle.status)
                }
                .padding(.vertical, 4)
            }

            Section(header: sectionHeader("Bildirimler", icon: "bell.badge.fill")) {
                Toggle(isOn: Binding(
                    get: { ignitionOnNotificationEnabled },
                    set: { setIgnitionNotificationEnabled("ignition_on", enabled: $0) }
                )) {
                    settingLabel("Kontak Açılma Bildirimi", subtitle: "Kontak açıldığında yalnızca size özel bildirim gönder")
                }
                .tint(AppTheme.online)

                Toggle(isOn: Binding(
                    get: { ignitionOffNotificationEnabled },
                    set: { setIgnitionNotificationEnabled("ignition_off", enabled: $0) }
                )) {
                    settingLabel("Kontak Kapanma Bildirimi", subtitle: "Kontak kapandığında yalnızca size özel bildirim gönder")
                }
                .tint(AppTheme.online)

                if hasAnyIgnitionNotificationEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: Binding(
                            get: { ignitionPushEnabled },
                            set: { setIgnitionChannel("push", enabled: $0) }
                        )) {
                            settingLabel("Mobil Bildirim", subtitle: "Uygulama içine anlık push gönder")
                        }
                        .tint(AppTheme.indigo)

                        Toggle(isOn: Binding(
                            get: { ignitionSmsEnabled },
                            set: { setIgnitionChannel("sms", enabled: $0) }
                        )) {
                            settingLabel("SMS", subtitle: "Telefon numaranıza kısa mesaj olarak ilet")
                        }
                        .tint(AppTheme.offline)

                        Toggle(isOn: Binding(
                            get: { ignitionMailEnabled },
                            set: { setIgnitionChannel("email", enabled: $0) }
                        )) {
                            settingLabel("Mail", subtitle: "E-posta adresinize bildirim özeti gönder")
                        }
                        .tint(accent)

                        HStack(spacing: 8) {
                            if ignitionSettingsSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.online)
                            }

                            Text(ignitionSettingsMessage ?? "Bu bildirim yalnızca sizin hesabınıza teslim edilir.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ignitionSettingsMessage == nil ? secondaryText : .red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.leading, 4)
                }

                Toggle(isOn: $movementAlarm) {
                    settingLabel("Hareket Algılandı", subtitle: "Beklenmeyen hareketlerde anlık uyarı ver")
                }
                .tint(AppTheme.online)

                Toggle(isOn: $weeklyHealthSummary) {
                    settingLabel("Haftalık Durum Özeti", subtitle: "Bakım ve operasyon özetini haftalık gönder")
                }
                .tint(AppTheme.online)
            }

            Section(header: sectionHeader("Sürüş ve Güvenlik", icon: "shield.lefthalf.filled")) {
                Toggle(isOn: $overspeedEnabled) {
                    settingLabel("Hız Aşımı Uyarısı", subtitle: "Belirlenen limit aşıldığında alarm üret")
                }
                .tint(AppTheme.offline)

                if overspeedEnabled {
                    Stepper(value: $overspeedLimit, in: 50...180, step: 5) {
                        HStack {
                            Text("Hız Limiti")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(primaryText)
                            Spacer()
                            Text("\(overspeedLimit) km/h")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.offline)
                        }
                    }
                }

                Toggle(isOn: $idleAlertEnabled) {
                    settingLabel("Rölanti Uyarısı", subtitle: "Araç uzun süre çalışır halde beklerse bildir")
                }
                .tint(AppTheme.idle)

                if idleAlertEnabled {
                    Stepper(value: $idleMinutes, in: 3...60, step: 1) {
                        HStack {
                            Text("Rölanti Süresi")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(primaryText)
                            Spacer()
                            Text("\(idleMinutes) dk")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.idle)
                        }
                    }
                }

                Toggle(isOn: $blockageProtection) {
                    settingLabel("Blokaj Koruması", subtitle: "Yetkisiz kullanımda blokaj önerisi oluştur")
                }
                .tint(AppTheme.offline)
            }

            Section(header: sectionHeader("Cihaz ve Raporlama", icon: "waveform.path.ecg")) {
                Stepper(value: $reportIntervalMinutes, in: 1...30, step: 1) {
                    HStack {
                        Text("Raporlama Aralığı")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(primaryText)
                        Spacer()
                        Text("\(reportIntervalMinutes) dk")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }

                Stepper(value: $sleepIntervalHours, in: 1...24, step: 1) {
                    HStack {
                        Text("Uyku Kontrol Aralığı")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(primaryText)
                        Spacer()
                        Text("\(sleepIntervalHours) saat")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }

                Toggle(isOn: $lowBatteryWarning) {
                    settingLabel("Düşük Batarya Uyarısı", subtitle: "Cihaz bataryası kritik seviyeye inerse bildir")
                }
                .tint(AppTheme.idle)
            }

            Section {
                Button {
                    if !vehicle.ignition && vehicle.status != .ignitionOn {
                        showKontakWarning = true
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Ayarları Kaydet")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(pageBackground.ignoresSafeArea())
        .listStyle(.insetGrouped)
        .navigationTitle("Araç Ayarları")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Geri")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(primaryText)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: overspeedEnabled)
        .animation(.easeInOut(duration: 0.25), value: idleAlertEnabled)
        .task {
            await loadIgnitionNotificationPreferences()
        }
        .alert("Kontak Kapalı", isPresented: $showKontakWarning) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Ayarları uygulamak için araçtan yeniden canlı veri alınması gerekebilir. Kontak açıldığında değişiklikler daha güvenilir çalışır.")
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(accent)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(primaryText)
        }
    }

    private func settingLabel(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(primaryText)
            Text(subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(secondaryText)
        }
    }

    private var ignitionTargetScope: String {
        vehicle.assignmentId != nil ? "assignment" : "device"
    }

    private var ignitionTargetId: Int? {
        if let assignmentId = vehicle.assignmentId, assignmentId > 0 { return assignmentId }
        return vehicle.deviceId > 0 ? vehicle.deviceId : nil
    }

    private var selectedIgnitionChannels: Set<String> {
        var channels = Set<String>()
        if ignitionPushEnabled { channels.insert("push") }
        if ignitionSmsEnabled { channels.insert("sms") }
        if ignitionMailEnabled { channels.insert("email") }
        return channels
    }

    private var hasAnyIgnitionNotificationEnabled: Bool {
        ignitionOnNotificationEnabled || ignitionOffNotificationEnabled
    }

    private func setIgnitionNotificationEnabled(_ alarmType: String, enabled: Bool) {
        switch alarmType {
        case "ignition_on":
            ignitionOnNotificationEnabled = enabled
        case "ignition_off":
            ignitionOffNotificationEnabled = enabled
        default:
            break
        }

        if enabled && selectedIgnitionChannels.isEmpty {
            ignitionPushEnabled = true
        }

        scheduleIgnitionSyncIfReady()
    }

    private func setIgnitionChannel(_ channel: String, enabled: Bool) {
        var channels = selectedIgnitionChannels

        if enabled {
            channels.insert(channel)
        } else {
            channels.remove(channel)
            if channels.isEmpty && hasAnyIgnitionNotificationEnabled {
                ignitionSettingsMessage = "En az bir teslimat kanalı açık kalmalı."
                channels.insert(channel)
            } else {
                ignitionSettingsMessage = nil
            }
        }

        ignitionPushEnabled = channels.contains("push")
        ignitionSmsEnabled = channels.contains("sms")
        ignitionMailEnabled = channels.contains("email")
        scheduleIgnitionSyncIfReady()
    }

    private func scheduleIgnitionSyncIfReady() {
        guard ignitionSettingsLoaded else { return }
        Task {
            await syncIgnitionNotificationPreferences()
        }
    }

    @MainActor
    private func loadIgnitionNotificationPreferences() async {
        guard let userId = try? await resolveCurrentUserId() else {
            ignitionSettingsLoaded = true
            ignitionSettingsMessage = "Kullanıcı bilgisi alınamadı."
            return
        }

        guard let targetId = ignitionTargetId else {
            ignitionSettingsLoaded = true
            ignitionSettingsMessage = "Bu araç için bildirim hedefi hazır değil."
            return
        }

        ignitionSettingsSyncing = true
        ignitionSettingsMessage = nil

        do {
            let sets = try await fetchHiddenIgnitionRules(userId: userId, targetId: targetId)
            let activeSets = sets.filter { $0.isActive && $0.status == "active" }
            let channelUnion = Set((activeSets.isEmpty ? sets : activeSets).flatMap(\.channelList))

            ignitionOnNotificationEnabled = activeSets.contains { $0.alarmType == "ignition_on" }
            ignitionOffNotificationEnabled = activeSets.contains { $0.alarmType == "ignition_off" }
            ignitionPushEnabled = channelUnion.contains("push") || channelUnion.isEmpty
            ignitionSmsEnabled = channelUnion.contains("sms")
            ignitionMailEnabled = channelUnion.contains("email")
            ignitionSettingsLoaded = true
            ignitionSettingsMessage = nil
        } catch {
            ignitionSettingsLoaded = true
            ignitionSettingsMessage = error.localizedDescription
        }

        ignitionSettingsSyncing = false
    }

    @MainActor
    private func syncIgnitionNotificationPreferences() async {
        guard let userId = try? await resolveCurrentUserId() else {
            ignitionSettingsMessage = "Kullanıcı bilgisi alınamadı."
            return
        }

        guard let targetId = ignitionTargetId else {
            ignitionSettingsMessage = "Bu araç için bildirim hedefi hazır değil."
            return
        }

        if hasAnyIgnitionNotificationEnabled && selectedIgnitionChannels.isEmpty {
            ignitionPushEnabled = true
        }

        ignitionSettingsSyncing = true
        ignitionSettingsMessage = nil

        do {
            let channelList = Array(selectedIgnitionChannels).sorted()
            let enabledByType = [
                "ignition_on": ignitionOnNotificationEnabled,
                "ignition_off": ignitionOffNotificationEnabled,
            ]
            let existingSets = try await fetchHiddenIgnitionRules(userId: userId, targetId: targetId)
            let grouped = Dictionary(grouping: existingSets, by: \.alarmType)

            for (type, isEnabled) in enabledByType {
                let matches = (grouped[type] ?? []).sorted { $0.id > $1.id }
                let primary = matches.first
                let duplicates = matches.dropFirst()

                for duplicate in duplicates {
                    _ = try? await APIService.shared.post("/api/mobile/alarm-sets/\(duplicate.id)/archive")
                }

                if isEnabled {
                    let body = hiddenIgnitionAlarmBody(
                        name: hiddenIgnitionAlarmName(type: type, userId: userId, targetId: targetId),
                        userId: userId,
                        targetId: targetId,
                        type: type,
                        channels: channelList
                    )

                    if let primary {
                        _ = try await APIService.shared.put("/api/mobile/alarm-sets/\(primary.id)", body: body)
                    } else {
                        _ = try await APIService.shared.post("/api/mobile/alarm-sets/", body: body)
                    }
                } else if let primary, primary.status == "active" || primary.isActive {
                    _ = try await APIService.shared.post("/api/mobile/alarm-sets/\(primary.id)/pause")
                }
            }

            ignitionSettingsMessage = hasAnyIgnitionNotificationEnabled
                ? "Kontak bildirimleri güncellendi."
                : "Kontak bildirimleri kapatıldı."
        } catch {
            ignitionSettingsMessage = error.localizedDescription
        }

        ignitionSettingsSyncing = false
    }

    private func resolveCurrentUserId() async throws -> Int {
        if let id = Int(authVM.currentUser?.id ?? "") {
            return id
        }

        let me = try await APIService.shared.fetchMe()
        await MainActor.run {
            authVM.currentUser = me
        }

        guard let id = Int(me.id) else {
            throw APIError.decodingError("Kullanıcı kimliği çözümlenemedi")
        }

        return id
    }

    private func fetchHiddenIgnitionRules(userId: Int, targetId: Int) async throws -> [AlarmSet] {
        let searchKey = "\(vehicleSettingsHiddenIgnitionPrefix)u\(userId)__\(ignitionTargetScope)_\(targetId)__"
        let json = try await APIService.shared.get("/api/mobile/alarm-sets/?search=\(searchKey)")
        let data = json["data"] as? [[String: Any]] ?? []
        return data
            .map { AlarmSet.from(json: $0) }
            .filter { $0.name.hasPrefix(searchKey) }
    }

    private func hiddenIgnitionAlarmName(type: String, userId: Int, targetId: Int) -> String {
        "\(vehicleSettingsHiddenIgnitionPrefix)u\(userId)__\(ignitionTargetScope)_\(targetId)__\(type)"
    }

    private func hiddenIgnitionAlarmBody(
        name: String,
        userId: Int,
        targetId: Int,
        type: String,
        channels: [String]
    ) -> [String: Any] {
        [
            "name": name,
            "description": "mobile_private_ignition_notification",
            "alarm_type": type,
            "status": "active",
            "evaluation_mode": "live",
            "source_mode": "derived",
            "cooldown_sec": 0,
            "is_active": true,
            "condition_require_ignition": true,
            "targets": [
                [
                    "scope": ignitionTargetScope,
                    "id": targetId,
                ],
            ],
            "channels": channels,
            "recipient_ids": [userId],
        ]
    }
}
