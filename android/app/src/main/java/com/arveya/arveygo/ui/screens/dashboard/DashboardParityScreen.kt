package com.arveya.arveygo.ui.screens.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.CarCrash
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Route
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
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.models.AlarmEvent
import com.arveya.arveygo.models.Vehicle
import com.arveya.arveygo.ui.components.DashboardSkeletonBlock
import com.arveya.arveygo.ui.components.StatusBadge
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.viewmodels.DashboardViewModel
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import java.text.NumberFormat
import java.util.Calendar
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardParityScreen(
    onNavigateToMap: () -> Unit = {},
    onNavigateToVehicles: () -> Unit = {},
    onNavigateToDrivers: () -> Unit = {},
    onNavigateToAlarms: () -> Unit = {},
    onNavigateToAlarmEvent: (AlarmEvent) -> Unit = {},
    onNavigateToAddAlarm: ((String) -> Unit)? = null,
    onNavigateToRouteHistory: (() -> Unit)? = null
) {
    val authVM = LocalAuthViewModel.current
    val vm: DashboardViewModel = viewModel()
    val user by authVM.currentUser.collectAsState()
    val vehicles by vm.vehicles.collectAsState()
    val vehiclesError by vm.vehiclesErrorMessage.collectAsState()
    val alerts by vm.alerts.collectAsState()
    val alertsError by vm.alertsErrorMessage.collectAsState()
    val isRefreshing by vm.isRefreshing.collectAsState()
    val isLoading by vm.isLoading.collectAsState()
    val isLoadingAlerts by vm.isLoadingAlerts.collectAsState()
    var selectedVehicle by remember { mutableStateOf<Vehicle?>(null) }

    val highlightedVehicles = remember(vehicles) {
        vehicles.sortedWith(
            compareByDescending<Vehicle> { it.speed }
                .thenBy { it.plate }
        ).take(3)
    }
    val mapVehicles = remember(vehicles) {
        vehicles.filter { it.hasValidCoordinates }.take(6)
    }

    selectedVehicle?.let { vehicle ->
        com.arveya.arveygo.ui.screens.fleet.VehicleDetailScreen(
            vehicle = vehicle,
            onBack = { selectedVehicle = null },
            onNavigateToRouteHistory = { _ ->
                selectedVehicle = null
                onNavigateToRouteHistory?.invoke()
            },
            onNavigateToAlarms = { _ ->
                selectedVehicle = null
                onNavigateToAlarms()
            },
            onNavigateToAddAlarm = { plate ->
                selectedVehicle = null
                onNavigateToAddAlarm?.invoke(plate)
            }
        )
        return
    }

    LaunchedEffect(Unit) {
        authVM.connectWebSocket()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "Dashboard",
                        fontSize = 17.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = AppColors.Navy
                )
            )
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = isRefreshing,
            onRefresh = { vm.refreshData() },
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                isLoading && vehicles.isEmpty() -> DashboardSkeletonBlock()
                vehiclesError != null && vehicles.isEmpty() -> DashboardStateCard(
                    icon = Icons.Default.CarCrash,
                    title = "Filo verisi alınamadı",
                    message = vehiclesError ?: "Araç verileri şu anda alınamıyor."
                )
                vehicles.isEmpty() -> DashboardStateCard(
                    icon = Icons.Default.DirectionsCar,
                    title = "Araç bulunmuyor",
                    message = "Gerçek veri geldiğinde dashboard burada canlı olarak listelenecek."
                )
                else -> Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .background(MaterialTheme.colorScheme.background)
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    HeroCard(
                        userName = user?.name ?: "Admin",
                        activeCount = vm.onlineCount,
                        idleCount = vm.idleCount,
                        closedCount = vm.kontakOffCount,
                        todayKm = vm.formatKm(vm.todayKm)
                    )

                    QuickActionsRow(
                        onNavigateToMap = onNavigateToMap,
                        onNavigateToVehicles = onNavigateToVehicles,
                        onNavigateToAlarms = onNavigateToAlarms,
                        onNavigateToRouteHistory = { onNavigateToRouteHistory?.invoke() }
                    )

                    MiniLiveMapCard(
                        vehicles = mapVehicles,
                        onNavigateToMap = onNavigateToMap
                    )

                    FeaturedVehiclesCard(
                        vehicles = highlightedVehicles,
                        onViewAll = onNavigateToVehicles,
                        onSelectVehicle = { selectedVehicle = it }
                    )

                    AlarmPulseCard(
                        alerts = alerts,
                        isLoading = isLoadingAlerts && alerts.isEmpty(),
                        errorMessage = alertsError,
                        onNavigateToAlarms = onNavigateToAlarms,
                        onOpenAlarm = onNavigateToAlarmEvent
                    )

                    if (isLoading) {
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun DashboardStateCard(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, message: String) {
    Card(
        shape = RoundedCornerShape(28.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 18.dp)
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    brush = Brush.linearGradient(
                        colors = listOf(AppColors.Navy, Color(0xFF1E367E))
                    )
                )
                .padding(horizontal = 24.dp, vertical = 32.dp)
        ) {
            Surface(
                shape = RoundedCornerShape(18.dp),
                color = Color.White.copy(alpha = 0.12f)
            ) {
                Icon(icon, null, tint = Color.White, modifier = Modifier.padding(14.dp).size(24.dp))
            }
            Text(title, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White)
            Text(
                message,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.74f)
            )
        }
    }
}

