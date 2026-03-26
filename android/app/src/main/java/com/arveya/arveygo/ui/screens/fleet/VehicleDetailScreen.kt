package com.arveya.arveygo.ui.screens.fleet

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.*
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.arveya.arveygo.models.*
import com.arveya.arveygo.services.WSEvent
import com.arveya.arveygo.services.WebSocketManager
import com.arveya.arveygo.ui.components.StatusBadge
import com.arveya.arveygo.ui.theme.AppColors
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView

// Tab enum matching iOS
private enum class DetailTab(val label: String) {
    OVERVIEW("Genel"),
    MAINTENANCE("Bakım"),
    COSTS("Masraf"),
    EVENTS("Olaylar")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VehicleDetailScreen(
    vehicle: Vehicle,
    onBack: () -> Unit,
    onNavigateToRouteHistory: ((Vehicle) -> Unit)? = null,
    onNavigateToAlarms: (() -> Unit)? = null
) {
    var selectedTab by remember { mutableStateOf(DetailTab.OVERVIEW) }
    val context = LocalContext.current
    var currentVehicle by remember { mutableStateOf(vehicle) }
    var showMotorcycleSettings by remember { mutableStateOf(false) }

    // If motorcycle settings is showing, show the full-screen settings page
    if (showMotorcycleSettings) {
        MotorcycleSettingsScreen(
            vehicle = currentVehicle,
            onBack = { showMotorcycleSettings = false }
        )
        return
    }

    LaunchedEffect(Unit) {
        Configuration.getInstance().userAgentValue = context.packageName
    }

    // Subscribe to real-time WebSocket updates
    LaunchedEffect(vehicle.id, vehicle.imei) {
        WebSocketManager.vehicleList.collect { vehicles ->
            val updated = vehicles.firstOrNull { it.id == vehicle.id || (it.imei.isNotEmpty() && it.imei == vehicle.imei) }
            if (updated != null) { currentVehicle = updated }
        }
    }
    LaunchedEffect(vehicle.id, vehicle.imei) {
        WebSocketManager.events.collect { event ->
            if (event is WSEvent.Update) {
                val u = event.vehicle
                if (u.id == vehicle.id || (u.imei.isNotEmpty() && u.imei == vehicle.imei)) {
                    currentVehicle = u
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.ChevronLeft, null, tint = AppColors.Navy, modifier = Modifier.size(18.dp))
                            Text("Geri", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                        }
                    }
                },
                title = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                        Text(currentVehicle.plate, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        Text("Araç Detayı", fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                },
                actions = {
                    if (currentVehicle.isMotorcycle) {
                        IconButton(onClick = { showMotorcycleSettings = true }) {
                            Icon(Icons.Default.Settings, null, tint = AppColors.Online, modifier = Modifier.size(22.dp))
                        }
                    }
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
            // Map Header
            MapHeader(currentVehicle, context)

            // Vehicle Identity Card (overlapping map)
            VehicleIdentityCard(currentVehicle)

            // Tab Selector
            TabSelector(selectedTab) { selectedTab = it }

            // Tab Content
            Column(
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .padding(top = 16.dp, bottom = 30.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                when (selectedTab) {
                    DetailTab.OVERVIEW -> OverviewTab(currentVehicle, context, onBack, onNavigateToRouteHistory, onNavigateToAlarms)
                    DetailTab.MAINTENANCE -> MaintenanceTab(currentVehicle)
                    DetailTab.COSTS -> CostsTab(currentVehicle)
                    DetailTab.EVENTS -> EventsTab(currentVehicle)
                }
            }
        }
    }
}

// MARK: - Map Header
@Composable
private fun MapHeader(vehicle: Vehicle, context: Context) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
    ) {
        AndroidView(
            factory = { ctx ->
                MapView(ctx).apply {
                    setTileSource(TileSourceFactory.MAPNIK)
                    setMultiTouchControls(false)
                    controller.setZoom(15.0)
                    controller.setCenter(GeoPoint(vehicle.lat, vehicle.lng))
                    zoomController.setVisibility(
                        org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER
                    )
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // Status overlay at bottom-right
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(12.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .background(Color.White.copy(alpha = 0.9f), RoundedCornerShape(20.dp))
                    .padding(horizontal = 10.dp, vertical = 5.dp)
            ) {
                Box(Modifier.size(7.dp).clip(CircleShape).background(vehicle.status.color))
                Spacer(Modifier.width(5.dp))
                Text(
                    if (vehicle.status == VehicleStatus.ONLINE) "Canlı" else vehicle.status.label,
                    fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = vehicle.status.color
                )
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .background(Color.White.copy(alpha = 0.9f), RoundedCornerShape(20.dp))
                    .padding(horizontal = 10.dp, vertical = 5.dp)
            ) {
                Icon(
                    Icons.Default.VpnKey, null,
                    tint = if (vehicle.kontakOn) AppColors.Online else AppColors.TextMuted,
                    modifier = Modifier.size(10.dp)
                )
                Spacer(Modifier.width(5.dp))
                Text(
                    if (vehicle.kontakOn) "Kontak Açık" else "Kontak Kapalı",
                    fontSize = 10.sp, fontWeight = FontWeight.Medium,
                    color = if (vehicle.kontakOn) AppColors.Online else AppColors.TextMuted
                )
            }
        }
    }
}

// MARK: - Vehicle Identity Card
@Composable
private fun VehicleIdentityCard(vehicle: Vehicle) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .offset(y = (-30).dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.Surface)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(16.dp)
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(56.dp)
                    .background(vehicle.status.color.copy(alpha = 0.1f), RoundedCornerShape(14.dp))
            ) {
                Icon(
                    if (vehicle.isMotorcycle) Icons.Default.TwoWheeler else Icons.Default.DirectionsCar,
                    null, tint = vehicle.status.color, modifier = Modifier.size(22.dp)
                )
            }
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(vehicle.plate, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                    Spacer(Modifier.width(8.dp))
                    StatusBadge(vehicle.status)
                }
                Text(vehicle.model, fontSize = 13.sp, color = AppColors.TextMuted)
                Spacer(Modifier.height(4.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    VehicleTag(vehicle.group, Icons.Default.Folder, Color.Blue)
                    VehicleTag(
                        vehicle.vehicleType,
                        if (vehicle.isMotorcycle) Icons.Default.TwoWheeler else Icons.Default.DirectionsCar,
                        Color(0xFF9C27B0)
                    )
                }
            }


        }

