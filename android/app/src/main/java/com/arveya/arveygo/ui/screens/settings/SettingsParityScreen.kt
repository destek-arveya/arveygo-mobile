package com.arveya.arveygo.ui.screens.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.ui.theme.ThemeManager
import com.arveya.arveygo.ui.theme.ThemeMode
import com.arveya.arveygo.utils.DashboardStrings
import com.arveya.arveygo.utils.LoginStrings

private data class SettingsLangOption(val code: String, val flag: String, val label: String)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsParityScreen() {
    var showNotifSettings by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val currentLang by LoginStrings.currentLang.collectAsState()
    val DL = DashboardStrings

    val languages = listOf(
        SettingsLangOption("TR", "🇹🇷", "Türkçe"),
        SettingsLangOption("EN", "🇬🇧", "English"),
        SettingsLangOption("ES", "🇪🇸", "Español"),
        SettingsLangOption("FR", "🇫🇷", "Français")
    )

    if (showNotifSettings) {
        NotificationSettingsScreen(onBack = { showNotifSettings = false })
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(DL.settingsTitle, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                        Text("Tercihler ve uygulama ayarları", fontSize = 11.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background)
            )
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            HeroSettingsCard(currentLang = currentLang, themeMode = ThemeManager.mode)

            SettingsSectionCard("Tercihler", "Günlük kullanım için temel ayarlar") {
                SettingsSectionHeader(Icons.Default.Language, DL.languageLabel, "Arayüz dilini seç")
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    languages.chunked(2).forEach { rowItems ->
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                            rowItems.forEach { language ->
                                val isSelected = currentLang == language.code
                                Surface(
                                    onClick = {
                                        LoginStrings.setLanguage(language.code)
                                        DashboardStrings.setLanguage(language.code)
                                    },
                                    color = if (isSelected) AppColors.Navy else MaterialTheme.colorScheme.surfaceVariant,
                                    shape = RoundedCornerShape(18.dp),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 14.dp)
                                    ) {
                                        Text(language.flag, fontSize = 18.sp)
                                        Spacer(Modifier.width(10.dp))
                                        Column {
                                            Text(language.label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface)
                                            Text(language.code, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = if (isSelected) Color.White.copy(alpha = 0.78f) else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
                                        }
                                    }
                                }
                            }
                            if (rowItems.size == 1) Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                }

                HorizontalDivider(modifier = Modifier.padding(vertical = 18.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.35f))

                SettingsSectionHeader(Icons.Default.Palette, "Tema", "Uygulamanın görünüm modunu belirle")
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                    ThemeMode.entries.forEach { mode ->
                        val selected = ThemeManager.mode == mode
                        Surface(
                            onClick = { ThemeManager.setMode(context, mode) },
                            color = if (selected) AppColors.Navy else MaterialTheme.colorScheme.surfaceVariant,
                            shape = RoundedCornerShape(18.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Column(
                                verticalArrangement = Arrangement.spacedBy(6.dp),
                                modifier = Modifier.padding(horizontal = 14.dp, vertical = 14.dp)
                            ) {
                                Text(
                                    when (mode) {
                                        ThemeMode.LIGHT -> "☀️"
                                        ThemeMode.DARK -> "🌙"
                                        ThemeMode.SYSTEM -> "📱"
                                    },
                                    fontSize = 18.sp
                                )
                                Text(mode.title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = if (selected) Color.White else MaterialTheme.colorScheme.onSurface)
                                Text(
                                    when (mode) {
                                        ThemeMode.LIGHT -> "Her zaman açık görünüm"
                                        ThemeMode.DARK -> "Her zaman koyu görünüm"
                                        ThemeMode.SYSTEM -> "Telefon ayarını takip eder"
                                    },
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = if (selected) Color.White.copy(alpha = 0.78f) else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
                                )
                            }
                        }
                    }
                }
            }

            SettingsSectionCard("Uygulama", "Bildirim ve erişim tercihleri") {
                SettingsNavRow(Icons.Default.NotificationsActive, DL.notificationSettings, DL.notificationSettingsSubtitle) {
                    showNotifSettings = true
                }
            }

            SettingsSectionCard(DL.appInfoTitle, "Sürüm ve platform bilgileri") {
                InfoRow(Icons.Default.Apps, DL.appInfoApp, "ArveyGo v1.0.0")
                HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.35f))
                InfoRow(Icons.Default.PhoneAndroid, DL.appInfoPlatform, "Android ${android.os.Build.VERSION.RELEASE}")
                HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.35f))
                InfoRow(Icons.Default.Description, DL.appInfoDeveloper, "Arveya Teknoloji")
            }

            SettingsSectionCard(DL.legalTitle, "Yasal ve gizlilik dokümanları") {
                SettingsNavRow(Icons.Default.Description, DL.termsOfUse, "Hesap güvenliği ve kullanım şartları") { }
                HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.35f))
                SettingsNavRow(Icons.Default.PrivacyTip, DL.privacyPolicy, "Veri işleme ve gizlilik bilgileri") { }
            }

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 6.dp, bottom = 24.dp)
            ) {
                Text("© 2026 Arveya Teknoloji A.Ş.", fontSize = 11.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f))
                Spacer(Modifier.height(4.dp))
                Text(DL.allRightsReserved, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f))
            }
        }
    }
}

@Composable
private fun HeroSettingsCard(currentLang: String, themeMode: ThemeMode) {
    Card(
        shape = RoundedCornerShape(26.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Row(verticalAlignment = Alignment.Top) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(54.dp)
                        .background(
                            brush = Brush.linearGradient(listOf(AppColors.Navy, AppColors.Indigo)),
                            shape = RoundedCornerShape(18.dp)
                        )
                ) {
                    Icon(Icons.Default.Description, null, tint = Color.White, modifier = Modifier.size(22.dp))
                }
                Spacer(Modifier.width(14.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text("Kontrol ve kişiselleştirme", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                    Text("Dil, tema ve bildirim tercihlerini tek merkezden yönet.", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                SettingsStat("Dil", currentLang, Modifier.weight(1f))
                SettingsStat("Tema", themeMode.title, Modifier.weight(1f))
                SettingsStat("Sürüm", "1.0.0", Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun SettingsStat(title: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(16.dp))
            .padding(horizontal = 12.dp, vertical = 11.dp)
    ) {
        Text(title, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
        Text(value, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
private fun SettingsSectionCard(title: String, subtitle: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Column(modifier = Modifier.padding(horizontal = 4.dp)) {
            Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
            Text(subtitle, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
        }
        Card(
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(18.dp), content = content)
        }
    }
}

@Composable
private fun SettingsSectionHeader(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    detail: String
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(10.dp))
        Column {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
            Text(detail, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
        }
    }
}

@Composable
private fun SettingsNavRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp)
    ) {
        Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
            Text(subtitle, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
        }
        Icon(Icons.Default.ArrowForward, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f), modifier = Modifier.size(16.dp))
    }
}

@Composable
private fun InfoRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: String
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp)
    ) {
        Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(10.dp))
        Text(label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.weight(1f))
        Text(value, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
    }
}
