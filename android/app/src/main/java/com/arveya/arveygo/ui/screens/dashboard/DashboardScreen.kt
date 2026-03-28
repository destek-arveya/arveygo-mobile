package com.arveya.arveygo.ui.screens.dashboard

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
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
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Dashboard Screen (Redesigned — Card-Based, Material 3)
// ═══════════════════════════════════════════════════════════════════════════
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    onMenuClick: () -> Unit,
    onNavigateToMap: () -> Unit = {},
    onNavigateToVehicles: () -> Unit = {},
    onNavigateToDrivers: () -> Unit = {},
    onNavigateToAlarms: (String) -> Unit = {},
    onNavigateToAddAlarm: ((String) -> Unit)? = null,
    onNavigateToRouteHistory: (() -> Unit)? = null
) {
    val authVM = LocalAuthViewModel.current
    val vm: DashboardViewModel = viewModel()
    val user by authVM.currentUser.collectAsState()
    val vehicles by vm.vehicles.collectAsState()
    val drivers by vm.drivers.collectAsState()
    val alerts by vm.alerts.collectAsState()
    val isRefreshing by vm.isRefreshing.collectAsState()
    val isLoadingDrivers by vm.isLoadingDrivers.collectAsState()
    val isLoadingAlerts by vm.isLoadingAlerts.collectAsState()
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
                        Icon(Icons.Default.Menu, null, tint = MaterialTheme.colorScheme.onSurface)
                    }
                },
                title = {
                    Column {
                        Text(
                            DL.title,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            DL.subtitle,
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { onNavigateToAlarms("") }) {
                        Icon(
                            Icons.Default.NotificationsActive,
                            contentDescription = null,
                            tint = Color(0xFFEF4444),
                            modifier = Modifier.size(22.dp)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
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
                // ─── 1. Greeting Header ───
                GreetingHeader(
                    userName = user?.name ?: "Admin",
                    fleetDesc = DL.welcomeSubtitle,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
                )

                // ─── 2. Summary Metrics Bar (horizontal scroll) ───
                SummaryBar(vm = vm, DL = DL)

                Spacer(Modifier.height(16.dp))

                // ─── 3. Live Fleet Map Card ───
                LiveMapCard(
                    vehicles = vehicles,
                    DL = DL,
                    onNavigateToMap = onNavigateToMap,
                    modifier = Modifier.padding(horizontal = 20.dp)
                )

                Spacer(Modifier.height(16.dp))

                // ─── 4. Vehicle Fleet Overview Card (moved up) ───
                VehicleFleetCard(
                    vm = vm,
                    vehicles = vehicles,
                    DL = DL,
                    onNavigateToVehicles = onNavigateToVehicles,
                    onSelectVehicle = { selectedVehicle = it },
                    modifier = Modifier.padding(horizontal = 20.dp)
                )

                Spacer(Modifier.height(16.dp))

                // ─── 5. Weekly Distance + Driver Safety (side by side) ───
                Row(
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    modifier = Modifier
                        .padding(horizontal = 20.dp)
                        .fillMaxWidth()
                ) {
                    WeeklyDistanceCard(
                        todayKm = vm.formatKm(vm.todayKm),
                        vehicles = vehicles,
                        modifier = Modifier.weight(1f)
                    )
                    DriverSafetyCard(
                        score = vm.avgScore,
                        driverCount = drivers.size,
                        onNavigateToDrivers = onNavigateToDrivers,
                        modifier = Modifier.weight(1f)
                    )
                }

                Spacer(Modifier.height(16.dp))

                // ─── 6. Critical Alerts Card ───
                CriticalAlertsCard(
                    alerts = alerts,
                    isLoading = isLoadingAlerts,
                    DL = DL,
                    onNavigateToAlarms = onNavigateToAlarms,
                    modifier = Modifier.padding(horizontal = 20.dp)
                )

                Spacer(Modifier.height(16.dp))

                // ─── 7. AI Insights Card ───
                AiInsightsCard(
                    vm = vm,
                    vehicles = vehicles,
                    DL = DL,
                    dlLang = dlLang,
                    modifier = Modifier.padding(horizontal = 20.dp)
                )

                Spacer(Modifier.height(30.dp))
            }
        } // PullToRefreshBox
    }

    // Vehicle Detail fullscreen overlay
    selectedVehicle?.let { vehicle ->
        com.arveya.arveygo.ui.screens.fleet.VehicleDetailScreen(
            vehicle = vehicle,
            onBack = { selectedVehicle = null },
            onNavigateToRouteHistory = { _ ->
                selectedVehicle = null
                onNavigateToRouteHistory?.invoke()
            },
            onNavigateToAlarms = { plateText ->
                selectedVehicle = null
                onNavigateToAlarms(plateText)
            },
            onNavigateToAddAlarm = { plate ->
                selectedVehicle = null
                onNavigateToAddAlarm?.invoke(plate)
            }
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 1 — Greeting Header
// ═══════════════════════════════════════════════════════════════════════════
@Composable
private fun GreetingHeader(userName: String, fleetDesc: String, modifier: Modifier = Modifier) {
    val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
    val greeting = when {
        hour < 12 -> "Günaydın"
        hour < 18 -> "İyi Günler"
        else -> "İyi Akşamlar"
    }
    val dateStr = remember {
        val sdf = SimpleDateFormat("d MMM, EEE", Locale("tr", "TR"))
        sdf.format(java.util.Date())
    }

    Row(
        verticalAlignment = Alignment.Top,
        modifier = modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                "$greeting, $userName 👋",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(Modifier.height(2.dp))
            Text(
                fleetDesc,
                fontSize = 13.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            )
        }
        // Date chip
        Text(
            dateStr,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            modifier = Modifier
                .background(
                    MaterialTheme.colorScheme.surface,
                    RoundedCornerShape(20.dp)
                )
                .padding(horizontal = 10.dp, vertical = 6.dp)
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 2 — Summary Metrics Bar
// ═══════════════════════════════════════════════════════════════════════════
@Composable
private fun SummaryBar(vm: DashboardViewModel, DL: DashboardStrings) {
    val vehicles by vm.vehicles.collectAsState()
    val alerts by vm.alerts.collectAsState()
    val criticalCount = alerts.count { it.severity == AlertSeverity.RED }

    // Average fuel
    val avgFuel = remember(vehicles) {
        val rates = vehicles.mapNotNull { v ->
            val r = if (v.dailyFuelPer100km > 0) v.dailyFuelPer100km else v.fuelPer100km
            if (r > 0) r else null
        }
        if (rates.isEmpty()) "—" else String.format("%.1f", rates.average())
    }

    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(horizontal = 20.dp),
        modifier = Modifier.padding(top = 8.dp)
    ) {
        item {
            SummaryPill(
                icon = Icons.Default.DirectionsCar,
                iconColor = Color(0xFF3B82F6),
                title = "Araçlar",
                value = "${vm.totalVehicles}",
                badge = "${vm.kontakOnCount} aktif",
                badgeColor = AppColors.Online
            )
        }
        item {
            SummaryPill(
                icon = Icons.Default.VpnKey,
                iconColor = AppColors.Online,
                title = "Kontak Açık",
                value = "${vm.kontakOnCount}",
                badge = null,
                badgeColor = AppColors.Online
            )
        }
        item {
            SummaryPill(
                icon = Icons.Default.VpnKeyOff,
                iconColor = AppColors.Idle,
                title = "Kontak Kapalı",
                value = "${vm.kontakOffCount}",
                badge = null,
                badgeColor = AppColors.Idle
            )
        }
        item {
            SummaryPill(
                icon = Icons.Default.SignalWifiOff,
                iconColor = Color(0xFF94A3B8),
                title = "Bilgi Yok",
                value = "${vm.bilgiYokCount}",
                badge = null,
                badgeColor = Color.Gray
            )
        }
        item {
            SummaryPill(
                icon = Icons.Default.LocalGasStation,
                iconColor = Color(0xFF8B5CF6),
                title = "Ort. Yakıt",
                value = avgFuel,
                badge = "L/100km",
                badgeColor = Color(0xFF8B5CF6)
            )
        }
        item {
            SummaryPill(
                icon = Icons.Default.Warning,
                iconColor = Color(0xFFEF4444),
                title = "Kritik Alarm",
                value = "$criticalCount",
                badge = if (criticalCount > 0) "acil" else null,
                badgeColor = Color(0xFFEF4444)
            )
        }
        item {
            SummaryPill(
                icon = Icons.Default.Route,
                iconColor = AppColors.Indigo,
                title = "Bugün KM",
                value = vm.formatKm(vm.todayKm),
                badge = null,
                badgeColor = Color.Blue
            )
        }
    }
}

@Composable
private fun SummaryPill(
    icon: ImageVector,
    iconColor: Color,
    title: String,
    value: String,
    badge: String?,
    badgeColor: Color
) {
    Column(
        modifier = Modifier
            .width(100.dp)
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(12.dp))
            .padding(12.dp)
    ) {
        // Simple icon
        Icon(
            icon,
            contentDescription = null,
            tint = iconColor,
            modifier = Modifier.size(18.dp)
        )
        Spacer(Modifier.height(6.dp))

        // Value — clean and readable
        Text(
            value,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1
        )
        Spacer(Modifier.height(2.dp))

        // Title
        Text(
            title,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            maxLines = 1
        )

        // Optional badge
        if (badge != null) {
            Spacer(Modifier.height(4.dp))
            Text(
                badge,
                fontSize = 9.sp,
                fontWeight = FontWeight.SemiBold,
                color = badgeColor
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 3 — Live Fleet Map Card
// ═══════════════════════════════════════════════════════════════════════════
@Composable
private fun LiveMapCard(
    vehicles: List<Vehicle>,
    DL: DashboardStrings,
    onNavigateToMap: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(16.dp))
    ) {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp)
        ) {
            Icon(
                Icons.Default.PinDrop,
                contentDescription = null,
                tint = AppColors.Indigo,
                modifier = Modifier.size(16.dp)
            )
            Spacer(Modifier.width(6.dp))
            Text(
                "Filo Haritası",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(Modifier.weight(1f))

            // Full screen button commented out
            // TextButton(onClick = { }) {
            //     Text("Tam Ekran", fontSize = 11.sp, color = AppColors.Indigo)
            // }

            // Live Map button — prominent
            Button(
                onClick = onNavigateToMap,
                colors = ButtonDefaults.buttonColors(
                    containerColor = AppColors.Indigo
                ),
                shape = RoundedCornerShape(20.dp),
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                modifier = Modifier.height(32.dp)
            ) {
                Icon(
                    Icons.Default.MyLocation,
                    contentDescription = null,
                    modifier = Modifier.size(12.dp),
                    tint = Color.White
                )
                Spacer(Modifier.width(4.dp))
                Text(
                    "Canlı Harita",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
                Spacer(Modifier.width(2.dp))
                Icon(
                    Icons.Default.ChevronRight,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = Color.White.copy(alpha = 0.7f)
                )
            }
        }

        // Map placeholder (static dot visualization)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(180.dp)
                .padding(horizontal = 12.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(AppColors.Bg)
        ) {
            // Simple dot-based vehicle positions visualization
            Canvas(modifier = Modifier.fillMaxSize()) {
                val w = size.width
                val h = size.height

                // Draw grid lines
                for (i in 0..4) {
                    val y = h * i / 4f
                    drawLine(
                        color = Color(0xFFE2E8F0),
                        start = Offset(0f, y),
                        end = Offset(w, y),
                        strokeWidth = 0.5f
                    )
                }
                for (i in 0..4) {
                    val x = w * i / 4f
                    drawLine(
                        color = Color(0xFFE2E8F0),
                        start = Offset(x, 0f),
                        end = Offset(x, h),
                        strokeWidth = 0.5f
                    )
                }

                // Vehicle dots
                vehicles.forEach { vehicle ->
                    val nx = ((vehicle.lng - 26.0) / (44.0 - 26.0)).coerceIn(0.0, 1.0).toFloat()
                    val ny = (1.0 - (vehicle.lat - 36.0) / (42.0 - 36.0)).coerceIn(0.0, 1.0).toFloat()
                    val cx = nx * w * 0.85f + w * 0.075f
                    val cy = ny * h * 0.85f + h * 0.075f
                    // Outer glow
                    drawCircle(
                        color = vehicle.status.color.copy(alpha = 0.25f),
                        radius = 10f,
                        center = Offset(cx, cy)
                    )
                    // Inner dot
                    drawCircle(
                        color = vehicle.status.color,
                        radius = 5f,
                        center = Offset(cx, cy)
                    )
                    // White border
                    drawCircle(
                        color = Color.White,
                        radius = 5f,
                        center = Offset(cx, cy),
                        style = Stroke(width = 1.5f)
                    )
                }
            }

            // Legend overlay
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = 10.dp, bottom = 8.dp)
                    .background(
                        Color.White.copy(alpha = 0.85f),
                        RoundedCornerShape(20.dp)
                    )
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            ) {
                MapLegendItem(AppColors.Online, "Açık")
                MapLegendItem(AppColors.Offline, "Kapalı")
                MapLegendItem(Color(0xFF94A3B8), "Bilgi Yok")
                MapLegendItem(AppColors.Idle, "Uyku")
            }
        }

        Spacer(Modifier.height(12.dp))
    }
}

@Composable
private fun MapLegendItem(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(color)
        )
        Spacer(Modifier.width(3.dp))
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.Medium, color = Color.Gray)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 4 — Vehicle Fleet Overview Card
// ═══════════════════════════════════════════════════════════════════════════
@Composable
private fun VehicleFleetCard(
    vm: DashboardViewModel,
    vehicles: List<Vehicle>,
    DL: DashboardStrings,
    onNavigateToVehicles: () -> Unit,
    onSelectVehicle: (Vehicle) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(16.dp))
    ) {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp)
        ) {
            Icon(
                Icons.Default.DirectionsCar,
                contentDescription = null,
                tint = Color(0xFF3B82F6),
                modifier = Modifier.size(16.dp)
            )
            Spacer(Modifier.width(6.dp))
            Text(
                "Araçlar",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(Modifier.width(8.dp))
            Text(
                "${vm.totalVehicles}",
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                modifier = Modifier
                    .background(AppColors.Bg, RoundedCornerShape(20.dp))
                    .padding(horizontal = 8.dp, vertical = 3.dp)
            )
            Spacer(Modifier.weight(1f))
            Text(
                DL.allLabel,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Indigo,
                modifier = Modifier
                    .clickable { onNavigateToVehicles() }
                    .padding(4.dp)
            )
        }

        // Fleet distribution bar
        FleetDistributionBar(vm = vm, modifier = Modifier.padding(horizontal = 16.dp))
        Spacer(Modifier.height(10.dp))

        // Vehicle rows — 5 oldest active/idle first, fill rest from others
        val displayVehicles = remember(vehicles) {
            val activeIdle = vehicles
                .filter { it.status == VehicleStatus.IGNITION_ON || it.status == VehicleStatus.SLEEPING }
                .sortedBy { it.ts }
                .takeLast(5)
            if (activeIdle.size >= 5) {
                activeIdle.take(5)
            } else {
                val remaining = vehicles.filter { v -> activeIdle.none { it.id == v.id } }
                (activeIdle + remaining).take(5)
            }
        }

        displayVehicles.forEachIndexed { index, vehicle ->
            DashboardVehicleRow(vehicle, onClick = { onSelectVehicle(vehicle) })
            if (index < displayVehicles.size - 1) {
                HorizontalDivider(
                    modifier = Modifier.padding(start = 56.dp),
                    color = AppColors.BorderSoft.copy(alpha = 0.5f)
                )
            }
        }

        // See all
        if (vehicles.size > 5) {
            TextButton(
                onClick = onNavigateToVehicles,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp)
            ) {
                Text(
                    "+${vehicles.size - 5} daha fazla araç",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Indigo
                )
            }
        }
    }
}