        HorizontalDivider(color = AppColors.BorderSoft)

        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
            QuickStatItem("Toplam Km", vehicle.formattedTotalKm, Icons.Default.Speed, AppColors.Navy, Modifier.weight(1f))
            Box(Modifier.width(1.dp).height(40.dp).background(AppColors.BorderSoft))
            QuickStatItem("Bugün", vehicle.formattedTodayKm, Icons.Default.Route, AppColors.Indigo, Modifier.weight(1f))
            Box(Modifier.width(1.dp).height(40.dp).background(AppColors.BorderSoft))
            QuickStatItem("Sürücü", vehicle.driver.split(" ").firstOrNull() ?: "—", Icons.Default.Person, AppColors.Online, Modifier.weight(1f))
            Box(Modifier.width(1.dp).height(40.dp).background(AppColors.BorderSoft))
            QuickStatItem("Konum", vehicle.city, Icons.Default.LocationOn, Color(0xFFFF9800), Modifier.weight(1f))
        }
    }
}

@Composable
private fun VehicleTag(text: String, icon: ImageVector, color: Color) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .background(color.copy(alpha = 0.08f), RoundedCornerShape(20.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Icon(icon, null, tint = color, modifier = Modifier.size(8.dp))
        Spacer(Modifier.width(4.dp))
        Text(text, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = color)
    }
}

@Composable
private fun QuickStatItem(label: String, value: String, icon: ImageVector, color: Color, modifier: Modifier = Modifier) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = modifier) {
        Icon(icon, null, tint = color, modifier = Modifier.size(12.dp))
        Spacer(Modifier.height(4.dp))
        Text(value, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(label, fontSize = 9.sp, color = AppColors.TextMuted)
    }
}

// MARK: - Tab Selector
@Composable
private fun TabSelector(selectedTab: DetailTab, onSelect: (DetailTab) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .offset(y = (-14).dp)
            .background(AppColors.Surface, RoundedCornerShape(12.dp))
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            .padding(top = 8.dp)
    ) {
        DetailTab.entries.forEach { tab ->
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .weight(1f)
                    .clickable { onSelect(tab) }
            ) {
                Text(
                    tab.label,
                    fontSize = 13.sp,
                    fontWeight = if (selectedTab == tab) FontWeight.SemiBold else FontWeight.Medium,
                    color = if (selectedTab == tab) AppColors.Navy else AppColors.TextMuted
                )
                Spacer(Modifier.height(6.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth(0.7f)
                        .height(2.5.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(if (selectedTab == tab) AppColors.Indigo else Color.Transparent)
                )
            }
        }
    }
}

