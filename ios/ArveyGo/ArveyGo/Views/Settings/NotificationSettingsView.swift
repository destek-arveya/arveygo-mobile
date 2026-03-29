import SwiftUI
import UserNotifications

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @StateObject private var vm = NotificationSettingsVM()

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // ── Push Permission Status ──
                    pushStatusCard

                    // ── Bildirim Kategorileri ──
                    categorySection

                    // ── Sessiz Saatler ──
                    quietHoursSection

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Bildirim Ayarları")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.checkPermission() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            vm.checkPermission()
        }
    }

    // MARK: - Push Permission Card
    private var pushStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "bell.badge.fill", title: "PUSH BİLDİRİM")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(vm.isAuthorized ? Color(hex: "#16A34A") : Color(hex: "#DC2626"))
                            .frame(width: 36, height: 36)
                        Image(systemName: vm.isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.isAuthorized ? "Bildirimler Açık" : "Bildirimler Kapalı")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                        Text(vm.isAuthorized
                             ? "Araç alarmları ve hatırlatmalar alabilirsiniz"
                             : "Bildirimleri alabilmek için izin verin")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }

                    Spacer()

                    if vm.isAuthorized {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "#16A34A"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if !vm.isAuthorized {
                    Divider().padding(.leading, 60)

                    Button(action: { vm.requestOrOpenSettings() }) {
                        HStack(spacing: 8) {
                            Image(systemName: vm.isDenied ? "gear" : "bell.and.waves.left.and.right")
                                .font(.system(size: 13))
                            Text(vm.isDenied ? "Ayarları Aç" : "İzin Ver")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AppTheme.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(AppTheme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(vm.isAuthorized ? Color(hex: "#16A34A").opacity(0.3) : AppTheme.borderSoft, lineWidth: 1)
            )
        }
    }

    // MARK: - Category Toggles
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "slider.horizontal.3", title: "BİLDİRİM KATEGORİLERİ")

            VStack(spacing: 0) {
                notificationToggleRow(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: Color(hex: "#EF4444"),
                    title: "Araç Alarmları",
                    subtitle: "Hız, geofence, motor vb.",
                    binding: $vm.alarmNotifications
                )

                Divider().padding(.leading, 60)

                notificationToggleRow(
                    icon: "wrench.and.screwdriver.fill",
                    iconColor: Color(hex: "#F59E0B"),
                    title: "Bakım Hatırlatmaları",
                    subtitle: "Servis, muayene, belge tarihleri",
                    binding: $vm.maintenanceNotifications
                )

                Divider().padding(.leading, 60)

                notificationToggleRow(
                    icon: "location.fill",
                    iconColor: AppTheme.indigo,
                    title: "Geofence Bildirimleri",
                    subtitle: "Bölge giriş/çıkış uyarıları",
                    binding: $vm.geofenceNotifications
                )

                Divider().padding(.leading, 60)

                notificationToggleRow(
                    icon: "megaphone.fill",
                    iconColor: Color(hex: "#8B5CF6"),
                    title: "Sistem Duyuruları",
                    subtitle: "Güncelleme ve bilgilendirmeler",
                    binding: $vm.systemNotifications
                )
            }
            .background(AppTheme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.borderSoft, lineWidth: 1)
            )

            Text("Bu ayarlar sunucu tarafında saklanır. Bildirimleri tamamen kapatmak için yukarıdaki Push izinini kapatın.")
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textMuted)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Quiet Hours
    private var quietHoursSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "moon.fill", title: "SESSİZ SAATLER")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#6366F1").opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.indigo)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sessiz Saatler")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.navy)
                        Text("Bu saatlerde bildirim gelmez")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }

                    Spacer()

                    Toggle("", isOn: $vm.quietHoursEnabled)
                        .labelsHidden()
                        .tint(AppTheme.indigo)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if vm.quietHoursEnabled {
                    Divider().padding(.leading, 60)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Başlangıç")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textMuted)
                            DatePicker("", selection: $vm.quietStart, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(AppTheme.indigo)
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bitiş")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textMuted)
                            DatePicker("", selection: $vm.quietEnd, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(AppTheme.indigo)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(AppTheme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.borderSoft, lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.indigo)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.textMuted)
                .tracking(1)
        }
    }

    private func notificationToggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        binding: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.navy)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }

            Spacer()

            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(AppTheme.indigo)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - ViewModel
