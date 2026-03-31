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
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.services.WSEvent
import com.arveya.arveygo.services.WebSocketManager
import com.arveya.arveygo.ui.components.StatusBadge
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.launch
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker

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
    onNavigateToAlarms: ((String) -> Unit)? = null,
    onNavigateToAddAlarm: ((String) -> Unit)? = null
) {
    var selectedTab by remember { mutableStateOf(DetailTab.OVERVIEW) }
    val context = LocalContext.current
    var currentVehicle by remember { mutableStateOf(vehicle) }
    var showMotorcycleSettings by remember { mutableStateOf(false) }
    var driverName by remember { mutableStateOf("") }
    var driverPhone by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    fun enrichVehicleFromDetail(detail: org.json.JSONObject) {
        val todayKmVal = detail.optDouble("todayKm", 0.0)
        val todayDistanceM = detail.optDouble("todayDistanceM", 0.0)
        val dailyKmApi = detail.optDouble("dailyKm", detail.optDouble("daily_km", 0.0))
        val dailyKmVal = if (dailyKmApi > 0) dailyKmApi else if (todayKmVal > 0) todayKmVal else if (todayDistanceM > 0) todayDistanceM / 1000.0 else 0.0
        val groupNameVal = detail.optString("groupName", "")
        val vehicleBrandVal = detail.optString("vehicleBrand", "")
        val vehicleModelVal = detail.optString("vehicleModel", "")
        val addressVal = detail.optString("address", "")
        val cityVal = detail.optString("city", "")
        val fuelTypeVal = detail.optString("fuelType", "")
        val dailyFuelLitersVal = detail.optDouble("dailyFuelLiters", 0.0)
        val dailyFuelPer100kmVal = detail.optDouble("dailyFuelPer100km", 0.0)
        val fuelPer100kmVal = detail.optDouble("fuelPer100km", 0.0)
        val odometerVal = detail.optDouble("odometer", 0.0)
        val kmVal = detail.optDouble("km", 0.0)
        val batteryVal = when {
            detail.has("battery") -> detail.optDouble("battery", Double.NaN)
            detail.has("battery_voltage") -> detail.optDouble("battery_voltage", Double.NaN)
            else -> Double.NaN
        }
        val externalVoltageVal = when {
            detail.has("externalVoltage") -> detail.optDouble("externalVoltage", Double.NaN)
            detail.has("external_voltage") -> detail.optDouble("external_voltage", Double.NaN)
            else -> Double.NaN
        }
        val deviceBatteryVal = when {
            detail.has("deviceBatteryLevelPct") -> detail.optDouble("deviceBatteryLevelPct", Double.NaN)
            detail.has("battery_level_pct") -> detail.optDouble("battery_level_pct", Double.NaN)
            detail.has("deviceBattery") -> detail.optDouble("deviceBattery", Double.NaN)
            detail.has("device_battery") -> detail.optDouble("device_battery", Double.NaN)
            else -> {
                // Also check inside power object
                val powerObj = if (detail.has("power") && !detail.isNull("power")) detail.optJSONObject("power") else null
                if (powerObj != null && powerObj.has("device_battery_level_pct")) powerObj.optDouble("device_battery_level_pct", Double.NaN)
                else Double.NaN
            }
        }
        // Ignition timestamps from API
        val firstIgnitionToday = detail.optString("first_ignition_on_at_today", "").let { if (it.isNotEmpty() && it != "null") it else null }
        val lastIgnitionOn = detail.optString("last_ignition_on_at", "").let { if (it.isNotEmpty() && it != "null") it else null }
        val lastIgnitionOff = detail.optString("last_ignition_off_at", "").let { if (it.isNotEmpty() && it != "null") it else null }

        currentVehicle = currentVehicle.copy(
            todayKm = dailyKmVal.toInt(),
            dailyKm = dailyKmVal,
            groupName = if (groupNameVal.isNotEmpty() && groupNameVal != "null") groupNameVal else currentVehicle.groupName,
            vehicleBrand = if (vehicleBrandVal.isNotEmpty() && vehicleBrandVal != "null") vehicleBrandVal else currentVehicle.vehicleBrand,
            vehicleModel = if (vehicleModelVal.isNotEmpty() && vehicleModelVal != "null") vehicleModelVal else currentVehicle.vehicleModel,
            address = if (addressVal.isNotEmpty() && addressVal != "null") addressVal else currentVehicle.address,
            city = if (cityVal.isNotEmpty() && cityVal != "null") cityVal else currentVehicle.city,
            fuelType = if (fuelTypeVal.isNotEmpty() && fuelTypeVal != "null") fuelTypeVal else currentVehicle.fuelType,
            dailyFuelLiters = if (dailyFuelLitersVal > 0) dailyFuelLitersVal else currentVehicle.dailyFuelLiters,
            dailyFuelPer100km = if (dailyFuelPer100kmVal > 0) dailyFuelPer100kmVal else currentVehicle.dailyFuelPer100km,
            fuelPer100km = if (fuelPer100kmVal > 0) fuelPer100kmVal else currentVehicle.fuelPer100km,
            totalKm = if (odometerVal > 0) odometerVal.toInt() else if (kmVal > 0) kmVal.toInt() else currentVehicle.totalKm,
            odometer = if (odometerVal > 0) odometerVal else if (kmVal > 0) kmVal else currentVehicle.odometer,
            batteryVoltage = if (!batteryVal.isNaN()) batteryVal else currentVehicle.batteryVoltage,
            externalVoltage = if (!externalVoltageVal.isNaN()) externalVoltageVal else currentVehicle.externalVoltage,
            deviceBattery = if (!deviceBatteryVal.isNaN()) deviceBatteryVal else currentVehicle.deviceBattery,
            firstIgnitionOnAtToday = firstIgnitionToday ?: currentVehicle.firstIgnitionOnAtToday,
            lastIgnitionOnAt = lastIgnitionOn ?: currentVehicle.lastIgnitionOnAt,
            lastIgnitionOffAt = lastIgnitionOff ?: currentVehicle.lastIgnitionOffAt
        )
    }

    fun refreshDriverInfo() {
        val deviceId = currentVehicle.deviceId
        if (deviceId > 0) {
            scope.launch {
                try {
                    val detail = APIService.fetchVehicleDetail(deviceId)
                    val driverObj = detail.optJSONObject("driver")
                    if (driverObj != null) {
                        driverName = driverObj.optString("name", "")
                        driverPhone = driverObj.optString("phone", "")
                    }
                    enrichVehicleFromDetail(detail)
                } catch (_: Exception) {}
            }
        }
    }

    // Fetch driver info and enrich vehicle from API when deviceId becomes available
    LaunchedEffect(currentVehicle.deviceId) {
        // Use enriched driverName from WS manager if available
        if (currentVehicle.driverName.isNotEmpty() && driverName.isEmpty()) {
            driverName = currentVehicle.driverName
        }
        if (currentVehicle.deviceId > 0) {
            try {
                val detail = APIService.fetchVehicleDetail(currentVehicle.deviceId)
                if (driverName.isEmpty()) {
                    val driverObj = detail.optJSONObject("driver")
                    if (driverObj != null) {
                        driverName = driverObj.optString("name", "")
                        driverPhone = driverObj.optString("phone", "")
                    }
                }
                enrichVehicleFromDetail(detail)
            } catch (e: Exception) {
                android.util.Log.e("VehicleDetail", "fetchVehicleDetail error", e)
            }
        }
    }

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
            if (updated != null) {
                // Merge WS update but preserve API-enriched fields
                currentVehicle = currentVehicle.mergeUpdate(updated)
            }
        }
    }
    LaunchedEffect(vehicle.id, vehicle.imei) {
        WebSocketManager.events.collect { event ->
            if (event is WSEvent.Update) {
                val u = event.vehicle
                if (u.id == vehicle.id || (u.imei.isNotEmpty() && u.imei == vehicle.imei)) {
                    currentVehicle = currentVehicle.mergeUpdate(u)
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
                    DetailTab.OVERVIEW -> OverviewTab(currentVehicle, context, onBack, onNavigateToRouteHistory, onNavigateToAlarms, onNavigateToAddAlarm, driverName, onDriverAssigned = {
                        refreshDriverInfo()
                    })
                    DetailTab.MAINTENANCE -> MaintenanceTab(currentVehicle)
                    DetailTab.COSTS -> CostsTab(currentVehicle)
                    DetailTab.EVENTS -> EventsTab(currentVehicle, onNavigateToAlarms)
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
                    // Add vehicle marker
                    val marker = Marker(this)
                    marker.position = GeoPoint(vehicle.lat, vehicle.lng)
                    marker.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    marker.title = vehicle.plate
                    marker.snippet = vehicle.model
                    marker.infoWindow = null
                    // Create colored marker icon
                    val statusColor = when (vehicle.status) {
                        VehicleStatus.IGNITION_ON -> android.graphics.Color.rgb(34, 197, 94)
                        VehicleStatus.IGNITION_OFF -> android.graphics.Color.rgb(239, 68, 68)
                        VehicleStatus.NO_DATA -> android.graphics.Color.rgb(148, 163, 184)
                        VehicleStatus.SLEEPING -> android.graphics.Color.rgb(245, 158, 11)
                    }
                    val density = ctx.resources.displayMetrics.density
                    val pinSize = (36 * density).toInt()
                    val bitmap = android.graphics.Bitmap.createBitmap(pinSize, pinSize, android.graphics.Bitmap.Config.ARGB_8888)
                    val canvas = android.graphics.Canvas(bitmap)
                    val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                        color = statusColor
                    }
                    val borderPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                        color = android.graphics.Color.WHITE
                        style = android.graphics.Paint.Style.STROKE
                        strokeWidth = 3f * density
                    }
                    canvas.drawCircle(pinSize / 2f, pinSize / 2f, pinSize / 2f - 2f * density, paint)
                    canvas.drawCircle(pinSize / 2f, pinSize / 2f, pinSize / 2f - 2f * density, borderPaint)
                    // Draw car icon
                    val iconPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                        color = android.graphics.Color.WHITE
                        textSize = 16f * density
                        textAlign = android.graphics.Paint.Align.CENTER
                    }
                    canvas.drawText("🚗", pinSize / 2f, pinSize / 2f + 6f * density, iconPaint)
                    marker.icon = android.graphics.drawable.BitmapDrawable(ctx.resources, bitmap)
                    overlays.add(marker)
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
                    if (vehicle.livenessStatus.isNotEmpty()) vehicle.livenessLabel
                    else vehicle.status.label,
                    fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = vehicle.status.color
                )
            }
            // Kontak durumu badge kaldırıldı
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
                // name fieldı yorum satırına alındı
                // Text(vehicle.model, fontSize = 13.sp, color = AppColors.TextMuted)
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
            QuickStatItem("Sürücü", run {
                val name = if (vehicle.driverName.isNotEmpty()) vehicle.driverName else vehicle.driver
                if (name.isEmpty()) "—" else name.split(" ").firstOrNull() ?: "—"
            }, Icons.Default.Person, AppColors.Online, Modifier.weight(1f))
            Box(Modifier.width(1.dp).height(40.dp).background(AppColors.BorderSoft))
            QuickStatItem("Konum", vehicle.locationDisplay, Icons.Default.LocationOn, Color(0xFFFF9800), Modifier.weight(1f))
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
    onNavigateToAlarms: ((String) -> Unit)?,
    onNavigateToAddAlarm: ((String) -> Unit)?,
    driverName: String = "",
    onDriverAssigned: (() -> Unit)? = null
) {
    var showEditDialog by remember { mutableStateOf(false) }
    var showBlockageDialog by remember { mutableStateOf(false) }

    fun formatVoltage(value: Double?): String {
        if (value == null) return "—"
        return String.format("%.2f V", value)
    }

    fun formatDeviceBattery(value: Double?): String {
        if (value == null) return "—"
        return if (value <= 100.0) "%${value.toInt()}" else String.format("%.2f V", value)
    }

    val vehicleBatteryDisplay = vehicle.batteryVoltage ?: vehicle.externalVoltage

    // ── Dialogs ──
    if (showEditDialog) {
        VehicleEditDialog(
            vehicle = vehicle,
            onDismiss = { showEditDialog = false },
            onSaved = { showEditDialog = false }
        )
    }
    if (showBlockageDialog) {
        BlockageDialog(
            vehicle = vehicle,
            onDismiss = { showBlockageDialog = false }
        )
    }

    // ── Quick Actions Row (top, prominent) ──
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface, RoundedCornerShape(14.dp))
            .padding(14.dp)
    ) {
        data class QuickAction(val icon: ImageVector, val label: String, val color: Color, val onClick: () -> Unit)
        val actions = listOf(
            QuickAction(Icons.Default.Navigation, "Yol Tarifi", Color(0xFF3B82F6)) {
                openMapsDirections(context, vehicle.lat, vehicle.lng, vehicle.plate)
            },
            QuickAction(Icons.Default.History, "Rota Geçmişi", AppColors.Indigo) {
                onBack()
                onNavigateToRouteHistory?.invoke(vehicle)
            },
            QuickAction(Icons.Default.Edit, "Düzenle", Color(0xFF8B5CF6)) {
                showEditDialog = true
            },
            QuickAction(Icons.Default.Lock, "Blokaj", Color(0xFFEF4444)) {
                showBlockageDialog = true
            },
            QuickAction(Icons.Default.Share, "Paylaş", AppColors.TextMuted) {
                shareVehicleLocation(context, vehicle)
            },
        )
        actions.forEach { action ->
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.weight(1f).clickable { action.onClick() }
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(40.dp)
                        .background(action.color.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
                ) {
                    Icon(action.icon, null, tint = action.color, modifier = Modifier.size(17.dp))
                }
                Spacer(Modifier.height(6.dp))
                Text(action.label, fontSize = 9.sp, fontWeight = FontWeight.Medium, color = AppColors.TextMuted, textAlign = TextAlign.Center, maxLines = 1)
            }
        }
    }

    // ── Vehicle Info ──
    CleanListCard {
        DetailRow(Icons.Default.Speed, "Hız", vehicle.formattedSpeed)
        ListDivider()
        DetailRow(Icons.Default.LocationOn, "Konum", vehicle.locationDisplay)
        if (vehicle.deviceTime != null) {
            ListDivider()
            DetailRow(Icons.Default.Schedule, "Son Güncelleme", vehicle.formattedDeviceTime)
        }
        if (vehicle.lastPacketAt != null) {
            ListDivider()
            DetailRow(Icons.Default.Sync, "Son Paket", vehicle.formattedLastPacketAt)
        }
    }

    // ── Kontak & Güç ──
    CleanListCard {
        DetailRow(
            Icons.Default.VpnKey, "Kontak",
            vehicle.kontakLabel,
            valueColor = if (vehicle.kontakOn) AppColors.Online else AppColors.Offline
        )
        ListDivider()
        DetailRow(Icons.Default.WbSunny, "İlk Kontak (Bugün)", vehicle.formattedFirstIgnitionToday)
        ListDivider()
        DetailRow(Icons.Default.VpnKey, "Son Kontak Açma", vehicle.formattedLastIgnitionOn)
        ListDivider()
        DetailRow(Icons.Default.VpnKey, "Son Kontak Kapama", vehicle.formattedLastIgnitionOff)
        ListDivider()
        
        if (vehicle.deviceBattery != null) {
            ListDivider()
            DetailRow(Icons.Default.PhoneAndroid, "Cihaz Bataryası", formatDeviceBattery(vehicle.deviceBattery))
        }
        if (vehicle.externalVoltage != null) {
            ListDivider()
            DetailRow(Icons.Default.Bolt, "Harici Voltaj", formatVoltage(vehicle.externalVoltage))
        }
    }

    // ── Temperature & Sensors (conditional) ──
    if (vehicle.temperatureC != null || vehicle.humidityPct != null) {
        CleanListCard {
            vehicle.temperatureC?.let { temp ->
                DetailRow(Icons.Default.Thermostat, "Sıcaklık", String.format("%.1f°C", temp))
            }
            if (vehicle.temperatureC != null && vehicle.humidityPct != null) { ListDivider() }
            vehicle.humidityPct?.let { hum ->
                DetailRow(Icons.Default.WaterDrop, "Nem", "%${hum.toInt()}")
            }
        }
    }

    // ── Yakıt & Maliyet ──
    if (vehicle.fuelType.isNotEmpty() || vehicle.dailyFuelPer100km > 0 || vehicle.fuelPer100km > 0) {
        CleanListCard {
            if (vehicle.fuelType.isNotEmpty()) {
                DetailRow(Icons.Default.LocalGasStation, "Yakıt Tipi", vehicle.fuelType)
                ListDivider()
            }
            val rate = if (vehicle.dailyFuelPer100km > 0) vehicle.dailyFuelPer100km else vehicle.fuelPer100km
            if (rate > 0) {
                DetailRow(Icons.Default.Speed, "Tüketim", String.format("%.1f L/100km", rate))
                ListDivider()
            }
            DetailRow(Icons.Default.WaterDrop, "Bugün Tahmini Yakıt", vehicle.formattedDailyFuelLiters)
            ListDivider()
            DetailRow(Icons.Default.Payments, "Bugün Tahmini Maliyet", vehicle.formattedDailyFuelCost)
        }
    }

    // ── Driver ──
    var showDriverAssign by remember { mutableStateOf(false) }
    val displayName = if (driverName.isNotEmpty()) driverName else if (vehicle.driverName.isNotEmpty()) vehicle.driverName else ""

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface, RoundedCornerShape(14.dp))
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier.size(40.dp).clip(CircleShape).background(AppColors.Indigo.copy(alpha = 0.08f))
            ) {
                Text(
                    if (displayName.isEmpty()) "?" else displayName.take(1),
                    fontSize = 17.sp, fontWeight = FontWeight.Bold, color = AppColors.Indigo
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    if (displayName.isEmpty()) "Sürücü Atanmamış" else displayName,
                    fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy
                )
                Text("Sürücü", fontSize = 11.sp, color = AppColors.TextMuted)
            }
            TextButton(onClick = { showDriverAssign = true }) {
                Icon(Icons.Default.Edit, null, modifier = Modifier.size(13.dp), tint = AppColors.Indigo)
                Spacer(Modifier.width(4.dp))
                Text("Değiştir", fontSize = 11.sp, fontWeight = FontWeight.Medium, color = AppColors.Indigo)
            }
        }
    }

    if (showDriverAssign) {
        VehicleDriverAssignDialog(
            vehicleId = vehicle.deviceId,
            currentDriverName = displayName,
            onDismiss = { showDriverAssign = false },
            onAssigned = { showDriverAssign = false; onDriverAssigned?.invoke() }
        )
    }
}

