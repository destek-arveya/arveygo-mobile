package com.arveya.arveygo.ui.components

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
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
    val menuWidth = 300.dp

    AnimatedVisibility(
        visible = isShowing,
        enter = slideInHorizontally(initialOffsetX = { -it }) + fadeIn(initialAlpha = 0.5f),
        exit = slideOutHorizontally(targetOffsetX = { -it }) + fadeOut(targetAlpha = 0.5f)
    ) {
        Row(modifier = Modifier.fillMaxSize()) {
            // Menu panel
            Column(
                modifier = Modifier
                    .width(menuWidth)
                    .fillMaxHeight()
                    .shadow(24.dp, clip = false)
                    .background(AppColors.Surface)
            ) {
                // ── Premium Header ──
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            Brush.verticalGradient(
                                listOf(
                                    Color(0xFF0A1158),
                                    Color(0xFF090F41),
                                    Color(0xFF060B30)
                                )
                            )
                        )
                        .statusBarsPadding()
                        .padding(horizontal = 24.dp, vertical = 24.dp)
                ) {
                    Column {
                        // Profile row
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            // Avatar with gradient ring
                            Box(contentAlignment = Alignment.Center) {
                                Box(
                                    modifier = Modifier
                                        .size(52.dp)
                                        .clip(CircleShape)
                                        .background(
                                            Brush.linearGradient(
                                                listOf(
                                                    AppColors.Indigo,
                                                    AppColors.Lavender
                                                )
                                            )
                                        )
                                )
                                Box(
                                    modifier = Modifier
                                        .size(48.dp)
                                        .clip(CircleShape)
                                        .background(Color(0xFF1A2060)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = user?.avatar ?: "A",
                                        fontSize = 18.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color.White
                                    )
                                }
                            }

                            Spacer(Modifier.width(14.dp))

                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = user?.name ?: "Admin",
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                Spacer(Modifier.height(4.dp))
                                // Role badge
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(6.dp))
                                        .background(Color.White.copy(alpha = 0.12f))
                                        .padding(horizontal = 8.dp, vertical = 3.dp)
                                ) {
                                    Text(
                                        text = user?.role ?: "Süper Yönetici",
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = AppColors.Lavender,
                                        letterSpacing = 0.5.sp
                                    )
                                }
                            }
                        }

                        Spacer(Modifier.height(16.dp))

                        // Company info card
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(Color.White.copy(alpha = 0.08f))
                                .padding(horizontal = 12.dp, vertical = 10.dp)
                        ) {
                            Icon(
                                Icons.Default.Business, null,
                                tint = AppColors.Lavender.copy(alpha = 0.7f),
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                "Arveya Teknoloji",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                color = Color.White.copy(alpha = 0.6f)
                            )
                        }
                    }
                }

                // ── Menu Items ──
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState())
                        .padding(vertical = 12.dp)
                ) {
                    MenuSection("ANA MENÜ") {
                        MenuItem(Icons.Default.Dashboard, "Dashboard", AppPage.DASHBOARD, selectedPage, onPageSelected)
                        MenuItem(Icons.Default.Map, "Canlı Harita", AppPage.LIVE_MAP, selectedPage, onPageSelected)
                        MenuItem(Icons.Default.History, "Rota Geçmişi", AppPage.ROUTE_HISTORY, selectedPage, onPageSelected)
                    }
                    MenuSection("FİLO YÖNETİMİ") {
                        MenuItem(Icons.Default.DirectionsCar, "Araçlar", AppPage.VEHICLES, selectedPage, onPageSelected)
                        MenuItem(Icons.Default.People, "Sürücüler", AppPage.DRIVERS, selectedPage, onPageSelected)
                        MenuItem(Icons.Default.Build, "Bakım / Belgeler / Masraflar", AppPage.FLEET_MANAGEMENT, selectedPage, onPageSelected)
                    }
                    MenuSection("İZLEME") {
                        MenuItem(Icons.Default.Notifications, "Alarmlar", AppPage.ALARMS, selectedPage, onPageSelected)
                        MenuItem(Icons.Default.Hexagon, "Geofence", AppPage.GEOFENCES, selectedPage, onPageSelected)
                        MenuItem(Icons.Default.BarChart, "Raporlar", AppPage.REPORTS, selectedPage, onPageSelected)
                    }
                    MenuSection("AYARLAR") {
                        MenuItem(Icons.Default.Settings, "Ayarlar", AppPage.SETTINGS, selectedPage, onPageSelected)
                    }
                    MenuSection("DESTEK") {
                        MenuItem(Icons.Default.HelpOutline, "Destek Talebi", AppPage.SUPPORT, selectedPage, onPageSelected)
                    }

                    Spacer(Modifier.height(8.dp))

                    HorizontalDivider(
                        modifier = Modifier.padding(horizontal = 20.dp),
                        color = AppColors.BorderSoft.copy(alpha = 0.6f)
                    )

                    Spacer(Modifier.height(4.dp))

                    // Logout button — modern style
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .clickable { onLogout() }
                            .padding(horizontal = 14.dp, vertical = 14.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(34.dp)
                                .clip(RoundedCornerShape(9.dp))
                                .background(Color.Red.copy(alpha = 0.08f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.AutoMirrored.Filled.Logout, null,
                                tint = Color.Red.copy(alpha = 0.8f),
                                modifier = Modifier.size(16.dp)
                            )
                        }
                        Spacer(Modifier.width(12.dp))
                        Text(
                            "Çıkış Yap",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color.Red.copy(alpha = 0.8f)
                        )
                    }
                }

                // ── Version Footer ──
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 16.dp),
                    contentAlignment = Alignment.CenterStart
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(6.dp)
                                .clip(CircleShape)
                                .background(AppColors.Online)
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            "ArveyGo Android v1.0.0",
                            fontSize = 10.sp,
                            color = AppColors.TextFaint,
                            letterSpacing = 0.3.sp
                        )
                    }
                }
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