// MARK: - Overview Tab
@Composable
private fun OverviewTab(
    vehicle: Vehicle,
    context: Context,
    onBack: () -> Unit,
    onNavigateToRouteHistory: ((Vehicle) -> Unit)?,
    onNavigateToAlarms: (() -> Unit)?
) {
    val infoItems = listOf(
        Triple(Icons.Default.Folder, "GRUP", vehicle.group),
        Triple(Icons.Default.Speed, "KİLOMETRE", vehicle.formattedTotalKm + " km"),
        Triple(Icons.Default.Speed, "HIZ", vehicle.formattedSpeed),
        Triple(Icons.Default.LocationOn, "KONUM", vehicle.city),
        Triple(Icons.Default.DirectionsCar, "ARAÇ TİPİ", vehicle.vehicleType),
    )

    // Device Time card (matching vehicles list style)
    if (vehicle.deviceTime != null) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Surface, RoundedCornerShape(12.dp))
                .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
                .padding(horizontal = 16.dp, vertical = 12.dp)
        ) {
            Icon(Icons.Default.Schedule, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
            Spacer(Modifier.width(8.dp))
            Text("Son Bilgi Tarihi", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Spacer(Modifier.weight(1f))
            Text(
                "⏱ ${vehicle.formattedDeviceTime}",
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                color = AppColors.TextMuted,
                modifier = Modifier
                    .background(AppColors.Bg, RoundedCornerShape(8.dp))
                    .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(8.dp))
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            )
        }
    }

    SectionCard(title = "ARAÇ BİLGİLERİ", icon = Icons.Default.DirectionsCar) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            for (i in infoItems.indices step 2) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    InfoCell(infoItems[i].first, infoItems[i].second, infoItems[i].third, Modifier.weight(1f))
                    if (i + 1 < infoItems.size) {
                        InfoCell(infoItems[i + 1].first, infoItems[i + 1].second, infoItems[i + 1].third, Modifier.weight(1f))
                    } else {
                        Spacer(Modifier.weight(1f))
                    }
                }
            }
        }
    }

    // Ignition / Kontak Details
    SectionCard(title = "KONTAK BİLGİLERİ", icon = Icons.Default.VpnKey) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                InfoCell(
                    Icons.Default.VpnKey,
                    "KONTAK DURUMU",
                    vehicle.kontakLabel,
                    Modifier.weight(1f),
                    valueColor = if (vehicle.kontakOn) AppColors.Online else AppColors.Offline
                )
                InfoCell(Icons.Default.WbSunny, "İLK KONTAK (BUGÜN)", vehicle.formattedFirstIgnitionToday, Modifier.weight(1f))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                InfoCell(Icons.Default.VpnKey, "SON KONTAK AÇMA", vehicle.formattedLastIgnitionOn, Modifier.weight(1f))
                InfoCell(Icons.Default.VpnKey, "SON KONTAK KAPAMA", vehicle.formattedLastIgnitionOff, Modifier.weight(1f))
            }
        }
    }

    // Temperature & Sensor section
    if (vehicle.temperatureC != null || vehicle.humidityPct != null) {
        SectionCard(title = "SICAKLIK & SENSÖR", icon = Icons.Default.Thermostat) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    InfoCell(
                        Icons.Default.Thermostat,
                        "SICAKLIK",
                        vehicle.temperatureC?.let { String.format("%.1f°C", it) } ?: "—",
                        Modifier.weight(1f)
                    )
                    InfoCell(
                        Icons.Default.WaterDrop,
                        "NEM",
                        vehicle.humidityPct?.let { "%${it.toInt()}" } ?: "—",
                        Modifier.weight(1f)
                    )
                }
            }
        }
    }

    var showDriverAssign by remember { mutableStateOf(false) }

    SectionCard(title = "SÜRÜCÜ BİLGİLERİ", icon = Icons.Default.Person) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().background(AppColors.Bg, RoundedCornerShape(10.dp)).padding(14.dp)
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier.size(50.dp).clip(CircleShape).background(AppColors.Indigo.copy(alpha = 0.1f))
            ) {
                Text(
                    if (vehicle.driver.isEmpty()) "?" else vehicle.driver.take(1),
                    fontSize = 20.sp, fontWeight = FontWeight.Bold, color = AppColors.Indigo
                )
            }
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    if (vehicle.driver.isEmpty()) "Sürücü Atanmamış" else vehicle.driver,
                    fontSize = 15.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy
                )
                Text("Atanmış Sürücü", fontSize = 11.sp, color = AppColors.TextMuted)
            }
            TextButton(onClick = { showDriverAssign = true }) {
                Icon(Icons.Default.Edit, null, modifier = Modifier.size(14.dp), tint = AppColors.Indigo)
                Spacer(Modifier.width(4.dp))
                Text("Değiştir", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.Indigo)
            }
        }
    }

    if (showDriverAssign) {
        VehicleDriverAssignDialog(
            vehicleId = vehicle.id.toIntOrNull() ?: 0,
            currentDriverName = vehicle.driver,
            onDismiss = { showDriverAssign = false },
            onAssigned = { showDriverAssign = false }
        )
    }

    SectionCard(title = "HIZLI İŞLEMLER", icon = Icons.Default.FlashOn) {
        data class QuickAction(val icon: ImageVector, val label: String, val color: Color, val onClick: () -> Unit)
        val actions = listOf(
            QuickAction(Icons.Default.LocationOn, "Konuma\nGit", Color.Blue) {
                openMapsDirections(context, vehicle.lat, vehicle.lng, vehicle.plate)
            },
            QuickAction(Icons.Default.History, "Rota\nGeçmişi", AppColors.Indigo) {
                onBack()
                onNavigateToRouteHistory?.invoke(vehicle)
            },
            QuickAction(Icons.Default.Notifications, "Alarm\nKur", Color(0xFFFF9800)) {
                onBack()
                onNavigateToAlarms?.invoke()
            },
            QuickAction(Icons.Default.Lock, "Blokaj\nGönder", Color.Red) {},
            QuickAction(Icons.Default.Build, "Bakım\nEkle", AppColors.Online) {},
            QuickAction(Icons.Default.Description, "Belge\nEkle", Color(0xFF9C27B0)) {},
            QuickAction(Icons.Default.LocalGasStation, "Yakıt\nKayıt", Color(0xFF00BCD4)) {},
            QuickAction(Icons.Default.Share, "Paylaş", AppColors.TextMuted) {
                shareVehicleLocation(context, vehicle)
            },
        )
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            for (i in actions.indices step 4) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (j in 0 until 4) {
                        val idx = i + j
                        if (idx < actions.size) {
                            ActionButton(actions[idx].icon, actions[idx].label, actions[idx].color, Modifier.weight(1f), actions[idx].onClick)
                        } else {
                            Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Maintenance Tab
@Composable
private fun MaintenanceTab(vehicle: Vehicle) {
    SectionCard(title = "BAKIM TAKVİMİ", icon = Icons.Default.Build) {
        Column {
            MaintenanceRow(Icons.Default.Build, "Periyodik Bakım", vehicle.nextService, "Her 10.000 km", MaintenanceStatus.UPCOMING)
            HorizontalDivider(modifier = Modifier.padding(start = 44.dp), color = AppColors.BorderSoft)
            MaintenanceRow(Icons.Default.Circle, "Lastik Değişimi", "15.06.2026", "Her 40.000 km", MaintenanceStatus.NORMAL)
            HorizontalDivider(modifier = Modifier.padding(start = 44.dp), color = AppColors.BorderSoft)
            MaintenanceRow(Icons.Default.WaterDrop, "Yağ Değişimi", vehicle.lastService, "Her 15.000 km", MaintenanceStatus.COMPLETED)
            HorizontalDivider(modifier = Modifier.padding(start = 44.dp), color = AppColors.BorderSoft)
            MaintenanceRow(Icons.Default.FlashOn, "Akü Kontrolü", "20.07.2026", "Yıllık", MaintenanceStatus.NORMAL)
        }
    }

    SectionCard(title = "BELGELER", icon = Icons.Default.Description) {
        Column {
            DocumentRow("Muayene", vehicle.muayeneDate, 85, DocStatus.NORMAL)
            HorizontalDivider(modifier = Modifier.padding(start = 14.dp), color = AppColors.BorderSoft)
            DocumentRow("Kasko", vehicle.insuranceDate, 120, DocStatus.NORMAL)
            HorizontalDivider(modifier = Modifier.padding(start = 14.dp), color = AppColors.BorderSoft)
            DocumentRow("Trafik Sigortası", "10.05.2026", 48, DocStatus.WARNING)
            HorizontalDivider(modifier = Modifier.padding(start = 14.dp), color = AppColors.BorderSoft)
            DocumentRow("K Belgesi", "01.04.2026", 9, DocStatus.CRITICAL)
        }
    }
}

// MARK: - Costs Tab
@Composable
private fun CostsTab(vehicle: Vehicle) {
    SectionCard(title = "MASRAF ÖZETİ (2026)", icon = Icons.Default.BarChart) {
        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
            CostSummaryItem("Yakıt", "₺14.200", Color(0xFFFF9800), 45, Modifier.weight(1f))
            CostSummaryItem("Bakım", "₺8.500", Color.Blue, 27, Modifier.weight(1f))
            CostSummaryItem("Sigorta", "₺5.800", Color(0xFF9C27B0), 18, Modifier.weight(1f))
            CostSummaryItem("Diğer", "₺3.100", AppColors.TextMuted, 10, Modifier.weight(1f))
        }

        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().background(AppColors.Navy.copy(alpha = 0.04f), RoundedCornerShape(10.dp)).padding(14.dp)
        ) {
            Text("TOPLAM", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted)
            Text("₺31.600", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
        }
    }

    SectionCard(title = "SON MASRAFLAR", icon = Icons.Default.List) {
        Column {
            vehicle.recentCosts.forEachIndexed { index, cost ->
                CostRow(cost)
                if (index < vehicle.recentCosts.size - 1) {
                    HorizontalDivider(modifier = Modifier.padding(start = 62.dp), color = AppColors.BorderSoft)
                }
            }
        }
    }
}

// MARK: - Events Tab
@Composable
private fun EventsTab(vehicle: Vehicle) {
    SectionCard(title = "SON OLAYLAR", icon = Icons.Default.Schedule) {
        Column {
            EventRow(Icons.Default.LocationOn, "Geofence Çıkışı", "İstanbul → Ankara yolu", "Bugün 14:32", AlertSeverity.AMBER)
            HorizontalDivider(modifier = Modifier.padding(start = 48.dp), color = AppColors.BorderSoft)
            EventRow(Icons.Default.Speed, "Hız İhlali", "132 km/h (Limit: 110 km/h)", "Bugün 11:45", AlertSeverity.RED)
            HorizontalDivider(modifier = Modifier.padding(start = 48.dp), color = AppColors.BorderSoft)
            EventRow(Icons.Default.VpnKey, "Kontak Açıldı", vehicle.city, "Bugün 08:15", AlertSeverity.GREEN)
            HorizontalDivider(modifier = Modifier.padding(start = 48.dp), color = AppColors.BorderSoft)
            EventRow(Icons.Default.VpnKey, "Kontak Kapatıldı", vehicle.city, "Dün 19:30", AlertSeverity.BLUE)
            HorizontalDivider(modifier = Modifier.padding(start = 48.dp), color = AppColors.BorderSoft)
            EventRow(Icons.Default.PauseCircle, "5 dk Rölanti", "Ankara - Çankaya", "Dün 15:12", AlertSeverity.AMBER)
            HorizontalDivider(modifier = Modifier.padding(start = 48.dp), color = AppColors.BorderSoft)
            EventRow(Icons.Default.LocalGasStation, "Yakıt Doldurma", "45 Lt Dizel", "Dün 09:40", AlertSeverity.BLUE)
            HorizontalDivider(modifier = Modifier.padding(start = 48.dp), color = AppColors.BorderSoft)
            EventRow(Icons.Default.Warning, "Ani Fren", "E-5 Karayolu", "22.03.2026 16:20", AlertSeverity.RED)
        }
    }
}

// ============================================================================
// MARK: - Open Maps Directions Helper
// ============================================================================

private fun openMapsDirections(context: Context, lat: Double, lng: Double, label: String) {
    // Try Google Maps first, fall back to generic geo intent
    try {
        val gmmIntentUri = Uri.parse("google.navigation:q=$lat,$lng&mode=d")
        val mapIntent = Intent(Intent.ACTION_VIEW, gmmIntentUri).apply {
            setPackage("com.google.android.apps.maps")
        }
        if (mapIntent.resolveActivity(context.packageManager) != null) {
            context.startActivity(mapIntent)
        } else {
            // Fallback to generic geo intent
            val genericUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng($label)")
            context.startActivity(Intent(Intent.ACTION_VIEW, genericUri))
        }
    } catch (e: Exception) {
        // Ultimate fallback: open in browser
        val browserUri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng")
        context.startActivity(Intent(Intent.ACTION_VIEW, browserUri))
    }
}

// ============================================================================
// MARK: - Share Vehicle Location Helper
// ============================================================================

private fun shareVehicleLocation(context: Context, vehicle: Vehicle) {
    val mapsUrl = "https://www.google.com/maps?q=${vehicle.lat},${vehicle.lng}"
    val shareText = "${vehicle.plate} konumu:\n${vehicle.city}\n\n$mapsUrl"
    val sendIntent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, shareText)
        putExtra(Intent.EXTRA_SUBJECT, "${vehicle.plate} Araç Konumu")
    }
    context.startActivity(Intent.createChooser(sendIntent, "Konumu Paylaş"))
}

