package com.arveya.arveygo.ui.screens.fleet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
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
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

// ViewModel for VehiclesList — uses real WebSocket data, fallback to dummy
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
            VehicleStatus.ONLINE -> "Aktif"
            VehicleStatus.OFFLINE -> "Pasif"
            VehicleStatus.IDLE -> "Bakımda"
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

    init {
        // Don't load dummy by default — wait for WS data via LaunchedEffect
    }

    fun loadDummyData() {
        if (vehicles.isNotEmpty()) return
        vehicles.addAll(
            listOf(
                Vehicle("1", "34 ABC 123", "Ford Transit", VehicleStatus.ONLINE, true, 48320, 312, "Ahmet Yılmaz", "İstanbul", 41.0082, 28.9784),
                Vehicle("2", "06 XYZ 789", "Mercedes Sprinter", VehicleStatus.OFFLINE, false, 92100, 0, "Mehmet Demir", "Ankara", 39.9334, 32.8597),
                Vehicle("3", "35 DEF 456", "Renault Master", VehicleStatus.ONLINE, true, 31540, 187, "Ayşe Kaya", "İzmir", 38.4192, 27.1287),
                Vehicle("4", "16 GHI 321", "Volkswagen Crafter", VehicleStatus.IDLE, false, 67890, 0, "Can Öztürk", "Bursa", 40.1885, 29.0610),
                Vehicle("5", "41 JKL 654", "Fiat Ducato", VehicleStatus.ONLINE, true, 22430, 95, "Zeynep Şahin", "Kocaeli", 40.7654, 29.9408),
                Vehicle("6", "07 MNO 987", "Peugeot Boxer", VehicleStatus.OFFLINE, false, 55670, 0, "Ali Çelik", "Antalya", 36.8969, 30.7133),
                Vehicle("7", "34 PRS 111", "Iveco Daily", VehicleStatus.ONLINE, true, 14220, 241, "Fatma Arslan", "İstanbul", 41.0422, 29.0083),
                Vehicle("8", "06 TUV 222", "Ford Transit Custom", VehicleStatus.IDLE, false, 38900, 0, "Hasan Koç", "Ankara", 39.9208, 32.8541),
            )
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VehiclesListScreen(onMenuClick: () -> Unit) {
    val authVM = LocalAuthViewModel.current
    val user by authVM.currentUser.collectAsState()
    val vm = remember { VehiclesListViewModel() }
    var selectedVehicle by remember { mutableStateOf<Vehicle?>(null) }

    // Subscribe to WebSocket vehicle data
    LaunchedEffect(Unit) {
        // Observe vehicle list from WS
        launch {
            WebSocketManager.vehicleList.collectLatest { list ->
                if (list.isNotEmpty()) {
                    vm.vehicles.clear()
                    vm.vehicles.addAll(list)
                }
            }
        }
        // Also listen for individual events
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
        // Fallback: load dummy data after 3 seconds if no WS data
        launch {
            delay(3000)
            if (vm.vehicles.isEmpty()) {
                vm.loadDummyData()
            }
        }
    }

    // If a vehicle is selected, show its detail
    selectedVehicle?.let { vehicle ->
        VehicleDetailScreen(
            vehicle = vehicle,
            onBack = { selectedVehicle = null }
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
                    // Notification bell
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
            // Alert Summary Cards (horizontal scroll)
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.padding(top = 6.dp)
            ) {
                item {
                    AlertSummaryCard(
                        icon = Icons.Default.Error,
                        value = "${vm.expiredDocs}",
                        label = "Süresi Dolmuş Belge",
                        iconBg = Color.Red.copy(alpha = 0.1f),
                        iconColor = Color.Red
                    )
                }
                item {
                    AlertSummaryCard(
                        icon = Icons.Default.Warning,
                        value = "${vm.criticalDocs}",
                        label = "Yaklaşan Belge Süresi",
                        iconBg = Color(0xFFFFA000).copy(alpha = 0.1f),
                        iconColor = Color(0xFFFFA000)
                    )
                }
                item {
                    AlertSummaryCard(
                        icon = Icons.Default.Circle,
                        value = "${vm.wornTires}",
                        label = "Lastik Değişimi",
                        iconBg = Color.Red.copy(alpha = 0.1f),
                        iconColor = Color.Red
                    )
                }
                item {
                    AlertSummaryCard(
                        icon = Icons.Default.Build,
                        value = "${vm.upcomingMaint}",
                        label = "30 Gün Bakım",
                        iconBg = Color.Blue.copy(alpha = 0.1f),
                        iconColor = Color.Blue
                    )
                }
            }

            Spacer(Modifier.height(14.dp))

            // Search bar
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .background(AppColors.Surface, RoundedCornerShape(10.dp))
                    .border(1.5.dp, AppColors.BorderSoft, RoundedCornerShape(10.dp))
                    .padding(horizontal = 12.dp)
                    .height(40.dp)
            ) {
                Icon(Icons.Default.Search, null, tint = AppColors.TextMuted, modifier = Modifier.size(13.dp))
                Spacer(Modifier.width(8.dp))
                BasicTextField(
                    value = vm.searchText,
                    onValueChange = { vm.searchText = it },
                    textStyle = LocalTextStyle.current.copy(fontSize = 13.sp, color = AppColors.Navy),
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    decorationBox = { innerTextField ->
                        Box(contentAlignment = Alignment.CenterStart) {
                            if (vm.searchText.isEmpty()) {
                                Text("Plaka, araç veya sürücü ara...", fontSize = 13.sp, color = AppColors.TextMuted)
                            }
                            innerTextField()
                        }
                    }
                )
                if (vm.searchText.isNotEmpty()) {
                    IconButton(onClick = { vm.searchText = "" }, modifier = Modifier.size(18.dp)) {
                        Icon(Icons.Default.Close, null, tint = AppColors.TextFaint, modifier = Modifier.size(14.dp))
                    }
                }
            }

            Spacer(Modifier.height(10.dp))

            // Filter row
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                // Status filter dropdown
                var statusMenuExpanded by remember { mutableStateOf(false) }
                Box {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .background(AppColors.Surface, RoundedCornerShape(8.dp))
                            .border(1.5.dp, AppColors.BorderSoft, RoundedCornerShape(8.dp))
                            .clickable { statusMenuExpanded = true }
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        Text(vm.statusFilterLabel, fontSize = 11.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                        Spacer(Modifier.width(5.dp))
                        Icon(Icons.Default.KeyboardArrowDown, null, tint = AppColors.Navy, modifier = Modifier.size(12.dp))
                    }
                    DropdownMenu(expanded = statusMenuExpanded, onDismissRequest = { statusMenuExpanded = false }) {
                        DropdownMenuItem(text = { Text("Tüm Durumlar", fontSize = 12.sp) }, onClick = { vm.statusFilter = null; statusMenuExpanded = false })
                        DropdownMenuItem(text = { Text("Aktif", fontSize = 12.sp) }, onClick = { vm.statusFilter = VehicleStatus.ONLINE; statusMenuExpanded = false })
                        DropdownMenuItem(text = { Text("Pasif / Çevrimdışı", fontSize = 12.sp) }, onClick = { vm.statusFilter = VehicleStatus.OFFLINE; statusMenuExpanded = false })
                        DropdownMenuItem(text = { Text("Bakımda", fontSize = 12.sp) }, onClick = { vm.statusFilter = VehicleStatus.IDLE; statusMenuExpanded = false })
                    }
                }

                Spacer(Modifier.width(8.dp))

                // Group filter dropdown
                var groupMenuExpanded by remember { mutableStateOf(false) }
                Box {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .background(AppColors.Surface, RoundedCornerShape(8.dp))
                            .border(1.5.dp, AppColors.BorderSoft, RoundedCornerShape(8.dp))
                            .clickable { groupMenuExpanded = true }
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        Text(vm.groupFilter ?: "Tüm Gruplar", fontSize = 11.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                        Spacer(Modifier.width(5.dp))
                        Icon(Icons.Default.KeyboardArrowDown, null, tint = AppColors.Navy, modifier = Modifier.size(12.dp))
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
                    "${vm.filteredVehicles.size} / ${vm.vehicles.size} araç",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.TextMuted
                )
            }

            Spacer(Modifier.height(14.dp))

            // Vehicle Table
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .background(AppColors.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            ) {
                // Table header
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppColors.Bg, RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp))
                        .padding(horizontal = 14.dp, vertical = 10.dp)
                ) {
                    Text(
                        "PLAKA / ARAÇ",
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.TextMuted,
                        letterSpacing = 0.5.sp,
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        "DURUM",
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.TextMuted,
                        letterSpacing = 0.5.sp,
                        modifier = Modifier.width(70.dp),
                        textAlign = TextAlign.Center
                    )
                    Text(
                        "KM",
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.TextMuted,
                        letterSpacing = 0.5.sp,
                        modifier = Modifier.width(60.dp),
                        textAlign = TextAlign.End
                    )
                    // Space for chevron
                    Spacer(Modifier.width(20.dp))
                }

                // Table rows
                if (vm.filteredVehicles.isEmpty()) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 40.dp)
                    ) {
                        Icon(Icons.Default.DirectionsCar, null, tint = AppColors.TextFaint.copy(alpha = 0.5f), modifier = Modifier.size(36.dp))
                        Spacer(Modifier.height(12.dp))
                        Text("Araç bulunamadı", fontSize = 13.sp, color = AppColors.TextMuted)
                    }
                } else {
                    vm.filteredVehicles.forEach { vehicle ->
                        VehicleTableRow(vehicle = vehicle, onClick = { selectedVehicle = vehicle })
                    }
                }
            }

            Spacer(Modifier.height(20.dp))
        }
    }
}

