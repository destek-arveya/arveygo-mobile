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
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
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
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.services.WebSocketManager
import com.arveya.arveygo.services.WSEvent
import com.arveya.arveygo.ui.components.AvatarCircle
import com.arveya.arveygo.ui.components.VehicleCardsSkeletonList
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

// ViewModel for VehiclesList — uses real WebSocket data
class VehiclesListViewModel {
    val vehicles = mutableStateListOf<Vehicle>()
    var searchText by mutableStateOf("")
    var statusFilter by mutableStateOf<VehicleStatus?>(null)
    var groupFilter by mutableStateOf<String?>(null)
    var isLoading by mutableStateOf(true)
    var isRefreshing by mutableStateOf(false)
    var errorMessage by mutableStateOf<String?>(null)

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

    fun mergeVehicles(list: List<Vehicle>) {
        if (list.isEmpty()) return
        val current = vehicles.associateBy { it.id }
        vehicles.clear()
        vehicles.addAll(
            list.map { incoming ->
                current[incoming.id]?.copy(
                    lat = incoming.lat,
                    lng = incoming.lng,
                    speed = incoming.speed,
                    kontakOn = incoming.kontakOn,
                    ignition = incoming.ignition,
                    status = incoming.status,
                    lastPacketAt = incoming.lastPacketAt ?: current[incoming.id]?.lastPacketAt,
                    deviceTime = incoming.deviceTime ?: current[incoming.id]?.deviceTime,
                    todayKm = if (incoming.todayKm > (current[incoming.id]?.todayKm ?: 0)) incoming.todayKm else current[incoming.id]?.todayKm ?: incoming.todayKm,
                    dailyKm = if (incoming.dailyKm > (current[incoming.id]?.dailyKm ?: 0.0)) incoming.dailyKm else current[incoming.id]?.dailyKm ?: incoming.dailyKm
                ) ?: incoming
            }
        )
        errorMessage = null
        isLoading = false
    }

    fun mergeVehicle(vehicle: Vehicle) {
        val index = vehicles.indexOfFirst { it.id == vehicle.id }
        if (index >= 0) {
            val existing = vehicles[index]
            vehicles[index] = existing.copy(
                lat = vehicle.lat,
                lng = vehicle.lng,
                speed = vehicle.speed,
                kontakOn = vehicle.kontakOn,
                ignition = vehicle.ignition,
                status = vehicle.status,
                lastPacketAt = vehicle.lastPacketAt ?: existing.lastPacketAt,
                deviceTime = vehicle.deviceTime ?: existing.deviceTime,
                todayKm = if (vehicle.todayKm > existing.todayKm) vehicle.todayKm else existing.todayKm,
                dailyKm = if (vehicle.dailyKm > existing.dailyKm) vehicle.dailyKm else existing.dailyKm
            )
        } else {
            vehicles.add(vehicle)
        }
    }