// ============================================================================
// MARK: - Reusable Components
// ============================================================================

@Composable
private fun SectionCard(title: String, icon: ImageVector, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface, RoundedCornerShape(14.dp))
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(14.dp))
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(11.dp))
            Spacer(Modifier.width(8.dp))
            Text(title, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted, letterSpacing = 0.5.sp)
            Spacer(Modifier.weight(1f))
        }
        Spacer(Modifier.height(12.dp))
        content()
    }
}

@Composable
private fun InfoCell(icon: ImageVector, label: String, value: String, modifier: Modifier = Modifier, valueColor: Color? = null) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier.background(AppColors.Bg, RoundedCornerShape(10.dp)).padding(10.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(26.dp).background(AppColors.Indigo.copy(alpha = 0.08f), RoundedCornerShape(7.dp))
        ) {
            Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(12.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f, fill = false)) {
            Text(label, fontSize = 8.sp, fontWeight = FontWeight.Bold, color = AppColors.TextFaint, letterSpacing = 0.3.sp)
            Text(value, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = valueColor ?: AppColors.Navy, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun ActionButton(icon: ImageVector, label: String, color: Color, modifier: Modifier = Modifier, onClick: () -> Unit = {}) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier.clickable { onClick() }
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(44.dp).background(color.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(17.dp))
        }
        Spacer(Modifier.height(6.dp))
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.Medium, color = AppColors.TextMuted, textAlign = TextAlign.Center, maxLines = 2, lineHeight = 11.sp)
    }
}

