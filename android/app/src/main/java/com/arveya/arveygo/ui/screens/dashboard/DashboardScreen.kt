package com.arveya.arveygo.ui.screens.dashboard

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
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
    val isLoading by vm.isLoading.collectAsState()
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
                title = {
                    Text(
                        "ArveyGo",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
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
            if (isLoading) {
                DashboardSkeletonScreen()
            } else {
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

                // ─── 5. Driver Score + Daily KM (side by side, matches iOS) ───
                Row(
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    modifier = Modifier
                        .padding(horizontal = 20.dp)
                        .fillMaxWidth()
                ) {
                    DriverScoreCard(
                        score = vm.avgScore,
                        driverCount = drivers.size,
                        vehicleCount = vm.totalVehicles,
                        onNavigateToDrivers = onNavigateToDrivers,
                        modifier = Modifier.weight(1f)
                    )
                    DailyKmCard(
                        totalDailyKm = vehicles.sumOf { it.dailyKm },
                        formattedKm = vm.formatKm(vehicles.sumOf { it.dailyKm }.toInt()),
                        vehicleCount = vm.totalVehicles,
                        activeCount = vm.kontakOnCount,
                        onNavigateToVehicles = onNavigateToVehicles,
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
            } // else (isLoading)
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
    val greetingEmoji = when {
        hour < 12 -> "☀️"
        hour < 18 -> "🌤️"
        else -> "🌙"
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
                "$greetingEmoji $greeting, $userName",
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
// MARK: 5a — Driver Score Card (compact, half-width — matches iOS)
// ═══════════════════════════════════════════════════════════════════════════
@Composable
private fun DriverScoreCard(
    score: Int,
    driverCount: Int,
    vehicleCount: Int,
    onNavigateToDrivers: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scoreColor = when {
        score >= 85 -> AppColors.Online
        score >= 70 -> AppColors.Idle
        else -> AppColors.Offline
    }

    Column(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(16.dp))
    ) {
        // Header
        Text(
            "Sürücü Skoru",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(start = 14.dp, end = 14.dp, top = 14.dp, bottom = 10.dp)
        )

        // Ring
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.fillMaxWidth()
        ) {
            Canvas(modifier = Modifier.size(64.dp)) {
                val strokeW = 5.dp.toPx()
                val radius = (size.minDimension - strokeW) / 2
                val topLeft = Offset(
                    (size.width - radius * 2) / 2,
                    (size.height - radius * 2) / 2
                )
                val arcSize = Size(radius * 2, radius * 2)
                drawArc(Color(0xFFF1F5F9), 0f, 360f, false, topLeft, arcSize, style = Stroke(width = strokeW, cap = StrokeCap.Round))
                drawArc(scoreColor, -90f, 360f * score / 100f, false, topLeft, arcSize, style = Stroke(width = strokeW, cap = StrokeCap.Round))
            }
            Text(
                "$score",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
        }

        Spacer(Modifier.height(8.dp))

        // Mini stats
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(horizontal = 14.dp)
        ) {
            MiniStatLabel("Sürücü", "$driverCount")
            MiniStatLabel("Araç", "$vehicleCount")
        }

        Spacer(Modifier.height(10.dp))

        // Detail button
        Button(
            onClick = onNavigateToDrivers,
            colors = ButtonDefaults.buttonColors(containerColor = AppColors.Indigo.copy(alpha = 0.06f)),
            shape = RoundedCornerShape(8.dp),
            contentPadding = PaddingValues(vertical = 7.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp)
                .padding(bottom = 14.dp)
        ) {
            Text("Detaylar", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Indigo)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 5b — Daily KM Card (compact, half-width — matches iOS)
// ═══════════════════════════════════════════════════════════════════════════
@Composable
private fun DailyKmCard(
    totalDailyKm: Double,
    formattedKm: String,
    vehicleCount: Int,
    activeCount: Int,
    onNavigateToVehicles: () -> Unit,
    modifier: Modifier = Modifier
) {
    val skyBlue = Color(0xFF3893F1)
    val progress = if (vehicleCount > 0) (totalDailyKm / maxOf(vehicleCount * 100.0, 1.0)).coerceAtMost(1.0).toFloat() else 0f

    Column(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(16.dp))
    ) {
        // Header
        Text(
            "Bugün Mesafe",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(start = 14.dp, end = 14.dp, top = 14.dp, bottom = 10.dp)
        )

        // Ring
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.fillMaxWidth()
        ) {
            Canvas(modifier = Modifier.size(64.dp)) {
                val strokeW = 5.dp.toPx()
                val radius = (size.minDimension - strokeW) / 2
                val topLeft = Offset(
                    (size.width - radius * 2) / 2,
                    (size.height - radius * 2) / 2
                )
                val arcSize = Size(radius * 2, radius * 2)
                drawArc(Color(0xFFF1F5F9), 0f, 360f, false, topLeft, arcSize, style = Stroke(width = strokeW, cap = StrokeCap.Round))
                drawArc(skyBlue, -90f, 360f * progress, false, topLeft, arcSize, style = Stroke(width = strokeW, cap = StrokeCap.Round))
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    formattedKm,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1
                )
                Text(
                    "km",
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)
                )
            }
        }

        Spacer(Modifier.height(8.dp))

        // Mini stats
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(horizontal = 14.dp)
        ) {
            MiniStatLabel("Araç", "$vehicleCount")
            MiniStatLabel("Aktif", "$activeCount")
        }

        Spacer(Modifier.height(10.dp))

        // View all button
        Button(
            onClick = onNavigateToVehicles,
            colors = ButtonDefaults.buttonColors(containerColor = skyBlue.copy(alpha = 0.07f)),
            shape = RoundedCornerShape(8.dp),
            contentPadding = PaddingValues(vertical = 7.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp)
                .padding(bottom = 14.dp)
        ) {
            Text("Tümünü Gör", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = skyBlue)
        }
    }
}

@Composable
private fun MiniStatLabel(label: String, value: String) {
    Column {
        Text(
            value,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1
        )
        Text(
            label,
            fontSize = 9.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
            maxLines = 1
        )
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
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                alert.description,
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                alert.dateString,
                fontSize = 9.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                maxLines = 1
            )
            if (alert.timeString.isNotEmpty()) {
                Text(
                    alert.timeString,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                    maxLines = 1
                )
            }
        }
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

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Shimmer Utilities
// ═══════════════════════════════════════════════════════════════════════════
@Composable
private fun shimmerBrush(): Brush {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val translateAnim by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1200, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmer_translate"
    )
    return Brush.linearGradient(
        colors = listOf(
            Color(0xFFE8EAF0),
            Color(0xFFF5F6FA),
            Color(0xFFFFFFFF),
            Color(0xFFF5F6FA),
            Color(0xFFE8EAF0),
        ),
        start = Offset(translateAnim - 400f, 0f),
        end = Offset(translateAnim, 0f)
    )
}

