import SwiftUI

// MARK: - Blockage Sheet
/// Araç blokaj gönderme / iptal modal'ı
struct BlockageSheet: View {
    let vehicle: Vehicle
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    @Binding var successMessage: String?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedAction: BlockageAction = .block
    @State private var showConfirm = false

    enum BlockageAction: String, CaseIterable {
        case block   = "block"
        case unblock = "unblock"

        var label: String {
            self == .block ? "Blokaj Uygula" : "Blokajı Kaldır"
        }
        var icon: String {
            self == .block ? "lock.shield.fill" : "lock.open.fill"
        }
        var color: Color {
            self == .block ? .red : .green
        }
        var description: String {
            self == .block
                ? "Bu komut aracın motorunu uzaktan kilitler. Araç durduğunda devreye girer."
                : "Bu komut aracın blokunun kaldırılmasını sağlar. Araç tekrar çalışabilir hale gelir."
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Araç Bilgisi ──
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(AppTheme.navy).opacity(0.08))
                            .frame(width: 52, height: 52)
                        Image(systemName: "car.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(AppTheme.navy))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(vehicle.plate)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.navy)
                        Text(vehicle.model.isEmpty ? "Bilinmiyor" : vehicle.model)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                    // Mevcut durum badge
                    VStack(spacing: 2) {
                        Circle()
                            .fill(vehicle.status.color)
                            .frame(width: 10, height: 10)
                        Text(vehicle.status.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(vehicle.status.color)
                    }
                }
                .padding(20)
                .background(Color(.systemGroupedBackground))

                Divider()

                ScrollView {
                    VStack(spacing: 20) {

                        // ── Aksiyon Seçici ──
                        VStack(alignment: .leading, spacing: 12) {
                            Text("KOMUT SEÇ")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.textMuted)
                                .tracking(0.5)

                            HStack(spacing: 10) {
                                ForEach(BlockageAction.allCases, id: \.self) { action in
                                    actionCard(action)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // ── Açıklama ──
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(selectedAction.color.opacity(0.8))
                                .font(.system(size: 18))
                            Text(selectedAction.description)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(selectedAction.color.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedAction.color.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal, 20)

                        // ── Hata / Başarı Mesajı ──
                        if let err = errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                Text(err).font(.subheadline).foregroundColor(.red)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                        }

                        if let ok = successMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text(ok).font(.subheadline).foregroundColor(.green)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                        }

                        // ── Gönder Butonu ──
                        Button {
                            showConfirm = true
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: selectedAction.icon)
                                        Text(selectedAction.label)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(selectedAction.color)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .disabled(isLoading || successMessage != nil)
                        .padding(.horizontal, 20)

                        // ── İptal Butonu ──
                        Button {
                            Task { await cancelBlockage() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 13))
                                Text("Bekleyen Komutu İptal Et")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(AppTheme.textMuted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Blokaj Komutu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(AppTheme.navy)
                }
            }
            .confirmationDialog(
                selectedAction == .block
                    ? "Blokaj uygulamak istediğinize emin misiniz?"
                    : "Blokajı kaldırmak istediğinize emin misiniz?",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button(selectedAction.label, role: selectedAction == .block ? .destructive : nil) {
                    Task { await sendBlockage() }
                }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Bu komut \(vehicle.plate) plakalı araca gönderilecek.")
            }
        }
    }

    // MARK: - Action Card
    private func actionCard(_ action: BlockageAction) -> some View {
        Button { selectedAction = action } label: {
            VStack(spacing: 10) {
                Image(systemName: action.icon)
                    .font(.system(size: 24))
                    .foregroundColor(selectedAction == action ? action.color : AppTheme.textMuted)
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selectedAction == action ? action.color.opacity(0.12) : Color(.secondarySystemBackground))
                    )
                Text(action.label)
                    .font(.system(size: 12, weight: selectedAction == action ? .semibold : .regular))
                    .foregroundColor(selectedAction == action ? action.color : AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedAction == action ? action.color.opacity(0.05) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selectedAction == action ? action.color.opacity(0.4) : Color(.separator), lineWidth: selectedAction == action ? 1.5 : 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - API Calls
    private func sendBlockage() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            _ = try await APIService.shared.sendBlockage(deviceId: vehicle.deviceId, action: selectedAction.rawValue)
            successMessage = selectedAction == .block
                ? "✅ Blokaj komutu gönderildi. Araç durduğunda devreye girecek."
                : "✅ Blokaj kaldırma komutu gönderildi."
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func cancelBlockage() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            try await APIService.shared.cancelBlockage(deviceId: vehicle.deviceId)
            successMessage = "✅ Bekleyen blokaj komutu iptal edildi."
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
