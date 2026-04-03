import SwiftUI

struct SupportRequestView: View {
    enum PresentationMode {
        case push
        case modal
    }

    enum SupportCategory: String, CaseIterable, Codable, Identifiable {
        case connection = "Bağlantı"
        case device = "Cihaz"
        case software = "Yazılım"
        case billing = "Fatura"
        case integration = "Entegrasyon"
        case other = "Diğer"

        var id: String { rawValue }

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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var store = SupportCenterStore()
    @State private var expandedFAQIDs: Set<String> = ["ownership"]
    @State private var selectedCategory: SupportCategory = .connection
    @State private var subject = ""
    @State private var description = ""
    @State private var contactEmail = ""
    @State private var contactPhone = ""
    @State private var activeThread: SupportCenterThread?
    @State private var isSubmitted = false

    let presentationMode: PresentationMode

    init(presentationMode: PresentationMode = .push) {
        self.presentationMode = presentationMode
    }

    private static let faqItems: [SupportFAQItem] = [
        SupportFAQItem(
            id: "ownership",
            question: "Donanım mülkiyeti kime aittir ve cihaz seçimi neden kritiktir?",
            answer: "ArveyGo'da satın alınan cihaz sizin mülkiyetinizde kalır. Cihaz kalitesi; GPS doğruluğunu, sinyal kararlılığını ve kilometre hesaplamalarının güvenilirliğini doğrudan etkiler."
        ),
        SupportFAQItem(
            id: "compatibility",
            question: "İstediğim marka/model cihazı kullanabilir miyim?",
            answer: "Platform açık protokol mimarisiyle çalışır. Uyumlu cihazlar teknik ekip tarafından kontrol edilerek mevcut filoya entegre edilebilir."
        ),
        SupportFAQItem(
            id: "subscription",
            question: "Aylık hizmet bedeli neleri kapsar?",
            answer: "SIM kart ve veri, yazılım lisansı, bulut altyapısı, harita servisi ve teknik destek aylık hizmet kapsamındadır."
        ),
        SupportFAQItem(
            id: "security",
            question: "Veri güvenliği nasıl sağlanır?",
            answer: "Veriler SSL/TLS ile aktarılır, KVKK ve GDPR prensiplerine uygun şekilde saklanır. Erişim ve saklama politikaları şirket ihtiyaçlarına göre yönetilebilir."
        ),
        SupportFAQItem(
            id: "canbus",
            question: "Standart takip ile CAN Bus okuma arasındaki fark nedir?",
            answer: "Standart takip konum, hız ve rota bilgisini sağlar. CAN Bus ise yakıt seviyesi, RPM, sıcaklık, gerçek kilometre ve arıza kodları gibi aracın iç verilerine erişim sunar."
        )
    ]

