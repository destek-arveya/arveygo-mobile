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
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.models.*
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.services.WSEvent
import com.arveya.arveygo.services.WebSocketManager
import com.arveya.arveygo.ui.components.StatusBadge
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.utils.DashboardStrings
import kotlinx.coroutines.launch
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker

private const val VEHICLE_SETTINGS_HIDDEN_IGNITION_PREFIX = "__mobile_private_ign__"

// Tab enum matching iOS
private enum class DetailTab {
    OVERVIEW,
    MAINTENANCE,
    COSTS,
    EVENTS;

    val label: String
        get() = when (this) {
            OVERVIEW -> DashboardStrings.t("Genel", "Overview", "Resumen", "Aperçu")
            MAINTENANCE -> DashboardStrings.t("Bakım", "Maintenance", "Mantenimiento", "Maintenance")
            COSTS -> DashboardStrings.t("Masraf", "Expense", "Gasto", "Dépense")
            EVENTS -> DashboardStrings.t("Olaylar", "Events", "Eventos", "Événements")
        }
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    var selectedTab by remember { mutableStateOf(DetailTab.OVERVIEW) }
    val context = LocalContext.current
    var currentVehicle by remember { mutableStateOf(vehicle) }
    var showVehicleSettings by remember { mutableStateOf(false) }
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

    // If vehicle settings is showing, show the full-screen settings page
    if (showVehicleSettings) {
        VehicleSettingsScreen(
            vehicle = currentVehicle,
            onBack = { showVehicleSettings = false }
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
                            Icon(Icons.Default.ChevronLeft, null, tint = AppColors.DarkText, modifier = Modifier.size(18.dp))
                            Text(DL.t("Geri", "Back", "Atrás", "Retour"), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.DarkText)
                        }
                    }
                },
                title = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                        Text(currentVehicle.plate, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.DarkText)
                        Text(DL.t("Araç Detayı", "Vehicle Detail", "Detalle del vehículo", "Détail du véhicule"), fontSize = 10.sp, color = AppColors.DarkTextMuted)
                    }
                },
                actions = {
                    IconButton(onClick = { showVehicleSettings = true }) {
                        Icon(Icons.Default.Settings, null, tint = AppColors.Online, modifier = Modifier.size(22.dp))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = AppColors.DarkSurface)
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(AppColors.DarkBg)
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
    val mapViewRef = remember { mutableStateOf<MapView?>(null) }

    DisposableEffect(Unit) {
        onDispose {
            mapViewRef.value?.onDetach()
            mapViewRef.value = null
        }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
    ) {
        if (vehicle.hasValidCoordinates) {
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
                        mapViewRef.value = this
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
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            )
        }

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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .offset(y = (-30).dp)
            .clip(RoundedCornerShape(16.dp))
            .background(AppColors.DarkSurface)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(16.dp)
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(56.dp)
                    .background(vehicle.status.color.copy(alpha = 0.15f), RoundedCornerShape(14.dp))
            ) {
                Icon(
                    if (vehicle.isMotorcycle) Icons.Default.TwoWheeler else Icons.Default.DirectionsCar,
                    null, tint = vehicle.status.color, modifier = Modifier.size(22.dp)
                )
            }
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(vehicle.plate, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = AppColors.DarkText)
                    Spacer(Modifier.width(8.dp))
                    StatusBadge(vehicle.status)
                }
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

        HorizontalDivider(color = AppColors.DarkBorder)

        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
            QuickStatItem(DL.t("Toplam Km", "Total KM", "KM total", "KM total"), vehicle.formattedTotalKm, Icons.Default.Speed, AppColors.Lavender, Modifier.weight(1f))
            Box(Modifier.width(1.dp).height(40.dp).background(AppColors.DarkBorder))
            QuickStatItem(DL.t("Bugün", "Today", "Hoy", "Aujourd'hui"), vehicle.formattedTodayKm, Icons.Default.Route, AppColors.Indigo, Modifier.weight(1f))
            Box(Modifier.width(1.dp).height(40.dp).background(AppColors.DarkBorder))
            QuickStatItem(DL.t("Sürücü", "Driver", "Conductor", "Conducteur"), run {
                val name = if (vehicle.driverName.isNotEmpty()) vehicle.driverName else vehicle.driver
                if (name.isEmpty()) "—" else name.split(" ").firstOrNull() ?: "—"
            }, Icons.Default.Person, AppColors.Online, Modifier.weight(1f))
            Box(Modifier.width(1.dp).height(40.dp).background(AppColors.DarkBorder))
            QuickStatItem(DL.t("Konum", "Location", "Ubicación", "Position"), vehicle.locationDisplay, Icons.Default.LocationOn, Color(0xFFFF9800), Modifier.weight(1f))
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
        Text(value, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = AppColors.DarkText, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(label, fontSize = 9.sp, color = AppColors.DarkTextMuted)
    }
}