@Composable
private fun FleetDistributionBar(vm: DashboardViewModel, modifier: Modifier = Modifier) {
    val total = maxOf(vm.totalVehicles, 1)
    val on = vm.kontakOnCount
    val off = vm.kontakOffCount
    val noData = vm.bilgiYokCount
    val sleeping = vm.idleCount

    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        // Bar
        Row(
            horizontalArrangement = Arrangement.spacedBy(2.dp),
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
        ) {
            if (on > 0) {
                Box(
                    modifier = Modifier
                        .weight(on.toFloat() / total)
                        .fillMaxHeight()
                        .background(AppColors.Online, RoundedCornerShape(3.dp))
                )
            }
            if (off > 0) {
                Box(
                    modifier = Modifier
                        .weight(off.toFloat() / total)
                        .fillMaxHeight()
                        .background(AppColors.Offline, RoundedCornerShape(3.dp))
                )
            }
            if (noData > 0) {
                Box(
                    modifier = Modifier
                        .weight(noData.toFloat() / total)
                        .fillMaxHeight()
                        .background(Color(0xFFBFC6D4), RoundedCornerShape(3.dp))
                )
            }
            if (sleeping > 0) {
                Box(
                    modifier = Modifier
                        .weight(sleeping.toFloat() / total)
                        .fillMaxHeight()
                        .background(AppColors.Idle, RoundedCornerShape(3.dp))
                )
            }
        }

        // Labels
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            DistributionLabel(AppColors.Online, "Açık $on")
            DistributionLabel(AppColors.Offline, "Kapalı $off")
            DistributionLabel(Color(0xFFBFC6D4), "Bilgi Yok $noData")
            DistributionLabel(AppColors.Idle, "Uyku $sleeping")
        }
    }
}