@Composable
private fun AlertSummaryCard(
    icon: ImageVector,
    value: String,
    label: String,
    iconBg: Color,
    iconColor: Color
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .background(AppColors.Surface, RoundedCornerShape(12.dp))
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            .padding(14.dp)
    ) {
        Icon(
            icon, null,
            tint = iconColor,
            modifier = Modifier
                .size(40.dp)
                .background(iconBg, RoundedCornerShape(10.dp))
                .padding(10.dp)
        )
        Spacer(Modifier.width(12.dp))
        Column {
            Text(value, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
            Text(label, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = AppColors.TextMuted, maxLines = 1)
        }
    }
}

@Composable
private fun VehicleTableRow(vehicle: Vehicle, onClick: () -> Unit) {
    Column {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(horizontal = 14.dp, vertical = 12.dp)
        ) {
            // Status dot + plate/model
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.weight(1f)
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(vehicle.status.color)
                )
                Spacer(Modifier.width(8.dp))
                Column {
                    Text(
                        vehicle.plate,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.Navy
                    )
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            vehicle.model,
                            fontSize = 10.sp,
                            color = AppColors.TextMuted,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        if (vehicle.driver.isNotEmpty()) {
                            Text(" • ", fontSize = 8.sp, color = AppColors.TextFaint)
                            Text(
                                vehicle.driver,
                                fontSize = 10.sp,
                                color = AppColors.TextMuted,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                        vehicle.temperatureC?.let { temp ->
                            Text(" • ", fontSize = 8.sp, color = AppColors.TextFaint)
                            Text(
                                "\uD83C\uDF21\uFE0F${"%.1f".format(temp)}°C",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = if (temp < 0) Color.Blue else if (temp < 30) AppColors.Online else Color.Red
                            )
                        }
                    }
                }
            }

            // Fleet status badge
            FleetStatusBadge(vehicle.fleetStatus, modifier = Modifier.width(70.dp))

            // Km
            Text(
                vehicle.formattedTotalKm,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Navy,
                modifier = Modifier.width(60.dp),
                textAlign = TextAlign.End
            )

            // Chevron
            Spacer(Modifier.width(6.dp))
            Icon(
                Icons.Default.ChevronRight, null,
                tint = AppColors.TextFaint,
                modifier = Modifier.size(14.dp)
            )
        }
        HorizontalDivider(modifier = Modifier.padding(start = 40.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
    }
}

@Composable
private fun FleetStatusBadge(status: FleetVehicleStatus, modifier: Modifier = Modifier) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
    ) {
        Text(
            status.label,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            color = status.color,
            modifier = Modifier
                .background(status.color.copy(alpha = 0.1f), RoundedCornerShape(20.dp))
                .padding(horizontal = 8.dp, vertical = 3.dp)
        )
    }
}