// MARK: - Tab Selector
@Composable
private fun TabSelector(selectedTab: DetailTab, onSelect: (DetailTab) -> Unit) {
    val currentLang by DashboardStrings.currentLang.collectAsState()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .offset(y = (-14).dp)
            .background(AppColors.DarkSurface, RoundedCornerShape(12.dp))
            .border(1.dp, AppColors.DarkBorder, RoundedCornerShape(12.dp))
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
                    color = if (selectedTab == tab) AppColors.DarkText else AppColors.DarkTextMuted
                )
                Spacer(Modifier.height(6.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth(0.7f)
                        .height(2.5.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(if (selectedTab == tab) AppColors.Lavender else Color.Transparent)
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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
            .background(AppColors.DarkSurface, RoundedCornerShape(14.dp))
            .padding(14.dp)
    ) {
        data class QuickAction(val icon: ImageVector, val label: String, val color: Color, val onClick: () -> Unit)
        val actions = listOf(
            QuickAction(Icons.Default.Navigation, DL.t("Yol Tarifi", "Directions", "Ruta", "Itinéraire"), Color(0xFF3B82F6)) {
                openMapsDirections(context, vehicle.lat, vehicle.lng, vehicle.plate)
            },
            QuickAction(Icons.Default.History, DL.t("Rota Geçmişi", "Route History", "Historial de rutas", "Historique des trajets"), AppColors.Lavender) {
                onBack()
                onNavigateToRouteHistory?.invoke(vehicle)
            },
            QuickAction(Icons.Default.Edit, DL.t("Düzenle", "Edit", "Editar", "Modifier"), Color(0xFF8B5CF6)) {
                showEditDialog = true
            },
            QuickAction(Icons.Default.Lock, DL.t("Blokaj", "Blockage", "Bloqueo", "Blocage"), Color(0xFFEF4444)) {
                showBlockageDialog = true
            },
            QuickAction(Icons.Default.Share, DL.t("Paylaş", "Share", "Compartir", "Partager"), AppColors.DarkTextMuted) {
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
                        .background(action.color.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
                ) {
                    Icon(action.icon, null, tint = action.color, modifier = Modifier.size(17.dp))
                }
                Spacer(Modifier.height(6.dp))
                Text(action.label, fontSize = 9.sp, fontWeight = FontWeight.Medium, color = AppColors.DarkTextMuted, textAlign = TextAlign.Center, maxLines = 1)
            }
        }
    }

    // ── Vehicle Info ──
    CleanListCard {
        DetailRow(Icons.Default.Speed, DL.t("Hız", "Speed", "Velocidad", "Vitesse"), vehicle.formattedSpeed)
        ListDivider()
        DetailRow(Icons.Default.LocationOn, DL.t("Konum", "Location", "Ubicación", "Position"), vehicle.locationDisplay)
        if (vehicle.deviceTime != null) {
            ListDivider()
            DetailRow(Icons.Default.Schedule, DL.t("Son Güncelleme", "Last Update", "Última actualización", "Dernière mise à jour"), vehicle.formattedDeviceTime)
        }
        if (vehicle.lastPacketAt != null) {
            ListDivider()
            DetailRow(Icons.Default.Sync, DL.t("Son Paket", "Last Packet", "Último paquete", "Dernier paquet"), vehicle.formattedLastPacketAt)
        }
    }

    // ── Kontak & Güç ──
    CleanListCard {
        DetailRow(
            Icons.Default.VpnKey, DL.t("Kontak", "Ignition", "Encendido", "Contact"),
            vehicle.kontakLabel,
            valueColor = if (vehicle.kontakOn) AppColors.Online else AppColors.Offline
        )
        ListDivider()
        DetailRow(Icons.Default.WbSunny, DL.t("İlk Kontak (Bugün)", "First Ignition (Today)", "Primer encendido (hoy)", "Premier contact (aujourd'hui)"), vehicle.formattedFirstIgnitionToday)
        ListDivider()
        DetailRow(Icons.Default.VpnKey, DL.t("Son Kontak Açma", "Last Ignition On", "Último encendido", "Dernier contact activé"), vehicle.formattedLastIgnitionOn)
        ListDivider()
        DetailRow(Icons.Default.VpnKey, DL.t("Son Kontak Kapama", "Last Ignition Off", "Último apagado", "Dernier contact coupé"), vehicle.formattedLastIgnitionOff)
        ListDivider()
        
        if (vehicle.deviceBattery != null) {
            ListDivider()
            DetailRow(Icons.Default.PhoneAndroid, DL.t("Cihaz Bataryası", "Device Battery", "Batería del dispositivo", "Batterie de l'appareil"), formatDeviceBattery(vehicle.deviceBattery))
        }
        if (vehicle.externalVoltage != null) {
            ListDivider()
            DetailRow(Icons.Default.Bolt, DL.t("Harici Voltaj", "External Voltage", "Voltaje externo", "Tension externe"), formatVoltage(vehicle.externalVoltage))
        }
    }

    // ── Temperature & Sensors (conditional) ──
    if (vehicle.temperatureC != null || vehicle.humidityPct != null) {
        CleanListCard {
            vehicle.temperatureC?.let { temp ->
                DetailRow(Icons.Default.Thermostat, DL.t("Sıcaklık", "Temperature", "Temperatura", "Température"), String.format("%.1f°C", temp))
            }
            if (vehicle.temperatureC != null && vehicle.humidityPct != null) { ListDivider() }
            vehicle.humidityPct?.let { hum ->
                DetailRow(Icons.Default.WaterDrop, DL.t("Nem", "Humidity", "Humedad", "Humidité"), "%${hum.toInt()}")
            }
        }
    }

    // ── Yakıt & Maliyet ──
    if (vehicle.fuelType.isNotEmpty() || vehicle.dailyFuelPer100km > 0 || vehicle.fuelPer100km > 0) {
        CleanListCard {
            if (vehicle.fuelType.isNotEmpty()) {
                DetailRow(Icons.Default.LocalGasStation, DL.t("Yakıt Tipi", "Fuel Type", "Tipo de combustible", "Type de carburant"), vehicle.fuelType)
                ListDivider()
            }
            val rate = if (vehicle.dailyFuelPer100km > 0) vehicle.dailyFuelPer100km else vehicle.fuelPer100km
            if (rate > 0) {
                DetailRow(Icons.Default.Speed, DL.t("Tüketim", "Consumption", "Consumo", "Consommation"), String.format("%.1f L/100km", rate))
                ListDivider()
            }
            DetailRow(Icons.Default.WaterDrop, DL.t("Bugün Tahmini Yakıt", "Estimated Fuel Today", "Combustible estimado hoy", "Carburant estimé aujourd'hui"), vehicle.formattedDailyFuelLiters)
            ListDivider()
            DetailRow(Icons.Default.Payments, DL.t("Bugün Tahmini Maliyet", "Estimated Cost Today", "Costo estimado hoy", "Coût estimé aujourd'hui"), vehicle.formattedDailyFuelCost)
        }
    }

    // ── Driver ──
    var showDriverAssign by remember { mutableStateOf(false) }
    val displayName = if (driverName.isNotEmpty()) driverName else if (vehicle.driverName.isNotEmpty()) vehicle.driverName else ""

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.DarkSurface, RoundedCornerShape(14.dp))
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier.size(40.dp).clip(CircleShape).background(AppColors.Indigo.copy(alpha = 0.15f))
            ) {
                Text(
                    if (displayName.isEmpty()) "?" else displayName.take(1),
                    fontSize = 17.sp, fontWeight = FontWeight.Bold, color = AppColors.Lavender
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    if (displayName.isEmpty()) DL.t("Sürücü Atanmamış", "No Driver Assigned", "Sin conductor asignado", "Aucun conducteur assigné") else displayName,
                    fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.DarkText
                )
                Text(DL.t("Sürücü", "Driver", "Conductor", "Conducteur"), fontSize = 11.sp, color = AppColors.DarkTextMuted)
            }
            TextButton(onClick = { showDriverAssign = true }) {
                Icon(Icons.Default.Edit, null, modifier = Modifier.size(13.dp), tint = AppColors.Lavender)
                Spacer(Modifier.width(4.dp))
                Text(DL.t("Değiştir", "Change", "Cambiar", "Changer"), fontSize = 11.sp, fontWeight = FontWeight.Medium, color = AppColors.Lavender)
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
            .background(AppColors.DarkSurface, RoundedCornerShape(14.dp))
            .padding(vertical = 4.dp),
        content = content
    )
}

