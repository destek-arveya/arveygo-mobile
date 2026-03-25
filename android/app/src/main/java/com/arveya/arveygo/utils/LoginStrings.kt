package com.arveya.arveygo.utils

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Login page localization strings – TR/EN
 */
object LoginStrings {
    private val _currentLang = MutableStateFlow("TR")
    val currentLang: StateFlow<String> = _currentLang

    fun setLanguage(lang: String) {
        _currentLang.value = lang
    }

    // ---------- Getters ----------

    val appTitle: String get() = s("ArveyGo", "ArveyGo")
    val appSubtitle: String get() = s("ARAÇ TAKİP SİSTEMİ", "VEHICLE TRACKING SYSTEM")

    val welcomeBack: String get() = s("Tekrar Hoş Geldiniz", "Welcome Back")
    val loginSubtitle: String get() = s("Hesabınıza giriş yapın", "Sign in to your account")

    // Tab titles
    val emailTab: String get() = s("E-posta", "Email")
    val phoneTab: String get() = s("Telefon", "Phone")

    // Email/Password
    val emailLabel: String get() = s("E-posta", "Email")
    val emailPlaceholder: String get() = s("ornek@email.com", "example@email.com")
    val passwordLabel: String get() = s("Şifre", "Password")
    val passwordPlaceholder: String get() = s("••••••••", "••••••••")

    // Phone/OTP
    val phoneLabel: String get() = s("Telefon Numarası", "Phone Number")
    val phonePlaceholder: String get() = s("+90 5XX XXX XX XX", "+90 5XX XXX XX XX")
    val sendOtp: String get() = s("Kod Gönder", "Send Code")
    val otpLabel: String get() = s("Doğrulama Kodu", "Verification Code")
    val otpPlaceholder: String get() = s("6 haneli kod", "6-digit code")
    val otpSent: String get() = s("Doğrulama kodu gönderildi", "Verification code sent")
    val otpInvalid: String get() = s("Doğrulama kodu hatalı", "Invalid verification code")
    val phoneRequired: String get() = s("Telefon numarası gerekli", "Phone number is required")
    val otpRequired: String get() = s("Doğrulama kodu gerekli", "Verification code is required")

    // Remember Me
    val rememberMe: String get() = s("Beni Hatırla", "Remember Me")

    // Buttons & links
    val forgotPassword: String get() = s("Şifremi Unuttum", "Forgot Password")
    val loginButton: String get() = s("Giriş Yap", "Sign In")
    val orDivider: String get() = s("veya", "or")
    val noAccount: String get() = s("Hesabınız yok mu?", "Don't have an account?")
    val register: String get() = s("Kayıt Ol", "Sign Up")

    // Validation
    val emailRequired: String get() = s("E-posta adresi gerekli", "Email address is required")
    val emailInvalid: String get() = s("Geçerli bir e-posta adresi girin", "Enter a valid email address")
    val passwordRequired: String get() = s("Şifre gerekli", "Password is required")
    val loginFailed: String get() = s("E-posta veya şifre hatalı", "Invalid email or password")

    // Footer
    val copyright: String get() = s("© 2026 Arveya Teknoloji", "© 2026 Arveya Teknoloji")
    val version: String get() = s("v1.0.0", "v1.0.0")

    // ---------- Helper ----------
    private fun s(tr: String, en: String): String =
        if (_currentLang.value == "TR") tr else en
}
