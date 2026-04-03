import SwiftUI

struct RegisterViewBackup: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    enum Field { case name, email, password, confirm }

    var body: some View {
        ZStack {
            AppTheme.panelGradient.ignoresSafeArea()

            // Decorative
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 350, height: 350)
                    .offset(x: geo.size.width - 80, y: -100)
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 250, height: 250)
                    .offset(x: -80, y: geo.size.height - 150)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Back button
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Giriş Yap")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(Color.white.opacity(0.86))
                        }
                        Spacer()
                        LanguageSwitcher()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                    // Logo
                    VStack(spacing: 8) {
                        Image("LoginLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
                    }
                    .padding(.bottom, 18)

                    // Register Card
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Yeni Hesap Oluştur")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppTheme.authTextPrimary)
                            Text("Bilgilerinizi girerek kayıt olun")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.authTextMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 24)

                        // Error
                        if let error = authVM.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14))
                                Text(error)
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding(12)
                            .background(Color.red.opacity(0.06))
                            .cornerRadius(10)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Name
                        formField(label: "Ad Soyad", icon: "person", placeholder: "Adınız Soyadınız", text: $authVM.registerName, field: .name)
                            .padding(.bottom, 14)

                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                                Text("E-posta")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.authTextSecondary)

                            HStack(spacing: 12) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.authTextMuted)
                                    .frame(width: 20)
                                TextField("ornek@email.com", text: $authVM.registerEmail)
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.authTextPrimary)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .tint(AppTheme.navy)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .focused($focusedField, equals: .email)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(AppTheme.authField)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedField == .email ? AppTheme.navy : AppTheme.authBorder, lineWidth: focusedField == .email ? 1.5 : 1)
                            )
                        }
                        .padding(.bottom, 14)

                        // Password
                        secureField(label: "Şifre", placeholder: "En az 8 karakter", text: $authVM.registerPassword, field: .password)
                            .padding(.bottom, 14)

                        // Confirm Password
                        secureField(label: "Şifre Tekrar", placeholder: "Şifrenizi tekrar girin", text: $authVM.registerPasswordConfirm, field: .confirm)
                            .padding(.bottom, 24)

                        // Register Button
                        Button(action: { authVM.register() }) {
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

                        // Login Link
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Text("Zaten hesabınız var mı?")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.authTextMuted)
                                Text("Giriş Yap")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.authTextPrimary)
                            }
                        }
                    }
                    .padding(22)
                    .background(AppTheme.authSurface)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppTheme.authBorder, lineWidth: 1)
                    )
                    .shadow(color: AppTheme.authShadow, radius: 20, x: 0, y: 12)
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 20)
                }
            }
        }
        .tint(AppTheme.navy)
        .navigationBarHidden(true)
        .onTapGesture { focusedField = nil }
        .onAppear { authVM.clearRegisterFields() }
    }

    // MARK: - Form Field Helper
    @ViewBuilder
    func formField(label: String, icon: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.authTextSecondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.authTextMuted)
                    .frame(width: 20)
                TextField(placeholder, text: text)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.authTextPrimary)
                    .tint(AppTheme.navy)
                    .focused($focusedField, equals: field)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(AppTheme.authField)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == field ? AppTheme.navy : AppTheme.authBorder, lineWidth: focusedField == field ? 1.5 : 1)
            )
        }
    }

    @ViewBuilder
    func secureField(label: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.authTextSecondary)

            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.authTextMuted)
                    .frame(width: 20)
                SecureField(placeholder, text: text)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.authTextPrimary)
                    .tint(AppTheme.navy)
                    .focused($focusedField, equals: field)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(AppTheme.authField)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == field ? AppTheme.navy : AppTheme.authBorder, lineWidth: focusedField == field ? 1.5 : 1)
            )
        }
    }
}

#Preview {
    NavigationStack {
        RegisterViewBackup()
            .environmentObject(AuthViewModel())
    }
}
