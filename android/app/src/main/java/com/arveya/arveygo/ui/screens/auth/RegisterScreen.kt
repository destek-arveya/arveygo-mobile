package com.arveya.arveygo.ui.screens.auth

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.R
import com.arveya.arveygo.ui.components.GradientButton
import com.arveya.arveygo.ui.components.LanguageSwitcher
import com.arveya.arveygo.ui.theme.AppColors
import androidx.compose.ui.res.painterResource
import com.arveya.arveygo.utils.LoginStrings

@Composable
fun RegisterScreen(onBack: () -> Unit) {
    val authVM = LocalAuthViewModel.current
    val name by authVM.registerName.collectAsState()
    val email by authVM.registerEmail.collectAsState()
    val password by authVM.registerPassword.collectAsState()
    val confirm by authVM.registerPasswordConfirm.collectAsState()
    val isLoading by authVM.isLoading.collectAsState()
    val errorMessage by authVM.errorMessage.collectAsState()
    val focusManager = LocalFocusManager.current
    val currentLang by LoginStrings.currentLang.collectAsState()
    val L = LoginStrings

    LaunchedEffect(Unit) { authVM.clearRegisterFields() }

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
        Box(Modifier.size(350.dp).align(Alignment.TopEnd).offset(x = 80.dp, y = (-100).dp).clip(CircleShape).background(Color.White.copy(alpha = 0.04f)))
        Box(Modifier.size(250.dp).align(Alignment.BottomStart).offset(x = (-80).dp, y = 50.dp).clip(CircleShape).background(AppColors.Lavender.copy(alpha = 0.10f)))

        Column(
            modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding()
        ) {
            // Top bar
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.clickable { onBack() }) {
                    Icon(Icons.Default.ChevronLeft, null, tint = Color.White.copy(alpha = 0.8f), modifier = Modifier.size(18.dp))
                    Text(L.loginButton, fontSize = 13.sp, color = Color.White.copy(alpha = 0.8f))
                }
                Spacer(Modifier.weight(1f))
                LanguageSwitcher()
            }

            // Logo
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Image(
                    painter = painterResource(R.drawable.logo_arveygo),
                    contentDescription = "ArveyGo Logo",
                    modifier = Modifier
                        .height(68.dp)
                        .clip(RoundedCornerShape(16.dp))
                )
                Spacer(Modifier.height(8.dp))
                Text("ArveyGo", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color.White)
                Text(L.t("Kurumsal kullanıcı hesabı oluştur", "Create your enterprise user account", "Crea tu cuenta corporativa", "Créez votre compte professionnel"), fontSize = 11.sp, fontWeight = FontWeight.Medium, color = Color.White.copy(alpha = 0.72f))
            }

            Spacer(Modifier.height(18.dp))

            // Card
            Column(
                modifier = Modifier.padding(horizontal = 16.dp).fillMaxWidth()
                    .shadow(10.dp, RoundedCornerShape(18.dp), ambientColor = Color.Black.copy(alpha = 0.25f))
                    .background(AppColors.Surface, RoundedCornerShape(16.dp)).padding(22.dp)
            ) {
                Text(L.t("Yeni Hesap Oluştur", "Create New Account", "Crear Cuenta Nueva", "Créer un compte"), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                Spacer(Modifier.height(6.dp))
                Text(L.t("Bilgilerinizi girerek kayıt olun", "Sign up by entering your details", "Regístrate ingresando tus datos", "Inscrivez-vous en saisissant vos informations"), fontSize = 13.sp, color = AppColors.TextMuted)
                Spacer(Modifier.height(24.dp))

                AnimatedVisibility(visible = errorMessage != null) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth().background(Color.Red.copy(alpha = 0.06f), RoundedCornerShape(10.dp)).padding(12.dp)
                    ) {
                        Icon(Icons.Default.Error, null, tint = Color.Red, modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(errorMessage ?: "", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Color.Red)
                    }
                }
                if (errorMessage != null) Spacer(Modifier.height(16.dp))

                // Name
                FormField(L.t("Ad Soyad", "Full Name", "Nombre completo", "Nom complet"), Icons.Default.Person, L.t("Adınız Soyadınız", "Your full name", "Tu nombre completo", "Votre nom complet"), name) { authVM.registerName.value = it }
                Spacer(Modifier.height(14.dp))

                // Email
                FormField(L.emailLabel, Icons.Default.Email, L.emailPlaceholder, email, KeyboardType.Email) { authVM.registerEmail.value = it }
                Spacer(Modifier.height(14.dp))

                // Password
                SecureFormField(L.passwordLabel, L.t("En az 8 karakter", "At least 8 characters", "Al menos 8 caracteres", "Au moins 8 caractères"), password) { authVM.registerPassword.value = it }
                Spacer(Modifier.height(14.dp))

                // Confirm
                SecureFormField(L.t("Şifre Tekrar", "Confirm Password", "Confirmar contraseña", "Confirmer le mot de passe"), L.t("Şifrenizi tekrar girin", "Enter your password again", "Ingresa tu contraseña nuevamente", "Saisissez à nouveau votre mot de passe"), confirm) { authVM.registerPasswordConfirm.value = it }
                Spacer(Modifier.height(24.dp))

                GradientButton(
                    text = L.register, onClick = { focusManager.clearFocus(); authVM.register() },
                    isLoading = isLoading, icon = Icons.Default.ArrowForward, modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(16.dp))

                Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth().clickable { onBack() }) {
                    Text("${L.noAccount} ", fontSize = 13.sp, color = AppColors.TextMuted)
                    Text(L.loginButton, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                }
            }

            Spacer(Modifier.height(20.dp))
        }
    }
}

@Composable
private fun FormField(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    placeholder: String,
    value: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    onValueChange: (String) -> Unit
) {
    Column {
        Text(label, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
        Spacer(Modifier.height(6.dp))
        OutlinedTextField(
            value = value, onValueChange = onValueChange,
            placeholder = { Text(placeholder, fontSize = 14.sp) },
            leadingIcon = { Icon(icon, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp)) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType, imeAction = ImeAction.Next),
            colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AppColors.Navy, unfocusedBorderColor = AppColors.BorderSoft, focusedContainerColor = AppColors.Bg, unfocusedContainerColor = AppColors.Bg),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth().height(50.dp)
        )
    }
}

@Composable
private fun SecureFormField(label: String, placeholder: String, value: String, onValueChange: (String) -> Unit) {
    Column {
        Text(label, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
        Spacer(Modifier.height(6.dp))
        OutlinedTextField(
            value = value, onValueChange = onValueChange,
            placeholder = { Text(placeholder, fontSize = 14.sp) },
            leadingIcon = { Icon(Icons.Default.Lock, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp)) },
            visualTransformation = PasswordVisualTransformation(),
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Next),
            colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AppColors.Navy, unfocusedBorderColor = AppColors.BorderSoft, focusedContainerColor = AppColors.Bg, unfocusedContainerColor = AppColors.Bg),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth().height(50.dp)
        )
    }
}
