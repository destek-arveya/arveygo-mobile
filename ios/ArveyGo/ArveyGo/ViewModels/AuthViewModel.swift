import SwiftUI
import Combine

// MARK: - Auth ViewModel
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var currentUser: AppUser?
    @Published var errorMessage: String?

    // Login fields
    @Published var loginEmail = ""
    @Published var loginPassword = ""

    // Register fields
    @Published var registerName = ""
    @Published var registerEmail = ""
    @Published var registerPassword = ""
    @Published var registerPasswordConfirm = ""

    // Forgot password
    @Published var forgotEmail = ""
    @Published var resetSent = false

    // Remember Me
    @Published var rememberMe = false

    // WebSocket config received from server (or generated locally)
    @Published var wsConfig: WSConfig?

    // Hardcoded admin credentials (offline fallback only)
    private let offlineAdminEmail = "admin@admin.com"
    private let offlineAdminPassword = "123"

    // Registered users storage (in-memory for offline demo)
    private var registeredUsers: [AppUser] = []
    private var userPasswords: [String: String] = [:]

    // MARK: - Init — auto-login if token exists
    init() {
        APIService.shared.onSessionExpired = { [weak self] in
            Task { @MainActor in
                self?.logout()
            }
        }
        if APIService.shared.hasStoredToken {
            attemptAutoLogin()
        }
    }

    // MARK: - Auto Login
    /// Try to restore session using stored Bearer token
    private func attemptAutoLogin() {
        isLoading = true
        Task {
            do {
                let user = try await APIService.shared.fetchMe()
                self.currentUser = user
                self.isLoggedIn = true
                self.isLoading = false
                self.generateLocalWSConfig(for: user)
                self.connectWebSocket()
                print("[Auth] Auto-login OK: \(user.name)")
            } catch {
                print("[Auth] Auto-login failed: \(error.localizedDescription)")
                APIService.shared.clearToken()
                self.isLoading = false
            }
        }
    }

    // MARK: - Login
    func login() {
        errorMessage = nil
        guard !loginEmail.isEmpty else {
            errorMessage = "E-posta adresi gerekli"
            return
        }
        guard loginEmail.contains("@") else {
            errorMessage = "Geçerli bir e-posta adresi girin"
            return
        }
        guard !loginPassword.isEmpty else {
            errorMessage = "Şifre gerekli"
            return
        }

        isLoading = true
        loginViaAPI()
    }

    // MARK: - Real API Login
    private func loginViaAPI() {
        Task {
            do {
                let response = try await APIService.shared.login(
                    email: loginEmail,
                    password: loginPassword
                )

                self.currentUser = response.user
                self.isLoggedIn = true
                self.isLoading = false

                // Generate WS config with user info
                self.generateLocalWSConfig(for: response.user)

                // Auto-connect WebSocket
                connectWebSocket()

                // Request push permission & register device token with backend
                registerPushToken()

                print("[Auth] Login OK: \(response.user.name)")

            } catch let error as APIError {
                self.isLoading = false

                switch error {
                case .networkError:
                    // Network failure → offer offline fallback
                    print("[Auth] Network error, trying offline login")
                    self.loginOffline()
                default:
                    self.errorMessage = error.errorDescription
                }

            } catch {
                self.isLoading = false
                // Unknown error → try offline
                print("[Auth] API login failed: \(error.localizedDescription)")
                self.loginOffline()
            }
        }
    }

    // MARK: - Offline / Demo Login (fallback when server is unreachable)
    private func loginOffline() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false

            let email = self.loginEmail.lowercased().trimmingCharacters(in: .whitespaces)

            // Check admin credentials
            if email == self.offlineAdminEmail && self.loginPassword == self.offlineAdminPassword {
                self.currentUser = AppUser.dummy
                self.isLoggedIn = true
                self.generateLocalWSConfig(for: AppUser.dummy)
                self.connectWebSocket()
                return
            }

            // Check registered users
            if let password = self.userPasswords[email],
               password == self.loginPassword,
               let user = self.registeredUsers.first(where: { $0.email == email }) {
                self.currentUser = user
                self.isLoggedIn = true
                self.generateLocalWSConfig(for: user)
                self.connectWebSocket()
                return
            }

            self.errorMessage = "Sunucuya bağlanılamadı. Çevrimdışı giriş: admin@admin.com / 123"
        }
    }

    // MARK: - Token Refresh
    func refreshTokenIfNeeded() {
        Task {
            do {
                _ = try await APIService.shared.refreshToken()
                print("[Auth] Token refreshed")
            } catch {
                print("[Auth] Token refresh failed: \(error.localizedDescription)")
                // If refresh fails with 401, force re-login
                if case APIError.unauthorized = error {
                    logout()
                }
            }
        }
    }

    // MARK: - WebSocket Configuration
    private func generateLocalWSConfig(for user: AppUser) {
        let jwt = JWTHelper.issueLiveMapToken(
            sub: user.id,
            companyId: user.companyId
        )
        wsConfig = WSConfig(
            url: AppConfig.wsURL,
            token: jwt,
            pingInterval: Int(AppConfig.wsPingInterval)
        )
    }

    func connectWebSocket() {
        guard let config = wsConfig else { return }
        WebSocketManager.shared.connect(url: config.url, token: config.token)
    }

    func disconnectWebSocket() {
        WebSocketManager.shared.disconnect()
    }

    // MARK: - Push Token Registration
    /// Request push permission, then send device token to backend
    private func registerPushToken() {
        AppDelegate.requestPushPermission()

        // Observe token changes — when Apple delivers the token, send it to backend
        var cancellable: AnyCancellable?
        cancellable = DeviceTokenStore.shared.$token
            .compactMap { $0 }          // wait for non-nil
            .first()                     // only once
            .sink { token in
                Task {
                    await APIService.shared.registerPushToken(token)
                }
                cancellable?.cancel()
            }

        // If token is already available (e.g. from previous session), send immediately
        if let existingToken = DeviceTokenStore.shared.token {
            Task {
                await APIService.shared.registerPushToken(existingToken)
            }
            cancellable?.cancel()
        }
    }

    // MARK: - Login via Phone + OTP
    func loginWithOTP(phone: String, otp: String, completion: @escaping (Bool) -> Void) {
        errorMessage = nil
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false

            if otp == "000000" {
                self.currentUser = AppUser.dummy
                self.isLoggedIn = true
                self.generateLocalWSConfig(for: AppUser.dummy)
                self.connectWebSocket()
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    // MARK: - Register
    func register() {
        errorMessage = nil

        guard !registerName.isEmpty else { errorMessage = "Ad Soyad gerekli"; return }
        guard !registerEmail.isEmpty, registerEmail.contains("@") else { errorMessage = "Geçerli bir e-posta adresi girin"; return }
        guard registerPassword.count >= 8 else { errorMessage = "Şifre en az 8 karakter olmalı"; return }
        guard registerPassword == registerPasswordConfirm else { errorMessage = "Şifreler eşleşmiyor"; return }

        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false

            let email = self.registerEmail.lowercased().trimmingCharacters(in: .whitespaces)
            let name = self.registerName.trimmingCharacters(in: .whitespaces)

            let initials = name.split(separator: " ")
                .prefix(2)
                .compactMap { $0.first.map { String($0).uppercased() } }
                .joined()

            let newUser = AppUser(
                id: UUID().uuidString,
                name: name,
                email: email,
                avatar: initials.isEmpty ? "U" : initials,
                role: "Kullanıcı",
                roleKey: "user",
                companyId: 1
            )

            self.registeredUsers.append(newUser)
            self.userPasswords[email] = self.registerPassword
            self.currentUser = newUser
            self.isLoggedIn = true
        }
    }

    // MARK: - Forgot Password
    func sendResetLink() {
        errorMessage = nil
        guard !forgotEmail.isEmpty, forgotEmail.contains("@") else {
            errorMessage = "Geçerli bir e-posta adresi girin"
            return
        }

        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.resetSent = true
        }
    }

    // MARK: - Logout
    func logout() {
        disconnectWebSocket()
        wsConfig = nil

        // Logout from API (clears token)
        Task { await APIService.shared.logout() }

        withAnimation {
            isLoggedIn = false
            currentUser = nil
            loginEmail = ""
            loginPassword = ""
            errorMessage = nil
        }
    }

    // MARK: - Clear
    func clearLoginFields() {
        loginEmail = ""
        loginPassword = ""
        errorMessage = nil
    }

    func clearRegisterFields() {
        registerName = ""
        registerEmail = ""
        registerPassword = ""
        registerPasswordConfirm = ""
        errorMessage = nil
    }

    func clearForgotFields() {
        forgotEmail = ""
        errorMessage = nil
        resetSent = false
    }
}
