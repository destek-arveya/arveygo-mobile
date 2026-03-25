import SwiftUI

/// Login page localization strings – TR/EN/ES/FR
class LoginStrings: ObservableObject {
    static let shared = LoginStrings()

    @Published var currentLang: String = "TR"

    var appTitle: String { "ArveyGo" }
    var appSubtitle: String { s("ARAÇ TAKİP SİSTEMİ", "VEHICLE TRACKING SYSTEM", "SISTEMA DE RASTREO", "SYSTÈME DE SUIVI") }

    var welcomeBack: String { s("Tekrar Hoş Geldiniz", "Welcome Back", "Bienvenido", "Bienvenue") }
    var loginSubtitle: String { s("Hesabınıza giriş yapın", "Sign in to your account", "Inicia sesión en tu cuenta", "Connectez-vous à votre compte") }

    var emailTab: String { s("E-posta", "Email", "Correo", "E-mail") }
    var phoneTab: String { s("Telefon", "Phone", "Teléfono", "Téléphone") }

    var emailLabel: String { s("E-posta", "Email", "Correo electrónico", "E-mail") }
    var emailPlaceholder: String { s("ornek@email.com", "example@email.com", "ejemplo@email.com", "exemple@email.com") }
    var passwordLabel: String { s("Şifre", "Password", "Contraseña", "Mot de passe") }
    var passwordPlaceholder: String { "••••••••" }

    var phoneLabel: String { s("Telefon Numarası", "Phone Number", "Número de Teléfono", "Numéro de Téléphone") }
    var phonePlaceholder: String { "+90 5XX XXX XX XX" }
    var sendOtp: String { s("Kod Gönder", "Send Code", "Enviar Código", "Envoyer le Code") }
    var otpLabel: String { s("Doğrulama Kodu", "Verification Code", "Código de Verificación", "Code de Vérification") }
    var otpPlaceholder: String { s("6 haneli kod", "6-digit code", "Código de 6 dígitos", "Code à 6 chiffres") }
    var otpSent: String { s("Doğrulama kodu gönderildi", "Verification code sent", "Código enviado", "Code envoyé") }
    var otpInvalid: String { s("Doğrulama kodu hatalı", "Invalid verification code", "Código inválido", "Code invalide") }
    var phoneRequired: String { s("Telefon numarası gerekli", "Phone number is required", "Se requiere teléfono", "Numéro requis") }
    var otpRequired: String { s("Doğrulama kodu gerekli", "Verification code is required", "Se requiere código", "Code requis") }
    var resendCode: String { s("Kodu Tekrar Gönder", "Resend Code", "Reenviar Código", "Renvoyer le Code") }
    var resendCooldown: String { s("Tekrar gönder", "Resend in", "Reenviar en", "Renvoyer dans") }
    var otpStep2Title: String { s("Doğrulama", "Verification", "Verificación", "Vérification") }
    var otpStep2Subtitle: String { s("Telefonunuza gönderilen 6 haneli kodu girin", "Enter the 6-digit code sent to your phone", "Ingrese el código enviado a su teléfono", "Entrez le code envoyé à votre téléphone") }

    var rememberMe: String { s("Beni Hatırla", "Remember Me", "Recuérdame", "Se souvenir de moi") }

    var forgotPassword: String { s("Şifremi Unuttum", "Forgot Password", "Olvidé mi Contraseña", "Mot de passe oublié") }
    var loginButton: String { s("Giriş Yap", "Sign In", "Iniciar Sesión", "Se connecter") }
    var orDivider: String { s("veya", "or", "o", "ou") }
    var noAccount: String { s("Hesabınız yok mu?", "Don't have an account?", "¿No tienes cuenta?", "Pas de compte ?") }
    var register: String { s("Kayıt Ol", "Sign Up", "Registrarse", "S'inscrire") }

    var emailRequired: String { s("E-posta adresi gerekli", "Email is required", "Correo requerido", "E-mail requis") }
    var emailInvalid: String { s("Geçerli bir e-posta girin", "Enter a valid email", "Ingrese un correo válido", "Entrez un e-mail valide") }
    var passwordRequired: String { s("Şifre gerekli", "Password is required", "Contraseña requerida", "Mot de passe requis") }
    var loginFailed: String { s("E-posta veya şifre hatalı", "Invalid email or password", "Correo o contraseña inválidos", "E-mail ou mot de passe invalide") }

    var copyright: String { "© 2026 Arveya Teknoloji" }
    var version: String { "v1.0.0" }

    private func s(_ tr: String, _ en: String, _ es: String, _ fr: String) -> String {
        switch currentLang {
        case "EN": return en
        case "ES": return es
        case "FR": return fr
        default: return tr
        }
    }
}
