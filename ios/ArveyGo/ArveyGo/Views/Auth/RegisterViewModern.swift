import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
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
                                Text("Giriş Yap")
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
                        eyebrow: "YENI HESAP",
                        title: "Yeni kullanıcı hesabını hızlıca oluştur",
                        subtitle: "Kurumsal erişim için temel bilgileri tamamlayın.",
                        chips: []
                    )
                    .padding(.horizontal, 20)

                    VStack(spacing: 18) {
                        AuthNeoPanel {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Yeni Hesap Oluştur")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(AppTheme.authNightText)
                                        Text("Kurumsal kullanım için kullanıcı bilgilerini tamamlayın")
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

                                AuthNeoField(label: "Ad Soyad", icon: "person", isFocused: focusedField == .name) {
                                    TextField("", text: $authVM.registerName, prompt: authPrompt("Adınız Soyadınız"))
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(AppTheme.authNightText)
                                        .tint(.white)
                                        .focused($focusedField, equals: .name)
                                }
                                .padding(.bottom, 14)

                                AuthNeoField(label: "E-posta", icon: "envelope", isFocused: focusedField == .email) {
                                    TextField("", text: $authVM.registerEmail, prompt: authPrompt("ornek@email.com"))
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

                                AuthNeoField(label: "Şifre", icon: "lock", isFocused: focusedField == .password) {
                                    SecureField("", text: $authVM.registerPassword, prompt: authPrompt("En az 8 karakter"))
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(AppTheme.authNightText)
                                        .tint(.white)
                                        .focused($focusedField, equals: .password)
                                }
                                .padding(.bottom, 14)

                                AuthNeoField(label: "Şifre Tekrar", icon: "lock.shield", isFocused: focusedField == .confirm) {
                                    SecureField("", text: $authVM.registerPasswordConfirm, prompt: authPrompt("Şifrenizi tekrar girin"))
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
                                            Text("Kayıt Ol")
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                    }
                                }
                                .buttonStyle(ArveyButtonStyle())
                                .disabled(authVM.isLoading)
                                .padding(.bottom, 16)

                                AuthNeoDivider(title: "veya")
                                    .padding(.bottom, 16)

                                Button(action: { dismiss() }) {
                                    HStack(spacing: 4) {
                                        Text("Zaten hesabınız var mı?")
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundStyle(AppTheme.authNightTextMuted)
                                        Text("Giriş Yap")
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