// ── Clean List Card (no section header, just grouped rows) ──
@Composable
private fun CleanListCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface, RoundedCornerShape(14.dp))
            .padding(vertical = 4.dp),
        content = content
    )
}

@Composable
private fun ListDivider() {
    HorizontalDivider(
        color = AppColors.BorderSoft,
        modifier = Modifier.padding(start = 52.dp, end = 16.dp)
    )
}

@Composable
private fun DetailRow(
    icon: ImageVector,
    label: String,
    value: String,
    valueColor: Color? = null
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Icon(
            icon, null,
            tint = AppColors.Indigo.copy(alpha = 0.7f),
            modifier = Modifier.size(16.dp)
        )
        Spacer(Modifier.width(14.dp))
        Text(
            label,
            fontSize = 13.sp,
            fontWeight = FontWeight.Normal,
            color = AppColors.TextMuted,
            modifier = Modifier.weight(1f)
        )
        Text(
            value,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = valueColor ?: AppColors.Navy,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.End,
            modifier = Modifier.widthIn(max = 180.dp)
        )
    }
}

// MARK: - Maintenance Tab
@Composable
private fun MaintenanceTab(vehicle: Vehicle) {
    var maintenanceList by remember { mutableStateOf<List<FleetMaintenance>>(emptyList()) }
    var documentsList by remember { mutableStateOf<List<FleetDocument>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(vehicle.imei) {
        isLoading = true
        try {
            val (mList, _) = APIService.fetchFleetMaintenance(imei = vehicle.imei, perPage = 10)
            maintenanceList = mList
        } catch (_: Exception) { maintenanceList = emptyList() }
        try {
            val (dList, _) = APIService.fetchFleetDocuments(imei = vehicle.imei, perPage = 10)
            documentsList = dList
        } catch (_: Exception) { documentsList = emptyList() }
        isLoading = false
    }

    if (isLoading) {
        Box(modifier = Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = AppColors.Indigo, strokeWidth = 2.dp, modifier = Modifier.size(24.dp))
        }
        return
    }

    SectionCard(title = "BAKIM TAKVİMİ", icon = Icons.Default.Build) {
        if (maintenanceList.isEmpty()) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            ) {
                Icon(Icons.Default.Build, null, tint = AppColors.TextFaint, modifier = Modifier.size(28.dp))
                Spacer(Modifier.height(8.dp))
                Text("Bakım kaydı bulunmuyor", fontSize = 13.sp, color = AppColors.TextMuted)
            }
        } else {
            Column {
                maintenanceList.forEachIndexed { index, item ->
                    val statusEnum = when (item.status) {
                        "done" -> MaintenanceStatus.COMPLETED
                        "scheduled" -> MaintenanceStatus.NORMAL
                        "overdue" -> MaintenanceStatus.OVERDUE
                        else -> MaintenanceStatus.UPCOMING
                    }
                    val icon = when {
                        item.maintenanceType.contains("lastik", true) -> Icons.Default.Circle
                        item.maintenanceType.contains("yağ", true) || item.maintenanceType.contains("oil", true) -> Icons.Default.WaterDrop
                        item.maintenanceType.contains("akü", true) || item.maintenanceType.contains("battery", true) -> Icons.Default.FlashOn
                        else -> Icons.Default.Build
                    }
                    val kmInfo = if (item.kmAtService != null) {
                        val fmt = java.text.NumberFormat.getNumberInstance(java.util.Locale("tr", "TR"))
                        "${fmt.format(item.kmAtService)} km"
                    } else ""
                    MaintenanceRow(icon, item.maintenanceType, item.nextServiceDate ?: item.serviceDate ?: "—", kmInfo, statusEnum)
                    if (index < maintenanceList.size - 1) {
                        HorizontalDivider(modifier = Modifier.padding(start = 44.dp), color = AppColors.BorderSoft)
                    }
                }
            }
        }
    }

    SectionCard(title = "BELGELER", icon = Icons.Default.Description) {
        if (documentsList.isEmpty()) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            ) {
                Icon(Icons.Default.Description, null, tint = AppColors.TextFaint, modifier = Modifier.size(28.dp))
                Spacer(Modifier.height(8.dp))
                Text("Belge kaydı bulunmuyor", fontSize = 13.sp, color = AppColors.TextMuted)
            }
        } else {
            Column {
                documentsList.forEachIndexed { index, doc ->
                    val docStatus = when (doc.status) {
                        "expired" -> DocStatus.CRITICAL
                        "expiring_soon" -> DocStatus.WARNING
                        else -> DocStatus.NORMAL
                    }
                    DocumentRow(doc.title.ifEmpty { doc.docTypeLabel }, doc.expiryDate ?: "—", doc.daysLeft ?: 0, docStatus)
                    if (index < documentsList.size - 1) {
                        HorizontalDivider(modifier = Modifier.padding(start = 14.dp), color = AppColors.BorderSoft)
                    }
                }
            }
        }
    }
}

