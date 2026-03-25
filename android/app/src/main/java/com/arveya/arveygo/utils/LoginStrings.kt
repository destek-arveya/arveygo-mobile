package com.arveya.arveygo.utils

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Login page localization strings – TR/EN/ES/FR
 */
object LoginStrings {
    private val _currentLang = MutableStateFlow("TR")
    val currentLang: StateFlow<String> = _currentLang

    fun setLanguage(lang: String) {
        _currentLang.value = lang
    }

    // ---------- Getters ----------

    val appTitle: String get() = "ArveyGo"
    val appSubtitle: String get() = s("ARAÇ TAKİP SİSTEMİ", "VEHICLE TRACKING SYSTEM", "SISTEMA DE RASTREO", "SYSTÈME DE SUIVI")

    val welcomeBack: String get() = s("Tekrar Hoş Geldiniz", "Welcome Back", "Bienvenido", "Bienvenue")
    val loginSubtitle: String get() = s("Hesabınıza giriş yapın", "Sign in to your account", "Inicia sesión en tu cuenta", "Connectez-vous à votre compte")

    // Tab titles
    val emailTab: String get() = s("E-posta", "Email", "Correo", "E-mail")
    val phoneTab: String get() = s("Telefon", "Phone", "Teléfono", "Téléphone")

    // Email/Password
    val emailLabel: String get() = s("E-posta", "Email", "Correo electrónico", "E-mail")
    val emailPlaceholder: String get() = s("ornek@email.com", "example@email.com", "ejemplo@email.com", "exemple@email.com")
    val passwordLabel: String get() = s("Şifre", "Password", "Contraseña", "Mot de passe")
    val passwordPlaceholder: String get() = "••••••••"

    // Phone/OTP
    val phoneLabel: String get() = s("Telefon Numarası", "Phone Number", "Número de Teléfono", "Numéro de Téléphone")
    val phonePlaceholder: String get() = "+90 5XX XXX XX XX"
    val sendOtp: String get() = s("Kod Gönder", "Send Code", "Enviar Código", "Envoyer le Code")
    val otpLabel: String get() = s("Doğrulama Kodu", "Verification Code", "Código de Verificación", "Code de Vérification")
    val otpPlaceholder: String get() = s("6 haneli kod", "6-digit code", "Código de 6 dígitos", "Code à 6 chiffres")
    val otpSent: String get() = s("Doğrulama kodu gönderildi", "Verification code sent", "Código enviado", "Code envoyé")
    val otpInvalid: String get() = s("Doğrulama kodu hatalı", "Invalid verification code", "Código inválido", "Code invalide")
    val phoneRequired: String get() = s("Telefon numarası gerekli", "Phone number is required", "Se requiere teléfono", "Numéro requis")
    val otpRequired: String get() = s("Doğrulama kodu gerekli", "Verification code is required", "Se requiere código", "Code requis")
    val resendCode: String get() = s("Kodu Tekrar Gönder", "Resend Code", "Reenviar Código", "Renvoyer le Code")
    val resendCooldown: String get() = s("Tekrar gönder", "Resend in", "Reenviar en", "Renvoyer dans")
    val otpStep2Title: String get() = s("Doğrulama", "Verification", "Verificación", "Vérification")
    val otpStep2Subtitle: String get() = s("Telefonunuza gönderilen 6 haneli kodu girin", "Enter the 6-digit code sent to your phone", "Ingrese el código enviado a su teléfono", "Entrez le code envoyé à votre téléphone")

    // Remember Me
    val rememberMe: String get() = s("Beni Hatırla", "Remember Me", "Recuérdame", "Se souvenir de moi")

    // Buttons & links
    val forgotPassword: String get() = s("Şifremi Unuttum", "Forgot Password", "Olvidé mi Contraseña", "Mot de passe oublié")
    val loginButton: String get() = s("Giriş Yap", "Sign In", "Iniciar Sesión", "Se connecter")
    val orDivider: String get() = s("veya", "or", "o", "ou")
    val noAccount: String get() = s("Hesabınız yok mu?", "Don't have an account?", "¿No tienes cuenta?", "Pas de compte ?")
    val register: String get() = s("Kayıt Ol", "Sign Up", "Registrarse", "S'inscrire")

    // Validation
    val emailRequired: String get() = s("E-posta adresi gerekli", "Email is required", "Correo requerido", "E-mail requis")
    val emailInvalid: String get() = s("Geçerli bir e-posta girin", "Enter a valid email", "Ingrese un correo válido", "Entrez un e-mail valide")
    val passwordRequired: String get() = s("Şifre gerekli", "Password is required", "Contraseña requerida", "Mot de passe requis")
    val loginFailed: String get() = s("E-posta veya şifre hatalı", "Invalid email or password", "Correo o contraseña inválidos", "E-mail ou mot de passe invalide")

    // Footer
    val copyright: String get() = "© 2026 Arveya Teknoloji"
    val version: String get() = "v1.0.0"

    // ---------- Helper ----------
    private fun s(tr: String, en: String, es: String, fr: String): String =
        when (_currentLang.value) {
            "EN" -> en
            "ES" -> es
            "FR" -> fr
            else -> tr
        }
}
