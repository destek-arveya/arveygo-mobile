package com.arveya.arveygo.ui.screens.fleet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.models.*
import com.arveya.arveygo.services.WebSocketManager
import com.arveya.arveygo.services.WSEvent
import com.arveya.arveygo.ui.components.AvatarCircle
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

// ViewModel for VehiclesList — uses real WebSocket data
class VehiclesListViewModel {
    val vehicles = mutableStateListOf<Vehicle>()
    var searchText by mutableStateOf("")
    var statusFilter by mutableStateOf<VehicleStatus?>(null)
    var groupFilter by mutableStateOf<String?>(null)
    var _initialized = false

    // Alert counts
    val expiredDocs get() = 0
    val criticalDocs get() = 0
    val wornTires get() = 0
    val upcomingMaint get() = 0

    val groups: List<String>
        get() = vehicles.map { it.group }.distinct().sorted()

    val statusFilterLabel: String
        get() = when (statusFilter) {
            VehicleStatus.IGNITION_ON -> "Kontak Açık"
            VehicleStatus.IGNITION_OFF -> "Kontak Kapalı"
            VehicleStatus.NO_DATA -> "Bilgi Yok"
            VehicleStatus.SLEEPING -> "Cihaz Uykuda"
            null -> "Tüm Durumlar"
        }

    val filteredVehicles: List<Vehicle>
        get() {
            var result = vehicles.toList()
            statusFilter?.let { filter -> result = result.filter { it.status == filter } }
            groupFilter?.let { group -> result = result.filter { it.group == group } }
            val q = searchText.lowercase()
            if (q.isNotEmpty()) {
                result = result.filter {
                    it.plate.lowercase().contains(q) ||
                            it.model.lowercase().contains(q) ||
                            it.driver.lowercase().contains(q)
                }
            }
            return result
        }