    private var isDark: Bool { colorScheme == .dark }
    private var pageBackground: Color {
        isDark ? Color(red: 12/255, green: 17/255, blue: 36/255) : Color(UIColor.systemGroupedBackground)
    }
    private var navigationBackground: Color {
        isDark ? Color(red: 15/255, green: 21/255, blue: 42/255) : Color(UIColor.systemBackground)
    }
    private var surface: Color {
        isDark ? Color(red: 23/255, green: 29/255, blue: 54/255) : .white
    }
    private var elevatedSurface: Color {
        isDark ? Color(red: 29/255, green: 37/255, blue: 66/255) : Color(UIColor.secondarySystemGroupedBackground)
    }
    private var primaryText: Color {
        isDark ? AppTheme.darkText : AppTheme.textPrimary
    }
    private var secondaryText: Color {
        isDark ? AppTheme.darkTextSub : AppTheme.textSecondary
    }
    private var mutedText: Color {
        isDark ? AppTheme.darkTextMuted : AppTheme.textMuted
    }
    private var borderColor: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }
    private var shadowColor: Color {
        isDark ? Color.black.opacity(0.26) : Color.black.opacity(0.06)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                supportHeroCard
                faqSection
                createRequestSection
                conversationsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(presentationMode == .modal)
        .toolbarBackground(navigationBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        .toolbar {
            if presentationMode == .modal {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(primaryText)
                            .frame(width: 34, height: 34)
                            .background(surface, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(borderColor, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Kapat")
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Destek Merkezi")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryText)
                    Text("SSS, talepler ve görüşmeler")
                        .font(.system(size: 10))
                        .foregroundStyle(mutedText)
                }
            }
        }
        .sheet(item: $activeThread) { thread in
            NavigationStack {
                SupportConversationView(store: store, threadID: thread.id)
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Talep oluşturuldu", isPresented: $isSubmitted) {
            Button("Tamam") {
                clearForm()
            }
        } message: {
            Text("Destek talebin görüşmelerine eklendi. İstersen aynı ekrandan yeni mesaj da gönderebilirsin.")
        }
    }

    private var supportHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.indigo.opacity(0.16))
                        .frame(width: 52, height: 52)

                    Image(systemName: "questionmark.bubble.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.indigo)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Destek akışını tek yerden yönet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(primaryText)

                    Text("Sık sorulan soruları incele, yeni bir talep oluştur veya geçmiş yazışmalarına dön.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                supportStat(title: "Açık Talep", value: "\(store.openCount)", tint: AppTheme.online)
                supportStat(title: "Yanıt Bekleyen", value: "\(store.pendingReplyCount)", tint: AppTheme.idle)
                supportStat(title: "Toplam", value: "\(store.threads.count)", tint: AppTheme.indigo)
            }

            Button(action: reconnectSocket) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Bağlantıyı Yeniden Dene")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(AppTheme.indigo)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(18)
        .background(surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 12, x: 0, y: 6)
    }

    private func supportStat(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(mutedText)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "SSS", subtitle: "En sık sorulan başlıklar")

            ForEach(Self.faqItems) { item in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedFAQIDs.contains(item.id) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedFAQIDs.insert(item.id)
                            } else {
                                expandedFAQIDs.remove(item.id)
                            }
                        }
                    )
                ) {
                    Text(item.answer)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(secondaryText)
                        .padding(.top, 6)
                } label: {
                    Text(item.question)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(primaryText)
                }
                .tint(AppTheme.indigo)
                .padding(16)
                .background(surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
            }
        }
    }

    private var createRequestSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Talep Oluştur", subtitle: "Yeni görüşme başlat")

            supportTextField(
                title: "Konu",
                placeholder: "Örn: Cihaz bağlantısı kararsız çalışıyor",
                text: $subject,
                keyboard: .default
            )

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Kategori")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(SupportCategory.allCases) { category in
                        Button(action: { selectedCategory = category }) {
                            VStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(category.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(selectedCategory == category ? AppTheme.indigo : secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedCategory == category ? AppTheme.indigo.opacity(0.12) : elevatedSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selectedCategory == category ? AppTheme.indigo : borderColor, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Detay")
                TextEditor(text: $description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(primaryText)
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
            }

            HStack(spacing: 10) {
                supportTextField(
                    title: "E-Posta",
                    placeholder: "ornek@email.com",
                    text: $contactEmail,
                    keyboard: .emailAddress
                )
                supportTextField(
                    title: "Telefon",
                    placeholder: "+90 5XX XXX XX XX",
                    text: $contactPhone,
                    keyboard: .phonePad
                )
            }

            Button(action: submitTicket) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Talebi Gönder")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isFormValid ? AppTheme.navy : secondaryText.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(!isFormValid)
        }
        .padding(18)
        .background(surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var conversationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Görüşmelerim", subtitle: "Geçmiş talepler ve mesajlar")

            if store.threads.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(mutedText)
                    Text("Henüz destek görüşmesi yok")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(primaryText)
                    Text("Yeni bir talep gönderdiğinde görüşme geçmişin burada görünecek.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(22)
                .background(surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
            } else {
                ForEach(store.threads) { thread in
                    Button(action: { activeThread = thread }) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 10) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(thread.status.tint.opacity(0.14))
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Image(systemName: thread.category.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(thread.status.tint)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(thread.subject)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(primaryText)
                                        .lineLimit(2)
                                    Text(thread.latestMessagePreview)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(secondaryText)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 10)

                                VStack(alignment: .trailing, spacing: 8) {
                                    Text(thread.status.label)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(thread.status.tint)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(thread.status.tint.opacity(0.12), in: Capsule())

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(mutedText)
                                }
                            }

                            HStack(spacing: 10) {
                                threadMetaPill(icon: "calendar", text: thread.updatedAt.formattedSupportDate)
                                threadMetaPill(icon: "bubble.left", text: "\(thread.messages.count) mesaj")
                            }
                        }
                        .padding(16)
                        .background(surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(borderColor, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(primaryText)
            Text(subtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(secondaryText)
    }

    private func supportTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(title)
            TextField(placeholder, text: text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(primaryText)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
    }

    private func threadMetaPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(elevatedSurface, in: Capsule())
    }

    private var isFormValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !contactEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitTicket() {
        guard isFormValid else { return }
        let thread = store.createThread(
            category: selectedCategory,
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            message: description.trimmingCharacters(in: .whitespacesAndNewlines),
            contactEmail: contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            contactPhone: contactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        activeThread = thread
        isSubmitted = true
    }

    private func clearForm() {
        selectedCategory = .connection
        subject = ""
        description = ""
        contactEmail = ""
        contactPhone = ""
    }

    private func reconnectSocket() {
        WebSocketManager.shared.reconnect()
    }
}

private struct SupportConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: SupportCenterStore
    let threadID: UUID

    @State private var replyText = ""

    private var isDark: Bool { colorScheme == .dark }
    private var pageBackground: Color {
        isDark ? Color(red: 12/255, green: 17/255, blue: 36/255) : Color(UIColor.systemGroupedBackground)
    }
    private var surface: Color {
        isDark ? Color(red: 23/255, green: 29/255, blue: 54/255) : .white
    }
    private var primaryText: Color {
        isDark ? AppTheme.darkText : AppTheme.textPrimary
    }
    private var secondaryText: Color {
        isDark ? AppTheme.darkTextSub : AppTheme.textSecondary
    }
    private var borderColor: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    private var thread: SupportCenterThread? {
        store.thread(id: threadID)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if let thread {
                        ForEach(thread.messages) { message in
                            messageBubble(message)
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            HStack(spacing: 10) {
                TextField("Mesaj yaz...", text: $replyText, axis: .vertical)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )

                Button(action: sendReply) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? secondaryText : AppTheme.indigo)
                }
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .background(pageBackground)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle(thread?.subject ?? "Görüşme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Kapat") {
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
            }
        }
    }

    private func messageBubble(_ message: SupportCenterMessage) -> some View {
        HStack {
            if message.sender == .support {
                bubbleContent(message, alignLeading: true)
                Spacer(minLength: 36)
            } else {
                Spacer(minLength: 36)
                bubbleContent(message, alignLeading: false)
            }
        }
    }

    private func bubbleContent(_ message: SupportCenterMessage, alignLeading: Bool) -> some View {
        VStack(alignment: alignLeading ? .leading : .trailing, spacing: 6) {
            Text(message.sender == .support ? "Destek Ekibi" : "Siz")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryText)

            Text(message.text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(primaryText)
                .multilineTextAlignment(alignLeading ? .leading : .trailing)

            Text(message.sentAt.formattedSupportDateTime)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(secondaryText)
        }
        .padding(14)
        .background(
            (message.sender == .support ? surface : AppTheme.indigo.opacity(0.14)),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private func sendReply() {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addReply(trimmed, to: threadID)
        replyText = ""
    }
}

private struct SupportFAQItem: Identifiable {
    let id: String
    let question: String
    let answer: String
}

private struct SupportCenterThread: Identifiable, Codable, Equatable {
    enum Status: String, Codable {
        case open
        case waiting
        case answered

        var label: String {
            switch self {
            case .open: return "Açık"
            case .waiting: return "Yanıt Bekliyor"
            case .answered: return "Yanıtlandı"
            }
        }

        var tint: Color {
            switch self {
            case .open: return AppTheme.online
            case .waiting: return AppTheme.idle
            case .answered: return AppTheme.indigo
            }
        }
    }

    let id: UUID
    var category: SupportRequestView.SupportCategory
    var subject: String
    var contactEmail: String
    var contactPhone: String
    var status: Status
    var updatedAt: Date
    var messages: [SupportCenterMessage]

    var latestMessagePreview: String {
        messages.last?.text ?? "Henüz mesaj yok"
    }
}

private struct SupportCenterMessage: Identifiable, Codable, Equatable {
    enum Sender: String, Codable {
        case user
        case support
    }

    let id: UUID
    let sender: Sender
    let text: String
    let sentAt: Date
}

private final class SupportCenterStore: ObservableObject {
    @Published private(set) var threads: [SupportCenterThread] = []

    private let storageKey = "arveygo.support.center.threads"

    init() {
        load()
    }

    var openCount: Int {
        threads.filter { $0.status == .open }.count
    }

    var pendingReplyCount: Int {
        threads.filter { $0.status == .waiting }.count
    }

    func thread(id: UUID) -> SupportCenterThread? {
        threads.first(where: { $0.id == id })
    }

    func createThread(
        category: SupportRequestView.SupportCategory,
        subject: String,
        message: String,
        contactEmail: String,
        contactPhone: String
    ) -> SupportCenterThread {
        let now = Date()
        let thread = SupportCenterThread(
            id: UUID(),
            category: category,
            subject: subject,
            contactEmail: contactEmail,
            contactPhone: contactPhone,
            status: .waiting,
            updatedAt: now,
            messages: [
                SupportCenterMessage(id: UUID(), sender: .user, text: message, sentAt: now),
                SupportCenterMessage(id: UUID(), sender: .support, text: "Talebini aldık. Ekip ilk incelemeyi başlattı.", sentAt: now.addingTimeInterval(120))
            ]
        )
        threads.insert(thread, at: 0)
        persist()
        return thread
    }

    func addReply(_ text: String, to threadID: UUID) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        let now = Date()
        threads[index].messages.append(
            SupportCenterMessage(id: UUID(), sender: .user, text: text, sentAt: now)
        )
        threads[index].status = .waiting
        threads[index].updatedAt = now
        sortThreads()
        persist()
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([SupportCenterThread].self, from: data)
        else {
            threads = Self.seedThreads
            return
        }
        threads = decoded.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    private func persist() {
        sortThreads()
        guard let data = try? JSONEncoder().encode(threads) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func sortThreads() {
        threads.sort(by: { $0.updatedAt > $1.updatedAt })
    }

    private static let seedThreads: [SupportCenterThread] = [
        SupportCenterThread(
            id: UUID(),
            category: .device,
            subject: "Kepez şube cihazı aralıklı veri gönderiyor",
            contactEmail: "demo@arveygo.com",
            contactPhone: "+90 530 000 00 00",
            status: .answered,
            updatedAt: Date().addingTimeInterval(-7200),
            messages: [
                SupportCenterMessage(id: UUID(), sender: .user, text: "Araç bazen 15-20 dakika veri göndermiyor gibi görünüyor.", sentAt: Date().addingTimeInterval(-10800)),
                SupportCenterMessage(id: UUID(), sender: .support, text: "İlk kontrolde cihaz son paket aralığında düzensizlik gördük. SIM ve güç hattı kontrolü öneriyoruz.", sentAt: Date().addingTimeInterval(-7200))
            ]
        ),
        SupportCenterThread(
            id: UUID(),
            category: .software,
            subject: "Rapor ekranında tarih aralığı kaydedilmiyor",
            contactEmail: "demo@arveygo.com",
            contactPhone: "+90 530 000 00 00",
            status: .open,
            updatedAt: Date().addingTimeInterval(-86400),
            messages: [
                SupportCenterMessage(id: UUID(), sender: .user, text: "Mesafe raporunda tarih seçimi bir sonraki girişte sıfırlanıyor.", sentAt: Date().addingTimeInterval(-90000)),
                SupportCenterMessage(id: UUID(), sender: .support, text: "Sorunu ürün ekibine ilettik, geçici çözüm üzerinde çalışıyoruz.", sentAt: Date().addingTimeInterval(-86400))
            ]
        )
    ]
}

private extension Date {
    var formattedSupportDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: self)
    }

    var formattedSupportDateTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: self)
    }
}

#Preview {
    NavigationStack {
        SupportRequestView()
    }
}
