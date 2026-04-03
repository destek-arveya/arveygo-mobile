import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var L = LoginStrings.shared
    @FocusState private var focusedField: Field?

    enum Field { case email, password, phone, otp }

    @State private var loginMode = 0
    @State private var phone = ""
    @State private var otpCode = ""
    @State private var otpSent = false
    @State private var otpError: String?
    @State private var otpLoading = false
    @State private var resendCooldown = 0
    @State private var cooldownTimer: Timer?
    @State private var selectedCountry = CountryCode.all.first(where: { $0.id == "TR" })!
    @State private var showCountryPicker = false

    var body: some View {
        ZStack {
            AuthNeoBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        LanguageSwitcher()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                    AuthNeoHero(
                        eyebrow: "ARVEYGO MOBILE",
                        title: "Filo kontrolüne güvenli biçimde giriş yap",
                        subtitle: "Tüm araç, alarm ve operasyon ekranlarına tek oturumla erişin.",
                        chips: []
                    )
                    .padding(.horizontal, 20)

                    VStack(spacing: 18) {
                        AuthNeoPanel {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(L.welcomeBack)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(AppTheme.authNightText)
                                        Text(L.loginSubtitle)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundStyle(AppTheme.authNightTextSecondary)
                                    }
                                    Spacer()
                                    Image("LoginLogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 54, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .padding(.bottom, 18)

                                AuthNeoModeSwitcher(
                                    selectedIndex: loginMode,
                                    options: [
                                        (icon: "envelope.fill", title: L.emailTab),
                                        (icon: "phone.fill", title: L.phoneTab)
                                    ]
                                ) { index in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        loginMode = index
                                        otpSent = false
                                        otpError = nil
                                    }
                                }
                                .padding(.bottom, 18)

                                if let error = authVM.errorMessage ?? otpError {
                                    authErrorBanner(error)
                                        .padding(.bottom, 16)
                                }

                                if loginMode == 0 {
                                    emailForm
                                } else {
                                    phoneForm
                                }

                                Spacer().frame(height: 20)

                                AuthNeoDivider(title: L.orDivider)
                                    .padding(.bottom, 18)

                                NavigationLink(destination: RegisterView()) {
                                    HStack(spacing: 4) {
                                        Text(L.noAccount)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundStyle(AppTheme.authNightTextMuted)
                                        Text(L.register)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(AppTheme.authNightText)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(spacing: 4) {
                            Text(L.copyright)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppTheme.authNightTextMuted)
                            Text(L.version)
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(AppTheme.authNightTextMuted.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 26)
                    .padding(.bottom, 24)
                }
            }
        }
        .tint(.white)
        .navigationBarHidden(true)
        .onTapGesture { focusedField = nil }
        .onAppear { authVM.clearLoginFields() }
        .onDisappear {
            cooldownTimer?.invalidate()
            cooldownTimer = nil
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(selected: $selectedCountry, isPresented: $showCountryPicker)
        }
    }

    private var emailForm: some View {
        VStack(spacing: 0) {
            AuthNeoField(label: L.emailLabel, icon: "envelope", isFocused: focusedField == .email) {
                TextField("", text: $authVM.loginEmail, prompt: authPrompt(L.emailPlaceholder))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.authNightText)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .tint(.white)
                    .focused($focusedField, equals: .email)
            }
            .padding(.bottom, 14)

            AuthNeoField(label: L.passwordLabel, icon: "lock", isFocused: focusedField == .password) {
                SecureField("", text: $authVM.loginPassword, prompt: authPrompt(L.passwordPlaceholder))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.authNightText)
                    .textContentType(.password)
                    .tint(.white)
                    .focused($focusedField, equals: .password)
            }
            .padding(.bottom, 12)

            HStack {
                Button(action: { authVM.rememberMe.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: authVM.rememberMe ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(authVM.rememberMe ? AppTheme.authNightText : AppTheme.authNightTextMuted)
                        Text(L.rememberMe)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.authNightTextSecondary)
                    }
                }

                Spacer()

                NavigationLink(destination: ForgotPasswordView()) {
                    Text(L.forgotPassword)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.authNightText)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 22)

            Button(action: {
                focusedField = nil
                authVM.login()
            }) {
                HStack(spacing: 8) {
                    if authVM.isLoading {
                        LoadingSpinner()
                    } else {
                        Text(L.loginButton)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
            }
            .buttonStyle(ArveyButtonStyle())
            .disabled(authVM.isLoading)
        }
    }

    private var phoneForm: some View {
        VStack(spacing: 0) {
            if !otpSent {
                AuthNeoField(label: L.phoneLabel, icon: "phone", isFocused: focusedField == .phone) {
                    HStack(spacing: 10) {
                        Button(action: { showCountryPicker = true }) {
                            HStack(spacing: 6) {
                                Text(selectedCountry.flag)
                                    .font(.system(size: 16))
                                Text(selectedCountry.dialCode)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.authNightText)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(AppTheme.authNightTextMuted)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08), in: Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)

                        TextField("", text: Binding(
                            get: { phone },
                            set: { newValue in
                                let digits = newValue.filter { $0.isNumber }
                                phone = String(digits.prefix(selectedCountry.maxDigits))
                            }
                        ), prompt: authPrompt(phonePlaceholder))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.authNightText)
                        .keyboardType(.numberPad)
                        .tint(.white)
                        .focused($focusedField, equals: .phone)
                    }
                }
                .padding(.bottom, 8)

                if !phone.isEmpty {
                    Text(formattedPhoneDisplay)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.authNightTextMuted)
                        .padding(.leading, 4)
                        .padding(.bottom, 16)
                } else {
                    Spacer().frame(height: 16)
                }

                Button(action: {
                    focusedField = nil
                    otpError = nil
                    let clean = phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
                    guard clean.count >= 10 else {
                        otpError = L.phoneRequired
                        return
                    }
                    otpLoading = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        otpLoading = false
                        otpSent = true
                        startCooldownTimer()
                    }
                }) {
                    HStack(spacing: 8) {
                        if otpLoading {
                            LoadingSpinner()
                        } else {
                            Text(L.sendOtp)
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }
                .buttonStyle(ArveyButtonStyle())
                .disabled(otpLoading)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .frame(width: 48, height: 48)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.otpStep2Title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppTheme.authNightText)
                            Text("\(selectedCountry.flag) \(selectedCountry.dialCode) \(formattedPhoneDisplay)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.authNightTextSecondary)
                        }
                    }
                    .padding(.bottom, 16)

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(L.otpSent)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(AppTheme.online)
                    .padding(12)
                    .background(AppTheme.online.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.bottom, 16)

                    AuthNeoField(label: L.otpLabel, icon: "number", isFocused: focusedField == .otp) {
                        TextField("", text: $otpCode, prompt: authPrompt(L.otpPlaceholder))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.authNightText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .tint(.white)
                            .focused($focusedField, equals: .otp)
                            .onChange(of: otpCode) {
                                let filtered = otpCode.filter { $0.isNumber }
                                otpCode = String(filtered.prefix(6))
                            }
                    }
                    .padding(.bottom, 16)

                    Button(action: { authVM.rememberMe.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: authVM.rememberMe ? "checkmark.square.fill" : "square")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(authVM.rememberMe ? AppTheme.authNightText : AppTheme.authNightTextMuted)
                            Text(L.rememberMe)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.authNightTextSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 18)

                    Button(action: {
                        focusedField = nil
                        otpError = nil
                        guard !otpCode.isEmpty else {
                            otpError = L.otpRequired
                            return
                        }
                        authVM.loginWithOTP(phone: phone, otp: otpCode) { success in
                            if !success {
                                otpError = L.otpInvalid
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if authVM.isLoading {
                                LoadingSpinner()
                            } else {
                                Text(L.loginButton)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                    }
                    .buttonStyle(ArveyButtonStyle())
                    .disabled(authVM.isLoading)
                    .padding(.bottom, 12)

                    if resendCooldown > 0 {
                        Text("\(L.resendCooldown) (\(resendCooldown)s)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.authNightTextMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 10)
                    } else {
                        AuthNeoSecondaryButton(title: L.resendCode) {
                            otpCode = ""
                            otpError = nil
                            otpLoading = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                otpLoading = false
                                startCooldownTimer()
                            }
                        }
                        .padding(.bottom, 10)
                    }

                    Button(action: {
                        cooldownTimer?.invalidate()
                        cooldownTimer = nil
                        resendCooldown = 0
                        otpSent = false
                        otpCode = ""
                        otpError = nil
                    }) {
                        Text(L.currentLang == "TR" ? "Numarayı Değiştir" : "Change Number")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.authNightTextMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func authErrorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.system(size: 12, weight: .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(Color.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.32), lineWidth: 1)
        )
    }

    private var formattedPhoneDisplay: String {
        CountryCode.formatPhone(phone, format: selectedCountry.format)
    }

    private var phonePlaceholder: String {
        selectedCountry.format.replacingOccurrences(of: "#", with: "0")
    }

    private func startCooldownTimer() {
        resendCooldown = 30
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                if resendCooldown > 0 {
                    resendCooldown -= 1
                } else {
                    timer.invalidate()
                    cooldownTimer = nil
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