@Composable
private fun HeroCard(
    userName: String,
    activeCount: Int,
    idleCount: Int,
    closedCount: Int,
    todayKm: String
) {
    Card(
        shape = RoundedCornerShape(28.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    brush = Brush.linearGradient(
                        colors = listOf(AppColors.Navy, Color(0xFF1E367E))
                    )
                )
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            Row(verticalAlignment = Alignment.Top) {
                val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
                val greeting = when {
                    hour < 12 -> "Günaydın"
                    hour < 18 -> "İyi Günler"
                    else -> "İyi Akşamlar"
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text("Kontrol Merkezi", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.78f))
                    Spacer(Modifier.height(6.dp))
                    Text("$greeting, $userName", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color.White)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(currentDateLabel(), fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Color.White.copy(alpha = 0.72f))
                    Text(currentTimeLabel(), fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color.White)
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                HeroStat("Aktif", activeCount.toString(), AppColors.Online, Modifier.weight(1f))
                HeroStat("Rölanti", idleCount.toString(), AppColors.Idle, Modifier.weight(1f))
                HeroStat("Kapalı", closedCount.toString(), AppColors.Offline, Modifier.weight(1f))
            }

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                HeroMetric(Icons.Default.DirectionsCar, "Toplam Araç", NumberFormat.getNumberInstance(Locale("tr", "TR")).format(activeCount + idleCount + closedCount), Modifier.weight(1f))
                HeroMetric(Icons.Default.Route, "Bugün KM", todayKm, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun HeroStat(title: String, value: String, tone: Color, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .background(tone.copy(alpha = 0.18f), RoundedCornerShape(18.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp)
    ) {
        Text(title, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.72f))
        Spacer(Modifier.height(4.dp))
        Text(value, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color.White)
    }
}

@Composable
private fun HeroMetric(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, value: String, modifier: Modifier = Modifier) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(20.dp))
            .padding(14.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(42.dp)
                .background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(14.dp))
        ) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column {
            Text(title, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.72f))
            Text(value, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
        }
    }
}

@Composable
private fun QuickActionsRow(
    onNavigateToMap: () -> Unit,
    onNavigateToVehicles: () -> Unit,
    onNavigateToAlarms: () -> Unit,
    onNavigateToRouteHistory: () -> Unit
) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        QuickAction("Canlı Harita", Icons.Default.LocationOn, AppColors.Online, onNavigateToMap, Modifier.weight(1f))
        QuickAction("Araçlar", Icons.Default.DirectionsCar, AppColors.Navy, onNavigateToVehicles, Modifier.weight(1f))
        QuickAction("Alarmlar", Icons.Default.Notifications, AppColors.Offline, onNavigateToAlarms, Modifier.weight(1f))
        QuickAction("Rotalar", Icons.Default.Route, AppColors.Indigo, onNavigateToRouteHistory, Modifier.weight(1f))
    }
}

@Composable
private fun QuickAction(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier.clickable(onClick = onClick)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(48.dp)
                .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(16.dp))
        ) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.height(8.dp))
        Text(title, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface, maxLines = 1)
    }
}

