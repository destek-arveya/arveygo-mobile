package com.arveya.arveygo.ui.screens.auth

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.ui.components.GradientButton
import com.arveya.arveygo.ui.components.LanguageSwitcher
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.utils.LoginStrings
import androidx.compose.ui.res.painterResource
import com.arveya.arveygo.R
import com.arveya.arveygo.models.CountryCode
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun LoginScreen() {
    val authVM = LocalAuthViewModel.current
    val email by authVM.loginEmail.collectAsState()
    val password by authVM.loginPassword.collectAsState()
    val isLoading by authVM.isLoading.collectAsState()
    val errorMessage by authVM.errorMessage.collectAsState()
    val rememberMe by authVM.rememberMe.collectAsState()

    // Force recomposition when language changes
    val currentLang by LoginStrings.currentLang.collectAsState()
    val L = LoginStrings

    // Login mode: 0 = email, 1 = phone
    var loginMode by remember { mutableStateOf(0) }

    // Phone / OTP local state
    var phone by remember { mutableStateOf("") }
    var otpCode by remember { mutableStateOf("") }
    var otpSent by remember { mutableStateOf(false) }
    var otpError by remember { mutableStateOf<String?>(null) }
    var otpLoading by remember { mutableStateOf(false) }
    var resendCooldown by remember { mutableIntStateOf(0) }

    var selectedCountry by remember { mutableStateOf(CountryCode.all.first { it.id == "TR" }) }
    var showCountryPicker by remember { mutableStateOf(false) }

    var showRegister by remember { mutableStateOf(false) }
    var showForgot by remember { mutableStateOf(false) }
    var emailFocused by remember { mutableStateOf(false) }
    var passwordFocused by remember { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current
    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(Unit) { authVM.clearLoginFields() }

    when {
        showRegister -> RegisterScreen(onBack = { showRegister = false })
        showForgot -> ForgotPasswordScreen(onBack = { showForgot = false })
        else -> {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                AppColors.Navy,
                                Color(0xFF121B55),
                                Color(0xFF080C2A)
                            )
                        )
                    )
                    .clickable(indication = null, interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }) { focusManager.clearFocus() }
            ) {
                // Decorative circles
                Box(
                    modifier = Modifier
                        .size(400.dp)
                        .offset(x = (-100).dp, y = (-150).dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.04f))
                )
                Box(
                    modifier = Modifier
                        .size(300.dp)
                        .align(Alignment.BottomEnd)
                        .offset(x = 100.dp, y = 100.dp)
                        .clip(CircleShape)
                        .background(AppColors.Lavender.copy(alpha = 0.10f))
                )

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .statusBarsPadding()
                ) {
                    // Language switcher
                    Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                        Spacer(Modifier.weight(1f))
                        LanguageSwitcher()
                    }

                    Spacer(Modifier.height(20.dp))

                    // Logo
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                        Image(
                            painter = painterResource(R.drawable.logo_arveygo),
                            contentDescription = "ArveyGo Logo",
                            modifier = Modifier
                                .height(68.dp)
                                .clip(RoundedCornerShape(14.dp))
                        )
                        Spacer(Modifier.height(8.dp))
                        Text("ArveyGo", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color.White)
                        Text(L.t("Kurumsal filo operasyonlarına giriş", "Secure sign-in for enterprise fleet operations", "Acceso seguro para operaciones de flota empresarial", "Connexion sécurisée pour les opérations de flotte"), fontSize = 11.sp, fontWeight = FontWeight.Medium, color = Color.White.copy(alpha = 0.72f))
                    }

                    Spacer(Modifier.height(24.dp))

                    // Login Card
                    Column(
                        modifier = Modifier
                            .padding(horizontal = 16.dp)
                            .fillMaxWidth()
                            .shadow(10.dp, RoundedCornerShape(18.dp), ambientColor = Color.Black.copy(alpha = 0.25f))
                            .background(AppColors.Surface, RoundedCornerShape(16.dp))
                            .padding(22.dp)
                    ) {
                        Text(L.welcomeBack, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                        Spacer(Modifier.height(6.dp))
                        Text(L.t("Araçlar, alarmlar ve rota operasyonları için tek oturumla devam edin.", "Continue with one session for vehicles, alarms, and route operations.", "Continúa con una sola sesión para vehículos, alarmas y rutas.", "Continuez avec une seule session pour les véhicules, alarmes et itinéraires."), fontSize = 13.sp, color = AppColors.TextMuted)
                        Spacer(Modifier.height(20.dp))

                        // ═══ Tab Switcher: E-posta / Telefon ═══
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(AppColors.Bg, RoundedCornerShape(10.dp))
                                .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(10.dp))
                                .padding(3.dp)
                        ) {
                            listOf(0, 1).forEach { mode ->
                                val tabLabel = if (mode == 0) L.emailTab else L.phoneTab
                                val icon = if (mode == 0) Icons.Default.Email else Icons.Default.Phone
                                Box(
                                    contentAlignment = Alignment.Center,
                                    modifier = Modifier
                                        .weight(1f)
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(if (loginMode == mode) AppColors.Navy else Color.Transparent)
                                        .clickable { loginMode = mode; otpSent = false; otpError = null }
                                        .padding(vertical = 8.dp)
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                                        Icon(icon, null, tint = if (loginMode == mode) Color.White else AppColors.TextMuted, modifier = Modifier.size(14.dp))
                                        Spacer(Modifier.width(6.dp))
                                        Text(tabLabel, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = if (loginMode == mode) Color.White else AppColors.TextMuted)
                                    }
                                }
                            }
                        }

                        Spacer(Modifier.height(20.dp))

                        // Error
                        AnimatedVisibility(visible = (errorMessage != null || otpError != null)) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(Color.Red.copy(alpha = 0.06f), RoundedCornerShape(10.dp))
                                    .padding(12.dp)
                            ) {
                                Icon(Icons.Default.Error, null, tint = Color.Red, modifier = Modifier.size(14.dp))
                                Spacer(Modifier.width(8.dp))
                                Text(errorMessage ?: otpError ?: "", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Color.Red)
                            }
                        }
                        if (errorMessage != null || otpError != null) Spacer(Modifier.height(16.dp))

                        // ═══ EMAIL/PASSWORD MODE ═══
                        if (loginMode == 0) {
                            // Email
                            Text(L.emailLabel, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
                            Spacer(Modifier.height(6.dp))
                            OutlinedTextField(
                                value = email,
                                onValueChange = { authVM.loginEmail.value = it },
                                placeholder = { Text(L.emailPlaceholder, fontSize = 14.sp) },
                                leadingIcon = { Icon(Icons.Default.Email, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp)) },
                                singleLine = true,
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedBorderColor = AppColors.Navy,
                                    unfocusedBorderColor = AppColors.BorderSoft,
                                    focusedContainerColor = AppColors.Bg,
                                    unfocusedContainerColor = AppColors.Bg,
                                    focusedTextColor = AppColors.TextPrimary,
                                    unfocusedTextColor = AppColors.TextPrimary,
                                    cursorColor = AppColors.Navy
                                ),
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 56.dp)
                            )

                            Spacer(Modifier.height(16.dp))

                            // Password
                            Text(L.passwordLabel, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
                            Spacer(Modifier.height(6.dp))
                            OutlinedTextField(
                                value = password,
                                onValueChange = { authVM.loginPassword.value = it },
                                placeholder = { Text(L.passwordPlaceholder, fontSize = 14.sp) },
                                leadingIcon = { Icon(Icons.Default.Lock, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp)) },
                                visualTransformation = PasswordVisualTransformation(),
                                singleLine = true,
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                                keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus(); authVM.login() }),
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedBorderColor = AppColors.Navy,
                                    unfocusedBorderColor = AppColors.BorderSoft,
                                    focusedContainerColor = AppColors.Bg,
                                    unfocusedContainerColor = AppColors.Bg,
                                    focusedTextColor = AppColors.TextPrimary,
                                    unfocusedTextColor = AppColors.TextPrimary,
                                    cursorColor = AppColors.Navy
                                ),
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 56.dp)
                            )

                            Spacer(Modifier.height(12.dp))

                            // Remember Me + Forgot password
                            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.clickable { authVM.rememberMe.value = !rememberMe }
                                ) {
                                    Checkbox(
                                        checked = rememberMe,
                                        onCheckedChange = { authVM.rememberMe.value = it },
                                        colors = CheckboxDefaults.colors(
                                            checkedColor = AppColors.Navy,
                                            uncheckedColor = AppColors.TextMuted
                                        ),
                                        modifier = Modifier.size(20.dp)
                                    )
                                    Spacer(Modifier.width(6.dp))
                                    Text(L.rememberMe, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
                                }
                                Spacer(Modifier.weight(1f))
                                Text(
                                    L.forgotPassword,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = AppColors.Indigo,
                                    modifier = Modifier.clickable { showForgot = true }
                                )
                            }

                            Spacer(Modifier.height(24.dp))

                            // Login button
                            GradientButton(
                                text = L.loginButton,
                                onClick = { focusManager.clearFocus(); authVM.login() },
                                isLoading = isLoading,
                                icon = Icons.Default.ArrowForward,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }

                        // ═══ PHONE/OTP MODE ═══
                        if (loginMode == 1) {
                            if (!otpSent) {
                                // ── Step 1: Phone number entry ──
                                Text(L.phoneLabel, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
                                Spacer(Modifier.height(6.dp))

                                // Country code + Phone input row
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    // Country code picker button
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier
                                            .height(56.dp)
                                            .background(AppColors.Bg, RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp))
                                            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp))
                                            .clickable { showCountryPicker = true }
                                            .padding(horizontal = 10.dp)
                                    ) {
                                        Text(selectedCountry.flag, fontSize = 20.sp)
                                        Spacer(Modifier.width(4.dp))
                                        Text(selectedCountry.dialCode, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                                        Spacer(Modifier.width(2.dp))
                                        Icon(Icons.Default.ArrowDropDown, null, tint = AppColors.TextMuted, modifier = Modifier.size(16.dp))
                                    }

                                    // Phone number input
                                    OutlinedTextField(
                                        value = phone,
                                        onValueChange = { newValue ->
                                            val digits = newValue.filter { c -> c.isDigit() }
                                            phone = digits.take(selectedCountry.maxDigits)
                                        },
                                        placeholder = {
                                            Text(
                                                selectedCountry.format.replace('#', '0'),
                                                fontSize = 14.sp
                                            )
                                        },
                                        singleLine = true,
                                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
                                        colors = OutlinedTextFieldDefaults.colors(
                                            focusedBorderColor = AppColors.Navy,
                                            unfocusedBorderColor = AppColors.BorderSoft,
                                            focusedContainerColor = AppColors.Bg,
                                            unfocusedContainerColor = AppColors.Bg,
                                            focusedTextColor = AppColors.TextPrimary,
                                            unfocusedTextColor = AppColors.TextPrimary,
                                            cursorColor = AppColors.Navy
                                        ),
                                        shape = RoundedCornerShape(topEnd = 12.dp, bottomEnd = 12.dp),
                                        modifier = Modifier.weight(1f)
                                    )
                                }

                                // Formatted preview
                                if (phone.isNotEmpty()) {
                                    Text(
                                        CountryCode.formatPhone(phone, selectedCountry.format),
                                        fontSize = 11.sp,
                                        color = AppColors.TextMuted,
                                        modifier = Modifier.padding(start = 4.dp, top = 2.dp)
                                    )
                                }

                                Spacer(Modifier.height(16.dp))

                                // Send OTP button
                                GradientButton(
                                    text = L.sendOtp,
                                    onClick = {
                                        focusManager.clearFocus()
                                        otpError = null
                                        val cleanPhone = phone.replace(" ", "").replace("+", "")
                                        if (cleanPhone.length < 10) {
                                            otpError = L.phoneRequired
                                            return@GradientButton
                                        }
                                        otpLoading = true
                                        coroutineScope.launch {
                                            delay(800)
                                            otpLoading = false
                                            otpSent = true
                                            resendCooldown = 30
                                            // Start cooldown timer
                                            while (resendCooldown > 0) {
                                                delay(1000)
                                                resendCooldown--
                                            }
                                        }
                                    },
                                    isLoading = otpLoading,
                                    icon = Icons.Default.Send,
                                    modifier = Modifier.fillMaxWidth()
                                )
                            } else {
                                // ── Step 2: OTP Verification ──

                                // Step 2 header
                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
                                ) {
                                    Box(
                                        contentAlignment = Alignment.Center,
                                        modifier = Modifier
                                            .size(48.dp)
                                            .background(AppColors.Navy.copy(alpha = 0.1f), RoundedCornerShape(14.dp))
                                    ) {
                                        Icon(Icons.Default.MarkEmailRead, null, tint = AppColors.Navy, modifier = Modifier.size(24.dp))
                                    }
                                    Spacer(Modifier.height(10.dp))
                                    Text(L.otpStep2Title, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                                    Spacer(Modifier.height(4.dp))
                                    Text(L.otpStep2Subtitle, fontSize = 12.sp, color = AppColors.TextMuted, textAlign = TextAlign.Center)
                                    Spacer(Modifier.height(4.dp))
                                    Text(
                                        "${selectedCountry.flag} ${selectedCountry.dialCode} ${CountryCode.formatPhone(phone, selectedCountry.format)}",
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = AppColors.Indigo
                                    )
                                }

                                // OTP sent success message
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .background(AppColors.Online.copy(alpha = 0.08f), RoundedCornerShape(10.dp))
                                        .padding(12.dp)
                                ) {
                                    Icon(Icons.Default.CheckCircle, null, tint = AppColors.Online, modifier = Modifier.size(14.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text(L.otpSent, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.Online)
                                }

                                Spacer(Modifier.height(16.dp))

                                // OTP input
                                Text(L.otpLabel, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
                                Spacer(Modifier.height(6.dp))
                                OutlinedTextField(
                                    value = otpCode,
                                    onValueChange = { if (it.length <= 6) otpCode = it.filter { c -> c.isDigit() } },
                                    placeholder = { Text(L.otpPlaceholder, fontSize = 14.sp) },
                                    leadingIcon = { Icon(Icons.Default.Lock, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp)) },
                                    singleLine = true,
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
                                    keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
                                    colors = OutlinedTextFieldDefaults.colors(
                                        focusedBorderColor = AppColors.Navy,
                                        unfocusedBorderColor = AppColors.BorderSoft,
                                        focusedContainerColor = AppColors.Bg,
                                        unfocusedContainerColor = AppColors.Bg,
                                        focusedTextColor = AppColors.TextPrimary,
                                        unfocusedTextColor = AppColors.TextPrimary,
                                        cursorColor = AppColors.Navy
                                    ),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.fillMaxWidth(),
                                    textStyle = androidx.compose.ui.text.TextStyle(
                                        fontSize = 18.sp,
                                        fontWeight = FontWeight.Bold,
                                        letterSpacing = 8.sp,
                                        textAlign = TextAlign.Center
                                    )
                                )

                                Spacer(Modifier.height(16.dp))

                                // Remember Me (phone mode)
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.clickable { authVM.rememberMe.value = !rememberMe }
                                ) {
                                    Checkbox(
                                        checked = rememberMe,
                                        onCheckedChange = { authVM.rememberMe.value = it },
                                        colors = CheckboxDefaults.colors(
                                            checkedColor = AppColors.Navy,
                                            uncheckedColor = AppColors.TextMuted
                                        ),
                                        modifier = Modifier.size(20.dp)
                                    )
                                    Spacer(Modifier.width(6.dp))
                                    Text(L.rememberMe, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
                                }

                                Spacer(Modifier.height(20.dp))

                                // Verify OTP button
                                GradientButton(
                                    text = L.loginButton,
                                    onClick = {
                                        focusManager.clearFocus()
                                        otpError = null
                                        if (otpCode.isEmpty()) {
                                            otpError = L.otpRequired
                                            return@GradientButton
                                        }
                                        authVM.loginWithOTP(phone, otpCode) { success ->
                                            if (!success) otpError = L.otpInvalid
                                        }
                                    },
                                    isLoading = isLoading,
                                    icon = Icons.Default.ArrowForward,
                                    modifier = Modifier.fillMaxWidth()
                                )

                                Spacer(Modifier.height(12.dp))

                                // Resend code with cooldown
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                                    if (resendCooldown > 0) {
                                        Text(
                                            "${L.resendCooldown} (${resendCooldown}s)",
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = AppColors.TextFaint
                                        )
                                    } else {
                                        Text(
                                            L.resendCode,
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = AppColors.Indigo,
                                            modifier = Modifier.clickable {
                                                otpCode = ""; otpError = null
                                                otpLoading = true
                                                coroutineScope.launch {
                                                    delay(800)
                                                    otpLoading = false
                                                    resendCooldown = 30
                                                    while (resendCooldown > 0) {
                                                        delay(1000)
                                                        resendCooldown--
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }

                                Spacer(Modifier.height(8.dp))

                                // Back to phone number
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                                    Text(
                                        L.t("Numarayı Değiştir", "Change Number", "Cambiar número", "Changer le numéro"),
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = AppColors.TextMuted,
                                        modifier = Modifier.clickable {
                                            otpSent = false; otpCode = ""; otpError = null; resendCooldown = 0
                                        }
                                    )
                                }
                            }
                        }

                        Spacer(Modifier.height(20.dp))

                        // Divider
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            HorizontalDivider(modifier = Modifier.weight(1f), color = AppColors.BorderSoft)
                            Text(L.orDivider, fontSize = 11.sp, fontWeight = FontWeight.Medium, color = AppColors.TextFaint, modifier = Modifier.padding(horizontal = 12.dp))
                            HorizontalDivider(modifier = Modifier.weight(1f), color = AppColors.BorderSoft)
                        }

                        Spacer(Modifier.height(20.dp))

                        // Register
                        Row(
                            horizontalArrangement = Arrangement.Center,
                            modifier = Modifier.fillMaxWidth().clickable { showRegister = true }
                        ) {
                            Text("${L.noAccount} ", fontSize = 13.sp, color = AppColors.TextMuted)
                            Text(L.register, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        }
                    }

                    Spacer(Modifier.height(16.dp))

                    // Footer
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                        Text(L.copyright, fontSize = 10.sp, color = AppColors.TextFaint)
                        Text(L.version, fontSize = 9.sp, color = AppColors.TextFaint.copy(alpha = 0.6f))
                    }

                    Spacer(Modifier.height(20.dp))
                }

                // Country Code Picker Dialog
                if (showCountryPicker) {
                    CountryPickerDialog(
                        countries = CountryCode.all,
                        selected = selectedCountry,
                        onSelect = { selectedCountry = it; showCountryPicker = false },
                        onDismiss = { showCountryPicker = false }
                    )
                }
            }
        }
    }
}