// MARK: - Costs Tab
@Composable
private fun CostsTab(vehicle: Vehicle) {
    var costsList by remember { mutableStateOf<List<VehicleCost>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(vehicle.imei) {
        isLoading = true
        try {
            val (cList, _) = APIService.fetchFleetCosts(imei = vehicle.imei, perPage = 20)
            costsList = cList
        } catch (_: Exception) { costsList = emptyList() }
        isLoading = false
    }

    if (isLoading) {
        Box(modifier = Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = AppColors.Indigo, strokeWidth = 2.dp, modifier = Modifier.size(24.dp))
        }
        return
    }

    if (costsList.isEmpty()) {
        SectionCard(title = "MASRAFLAR", icon = Icons.Default.AttachMoney) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            ) {
                Icon(Icons.Default.AttachMoney, null, tint = AppColors.TextFaint, modifier = Modifier.size(28.dp))
                Spacer(Modifier.height(8.dp))
                Text("Masraf kaydı bulunmuyor", fontSize = 13.sp, color = AppColors.TextMuted)
            }
        }
        return
    }

    // Summary
    val totalAmount = costsList.sumOf { it.amount }
    val byCat = costsList.groupBy { it.category }.mapValues { (_, v) -> v.sumOf { it.amount } }
    val fmt = java.text.NumberFormat.getNumberInstance(java.util.Locale("tr", "TR")).apply { maximumFractionDigits = 0 }

    SectionCard(title = "MASRAF ÖZETİ", icon = Icons.Default.BarChart) {
        if (byCat.isNotEmpty()) {
            Row(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                byCat.entries.take(4).forEach { (cat, amount) ->
                    val color = when (cat.lowercase()) {
                        "fuel" -> Color(0xFFFF9800)
                        "maintenance" -> Color.Blue
                        "insurance" -> Color(0xFF9C27B0)
                        else -> AppColors.TextMuted
                    }
                    val label = when (cat.lowercase()) {
                        "fuel" -> "Yakıt"
                        "maintenance" -> "Bakım"
                        "insurance" -> "Sigorta"
                        "tire" -> "Lastik"
                        "tax" -> "Vergi"
                        "fine" -> "Ceza"
                        else -> "Diğer"
                    }
                    val percent = if (totalAmount > 0) ((amount / totalAmount) * 100).toInt() else 0
                    CostSummaryItem(label, "₺${fmt.format(amount)}", color, percent, Modifier.weight(1f))
                }
            }
        }

        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().background(AppColors.Navy.copy(alpha = 0.04f), RoundedCornerShape(10.dp)).padding(14.dp)
        ) {
            Text("TOPLAM", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted)
            Text("₺${fmt.format(totalAmount)}", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
        }
    }

    SectionCard(title = "SON MASRAFLAR", icon = Icons.Default.List) {
        Column {
            costsList.take(10).forEachIndexed { index, cost ->
                CostRow(cost)
                if (index < minOf(costsList.size, 10) - 1) {
                    HorizontalDivider(modifier = Modifier.padding(start = 62.dp), color = AppColors.BorderSoft)
                }
            }
        }
    }
}

