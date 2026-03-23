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

    // WebSocket config received from server (or generated locally)
    @Published var wsConfig: WSConfig?

    // Whether to use real API (true) or demo/fallback mode (false)
    var useRealAPI: Bool = true

    // Hardcoded admin credentials (matching Laravel — used as offline fallback)
    private let adminEmail = "admin@admin.com"
    private let adminPassword = "123"

    // Registered users storage (in-memory for demo)
    private var registeredUsers: [AppUser] = []
    private var userPasswords: [String: String] = [:]

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

        if useRealAPI {
            loginViaAPI()
        } else {
            loginOffline()
        }
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

                // Use server-provided WS config if available
                if let serverWS = response.wsConfig {
                    self.wsConfig = serverWS
                } else {
                    // Generate JWT locally (we have the shared secret)
                    self.generateLocalWSConfig(for: response.user)
                }

                // Auto-connect WebSocket
                connectWebSocket()

            } catch let error as APIError {
                self.isLoading = false
                self.errorMessage = error.errorDescription

                // If it's a network error, offer fallback to offline mode
                if case .networkError = error {
                    self.errorMessage = "Sunucuya bağlanılamadı. Çevrimdışı mod deneyin."
                }
            } catch {
                self.isLoading = false

                // Network failure → fall back to offline login
                print("[Auth] API login failed, trying offline: \(error.localizedDescription)")
                self.loginOffline()
            }
        }
    }

    // MARK: - Offline / Demo Login
    private func loginOffline() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false

            let email = self.loginEmail.lowercased().trimmingCharacters(in: .whitespaces)

            // Check admin credentials
            if email == self.adminEmail && self.loginPassword == self.adminPassword {
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

            self.errorMessage = "E-posta veya şifre hatalı"
        }
    }

    // MARK: - WebSocket Configuration

    /// Generate JWT locally using the shared secret (for offline/fallback mode)
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

    /// Connect to the WebSocket with current config
    func connectWebSocket() {
        guard let config = wsConfig else { return }
        WebSocketManager.shared.connect(url: config.url, token: config.token)
    }

    /// Disconnect WebSocket
    func disconnectWebSocket() {
        WebSocketManager.shared.disconnect()
    }

    // MARK: - Register
    func register() {
        errorMessage = nil

        guard !registerName.isEmpty else {
            errorMessage = "Ad Soyad gerekli"
            return
        }
        guard !registerEmail.isEmpty, registerEmail.contains("@") else {
            errorMessage = "Geçerli bir e-posta adresi girin"
            return
        }
        guard registerPassword.count >= 8 else {
            errorMessage = "Şifre en az 8 karakter olmalı"
            return
        }
        guard registerPassword == registerPasswordConfirm else {
            errorMessage = "Şifreler eşleşmiyor"
            return
        }
        guard registerEmail.lowercased() != adminEmail else {
            errorMessage = "Bu e-posta adresi kullanılamaz"
            return
        }
        guard !registeredUsers.contains(where: { $0.email == registerEmail.lowercased() }) else {
            errorMessage = "Bu e-posta adresi zaten kayıtlı"
            return
        }

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
        // Disconnect WebSocket
        disconnectWebSocket()
        wsConfig = nil

        // Logout from API
        if useRealAPI {
            Task { await APIService.shared.logout() }
        }

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