@Composable
private fun DistributionLabel(color: Color, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(5.dp)
                .clip(CircleShape)
                .background(color)
        )
        Spacer(Modifier.width(3.dp))
        Text(text, fontSize = 9.sp, fontWeight = FontWeight.Medium, color = Color.Gray)
    }
}

@Composable
private fun DashboardVehicleRow(vehicle: Vehicle, onClick: () -> Unit = {}) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        // Status icon
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(36.dp)
                .background(vehicle.status.color.copy(alpha = 0.1f), RoundedCornerShape(10.dp))
        ) {
            Icon(
                Icons.Default.DirectionsCar,
                contentDescription = null,
                tint = vehicle.status.color,
                modifier = Modifier.size(16.dp)
            )
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                vehicle.plate,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                "${vehicle.model} · ${vehicle.city}",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                vehicle.formattedTodayKm,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                vehicle.formattedSpeed,
                fontSize = 10.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)
            )
        }
        Spacer(Modifier.width(8.dp))
        // Status badge
        Text(
            vehicle.status.label,
            fontSize = 9.sp,
            fontWeight = FontWeight.SemiBold,
            color = vehicle.status.color,
            modifier = Modifier
                .background(vehicle.status.color.copy(alpha = 0.1f), RoundedCornerShape(20.dp))
                .padding(horizontal = 7.dp, vertical = 3.dp)
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 5a — Weekly Distance Card (Mini Line Chart)
// ═══════════════════════════════════════════════════════════════════════════
@Composable
private fun WeeklyDistanceCard(
    todayKm: String,
    vehicles: List<Vehicle>,
    modifier: Modifier = Modifier
) {
    val todayTotal = vehicles.sumOf { it.todayKm }.toFloat()
    val base = maxOf(todayTotal * 0.6f, 50f)
    val weeklyData = listOf(
        base * 0.7f, base * 1.1f, base * 0.9f, base * 1.3f,
        base * 0.8f, base * 1.05f, todayTotal
    )

    val dayLabels = remember {
        val sdf = SimpleDateFormat("EEE", Locale("tr", "TR"))
        val cal = Calendar.getInstance()
        (6 downTo 0).map { offset ->
            cal.time = java.util.Date()
            cal.add(Calendar.DAY_OF_YEAR, -offset)
            sdf.format(cal.time).take(2)
        }
    }

    Column(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(16.dp))
            .padding(14.dp)
    ) {
        // Header
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.AutoMirrored.Filled.ShowChart,
                contentDescription = null,
                tint = AppColors.Indigo,
                modifier = Modifier.size(14.dp)
            )
            Spacer(Modifier.width(4.dp))
            Text(
                "Haftalık Mesafe",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
        Spacer(Modifier.height(8.dp))

        Text(
            "$todayKm km",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )
        Text(
            "bugün",
            fontSize = 10.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)
        )
        Spacer(Modifier.height(8.dp))

        // Mini line chart
        MiniLineChart(
            values = weeklyData,
            lineColor = AppColors.Indigo,
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp)
        )

        Spacer(Modifier.height(4.dp))

        // Day labels
        Row(modifier = Modifier.fillMaxWidth()) {
            dayLabels.forEach { day ->
                Text(
                    day,
                    fontSize = 8.sp,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.25f),
                    modifier = Modifier.weight(1f),
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
private fun MiniLineChart(
    values: List<Float>,
    lineColor: Color,
    modifier: Modifier = Modifier
) {
    Canvas(modifier = modifier) {
        if (values.isEmpty()) return@Canvas
        val maxVal = values.max().coerceAtLeast(1f)
        val w = size.width
        val h = size.height
        val step = w / (values.size - 1).coerceAtLeast(1)

        val points = values.mapIndexed { i, v ->
            Offset(step * i, h - (v / maxVal) * h)
        }

        // Gradient fill
        val fillPath = Path().apply {
            points.forEachIndexed { i, p ->
                if (i == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y)
            }
            lineTo(w, h)
            lineTo(0f, h)
            close()
        }
        drawPath(
            fillPath,
            brush = Brush.verticalGradient(
                colors = listOf(lineColor.copy(alpha = 0.2f), lineColor.copy(alpha = 0.02f))
            )
        )

        // Line
        val linePath = Path().apply {
            points.forEachIndexed { i, p ->
                if (i == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y)
            }
        }
        drawPath(
            linePath,
            color = lineColor,
            style = Stroke(width = 2f, cap = StrokeCap.Round, join = StrokeJoin.Round)
        )

        // End dot
        val last = points.lastOrNull()
        if (last != null) {
            drawCircle(color = lineColor, radius = 3f, center = last)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 5b — Driver Safety Score Card (Circular)
// ═══════════════════════════════════════════════════════════════════════════
@Composable
private fun DriverSafetyCard(
    score: Int,
    driverCount: Int,
    onNavigateToDrivers: () -> Unit,
    modifier: Modifier = Modifier
) {
    val grade = when {
        score >= 85 -> "A"
        score >= 70 -> "B"
        score >= 50 -> "C"
        else -> "D"
    }
    val scoreColor = when {
        score >= 85 -> AppColors.Online
        score >= 70 -> AppColors.Idle
        else -> AppColors.Offline
    }

    Column(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(16.dp))
            .padding(14.dp)
    ) {
        // Header
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Default.Shield,
                contentDescription = null,
                tint = AppColors.Online,
                modifier = Modifier.size(14.dp)
            )
            Spacer(Modifier.width(4.dp))
            Text(
                "Güvenlik Skoru",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
        }

        Spacer(Modifier.height(8.dp))

        // Circular progress
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1f)
                .padding(horizontal = 12.dp)
        ) {
            Canvas(modifier = Modifier.size(72.dp)) {
                val strokeW = 6.dp.toPx()
                val radius = (size.minDimension - strokeW) / 2
                val topLeft = Offset(
                    (size.width - radius * 2) / 2,
                    (size.height - radius * 2) / 2
                )
                val arcSize = Size(radius * 2, radius * 2)

                // Background circle
                drawArc(
                    color = Color(0xFFF1F5F9),
                    startAngle = 0f,
                    sweepAngle = 360f,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = strokeW, cap = StrokeCap.Round)
                )

                // Score arc
                drawArc(
                    color = scoreColor,
                    startAngle = -90f,
                    sweepAngle = 360f * score / 100f,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = strokeW, cap = StrokeCap.Round)
                )
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "$score",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    grade,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                )
            }
        }

        Spacer(Modifier.height(4.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Default.People,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                modifier = Modifier.size(12.dp)
            )
            Spacer(Modifier.width(3.dp))
            Text(
                "$driverCount sürücü",
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)
            )
        }

        Spacer(Modifier.height(6.dp))

        // Detail button
        Button(
            onClick = onNavigateToDrivers,
            colors = ButtonDefaults.buttonColors(
                containerColor = AppColors.Indigo.copy(alpha = 0.06f)
            ),
            shape = RoundedCornerShape(8.dp),
            contentPadding = PaddingValues(vertical = 6.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                "Detaylar",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Indigo
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 6 — Critical Alerts Card
// ═══════════════════════════════════════════════════════════════════════════
@Composable
private fun CriticalAlertsCard(
    alerts: List<FleetAlert>,
    isLoading: Boolean,
    DL: DashboardStrings,
    onNavigateToAlarms: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val criticalCount = alerts.count { it.severity == AlertSeverity.RED }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(16.dp))
    ) {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp)
        ) {
            Icon(
                Icons.Default.Warning,
                contentDescription = null,
                tint = Color(0xFFEF4444),
                modifier = Modifier.size(16.dp)
            )
            Spacer(Modifier.width(6.dp))
            Text(
                DL.recentAlarms,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(Modifier.width(8.dp))

            if (criticalCount > 0) {
                Text(
                    "$criticalCount kritik",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFFEF4444),
                    modifier = Modifier
                        .background(Color(0xFFEF4444).copy(alpha = 0.1f), RoundedCornerShape(20.dp))
                        .padding(horizontal = 8.dp, vertical = 3.dp)
                )
            }
            Spacer(Modifier.weight(1f))
            Text(
                DL.allLabel,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Indigo,
                modifier = Modifier
                    .clickable { onNavigateToAlarms("") }
                    .padding(4.dp)
            )
        }

        if (isLoading && alerts.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 24.dp),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    strokeWidth = 2.dp,
                    color = AppColors.Indigo
                )
            }
        } else if (alerts.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 20.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = AppColors.Online.copy(alpha = 0.6f),
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "Alarm bulunmuyor",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                    )
                }
            }
        } else {
            alerts.take(5).forEachIndexed { index, alert ->
                DashboardAlertRow(alert)
                if (index < minOf(alerts.size, 5) - 1) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp),
                        color = AppColors.BorderSoft.copy(alpha = 0.5f)
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun DashboardAlertRow(alert: FleetAlert) {
    val icon = when (alert.severity) {
        AlertSeverity.RED -> Icons.Default.Warning
        AlertSeverity.AMBER -> Icons.Default.ErrorOutline
        AlertSeverity.BLUE -> Icons.Default.Build
        AlertSeverity.GREEN -> Icons.Default.CheckCircle
    }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(32.dp)
                .background(alert.severity.color.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
        ) {
            Icon(icon, null, tint = alert.severity.color, modifier = Modifier.size(16.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                alert.title,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                alert.description,
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Text(
            alert.time,
            fontSize = 10.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 7 — AI Insights Card
// ═══════════════════════════════════════════════════════════════════════════
@Composable
private fun AiInsightsCard(
    vm: DashboardViewModel,
    vehicles: List<Vehicle>,
    DL: DashboardStrings,
    dlLang: String,
    modifier: Modifier = Modifier
) {
    val topVehicle = vehicles.maxByOrNull { it.todayKm }
    val topPlate = topVehicle?.plate ?: "—"
    val topKm = vm.formatKm(topVehicle?.todayKm ?: 0)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(16.dp))
            .padding(16.dp)
    ) {
        // Header
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Default.AutoAwesome,
                contentDescription = null,
                tint = Color(0xFF8B5CF6),
                modifier = Modifier.size(16.dp)
            )
            Spacer(Modifier.width(6.dp))
            Text(
                "AI Filo Analizi",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
        Spacer(Modifier.height(10.dp))

        // Summary text
        Text(
            if (dlLang == "TR")
                "Filonuzda ${vm.onlineCount} araç aktif durumda. Günlük toplam ${vm.formatKm(vm.todayKm)} km yol katedildi."
            else
                "${vm.onlineCount} vehicles active in your fleet. Total ${vm.formatKm(vm.todayKm)} km covered today.",
            fontSize = 12.5.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            lineHeight = 18.sp
        )
        Spacer(Modifier.height(12.dp))

        // Insight bubbles
        InsightBubble(
            text = if (dlLang == "TR") "En yüksek mesafe: $topPlate — $topKm km"
            else "Highest distance: $topPlate — $topKm km",
            dotColor = AppColors.Online,
            tag = null
        )
        Spacer(Modifier.height(8.dp))
        InsightBubble(
            text = if (dlLang == "TR") "${vm.bilgiYokCount} araç çevrimdışı — bakım kontrolü önerilir"
            else "${vm.bilgiYokCount} vehicles offline — maintenance check recommended",
            dotColor = AppColors.Offline,
            tag = if (vm.bilgiYokCount > 0) ("Yüksek" to Color(0xFFEF4444)) else null
        )
        Spacer(Modifier.height(8.dp))
        InsightBubble(
            text = if (dlLang == "TR") "Ortalama sürücü skoru ${vm.avgScore} — filo güvenliği iyi seviyede"
            else "Average driver score ${vm.avgScore} — fleet safety in good standing",
            dotColor = AppColors.Indigo,
            tag = if (vm.avgScore >= 70) ("Düşük" to AppColors.Online) else ("Yüksek" to AppColors.Idle)
        )
    }
}

@Composable
private fun InsightBubble(
    text: String,
    dotColor: Color,
    tag: Pair<String, Color>?
) {
    Row(
        verticalAlignment = Alignment.Top,
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Bg, RoundedCornerShape(10.dp))
            .padding(10.dp)
    ) {
        Box(
            modifier = Modifier
                .padding(top = 5.dp)
                .size(6.dp)
                .clip(CircleShape)
                .background(dotColor)
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text,
            fontSize = 11.5.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            lineHeight = 16.sp,
            modifier = Modifier.weight(1f)
        )
        if (tag != null) {
            Spacer(Modifier.width(6.dp))
            Text(
                tag.first,
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold,
                color = tag.second,
                modifier = Modifier
                    .background(tag.second.copy(alpha = 0.1f), RoundedCornerShape(20.dp))
                    .padding(horizontal = 6.dp, vertical = 3.dp)
            )
        }
    }
}