@Composable
private fun ListDivider() {
    HorizontalDivider(
        color = AppColors.DarkBorder,
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
            tint = AppColors.Lavender.copy(alpha = 0.8f),
            modifier = Modifier.size(16.dp)
        )
        Spacer(Modifier.width(14.dp))
        Text(
            label,
            fontSize = 13.sp,
            fontWeight = FontWeight.Normal,
            color = AppColors.DarkTextSub,
            modifier = Modifier.weight(1f)
        )
        Text(
            value,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = valueColor ?: AppColors.DarkText,
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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

    SectionCard(title = DL.t("BAKIM TAKVİMİ", "MAINTENANCE SCHEDULE", "CALENDARIO DE MANTENIMIENTO", "CALENDRIER D'ENTRETIEN"), icon = Icons.Default.Build) {
        if (maintenanceList.isEmpty()) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            ) {
                Icon(Icons.Default.Build, null, tint = AppColors.TextFaint, modifier = Modifier.size(28.dp))
                Spacer(Modifier.height(8.dp))
                Text(DL.t("Bakım kaydı bulunmuyor", "No maintenance records", "No hay registros de mantenimiento", "Aucun entretien"), fontSize = 13.sp, color = AppColors.TextMuted)
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

    SectionCard(title = DL.t("BELGELER", "DOCUMENTS", "DOCUMENTOS", "DOCUMENTS"), icon = Icons.Default.Description) {
        if (documentsList.isEmpty()) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            ) {
                Icon(Icons.Default.Description, null, tint = AppColors.TextFaint, modifier = Modifier.size(28.dp))
                Spacer(Modifier.height(8.dp))
                Text(DL.t("Belge kaydı bulunmuyor", "No document records", "No hay documentos", "Aucun document"), fontSize = 13.sp, color = AppColors.TextMuted)
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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
        SectionCard(title = DL.t("MASRAFLAR", "EXPENSES", "GASTOS", "DÉPENSES"), icon = Icons.Default.AttachMoney) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            ) {
                Icon(Icons.Default.AttachMoney, null, tint = AppColors.TextFaint, modifier = Modifier.size(28.dp))
                Spacer(Modifier.height(8.dp))
                Text(DL.t("Masraf kaydı bulunmuyor", "No expense records", "No hay gastos", "Aucune dépense"), fontSize = 13.sp, color = AppColors.TextMuted)
            }
        }
        return
    }

    // Summary
    val totalAmount = costsList.sumOf { it.amount }
    val byCat = costsList.groupBy { it.category }.mapValues { (_, v) -> v.sumOf { it.amount } }
    val fmt = java.text.NumberFormat.getNumberInstance(java.util.Locale("tr", "TR")).apply { maximumFractionDigits = 0 }

    SectionCard(title = DL.t("MASRAF ÖZETİ", "EXPENSE SUMMARY", "RESUMEN DE GASTOS", "RÉSUMÉ DES DÉPENSES"), icon = Icons.Default.BarChart) {
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
                        "fuel" -> DL.t("Yakıt", "Fuel", "Combustible", "Carburant")
                        "maintenance" -> DL.t("Bakım", "Maintenance", "Mantenimiento", "Maintenance")
                        "insurance" -> DL.t("Sigorta", "Insurance", "Seguro", "Assurance")
                        "tire" -> DL.t("Lastik", "Tire", "Neumático", "Pneu")
                        "tax" -> DL.t("Vergi", "Tax", "Impuesto", "Taxe")
                        "fine" -> DL.t("Ceza", "Fine", "Multa", "Amende")
                        else -> DL.t("Diğer", "Other", "Otro", "Autre")
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
            Text(DL.t("TOPLAM", "TOTAL", "TOTAL", "TOTAL"), fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted)
            Text("₺${fmt.format(totalAmount)}", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
        }
    }

    SectionCard(title = DL.t("SON MASRAFLAR", "RECENT EXPENSES", "GASTOS RECIENTES", "DÉPENSES RÉCENTES"), icon = Icons.Default.List) {
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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

    SectionCard(title = DL.t("SON OLAYLAR", "RECENT EVENTS", "EVENTOS RECIENTES", "ÉVÉNEMENTS RÉCENTS"), icon = Icons.Default.Schedule) {
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
                Text(DL.t("Bu araç için alarm bulunamadı", "No alarms found for this vehicle", "No se encontraron alarmas para este vehículo", "Aucune alarme pour ce véhicule"), fontSize = 13.sp, color = AppColors.TextMuted)
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
                        Text(DL.t("Tümünü Gör", "View All", "Ver todo", "Voir tout"), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Indigo)
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
    val DL = DashboardStrings
    val mapsUrl = "https://www.google.com/maps?q=${vehicle.lat},${vehicle.lng}"
    val shareText = DL.t("${vehicle.plate} konumu:\n${vehicle.locationDisplay}\n\n$mapsUrl", "${vehicle.plate} location:\n${vehicle.locationDisplay}\n\n$mapsUrl", "Ubicación de ${vehicle.plate}:\n${vehicle.locationDisplay}\n\n$mapsUrl", "Position de ${vehicle.plate} :\n${vehicle.locationDisplay}\n\n$mapsUrl")
    val sendIntent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, shareText)
        putExtra(Intent.EXTRA_SUBJECT, DL.t("${vehicle.plate} Araç Konumu", "${vehicle.plate} Vehicle Location", "Ubicación del vehículo ${vehicle.plate}", "Position du véhicule ${vehicle.plate}"))
    }
    context.startActivity(Intent.createChooser(sendIntent, DL.t("Konumu Paylaş", "Share Location", "Compartir ubicación", "Partager la position")))
}