// ── Section Header ──
@Composable
private fun MenuSection(title: String, content: @Composable () -> Unit) {
    Column {
        Text(
            text = title,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.TextFaint.copy(alpha = 0.7f),
            letterSpacing = 1.2.sp,
            modifier = Modifier.padding(start = 24.dp, top = 20.dp, bottom = 8.dp)
        )
        content()
    }
}

// ── Menu Item ──
@Composable
private fun MenuItem(
    icon: ImageVector,
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
            .padding(horizontal = 12.dp, vertical = 2.dp)
            .clip(RoundedCornerShape(12.dp))
            .then(
                if (isActive) {
                    Modifier.background(
                        Brush.horizontalGradient(
                            listOf(
                                AppColors.Indigo.copy(alpha = 0.10f),
                                AppColors.Indigo.copy(alpha = 0.04f)
                            )
                        )
                    )
                } else {
                    Modifier.background(Color.Transparent)
                }
            )
            .clickable { page?.let { onSelect(it) } }
            .padding(horizontal = 12.dp, vertical = 12.dp)
    ) {
        // Icon with background box
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(RoundedCornerShape(9.dp))
                .background(
                    if (isActive) AppColors.Indigo.copy(alpha = 0.12f)
                    else AppColors.Bg
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                icon, null,
                tint = if (isActive) AppColors.Indigo else AppColors.TextMuted,
                modifier = Modifier.size(18.dp)
            )
        }

        Spacer(Modifier.width(12.dp))

        Text(
            label,
            fontSize = 14.sp,
            fontWeight = if (isActive) FontWeight.SemiBold else FontWeight.Normal,
            color = if (isActive) AppColors.Navy else AppColors.TextSecondary,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        if (isActive) {
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .height(20.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(AppColors.Indigo)
            )
        }
    }
}
