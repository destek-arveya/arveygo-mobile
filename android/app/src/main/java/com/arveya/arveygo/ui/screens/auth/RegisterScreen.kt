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
fun RegisterScreen(onBack: () -> Unit) {
    val authVM = LocalAuthViewModel.current
    val name by authVM.registerName.collectAsState()
    val email by authVM.registerEmail.collectAsState()
    val password by authVM.registerPassword.collectAsState()
    val confirm by authVM.registerPasswordConfirm.collectAsState()
    val isLoading by authVM.isLoading.collectAsState()
    val errorMessage by authVM.errorMessage.collectAsState()
    val focusManager = LocalFocusManager.current

    LaunchedEffect(Unit) { authVM.clearRegisterFields() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
            .clickable(indication = null, interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }) { focusManager.clearFocus() }
    ) {
        Box(Modifier.size(350.dp).align(Alignment.TopEnd).offset(x = 80.dp, y = (-100).dp).clip(CircleShape).background(AppColors.Indigo.copy(alpha = 0.04f)))
        Box(Modifier.size(250.dp).align(Alignment.BottomStart).offset(x = (-80).dp, y = 50.dp).clip(CircleShape).background(AppColors.Navy.copy(alpha = 0.03f)))

        Column(
            modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding()
        ) {
            // Top bar
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.clickable { onBack() }) {
                    Icon(Icons.Default.ChevronLeft, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp))
                    Text("Giriş Yap", fontSize = 13.sp, color = AppColors.TextMuted)
                }
                Spacer(Modifier.weight(1f))
                LanguageSwitcher()
            }

            // Logo
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Box(contentAlignment = Alignment.Center, modifier = Modifier.size(52.dp).clip(RoundedCornerShape(14.dp)).background(AppColors.Navy)) {
                    Icon(Icons.Default.Navigation, null, tint = Color.White, modifier = Modifier.size(22.dp))
                }
                Spacer(Modifier.height(8.dp))
                Text("ArveyGo", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                Text("ARAÇ TAKİP SİSTEMİ", fontSize = 9.sp, fontWeight = FontWeight.Medium, color = AppColors.TextMuted, letterSpacing = 2.sp)
            }

            Spacer(Modifier.height(18.dp))

            // Card
            Column(
                modifier = Modifier.padding(horizontal = 16.dp).fillMaxWidth()
                    .shadow(6.dp, RoundedCornerShape(16.dp), ambientColor = AppColors.Navy.copy(alpha = 0.06f))
                    .background(AppColors.Surface, RoundedCornerShape(16.dp)).padding(22.dp)
            ) {
                Text("Yeni Hesap Oluştur", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                Spacer(Modifier.height(6.dp))
                Text("Bilgilerinizi girerek kayıt olun", fontSize = 13.sp, color = AppColors.TextMuted)
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
                FormField("Ad Soyad", Icons.Default.Person, "Adınız Soyadınız", name) { authVM.registerName.value = it }
                Spacer(Modifier.height(14.dp))

                // Email
                FormField("E-posta", Icons.Default.Email, "ornek@email.com", email, KeyboardType.Email) { authVM.registerEmail.value = it }
                Spacer(Modifier.height(14.dp))

                // Password
                SecureFormField("Şifre", "En az 8 karakter", password) { authVM.registerPassword.value = it }
                Spacer(Modifier.height(14.dp))

                // Confirm
                SecureFormField("Şifre Tekrar", "Şifrenizi tekrar girin", confirm) { authVM.registerPasswordConfirm.value = it }
                Spacer(Modifier.height(24.dp))

                GradientButton(
                    text = "Kayıt Ol", onClick = { focusManager.clearFocus(); authVM.register() },
                    isLoading = isLoading, icon = Icons.Default.ArrowForward, modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(16.dp))

                Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth().clickable { onBack() }) {
                    Text("Zaten hesabınız var mı? ", fontSize = 13.sp, color = AppColors.TextMuted)
                    Text("Giriş Yap", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
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
