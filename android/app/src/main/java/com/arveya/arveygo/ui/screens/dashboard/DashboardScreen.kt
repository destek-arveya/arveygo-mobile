package com.arveya.arveygo.ui.screens.dashboard

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.models.*
import com.arveya.arveygo.ui.components.*
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.utils.DashboardStrings
import com.arveya.arveygo.viewmodels.DashboardViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(onMenuClick: () -> Unit, onNavigateToMap: () -> Unit = {}, onNavigateToVehicles: () -> Unit = {}) {
    val authVM = LocalAuthViewModel.current
    val vm: DashboardViewModel = viewModel()
    val user by authVM.currentUser.collectAsState()
    val vehicles by vm.vehicles.collectAsState()
    val drivers by vm.drivers.collectAsState()
    val alerts by vm.alerts.collectAsState()
    val selectedPeriod by vm.selectedPeriod.collectAsState()
    val isRefreshing by vm.isRefreshing.collectAsState()
    var selectedVehicle by remember { mutableStateOf<Vehicle?>(null) }
    val dlLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings

    // Connect WebSocket when dashboard appears
    LaunchedEffect(Unit) {
        authVM.connectWebSocket()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onMenuClick) {
                        Icon(Icons.Default.Menu, null, tint = AppColors.Navy)
                    }
                },
                title = {
                    Column {
                        Text(DL.title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        Text(DL.subtitle, fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                },
                actions = {
                    AvatarCircle(initials = user?.avatar ?: "A", size = 30.dp)
                    Spacer(Modifier.width(12.dp))
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = AppColors.Surface)
            )
        }
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = isRefreshing,
            onRefresh = { vm.refreshData() },
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .background(AppColors.Bg)
        ) {
            // Welcome Card
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .background(AppColors.PanelGradient, RoundedCornerShape(18.dp))
                    .padding(20.dp)
            ) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("👋", fontSize = 22.sp)
                        Spacer(Modifier.width(10.dp))
                        Column {
                            Text(DL.welcomeMsg(user?.name ?: "Admin"), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White)
                            Text(DL.welcomeSubtitle, fontSize = 12.sp, color = Color.White.copy(alpha = 0.7f))
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        WelcomeChip(DL.kontakOnChip(vm.kontakOnCount), AppColors.Online)
                        WelcomeChip(DL.kontakOffChip(vm.kontakOffCount), AppColors.Idle)
                        WelcomeChip(DL.bilgiYokChip(vm.bilgiYokCount), AppColors.Offline)
                    }
                }
            }

            // Period filter
            PeriodFilter(selected = selectedPeriod, onSelect = { vm.setPeriod(it) })

            // Metric cards
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.padding(vertical = 8.dp)
            ) {
                items(vm.getMetrics()) { metric ->
                    Card(
                        shape = RoundedCornerShape(14.dp),
                        border = BorderStroke(1.dp, AppColors.BorderSoft),
                        colors = CardDefaults.cardColors(containerColor = AppColors.Surface),
                        modifier = Modifier.width(150.dp)
                    ) {
                        MetricCard(metric = metric)
                    }
                }
            }

            Spacer(Modifier.height(8.dp))

            // Active Vehicles
            CardView(
                title = DL.activeVehicles,
                count = "${vm.onlineCount}",
                actionLabel = DL.allLabel,
                onAction = onNavigateToVehicles,
                modifier = Modifier.padding(horizontal = 16.dp)
            ) {
                Column {
                    vehicles.filter { it.status == VehicleStatus.ONLINE }.take(4).forEach { v ->
                        DashboardVehicleRow(v, onClick = { selectedVehicle = v })
                    }
                }
            }

            Spacer(Modifier.height(14.dp))

            // Driver Scores
            CardView(
                title = DL.driverPerformance,
                count = "${drivers.size}",
                actionLabel = DL.detailLabel,
                modifier = Modifier.padding(horizontal = 16.dp)
            ) {
                Column {
                    drivers.take(5).forEach { d ->
                        DriverRow(d)
                    }
                }
            }

            Spacer(Modifier.height(14.dp))

            // Alerts
            CardView(
                title = DL.recentAlarms,
                count = "${alerts.size}",
                actionLabel = DL.allLabel,
                modifier = Modifier.padding(horizontal = 16.dp)
            ) {
                Column {
                    alerts.take(4).forEach { a ->
                        AlertRow(a)
                    }
                }
            }

            Spacer(Modifier.height(14.dp))

            // AI Insights
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .background(
                        Brush.horizontalGradient(listOf(AppColors.Indigo.copy(alpha = 0.06f), AppColors.Lavender.copy(alpha = 0.06f))),
                        RoundedCornerShape(14.dp)
                    )
                    .border(1.dp, AppColors.Indigo.copy(alpha = 0.1f), RoundedCornerShape(14.dp))
                    .padding(16.dp)
            ) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier.size(28.dp).clip(RoundedCornerShape(8.dp)).background(AppColors.Indigo.copy(alpha = 0.1f))
                        ) { Icon(Icons.Default.AutoAwesome, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp)) }
                        Spacer(Modifier.width(8.dp))
                        Text(DL.aiInsights, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                    }
                    Spacer(Modifier.height(12.dp))
                    InsightChip(if (dlLang == "TR") "💡 Yüksek yakıt tüketimi: 34 ABC 123 son 7 günde %15 artış gösterdi" else "💡 High fuel consumption: 34 ABC 123 showed 15% increase in 7 days")
                    Spacer(Modifier.height(8.dp))
                    InsightChip(if (dlLang == "TR") "📍 Optimum rota: Ankara-İstanbul hattında alternatif güzergah %12 tasarruf sağlayabilir" else "📍 Optimal route: Alternative route on Ankara-Istanbul line can save 12%")
                    Spacer(Modifier.height(8.dp))
                    InsightChip(if (dlLang == "TR") "🔧 07 MNO 987 için bakım zamanı yaklaşıyor (3 gün)" else "🔧 Maintenance due for 07 MNO 987 (3 days)")
                }
            }

            Spacer(Modifier.height(30.dp))
        }
        } // PullToRefreshBox
    }

    // Vehicle Detail fullscreen overlay
    selectedVehicle?.let { vehicle ->
        com.arveya.arveygo.ui.screens.fleet.VehicleDetailScreen(
            vehicle = vehicle,
            onBack = { selectedVehicle = null }
        )
    }
}

