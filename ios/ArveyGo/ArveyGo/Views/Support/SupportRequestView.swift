import SwiftUI

/// Support Request page — shown when WebSocket connection fails repeatedly.
/// Modeled after the web's integration request form (settings/index.blade.php).
struct SupportRequestView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: SupportCategory = .connection
    @State private var subject = ""
    @State private var description = ""
    @State private var contactEmail = ""
    @State private var contactPhone = ""
    @State private var isSubmitted = false

    enum SupportCategory: String, CaseIterable {
        case connection = "Bağlantı"
        case device = "Cihaz"
        case software = "Yazılım"
        case billing = "Fatura"
        case integration = "Entegrasyon"
        case other = "Diğer"

        var icon: String {
            switch self {
            case .connection: return "wifi.slash"
            case .device: return "cpu"
            case .software: return "laptopcomputer"
            case .billing: return "creditcard"
            case .integration: return "arrow.triangle.2.circlepath"
            case .other: return "ellipsis.circle"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Warning card
                        warningCard

                        // Category picker
                        categorySection

                        // Form
                        formSection

                        // Submit button
                        submitButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Destek Talebi")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.navy)
                        Text("Arveya Teknoloji")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }
            .alert("Talebiniz Alındı", isPresented: $isSubmitted) {
                Button("Tamam") { dismiss() }
            } message: {
                Text("Destek ekibimiz en kısa sürede sizinle iletişime geçecektir. Ortalama yanıt süresi 24-48 saattir.")
            }
        }
    }

    // MARK: - Warning Card
    var warningCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
            }

            Text("Bağlantı Sorunu")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppTheme.navy)

            Text("Sunucuya bağlantı kurulamadı. Lütfen internet bağlantınızı kontrol edin veya aşağıdaki formu doldurarak destek ekibimize ulaşın.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            // Retry button
            Button(action: {
                WebSocketManager.shared.reconnect()
                dismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Tekrar Dene")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(AppTheme.indigo)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(AppTheme.indigo.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Category Section
    var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DESTEK KATEGORİSİ")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.textMuted)
                .tracking(0.5)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(SupportCategory.allCases, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        VStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 16))
                            Text(category.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(selectedCategory == category ? AppTheme.navy : AppTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedCategory == category ? AppTheme.indigo.opacity(0.08) : AppTheme.surface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedCategory == category ? AppTheme.indigo : AppTheme.borderSoft, lineWidth: selectedCategory == category ? 1.5 : 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Form Section
    var formSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TALEP DETAYLARI")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.textMuted)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 4) {
                Text("Konu")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
                TextField("Örn: Soket bağlantısı kurulamıyor", text: $subject)
                    .font(.system(size: 13))
                    .padding(12)
                    .background(AppTheme.surface)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.borderSoft, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Detaylı Açıklama")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.navy)
                TextEditor(text: $description)
                    .font(.system(size: 13))
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(AppTheme.surface)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.borderSoft, lineWidth: 1)
                    )
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("E-Posta")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.navy)
                    TextField("ornek@email.com", text: $contactEmail)
                        .font(.system(size: 13))
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(12)
                        .background(AppTheme.surface)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppTheme.borderSoft, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Telefon")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.navy)
                    TextField("+90 5XX XXX XX XX", text: $contactPhone)
                        .font(.system(size: 13))
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .padding(12)
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

    // MARK: - Submit Button
    var submitButton: some View {
        Button(action: {
            guard !subject.isEmpty, !description.isEmpty, !contactEmail.isEmpty else { return }
            isSubmitted = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
                Text("Talebi Gönder")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                (subject.isEmpty || description.isEmpty || contactEmail.isEmpty)
                    ? AppTheme.textMuted
                    : AppTheme.navy
            )
            .cornerRadius(14)
        }
        .disabled(subject.isEmpty || description.isEmpty || contactEmail.isEmpty)
    }
}

#Preview {
    SupportRequestView()
}
