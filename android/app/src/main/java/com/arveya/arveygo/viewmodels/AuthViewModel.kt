package com.arveya.arveygo.viewmodels

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.arveya.arveygo.models.AppUser
import com.arveya.arveygo.models.WSConfig
import com.arveya.arveygo.services.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class AuthViewModel(application: Application) : AndroidViewModel(application) {

    private val ctx get() = getApplication<Application>().applicationContext

    private val _isLoggedIn = MutableStateFlow(false)
    val isLoggedIn: StateFlow<Boolean> = _isLoggedIn

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _currentUser = MutableStateFlow<AppUser?>(null)
    val currentUser: StateFlow<AppUser?> = _currentUser

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    // Login fields
    val loginEmail = MutableStateFlow("")
    val loginPassword = MutableStateFlow("")

    // Register fields
    val registerName = MutableStateFlow("")
    val registerEmail = MutableStateFlow("")
    val registerPassword = MutableStateFlow("")
    val registerPasswordConfirm = MutableStateFlow("")

    // Forgot password
    val forgotEmail = MutableStateFlow("")
    private val _resetSent = MutableStateFlow(false)
    val resetSent: StateFlow<Boolean> = _resetSent

    // Remember Me
    val rememberMe = MutableStateFlow(false)

    // WS config
    private var wsConfig: WSConfig? = null

    // Offline fallback credentials
    private val offlineAdminEmail = "admin@admin.com"
    private val offlineAdminPassword = "123"

    // Registered users (in-memory for offline demo)
    private val registeredUsers = mutableListOf<AppUser>()
    private val userPasswords = mutableMapOf<String, String>()

    // MARK: - Init — restore token & auto-login
    init {
        APIService.initialize(ctx)
        // Register global 401 handler — any API call that returns 401 will auto-logout
        APIService.onSessionExpired = { logout() }
        if (APIService.hasStoredToken) {
            attemptAutoLogin()
        }
    }

    private fun attemptAutoLogin() {
        _isLoading.value = true
        viewModelScope.launch {
            try {
                val user = APIService.fetchMe()
                _currentUser.value = user
                _isLoggedIn.value = true
                _isLoading.value = false
                generateLocalWSConfig(user)
                connectWebSocket()
                Log.d("Auth", "Auto-login OK: ${user.name}")
            } catch (e: Exception) {
                Log.d("Auth", "Auto-login failed: ${e.localizedMessage}")
                APIService.clearToken(ctx)
                _isLoading.value = false
            }
        }
    }

    // MARK: - Login
    fun login() {
        _errorMessage.value = null
        val email = loginEmail.value.trim()
        val password = loginPassword.value

        if (email.isEmpty()) { _errorMessage.value = "E-posta adresi gerekli"; return }
        if (!email.contains("@")) { _errorMessage.value = "Geçerli bir e-posta adresi girin"; return }
        if (password.isEmpty()) { _errorMessage.value = "Şifre gerekli"; return }

        _isLoading.value = true
        loginViaAPI(email, password)
    }

    private fun loginViaAPI(email: String, password: String) {
        viewModelScope.launch {
            try {
                val response = APIService.login(email, password, ctx)
                _currentUser.value = response.user
                _isLoggedIn.value = true
                _isLoading.value = false

                generateLocalWSConfig(response.user)
                connectWebSocket()

                Log.d("Auth", "Login OK: ${response.user.name}")

            } catch (e: APIException.NetworkError) {
                _isLoading.value = false
                Log.d("Auth", "Network error, trying offline: ${e.localizedMessage}")
                loginOffline(email, password)
            } catch (e: APIException) {
                _isLoading.value = false
                _errorMessage.value = e.message
            } catch (e: Exception) {
                _isLoading.value = false
                Log.d("Auth", "API login failed: ${e.localizedMessage}")
                loginOffline(email, password)
            }
        }
    }

    // MARK: - Offline / Demo Login (fallback when server is unreachable)
    private fun loginOffline(email: String, password: String) {
        viewModelScope.launch {
            delay(800)
            _isLoading.value = false
            val em = email.lowercase().trim()

            if (em == offlineAdminEmail && password == offlineAdminPassword) {
                _currentUser.value = AppUser.dummy
                _isLoggedIn.value = true
                generateLocalWSConfig(AppUser.dummy)
                connectWebSocket()
                return@launch
            }

            val storedPassword = userPasswords[em]
            if (storedPassword == password) {
                val user = registeredUsers.firstOrNull { it.email == em }
                if (user != null) {
                    _currentUser.value = user
                    _isLoggedIn.value = true
                    generateLocalWSConfig(user)
                    connectWebSocket()
                    return@launch
                }
            }

            _errorMessage.value = "Sunucuya bağlanılamadı. Çevrimdışı giriş: admin@admin.com / 123"
        }
    }

    // MARK: - Token Refresh
    fun refreshTokenIfNeeded() {
        viewModelScope.launch {
            try {
                APIService.refreshToken(ctx)
                Log.d("Auth", "Token refreshed")
            } catch (e: Exception) {
                Log.d("Auth", "Token refresh failed: ${e.localizedMessage}")
                if (e is APIException.Unauthorized) {
                    logout()
                }
            }
        }
    }

    // MARK: - WS Configuration
    private fun generateLocalWSConfig(user: AppUser) {
        val jwt = JWTHelper.issueLiveMapToken(sub = user.id, companyId = user.companyId)
        wsConfig = WSConfig(url = AppConfig.WS_URL, token = jwt, pingInterval = AppConfig.WS_PING_INTERVAL.toInt())
        Log.d("WS", "generateLocalWSConfig: url=${AppConfig.WS_URL}, userId=${user.id}")
    }

    fun connectWebSocket() {
        wsConfig?.let {
            WebSocketManager.connect(it.url, it.token)
        }
    }

    fun disconnectWebSocket() {
        WebSocketManager.disconnect()
    }

    // MARK: - Login via Phone + OTP
    fun loginWithOTP(phone: String, otp: String, onResult: (Boolean) -> Unit) {
        _errorMessage.value = null
        _isLoading.value = true

        viewModelScope.launch {
            delay(800)
            _isLoading.value = false

            if (otp == "000000") {
                _currentUser.value = AppUser.dummy
                _isLoggedIn.value = true
                generateLocalWSConfig(AppUser.dummy)
                connectWebSocket()
                onResult(true)
            } else {
                onResult(false)
            }
        }
    }

    // MARK: - Register
    fun register() {
        _errorMessage.value = null
        val name = registerName.value.trim()
        val email = registerEmail.value.trim().lowercase()
        val password = registerPassword.value
        val confirm = registerPasswordConfirm.value

        if (name.isEmpty()) { _errorMessage.value = "Ad Soyad gerekli"; return }
        if (email.isEmpty() || !email.contains("@")) { _errorMessage.value = "Geçerli bir e-posta adresi girin"; return }
        if (password.length < 8) { _errorMessage.value = "Şifre en az 8 karakter olmalı"; return }
        if (password != confirm) { _errorMessage.value = "Şifreler eşleşmiyor"; return }

        _isLoading.value = true

        viewModelScope.launch {
            delay(1200)
            _isLoading.value = false

            val initials = name.split(" ").take(2).mapNotNull { it.firstOrNull()?.uppercase() }.joinToString("")
            val newUser = AppUser(
                id = java.util.UUID.randomUUID().toString(),
                name = name, email = email,
                avatar = initials.ifEmpty { "U" },
                role = "Kullanıcı", roleKey = "user", companyId = 1
            )
            registeredUsers.add(newUser)
            userPasswords[email] = password
            _currentUser.value = newUser
            _isLoggedIn.value = true
        }
    }

    // MARK: - Forgot Password
    fun sendResetLink() {
        _errorMessage.value = null
        val email = forgotEmail.value.trim()
        if (email.isEmpty() || !email.contains("@")) { _errorMessage.value = "Geçerli bir e-posta adresi girin"; return }

        _isLoading.value = true
        viewModelScope.launch {
            delay(1000)
            _isLoading.value = false
            _resetSent.value = true
        }
    }

    // MARK: - Logout
    fun logout() {
        disconnectWebSocket()
        wsConfig = null

        viewModelScope.launch { APIService.logout(ctx) }

        _isLoggedIn.value = false
        _currentUser.value = null
        loginEmail.value = ""
        loginPassword.value = ""
        _errorMessage.value = null
    }

    // MARK: - Clear
    fun clearLoginFields() {
        loginEmail.value = ""
        loginPassword.value = ""
        _errorMessage.value = null
    }

    fun clearRegisterFields() {
        registerName.value = ""
        registerEmail.value = ""
        registerPassword.value = ""
        registerPasswordConfirm.value = ""
        _errorMessage.value = null
    }

    fun clearForgotFields() {
        forgotEmail.value = ""
        _errorMessage.value = null
        _resetSent.value = false
    }
}