@Composable
private fun WelcomeChip(text: String, color: Color) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(20.dp))
            .padding(horizontal = 10.dp, vertical = 5.dp)
    ) {
        Box(Modifier.size(6.dp).clip(CircleShape).background(color))
        Spacer(Modifier.width(6.dp))
        Text(text, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.9f))
    }
}

@Composable
private fun PeriodFilter(selected: String, onSelect: (String) -> Unit) {
    val DL = DashboardStrings
    val periods = listOf("today" to DL.periodToday, "week" to DL.periodWeek, "month" to DL.periodMonth, "year" to DL.periodYear)
    Row(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)
    ) {
        periods.forEach { (key, label) ->
            val isActive = selected == key
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(if (isActive) AppColors.Navy else AppColors.Surface)
                    .border(1.dp, if (isActive) AppColors.Navy else AppColors.BorderSoft, RoundedCornerShape(20.dp))
                    .clickable { onSelect(key) }
                    .padding(horizontal = 14.dp, vertical = 7.dp)
            ) {
                Text(label, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = if (isActive) Color.White else AppColors.TextSecondary)
            }
        }
    }
}

@Composable
private fun DashboardVehicleRow(vehicle: Vehicle, onClick: () -> Unit = {}) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().clickable { onClick() }.padding(horizontal = 14.dp, vertical = 8.dp)
    ) {
        Box(Modifier.width(3.dp).height(36.dp).clip(RoundedCornerShape(2.dp)).background(vehicle.status.color))
        Spacer(Modifier.width(10.dp))
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(34.dp).background(vehicle.status.color.copy(alpha = 0.1f), RoundedCornerShape(8.dp))) {
            Icon(Icons.Default.DirectionsCar, null, tint = vehicle.status.color, modifier = Modifier.size(14.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(vehicle.plate, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Text(vehicle.model, fontSize = 11.sp, color = AppColors.TextMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(vehicle.formattedSpeed, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            StatusBadge(vehicle.status)
        }
    }
    HorizontalDivider(modifier = Modifier.padding(start = 60.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
}

@Composable
private fun DriverRow(driver: DriverScore) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp)
    ) {
        AvatarCircle(driver.name.take(1), driver.color, 32.dp)
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(driver.name, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
            Text(driver.plate, fontSize = 11.sp, color = AppColors.TextMuted)
        }
        // Score
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(38.dp).clip(CircleShape).border(2.dp, driver.scoreColor, CircleShape)
        ) {
            Text("${driver.score}", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = driver.scoreColor)
        }
    }
    HorizontalDivider(modifier = Modifier.padding(start = 60.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
}

@Composable
private fun AlertRow(alert: FleetAlert) {
    Row(
        verticalAlignment = Alignment.Top,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(28.dp).clip(RoundedCornerShape(6.dp)).background(alert.severity.color.copy(alpha = 0.1f))
        ) {
            Icon(
                when (alert.severity) {
                    AlertSeverity.RED -> Icons.Default.Warning
                    AlertSeverity.AMBER -> Icons.Default.ErrorOutline
                    AlertSeverity.BLUE -> Icons.Default.Build
                    AlertSeverity.GREEN -> Icons.Default.CheckCircle
                }, null, tint = alert.severity.color, modifier = Modifier.size(14.dp)
            )
        }
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(alert.title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Text(alert.description, fontSize = 11.sp, color = AppColors.TextMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Text(alert.time, fontSize = 10.sp, color = AppColors.TextFaint)
    }
    HorizontalDivider(modifier = Modifier.padding(start = 50.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
}

@Composable
private fun InsightChip(text: String) {
    Text(
        text = text,
        fontSize = 12.sp,
        color = AppColors.TextSecondary,
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White, RoundedCornerShape(10.dp))
            .padding(10.dp)
    )
}

// Extension: CardView with modifier
@Composable
private fun CardView(
    title: String,
    count: String? = null,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(AppColors.Surface, RoundedCornerShape(14.dp))
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(14.dp))
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp)
        ) {
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            if (count != null) {
                Spacer(Modifier.width(8.dp))
                Text(count, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = AppColors.TextMuted, modifier = Modifier.background(AppColors.Bg, RoundedCornerShape(20.dp)).padding(horizontal = 8.dp, vertical = 2.dp))
            }
            Spacer(Modifier.weight(1f))
            if (actionLabel != null) {
                Text(actionLabel, fontSize = 11.sp, fontWeight = FontWeight.Medium, color = AppColors.Indigo,
                    modifier = Modifier.clickable { onAction?.invoke() })
            }
        }
        content()
    }
}
