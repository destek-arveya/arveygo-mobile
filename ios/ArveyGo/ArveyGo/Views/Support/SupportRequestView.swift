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

        var localizedLabel: String {
            DashboardStrings.shared.t(
                self == .connection ? "Bağlantı" : self == .device ? "Cihaz" : self == .software ? "Yazılım" : self == .billing ? "Fatura" : self == .integration ? "Entegrasyon" : "Diğer",
                self == .connection ? "Connection" : self == .device ? "Device" : self == .software ? "Software" : self == .billing ? "Billing" : self == .integration ? "Integration" : "Other",
                self == .connection ? "Conexión" : self == .device ? "Dispositivo" : self == .software ? "Software" : self == .billing ? "Facturación" : self == .integration ? "Integración" : "Otro",
                self == .connection ? "Connexion" : self == .device ? "Appareil" : self == .software ? "Logiciel" : self == .billing ? "Facturation" : self == .integration ? "Intégration" : "Autre"
            )
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var DL = DashboardStrings.shared

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

    private var faqItems: [SupportFAQItem] {
        [
            SupportFAQItem(
                id: "ownership",
                question: DL.t("Donanım mülkiyeti kime aittir ve cihaz seçimi neden kritiktir?", "Who owns the hardware and why is device choice critical?", "¿Quién es el propietario del hardware y por qué es crítica la elección del dispositivo?", "À qui appartient le matériel et pourquoi le choix de l'appareil est-il crucial ?"),
                answer: DL.t("ArveyGo'da satın alınan cihaz sizin mülkiyetinizde kalır. Cihaz kalitesi; GPS doğruluğunu, sinyal kararlılığını ve kilometre hesaplamalarının güvenilirliğini doğrudan etkiler.", "In ArveyGo, purchased hardware remains your property. Device quality directly affects GPS accuracy, signal stability, and mileage reliability.", "En ArveyGo, el hardware comprado sigue siendo de tu propiedad. La calidad del dispositivo afecta directamente la precisión GPS, la estabilidad de la señal y la fiabilidad del kilometraje.", "Chez ArveyGo, le matériel acheté reste votre propriété. La qualité de l'appareil influence directement la précision GPS, la stabilité du signal et la fiabilité du kilométrage.")
            ),
            SupportFAQItem(
                id: "compatibility",
                question: DL.t("İstediğim marka/model cihazı kullanabilir miyim?", "Can I use any device brand/model?", "¿Puedo usar cualquier marca o modelo de dispositivo?", "Puis-je utiliser n'importe quelle marque ou modèle d'appareil ?"),
                answer: DL.t("Platform açık protokol mimarisiyle çalışır. Uyumlu cihazlar teknik ekip tarafından kontrol edilerek mevcut filoya entegre edilebilir.", "The platform works with an open protocol architecture. Compatible devices can be reviewed by the technical team and integrated into the existing fleet.", "La plataforma funciona con una arquitectura de protocolo abierto. Los dispositivos compatibles pueden ser revisados por el equipo técnico e integrados en la flota actual.", "La plateforme fonctionne avec une architecture à protocole ouvert. Les appareils compatibles peuvent être validés par l'équipe technique et intégrés à la flotte existante.")
            ),
            SupportFAQItem(
                id: "subscription",
                question: DL.t("Aylık hizmet bedeli neleri kapsar?", "What does the monthly service fee include?", "¿Qué incluye la tarifa mensual?", "Que couvre le service mensuel ?"),
                answer: DL.t("SIM kart ve veri, yazılım lisansı, bulut altyapısı, harita servisi ve teknik destek aylık hizmet kapsamındadır.", "The monthly service includes SIM/data, software licensing, cloud infrastructure, map service, and technical support.", "El servicio mensual incluye SIM/datos, licencia de software, infraestructura en la nube, servicio de mapas y soporte técnico.", "Le service mensuel inclut SIM/données, licence logicielle, infrastructure cloud, service cartographique et support technique.")
            ),
            SupportFAQItem(
                id: "security",
                question: DL.t("Veri güvenliği nasıl sağlanır?", "How is data security ensured?", "¿Cómo se garantiza la seguridad de los datos?", "Comment la sécurité des données est-elle assurée ?"),
                answer: DL.t("Veriler SSL/TLS ile aktarılır, KVKK ve GDPR prensiplerine uygun şekilde saklanır. Erişim ve saklama politikaları şirket ihtiyaçlarına göre yönetilebilir.", "Data is transferred over SSL/TLS and stored in line with KVKK and GDPR principles. Access and retention policies can be managed based on company needs.", "Los datos se transfieren con SSL/TLS y se almacenan conforme a los principios de KVKK y GDPR. Las políticas de acceso y retención pueden gestionarse según las necesidades de la empresa.", "Les données sont transférées via SSL/TLS et stockées conformément aux principes KVKK et RGPD. Les politiques d'accès et de conservation peuvent être gérées selon les besoins de l'entreprise.")
            ),
            SupportFAQItem(
                id: "canbus",
                question: DL.t("Standart takip ile CAN Bus okuma arasındaki fark nedir?", "What is the difference between standard tracking and CAN Bus reading?", "¿Cuál es la diferencia entre el rastreo estándar y la lectura CAN Bus?", "Quelle est la différence entre le suivi standard et la lecture CAN Bus ?"),
                answer: DL.t("Standart takip konum, hız ve rota bilgisini sağlar. CAN Bus ise yakıt seviyesi, RPM, sıcaklık, gerçek kilometre ve arıza kodları gibi aracın iç verilerine erişim sunar.", "Standard tracking provides location, speed, and route data. CAN Bus adds access to internal vehicle data such as fuel level, RPM, temperature, true mileage, and fault codes.", "El rastreo estándar proporciona ubicación, velocidad y ruta. CAN Bus añade acceso a datos internos del vehículo como nivel de combustible, RPM, temperatura, kilometraje real y códigos de fallo.", "Le suivi standard fournit la localisation, la vitesse et l'itinéraire. CAN Bus ajoute l'accès aux données internes du véhicule comme le niveau de carburant, le régime, la température, le kilométrage réel et les codes défaut.")
            )
        ]
    }

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
                    .accessibilityLabel(DL.t("Kapat", "Close", "Cerrar", "Fermer"))
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(DL.t("Destek Merkezi", "Support Center", "Centro de soporte", "Centre d'assistance"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryText)
                    Text(DL.t("SSS, talepler ve görüşmeler", "FAQs, requests, and conversations", "FAQ, solicitudes y conversaciones", "FAQ, demandes et conversations"))
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
        .alert(DL.t("Talep oluşturuldu", "Request created", "Solicitud creada", "Demande créée"), isPresented: $isSubmitted) {
            Button(DL.t("Tamam", "OK", "Aceptar", "OK")) {
                clearForm()
            }
        } message: {
            Text(DL.t("Destek talebin görüşmelerine eklendi. İstersen aynı ekrandan yeni mesaj da gönderebilirsin.", "Your support request was added to conversations. You can also send a new message from the same screen.", "Tu solicitud de soporte se añadió a las conversaciones. También puedes enviar un nuevo mensaje desde la misma pantalla.", "Votre demande a été ajoutée aux conversations. Vous pouvez aussi envoyer un nouveau message depuis ce même écran."))
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
                    Text(DL.t("Destek akışını tek yerden yönet", "Manage support from one place", "Gestiona el soporte desde un solo lugar", "Gérez l'assistance depuis un seul endroit"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(primaryText)

                    Text(DL.t("Sık sorulan soruları incele, yeni bir talep oluştur veya geçmiş yazışmalarına dön.", "Review FAQs, create a new request, or return to your previous conversations.", "Revisa las FAQ, crea una nueva solicitud o vuelve a tus conversaciones anteriores.", "Consultez la FAQ, créez une nouvelle demande ou revenez à vos conversations précédentes."))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                supportStat(title: DL.t("Açık Talep", "Open Requests", "Solicitudes abiertas", "Demandes ouvertes"), value: "\(store.openCount)", tint: AppTheme.online)
                supportStat(title: DL.t("Yanıt Bekleyen", "Waiting Reply", "Esperando respuesta", "En attente de réponse"), value: "\(store.pendingReplyCount)", tint: AppTheme.idle)
                supportStat(title: DL.t("Toplam", "Total", "Total", "Total"), value: "\(store.threads.count)", tint: AppTheme.indigo)
            }

            Button(action: reconnectSocket) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text(DL.t("Bağlantıyı Yeniden Dene", "Retry Connection", "Reintentar conexión", "Réessayer la connexion"))
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
            sectionHeader(title: DL.t("SSS", "FAQ", "FAQ", "FAQ"), subtitle: DL.t("En sık sorulan başlıklar", "Most frequently asked topics", "Temas más consultados", "Questions les plus fréquentes"))

            ForEach(faqItems) { item in
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
            sectionHeader(title: DL.t("Talep Oluştur", "Create Request", "Crear solicitud", "Créer une demande"), subtitle: DL.t("Yeni görüşme başlat", "Start a new conversation", "Inicia una nueva conversación", "Démarrer une nouvelle conversation"))

            supportTextField(
                title: DL.t("Konu", "Subject", "Asunto", "Sujet"),
                placeholder: DL.t("Örn: Cihaz bağlantısı kararsız çalışıyor", "Example: Device connection is unstable", "Ej.: la conexión del dispositivo es inestable", "Ex. : la connexion de l'appareil est instable"),
                text: $subject,
                keyboard: .default
            )

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel(DL.t("Kategori", "Category", "Categoría", "Catégorie"))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(SupportCategory.allCases) { category in
                        Button(action: { selectedCategory = category }) {
                            VStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(category.localizedLabel)
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
                fieldLabel(DL.t("Detay", "Details", "Detalles", "Détails"))
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
                    title: DL.t("E-Posta", "Email", "Correo", "E-mail"),
                    placeholder: "ornek@email.com",
                    text: $contactEmail,
                    keyboard: .emailAddress
                )
                supportTextField(
                    title: DL.t("Telefon", "Phone", "Teléfono", "Téléphone"),
                    placeholder: "+90 5XX XXX XX XX",
                    text: $contactPhone,
                    keyboard: .phonePad
                )
            }

            Button(action: submitTicket) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(DL.t("Talebi Gönder", "Send Request", "Enviar solicitud", "Envoyer la demande"))
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
            sectionHeader(title: DL.t("Görüşmelerim", "My Conversations", "Mis conversaciones", "Mes conversations"), subtitle: DL.t("Geçmiş talepler ve mesajlar", "Past requests and messages", "Solicitudes y mensajes anteriores", "Demandes et messages passés"))

            if store.threads.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(mutedText)
                    Text(DL.t("Henüz destek görüşmesi yok", "No support conversations yet", "Aún no hay conversaciones de soporte", "Aucune conversation d'assistance pour l'instant"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(primaryText)
                    Text(DL.t("Yeni bir talep gönderdiğinde görüşme geçmişin burada görünecek.", "When you send a new request, your conversation history will appear here.", "Cuando envíes una nueva solicitud, tu historial aparecerá aquí.", "Lorsque vous enverrez une nouvelle demande, votre historique apparaîtra ici."))
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
                                    Text(localizedSupportText(thread.latestMessagePreview))
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
                                threadMetaPill(icon: "bubble.left", text: DL.t("\(thread.messages.count) mesaj", "\(thread.messages.count) messages", "\(thread.messages.count) mensajes", "\(thread.messages.count) messages"))
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

    private func localizedSupportText(_ text: String) -> String {
        switch text {
        case "Kepez şube cihazı aralıklı veri gönderiyor":
            return DL.t("Kepez şube cihazı aralıklı veri gönderiyor", "Kepez branch device sends data intermittently", "El dispositivo de la sucursal de Kepez envía datos de forma intermitente", "L'appareil de l'agence Kepez envoie des données par intermittence")
        case "Araç bazen 15-20 dakika veri göndermiyor gibi görünüyor.":
            return DL.t("Araç bazen 15-20 dakika veri göndermiyor gibi görünüyor.", "The vehicle sometimes seems to stop sending data for 15-20 minutes.", "El vehículo a veces parece dejar de enviar datos durante 15-20 minutos.", "Le véhicule semble parfois cesser d'envoyer des données pendant 15 à 20 minutes.")
        case "İlk kontrolde cihaz son paket aralığında düzensizlik gördük. SIM ve güç hattı kontrolü öneriyoruz.":
            return DL.t("İlk kontrolde cihaz son paket aralığında düzensizlik gördük. SIM ve güç hattı kontrolü öneriyoruz.", "In the initial check we saw irregularity in the last packet interval. We recommend checking the SIM and power line.", "En la revisión inicial vimos irregularidades en el intervalo del último paquete. Recomendamos revisar la SIM y la línea de energía.", "Lors de la première vérification, nous avons constaté une irrégularité dans l'intervalle des derniers paquets. Nous recommandons de vérifier la SIM et l'alimentation.")
        case "Rapor ekranında tarih aralığı kaydedilmiyor":
            return DL.t("Rapor ekranında tarih aralığı kaydedilmiyor", "Date range is not saved on the report screen", "El rango de fechas no se guarda en la pantalla de informes", "L'intervalle de dates n'est pas enregistré sur l'écran des rapports")
        case "Mesafe raporunda tarih seçimi bir sonraki girişte sıfırlanıyor.":
            return DL.t("Mesafe raporunda tarih seçimi bir sonraki girişte sıfırlanıyor.", "The date selection in the distance report resets on the next visit.", "La selección de fecha del informe de distancia se restablece en la siguiente entrada.", "La sélection de date du rapport de distance se réinitialise lors de la prochaine visite.")
        case "Sorunu ürün ekibine ilettik, geçici çözüm üzerinde çalışıyoruz.":
            return DL.t("Sorunu ürün ekibine ilettik, geçici çözüm üzerinde çalışıyoruz.", "We forwarded the issue to the product team and are working on a temporary solution.", "Hemos trasladado el problema al equipo de producto y estamos trabajando en una solución temporal.", "Nous avons transmis le problème à l'équipe produit et travaillons sur une solution temporaire.")
        case "Talebini aldık. Ekip ilk incelemeyi başlattı.":
            return DL.t("Talebini aldık. Ekip ilk incelemeyi başlattı.", "We received your request. The team started the initial review.", "Recibimos tu solicitud. El equipo inició la revisión inicial.", "Nous avons reçu votre demande. L'équipe a lancé la première analyse.")
        default:
            return text
        }
    }
}

private struct SupportConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var DL = DashboardStrings.shared
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
                TextField(DL.t("Mesaj yaz...", "Write a message...", "Escribe un mensaje...", "Écrire un message..."), text: $replyText, axis: .vertical)
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
        .navigationTitle(thread?.subject ?? DL.t("Görüşme", "Conversation", "Conversación", "Conversation"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(DL.t("Kapat", "Close", "Cerrar", "Fermer")) {
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
            Text(message.sender == .support ? DL.t("Destek Ekibi", "Support Team", "Equipo de soporte", "Équipe support") : DL.t("Siz", "You", "Tú", "Vous"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryText)

            Text(localizedSupportText(message.text))
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

    private func localizedSupportText(_ text: String) -> String {
        switch text {
        case "Kepez şube cihazı aralıklı veri gönderiyor":
            return DL.t("Kepez şube cihazı aralıklı veri gönderiyor", "Kepez branch device sends data intermittently", "El dispositivo de la sucursal de Kepez envía datos de forma intermitente", "L'appareil de l'agence Kepez envoie des données par intermittence")
        case "Araç bazen 15-20 dakika veri göndermiyor gibi görünüyor.":
            return DL.t("Araç bazen 15-20 dakika veri göndermiyor gibi görünüyor.", "The vehicle sometimes seems to stop sending data for 15-20 minutes.", "El vehículo a veces parece dejar de enviar datos durante 15-20 minutos.", "Le véhicule semble parfois cesser d'envoyer des données pendant 15 à 20 minutes.")
        case "İlk kontrolde cihaz son paket aralığında düzensizlik gördük. SIM ve güç hattı kontrolü öneriyoruz.":
            return DL.t("İlk kontrolde cihaz son paket aralığında düzensizlik gördük. SIM ve güç hattı kontrolü öneriyoruz.", "In the initial check we saw irregularity in the last packet interval. We recommend checking the SIM and power line.", "En la revisión inicial vimos irregularidades en el intervalo del último paquete. Recomendamos revisar la SIM y la línea de energía.", "Lors de la première vérification, nous avons constaté une irrégularité dans l'intervalle des derniers paquets. Nous recommandons de vérifier la SIM et l'alimentation.")
        case "Rapor ekranında tarih aralığı kaydedilmiyor":
            return DL.t("Rapor ekranında tarih aralığı kaydedilmiyor", "Date range is not saved on the report screen", "El rango de fechas no se guarda en la pantalla de informes", "L'intervalle de dates n'est pas enregistré sur l'écran des rapports")
        case "Mesafe raporunda tarih seçimi bir sonraki girişte sıfırlanıyor.":
            return DL.t("Mesafe raporunda tarih seçimi bir sonraki girişte sıfırlanıyor.", "The date selection in the distance report resets on the next visit.", "La selección de fecha del informe de distancia se restablece en la siguiente entrada.", "La sélection de date du rapport de distance se réinitialise lors de la prochaine visite.")
        case "Sorunu ürün ekibine ilettik, geçici çözüm üzerinde çalışıyoruz.":
            return DL.t("Sorunu ürün ekibine ilettik, geçici çözüm üzerinde çalışıyoruz.", "We forwarded the issue to the product team and are working on a temporary solution.", "Hemos trasladado el problema al equipo de producto y estamos trabajando en una solución temporal.", "Nous avons transmis le problème à l'équipe produit et travaillons sur une solution temporaire.")
        case "Talebini aldık. Ekip ilk incelemeyi başlattı.":
            return DL.t("Talebini aldık. Ekip ilk incelemeyi başlattı.", "We received your request. The team started the initial review.", "Recibimos tu solicitud. El equipo inició la revisión inicial.", "Nous avons reçu votre demande. L'équipe a lancé la première analyse.")
        default:
            return text
        }
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
            case .open: return DashboardStrings.shared.t("Açık", "Open", "Abierto", "Ouvert")
            case .waiting: return DashboardStrings.shared.t("Yanıt Bekliyor", "Waiting Reply", "Esperando respuesta", "En attente de réponse")
            case .answered: return DashboardStrings.shared.t("Yanıtlandı", "Answered", "Respondido", "Répondu")
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
        messages.last?.text ?? DashboardStrings.shared.t("Henüz mesaj yok", "No messages yet", "Aún no hay mensajes", "Aucun message pour l'instant")
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
                SupportCenterMessage(id: UUID(), sender: .support, text: DashboardStrings.shared.t("Talebini aldık. Ekip ilk incelemeyi başlattı.", "We received your request. The team started the initial review.", "Recibimos tu solicitud. El equipo inició la revisión inicial.", "Nous avons reçu votre demande. L'équipe a lancé la première analyse."), sentAt: now.addingTimeInterval(120))
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
