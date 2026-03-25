package com.arveya.arveygo.ui.screens.fleet

import android.graphics.*
import android.graphics.drawable.BitmapDrawable
import android.util.Log
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.arveya.arveygo.models.*
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.services.WebSocketManager
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline as OsmPolyline
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RouteHistoryScreen(onMenuClick: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var vehicles by remember { mutableStateOf<List<Vehicle>>(emptyList()) }
    var selectedVehicle by remember { mutableStateOf<Vehicle?>(null) }
    var selectedTrip by remember { mutableStateOf<RouteTrip?>(null) }
    var showDatePicker by remember { mutableStateOf(false) }
    var dateRange by remember { mutableStateOf("Bug\u00fcn") }
    var isPlaying by remember { mutableStateOf(false) }
    var trips by remember { mutableStateOf<List<RouteTrip>>(emptyList()) }
    var isLoadingRoutes by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    // Date range state
    var startDate by remember {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        mutableStateOf(cal.time)
    }
    var endDate by remember { mutableStateOf(Date()) }

    val dateFormat = remember { SimpleDateFormat("yyyy-MM-dd", Locale.US) }

    // Helper to format time from ISO date string
    fun formatTimeOnly(isoString: String): String {
        val cleaned = isoString.replace(Regex("\\.\\d+"), "")
        val formats = listOf("yyyy-MM-dd'T'HH:mm:ssXXX", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss")
        for (fmt in formats) {
            try {
                val sdf = SimpleDateFormat(fmt, Locale.US)
                val date = sdf.parse(cleaned) ?: continue
                val outFmt = SimpleDateFormat("HH:mm", Locale.US)
                return outFmt.format(date)
            } catch (_: Exception) {}
        }
        // Fallback: try to extract HH:mm from string
        val timeMatch = Regex("(\\d{2}:\\d{2})").find(isoString)
        return timeMatch?.groupValues?.get(1) ?: isoString
    }

    // Helper to format date label
    fun formatDateLabel(isoString: String): String {
        val cleaned = isoString.replace(Regex("\\.\\d+"), "")
        val formats = listOf("yyyy-MM-dd'T'HH:mm:ssXXX", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss")
        for (fmt in formats) {
            try {
                val sdf = SimpleDateFormat(fmt, Locale.US)
                val date = sdf.parse(cleaned) ?: continue
                val cal = Calendar.getInstance()
                val todayCal = Calendar.getInstance()
                cal.time = date
                if (cal.get(Calendar.YEAR) == todayCal.get(Calendar.YEAR) &&
                    cal.get(Calendar.DAY_OF_YEAR) == todayCal.get(Calendar.DAY_OF_YEAR)) return "Bugün"
                todayCal.add(Calendar.DAY_OF_YEAR, -1)
                if (cal.get(Calendar.YEAR) == todayCal.get(Calendar.YEAR) &&
                    cal.get(Calendar.DAY_OF_YEAR) == todayCal.get(Calendar.DAY_OF_YEAR)) return "Dün"
                return SimpleDateFormat("dd MMM yyyy", Locale("tr")).format(date)
            } catch (_: Exception) {}
        }
        return isoString
    }

    // IMEI → device_id cache
    val imeiToDeviceId = mutableMapOf<String, Int>()

    // Resolve IMEI to backend device_id
    suspend fun resolveDeviceId(imei: String): Int {
        imeiToDeviceId[imei]?.let { return it }
        val json = withContext(Dispatchers.IO) { APIService.get("/api/mobile/route-history/vehicles") }
        val data = json.optJSONArray("data")
        if (data != null) {
            for (i in 0 until data.length()) {
                val v = data.getJSONObject(i)
                val vImei = v.optString("imei", "")
                val vId = v.optInt("id", v.optInt("deviceId", 0))
                if (vImei.isNotEmpty() && vId > 0) {
                    imeiToDeviceId[vImei] = vId
                }
            }
        }
        return imeiToDeviceId[imei] ?: throw Exception("Araç bulunamadı (IMEI: $imei)")
    }

    // Load routes from API
    fun loadRoutes(vehicle: Vehicle, from: Date, to: Date) {
        scope.launch {
            isLoadingRoutes = true
            errorMessage = null
            try {
                val startStr = dateFormat.format(from)
                val endStr = dateFormat.format(to)
                // Resolve IMEI to backend device_id
                val deviceId = resolveDeviceId(vehicle.id)
                val path = "/api/mobile/route-history/$deviceId/trips?started_at=$startStr&ended_at=$endStr&per_page=4"
                Log.d("RouteHistory", "Loading: $path")
                val json = withContext(Dispatchers.IO) { APIService.get(path) }

                val tripsArr = json.optJSONArray("trips") ?: json.optJSONArray("data")
                val parsed = mutableListOf<RouteTrip>()
                if (tripsArr != null) {
                    for (i in 0 until tripsArr.length()) {
                        val t = tripsArr.getJSONObject(i)
                        val tripNo = t.optInt("tripNo", t.optInt("trip_no", i + 1))
                        val startedAt = t.optString("startTime", t.optString("started_at", ""))
                        val endedAt = t.optString("endTime", t.optString("ended_at", ""))

                        // Distance comes in meters from API
                        val distM = t.optDouble("distance", 0.0)
                        val distKm = distM / 1000.0
                        val distStr = if (distKm < 1.0) "%.0f m".format(distM) else "%.1f km".format(distKm)

                        // Duration in seconds
                        val dur = t.optInt("duration", 0)
                        val durMin = dur / 60
                        val durSec = dur % 60
                        val durStr = if (durMin > 0) "${durMin}dk ${durSec}sn" else "${durSec}sn"

                        val maxSpd = t.optInt("maxSpeed", t.optInt("max_speed", 0))
                        val avgSpd = t.optInt("avgSpeed", t.optInt("avg_speed", 0))

                        // Parse inline coords array [[lat, lng, alt], ...]
                        val points = mutableListOf<RoutePoint>()
                        val coordsArr = t.optJSONArray("coords")
                        if (coordsArr != null && coordsArr.length() > 0) {
                            for (j in 0 until coordsArr.length()) {
                                val coord = coordsArr.optJSONArray(j)
                                if (coord != null && coord.length() >= 2) {
                                    points.add(RoutePoint(
                                        lat = coord.optDouble(0, 0.0),
                                        lng = coord.optDouble(1, 0.0),
                                        speed = 0, time = ""
                                    ))
                                }
                            }
                        }

                        // If no inline coords, fetch playbackPoints from points endpoint
                        if (points.isEmpty()) {
                            try {
                                val ptsPath = "/api/mobile/route-history/$deviceId/trips/$tripNo/points?started_at=$startStr&ended_at=$endStr"
                                val ptsJson = withContext(Dispatchers.IO) { APIService.get(ptsPath) }

                                // Try playbackPoints first (full data)
                                val pbArr = ptsJson.optJSONArray("playbackPoints")
                                if (pbArr != null && pbArr.length() > 0) {
                                    for (j in 0 until pbArr.length()) {
                                        val p = pbArr.getJSONObject(j)
                                        points.add(RoutePoint(
                                            lat = p.optDouble("lat", 0.0),
                                            lng = p.optDouble("lng", 0.0),
                                            speed = p.optInt("speed", 0),
                                            time = formatTimeOnly(p.optString("time", ""))
                                        ))
                                    }
                                } else {
                                    // Fallback to routeCoords [[lat, lng, alt], ...]
                                    val rcArr = ptsJson.optJSONArray("routeCoords")
                                    if (rcArr != null && rcArr.length() > 0) {
                                        for (j in 0 until rcArr.length()) {
                                            val coord = rcArr.optJSONArray(j)
                                            if (coord != null && coord.length() >= 2) {
                                                points.add(RoutePoint(
                                                    lat = coord.optDouble(0, 0.0),
                                                    lng = coord.optDouble(1, 0.0),
                                                    speed = 0, time = ""
                                                ))
                                            }
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                Log.e("RouteHistory", "Failed to load points for trip $tripNo", e)
                            }
                        }

                        // If still no points, use startCoord/endCoord
                        if (points.isEmpty()) {
                            val sc = t.optJSONArray("startCoord")
                            if (sc != null && sc.length() >= 2) {
                                points.add(RoutePoint(sc.optDouble(0, 0.0), sc.optDouble(1, 0.0), 0, formatTimeOnly(startedAt)))
                            }
                            val ec = t.optJSONArray("endCoord")
                            if (ec != null && ec.length() >= 2) {
                                points.add(RoutePoint(ec.optDouble(0, 0.0), ec.optDouble(1, 0.0), 0, formatTimeOnly(endedAt)))
                            }
                        }

                        val startLabel = t.optString("startTimeLabel", formatTimeOnly(startedAt))
                        val endLabel = t.optString("endTimeLabel", formatTimeOnly(endedAt))

                        parsed.add(RouteTrip(
                            id = "trip$tripNo",
                            dateLabel = formatDateLabel(startedAt),
                            startTime = formatTimeOnly(startedAt),
                            endTime = formatTimeOnly(endedAt),
                            startAddress = startLabel,
                            endAddress = endLabel,
                            distance = distStr,
                            duration = durStr,
                            maxSpeed = "$maxSpd km/h",
                            avgSpeed = "$avgSpd km/h",
                            fuelUsed = "\u2014",
                            points = points
                        ))
                    }
                }
                trips = parsed
                Log.d("RouteHistory", "Loaded ${parsed.size} trips")
            } catch (e: Exception) {
                Log.e("RouteHistory", "Failed to load routes", e)
                errorMessage = e.message
            } finally {
                isLoadingRoutes = false
            }
        }
    }

    // Subscribe to WebSocket vehicles
    LaunchedEffect(Unit) {
        WebSocketManager.vehicleList.collectLatest { list ->
            if (list.isNotEmpty()) {
                vehicles = list
                if (selectedVehicle == null) {
                    selectedVehicle = list.first()
                }
            }
        }
    }

    // Load routes when vehicle or date changes
    LaunchedEffect(selectedVehicle, startDate, endDate) {
        selectedVehicle?.let { v ->
            loadRoutes(v, startDate, endDate)
        }
    }

    // Update date range from quick filter
    fun applyDateFilter(label: String) {
        dateRange = label
        val cal = Calendar.getInstance()
        when (label) {
            "Bugün" -> {
                cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0)
                startDate = cal.time
                endDate = Date()
            }
            "Dün" -> {
                cal.add(Calendar.DAY_OF_YEAR, -1)
                cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0)
                startDate = cal.time
                val endCal = Calendar.getInstance()
                endCal.add(Calendar.DAY_OF_YEAR, -1)
                endCal.set(Calendar.HOUR_OF_DAY, 23); endCal.set(Calendar.MINUTE, 59); endCal.set(Calendar.SECOND, 59)
                endDate = endCal.time
            }
            "Bu Hafta" -> {
                cal.set(Calendar.DAY_OF_WEEK, cal.firstDayOfWeek)
                cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0)
                startDate = cal.time
                endDate = Date()
            }
            "Bu Ay" -> {
                cal.set(Calendar.DAY_OF_MONTH, 1)
                cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0)
                startDate = cal.time
                endDate = Date()
            }
        }
        showDatePicker = false
    }

    LaunchedEffect(Unit) {
        Configuration.getInstance().apply {
            userAgentValue = context.packageName
        }
    }

    val mapViewRef = remember { mutableStateOf<MapView?>(null) }

    // Draw route on map when trip is selected
    LaunchedEffect(selectedTrip) {
        val mapView = mapViewRef.value ?: return@LaunchedEffect
        // Clear previous overlays
        mapView.overlays.clear()

        selectedTrip?.let { trip ->
            if (trip.points.isNotEmpty()) {
                // Draw polyline
                val polyline = OsmPolyline().apply {
                    outlinePaint.color = AppColors.Indigo.toArgb()
                    outlinePaint.strokeWidth = 5f
                    setPoints(trip.points.map { GeoPoint(it.lat, it.lng) })
                }
                mapView.overlays.add(polyline)

                // Start marker
                trip.points.firstOrNull()?.let { start ->
                    val startMarker = Marker(mapView).apply {
                        position = GeoPoint(start.lat, start.lng)
                        title = "Ba\u015flang\u0131\u00e7"
                        snippet = trip.startAddress
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    }
                    mapView.overlays.add(startMarker)
                }

                // End marker
                trip.points.lastOrNull()?.let { end ->
                    val endMarker = Marker(mapView).apply {
                        position = GeoPoint(end.lat, end.lng)
                        title = "Biti\u015f"
                        snippet = trip.endAddress
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    }
                    mapView.overlays.add(endMarker)
                }

                // Zoom to fit
                try {
                    val north = trip.points.maxOf { it.lat }
                    val south = trip.points.minOf { it.lat }
                    val east = trip.points.maxOf { it.lng }
                    val west = trip.points.minOf { it.lng }
                    val box = BoundingBox(north + 0.02, east + 0.02, south - 0.02, west - 0.02)
                    mapView.zoomToBoundingBox(box, true, 60)
                } catch (_: Exception) {}
            }
        }
        mapView.invalidate()
    }

    DisposableEffect(Unit) {
        onDispose {
            mapViewRef.value?.onDetach()
        }
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
                        Text("Rota Ge\u00e7mi\u015fi", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        Text(selectedVehicle?.plate ?: "Ara\u00e7 Se\u00e7in", fontSize = 10.sp, color = AppColors.TextMuted)
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
        ) {
            // Vehicle selector & date range
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            ) {
                var expanded by remember { mutableStateOf(false) }
                Box(modifier = Modifier.weight(1f)) {
                    OutlinedButton(
                        onClick = { expanded = true },
                        shape = RoundedCornerShape(10.dp),
                        border = BorderStroke(1.dp, AppColors.BorderSoft),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(42.dp)
                    ) {
                        Icon(Icons.Default.DirectionsCar, null, modifier = Modifier.size(14.dp), tint = AppColors.Indigo)
                        Spacer(Modifier.width(6.dp))
                        Text(
                            selectedVehicle?.plate ?: "Ara\u00e7 Se\u00e7in",
                            fontSize = 11.sp, color = AppColors.Navy,
                            maxLines = 1, overflow = TextOverflow.Ellipsis
                        )
                        Spacer(Modifier.weight(1f))
                        Icon(Icons.Default.KeyboardArrowDown, null, modifier = Modifier.size(16.dp), tint = AppColors.TextMuted)
                    }
                    DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                        vehicles.forEach { v ->
                            DropdownMenuItem(
                                text = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Box(Modifier.size(6.dp).clip(CircleShape).background(v.status.color))
                                        Spacer(Modifier.width(8.dp))
                                        Text("${v.plate} \u2014 ${v.model}", fontSize = 12.sp)
                                    }
                                },
                                onClick = {
                                    selectedVehicle = v
                                    expanded = false
                                }
                            )
                        }
                    }
                }

                OutlinedButton(
                    onClick = { showDatePicker = !showDatePicker },
                    shape = RoundedCornerShape(10.dp),
                    border = BorderStroke(1.dp, AppColors.BorderSoft),
                    modifier = Modifier.height(42.dp)
                ) {
                    Icon(Icons.Default.CalendarMonth, null, modifier = Modifier.size(14.dp), tint = AppColors.Indigo)
                    Spacer(Modifier.width(6.dp))
                    Text(dateRange, fontSize = 11.sp, color = AppColors.Navy)
                }
            }

            // Date quick filters
            AnimatedVisibility(visible = showDatePicker) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                ) {
                    listOf("Bug\u00fcn", "D\u00fcn", "Bu Hafta", "Bu Ay").forEach { label ->
                        val isActive = dateRange == label
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier
                                .clip(RoundedCornerShape(20.dp))
                                .background(if (isActive) AppColors.Navy else AppColors.Surface)
                                .border(1.dp, if (isActive) AppColors.Navy else AppColors.BorderSoft, RoundedCornerShape(20.dp))
                                .clickable { applyDateFilter(label) }
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text(label, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = if (isActive) Color.White else AppColors.TextSecondary)
                        }
                    }
                }
            }

            // Map with route (osmdroid - FREE)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(250.dp)
                    .padding(horizontal = 16.dp, vertical = 4.dp)
                    .clip(RoundedCornerShape(14.dp))
            ) {
                AndroidView(
                    factory = { ctx ->
                        MapView(ctx).apply {
                            setTileSource(TileSourceFactory.MAPNIK)
                            setMultiTouchControls(true)
                            controller.setZoom(15.0)
                            controller.setCenter(GeoPoint(40.136, 26.408))
                            zoomController.setVisibility(
                                org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER
                            )
                            mapViewRef.value = this
                        }
                    },
                    modifier = Modifier.fillMaxSize()
                )

                // Playback controls overlay
                if (selectedTrip != null) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(12.dp)
                            .background(AppColors.Surface.copy(alpha = 0.95f), RoundedCornerShape(12.dp))
                            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        IconButton(onClick = {}, modifier = Modifier.size(28.dp)) {
                            Icon(Icons.Default.SkipPrevious, null, tint = AppColors.Navy, modifier = Modifier.size(16.dp))
                        }
                        IconButton(
                            onClick = { isPlaying = !isPlaying },
                            modifier = Modifier
                                .size(34.dp)
                                .clip(CircleShape)
                                .background(AppColors.Navy)
                        ) {
                            Icon(
                                if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                                null, tint = Color.White, modifier = Modifier.size(18.dp)
                            )
                        }
                        IconButton(onClick = {}, modifier = Modifier.size(28.dp)) {
                            Icon(Icons.Default.SkipNext, null, tint = AppColors.Navy, modifier = Modifier.size(16.dp))
                        }
                        Text("1x", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AppColors.Indigo)
                    }
                }
            }

            // Trip summary
            selectedTrip?.let { trip ->
                Row(
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 6.dp)
                        .background(AppColors.Surface, RoundedCornerShape(12.dp))
                        .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
                        .padding(12.dp)
                ) {
                    TripStat("Mesafe", trip.distance, Icons.Default.Route)
                    TripStat("S\u00fcre", trip.duration, Icons.Default.Schedule)
                    TripStat("Max H\u0131z", trip.maxSpeed, Icons.Default.Speed)
                    TripStat("Ort. H\u0131z", trip.avgSpeed, Icons.Default.Timeline)
                    TripStat("Yak\u0131t", trip.fuelUsed, Icons.Default.LocalGasStation)
                }
            }

            // Trip list
            if (isLoadingRoutes) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.fillMaxSize()
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator(color = AppColors.Indigo, modifier = Modifier.size(32.dp))
                        Spacer(Modifier.height(8.dp))
                        Text("Rotalar yükleniyor...", fontSize = 12.sp, color = AppColors.TextMuted)
                    }
                }
            } else if (errorMessage != null) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.fillMaxSize()
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Default.ErrorOutline, null, tint = AppColors.Offline, modifier = Modifier.size(32.dp))
                        Spacer(Modifier.height(8.dp))
                        Text(errorMessage ?: "Hata oluştu", fontSize = 12.sp, color = AppColors.TextMuted)
                    }
                }
            } else if (trips.isEmpty()) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.fillMaxSize()
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Default.Route, null, tint = AppColors.TextMuted, modifier = Modifier.size(32.dp))
                        Spacer(Modifier.height(8.dp))
                        Text("Bu tarih aralığında rota bulunamadı", fontSize = 12.sp, color = AppColors.TextMuted)
                    }
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxSize()
                ) {
                    val grouped = trips.groupBy { it.dateLabel }
                    grouped.forEach { (date, dayTrips) ->
                        item {
                            Text(date, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = AppColors.TextMuted, modifier = Modifier.padding(vertical = 4.dp))
                        }
                        items(dayTrips) { trip ->
                            TripCard(trip, isSelected = selectedTrip?.id == trip.id) { selectedTrip = trip }
                        }
                    }
                    item { Spacer(Modifier.height(20.dp)) }
                }
            }
        }
    }
}