// ============================================================================
// MARK: - Reusable Components
// ============================================================================

@Composable
private fun SectionCard(title: String, icon: ImageVector, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.DarkSurface, RoundedCornerShape(14.dp))
            .border(1.dp, AppColors.DarkBorder, RoundedCornerShape(14.dp))
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = AppColors.Lavender, modifier = Modifier.size(11.dp))
            Spacer(Modifier.width(8.dp))
            Text(title, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.DarkTextMuted, letterSpacing = 0.5.sp)
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
        modifier = modifier.background(AppColors.DarkCard, RoundedCornerShape(10.dp)).padding(10.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(26.dp).background(AppColors.Lavender.copy(alpha = 0.12f), RoundedCornerShape(7.dp))
        ) {
            Icon(icon, null, tint = AppColors.Lavender, modifier = Modifier.size(12.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f, fill = false)) {
            Text(label, fontSize = 8.sp, fontWeight = FontWeight.Bold, color = AppColors.DarkTextMuted, letterSpacing = 0.3.sp)
            Text(value, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = valueColor ?: AppColors.DarkText, maxLines = 1, overflow = TextOverflow.Ellipsis)
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
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.Medium, color = AppColors.DarkTextMuted, textAlign = TextAlign.Center, maxLines = 2, lineHeight = 11.sp)
    }
}

private enum class MaintenanceStatus(val color: Color) {
    COMPLETED(Color(0xFF22C55E)),
    UPCOMING(Color(0xFFFF9800)),
    NORMAL(Color.Blue),
    OVERDUE(Color.Red);

    val label: String
        get() = when (this) {
            COMPLETED -> DashboardStrings.t("Tamamlandı", "Completed", "Completado", "Terminé")
            UPCOMING -> DashboardStrings.t("Yaklaşıyor", "Upcoming", "Próximo", "À venir")
            NORMAL -> DashboardStrings.t("Planlandı", "Scheduled", "Programado", "Planifié")
            OVERDUE -> DashboardStrings.t("Gecikmiş", "Overdue", "Atrasado", "En retard")
        }
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
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.DarkText)
            Row {
                Text(date, fontSize = 11.sp, color = AppColors.DarkTextSub)
                Text(" • ", fontSize = 8.sp, color = AppColors.DarkTextMuted)
                Text(km, fontSize = 11.sp, color = AppColors.DarkTextSub)
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp, horizontal = 14.dp)
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.DarkText)
            Text(DL.t("Bitiş: $date", "Expiry: $date", "Vence: $date", "Expiration : $date"), fontSize = 11.sp, color = AppColors.DarkTextSub)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(DL.t("$daysLeft gün", "$daysLeft days", "$daysLeft días", "$daysLeft jours"), fontSize = 13.sp, fontWeight = FontWeight.Bold, color = status.color)
            Text(DL.t("kalan", "left", "restantes", "restants"), fontSize = 9.sp, color = AppColors.DarkTextMuted)
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
        Text(amount, fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AppColors.DarkText)
        Text(label, fontSize = 9.sp, color = AppColors.DarkTextMuted)
    }
}

@Composable
private fun CostRow(cost: VehicleCost) {
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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
        "fuel" -> DL.t("Yakıt", "Fuel", "Combustible", "Carburant")
        "maintenance" -> DL.t("Bakım", "Maintenance", "Mantenimiento", "Maintenance")
        "insurance" -> DL.t("Sigorta", "Insurance", "Seguro", "Assurance")
        "tire" -> DL.t("Lastik", "Tire", "Neumático", "Pneu")
        "tax" -> DL.t("Vergi", "Tax", "Impuesto", "Taxe")
        "fine" -> DL.t("Ceza", "Fine", "Multa", "Amende")
        "other" -> DL.t("Diğer", "Other", "Otro", "Autre")
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
            Text(label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.DarkText)
            Text(cost.costDate.ifEmpty { "—" }, fontSize = 11.sp, color = AppColors.DarkTextSub)
        }
        Text(cost.formattedAmount, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = AppColors.DarkText)
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
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.DarkText)
            Text(subtitle, fontSize = 11.sp, color = AppColors.DarkTextSub)
        }
        Text(time, fontSize = 10.sp, color = AppColors.DarkTextMuted, textAlign = TextAlign.End)
    }
}