    suspend fun loadVehiclesFromApi() {
        errorMessage = null
        try {
            val apiVehicles = APIService.fetchVehicles()
            mergeVehicles(apiVehicles)
        } catch (e: Exception) {
            if (vehicles.isEmpty()) {
                errorMessage = e.localizedMessage ?: "Araç verileri alınamadı."
            }
            isLoading = false
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VehiclesListScreen(
    onNavigateToRouteHistory: ((Vehicle) -> Unit)? = null,
    onNavigateToAlarms: (() -> Unit)? = null,
    onNavigateToAddAlarm: ((String) -> Unit)? = null
) {
    val authVM = LocalAuthViewModel.current
    val user by authVM.currentUser.collectAsState()
    val vm = remember { VehiclesListViewModel() }
    val scope = rememberCoroutineScope()
    var selectedVehicle by remember { mutableStateOf<Vehicle?>(null) }
    val colors = MaterialTheme.colorScheme

    // Subscribe to WebSocket vehicle data
    LaunchedEffect(Unit) {
        launch {
            vm.loadVehiclesFromApi()
        }
        launch {
            WebSocketManager.vehicleList.collectLatest { list ->
                if (list.isNotEmpty()) {
                    vm.mergeVehicles(list)
                }
            }
        }
        launch {
            WebSocketManager.events.collect { event ->
                when (event) {
                    is WSEvent.Snapshot -> {
                        vm.mergeVehicles(event.vehicles)
                    }
                    is WSEvent.Update -> {
                        vm.mergeVehicle(event.vehicle)
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
                title = {
                    Column {
                        Text("Araçlar", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = colors.onSurface)
                        Text("Kurumsal filo görünümü", fontSize = 10.sp, color = colors.onSurface.copy(alpha = 0.55f))
                    }
                },
                actions = {
                    Box {
                        IconButton(onClick = {}) {
                            Icon(Icons.Default.Notifications, null, tint = colors.onSurface.copy(alpha = 0.55f), modifier = Modifier.size(20.dp))
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
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.background)
            )
        }
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = vm.isRefreshing,
            onRefresh = {
                vm.isRefreshing = true
                scope.launch {
                    WebSocketManager.reconnect()
                    vm.loadVehiclesFromApi()
                    vm.isRefreshing = false
                }
            },
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                vm.isLoading && vm.vehicles.isEmpty() -> VehicleCardsSkeletonList()
                vm.errorMessage != null && vm.vehicles.isEmpty() -> VehicleListErrorState(vm.errorMessage ?: "Araç verileri alınamadı.") {
                    scope.launch { vm.loadVehiclesFromApi() }
                }
                else -> Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(colors.background)
                        .verticalScroll(rememberScrollState())
                ) {
                    Spacer(Modifier.height(6.dp))

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

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                            .background(colors.surface, RoundedCornerShape(12.dp))
                            .border(1.dp, colors.outline.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                            .padding(horizontal = 14.dp)
                            .height(44.dp)
                    ) {
                        Icon(Icons.Default.Search, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(10.dp))
                        BasicTextField(
                            value = vm.searchText,
                            onValueChange = { vm.searchText = it },
                            textStyle = LocalTextStyle.current.copy(fontSize = 14.sp, color = colors.onSurface),
                            modifier = Modifier.weight(1f),
                            singleLine = true,
                            decorationBox = { innerTextField ->
                                Box(contentAlignment = Alignment.CenterStart) {
                                    if (vm.searchText.isEmpty()) {
                                        Text("Plaka, araç veya sürücü ara...", fontSize = 14.sp, color = colors.onSurface.copy(alpha = 0.45f))
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
                                    .background(colors.surface, RoundedCornerShape(8.dp))
                                    .border(1.dp, colors.outline.copy(alpha = 0.4f), RoundedCornerShape(8.dp))
                                    .clickable { groupMenuExpanded = true }
                                    .padding(horizontal = 12.dp, vertical = 8.dp)
                            ) {
                                Icon(Icons.Default.FolderOpen, null, tint = colors.onSurface.copy(alpha = 0.55f), modifier = Modifier.size(14.dp))
                                Spacer(Modifier.width(6.dp))
                                Text(vm.groupFilter ?: "Tüm Gruplar", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = colors.onSurface)
                                Spacer(Modifier.width(5.dp))
                                Icon(Icons.Default.KeyboardArrowDown, null, tint = colors.onSurface, modifier = Modifier.size(14.dp))
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
                            color = colors.onSurface.copy(alpha = 0.55f)
                        )
                    }

                    Spacer(Modifier.height(14.dp))

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
                                VehicleCard(
                                    vehicle = vehicle,
                                    onClick = { selectedVehicle = vehicle }
                                )
                            }
                        }
                    }

                    Spacer(Modifier.height(24.dp))
                }
            }
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
    val colors = MaterialTheme.colorScheme
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(
                if (isSelected) color.copy(alpha = 0.12f)
                else colors.surface
            )
            .border(
                1.dp,
                if (isSelected) color.copy(alpha = 0.3f) else colors.outline.copy(alpha = 0.4f),
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
            color = if (isSelected) color else colors.onSurface.copy(alpha = 0.7f)
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
                else colors.surfaceVariant
                )
                .padding(horizontal = 6.dp, vertical = 1.dp)
        )
    }
}

// ── Vehicle Card ──
@Composable
private fun VehicleCard(vehicle: Vehicle, onClick: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(colors.surface)
            .border(1.dp, colors.outline.copy(alpha = 0.35f), RoundedCornerShape(18.dp))
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
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    color = colors.onSurface
                )
                if (vehicle.vehicleType.isNotEmpty() && vehicle.vehicleType != "Ticari") {
                    Text(
                        vehicle.vehicleType,
                        fontSize = 10.sp,
                        color = colors.onSurface.copy(alpha = 0.55f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            FleetStatusBadge(vehicle.fleetStatus)
            Icon(
                Icons.Default.ChevronRight, null,
                tint = colors.onSurface.copy(alpha = 0.35f),
                modifier = Modifier.size(18.dp)
            )
        }

        // ── Stats Grid: 4 columns ──
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(colors.surfaceVariant)
                .padding(vertical = 8.dp)
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

        // ── Footer: Time + Temp/Humidity + Driver + Fuel ──
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(colors.surfaceVariant.copy(alpha = 0.75f))
                .padding(horizontal = 16.dp, vertical = 9.dp)
        ) {
            if (vehicle.listLastInfoLabel.isNotEmpty()) {
                Icon(Icons.Default.Schedule, null, tint = AppColors.TextFaint, modifier = Modifier.size(12.dp))
                Spacer(Modifier.width(3.dp))
                Text(vehicle.listLastInfoLabel, fontSize = 10.sp, color = colors.onSurface.copy(alpha = 0.42f))
            }

            // Temperature
            vehicle.temperatureC?.let { temp ->
                if (vehicle.listLastInfoLabel.isNotEmpty()) {
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
                    color = colors.onSurface.copy(alpha = 0.55f),
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
    val colors = MaterialTheme.colorScheme
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
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = if (value == "0 km/h" || value == "0 km") colors.onSurface else color,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Text(label, fontSize = 8.sp, color = colors.onSurface.copy(alpha = 0.48f))
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

@Composable
private fun VehicleListErrorState(message: String, onRetry: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 28.dp)
    ) {
        Icon(Icons.Default.WifiOff, null, tint = AppColors.Offline, modifier = Modifier.size(44.dp))
        Spacer(Modifier.height(12.dp))
        Text("Araç verisi alınamadı", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
        Spacer(Modifier.height(6.dp))
        Text(message, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f), textAlign = TextAlign.Center)
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = onRetry,
            colors = ButtonDefaults.buttonColors(containerColor = AppColors.Indigo),
            shape = RoundedCornerShape(10.dp)
        ) {
            Text("Tekrar Dene", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}