@Composable
private fun TripStat(label: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
        Spacer(Modifier.height(3.dp))
        Text(value, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
        Text(label, fontSize = 8.sp, color = AppColors.TextMuted)
    }
}

@Composable
private fun TripCard(trip: RouteTrip, isSelected: Boolean, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface, RoundedCornerShape(14.dp))
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = if (isSelected) AppColors.Indigo else AppColors.BorderSoft,
                shape = RoundedCornerShape(14.dp)
            )
            .clickable(onClick = onClick)
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.size(10.dp).clip(CircleShape).background(AppColors.Online))
                Box(Modifier.width(2.dp).height(28.dp).background(AppColors.BorderSoft))
                Box(Modifier.size(10.dp).clip(CircleShape).background(AppColors.Offline))
            }
            Spacer(Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                    Text(trip.startAddress, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                    Text(trip.startTime, fontSize = 10.sp, color = AppColors.TextMuted)
                }
                Spacer(Modifier.height(14.dp))
                Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                    Text(trip.endAddress, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                    Text(trip.endTime, fontSize = 10.sp, color = AppColors.TextMuted)
                }
            }
        }

        Spacer(Modifier.height(10.dp))
        HorizontalDivider(color = AppColors.BorderSoft.copy(alpha = 0.5f))
        Spacer(Modifier.height(8.dp))

        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            TripMetricChip(Icons.Default.Route, trip.distance)
            TripMetricChip(Icons.Default.Schedule, trip.duration)
            TripMetricChip(Icons.Default.Speed, trip.maxSpeed)
            TripMetricChip(Icons.Default.LocalGasStation, trip.fuelUsed)
        }
    }
}

@Composable
private fun TripMetricChip(icon: androidx.compose.ui.graphics.vector.ImageVector, value: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .background(AppColors.Bg, RoundedCornerShape(20.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(11.dp))
        Spacer(Modifier.width(4.dp))
        Text(value, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
    }
}
