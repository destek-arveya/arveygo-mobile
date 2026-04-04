import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var L = LoginStrings.shared
    @FocusState private var focusedField: Field?

    enum Field { case name, email, password, confirm }

    var body: some View {
        ZStack {
            AuthNeoBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(L.loginButton)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.authNightTextSecondary)
                        }

                        Spacer()
                        LanguageSwitcher()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                    AuthNeoHero(
                        eyebrow: L.t("YENI HESAP", "NEW ACCOUNT", "NUEVA CUENTA", "NOUVEAU COMPTE"),
                        title: L.t("Yeni kullanıcı hesabını hızlıca oluştur", "Create your new user account quickly", "Crea tu nueva cuenta rápidamente", "Créez rapidement votre nouveau compte"),
                        subtitle: L.t("Kurumsal erişim için temel bilgileri tamamlayın.", "Complete the core details for enterprise access.", "Completa los datos principales para el acceso corporativo.", "Complétez les informations essentielles pour l'accès professionnel."),
                        chips: []
                    )
                    .padding(.horizontal, 20)

                    VStack(spacing: 18) {
                        AuthNeoPanel {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(L.t("Yeni Hesap Oluştur", "Create New Account", "Crear Cuenta Nueva", "Créer un compte"))
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(AppTheme.authNightText)
                                        Text(L.t("Kurumsal kullanım için kullanıcı bilgilerini tamamlayın", "Complete user details for enterprise use", "Completa los datos del usuario para uso corporativo", "Complétez les informations utilisateur pour l'usage professionnel"))
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundStyle(AppTheme.authNightTextSecondary)
                                    }
                                    Spacer()
                                    Image("LoginLogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 54, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .padding(.bottom, 18)

                                if let error = authVM.errorMessage {
                                    authErrorBanner(error)
                                        .padding(.bottom, 16)
                                }

                                AuthNeoField(label: L.t("Ad Soyad", "Full Name", "Nombre completo", "Nom complet"), icon: "person", isFocused: focusedField == .name) {
                                    TextField("", text: $authVM.registerName, prompt: authPrompt(L.t("Adınız Soyadınız", "Your full name", "Tu nombre completo", "Votre nom complet")))
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(AppTheme.authNightText)
                                        .tint(.white)
                                        .focused($focusedField, equals: .name)
                                }
                                .padding(.bottom, 14)

                                AuthNeoField(label: L.emailLabel, icon: "envelope", isFocused: focusedField == .email) {
                                    TextField("", text: $authVM.registerEmail, prompt: authPrompt(L.emailPlaceholder))
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(AppTheme.authNightText)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .disableAutocorrection(true)
                                        .tint(.white)
                                        .focused($focusedField, equals: .email)
                                }
                                .padding(.bottom, 14)

                                AuthNeoField(label: L.passwordLabel, icon: "lock", isFocused: focusedField == .password) {
                                    SecureField("", text: $authVM.registerPassword, prompt: authPrompt(L.t("En az 8 karakter", "At least 8 characters", "Al menos 8 caracteres", "Au moins 8 caractères")))
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(AppTheme.authNightText)
                                        .tint(.white)
                                        .focused($focusedField, equals: .password)
                                }
                                .padding(.bottom, 14)

                                AuthNeoField(label: L.t("Şifre Tekrar", "Confirm Password", "Confirmar contraseña", "Confirmer le mot de passe"), icon: "lock.shield", isFocused: focusedField == .confirm) {
                                    SecureField("", text: $authVM.registerPasswordConfirm, prompt: authPrompt(L.t("Şifrenizi tekrar girin", "Enter your password again", "Ingresa tu contraseña nuevamente", "Saisissez à nouveau votre mot de passe")))
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(AppTheme.authNightText)
                                        .tint(.white)
                                        .focused($focusedField, equals: .confirm)
                                }
                                .padding(.bottom, 20)

                                Button(action: {
                                    focusedField = nil
                                    authVM.register()
                                }) {
                                    HStack(spacing: 8) {
                                        if authVM.isLoading {
                                            LoadingSpinner()
                                        } else {
                                            Text(L.register)
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                    }
                                }
                                .buttonStyle(ArveyButtonStyle())
                                .disabled(authVM.isLoading)
                                .padding(.bottom, 16)

                                AuthNeoDivider(title: L.orDivider)
                                    .padding(.bottom, 16)

                                Button(action: { dismiss() }) {
                                    HStack(spacing: 4) {
                                        Text(L.noAccount)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundStyle(AppTheme.authNightTextMuted)
                                        Text(L.loginButton)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(AppTheme.authNightText)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 26)
                    .padding(.bottom, 24)
                }
            }
        }
        .tint(.white)
        .navigationBarHidden(true)
        .onTapGesture { focusedField = nil }
        .onAppear { authVM.clearRegisterFields() }
    }

    private func authErrorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.system(size: 12, weight: .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(Color.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.32), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}