    // Status summary counts
    val onlineCount get() = vehicles.count { it.status == VehicleStatus.IGNITION_ON }
    val offlineCount get() = vehicles.count { it.status == VehicleStatus.IGNITION_OFF }
    val noDataCount get() = vehicles.count { it.status == VehicleStatus.NO_DATA }
    val sleepingCount get() = vehicles.count { it.status == VehicleStatus.SLEEPING }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VehiclesListScreen(
    onMenuClick: () -> Unit,
    onNavigateToRouteHistory: ((Vehicle) -> Unit)? = null,
    onNavigateToAlarms: (() -> Unit)? = null,
    onNavigateToAddAlarm: ((String) -> Unit)? = null
) {
    val authVM = LocalAuthViewModel.current
    val user by authVM.currentUser.collectAsState()
    val vm = remember { VehiclesListViewModel() }
    var selectedVehicle by remember { mutableStateOf<Vehicle?>(null) }

    // Subscribe to WebSocket vehicle data
    LaunchedEffect(Unit) {
        launch {
            WebSocketManager.vehicleList.collectLatest { list ->
                if (list.isNotEmpty()) {
                    vm.vehicles.clear()
                    vm.vehicles.addAll(list)
                }
            }
        }
        launch {
            WebSocketManager.events.collect { event ->
                when (event) {
                    is WSEvent.Snapshot -> {
                        vm.vehicles.clear()
                        vm.vehicles.addAll(event.vehicles)
                    }
                    is WSEvent.Update -> {
                        val idx = vm.vehicles.indexOfFirst { it.id == event.vehicle.id }
                        if (idx >= 0) vm.vehicles[idx] = event.vehicle
                        else vm.vehicles.add(event.vehicle)
                    }
                    else -> {}
                }
            }
        }
    }

    // If a vehicle is selected, show its detail
    selectedVehicle?.let { vehicle ->
        VehicleDetailScreen(
            vehicle = vehicle,
            onBack = { selectedVehicle = null },
            onNavigateToRouteHistory = { v ->
                selectedVehicle = null
                onNavigateToRouteHistory?.invoke(v)
            },
            onNavigateToAlarms = { _ ->
                selectedVehicle = null
                onNavigateToAlarms?.invoke()
            },
            onNavigateToAddAlarm = { plate ->
                selectedVehicle = null
                onNavigateToAddAlarm?.invoke(plate)
            }
        )
        return
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
                        Text("Araçlarım", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        Text("Filo Yönetimi / Araçlar", fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                },
                actions = {
                    Box {
                        IconButton(onClick = {}) {
                            Icon(Icons.Default.Notifications, null, tint = AppColors.TextMuted, modifier = Modifier.size(20.dp))
                        }
                        Box(
                            modifier = Modifier
                                .size(7.dp)
                                .clip(CircleShape)
                                .background(Color.Red)
                                .align(Alignment.TopEnd)
                                .offset(x = (-6).dp, y = 10.dp)
                        )
                    }
                    AvatarCircle(initials = user?.avatar ?: "A", size = 30.dp)
                    Spacer(Modifier.width(12.dp))
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = AppColors.Surface)
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(AppColors.Bg)
                .verticalScroll(rememberScrollState())
        ) {
            Spacer(Modifier.height(6.dp))

            // ── Status Summary Chips ──
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                item {
                    StatusChip(
                        label = "Toplam",
                        count = vm.vehicles.size,
                        color = AppColors.Navy,
                        isSelected = vm.statusFilter == null,
                        onClick = { vm.statusFilter = null }
                    )
                }
                item {
                    StatusChip(
                        label = "Kontak Açık",
                        count = vm.onlineCount,
                        color = AppColors.Online,
                        isSelected = vm.statusFilter == VehicleStatus.IGNITION_ON,
                        onClick = { vm.statusFilter = if (vm.statusFilter == VehicleStatus.IGNITION_ON) null else VehicleStatus.IGNITION_ON }
                    )
                }
                item {
                    StatusChip(
                        label = "Kontak Kapalı",
                        count = vm.offlineCount,
                        color = AppColors.Offline,
                        isSelected = vm.statusFilter == VehicleStatus.IGNITION_OFF,
                        onClick = { vm.statusFilter = if (vm.statusFilter == VehicleStatus.IGNITION_OFF) null else VehicleStatus.IGNITION_OFF }
                    )
                }
                item {
                    StatusChip(
                        label = "Bilgi Yok",
                        count = vm.noDataCount,
                        color = AppColors.TextMuted,
                        isSelected = vm.statusFilter == VehicleStatus.NO_DATA,
                        onClick = { vm.statusFilter = if (vm.statusFilter == VehicleStatus.NO_DATA) null else VehicleStatus.NO_DATA }
                    )
                }
                item {
                    StatusChip(
                        label = "Uyku",
                        count = vm.sleepingCount,
                        color = AppColors.Idle,
                        isSelected = vm.statusFilter == VehicleStatus.SLEEPING,
                        onClick = { vm.statusFilter = if (vm.statusFilter == VehicleStatus.SLEEPING) null else VehicleStatus.SLEEPING }
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            // ── Search bar ──
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .background(AppColors.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
                    .padding(horizontal = 14.dp)
                    .height(44.dp)
            ) {
                Icon(Icons.Default.Search, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(10.dp))
                BasicTextField(
                    value = vm.searchText,
                    onValueChange = { vm.searchText = it },
                    textStyle = LocalTextStyle.current.copy(fontSize = 14.sp, color = AppColors.Navy),
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    decorationBox = { innerTextField ->
                        Box(contentAlignment = Alignment.CenterStart) {
                            if (vm.searchText.isEmpty()) {
                                Text("Plaka, araç veya sürücü ara...", fontSize = 14.sp, color = AppColors.TextMuted)
                            }
                            innerTextField()
                        }
                    }
                )
                if (vm.searchText.isNotEmpty()) {
                    IconButton(onClick = { vm.searchText = "" }, modifier = Modifier.size(20.dp)) {
                        Icon(Icons.Default.Close, null, tint = AppColors.TextFaint, modifier = Modifier.size(16.dp))
                    }
                }
            }

            Spacer(Modifier.height(8.dp))

            // ── Group filter + count ──
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                var groupMenuExpanded by remember { mutableStateOf(false) }
                Box {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .background(AppColors.Surface, RoundedCornerShape(8.dp))
                            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(8.dp))
                            .clickable { groupMenuExpanded = true }
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        Icon(Icons.Default.FolderOpen, null, tint = AppColors.TextMuted, modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(vm.groupFilter ?: "Tüm Gruplar", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                        Spacer(Modifier.width(5.dp))
                        Icon(Icons.Default.KeyboardArrowDown, null, tint = AppColors.Navy, modifier = Modifier.size(14.dp))
                    }
                    DropdownMenu(expanded = groupMenuExpanded, onDismissRequest = { groupMenuExpanded = false }) {
                        DropdownMenuItem(text = { Text("Tüm Gruplar", fontSize = 12.sp) }, onClick = { vm.groupFilter = null; groupMenuExpanded = false })
                        vm.groups.forEach { group ->
                            DropdownMenuItem(text = { Text(group, fontSize = 12.sp) }, onClick = { vm.groupFilter = group; groupMenuExpanded = false })
                        }
                    }
                }

                Spacer(Modifier.weight(1f))

                Text(
                    "${vm.filteredVehicles.size} araç listeleniyor",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.TextMuted
                )
            }

            Spacer(Modifier.height(14.dp))

            // ── Vehicle Cards ──
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                if (vm.filteredVehicles.isEmpty()) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 60.dp)
                    ) {
                        Icon(Icons.Default.DirectionsCar, null, tint = AppColors.TextFaint.copy(alpha = 0.4f), modifier = Modifier.size(48.dp))
                        Spacer(Modifier.height(16.dp))
                        Text("Araç bulunamadı", fontSize = 15.sp, fontWeight = FontWeight.Medium, color = AppColors.TextMuted)
                        Text("Filtre veya arama kriterlerinizi değiştirin", fontSize = 12.sp, color = AppColors.TextFaint)
                    }
                } else {
                    vm.filteredVehicles.forEach { vehicle ->
                        VehicleCard(vehicle = vehicle, onClick = { selectedVehicle = vehicle })
                    }
                }
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

// ── Status Filter Chip ──
@Composable
private fun StatusChip(
    label: String,
    count: Int,
    color: Color,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(
                if (isSelected) color.copy(alpha = 0.12f)
                else AppColors.Surface
            )
            .border(
                1.dp,
                if (isSelected) color.copy(alpha = 0.3f) else AppColors.BorderSoft,
                RoundedCornerShape(20.dp)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(color)
        )
        Spacer(Modifier.width(6.dp))
        Text(
            label,
            fontSize = 12.sp,
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
            color = if (isSelected) color else AppColors.TextSecondary
        )
        Spacer(Modifier.width(6.dp))
        Text(
            "$count",
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = if (isSelected) color else AppColors.TextMuted,
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(
                    if (isSelected) color.copy(alpha = 0.15f)
                    else AppColors.Bg
                )
                .padding(horizontal = 6.dp, vertical = 1.dp)
        )
    }
}

// ── Vehicle Card ──
@Composable
private fun VehicleCard(vehicle: Vehicle, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.Surface)
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
    ) {
        // ── Header: Status + Plate + Type + Fleet Badge + Chevron ──
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp)
        ) {
            // Status indicator with pulse effect
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(vehicle.status.color)
                    .border(2.dp, vehicle.status.color.copy(alpha = 0.3f), CircleShape)
            )
            Spacer(Modifier.width(10.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    vehicle.plate,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.Navy
                )
                if (vehicle.vehicleType.isNotEmpty() && vehicle.vehicleType != "Ticari") {
                    Text(
                        vehicle.vehicleType,
                        fontSize = 11.sp,
                        color = AppColors.TextMuted,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            FleetStatusBadge(vehicle.fleetStatus)
            Spacer(Modifier.width(8.dp))
            Icon(
                Icons.Default.ChevronRight, null,
                tint = AppColors.TextFaint,
                modifier = Modifier.size(18.dp)
            )
        }

        // ── Stats Grid: 4 columns ──
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(AppColors.Bg.copy(alpha = 0.7f))
                .padding(vertical = 10.dp)
        ) {
            CompactStatItem(
                icon = Icons.Default.Speed,
                value = vehicle.formattedSpeed,
                label = "Hız",
                color = if (vehicle.speed > 0) AppColors.Online else AppColors.TextMuted,
                modifier = Modifier.weight(1f)
            )
            CompactStatItem(
                icon = Icons.Default.Today,
                value = vehicle.formattedTodayKm,
                label = "Bugün",
                color = AppColors.Indigo,
                modifier = Modifier.weight(1f)
            )
            CompactStatItem(
                icon = Icons.Default.Route,
                value = vehicle.formattedTotalKm,
                label = "Toplam",
                color = AppColors.Navy,
                modifier = Modifier.weight(1f)
            )
            CompactStatItem(
                icon = Icons.Default.VpnKey,
                value = if (vehicle.kontakOn) "Açık" else "Kapalı",
                label = "Kontak",
                color = if (vehicle.kontakOn) AppColors.Online else AppColors.Offline,
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(Modifier.height(8.dp))

        // ── Location row (if available) ──
        if (vehicle.locationDisplay != "—") {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .padding(bottom = 8.dp)
            ) {
                Icon(Icons.Default.LocationOn, null, tint = AppColors.Indigo.copy(alpha = 0.6f), modifier = Modifier.size(13.dp))
                Spacer(Modifier.width(4.dp))
                Text(
                    vehicle.locationDisplay,
                    fontSize = 11.sp,
                    color = AppColors.TextSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        // ── Footer: Time + Temp/Humidity + Driver + Fuel ──
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Bg.copy(alpha = 0.4f))
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            // Device time
            if (vehicle.deviceTime != null) {
                Icon(Icons.Default.Schedule, null, tint = AppColors.TextFaint, modifier = Modifier.size(12.dp))
                Spacer(Modifier.width(3.dp))
                Text(vehicle.formattedDeviceTime, fontSize = 10.sp, color = AppColors.TextFaint)
            }

            // Temperature
            vehicle.temperatureC?.let { temp ->
                if (vehicle.deviceTime != null) {
                    Spacer(Modifier.width(8.dp))
                    Box(Modifier.size(3.dp).clip(CircleShape).background(AppColors.BorderSoft))
                    Spacer(Modifier.width(8.dp))
                }
                Text(
                    "🌡️${"%.1f".format(temp)}°C",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (temp < 0) Color(0xFF3B82F6) else if (temp < 30) AppColors.Online else Color(0xFFEF4444)
                )
            }

            // Humidity
            vehicle.humidityPct?.let { hum ->
                Spacer(Modifier.width(6.dp))
                Text(
                    "💧${"%.0f".format(hum)}%",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.Indigo
                )
            }

            Spacer(Modifier.weight(1f))

            // Driver
            val driverText = vehicle.driverName.ifEmpty { vehicle.driver }
            if (driverText.isNotEmpty()) {
                Icon(Icons.Default.Person, null, tint = AppColors.TextFaint, modifier = Modifier.size(12.dp))
                Spacer(Modifier.width(3.dp))
                Text(
                    driverText,
                    fontSize = 10.sp,
                    color = AppColors.TextMuted,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.widthIn(max = 100.dp)
                )
            }
        }
    }
}

// ── Compact Stat Item for the grid ──
@Composable
private fun CompactStatItem(
    icon: ImageVector,
    value: String,
    label: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier.padding(vertical = 4.dp)
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(RoundedCornerShape(7.dp))
                .background(color.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(14.dp))
        }
        Spacer(Modifier.height(4.dp))
        Text(
            value,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            color = color,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Text(label, fontSize = 9.sp, color = AppColors.TextMuted)
    }
}

// ── Fleet Status Badge ──
@Composable
private fun FleetStatusBadge(status: FleetVehicleStatus, modifier: Modifier = Modifier) {
    Text(
        status.label,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        color = status.color,
        modifier = modifier
            .background(status.color.copy(alpha = 0.1f), RoundedCornerShape(20.dp))
            .padding(horizontal = 10.dp, vertical = 4.dp)
    )
}
