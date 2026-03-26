import SwiftUI

struct MotorcycleSettingsView: View {
    let vehicle: Vehicle
    @Environment(\.dismiss) private var dismiss

    // Notification toggles
    @State private var kontakOnNotification = true
    @State private var kontakOffNotification = true
    @State private var batteryRemovedNotification = true
    @State private var batteryInstalledNotification = true
    @State private var motionDetectedNotification = true

    // Phone call settings
    @State private var motionDetectedPhoneCall = false
    @State private var phoneNumber = ""

    // Sleep/wake settings
    @State private var sleepDelaySeconds = "30"
    @State private var wakeIntervalHours = "6"

    // Alarm settings
    @State private var alarmEnabled = false
    @State private var alarmDurationSeconds: Double = 30

    // Kontak warning
    @State private var showKontakWarning = false

    var body: some View {
        List {
            // Vehicle info header
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.online.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "bicycle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppTheme.online)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(vehicle.plate)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.navy)
                        Text(vehicle.model)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                    StatusBadge(status: vehicle.status)
                }
                .padding(.vertical, 4)
            }

            // Kontak Bildirimleri
            Section(header: sectionHeader("Kontak Bildirimleri", icon: "key.fill")) {
                Toggle(isOn: $kontakOnNotification) {
                    settingLabel("Kontak Açılma Bildirimi", subtitle: "Kontak açıldığında bildirim al")
                }
                .tint(AppTheme.online)

                Toggle(isOn: $kontakOffNotification) {
                    settingLabel("Kontak Kapanma Bildirimi", subtitle: "Kontak kapandığında bildirim al")
                }
                .tint(AppTheme.online)
            }

            // Akü Bildirimleri
            Section(header: sectionHeader("Akü Bildirimleri", icon: "battery.100.bolt")) {
                Toggle(isOn: $batteryRemovedNotification) {
                    settingLabel("Aküden Söküldü Bildirimi", subtitle: "Cihaz aküden sökülünce bildirim al")
                }
                .tint(AppTheme.online)

                Toggle(isOn: $batteryInstalledNotification) {
                    settingLabel("Aküye Takıldı Bildirimi", subtitle: "Cihaz aküye takılınca bildirim al")
                }
                .tint(AppTheme.online)
            }

            // Hareket Algılama
            Section(header: sectionHeader("Hareket Algılama", icon: "figure.walk.motion")) {
                Toggle(isOn: $motionDetectedNotification) {
                    settingLabel("Hareket Algılandı Bildirimi", subtitle: "Araç hareket edince bildirim al")
                }
                .tint(AppTheme.online)

                Toggle(isOn: $motionDetectedPhoneCall) {
                    settingLabel("Hareket Algılandı Telefon Araması", subtitle: "Araç hareket edince telefon ile ara")
                }
                .tint(AppTheme.online)

                if motionDetectedPhoneCall {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(AppTheme.online)
                            .frame(width: 24)
                        TextField("Telefon Numarası", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textFieldStyle(.roundedBorder)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Alarm Kur
            Section(header: sectionHeader("Alarm", icon: "speaker.wave.3.fill")) {
                Toggle(isOn: $alarmEnabled) {
                    settingLabel("Alarm Kur", subtitle: "Motosiklete uzaktan alarm gönder")
                }
                .tint(.red)

                if alarmEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Alarm Süresi")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.navy)
                            Spacer()
                            Text("\(Int(alarmDurationSeconds)) saniye")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                        }

                        Slider(value: $alarmDurationSeconds, in: 5...60, step: 5)
                            .tint(.red)

                        HStack {
                            Text("5 sn")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                            Spacer()
                            Text("60 sn")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Uyku Zamanlama
            Section(header: sectionHeader("Cihaz Uyku Ayarları", icon: "moon.zzz.fill")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kontak kapandıktan sonra uyku süresi")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.navy)
                        Text("Kontak kapandıktan kaç saniye sonra uyusun")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        TextField("30", text: $sleepDelaySeconds)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        Text("sn")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uyanma periyodu")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.navy)
                        Text("Uykudan kaç saatte bir uyanıp veri atsın")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        TextField("6", text: $wakeIntervalHours)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                        Text("saat")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }

            // Save button
            Section {
                Button(action: {
                    if !vehicle.ignition {
                        showKontakWarning = true
                    } else {
                        // TODO: Save settings to backend
                        dismiss()
                    }
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Ayarları Kaydet")
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .background(AppTheme.online)
                    .cornerRadius(10)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Motosiklet Ayarları")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Geri")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.navy)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: motionDetectedPhoneCall)
        .animation(.easeInOut(duration: 0.25), value: alarmEnabled)
        .alert("Kontak Kapalı", isPresented: $showKontakWarning) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Ayarları kaydetmek için aracın kontağının açık olması gerekmektedir. Lütfen önce kontağı açın.")
        }
    }

    // MARK: - Helpers
    func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.online)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.navy)
        }
    }

    func settingLabel(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.navy)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textMuted)
        }
    }
}
