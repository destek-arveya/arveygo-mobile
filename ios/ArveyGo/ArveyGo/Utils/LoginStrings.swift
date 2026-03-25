import SwiftUI

/// Login page localization strings – TR/EN
class LoginStrings: ObservableObject {
    static let shared = LoginStrings()

    @Published var currentLang: String = "TR"

    // ---------- Getters ----------

    var appTitle: String { s("ArveyGo", "ArveyGo") }
    var appSubtitle: String { s("ARAÇ TAKİP SİSTEMİ", "VEHICLE TRACKING SYSTEM") }

    var welcomeBack: String { s("Tekrar Hoş Geldiniz", "Welcome Back") }
    var loginSubtitle: String { s("Hesabınıza giriş yapın", "Sign in to your account") }

    // Tab titles
    var emailTab: String { s("E-posta", "Email") }
    var phoneTab: String { s("Telefon", "Phone") }

    // Email/Password
    var emailLabel: String { s("E-posta", "Email") }
    var emailPlaceholder: String { s("ornek@email.com", "example@email.com") }
    var passwordLabel: String { s("Şifre", "Password") }
    var passwordPlaceholder: String { s("••••••••", "••••••••") }

    // Phone/OTP
    var phoneLabel: String { s("Telefon Numarası", "Phone Number") }
    var phonePlaceholder: String { s("+90 5XX XXX XX XX", "+90 5XX XXX XX XX") }
    var sendOtp: String { s("Kod Gönder", "Send Code") }
    var otpLabel: String { s("Doğrulama Kodu", "Verification Code") }
    var otpPlaceholder: String { s("6 haneli kod", "6-digit code") }
    var otpSent: String { s("Doğrulama kodu gönderildi", "Verification code sent") }
    var otpInvalid: String { s("Doğrulama kodu hatalı", "Invalid verification code") }
    var phoneRequired: String { s("Telefon numarası gerekli", "Phone number is required") }
    var otpRequired: String { s("Doğrulama kodu gerekli", "Verification code is required") }
    var resendCode: String { s("Kodu Tekrar Gönder", "Resend Code") }
    var resendCooldown: String { s("Tekrar gönder", "Resend in") }
    var otpStep2Title: String { s("Doğrulama", "Verification") }
    var otpStep2Subtitle: String { s("Telefonunuza gönderilen 6 haneli kodu girin", "Enter the 6-digit code sent to your phone") }

    // Remember Me
    var rememberMe: String { s("Beni Hatırla", "Remember Me") }

    // Buttons & links
    var forgotPassword: String { s("Şifremi Unuttum", "Forgot Password") }
    var loginButton: String { s("Giriş Yap", "Sign In") }
    var orDivider: String { s("veya", "or") }
    var noAccount: String { s("Hesabınız yok mu?", "Don't have an account?") }
    var register: String { s("Kayıt Ol", "Sign Up") }

    // Validation
    var emailRequired: String { s("E-posta adresi gerekli", "Email address is required") }
    var emailInvalid: String { s("Geçerli bir e-posta adresi girin", "Enter a valid email address") }
    var passwordRequired: String { s("Şifre gerekli", "Password is required") }
    var loginFailed: String { s("E-posta veya şifre hatalı", "Invalid email or password") }

    // Footer
    var copyright: String { s("© 2026 Arveya Teknoloji", "© 2026 Arveya Teknoloji") }
    var version: String { s("v1.0.0", "v1.0.0") }

    // ---------- Helper ----------
    private func s(_ tr: String, _ en: String) -> String {
        currentLang == "TR" ? tr : en
    }
}
