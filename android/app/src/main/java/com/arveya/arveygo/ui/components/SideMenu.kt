package com.arveya.arveygo.ui.components

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.ui.navigation.AppPage
import com.arveya.arveygo.ui.theme.AppColors

@Composable
fun SideMenu(
    isShowing: Boolean,
    selectedPage: AppPage,
    onPageSelected: (AppPage) -> Unit,
    onClose: () -> Unit,
    onLogout: () -> Unit
) {
    val authVM = LocalAuthViewModel.current
    val user by authVM.currentUser.collectAsState()
    val menuWidth = 280.dp

    AnimatedVisibility(
        visible = isShowing,
        enter = slideInHorizontally(initialOffsetX = { -it }),
        exit = slideOutHorizontally(targetOffsetX = { -it })
    ) {
        Row(modifier = Modifier.fillMaxSize()) {
            // Menu panel — clean border, no shadow artifacts
            Column(
                modifier = Modifier
                    .width(menuWidth)
                    .fillMaxHeight()
                    .background(AppColors.Surface)
            ) {
                // Header with gradient
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Brush.linearGradient(listOf(Color(0xFF0D1550), AppColors.Navy)))
                        .statusBarsPadding()
                        .padding(horizontal = 20.dp, vertical = 20.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        AvatarCircle(initials = user?.avatar ?: "A", size = 44.dp)
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text(
                                user?.name ?: "Admin",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color.White
                            )
                            Text(
                                user?.role ?: "Süper Yönetici",
                                fontSize = 11.sp,
                                color = Color.White.copy(alpha = 0.6f)
                            )
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Default.Business, null,
                            tint = Color.White.copy(alpha = 0.5f),
                            modifier = Modifier.size(12.dp)
                        )
                        Spacer(Modifier.width(6.dp))
                        Text(
                            "Arveya Teknoloji",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color.White.copy(alpha = 0.5f)
                        )
                    }
                }

                // Scrollable menu items
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState())
                        .padding(vertical = 8.dp)
                ) {
                    MenuSection("ANA MENÜ") {
                        MenuItem(Icons.Default.Dashboard, "Dashboard", AppPage.DASHBOARD, selectedPage, onPageSelected)
                        MenuItem(Icons.Default.Map, "Canlı Harita", AppPage.LIVE_MAP, selectedPage, onPageSelected)
                        MenuItem(Icons.Default.History, "Rota Geçmişi", AppPage.ROUTE_HISTORY, selectedPage, onPageSelected)
                    }
                    MenuSection("FİLO YÖNETİMİ") {
                        MenuItem(Icons.Default.DirectionsCar, "Araçlar", AppPage.VEHICLES, selectedPage, onPageSelected)
                        MenuItem(Icons.Default.People, "Sürücüler", null, selectedPage) { onClose() }
                        MenuItem(Icons.Default.Build, "Bakım", null, selectedPage) { onClose() }
                        MenuItem(Icons.Default.Description, "Belgeler", null, selectedPage) { onClose() }
                        MenuItem(Icons.Default.AttachMoney, "Masraflar", null, selectedPage) { onClose() }
                    }
                    MenuSection("İZLEME") {
                        MenuItem(Icons.Default.Notifications, "Alarmlar", AppPage.ALARMS, selectedPage, onPageSelected)
                        MenuItem(Icons.Default.Hexagon, "Geofence", null, selectedPage) { onClose() }
                        MenuItem(Icons.Default.BarChart, "Raporlar", null, selectedPage) { onClose() }
                    }
                    MenuSection("AYARLAR") {
                        MenuItem(Icons.Default.Settings, "Ayarlar", AppPage.SETTINGS, selectedPage, onPageSelected)
                    }
                    MenuSection("DESTEK") {
                        MenuItem(Icons.Default.HelpOutline, "Destek Talebi", AppPage.SUPPORT, selectedPage, onPageSelected)
                    }

                    HorizontalDivider(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                        color = AppColors.BorderSoft
                    )

                    // Logout — minimum 48dp touch target
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onLogout() }
                            .padding(horizontal = 16.dp)
                            .heightIn(min = 48.dp),
                        horizontalArrangement = Arrangement.Start
                    ) {
                        Icon(
                            Icons.Default.Logout, null,
                            tint = Color.Red,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(Modifier.width(12.dp))
                        Text(
                            "Çıkış Yap",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color.Red
                        )
                    }
                }

                // Version
                Text(
                    "ArveyGo Android v1.0.0",
                    fontSize = 10.sp,
                    color = AppColors.TextFaint,
                    modifier = Modifier.padding(16.dp)
                )
            }

            // Tap area outside menu to close
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight()
                    .clickable(
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() }
                    ) { onClose() }
            )
        }
    }
}

@Composable
private fun MenuSection(title: String, content: @Composable () -> Unit) {
    Column {
        Text(
            text = title,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.TextFaint,
            letterSpacing = 1.sp,
            modifier = Modifier.padding(start = 16.dp, top = 16.dp, bottom = 6.dp)
        )
        content()
    }
}

@Composable
private fun MenuItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    page: AppPage?,
    selectedPage: AppPage,
    onSelect: (AppPage) -> Unit
) {
    val isActive = page != null && selectedPage == page
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(if (isActive) AppColors.Indigo.copy(alpha = 0.06f) else Color.Transparent)
            .clickable { page?.let { onSelect(it) } }
            .heightIn(min = 48.dp)
            .padding(horizontal = 12.dp)
    ) {
        Icon(
            icon, null,
            tint = if (isActive) AppColors.Indigo else AppColors.TextMuted,
            modifier = Modifier.size(20.dp)
        )
        Spacer(Modifier.width(12.dp))
        Text(
            label,
            fontSize = 14.sp,
            fontWeight = if (isActive) FontWeight.SemiBold else FontWeight.Normal,
            color = if (isActive) AppColors.Navy else AppColors.TextSecondary,
            modifier = Modifier.weight(1f)
        )
        if (isActive) {
            Box(Modifier.size(6.dp).clip(CircleShape).background(AppColors.Indigo))
        }
    }
}
