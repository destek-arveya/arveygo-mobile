package com.arveya.arveygo

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.ui.navigation.AppPage
import com.arveya.arveygo.ui.screens.auth.LoginScreen
import com.arveya.arveygo.ui.screens.dashboard.DashboardScreen
import com.arveya.arveygo.ui.screens.fleet.AlarmsScreen
import com.arveya.arveygo.ui.screens.fleet.DriversScreen
import com.arveya.arveygo.ui.screens.fleet.FleetManagementScreen
import com.arveya.arveygo.ui.screens.fleet.GeofencesScreen
import com.arveya.arveygo.ui.screens.fleet.RouteHistoryScreen
import com.arveya.arveygo.ui.screens.fleet.VehiclesListScreen
import com.arveya.arveygo.ui.screens.fleet.ReportsScreen
import com.arveya.arveygo.ui.screens.livemap.LiveMapScreen
import com.arveya.arveygo.ui.screens.settings.SettingsScreen
import com.arveya.arveygo.ui.screens.support.SupportRequestScreen
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.viewmodels.AuthViewModel
import com.arveya.arveygo.services.WebSocketManager

// ═══════════════════════════════════════════════════════════════════════════
// Bottom Tab Enum (matches iOS AppTab)
// ═══════════════════════════════════════════════════════════════════════════
enum class AppTab(val label: String) {
    DASHBOARD("Özet"),
    ALARMS("Alarmlar"),
    LIVE_MAP("Harita"),
    FLEET("Filo"),
    HUB("Hub")
}

@Composable
fun ArveyGoApp(authVM: AuthViewModel) {
    val isLoggedIn by authVM.isLoggedIn.collectAsState()

    AnimatedContent(
        targetState = isLoggedIn,
        transitionSpec = {
            if (targetState) {
                slideInHorizontally { it } + fadeIn() togetherWith
                        slideOutHorizontally { -it } + fadeOut()
            } else {
                slideInHorizontally { -it } + fadeIn() togetherWith
                        slideOutHorizontally { it } + fadeOut()
            }
        },
        label = "auth_transition"
    ) { loggedIn ->
        if (loggedIn) {
            MainContent(authVM = authVM)
        } else {
            LoginScreen()
        }
    }
}

