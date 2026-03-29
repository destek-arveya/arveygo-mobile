package com.arveya.arveygo.ui.screens.settings

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.utils.DashboardStrings
import com.arveya.arveygo.utils.LoginStrings

private data class LangChip(val code: String, val flag: String)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(onMenuClick: () -> Unit) {
    var showNotifSettings by remember { mutableStateOf(false) }

    if (showNotifSettings) {
        NotificationSettingsScreen(onBack = { showNotifSettings = false })
        return
    }

    val currentLang by LoginStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    val dlLang by DashboardStrings.currentLang.collectAsState()

    val languages = listOf(
        LangChip("TR", "🇹🇷"),
        LangChip("EN", "🇬🇧"),
        LangChip("ES", "🇪🇸"),
        LangChip("FR", "🇫🇷")
    )

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onMenuClick) {
                        Icon(Icons.Default.Menu, null, tint = AppColors.Navy)
                    }
                },
                title = {
                    Text(DL.settingsTitle, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = AppColors.Surface)
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(AppColors.Bg)
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // ── GENEL ──
            SectionCard(title = DL.settingsTitle.uppercase()) {
                // Language — compact horizontal chips
                Column {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(start = 16.dp, top = 13.dp, bottom = 10.dp)
                    ) {
                        Icon(Icons.Default.Language, null, tint = AppColors.Indigo, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(10.dp))
                        Text(DL.languageLabel, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                    }

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 13.dp)
                    ) {
                        languages.forEach { lang ->
                            val selected = currentLang == lang.code
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(5.dp),
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(if (selected) AppColors.Indigo else AppColors.Bg)
                                    .clickable {
                                        LoginStrings.setLanguage(lang.code)
                                        DashboardStrings.setLanguage(lang.code)
                                    }
                                    .padding(horizontal = 12.dp, vertical = 7.dp)
                            ) {
                                Text(lang.flag, fontSize = 14.sp)
                                Text(
                                    lang.code,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (selected) Color.White else AppColors.Navy
                                )
                            }
                        }
                    }
                }

                HorizontalDivider(modifier = Modifier.padding(start = 52.dp))

                // Bildirim Ayarları
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showNotifSettings = true }
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                ) {
                    Icon(Icons.Default.NotificationsActive, null, tint = Color(0xFFEF4444), modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(DL.notificationSettings, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                        Text(DL.notificationSettingsSubtitle, fontSize = 11.sp, color = AppColors.TextMuted)
                    }
                    Icon(Icons.Default.ChevronRight, null, tint = AppColors.TextMuted.copy(alpha = 0.5f), modifier = Modifier.size(16.dp))
                }
            }

            // ── UYGULAMA BİLGİSİ ──
            SectionCard(title = DL.appInfoTitle.uppercase()) {
                InfoRow(Icons.Default.Apps, DL.appInfoApp, "ArveyGo v1.0.0")
                HorizontalDivider(modifier = Modifier.padding(start = 52.dp))
                InfoRow(Icons.Default.PhoneAndroid, DL.appInfoPlatform, "Android ${android.os.Build.VERSION.RELEASE}")
                HorizontalDivider(modifier = Modifier.padding(start = 52.dp))
                InfoRow(Icons.Default.Business, DL.appInfoDeveloper, "Arveya Teknoloji")
            }

            // ── YASAL ──
            SectionCard(title = DL.legalTitle.uppercase()) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { }
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                ) {
                    Icon(Icons.Default.Description, null, tint = AppColors.Indigo, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(10.dp))
                    Text(DL.termsOfUse, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy, modifier = Modifier.weight(1f))
                    Icon(Icons.Default.ChevronRight, null, tint = AppColors.TextMuted.copy(alpha = 0.5f), modifier = Modifier.size(16.dp))
                }
                HorizontalDivider(modifier = Modifier.padding(start = 52.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { }
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                ) {
                    Icon(Icons.Default.PrivacyTip, null, tint = AppColors.Indigo, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(10.dp))
                    Text(DL.privacyPolicy, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy, modifier = Modifier.weight(1f))
                    Icon(Icons.Default.ChevronRight, null, tint = AppColors.TextMuted.copy(alpha = 0.5f), modifier = Modifier.size(16.dp))
                }
            }

            // Footer
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 20.dp)
            ) {
                Text("© 2026 Arveya Teknoloji A.Ş.", fontSize = 11.sp, color = AppColors.TextMuted)
                Spacer(Modifier.height(4.dp))
                Text(DL.allRightsReserved, fontSize = 10.sp, color = AppColors.TextMuted.copy(alpha = 0.6f))
            }
        }
    }
}

@Composable
private fun SectionCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column {
        Text(
            title,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.TextMuted,
            letterSpacing = 0.5.sp,
            modifier = Modifier.padding(start = 4.dp, bottom = 8.dp)
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Surface, RoundedCornerShape(12.dp))
                .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
        ) {
            content()
        }
    }
}

@Composable
private fun InfoRow(icon: ImageVector, label: String, value: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(10.dp))
        Text(label, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
        Spacer(Modifier.weight(1f))
        Text(value, fontSize = 12.sp, color = AppColors.TextMuted)
    }
}