private enum class MaintenanceStatus(val label: String, val color: Color) {
    COMPLETED("Tamamlandı", Color(0xFF22C55E)),
    UPCOMING("Yaklaşıyor", Color(0xFFFF9800)),
    NORMAL("Planlandı", Color.Blue),
    OVERDUE("Gecikmiş", Color.Red)
}

@Composable
private fun MaintenanceRow(icon: ImageVector, title: String, date: String, km: String, status: MaintenanceStatus) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp, horizontal = 14.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(36.dp).clip(CircleShape).background(status.color.copy(alpha = 0.1f))
        ) {
            Icon(icon, null, tint = status.color, modifier = Modifier.size(14.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Row {
                Text(date, fontSize = 11.sp, color = AppColors.TextMuted)
                Text(" • ", fontSize = 8.sp, color = AppColors.TextFaint)
                Text(km, fontSize = 11.sp, color = AppColors.TextMuted)
            }
        }
        Text(
            status.label, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = status.color,
            modifier = Modifier.background(status.color.copy(alpha = 0.1f), RoundedCornerShape(20.dp)).padding(horizontal = 8.dp, vertical = 4.dp)
        )
    }
}

private enum class DocStatus(val color: Color) {
    NORMAL(Color(0xFF22C55E)),
    WARNING(Color(0xFFFF9800)),
    CRITICAL(Color.Red)
}