@MainActor
class NotificationSettingsVM: ObservableObject {
    @Published var isAuthorized = false
    @Published var isDenied = false

    // Category preferences (persisted locally + synced to backend)
    @Published var alarmNotifications: Bool { didSet { save() } }
    @Published var maintenanceNotifications: Bool { didSet { save() } }
    @Published var geofenceNotifications: Bool { didSet { save() } }
    @Published var systemNotifications: Bool { didSet { save() } }

    // Quiet hours
    @Published var quietHoursEnabled: Bool { didSet { save() } }
    @Published var quietStart: Date { didSet { save() } }
    @Published var quietEnd: Date { didSet { save() } }

    private let defaults = UserDefaults.standard
    private let prefix = "notif_pref_"

    init() {
        // Load from UserDefaults (defaults to all ON)
        alarmNotifications = defaults.object(forKey: "\(prefix)alarm") as? Bool ?? true
        maintenanceNotifications = defaults.object(forKey: "\(prefix)maintenance") as? Bool ?? true
        geofenceNotifications = defaults.object(forKey: "\(prefix)geofence") as? Bool ?? true
        systemNotifications = defaults.object(forKey: "\(prefix)system") as? Bool ?? true
        quietHoursEnabled = defaults.bool(forKey: "\(prefix)quiet_enabled")

        // Default quiet hours: 23:00 - 07:00
        let cal = Calendar.current
        if let savedStart = defaults.object(forKey: "\(prefix)quiet_start") as? Date {
            quietStart = savedStart
        } else {
            quietStart = cal.date(from: DateComponents(hour: 23, minute: 0)) ?? Date()
        }
        if let savedEnd = defaults.object(forKey: "\(prefix)quiet_end") as? Date {
            quietEnd = savedEnd
        } else {
            quietEnd = cal.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        }
    }

    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
                self.isDenied = settings.authorizationStatus == .denied
            }
        }
    }

    func requestOrOpenSettings() {
        if isDenied {
            // Already denied — open iOS Settings
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } else {
            // First time — request permission
            AppDelegate.requestPushPermission()
            // Re-check after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkPermission()
            }
        }
    }

    private func save() {
        defaults.set(alarmNotifications, forKey: "\(prefix)alarm")
        defaults.set(maintenanceNotifications, forKey: "\(prefix)maintenance")
        defaults.set(geofenceNotifications, forKey: "\(prefix)geofence")
        defaults.set(systemNotifications, forKey: "\(prefix)system")
        defaults.set(quietHoursEnabled, forKey: "\(prefix)quiet_enabled")
        defaults.set(quietStart, forKey: "\(prefix)quiet_start")
        defaults.set(quietEnd, forKey: "\(prefix)quiet_end")

        // Sync to backend (fire & forget)
        Task {
            await syncPreferencesToBackend()
        }
    }

    private func syncPreferencesToBackend() async {
        let prefs: [String: Any] = [
            "alarm_notifications": alarmNotifications,
            "maintenance_notifications": maintenanceNotifications,
            "geofence_notifications": geofenceNotifications,
            "system_notifications": systemNotifications,
            "quiet_hours_enabled": quietHoursEnabled,
            "quiet_hours_start": formatTime(quietStart),
            "quiet_hours_end": formatTime(quietEnd)
        ]
        do {
            let _ = try await APIService.shared.post("/api/mobile/notification-settings", body: prefs)
            print("[NotifSettings] Synced to backend")
        } catch {
            print("[NotifSettings] Sync failed: \(error.localizedDescription)")
        }
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
