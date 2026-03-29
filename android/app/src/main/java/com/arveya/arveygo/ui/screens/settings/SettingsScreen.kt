package com.arveya.arveygo.ui.screens.settings

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
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

private data class LangItem(val code: String, val flag: String, val name: String)

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
    var isChangingLang by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()

    val languages = listOf(
        LangItem("TR", "🇹🇷", "Türkçe"),
        LangItem("EN", "🇬🇧", "English"),
        LangItem("ES", "🇪🇸", "Español"),
        LangItem("FR", "🇫🇷", "Français")
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
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(AppColors.Bg)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Language Section Header
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Language, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(8.dp))
                Text(DL.languageLabel.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted, letterSpacing = 1.sp)
            }

            // Language list
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            ) {
                languages.forEachIndexed { index, lang ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(enabled = !isChangingLang) {
                                if (currentLang != lang.code) {
                                    isChangingLang = true
                                    coroutineScope.launch {
                                        delay(600)
                                        LoginStrings.setLanguage(lang.code)
                                        DashboardStrings.setLanguage(lang.code)
                                        delay(300)
                                        isChangingLang = false
                                    }
                                }
                            }
                            .background(
                                if (currentLang == lang.code) AppColors.Indigo.copy(alpha = 0.06f)
                                else AppColors.Surface
                            )
                            .padding(horizontal = 16.dp, vertical = 14.dp)
                    ) {
                        Text(lang.flag, fontSize = 22.sp)
                        Spacer(Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(lang.name, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                            Text(lang.code, fontSize = 11.sp, color = AppColors.TextMuted)
                        }
                        if (currentLang == lang.code) {
                            Icon(Icons.Default.CheckCircle, null, tint = AppColors.Indigo, modifier = Modifier.size(20.dp))
                        } else {
                            Box(
                                modifier = Modifier
                                    .size(20.dp)
                                    .border(1.5.dp, AppColors.BorderSoft, CircleShape)
                            )
                        }
                    }
                    if (index < languages.size - 1) {
                        HorizontalDivider(modifier = Modifier.padding(start = 52.dp))
                    }
                }
            }

            // App Info Section
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Info, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(8.dp))
                Text(DL.appInfoTitle.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted, letterSpacing = 1.sp)
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            ) {
                SettingsInfoRow(Icons.Default.Apps, "ArveyGo", "v1.0.0")
                HorizontalDivider(modifier = Modifier.padding(start = 44.dp))
                SettingsInfoRow(Icons.Default.PhoneAndroid, "Platform", "Android")
                HorizontalDivider(modifier = Modifier.padding(start = 44.dp))
                SettingsInfoRow(Icons.Default.Business, "Arveya Teknoloji", "© 2026")
            }

            // Bildirim Ayarları Section
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.NotificationsActive, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(8.dp))
                Text("BİLDİRİM AYARLARI", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted, letterSpacing = 1.sp)
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
                    .clickable { showNotifSettings = true }
                    .padding(horizontal = 16.dp, vertical = 14.dp)
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(28.dp)
                        .background(AppColors.Indigo, RoundedCornerShape(7.dp))
                ) {
                    Icon(Icons.Default.NotificationsActive, null, tint = Color.White, modifier = Modifier.size(16.dp))
                }
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text("Bildirim Ayarları", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                    Text("Push bildirim, kategoriler ve sessiz saatler", fontSize = 11.sp, color = AppColors.TextMuted)
                }
                Icon(Icons.Default.ChevronRight, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp))
            }

            Spacer(Modifier.height(16.dp))
        }

        // Loading overlay
        if (isChangingLang) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.3f))
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier
                        .background(AppColors.Surface, RoundedCornerShape(16.dp))
                        .padding(28.dp)
                ) {
                    CircularProgressIndicator(
                        color = AppColors.Indigo,
                        modifier = Modifier.size(32.dp),
                        strokeWidth = 3.dp
                    )
                    Text(DL.languageLabel, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                }
            }
        }
        }
    }
}

@Composable
private fun SettingsInfoRow(icon: ImageVector, label: String, value: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp)
    ) {
        Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(12.dp))
        Text(label, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
        Spacer(Modifier.weight(1f))
        Text(value, fontSize = 12.sp, color = AppColors.TextMuted)
    }
}