@Composable
private fun CountryPickerDialog(
    countries: List<CountryCode>,
    selected: CountryCode,
    onSelect: (CountryCode) -> Unit,
    onDismiss: () -> Unit
) {
    var searchText by remember { mutableStateOf("") }
    val filtered = if (searchText.isEmpty()) countries
    else countries.filter {
        it.name.contains(searchText, ignoreCase = true) ||
        it.dialCode.contains(searchText) ||
        it.id.contains(searchText, ignoreCase = true)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {},
        title = {
            Text(LoginStrings.t("Ülke Kodu", "Country Code", "Código de país", "Indicatif"), fontSize = 16.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
        },
        text = {
            Column(modifier = Modifier.fillMaxWidth().height(400.dp)) {
                // Search
                OutlinedTextField(
                    value = searchText,
                    onValueChange = { searchText = it },
                    placeholder = { Text(LoginStrings.t("Ülke ara", "Search country", "Buscar país", "Rechercher un pays"), fontSize = 13.sp) },
                    leadingIcon = { Icon(Icons.Default.Search, null, modifier = Modifier.size(16.dp)) },
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AppColors.Navy,
                        unfocusedBorderColor = AppColors.BorderSoft,
                        cursorColor = AppColors.Navy
                    )
                )
                Spacer(Modifier.height(8.dp))

                // List
                Column(modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState())) {
                    filtered.forEach { country ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(if (country.id == selected.id) AppColors.Navy.copy(alpha = 0.08f) else Color.Transparent)
                                .clickable { onSelect(country) }
                                .padding(horizontal = 12.dp, vertical = 10.dp)
                        ) {
                            Text(country.flag, fontSize = 22.sp)
                            Spacer(Modifier.width(10.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(country.name, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.TextPrimary)
                                Text(country.dialCode, fontSize = 11.sp, color = AppColors.TextMuted)
                            }
                            if (country.id == selected.id) {
                                Icon(Icons.Default.CheckCircle, null, tint = AppColors.Navy, modifier = Modifier.size(18.dp))
                            }
                        }
                    }
                }
            }
        },
        containerColor = AppColors.Surface,
        shape = RoundedCornerShape(16.dp)
    )
}
