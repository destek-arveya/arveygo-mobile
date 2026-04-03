import SwiftUI

struct LoginViewBackup: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var L = LoginStrings.shared
    @FocusState private var focusedField: Field?

    enum Field { case email, password, phone, otp }

    // Login mode: 0 = email, 1 = phone
    @State private var loginMode = 0

    // Phone / OTP
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
            // Background
            AppTheme.panelGradient.ignoresSafeArea()

            // Decorative background circles
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 380, height: 380)
                    .offset(x: -110, y: -130)

                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 300, height: 300)
                    .offset(x: geo.size.width - 110, y: geo.size.height - 220)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Language Switcher
                    HStack {
                        Spacer()
                        LanguageSwitcher()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                    // Logo
                    VStack(spacing: 8) {
                        Image("LoginLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
                    }
                    .padding(.bottom, 24)

                    // Login Card
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L.welcomeBack)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppTheme.authTextPrimary)

                            Text(L.loginSubtitle)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.authTextMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 20)

                        // ═══ Tab Switcher: E-posta / Telefon ═══
                        HStack(spacing: 0) {
                            ForEach([0, 1], id: \.self) { mode in
                                let tabLabel = mode == 0 ? L.emailTab : L.phoneTab
                                let icon = mode == 0 ? "envelope.fill" : "phone.fill"

                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) { loginMode = mode }
                                    otpSent = false; otpError = nil
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: icon)
                                            .font(.system(size: 11))
                                        Text(tabLabel)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(loginMode == mode ? .white : AppTheme.authTextMuted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(loginMode == mode ? AppTheme.navy : Color.clear)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(3)
                        .background(AppTheme.authCanvas.opacity(0.96))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppTheme.authBorder, lineWidth: 1)
                        )
                        .padding(.bottom, 20)

                        // Error message
                        if let error = authVM.errorMessage ?? otpError {
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
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // ═══ EMAIL/PASSWORD MODE ═══
                        if loginMode == 0 {
                            // Email Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L.emailLabel)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.authTextSecondary)

                                HStack(spacing: 12) {
                                    Image(systemName: "envelope")
                                        .font(.system(size: 15))
                                        .foregroundColor(AppTheme.authTextMuted)
                                        .frame(width: 20)

                                    TextField(L.emailPlaceholder, text: $authVM.loginEmail)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.authTextPrimary)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .tint(AppTheme.navy)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .focused($focusedField, equals: .email)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 56)
                                .background(AppTheme.authField)
                                .cornerRadius(12)
                                .contentShape(Rectangle())
                                .onTapGesture { focusedField = .email }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .email ? AppTheme.navy : AppTheme.authBorder, lineWidth: focusedField == .email ? 1.5 : 1)
                                )
                            }
                            .padding(.bottom, 16)

                            // Password Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L.passwordLabel)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.authTextSecondary)

                                HStack(spacing: 12) {
                                    Image(systemName: "lock")
                                        .font(.system(size: 15))
                                        .foregroundColor(AppTheme.authTextMuted)
                                        .frame(width: 20)

                                    SecureField(L.passwordPlaceholder, text: $authVM.loginPassword)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.authTextPrimary)
                                        .textContentType(.password)
                                        .tint(AppTheme.navy)
                                        .focused($focusedField, equals: .password)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 56)
                                .background(AppTheme.authField)
                                .cornerRadius(12)
                                .contentShape(Rectangle())
                                .onTapGesture { focusedField = .password }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focusedField == .password ? AppTheme.navy : AppTheme.authBorder, lineWidth: focusedField == .password ? 1.5 : 1)
                                )
                            }
                            .padding(.bottom, 12)

                            // Remember Me + Forgot Password
                            HStack {
                                // Remember Me
                                Button(action: { authVM.rememberMe.toggle() }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: authVM.rememberMe ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 16))
                                            .foregroundColor(authVM.rememberMe ? AppTheme.navy : AppTheme.authTextMuted)
                                        Text(L.rememberMe)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppTheme.authTextSecondary)
                                    }
                                }

                                Spacer()

                                NavigationLink(destination: ForgotPasswordView()) {
                                    Text(L.forgotPassword)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.authAccent)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.bottom, 24)

                            // Login Button
                            Button(action: { focusedField = nil; authVM.login() }) {
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

                        // ═══ PHONE/OTP MODE ═══
                        if loginMode == 1 {
                            if !otpSent {
                                // ── Step 1: Phone number entry ──
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(L.phoneLabel)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.authTextSecondary)

                                    HStack(spacing: 0) {
                                        // Country code picker button
                                        Button(action: { showCountryPicker = true }) {
                                            HStack(spacing: 6) {
                                                Text(selectedCountry.flag)
                                                    .font(.system(size: 18))
                                                Text(selectedCountry.dialCode)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(AppTheme.authTextPrimary)
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(AppTheme.authTextMuted)
                                            }
                                            .padding(.horizontal, 12)
                                            .frame(height: 56)
                                            .background(AppTheme.authField)
                                            .cornerRadius(12, corners: [.topLeft, .bottomLeft])
                                            .overlay(
                                                RoundedCorner(radius: 12, corners: [.topLeft, .bottomLeft])
                                                    .stroke(focusedField == .phone ? AppTheme.navy : AppTheme.authBorder, lineWidth: focusedField == .phone ? 1.5 : 1)
                                            )
                                        }

                                        // Phone number input
                                        TextField(phonePlaceholder, text: Binding(
                                            get: { phone },
                                            set: { newValue in
                                                let digits = newValue.filter { $0.isNumber }
                                                let limited = String(digits.prefix(selectedCountry.maxDigits))
                                                phone = limited
                                            }
                                        ))
                                            .font(.system(size: 14))
                                            .foregroundColor(AppTheme.authTextPrimary)
                                            .keyboardType(.numberPad)
                                            .tint(AppTheme.navy)
                                            .focused($focusedField, equals: .phone)
                                            .padding(.horizontal, 12)
                                            .frame(height: 56)
                                            .background(AppTheme.authField)
                                            .cornerRadius(12, corners: [.topRight, .bottomRight])
                                            .overlay(
                                                RoundedCorner(radius: 12, corners: [.topRight, .bottomRight])
                                                    .stroke(focusedField == .phone ? AppTheme.navy : AppTheme.authBorder, lineWidth: focusedField == .phone ? 1.5 : 1)
                                            )
                                    }

                                    // Formatted preview
                                    if !phone.isEmpty {
                                        Text(formattedPhoneDisplay)
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.authTextMuted)
                                            .padding(.leading, 4)
                                            .padding(.top, 2)
                                    }
                                }
                                .padding(.bottom, 16)

                                // Send OTP Button
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
                                // ── Step 2: OTP Verification ──

                                // Step 2 header
                                VStack(spacing: 4) {
                                    Image(systemName: "envelope.badge.shield.half.filled")
                                        .font(.system(size: 28))
                                        .foregroundColor(AppTheme.authTextPrimary)
                                        .frame(width: 48, height: 48)
                                        .background(AppTheme.navy.opacity(0.1))
                                        .cornerRadius(14)

                                    Text(L.otpStep2Title)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(AppTheme.authTextPrimary)
                                        .padding(.top, 6)

                                    Text(L.otpStep2Subtitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.authTextMuted)
                                        .multilineTextAlignment(.center)

                                    Text("\(selectedCountry.flag) \(selectedCountry.dialCode) \(formattedPhoneDisplay)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.authAccent)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 16)

                                // OTP sent success
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                    Text(L.otpSent)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                }
                                .foregroundColor(AppTheme.online)
                                .padding(12)
                                .background(AppTheme.online.opacity(0.08))
                                .cornerRadius(10)
                                .padding(.bottom, 16)

                                // OTP Field
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(L.otpLabel)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.authTextSecondary)

                                    HStack(spacing: 12) {
                                        Image(systemName: "lock.shield")
                                            .font(.system(size: 15))
                                            .foregroundColor(AppTheme.authTextMuted)
                                            .frame(width: 20)

                                        TextField(L.otpPlaceholder, text: $otpCode)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(AppTheme.authTextPrimary)
                                            .keyboardType(.numberPad)
                                            .tint(AppTheme.navy)
                                            .multilineTextAlignment(.center)
                                            .focused($focusedField, equals: .otp)
                                            .onChange(of: otpCode) {
                                                let filtered = otpCode.filter { $0.isNumber }
                                                if filtered.count > 6 { otpCode = String(filtered.prefix(6)) }
                                                else { otpCode = filtered }
                                            }
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(height: 56)
                                    .background(AppTheme.authField)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(focusedField == .otp ? AppTheme.navy : AppTheme.authBorder, lineWidth: focusedField == .otp ? 1.5 : 1)
                                    )
                                }
                                .padding(.bottom, 16)

                                // Remember Me (phone mode)
                                Button(action: { authVM.rememberMe.toggle() }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: authVM.rememberMe ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 16))
                                            .foregroundColor(authVM.rememberMe ? AppTheme.navy : AppTheme.authTextMuted)
                                        Text(L.rememberMe)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppTheme.authTextSecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 20)

                                // Verify OTP Button
                                Button(action: {
                                    focusedField = nil
                                    otpError = nil
                                    guard !otpCode.isEmpty else {
                                        otpError = L.otpRequired
                                        return
                                    }
                                    authVM.loginWithOTP(phone: phone, otp: otpCode) { success in
                                        if !success { otpError = L.otpInvalid }
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

                                // Resend code with cooldown
                                if resendCooldown > 0 {
                                    Text("\(L.resendCooldown) (\(resendCooldown)s)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.authTextMuted)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Button(action: {
                                        otpCode = ""; otpError = nil
                                        otpLoading = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                            otpLoading = false
                                            startCooldownTimer()
                                        }
                                    }) {
                                        Text(L.resendCode)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppTheme.authAccent)
                                    }
                                    .frame(maxWidth: .infinity)
                                }

                                // Back to phone number
                                Button(action: {
                                    cooldownTimer?.invalidate()
                                    cooldownTimer = nil
                                    resendCooldown = 0
                                    otpSent = false; otpCode = ""; otpError = nil
                                }) {
                                    Text(L.currentLang == "TR" ? "Numarayı Değiştir" : "Change Number")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AppTheme.authTextMuted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                            }
                        }

                        Spacer().frame(height: 20)

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(AppTheme.authBorder)
                                .frame(height: 1)
                            Text(L.orDivider)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.authTextMuted)
                            Rectangle()
                                .fill(AppTheme.authBorder)
                                .frame(height: 1)
                        }
                        .padding(.bottom, 20)

                        // Register Link
                        NavigationLink(destination: RegisterView()) {
                            HStack(spacing: 4) {
                                Text(L.noAccount)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.authTextMuted)
                                Text(L.register)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.authTextPrimary)
                            }
                        }
                        .buttonStyle(.plain)
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

                    // Footer
                    VStack(spacing: 4) {
                        Text(L.copyright)
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.72))
                        Text(L.version)
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.52))
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .tint(AppTheme.navy)
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

    // MARK: - Formatted phone helpers
    var formattedPhoneDisplay: String {
        CountryCode.formatPhone(phone, format: selectedCountry.format)
    }

    var phonePlaceholder: String {
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
        LoginViewBackup()
            .environmentObject(AuthViewModel())
    }
}