// MARK: - Vehicle Settings Screen (Full Page)
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VehicleSettingsScreen(vehicle: Vehicle, onBack: () -> Unit) {
    val authVM = LocalAuthViewModel.current
    val currentUser by authVM.currentUser.collectAsState()
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    val colors = MaterialTheme.colorScheme
    val scope = rememberCoroutineScope()

    var ignitionOnNotificationEnabled by remember { mutableStateOf(false) }
    var ignitionOffNotificationEnabled by remember { mutableStateOf(false) }
    var ignitionPushEnabled by remember { mutableStateOf(true) }
    var ignitionSmsEnabled by remember { mutableStateOf(false) }
    var ignitionMailEnabled by remember { mutableStateOf(false) }
    var ignitionLoaded by remember { mutableStateOf(false) }
    var ignitionSyncing by remember { mutableStateOf(false) }
    var ignitionMessage by remember { mutableStateOf<String?>(null) }

    var movementAlarm by remember { mutableStateOf(false) }
    var weeklyHealthSummary by remember { mutableStateOf(false) }
    var overspeedEnabled by remember { mutableStateOf(false) }
    var overspeedLimit by remember { mutableIntStateOf(110) }
    var idleAlertEnabled by remember { mutableStateOf(false) }
    var idleMinutes by remember { mutableIntStateOf(10) }
    var sleepDelaySeconds by remember { mutableStateOf("30") }
    var wakeIntervalHours by remember { mutableStateOf("6") }
    var showKontakAlert by remember { mutableStateOf(false) }

    fun selectedChannels(): Set<String> = buildSet {
        if (ignitionPushEnabled) add("push")
        if (ignitionSmsEnabled) add("sms")
        if (ignitionMailEnabled) add("email")
    }

    fun hasAnyIgnitionNotificationEnabled(): Boolean =
        ignitionOnNotificationEnabled || ignitionOffNotificationEnabled

    fun scheduleIgnitionSync() {
        if (!ignitionLoaded) return
        scope.launch {
            val userId = resolveVehicleSettingsUserId(currentUser)
            val targetId = vehicleSettingsTargetId(vehicle)

            if (userId == null || targetId == null) {
                ignitionMessage = DL.t("Bildirim hedefi hazırlanamadı.", "Notification target could not be prepared.", "No se pudo preparar el destino de la notificación.", "La cible de notification n'a pas pu être préparée.")
                return@launch
            }

            if (hasAnyIgnitionNotificationEnabled() && selectedChannels().isEmpty()) {
                ignitionPushEnabled = true
            }

            ignitionSyncing = true
            ignitionMessage = null

            runCatching {
                syncVehicleIgnitionAlarmSettings(
                    vehicle = vehicle,
                    userId = userId,
                    ignitionOnEnabled = ignitionOnNotificationEnabled,
                    ignitionOffEnabled = ignitionOffNotificationEnabled,
                    channels = selectedChannels().toList().sorted()
                )
            }.onSuccess {
                ignitionMessage = if (hasAnyIgnitionNotificationEnabled()) {
                    DL.t("Kontak bildirimleri güncellendi.", "Ignition notifications updated.", "Las notificaciones de encendido se actualizaron.", "Les notifications de contact ont été mises à jour.")
                } else {
                    DL.t("Kontak bildirimleri kapatıldı.", "Ignition notifications disabled.", "Las notificaciones de encendido se desactivaron.", "Les notifications de contact ont été désactivées.")
                }
            }.onFailure {
                ignitionMessage = it.localizedMessage ?: DL.t("Kontak bildirimleri güncellenemedi.", "Ignition notifications could not be updated.", "No se pudieron actualizar las notificaciones de encendido.", "Les notifications de contact n'ont pas pu être mises à jour.")
            }

            ignitionSyncing = false
        }
    }

    fun setIgnitionNotificationEnabled(alarmType: String, enabled: Boolean) {
        when (alarmType) {
            "ignition_on" -> ignitionOnNotificationEnabled = enabled
            "ignition_off" -> ignitionOffNotificationEnabled = enabled
        }

        if (enabled && selectedChannels().isEmpty()) {
            ignitionPushEnabled = true
        }

        scheduleIgnitionSync()
    }

    fun setIgnitionChannel(channel: String, enabled: Boolean) {
        val channels = selectedChannels().toMutableSet()
        if (enabled) {
            channels += channel
            ignitionMessage = null
        } else {
            channels -= channel
            if (channels.isEmpty() && hasAnyIgnitionNotificationEnabled()) {
                ignitionMessage = DL.t("En az bir teslimat kanalı açık kalmalı.", "At least one delivery channel must remain enabled.", "Debe permanecer habilitado al menos un canal de entrega.", "Au moins un canal de livraison doit rester actif.")
                channels += channel
            }
        }

        ignitionPushEnabled = channels.contains("push")
        ignitionSmsEnabled = channels.contains("sms")
        ignitionMailEnabled = channels.contains("email")
        scheduleIgnitionSync()
    }

    LaunchedEffect(vehicle.id, currentUser?.id) {
        val userId = resolveVehicleSettingsUserId(currentUser)
        val targetId = vehicleSettingsTargetId(vehicle)

        if (userId == null || targetId == null) {
            ignitionLoaded = true
            ignitionMessage = DL.t("Bildirim hedefi hazırlanamadı.", "Notification target could not be prepared.", "No se pudo preparar el destino de la notificación.", "La cible de notification n'a pas pu être préparée.")
            return@LaunchedEffect
        }

        ignitionSyncing = true
        ignitionMessage = null

        runCatching {
            fetchVehicleHiddenIgnitionAlarmSets(vehicle, userId)
        }.onSuccess { sets ->
            val activeSets = sets.filter { it.isActive && it.status == "active" }
            val channelUnion = (if (activeSets.isEmpty()) sets else activeSets)
                .flatMap { it.channelList }
                .toSet()

            ignitionOnNotificationEnabled = activeSets.any { it.alarmType == "ignition_on" }
            ignitionOffNotificationEnabled = activeSets.any { it.alarmType == "ignition_off" }
            ignitionPushEnabled = channelUnion.contains("push") || channelUnion.isEmpty()
            ignitionSmsEnabled = channelUnion.contains("sms")
            ignitionMailEnabled = channelUnion.contains("email")
            ignitionMessage = null
        }.onFailure {
            ignitionMessage = it.localizedMessage ?: DL.t("Kontak bildirimleri yüklenemedi.", "Ignition notifications could not be loaded.", "No se pudieron cargar las notificaciones de encendido.", "Les notifications de contact n'ont pas pu être chargées.")
        }

        ignitionLoaded = true
        ignitionSyncing = false
    }

    if (showKontakAlert) {
        AlertDialog(
            onDismissRequest = { showKontakAlert = false },
            confirmButton = {
                TextButton(onClick = { showKontakAlert = false }) {
                    Text(DL.t("Tamam", "OK", "Aceptar", "OK"), fontWeight = FontWeight.Bold, color = AppColors.Online)
                }
            },
            icon = {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(48.dp)
                        .background(Color(0xFFFF9800).copy(alpha = 0.12f), CircleShape)
                ) {
                    Icon(Icons.Default.Warning, null, tint = Color(0xFFFF9800), modifier = Modifier.size(24.dp))
                }
            },
            title = {
                Text(DL.t("Kontak Kapalı", "Ignition Off", "Encendido apagado", "Contact coupé"), fontWeight = FontWeight.Bold, fontSize = 18.sp, color = colors.onSurface)
            },
            text = {
                Text(DL.t("Ayarları kaydetmek için aracın kontağının açık olması gereklidir.", "The ignition must be on to save settings.", "El encendido debe estar activo para guardar la configuración.", "Le contact doit être activé pour enregistrer les paramètres."), fontSize = 14.sp, color = colors.onSurface.copy(alpha = 0.7f))
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.ChevronLeft, null, tint = colors.onSurface, modifier = Modifier.size(18.dp))
                            Text(DL.t("Geri", "Back", "Atrás", "Retour"), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = colors.onSurface)
                        }
                    }
                },
                title = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                        Text(DL.t("Araç Ayarları", "Vehicle Settings", "Ajustes del vehículo", "Paramètres du véhicule"), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = colors.onSurface)
                        Text(vehicle.plate, fontSize = 10.sp, color = colors.onSurface.copy(alpha = 0.55f))
                    }
                },
                actions = { Spacer(Modifier.width(48.dp)) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.background)
            )
        },
        bottomBar = {
            Surface(shadowElevation = 8.dp, color = colors.surface) {
                Button(
                    onClick = {
                        if (!vehicle.ignition) {
                            showKontakAlert = true
                        } else {
                            onBack()
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                        .height(50.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.Online),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Icon(Icons.Default.Check, null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(DL.t("Kaydet", "Save", "Guardar", "Enregistrer"), fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(colors.background)
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Card(
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(containerColor = colors.surface),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 14.dp)
                ) {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .size(52.dp)
                            .background(vehicle.status.color.copy(alpha = 0.12f), RoundedCornerShape(14.dp))
                    ) {
                        Icon(
                            if (vehicle.isMotorcycle) Icons.Default.TwoWheeler else Icons.Default.DirectionsCar,
                            null,
                            tint = vehicle.status.color,
                            modifier = Modifier.size(24.dp)
                        )
                    }

                    Spacer(Modifier.width(12.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Text(vehicle.plate, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = colors.onSurface)
                        Text(
                            if (vehicle.model.isBlank()) DL.t("Araç ayar merkezi", "Vehicle settings center", "Centro de ajustes del vehículo", "Centre des paramètres du véhicule") else vehicle.model,
                            fontSize = 13.sp,
                            color = colors.onSurface.copy(alpha = 0.6f)
                        )
                    }

                    StatusBadge(status = vehicle.status)
                }
            }

            SettingsSection(DL.t("Kontak Bildirimleri", "Ignition Notifications", "Notificaciones de encendido", "Notifications de contact"), Icons.Default.Key) {
                SettingsToggle(
                    DL.t("Kontak Açılma Bildirimi", "Ignition On Notification", "Notificación de encendido", "Notification de mise du contact"),
                    DL.t("Araç kontağı açıldığında yalnızca size özel bildirim gönder", "Send a private notification only to you when the ignition turns on", "Envíe una notificación privada solo para usted cuando se encienda el contacto", "Envoyer une notification privée uniquement pour vous lorsque le contact s'allume"),
                    ignitionOnNotificationEnabled
                ) { enabled ->
                    setIgnitionNotificationEnabled("ignition_on", enabled)
                }

                SettingsToggle(
                    DL.t("Kontak Kapanma Bildirimi", "Ignition Off Notification", "Notificación de apagado", "Notification de coupure du contact"),
                    DL.t("Araç kontağı kapandığında yalnızca size özel bildirim gönder", "Send a private notification only to you when the ignition turns off", "Envíe una notificación privada solo para usted cuando se apague el contacto", "Envoyer une notification privée uniquement pour vous lorsque le contact se coupe"),
                    ignitionOffNotificationEnabled
                ) { enabled ->
                    setIgnitionNotificationEnabled("ignition_off", enabled)
                }

                if (hasAnyIgnitionNotificationEnabled()) {
                    Column(
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.padding(start = 8.dp, top = 6.dp)
                    ) {
                        SettingsToggle(DL.t("Mobil Bildirim", "Mobile Notification", "Notificación móvil", "Notification mobile"), DL.t("Uygulama içine push olarak düşsün", "Deliver as an in-app push notification", "Enviar como notificación push en la app", "Envoyer comme notification push dans l'application"), ignitionPushEnabled) {
                            setIgnitionChannel("push", it)
                        }
                        SettingsToggle("SMS", DL.t("Telefon numaranıza kısa mesaj gelsin", "Send a text message to your phone", "Enviar SMS a su teléfono", "Envoyer un SMS à votre téléphone"), ignitionSmsEnabled) {
                            setIgnitionChannel("sms", it)
                        }
                        SettingsToggle(DL.t("Mail", "Email", "Correo", "E-mail"), DL.t("E-posta adresinize bildirim özeti gelsin", "Send a notification summary to your email", "Enviar un resumen a su correo", "Envoyer un résumé à votre e-mail"), ignitionMailEnabled) {
                            setIgnitionChannel("email", it)
                        }

                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(top = 4.dp)
                        ) {
                            if (ignitionSyncing) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(14.dp),
                                    strokeWidth = 2.dp,
                                    color = AppColors.Online
                                )
                            } else {
                                Icon(Icons.Default.Person, null, tint = AppColors.Online, modifier = Modifier.size(14.dp))
                            }
                            Spacer(Modifier.width(8.dp))
                            Text(
                                ignitionMessage ?: DL.t("Bu bildirim yalnızca sizin hesabınıza gönderilir.", "This notification is sent only to your account.", "Esta notificación se envía solo a su cuenta.", "Cette notification est envoyée uniquement à votre compte."),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium,
                                color = if (ignitionMessage == null) colors.onSurface.copy(alpha = 0.6f) else Color(0xFFEF4444)
                            )
                        }
                    }
                }
            }

            SettingsSection(DL.t("Sürüş ve Güvenlik", "Driving & Safety", "Conducción y seguridad", "Conduite et sécurité"), Icons.Default.Shield) {
                SettingsToggle(DL.t("Hareket Algılandı", "Movement Detected", "Movimiento detectado", "Mouvement détecté"), DL.t("Beklenmeyen hareketlerde anlık uyarı ver", "Send an instant alert on unexpected movement", "Enviar alerta instantánea ante movimiento inesperado", "Envoyer une alerte instantanée en cas de mouvement inattendu"), movementAlarm) { movementAlarm = it }
                SettingsToggle(DL.t("Haftalık Durum Özeti", "Weekly Status Summary", "Resumen semanal de estado", "Résumé hebdomadaire"), DL.t("Bakım ve operasyon özetini haftalık paylaş", "Share maintenance and operations summary weekly", "Compartir semanalmente el resumen de mantenimiento y operaciones", "Partager chaque semaine le résumé maintenance et opérations"), weeklyHealthSummary) { weeklyHealthSummary = it }
                SettingsToggle(DL.t("Hız Aşımı Uyarısı", "Overspeed Alert", "Alerta de exceso de velocidad", "Alerte de survitesse"), DL.t("Belirlenen limit aşıldığında alarm üret", "Trigger an alert when the limit is exceeded", "Generar alerta cuando se supere el límite", "Déclencher une alerte lorsque la limite est dépassée"), overspeedEnabled) { overspeedEnabled = it }

                if (overspeedEnabled) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth().padding(top = 4.dp)
                    ) {
                        Text(DL.t("Hız Limiti", "Speed Limit", "Límite de velocidad", "Limite de vitesse"), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = colors.onSurface)
                        Spacer(Modifier.weight(1f))
                        Text("$overspeedLimit km/h", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Offline)
                    }
                    Slider(
                        value = overspeedLimit.toFloat(),
                        onValueChange = { overspeedLimit = it.toInt() },
                        valueRange = 50f..180f,
                        steps = 25,
                        colors = SliderDefaults.colors(thumbColor = AppColors.Offline, activeTrackColor = AppColors.Offline)
                    )
                }

                SettingsToggle(DL.t("Rölanti Uyarısı", "Idle Alert", "Alerta de ralentí", "Alerte de ralenti"), DL.t("Araç uzun süre çalışır halde beklerse bildir", "Notify if the vehicle idles for too long", "Notificar si el vehículo permanece mucho tiempo al ralentí", "Notifier si le véhicule reste trop longtemps au ralenti"), idleAlertEnabled) { idleAlertEnabled = it }
                if (idleAlertEnabled) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth().padding(top = 4.dp)
                    ) {
                        Text(DL.t("Rölanti Süresi", "Idle Duration", "Duración de ralentí", "Durée de ralenti"), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = colors.onSurface)
                        Spacer(Modifier.weight(1f))
                        Text(DL.t("$idleMinutes dk", "$idleMinutes min", "$idleMinutes min", "$idleMinutes min"), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Idle)
                    }
                    Slider(
                        value = idleMinutes.toFloat(),
                        onValueChange = { idleMinutes = it.toInt() },
                        valueRange = 3f..60f,
                        steps = 56,
                        colors = SliderDefaults.colors(thumbColor = AppColors.Idle, activeTrackColor = AppColors.Idle)
                    )
                }
            }

            SettingsSection(DL.t("Cihaz ve Raporlama", "Device & Reporting", "Dispositivo y reportes", "Appareil et rapports"), Icons.Default.Tune) {
                OutlinedTextField(
                    value = sleepDelaySeconds,
                    onValueChange = { sleepDelaySeconds = it.filter { char -> char.isDigit() } },
                    label = { Text(DL.t("Uyku Süresi (sn)", "Sleep Delay (sec)", "Tiempo de reposo (seg)", "Délai de veille (sec)")) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = wakeIntervalHours,
                    onValueChange = { wakeIntervalHours = it.filter { char -> char.isDigit() } },
                    label = { Text(DL.t("Uyanma Periyodu (saat)", "Wake Interval (hours)", "Periodo de activación (horas)", "Période de réveil (heures)")) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

private suspend fun resolveVehicleSettingsUserId(currentUser: AppUser?): Int? {
    currentUser?.id?.toIntOrNull()?.let { return it }
    return try {
        APIService.fetchMe().id.toIntOrNull()
    } catch (_: Exception) {
        null
    }
}

private fun vehicleSettingsTargetScope(vehicle: Vehicle): String =
    if (vehicle.assignmentId != null) "assignment" else "device"

private fun vehicleSettingsTargetId(vehicle: Vehicle): Int? =
    vehicle.assignmentId?.takeIf { it > 0 } ?: vehicle.deviceId.takeIf { it > 0 }

private fun vehicleSettingsHiddenAlarmName(vehicle: Vehicle, userId: Int, alarmType: String): String {
    val targetId = vehicleSettingsTargetId(vehicle) ?: 0
    val targetScope = vehicleSettingsTargetScope(vehicle)
    return "${VEHICLE_SETTINGS_HIDDEN_IGNITION_PREFIX}u${userId}__${targetScope}_${targetId}__${alarmType}"
}

private suspend fun fetchVehicleHiddenIgnitionAlarmSets(vehicle: Vehicle, userId: Int): List<AlarmSet> {
    val targetId = vehicleSettingsTargetId(vehicle) ?: return emptyList()
    val searchKey = "${VEHICLE_SETTINGS_HIDDEN_IGNITION_PREFIX}u${userId}__${vehicleSettingsTargetScope(vehicle)}_${targetId}__"
    val json = APIService.get("/api/mobile/alarm-sets/?search=$searchKey")
    val data = json.optJSONArray("data") ?: return emptyList()
    return buildList {
        for (index in 0 until data.length()) {
            val set = AlarmSet.from(data.optJSONObject(index) ?: org.json.JSONObject())
            if (set.name.startsWith(searchKey)) add(set)
        }
    }
}

private fun vehicleHiddenIgnitionBody(
    vehicle: Vehicle,
    userId: Int,
    alarmType: String,
    channels: List<String>
): org.json.JSONObject {
    val targetId = vehicleSettingsTargetId(vehicle) ?: 0
    return org.json.JSONObject().apply {
        put("name", vehicleSettingsHiddenAlarmName(vehicle, userId, alarmType))
        put("description", "mobile_private_ignition_notification")
        put("alarm_type", alarmType)
        put("status", "active")
        put("evaluation_mode", "live")
        put("source_mode", "derived")
        put("cooldown_sec", 0)
        put("is_active", true)
        put("condition_require_ignition", true)
        put(
            "targets",
            org.json.JSONArray().put(
                org.json.JSONObject()
                    .put("scope", vehicleSettingsTargetScope(vehicle))
                    .put("id", targetId)
            )
        )
        put("channels", org.json.JSONArray().apply { channels.forEach { put(it) } })
        put("recipient_ids", org.json.JSONArray().put(userId))
    }
}

private suspend fun syncVehicleIgnitionAlarmSettings(
    vehicle: Vehicle,
    userId: Int,
    ignitionOnEnabled: Boolean,
    ignitionOffEnabled: Boolean,
    channels: List<String>
) {
    val existingSets = fetchVehicleHiddenIgnitionAlarmSets(vehicle, userId)
    val grouped = existingSets.groupBy { it.alarmType }

    for ((type, enabled) in listOf(
        "ignition_on" to ignitionOnEnabled,
        "ignition_off" to ignitionOffEnabled
    )) {
        val matches = (grouped[type] ?: emptyList()).sortedByDescending { it.id }
        val primary = matches.firstOrNull()
        val duplicates = matches.drop(1)

        for (duplicate in duplicates) {
            try {
                APIService.post("/api/mobile/alarm-sets/${duplicate.id}/archive")
            } catch (_: Exception) {
            }
        }

        if (enabled) {
            val body = vehicleHiddenIgnitionBody(vehicle, userId, type, channels)
            if (primary != null) {
                APIService.put("/api/mobile/alarm-sets/${primary.id}", body)
            } else {
                APIService.post("/api/mobile/alarm-sets/", body)
            }
        } else if (primary != null && (primary.isActive || primary.status == "active")) {
            APIService.post("/api/mobile/alarm-sets/${primary.id}/pause")
        }
    }
}

@Composable
private fun SettingsSection(title: String, icon: ImageVector, content: @Composable ColumnScope.() -> Unit) {
    val colors = MaterialTheme.colorScheme
    Card(
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = colors.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(bottom = 8.dp)
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(30.dp)
                        .background(AppColors.Online.copy(alpha = 0.12f), RoundedCornerShape(10.dp))
                ) {
                    Icon(icon, null, tint = AppColors.Online, modifier = Modifier.size(16.dp))
                }
                Spacer(Modifier.width(10.dp))
                Text(title, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = colors.onSurface)
            }
            content()
        }
    }
}

@Composable
private fun SettingsToggle(title: String, subtitle: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    val colors = MaterialTheme.colorScheme
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = colors.onSurface)
            Text(subtitle, fontSize = 11.sp, color = colors.onSurface.copy(alpha = 0.58f))
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(checkedTrackColor = AppColors.Online)
        )
    }
}