@Composable
private fun DocumentRow(title: String, date: String, daysLeft: Int, status: DocStatus) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp, horizontal = 14.dp)
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Text("Bitiş: $date", fontSize = 11.sp, color = AppColors.TextMuted)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("$daysLeft gün", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = status.color)
            Text("kalan", fontSize = 9.sp, color = AppColors.TextMuted)
        }
        Spacer(Modifier.width(8.dp))
        Box(Modifier.size(8.dp).clip(CircleShape).background(status.color))
    }
}

@Composable
private fun CostSummaryItem(label: String, amount: String, color: Color, percent: Int, modifier: Modifier = Modifier) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = modifier) {
        Box(
            contentAlignment = Alignment.BottomCenter,
            modifier = Modifier.width(32.dp).height(60.dp).background(color.copy(alpha = 0.15f), RoundedCornerShape(4.dp))
        ) {
            Box(modifier = Modifier.fillMaxWidth().height((percent / 100f * 60).dp).background(color, RoundedCornerShape(4.dp)))
        }
        Spacer(Modifier.height(6.dp))
        Text(amount, fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
        Text(label, fontSize = 9.sp, color = AppColors.TextMuted)
    }
}

@Composable
private fun CostRow(cost: VehicleCost) {
    val color = when (cost.category) {
        "Yakıt" -> Color(0xFFFF9800)
        "Bakım" -> Color.Blue
        "Sigorta" -> Color(0xFF9C27B0)
        else -> AppColors.TextMuted
    }
    val icon = when (cost.category) {
        "Yakıt" -> Icons.Default.LocalGasStation
        "Bakım" -> Icons.Default.Build
        "Sigorta" -> Icons.Default.Shield
        else -> Icons.Default.MoreHoriz
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp, horizontal = 14.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(36.dp).background(color.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(14.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(cost.category, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Text(cost.date, fontSize = 11.sp, color = AppColors.TextMuted)
        }
        Text(cost.amount, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
    }
}

@Composable
private fun EventRow(icon: ImageVector, title: String, subtitle: String, time: String, severity: AlertSeverity) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp, horizontal = 14.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(36.dp).background(severity.color.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
        ) {
            Icon(icon, null, tint = severity.color, modifier = Modifier.size(14.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Text(subtitle, fontSize = 11.sp, color = AppColors.TextMuted)
        }
        Text(time, fontSize = 10.sp, color = AppColors.TextFaint, textAlign = TextAlign.End)
    }
}

// MARK: - Motorcycle Settings Screen (Full Page)
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MotorcycleSettingsScreen(vehicle: Vehicle, onBack: () -> Unit) {
    var kontakOnNotification by remember { mutableStateOf(true) }
    var kontakOffNotification by remember { mutableStateOf(true) }
    var batteryRemovedNotification by remember { mutableStateOf(true) }
    var batteryInstalledNotification by remember { mutableStateOf(true) }
    var motionDetectedNotification by remember { mutableStateOf(true) }
    var motionDetectedPhoneCall by remember { mutableStateOf(false) }
    var phoneNumber by remember { mutableStateOf("") }
    var sleepDelaySeconds by remember { mutableStateOf("30") }
    var wakeIntervalHours by remember { mutableStateOf("6") }
    var alarmEnabled by remember { mutableStateOf(false) }
    var alarmDurationSeconds by remember { mutableFloatStateOf(30f) }
    var showKontakAlert by remember { mutableStateOf(false) }

    // Kontak alert dialog
    if (showKontakAlert) {
        AlertDialog(
            onDismissRequest = { showKontakAlert = false },
            confirmButton = {
                TextButton(onClick = { showKontakAlert = false }) {
                    Text("Tamam", fontWeight = FontWeight.Bold, color = AppColors.Online)
                }
            },
            icon = {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(48.dp)
                        .background(Color(0xFFFF9800).copy(alpha = 0.1f), CircleShape)
                ) {
                    Icon(Icons.Default.Warning, null, tint = Color(0xFFFF9800), modifier = Modifier.size(24.dp))
                }
            },
            title = {
                Text("Kontak Kapalı", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = AppColors.Navy)
            },
            text = {
                Text("Ayarları kaydetmek için aracın kontağının açık olması gereklidir.", fontSize = 14.sp, color = AppColors.TextMuted)
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.ChevronLeft, null, tint = AppColors.Navy, modifier = Modifier.size(18.dp))
                            Text("Geri", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                        }
                    }
                },
                title = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                        Text("Motosiklet Ayarları", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        Text("${vehicle.plate} · ${vehicle.model}", fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                },
                actions = { Spacer(Modifier.width(48.dp)) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.White)
            )
        },
        bottomBar = {
            Surface(shadowElevation = 8.dp) {
                Button(
                    onClick = {
                        if (!vehicle.ignition) {
                            showKontakAlert = true
                        } else {
                            // TODO: Save to backend
                            onBack()
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                        .height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.Online),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.Check, null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Ayarları Kaydet", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(AppColors.Bg)
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header icon
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .size(64.dp)
                    .background(AppColors.Online.copy(alpha = 0.1f), CircleShape)
            ) {
                Icon(Icons.Default.TwoWheeler, null, tint = AppColors.Online, modifier = Modifier.size(32.dp))
            }

            // Section: Kontak
            SettingsSection("Kontak Bildirimleri", Icons.Default.Key) {
                SettingsToggle("Kontak Açılma Bildirimi", "Kontak açıldığında bildirim al", kontakOnNotification) { kontakOnNotification = it }
                SettingsToggle("Kontak Kapanma Bildirimi", "Kontak kapandığında bildirim al", kontakOffNotification) { kontakOffNotification = it }
            }

            // Section: Akü
            SettingsSection("Akü Bildirimleri", Icons.Default.BatteryChargingFull) {
                SettingsToggle("Aküden Söküldü Bildirimi", "Cihaz aküden sökülünce bildirim al", batteryRemovedNotification) { batteryRemovedNotification = it }
                SettingsToggle("Aküye Takıldı Bildirimi", "Cihaz aküye takılınca bildirim al", batteryInstalledNotification) { batteryInstalledNotification = it }
            }

            // Section: Hareket
            SettingsSection("Hareket Algılama", Icons.Default.DirectionsWalk) {
                SettingsToggle("Hareket Algılandı Bildirimi", "Araç hareket edince bildirim al", motionDetectedNotification) { motionDetectedNotification = it }
                SettingsToggle("Telefon Araması", "Hareket algılanınca telefon ile ara", motionDetectedPhoneCall) { motionDetectedPhoneCall = it }

                if (motionDetectedPhoneCall) {
                    OutlinedTextField(
                        value = phoneNumber,
                        onValueChange = { phoneNumber = it },
                        label = { Text("Telefon Numarası") },
                        leadingIcon = { Icon(Icons.Default.Phone, null, tint = AppColors.Online) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().padding(start = 8.dp, top = 4.dp)
                    )
                }
            }

            // Section: Alarm
            SettingsSection("Alarm Ayarları", Icons.Default.Notifications) {
                SettingsToggle("Alarm Kur", "Uzaktan alarm çalıştır", alarmEnabled) { alarmEnabled = it }

                if (alarmEnabled) {
                    Column(modifier = Modifier.padding(start = 8.dp, top = 4.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("Alarm Süresi", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                            Spacer(Modifier.weight(1f))
                            Text("${alarmDurationSeconds.toInt()} saniye", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = AppColors.Online)
                        }
                        Slider(
                            value = alarmDurationSeconds,
                            onValueChange = { alarmDurationSeconds = it },
                            valueRange = 10f..60f,
                            steps = 4,
                            colors = SliderDefaults.colors(
                                thumbColor = AppColors.Online,
                                activeTrackColor = AppColors.Online
                            ),
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(modifier = Modifier.fillMaxWidth()) {
                            Text("10 sn", fontSize = 10.sp, color = AppColors.TextMuted)
                            Spacer(Modifier.weight(1f))
                            Text("60 sn", fontSize = 10.sp, color = AppColors.TextMuted)
                        }
                    }
                }
            }

            // Section: Uyku
            SettingsSection("Cihaz Uyku Ayarları", Icons.Default.Bedtime) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Uyku Süresi", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                        Text("Kontak kapandıktan sonra", fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                    OutlinedTextField(
                        value = sleepDelaySeconds,
                        onValueChange = { sleepDelaySeconds = it.filter { c -> c.isDigit() } },
                        suffix = { Text("sn", fontSize = 12.sp) },
                        singleLine = true,
                        modifier = Modifier.width(80.dp)
                    )
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Uyanma Periyodu", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                        Text("Kaç saatte bir veri atsın", fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                    OutlinedTextField(
                        value = wakeIntervalHours,
                        onValueChange = { wakeIntervalHours = it.filter { c -> c.isDigit() } },
                        suffix = { Text("saat", fontSize = 12.sp) },
                        singleLine = true,
                        modifier = Modifier.width(80.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun SettingsSection(title: String, icon: ImageVector, content: @Composable ColumnScope.() -> Unit) {
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(bottom = 8.dp)
            ) {
                Icon(icon, null, tint = AppColors.Online, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(title, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
            }
            content()
        }
    }
}

@Composable
private fun SettingsToggle(title: String, subtitle: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp)
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
            Text(subtitle, fontSize = 10.sp, color = AppColors.TextMuted)
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(checkedTrackColor = AppColors.Online)
        )
    }
}
