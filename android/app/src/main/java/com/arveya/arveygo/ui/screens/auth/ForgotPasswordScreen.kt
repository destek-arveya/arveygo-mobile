package com.arveya.arveygo.ui.screens.auth

import androidx.compose.animation.*
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.ui.components.GradientButton
import com.arveya.arveygo.ui.components.LanguageSwitcher
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.utils.LoginStrings

@Composable
fun ForgotPasswordScreen(onBack: () -> Unit) {
    val authVM = LocalAuthViewModel.current
    val email by authVM.forgotEmail.collectAsState()
    val isLoading by authVM.isLoading.collectAsState()
    val errorMessage by authVM.errorMessage.collectAsState()
    val resetSent by authVM.resetSent.collectAsState()
    val focusManager = LocalFocusManager.current
    val currentLang by LoginStrings.currentLang.collectAsState()
    val L = LoginStrings

    LaunchedEffect(Unit) { authVM.clearForgotFields() }

    Box(
        modifier = Modifier.fillMaxSize().background(AppColors.Bg)
            .clickable(indication = null, interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }) { focusManager.clearFocus() }
    ) {
        Box(Modifier.size(400.dp).offset(x = (-120).dp, y = (-180).dp).clip(CircleShape).background(AppColors.Navy.copy(alpha = 0.03f)))
        Box(Modifier.size(300.dp).offset(x = 200.dp, y = 500.dp).clip(CircleShape).background(AppColors.Indigo.copy(alpha = 0.04f)))

        Column(
            modifier = Modifier.fillMaxSize().statusBarsPadding()
        ) {
            // Top bar
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.clickable { onBack() }) {
                    Icon(Icons.Default.ChevronLeft, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp))
                    Text(L.loginButton, fontSize = 13.sp, color = AppColors.TextMuted)
                }
                Spacer(Modifier.weight(1f))
                LanguageSwitcher()
            }

            Spacer(Modifier.weight(1f))

            // Card
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(horizontal = 16.dp).fillMaxWidth()
                    .shadow(6.dp, RoundedCornerShape(16.dp), ambientColor = AppColors.Navy.copy(alpha = 0.06f))
                    .background(AppColors.Surface, RoundedCornerShape(16.dp)).padding(22.dp)
            ) {
                // Icon
                Box(contentAlignment = Alignment.Center, modifier = Modifier.size(64.dp).clip(CircleShape).background(AppColors.Navy.copy(alpha = 0.06f))) {
                    Icon(Icons.Default.Key, null, tint = AppColors.Navy, modifier = Modifier.size(24.dp))
                }
                Spacer(Modifier.height(20.dp))

                AnimatedContent(targetState = resetSent, label = "forgot_state") { sent ->
                    if (sent) {
                        // Success
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Box(contentAlignment = Alignment.Center, modifier = Modifier.size(56.dp).clip(CircleShape).background(AppColors.Online.copy(alpha = 0.1f))) {
                                Icon(Icons.Default.CheckCircle, null, tint = AppColors.Online, modifier = Modifier.size(28.dp))
                            }
                            Spacer(Modifier.height(12.dp))
                            Text(L.t("Bağlantı Gönderildi!", "Link Sent!", "Enlace enviado", "Lien envoyé"), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                            Spacer(Modifier.height(8.dp))
                            Text(L.t("Şifre sıfırlama bağlantısı $email adresine gönderildi.", "Password reset link sent to $email.", "El enlace para restablecer la contraseña se envió a $email.", "Le lien de réinitialisation a été envoyé à $email."), fontSize = 13.sp, color = AppColors.TextMuted, modifier = Modifier.padding(horizontal = 8.dp))
                            Spacer(Modifier.height(16.dp))
                            Text(L.t("Giriş Sayfasına Dön", "Return to Login", "Volver al inicio de sesión", "Retour à la connexion"), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Indigo, modifier = Modifier.clickable { onBack() })
                        }
                    } else {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(L.forgotPassword, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                            Spacer(Modifier.height(6.dp))
                            Text(L.t("E-posta adresinize şifre sıfırlama bağlantısı göndereceğiz", "We'll send a password reset link to your email address", "Enviaremos un enlace de restablecimiento a tu correo electrónico", "Nous enverrons un lien de réinitialisation à votre adresse e-mail"), fontSize = 13.sp, color = AppColors.TextMuted)
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

                            Column(modifier = Modifier.fillMaxWidth()) {
                                Text(L.emailLabel, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
                                Spacer(Modifier.height(6.dp))
                                OutlinedTextField(
                                    value = email, onValueChange = { authVM.forgotEmail.value = it },
                                    placeholder = { Text(L.emailPlaceholder, fontSize = 14.sp) },
                                    leadingIcon = { Icon(Icons.Default.Email, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp)) },
                                    singleLine = true,
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AppColors.Navy, unfocusedBorderColor = AppColors.BorderSoft, focusedContainerColor = AppColors.Bg, unfocusedContainerColor = AppColors.Bg),
                                    shape = RoundedCornerShape(12.dp),
                                    modifier = Modifier.fillMaxWidth().height(50.dp)
                                )
                            }
                            Spacer(Modifier.height(24.dp))

                            GradientButton(
                                text = L.t("Sıfırlama Bağlantısı Gönder", "Send Reset Link", "Enviar enlace de restablecimiento", "Envoyer le lien"),
                                onClick = { focusManager.clearFocus(); authVM.sendResetLink() },
                                isLoading = isLoading,
                                icon = Icons.Default.Send,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.weight(1f))

            // Footer
            Text(L.copyright, fontSize = 10.sp, color = AppColors.TextFaint, modifier = Modifier.align(Alignment.CenterHorizontally).padding(bottom = 30.dp))
        }
    }
}
