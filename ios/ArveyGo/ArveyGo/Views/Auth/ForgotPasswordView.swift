import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var L = LoginStrings.shared
    @FocusState private var emailFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.panelGradient.ignoresSafeArea()

            // Decorative
            GeometryReader { _ in
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 400, height: 400)
                    .offset(x: -120, y: -180)
                Circle()
                    .fill(Color.white.opacity(0.05))
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
                            Text(L.loginButton)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(Color.white.opacity(0.86))
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
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 64, height: 64)
                        Image(systemName: "key.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
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

                            Text(L.t("Bağlantı Gönderildi!", "Link Sent!", "Enlace enviado", "Lien envoyé"))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.authTextPrimary)

                            Text(L.t("Şifre sıfırlama bağlantısı **\(authVM.forgotEmail)** adresine gönderildi.", "Password reset link sent to **\(authVM.forgotEmail)**.", "El enlace para restablecer la contraseña se envió a **\(authVM.forgotEmail)**.", "Le lien de réinitialisation a été envoyé à **\(authVM.forgotEmail)**."))
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.authTextMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)

                            Button(action: { dismiss() }) {
                                Text(L.t("Giriş Sayfasına Dön", "Return to Login", "Volver al inicio de sesión", "Retour à la connexion"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.authAccent)
                            }
                            .padding(.top, 8)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L.forgotPassword)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppTheme.authTextPrimary)
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text(L.t("E-posta adresinize şifre sıfırlama bağlantısı göndereceğiz", "We'll send a password reset link to your email address", "Enviaremos un enlace de restablecimiento a tu correo electrónico", "Nous enverrons un lien de réinitialisation à votre adresse e-mail"))
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.authTextMuted)
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
                            Text(L.emailLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.authTextSecondary)

                            HStack(spacing: 12) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.authTextMuted)
                                    .frame(width: 20)
                                TextField(L.emailPlaceholder, text: $authVM.forgotEmail)
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.authTextPrimary)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .tint(AppTheme.navy)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .focused($emailFocused)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(AppTheme.authField)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(emailFocused ? AppTheme.navy : AppTheme.authBorder, lineWidth: emailFocused ? 1.5 : 1)
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
                                    Text(L.t("Sıfırlama Bağlantısı Gönder", "Send Reset Link", "Enviar enlace de restablecimiento", "Envoyer le lien"))
                                }
                            }
                        }
                        .buttonStyle(ArveyButtonStyle())
                        .disabled(authVM.isLoading)
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

                Spacer()

                // Footer
                VStack(spacing: 4) {
                    Text(L.copyright)
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.68))
                }
                .padding(.bottom, 30)
            }
        }
        .tint(AppTheme.navy)
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