@Composable
fun MainContent(authVM: AuthViewModel) {
    var selectedTab by remember { mutableStateOf(AppTab.DASHBOARD) }
    var selectedPage by remember { mutableStateOf(AppPage.DASHBOARD) }
    var showSupportRequest by remember { mutableStateOf(false) }
    var alarmsSearchText by remember { mutableStateOf("") }
    var alarmsAutoOpenCreate by remember { mutableStateOf(false) }
    var alarmsPrePlate by remember { mutableStateOf("") }

    // Observe consecutive failures to trigger support request page
    val consecutiveFailures by WebSocketManager.consecutiveFailures.collectAsState()
    LaunchedEffect(consecutiveFailures) {
        if (consecutiveFailures >= WebSocketManager.MAX_CONSECUTIVE_FAILURES) {
            showSupportRequest = true
        }
    }

    // Sync selectedPage → selectedTab
    LaunchedEffect(selectedPage) {
        when (selectedPage) {
            AppPage.DASHBOARD -> selectedTab = AppTab.DASHBOARD
            AppPage.ALARMS -> selectedTab = AppTab.ALARMS
            AppPage.LIVE_MAP -> selectedTab = AppTab.LIVE_MAP
            AppPage.FLEET_MANAGEMENT -> selectedTab = AppTab.FLEET
            else -> { /* Hub sub-pages don't change tab */ }
        }
    }

    // If support request is showing, overlay it
    if (showSupportRequest) {
        SupportRequestScreen(onBack = { showSupportRequest = false })
        return
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // ── Active Page Content (fills remaining space) ──
        Box(modifier = Modifier.weight(1f)) {
            when (selectedTab) {
                AppTab.DASHBOARD -> DashboardScreen(
                    onNavigateToMap = { selectedTab = AppTab.LIVE_MAP },
                    onNavigateToVehicles = { selectedPage = AppPage.VEHICLES; selectedTab = AppTab.HUB },
                    onNavigateToDrivers = { selectedPage = AppPage.DRIVERS; selectedTab = AppTab.HUB },
                    onNavigateToAlarms = { searchText -> alarmsSearchText = searchText; alarmsAutoOpenCreate = false; alarmsPrePlate = ""; selectedTab = AppTab.ALARMS },
                    onNavigateToAddAlarm = { plate -> alarmsSearchText = ""; alarmsAutoOpenCreate = true; alarmsPrePlate = plate; selectedTab = AppTab.ALARMS },
                    onNavigateToRouteHistory = { selectedPage = AppPage.ROUTE_HISTORY; selectedTab = AppTab.HUB }
                )
                AppTab.ALARMS -> AlarmsScreen(
                    initialSearchText = alarmsSearchText,
                    autoOpenCreate = alarmsAutoOpenCreate,
                    preSelectedPlate = alarmsPrePlate
                )
                AppTab.LIVE_MAP -> LiveMapScreen(
                    onNavigateToRouteHistory = { _ -> selectedPage = AppPage.ROUTE_HISTORY; selectedTab = AppTab.HUB },
                    onNavigateToAlarms = { alarmsSearchText = ""; alarmsAutoOpenCreate = false; alarmsPrePlate = ""; selectedTab = AppTab.ALARMS },
                    onNavigateToAddAlarm = { plate -> alarmsSearchText = ""; alarmsAutoOpenCreate = true; alarmsPrePlate = plate; selectedTab = AppTab.ALARMS }
                )
                AppTab.FLEET -> FleetManagementScreen()
                AppTab.HUB -> HubScreen(
                    selectedPage = selectedPage,
                    onPageSelected = { selectedPage = it },
                    onLogout = { authVM.logout() }
                )
            }
        }

        // ── Bottom Tab Bar (flush, edge-to-edge) ──
        BottomTabBar(
            selectedTab = selectedTab,
            onTabSelected = { tab ->
                if (selectedTab == AppTab.ALARMS && tab != AppTab.ALARMS) {
                    alarmsSearchText = ""
                    alarmsAutoOpenCreate = false
                    alarmsPrePlate = ""
                }
                selectedTab = tab
            }
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Hub Screen — shows sub-pages (Vehicles, Drivers, RouteHistory, etc.)
// ═══════════════════════════════════════════════════════════════════════════
@Composable
fun HubScreen(
    selectedPage: AppPage,
    onPageSelected: (AppPage) -> Unit,
    onLogout: () -> Unit
) {
    when (selectedPage) {
        AppPage.VEHICLES -> VehiclesListScreen(
            onNavigateToRouteHistory = { _ -> onPageSelected(AppPage.ROUTE_HISTORY) },
            onNavigateToAlarms = { onPageSelected(AppPage.ALARMS) },
            onNavigateToAddAlarm = { _ -> onPageSelected(AppPage.ALARMS) }
        )
        AppPage.DRIVERS -> DriversScreen()
        AppPage.ROUTE_HISTORY -> RouteHistoryScreen()
        AppPage.GEOFENCES -> GeofencesScreen()
        AppPage.REPORTS -> ReportsScreen()
        AppPage.SETTINGS -> SettingsScreen()
        AppPage.SUPPORT -> SupportRequestScreen(onBack = { onPageSelected(AppPage.DASHBOARD) })
        else -> {
            // Default Hub grid (like iOS HubView)
            HubGridView(
                onNavigate = { onPageSelected(it) },
                onLogout = onLogout
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Hub Grid View — Grid of sub-page cards
// ═══════════════════════════════════════════════════════════════════════════
@Composable
fun HubGridView(onNavigate: (AppPage) -> Unit, onLogout: () -> Unit) {
    val authVM = LocalAuthViewModel.current
    val user by authVM.currentUser.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        // Top bar
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surface)
                .padding(horizontal = 20.dp, vertical = 14.dp)
                .statusBarsPadding()
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Hub",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    user?.name ?: "Admin",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                )
            }
        }

        // Grid
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp), modifier = Modifier.fillMaxWidth()) {
                HubCard("Raporlar", Icons.Default.BarChart, Color(0xFF6366F1), Modifier.weight(1f)) { onNavigate(AppPage.REPORTS) }
                HubCard("Geofence", Icons.Default.LocationOn, Color(0xFF10B981), Modifier.weight(1f)) { onNavigate(AppPage.GEOFENCES) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp), modifier = Modifier.fillMaxWidth()) {
                HubCard("Rota Geçmişi", Icons.Default.History, Color(0xFFF59E0B), Modifier.weight(1f)) { onNavigate(AppPage.ROUTE_HISTORY) }
                HubCard("Sürücüler", Icons.Default.People, Color(0xFF3B93F1), Modifier.weight(1f)) { onNavigate(AppPage.DRIVERS) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp), modifier = Modifier.fillMaxWidth()) {
                HubCard("Araçlar", Icons.Default.DirectionsCar, Color(0xFF8B5CF6), Modifier.weight(1f)) { onNavigate(AppPage.VEHICLES) }
                HubCard("Ayarlar", Icons.Default.Settings, Color(0xFF64748B), Modifier.weight(1f)) { onNavigate(AppPage.SETTINGS) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp), modifier = Modifier.fillMaxWidth()) {
                HubCard("Destek", Icons.Default.SupportAgent, Color(0xFFEC4899), Modifier.weight(1f)) { onNavigate(AppPage.SUPPORT) }
                Box(modifier = Modifier.weight(1f)) // empty cell
            }

            Spacer(Modifier.weight(1f))

            // Logout
            Button(
                onClick = onLogout,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFEF4444).copy(alpha = 0.08f)),
                shape = MaterialTheme.shapes.medium,
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(Icons.Default.Logout, null, tint = Color(0xFFEF4444), modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(8.dp))
                Text("Çıkış Yap", color = Color(0xFFEF4444), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            }
        }
    }
}

