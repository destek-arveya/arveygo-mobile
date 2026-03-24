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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.ui.components.GradientButton
import com.arveya.arveygo.ui.components.LanguageSwitcher
import com.arveya.arveygo.ui.theme.AppColors

@Composable
fun LoginScreen() {
    val authVM = LocalAuthViewModel.current
    val email by authVM.loginEmail.collectAsState()
    val password by authVM.loginPassword.collectAsState()
    val isLoading by authVM.isLoading.collectAsState()
    val errorMessage by authVM.errorMessage.collectAsState()

    var showRegister by remember { mutableStateOf(false) }
    var showForgot by remember { mutableStateOf(false) }
    var emailFocused by remember { mutableStateOf(false) }
    var passwordFocused by remember { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current

    LaunchedEffect(Unit) { authVM.clearLoginFields() }

    when {
        showRegister -> RegisterScreen(onBack = { showRegister = false })
        showForgot -> ForgotPasswordScreen(onBack = { showForgot = false })
        else -> {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(AppColors.Bg)
                    .clickable(indication = null, interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }) { focusManager.clearFocus() }
            ) {
                // Decorative circles
                Box(
                    modifier = Modifier
                        .size(400.dp)
                        .offset(x = (-100).dp, y = (-150).dp)
                        .clip(CircleShape)
                        .background(AppColors.Navy.copy(alpha = 0.03f))
                )
                Box(
                    modifier = Modifier
                        .size(300.dp)
                        .align(Alignment.BottomEnd)
                        .offset(x = 100.dp, y = 100.dp)
                        .clip(CircleShape)
                        .background(AppColors.Indigo.copy(alpha = 0.04f))
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
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier.size(52.dp).clip(RoundedCornerShape(14.dp)).background(AppColors.Navy)
                        ) {
                            Icon(Icons.Default.Navigation, null, tint = Color.White, modifier = Modifier.size(22.dp))
                        }
                        Spacer(Modifier.height(8.dp))
                        Text("ArveyGo", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                        Text("ARAÇ TAKİP SİSTEMİ", fontSize = 9.sp, fontWeight = FontWeight.Medium, color = AppColors.TextMuted, letterSpacing = 2.sp)
                    }

                    Spacer(Modifier.height(24.dp))

                    // Login Card
                    Column(
                        modifier = Modifier
                            .padding(horizontal = 16.dp)
                            .fillMaxWidth()
                            .shadow(6.dp, RoundedCornerShape(16.dp), ambientColor = AppColors.Navy.copy(alpha = 0.06f))
                            .background(AppColors.Surface, RoundedCornerShape(16.dp))
                            .padding(22.dp)
                    ) {
                        Text("Tekrar Hoş Geldiniz", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                        Spacer(Modifier.height(6.dp))
                        Text("Hesabınıza giriş yapın", fontSize = 13.sp, color = AppColors.TextMuted)
                        Spacer(Modifier.height(28.dp))

                        // Error
                        AnimatedVisibility(visible = errorMessage != null) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(Color.Red.copy(alpha = 0.06f), RoundedCornerShape(10.dp))
                                    .padding(12.dp)
                            ) {
                                Icon(Icons.Default.Error, null, tint = Color.Red, modifier = Modifier.size(14.dp))
                                Spacer(Modifier.width(8.dp))
                                Text(errorMessage ?: "", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Color.Red)
                            }
                        }
                        if (errorMessage != null) Spacer(Modifier.height(16.dp))

                        // Email
                        Text("E-posta", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
                        Spacer(Modifier.height(6.dp))
                        OutlinedTextField(
                            value = email,
                            onValueChange = { authVM.loginEmail.value = it },
                            placeholder = { Text("ornek@email.com", fontSize = 14.sp) },
                            leadingIcon = { Icon(Icons.Default.Email, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp)) },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = AppColors.Navy,
                                unfocusedBorderColor = AppColors.BorderSoft,
                                focusedContainerColor = AppColors.Bg,
                                unfocusedContainerColor = AppColors.Bg
                            ),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth().height(50.dp)
                        )

                        Spacer(Modifier.height(16.dp))

                        // Password
                        Text("Şifre", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
                        Spacer(Modifier.height(6.dp))
                        OutlinedTextField(
                            value = password,
                            onValueChange = { authVM.loginPassword.value = it },
                            placeholder = { Text("••••••••", fontSize = 14.sp) },
                            leadingIcon = { Icon(Icons.Default.Lock, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp)) },
                            visualTransformation = PasswordVisualTransformation(),
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                            keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus(); authVM.login() }),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = AppColors.Navy,
                                unfocusedBorderColor = AppColors.BorderSoft,
                                focusedContainerColor = AppColors.Bg,
                                unfocusedContainerColor = AppColors.Bg
                            ),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth().height(50.dp)
                        )

                        Spacer(Modifier.height(12.dp))

                        // Forgot password
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            Text(
                                "Şifremi Unuttum",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                color = AppColors.Indigo,
                                modifier = Modifier.clickable { showForgot = true }
                            )
                        }

                        Spacer(Modifier.height(24.dp))

                        // Login button
                        GradientButton(
                            text = "Giriş Yap",
                            onClick = { focusManager.clearFocus(); authVM.login() },
                            isLoading = isLoading,
                            icon = Icons.Default.ArrowForward,
                            modifier = Modifier.fillMaxWidth()
                        )

                        Spacer(Modifier.height(20.dp))

                        // Divider
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            HorizontalDivider(modifier = Modifier.weight(1f), color = AppColors.BorderSoft)
                            Text("veya", fontSize = 11.sp, fontWeight = FontWeight.Medium, color = AppColors.TextFaint, modifier = Modifier.padding(horizontal = 12.dp))
                            HorizontalDivider(modifier = Modifier.weight(1f), color = AppColors.BorderSoft)
                        }

                        Spacer(Modifier.height(20.dp))

                        // Register
                        Row(
                            horizontalArrangement = Arrangement.Center,
                            modifier = Modifier.fillMaxWidth().clickable { showRegister = true }
                        ) {
                            Text("Hesabınız yok mu? ", fontSize = 13.sp, color = AppColors.TextMuted)
                            Text("Kayıt Ol", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        }
                    }

                    Spacer(Modifier.height(16.dp))

                    // Footer
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                        Text("© 2026 Arveya Teknoloji", fontSize = 10.sp, color = AppColors.TextFaint)
                        Text("v1.0.0", fontSize = 9.sp, color = AppColors.TextFaint.copy(alpha = 0.6f))
                    }

                    Spacer(Modifier.height(20.dp))
                }
            }
        }
    }
}
