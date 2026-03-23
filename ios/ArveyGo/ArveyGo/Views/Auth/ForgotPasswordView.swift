import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var emailFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            // Decorative
            GeometryReader { _ in
                Circle()
                    .fill(AppTheme.navy.opacity(0.03))
                    .frame(width: 400, height: 400)
                    .offset(x: -120, y: -180)
                Circle()
                    .fill(AppTheme.indigo.opacity(0.04))
                    .frame(width: 300, height: 300)
                    .offset(x: 200, y: 500)
            }

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Giriş Yap")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                    LanguageSwitcher()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // Card
                VStack(spacing: 0) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.navy.opacity(0.06))
                            .frame(width: 64, height: 64)
                        Image(systemName: "key.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.navy)
                    }
                    .padding(.bottom, 20)

                    if authVM.resetSent {
                        // Success state
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.online.opacity(0.1))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(AppTheme.online)
                            }

                            Text("Bağlantı Gönderildi!")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.navy)

                            Text("Şifre sıfırlama bağlantısı **\(authVM.forgotEmail)** adresine gönderildi.")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)

                            Button(action: { dismiss() }) {
                                Text("Giriş Sayfasına Dön")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.indigo)
                            }
                            .padding(.top, 8)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Şifremi Unuttum")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppTheme.navy)
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text("E-posta adresinize şifre sıfırlama bağlantısı göndereceğiz")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.bottom, 24)

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
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("E-posta")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)

                            HStack(spacing: 12) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(width: 20)
                                TextField("ornek@email.com", text: $authVM.forgotEmail)
                                    .font(.system(size: 14))
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .focused($emailFocused)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(AppTheme.bg)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(emailFocused ? AppTheme.navy : AppTheme.borderSoft, lineWidth: emailFocused ? 1.5 : 1)
                            )
                        }
                        .padding(.bottom, 24)

                        Button(action: { authVM.sendResetLink() }) {
                            HStack(spacing: 8) {
                                if authVM.isLoading {
                                    LoadingSpinner()
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 13))
                                    Text("Sıfırlama Bağlantısı Gönder")
                                }
                            }
                        }
                        .buttonStyle(ArveyButtonStyle())
                        .disabled(authVM.isLoading)
                    }
                }
                .padding(22)
                .background(AppTheme.surface)
                .cornerRadius(16)
                .shadow(color: AppTheme.navy.opacity(0.06), radius: 16, y: 6)
                .padding(.horizontal, 16)

                Spacer()

                // Footer
                VStack(spacing: 4) {
                    Text("© 2026 Arveya Teknoloji")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textFaint)
                }
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .onTapGesture { emailFocused = false }
        .onAppear { authVM.clearForgotFields() }
        .animation(.easeInOut(duration: 0.3), value: authVM.resetSent)
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
            .environmentObject(AuthViewModel())
    }
}