@Composable
private fun SkeletonBox(
    modifier: Modifier = Modifier,
    height: Int = 14,
    cornerRadius: Int = 6
) {
    val brush = shimmerBrush()
    Box(
        modifier = modifier
            .height(height.dp)
            .clip(RoundedCornerShape(cornerRadius.dp))
            .background(brush)
    )
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Dashboard Skeleton Screen
// ═══════════════════════════════════════════════════════════════════════════
@Composable
internal fun DashboardSkeletonScreen() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .background(AppColors.Bg)
    ) {
        // ─── Header Skeleton ───
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp)
        ) {
            Column(modifier = Modifier.weight(1f)) {
                SkeletonBox(modifier = Modifier.width(80.dp), height = 12)
                Spacer(Modifier.height(6.dp))
                SkeletonBox(modifier = Modifier.width(150.dp), height = 20)
            }
            SkeletonBox(modifier = Modifier.width(72.dp), height = 28, cornerRadius = 14)
        }

        Spacer(Modifier.height(12.dp))

        // ─── Fleet Status Card Skeleton ───
        SkeletonCard(modifier = Modifier.padding(horizontal = 20.dp)) {
            Column {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 14.dp)
                ) {
                    SkeletonBox(modifier = Modifier.width(90.dp), height = 15)
                    Spacer(Modifier.weight(1f))
                    SkeletonBox(modifier = Modifier.width(55.dp), height = 12)
                }
                SkeletonBox(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                    height = 6,
                    cornerRadius = 3
                )
                Spacer(Modifier.height(12.dp))
                HorizontalDivider(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    color = Color(0xFFE2E8F0)
                )
                Row(
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 14.dp)
                ) {
                    repeat(3) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            SkeletonBox(modifier = Modifier.width(36.dp), height = 22)
                            Spacer(Modifier.height(4.dp))
                            SkeletonBox(modifier = Modifier.width(56.dp), height = 10)
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // ─── Vehicles Card Skeleton ───
        SkeletonCard(modifier = Modifier.padding(horizontal = 20.dp)) {
            Column {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 14.dp)
                ) {
                    SkeletonBox(modifier = Modifier.width(65.dp), height = 15)
                    Spacer(Modifier.weight(1f))
                    SkeletonBox(modifier = Modifier.width(40.dp), height = 12)
                }
                SkeletonBox(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                    height = 6,
                    cornerRadius = 3
                )
                Spacer(Modifier.height(10.dp))
                repeat(4) { index ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 8.dp)
                    ) {
                        SkeletonBox(modifier = Modifier.size(36.dp), cornerRadius = 10)
                        Spacer(Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            SkeletonBox(modifier = Modifier.width(80.dp), height = 13)
                            Spacer(Modifier.height(4.dp))
                            SkeletonBox(modifier = Modifier.width(110.dp), height = 10)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            SkeletonBox(modifier = Modifier.width(45.dp), height = 12)
                            Spacer(Modifier.height(3.dp))
                            SkeletonBox(modifier = Modifier.width(35.dp), height = 10)
                        }
                    }
                    if (index < 3) {
                        HorizontalDivider(
                            modifier = Modifier.padding(start = 56.dp),
                            color = Color(0xFFE2E8F0)
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
            }
        }

        Spacer(Modifier.height(16.dp))

        // ─── Driver Score + Daily KM (side-by-side) ───
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            modifier = Modifier
                .padding(horizontal = 20.dp)
                .fillMaxWidth()
        ) {
            repeat(2) {
                SkeletonCard(modifier = Modifier.weight(1f)) {
                    Column {
                        SkeletonBox(
                            modifier = Modifier
                                .padding(start = 14.dp, end = 14.dp, top = 14.dp, bottom = 10.dp)
                                .width(75.dp),
                            height = 13
                        )
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            val brush = shimmerBrush()
                            Box(
                                modifier = Modifier
                                    .size(64.dp)
                                    .clip(CircleShape)
                                    .background(brush)
                            )
                        }
                        Spacer(Modifier.height(10.dp))
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.padding(horizontal = 14.dp)
                        ) {
                            repeat(2) {
                                Column {
                                    SkeletonBox(modifier = Modifier.width(24.dp), height = 15)
                                    Spacer(Modifier.height(3.dp))
                                    SkeletonBox(modifier = Modifier.width(32.dp), height = 9)
                                }
                            }
                        }
                        Spacer(Modifier.height(10.dp))
                        SkeletonBox(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp)
                                .padding(bottom = 14.dp),
                            height = 30,
                            cornerRadius = 8
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        // ─── Alarms Card Skeleton ───
        SkeletonCard(modifier = Modifier.padding(horizontal = 20.dp)) {
            Column {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 14.dp)
                ) {
                    SkeletonBox(modifier = Modifier.width(90.dp), height = 15)
                    Spacer(Modifier.weight(1f))
                    SkeletonBox(modifier = Modifier.width(38.dp), height = 12)
                }
                repeat(4) { index ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 8.dp)
                    ) {
                        SkeletonBox(modifier = Modifier.size(32.dp), cornerRadius = 8)
                        Spacer(Modifier.width(10.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            SkeletonBox(modifier = Modifier.width(130.dp), height = 13)
                            Spacer(Modifier.height(4.dp))
                            SkeletonBox(modifier = Modifier.width(90.dp), height = 10)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            SkeletonBox(modifier = Modifier.width(38.dp), height = 10)
                            Spacer(Modifier.height(3.dp))
                            SkeletonBox(modifier = Modifier.width(30.dp), height = 10)
                        }
                    }
                    if (index < 3) {
                        HorizontalDivider(
                            modifier = Modifier.padding(start = 52.dp),
                            color = Color(0xFFE2E8F0)
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
            }
        }

        Spacer(Modifier.height(30.dp))
    }
}

@Composable
private fun SkeletonCard(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(16.dp))
    ) {
        content()
    }
}