@Composable
private fun MiniLiveMapCard(
    vehicles: List<Vehicle>,
    onNavigateToMap: () -> Unit
) {
    val mapViewRef = remember { mutableStateOf<MapView?>(null) }

    DisposableEffect(Unit) {
        onDispose {
            mapViewRef.value?.onDetach()
            mapViewRef.value = null
        }
    }

    Card(
        shape = RoundedCornerShape(26.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Canlı Akış", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.weight(1f))
                Text("${vehicles.size} araç", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp)
                    .clip(RoundedCornerShape(22.dp))
                    .clickable(onClick = onNavigateToMap)
            ) {
                AndroidView(
                    factory = { context ->
                        Configuration.getInstance().userAgentValue = context.packageName
                        MapView(context).apply {
                            setTileSource(TileSourceFactory.MAPNIK)
                            setMultiTouchControls(false)
                            zoomController.setVisibility(org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER)
                            mapViewRef.value = this
                        }
                    },
                    update = { mapView ->
                        mapView.overlays.clear()
                        val safeVehicles = vehicles.filter { it.hasValidCoordinates }
                        if (safeVehicles.isNotEmpty()) {
                            safeVehicles.forEach { vehicle ->
                                val marker = Marker(mapView).apply {
                                    position = GeoPoint(vehicle.lat, vehicle.lng)
                                    infoWindow = null
                                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                                    icon = null
                                    title = vehicle.plate
                                }
                                mapView.overlays.add(marker)
                            }
                            val latitudes = safeVehicles.map { it.lat }
                            val longitudes = safeVehicles.map { it.lng }
                            val box = BoundingBox(
                                latitudes.max() + 0.12,
                                longitudes.max() + 0.12,
                                latitudes.min() - 0.12,
                                longitudes.min() - 0.12
                            )
                            mapView.zoomToBoundingBox(box, true, 60)
                        } else {
                            mapView.controller.setZoom(6.0)
                            mapView.controller.setCenter(GeoPoint(39.0, 35.0))
                        }
                        mapView.invalidate()
                    },
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }
}

@Composable
private fun FeaturedVehiclesCard(
    vehicles: List<Vehicle>,
    onViewAll: () -> Unit,
    onSelectVehicle: (Vehicle) -> Unit
) {
    Card(
        shape = RoundedCornerShape(26.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Öne Çıkan Araçlar", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.weight(1f))
                GradientPillButton(title = "Tüm araçları gör", onClick = onViewAll)
            }

            vehicles.forEach { vehicle ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(22.dp))
                        .clickable { onSelectVehicle(vehicle) }
                        .padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Row(verticalAlignment = Alignment.Top) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(vehicle.plate, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                            Text(vehicle.model, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f), maxLines = 1)
                        }
                        StatusBadge(vehicle.status)
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                        VehicleMetricChip("Hız", vehicle.formattedSpeed, Modifier.weight(1f))
                        VehicleMetricChip("Bugün", vehicle.formattedTodayKm, Modifier.weight(1f))
                        VehicleMetricChip("Konum", vehicle.city.ifBlank { "Bekleniyor" }, Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun VehicleMetricChip(label: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(14.dp))
            .padding(horizontal = 10.dp, vertical = 9.dp)
    ) {
        Text(label, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
        Text(value, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun AlarmPulseCard(
    alerts: List<AlarmEvent>,
    isLoading: Boolean,
    errorMessage: String?,
    onNavigateToAlarms: () -> Unit,
    onOpenAlarm: (AlarmEvent) -> Unit
) {
    Card(
        shape = RoundedCornerShape(26.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Alarm Nabzı", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.weight(1f))
                GradientPillButton(title = "Alarm Merkezine Git", icon = Icons.Default.Notifications, onClick = onNavigateToAlarms)
            }

            when {
                isLoading -> {
                    Text("Alarmlar yükleniyor...", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                }

                errorMessage != null -> {
                    Text(errorMessage, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                }

                alerts.isEmpty() -> {
                    Text("Yeni alarm bulunmuyor", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                }

                else -> {
                    alerts.take(4).forEachIndexed { index, alert ->
                        if (index > 0) {
                            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.35f))
                        }
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onOpenAlarm(alert) }
                                .padding(vertical = 4.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(10.dp)
                                    .clip(CircleShape)
                                    .background(alert.severity.color)
                            )
                            Spacer(Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(alert.dashboardTitle, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                                Text(alert.dashboardDescription, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f), maxLines = 2, overflow = TextOverflow.Ellipsis)
                            }
                            Spacer(Modifier.width(8.dp))
                            Text(alert.dashboardDisplayTime, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun GradientPillButton(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector? = Icons.Default.ArrowForward,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(100.dp),
        color = Color.Transparent
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier
                .background(
                    brush = Brush.horizontalGradient(listOf(AppColors.Indigo, AppColors.Navy)),
                    shape = RoundedCornerShape(100.dp)
                )
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            if (icon != null) {
                Icon(icon, null, tint = Color.White, modifier = Modifier.size(14.dp))
            }
            Text(title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
        }
    }
}

private fun currentDateLabel(): String {
    val months = arrayOf("Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara")
    val calendar = Calendar.getInstance()
    return "${calendar.get(Calendar.DAY_OF_MONTH)} ${months[calendar.get(Calendar.MONTH)]}"
}

private fun currentTimeLabel(): String {
    val calendar = Calendar.getInstance()
    return "%02d:%02d".format(calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE))
}
