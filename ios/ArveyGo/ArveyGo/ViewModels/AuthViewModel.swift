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

    // Hardcoded admin credentials (matching Laravel)
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

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false

            let email = self.loginEmail.lowercased().trimmingCharacters(in: .whitespaces)

            // Check admin credentials
            if email == self.adminEmail && self.loginPassword == self.adminPassword {
                self.currentUser = AppUser.dummy
                self.isLoggedIn = true
                return
            }

            // Check registered users
            if let password = self.userPasswords[email],
               password == self.loginPassword,
               let user = self.registeredUsers.first(where: { $0.email == email }) {
                self.currentUser = user
                self.isLoggedIn = true
                return
            }

            self.errorMessage = "E-posta veya şifre hatalı"
        }
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