@Composable
private fun HubCard(title: String, icon: ImageVector, color: Color, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = modifier
            .aspectRatio(1.2f)
            .background(MaterialTheme.colorScheme.surface, MaterialTheme.shapes.medium)
            .clickable { onClick() }
            .padding(16.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(44.dp)
                .background(color.copy(alpha = 0.1f), CircleShape)
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(22.dp))
        }
        Spacer(Modifier.height(10.dp))
        Text(
            title,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom Tab Bar (matches iOS flush tab bar)
// ═══════════════════════════════════════════════════════════════════════════
@Composable
fun BottomTabBar(selectedTab: AppTab, onTabSelected: (AppTab) -> Unit) {
    // Uygulamanın dark-first tasarımına uygun sabit dark renk paleti
    val activeColor   = Color(0xFF8B95E0)   // lavender
    val inactiveColor = Color(0xFF50546E)
    val bgColor       = Color(0xFF10132A)   // darkBg tonu
    val dividerColor  = Color.White.copy(alpha = 0.06f)

    Column {
        // Top separator
        HorizontalDivider(
            thickness = 0.5.dp,
            color = dividerColor
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(bgColor)
                .navigationBarsPadding()
                .padding(top = 6.dp, bottom = 2.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Dashboard tab
            TabItem(
                icon = Icons.Default.GridView,
                label = "Özet",
                isActive = selectedTab == AppTab.DASHBOARD,
                activeColor = activeColor,
                inactiveColor = inactiveColor,
                onClick = { onTabSelected(AppTab.DASHBOARD) }
            )

            // Alarms tab
            TabItem(
                icon = Icons.Default.Notifications,
                label = "Alarmlar",
                isActive = selectedTab == AppTab.ALARMS,
                activeColor = activeColor,
                inactiveColor = inactiveColor,
                onClick = { onTabSelected(AppTab.ALARMS) }
            )

            // Center Map tab — elevated circle
            MapCenterTab(
                isActive = selectedTab == AppTab.LIVE_MAP,
                onClick = { onTabSelected(AppTab.LIVE_MAP) }
            )

            // Fleet tab
            TabItem(
                icon = Icons.Default.Build,
                label = "Filo",
                isActive = selectedTab == AppTab.FLEET,
                activeColor = activeColor,
                inactiveColor = inactiveColor,
                onClick = { onTabSelected(AppTab.FLEET) }
            )

            // Hub tab
            TabItem(
                icon = Icons.Default.Apps,
                label = "Hub",
                isActive = selectedTab == AppTab.HUB,
                activeColor = activeColor,
                inactiveColor = inactiveColor,
                onClick = { onTabSelected(AppTab.HUB) }
            )
        }
    }
}

@Composable
private fun TabItem(
    icon: ImageVector,
    label: String,
    isActive: Boolean,
    activeColor: Color,
    inactiveColor: Color,
    onClick: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() }
            ) { onClick() }
            .padding(horizontal = 12.dp)
            .height(48.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            icon,
            contentDescription = label,
            tint = if (isActive) activeColor else inactiveColor,
            modifier = Modifier.size(22.dp)
        )
        Spacer(Modifier.height(3.dp))
        Text(
            label,
            fontSize = 10.sp,
            fontWeight = if (isActive) FontWeight.SemiBold else FontWeight.Normal,
            color = if (isActive) activeColor else inactiveColor,
            maxLines = 1
        )
    }
}

@Composable
private fun MapCenterTab(isActive: Boolean, onClick: () -> Unit) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .offset(y = (-10).dp)
            .clickable(
                indication = null,
                interactionSource = remember { MutableInteractionSource() }
            ) { onClick() }
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(50.dp)
                .shadow(
                    elevation = if (isActive) 10.dp else 6.dp,
                    shape = CircleShape,
                    ambientColor = AppColors.Navy.copy(alpha = if (isActive) 0.4f else 0.2f)
                )
                .background(
                    brush = Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF090F41),
                            Color(0xFF37418C)
                        )
                    ),
                    shape = CircleShape
                )
        ) {
            Icon(
                Icons.Default.MyLocation,
                contentDescription = "Harita",
                tint = Color.White,
                modifier = Modifier.size(22.dp)
            )
        }
    }
}
