import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            // Background
            AppTheme.bg.ignoresSafeArea()

            // Decorative background circles
            GeometryReader { geo in
                Circle()
                    .fill(AppTheme.navy.opacity(0.03))
                    .frame(width: 400, height: 400)
                    .offset(x: -100, y: -150)

                Circle()
                    .fill(AppTheme.indigo.opacity(0.04))
                    .frame(width: 300, height: 300)
                    .offset(x: geo.size.width - 100, y: geo.size.height - 200)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Language Switcher
                    HStack {
                        Spacer()
                        LanguageSwitcher()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                    // Logo
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppTheme.navy)
                                .frame(width: 52, height: 52)

                            Image(systemName: "location.north.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 2) {
                            Text("ArveyGo")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(AppTheme.navy)

                            Text("ARAÇ TAKİP SİSTEMİ")
                                .font(.system(size: 9, weight: .medium))
                                .tracking(2)
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    .padding(.bottom, 24)

                    // Login Card
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tekrar Hoş Geldiniz")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppTheme.navy)

                            Text("Hesabınıza giriş yapın")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 28)

                        // Error message
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

                        // Email Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("E-posta")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)

                            HStack(spacing: 12) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(width: 20)

                                TextField("ornek@email.com", text: $authVM.loginEmail)
                                    .font(.system(size: 14))
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .focused($focusedField, equals: .email)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(AppTheme.bg)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedField == .email ? AppTheme.navy : AppTheme.borderSoft, lineWidth: focusedField == .email ? 1.5 : 1)
                            )
                        }
                        .padding(.bottom, 16)

                        // Password Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Şifre")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)

                            HStack(spacing: 12) {
                                Image(systemName: "lock")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(width: 20)

                                SecureField("••••••••", text: $authVM.loginPassword)
                                    .font(.system(size: 14))
                                    .textContentType(.password)
                                    .focused($focusedField, equals: .password)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(AppTheme.bg)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedField == .password ? AppTheme.navy : AppTheme.borderSoft, lineWidth: focusedField == .password ? 1.5 : 1)
                            )
                        }
                        .padding(.bottom, 12)

                        // Forgot Password
                        HStack {
                            Spacer()
                            NavigationLink(destination: ForgotPasswordView()) {
                                Text("Şifremi Unuttum")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.indigo)
                            }
                        }
                        .padding(.bottom, 24)

                        // Login Button
                        Button(action: { authVM.login() }) {
                            HStack(spacing: 8) {
                                if authVM.isLoading {
                                    LoadingSpinner()
                                } else {
                                    Text("Giriş Yap")
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                        }
                        .buttonStyle(ArveyButtonStyle())
                        .disabled(authVM.isLoading)
                        .padding(.bottom, 20)

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(AppTheme.borderSoft)
                                .frame(height: 1)
                            Text("veya")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textFaint)
                            Rectangle()
                                .fill(AppTheme.borderSoft)
                                .frame(height: 1)
                        }
                        .padding(.bottom, 20)

                        // Register Link
                        NavigationLink(destination: RegisterView()) {
                            HStack(spacing: 4) {
                                Text("Hesabınız yok mu?")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textMuted)
                                Text("Kayıt Ol")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.navy)
                            }
                        }
                    }
                    .padding(22)
                    .background(AppTheme.surface)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.navy.opacity(0.06), radius: 16, y: 6)
                    .padding(.horizontal, 16)

                    // Footer
                    VStack(spacing: 4) {
                        Text("© 2026 Arveya Teknoloji")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textFaint)
                        Text("v1.0.0")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.textFaint.opacity(0.6))
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onTapGesture { focusedField = nil }
        .onAppear { authVM.clearLoginFields() }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