// MARK: - Events Tab
@Composable
private fun EventsTab(vehicle: Vehicle, onNavigateToAlarms: ((String) -> Unit)? = null) {
    var alarms by remember { mutableStateOf<List<AlarmEvent>>(emptyList()) }
    var isLoadingAlarms by remember { mutableStateOf(true) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(vehicle.imei) {
        isLoadingAlarms = true
        try {
            // Fetch all alarms and filter client-side by this vehicle's imei
            val json = APIService.get("/api/mobile/alarms?page=1&per_page=50")
            val dataArr = json.optJSONArray("data")
            val results = mutableListOf<AlarmEvent>()
            if (dataArr != null) {
                for (i in 0 until dataArr.length()) {
                    val a = AlarmEvent.from(dataArr.getJSONObject(i), i)
                    if (a.imei == vehicle.imei || a.plate == vehicle.plate) {
                        results.add(a)
                    }
                }
            }
            alarms = results.take(10)
        } catch (_: Exception) {
            alarms = emptyList()
        }
        isLoadingAlarms = false
    }

    SectionCard(title = "SON OLAYLAR", icon = Icons.Default.Schedule) {
        if (isLoadingAlarms) {
            Box(modifier = Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = AppColors.Indigo, strokeWidth = 2.dp, modifier = Modifier.size(24.dp))
            }
        } else if (alarms.isEmpty()) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth().padding(24.dp)
            ) {
                Icon(Icons.Default.NotificationsOff, null, tint = AppColors.TextFaint, modifier = Modifier.size(32.dp))
                Spacer(Modifier.height(8.dp))
                Text("Bu araç için alarm bulunamadı", fontSize = 13.sp, color = AppColors.TextMuted)
            }
        } else {
            Column {
                alarms.forEachIndexed { index, alarm ->
                    EventRow(
                        alarm.icon,
                        alarm.typeLabel,
                        alarm.description.ifEmpty { alarm.plate },
                        alarm.formattedDate,
                        when {
                            alarm.alarmKey.contains("GF_", true) || alarm.alarmKey.contains("geofence", true) -> AlertSeverity.GREEN
                            alarm.alarmKey.contains("T_TOWING", true) || alarm.alarmKey.contains("sos", true) -> AlertSeverity.RED
                            alarm.alarmKey.contains("T_MOVEMENT", true) -> AlertSeverity.AMBER
                            else -> AlertSeverity.BLUE
                        }
                    )
                    if (index < alarms.size - 1) {
                        HorizontalDivider(modifier = Modifier.padding(start = 48.dp), color = AppColors.BorderSoft)
                    }
                }

                // "Tümünü Gör" button
                if (onNavigateToAlarms != null) {
                    Spacer(Modifier.height(8.dp))
                    HorizontalDivider(color = AppColors.BorderSoft)
                    TextButton(
                        onClick = { onNavigateToAlarms(vehicle.plate) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Tümünü Gör", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Indigo)
                        Spacer(Modifier.width(4.dp))
                        Icon(Icons.Default.ArrowForward, null, modifier = Modifier.size(14.dp), tint = AppColors.Indigo)
                    }
                }
            }
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
    val shareText = "${vehicle.plate} konumu:\n${vehicle.locationDisplay}\n\n$mapsUrl"
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
    val catLower = cost.category.lowercase()
    val color = when {
        catLower == "fuel" || catLower.contains("yakıt") -> Color(0xFFFF9800)
        catLower == "maintenance" || catLower.contains("bakım") -> Color.Blue
        catLower == "insurance" || catLower.contains("sigorta") -> Color(0xFF9C27B0)
        else -> AppColors.TextMuted
    }
    val icon = when {
        catLower == "fuel" || catLower.contains("yakıt") -> Icons.Default.LocalGasStation
        catLower == "maintenance" || catLower.contains("bakım") -> Icons.Default.Build
        catLower == "insurance" || catLower.contains("sigorta") -> Icons.Default.Shield
        else -> Icons.Default.MoreHoriz
    }
    val label = when (catLower) {
        "fuel" -> "Yakıt"
        "maintenance" -> "Bakım"
        "insurance" -> "Sigorta"
        "tire" -> "Lastik"
        "tax" -> "Vergi"
        "fine" -> "Ceza"
        "other" -> "Diğer"
        else -> cost.category.replaceFirstChar { it.uppercase() }
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
            Text(label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Text(cost.costDate.ifEmpty { "—" }, fontSize = 11.sp, color = AppColors.TextMuted)
        }
        Text(cost.formattedAmount, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
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
