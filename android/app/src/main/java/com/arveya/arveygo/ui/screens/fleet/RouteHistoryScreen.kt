package com.arveya.arveygo.ui.screens.fleet

import android.graphics.*
import android.graphics.drawable.BitmapDrawable
import android.util.Log
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
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
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.isActive
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
fun RouteHistoryScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var vehicles by remember { mutableStateOf<List<Vehicle>>(emptyList()) }
    var selectedVehicle by remember { mutableStateOf<Vehicle?>(null) }
    var selectedTrip by remember { mutableStateOf<RouteTrip?>(null) }
    var showDatePicker by remember { mutableStateOf(false) }
    var dateRange by remember { mutableStateOf("Bug\u00fcn") }
    var isPlaying by remember { mutableStateOf(false) }
    var playbackIndex by remember { mutableStateOf(0) }
    var playbackSpeed by remember { mutableStateOf(1f) }
    var trips by remember { mutableStateOf<List<RouteTrip>>(emptyList()) }
    var isLoadingRoutes by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var loadJob by remember { mutableStateOf<Job?>(null) }
    var followVehicle by remember { mutableStateOf(true) }
    var isAutoAdvancing by remember { mutableStateOf(false) }
    val tripListState = rememberLazyListState()

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
        // Cancel any in-flight load
        loadJob?.cancel()
        loadJob = scope.launch {
            isLoadingRoutes = true
            errorMessage = null
            trips = emptyList()
            selectedTrip = null
            isPlaying = false
            playbackIndex = 0
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
                if (selectedTrip == null || !parsed.any { it.id == selectedTrip?.id }) {
                    selectedTrip = parsed.firstOrNull()
                }
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
    val playbackMarkerRef = remember { mutableStateOf<Marker?>(null) }
    var lastPlaybackCameraAt by remember { mutableLongStateOf(0L) }

    // Draw routes on map when trip is selected or trips change
    LaunchedEffect(selectedTrip, trips) {
        val mapView = mapViewRef.value ?: return@LaunchedEffect
        // Clear previous overlays
        mapView.overlays.clear()
        playbackMarkerRef.value = null

        // Draw all trip polylines (non-selected in lighter color)
        for (trip in trips) {
            if (trip.points.size < 2) continue
            val isSelected = trip.id == selectedTrip?.id
            val polyline = OsmPolyline().apply {
                outlinePaint.color = if (isSelected) AppColors.Indigo.toArgb() else Color(0xFFB0B0FF).toArgb()
                outlinePaint.strokeWidth = if (isSelected) 6f else 3f
                outlinePaint.isAntiAlias = true
                outlinePaint.strokeCap = android.graphics.Paint.Cap.ROUND
                outlinePaint.strokeJoin = android.graphics.Paint.Join.ROUND
                setPoints(trip.points.map { GeoPoint(it.lat, it.lng) })
            }
            mapView.overlays.add(polyline)
        }

        // Add start/end markers for selected trip
        selectedTrip?.let { trip ->
            if (trip.points.isNotEmpty()) {
                // Start marker
                trip.points.firstOrNull()?.let { start ->
                    val startMarker = Marker(mapView).apply {
                        position = GeoPoint(start.lat, start.lng)
                        title = "Başlangıç"
                        snippet = trip.startAddress
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    }
                    mapView.overlays.add(startMarker)
                }

                // End marker
                trip.points.lastOrNull()?.let { end ->
                    val endMarker = Marker(mapView).apply {
                        position = GeoPoint(end.lat, end.lng)
                        title = "Bitiş"
                        snippet = trip.endAddress
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                    }
                    mapView.overlays.add(endMarker)
                }

                // Zoom to fit
                try {
                    val allPts = trip.points
                    if (allPts.size >= 2) {
                        val north = allPts.maxOf { it.lat }
                        val south = allPts.minOf { it.lat }
                        val east = allPts.maxOf { it.lng }
                        val west = allPts.minOf { it.lng }
                        val latPad = maxOf((north - south) * 0.15, 0.005)
                        val lngPad = maxOf((east - west) * 0.15, 0.005)
                        val box = BoundingBox(north + latPad, east + lngPad, south - latPad, west - lngPad)
                        mapView.zoomToBoundingBox(box, true, 60)
                    } else {
                        val pt = allPts.first()
                        mapView.controller.setCenter(GeoPoint(pt.lat, pt.lng))
                        mapView.controller.setZoom(15.0)
                    }
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

    // Reset playback when trip changes (but not during auto-advance)
    LaunchedEffect(selectedTrip?.id) {
        if (!isAutoAdvancing) {
            isPlaying = false
            playbackIndex = 0
        }
        isAutoAdvancing = false
        // Auto-scroll trip list to selected
        val idx = trips.indexOfFirst { it.id == selectedTrip?.id }
        if (idx >= 0) {
            tripListState.animateScrollToItem(idx)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text("Rota Ge\u00e7mi\u015fi", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
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
            // === COMPACT TOP BAR: Vehicle + Date + Search ===
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 6.dp)
            ) {
                // Vehicle selector - compact
                var expanded by remember { mutableStateOf(false) }
                Box(modifier = Modifier.weight(1f)) {
                    OutlinedButton(
                        onClick = { expanded = true },
                        shape = RoundedCornerShape(8.dp),
                        border = BorderStroke(1.dp, AppColors.BorderSoft),
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(36.dp)
                    ) {
                        Icon(Icons.Default.DirectionsCar, null, modifier = Modifier.size(14.dp), tint = AppColors.Indigo)
                        Spacer(Modifier.width(4.dp))
                        Text(
                            selectedVehicle?.plate ?: "Ara\u00e7",
                            fontSize = 11.sp, color = AppColors.Navy,
                            maxLines = 1, overflow = TextOverflow.Ellipsis
                        )
                        Spacer(Modifier.weight(1f))
                        Icon(Icons.Default.KeyboardArrowDown, null, modifier = Modifier.size(14.dp), tint = AppColors.TextMuted)
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

                // Date filter - compact toggle
                OutlinedButton(
                    onClick = { showDatePicker = !showDatePicker },
                    shape = RoundedCornerShape(8.dp),
                    border = BorderStroke(1.dp, AppColors.BorderSoft),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                    modifier = Modifier.height(36.dp)
                ) {
                    Icon(Icons.Default.CalendarMonth, null, modifier = Modifier.size(13.dp), tint = AppColors.Indigo)
                    Spacer(Modifier.width(4.dp))
                    Text(dateRange, fontSize = 11.sp, color = AppColors.Navy)
                }

                // Search / Refresh button - PROMINENT
                Button(
                    onClick = {
                        selectedVehicle?.let { v -> loadRoutes(v, startDate, endDate) }
                    },
                    shape = RoundedCornerShape(8.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.Indigo),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                    modifier = Modifier.height(36.dp)
                ) {
                    Icon(Icons.Default.Search, null, modifier = Modifier.size(16.dp), tint = Color.White)
                    Spacer(Modifier.width(4.dp))
                    Text("Ara", fontSize = 11.sp, color = Color.White, fontWeight = FontWeight.SemiBold)
                }
            }

            // Date quick filters - collapsible, improved design
            AnimatedVisibility(visible = showDatePicker) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 4.dp)
                        .background(AppColors.Surface, RoundedCornerShape(12.dp))
                        .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
                        .padding(12.dp)
                ) {
                    Text("Tarih Aral\u0131\u011f\u0131 Se\u00e7in", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                    Spacer(Modifier.height(8.dp))
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        listOf(
                            "Bug\u00fcn" to Icons.Default.WbSunny,
                            "D\u00fcn" to Icons.Default.DarkMode,
                            "Bu Hafta" to Icons.Default.DateRange,
                            "Bu Ay" to Icons.Default.CalendarMonth
                        ).forEach { (label, icon) ->
                            val isActive = dateRange == label
                            Box(
                                contentAlignment = Alignment.Center,
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(
                                        if (isActive) Brush.horizontalGradient(listOf(AppColors.Indigo, AppColors.Navy))
                                        else Brush.horizontalGradient(listOf(AppColors.Bg, AppColors.Bg))
                                    )
                                    .then(
                                        if (!isActive) Modifier.border(1.dp, AppColors.BorderSoft, RoundedCornerShape(20.dp))
                                        else Modifier
                                    )
                                    .clickable { applyDateFilter(label) }
                                    .padding(horizontal = 8.dp, vertical = 7.dp)
                            ) {
                                Row(
                                    horizontalArrangement = Arrangement.Center,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(icon, null, modifier = Modifier.size(11.dp), tint = if (isActive) Color.White else AppColors.TextMuted)
                                    Spacer(Modifier.width(3.dp))
                                    Text(label, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = if (isActive) Color.White else AppColors.TextSecondary)
                                }
                            }
                        }
                    }
                }
            }

            // === MAP - Takes maximum available space ===
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(horizontal = 8.dp, vertical = 4.dp)
                    .clip(RoundedCornerShape(12.dp))
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

                // Playback controls overlay - compact with global slider
                if (selectedTrip != null) {
                    Column(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(8.dp)
                            .background(AppColors.Surface.copy(alpha = 0.95f), RoundedCornerShape(10.dp))
                            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(10.dp))
                            .padding(horizontal = 10.dp, vertical = 6.dp)
                    ) {
                        // Global calculations for slider (must be before Row so they're accessible)
                        val totalGlobalPts = trips.sumOf { it.points.size }
                        val globalIdx = run {
                            var offset = 0
                            for (t in trips) {
                                if (t.id == selectedTrip?.id) break
                                offset += t.points.size
                            }
                            offset + playbackIndex
                        }

                        Row(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // Reset
                            IconButton(onClick = {
                                isPlaying = false
                                playbackIndex = 0
                                // Jump to first trip
                                if (trips.isNotEmpty()) {
                                    isAutoAdvancing = true
                                    selectedTrip = trips.first()
                                }
                            }, modifier = Modifier.size(26.dp)) {
                                Icon(Icons.Default.SkipPrevious, null, tint = AppColors.Navy, modifier = Modifier.size(16.dp))
                            }
                            // Play/Pause
                            IconButton(
                                onClick = {
                                    if (isPlaying) {
                                        isPlaying = false
                                    } else {
                                        // If at very end of all trips, restart
                                        val lastTrip = trips.lastOrNull()
                                        if (selectedTrip?.id == lastTrip?.id && playbackIndex >= (lastTrip?.points?.size ?: 1) - 1) {
                                            isAutoAdvancing = true
                                            selectedTrip = trips.firstOrNull()
                                            playbackIndex = 0
                                        } else {
                                            val pts = selectedTrip?.points ?: emptyList()
                                            if (playbackIndex >= pts.size - 1) {
                                                // Advance to next trip
                                                val idx = trips.indexOfFirst { it.id == selectedTrip?.id }
                                                if (idx >= 0 && idx + 1 < trips.size) {
                                                    isAutoAdvancing = true
                                                    selectedTrip = trips[idx + 1]
                                                    playbackIndex = 0
                                                }
                                            }
                                        }
                                        isPlaying = true
                                    }
                                },
                                modifier = Modifier
                                    .size(32.dp)
                                    .clip(CircleShape)
                                    .background(AppColors.Navy)
                            ) {
                                Icon(
                                    if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                                    null, tint = Color.White, modifier = Modifier.size(18.dp)
                                )
                            }
                            // Skip to end
                            IconButton(onClick = {
                                isPlaying = false
                                if (trips.isNotEmpty()) {
                                    val lastTrip = trips.last()
                                    isAutoAdvancing = true
                                    selectedTrip = lastTrip
                                    playbackIndex = maxOf(0, lastTrip.points.size - 1)
                                }
                            }, modifier = Modifier.size(26.dp)) {
                                Icon(Icons.Default.SkipNext, null, tint = AppColors.Navy, modifier = Modifier.size(16.dp))
                            }

                            // Global progress text
                            val currentTripIdx = trips.indexOfFirst { it.id == selectedTrip?.id }
                            Text(
                                "Sefer ${(currentTripIdx + 1).coerceAtLeast(1)}/${trips.size}",
                                fontSize = 9.sp,
                                color = AppColors.Indigo,
                                fontWeight = FontWeight.SemiBold
                            )

                            // Speed selector
                            var speedExpanded by remember { mutableStateOf(false) }
                            Box {
                                Box(
                                    contentAlignment = Alignment.Center,
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(6.dp))
                                        .background(AppColors.Indigo.copy(alpha = 0.1f))
                                        .clickable { speedExpanded = true }
                                        .padding(horizontal = 8.dp, vertical = 3.dp)
                                ) {
                                    Text(
                                        "${playbackSpeed.toInt()}x",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = AppColors.Indigo
                                    )
                                }
                                DropdownMenu(expanded = speedExpanded, onDismissRequest = { speedExpanded = false }) {
                                    listOf(1f, 2f, 4f, 8f).forEach { spd ->
                                        DropdownMenuItem(
                                            text = { Text("${spd.toInt()}x") },
                                            onClick = { playbackSpeed = spd; speedExpanded = false }
                                        )
                                    }
                                }
                            }
                        }

                        // Global slider
                        if (totalGlobalPts > 1) {
                            Slider(
                                value = globalIdx.toFloat() / (totalGlobalPts - 1).coerceAtLeast(1).toFloat(),
                                onValueChange = { frac ->
                                    val targetIdx = (frac * (totalGlobalPts - 1)).toInt()
                                    var cumulative = 0
                                    for ((i, t) in trips.withIndex()) {
                                        if (cumulative + t.points.size > targetIdx) {
                                            val localIdx = targetIdx - cumulative
                                            if (selectedTrip?.id != t.id) {
                                                isAutoAdvancing = true
                                                selectedTrip = t
                                            }
                                            playbackIndex = localIdx.coerceIn(0, t.points.size - 1)
                                            return@Slider
                                        }
                                        cumulative += t.points.size
                                    }
                                },
                                modifier = Modifier.fillMaxWidth().height(20.dp),
                                colors = SliderDefaults.colors(
                                    thumbColor = AppColors.Indigo,
                                    activeTrackColor = AppColors.Indigo
                                )
                            )
                        }
                    }
                }

                // Follow vehicle toggle - top right of map
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp)
                        .background(AppColors.Surface.copy(alpha = 0.9f), RoundedCornerShape(8.dp))
                        .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(8.dp))
                        .clickable { followVehicle = !followVehicle }
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Icon(
                        if (followVehicle) Icons.Default.GpsFixed else Icons.Default.GpsOff,
                        null,
                        tint = if (followVehicle) AppColors.Indigo else AppColors.TextMuted,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        if (followVehicle) "Takip" else "Serbest",
                        fontSize = 9.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (followVehicle) AppColors.Indigo else AppColors.TextMuted
                    )
                }

                // Playback animation with auto-advance and follow
                LaunchedEffect(isPlaying, playbackSpeed, selectedTrip?.id) {
                    if (!isPlaying) return@LaunchedEffect
                    val trip = selectedTrip ?: return@LaunchedEffect
                    while (isActive && playbackIndex < trip.points.size - 1) {
                        delay((400L / playbackSpeed).toLong())
                        playbackIndex++
                        val pt = trip.points[playbackIndex]
                        mapViewRef.value?.let { mv ->
                            val target = GeoPoint(pt.lat, pt.lng)
                            val marker = playbackMarkerRef.value ?: Marker(mv).apply {
                                title = "__playback__"
                                setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                                position = target
                                mv.overlays.add(this)
                                playbackMarkerRef.value = this
                            }
                            marker.position = target
                            if (followVehicle) {
                                val now = System.currentTimeMillis()
                                if (now - lastPlaybackCameraAt >= 800L) {
                                    lastPlaybackCameraAt = now
                                    mv.controller.animateTo(target)
                                }
                            }
                            mv.invalidate()
                        }
                    }
                    // Trip ended - auto advance
                    if (playbackIndex >= (trip.points.size) - 1) {
                        val tripIdx = trips.indexOfFirst { it.id == selectedTrip?.id }
                        if (tripIdx >= 0 && tripIdx + 1 < trips.size) {
                            isAutoAdvancing = true
                            selectedTrip = trips[tripIdx + 1]
                            playbackIndex = 0
                            // isPlaying stays true, new LaunchedEffect will fire
                        } else {
                            isPlaying = false
                        }
                    }
                }
            }

            // === LIVE HUD BAR - speed graph + info ===
            selectedTrip?.let { trip ->
                val currentPoint = if ((isPlaying || playbackIndex > 0) && playbackIndex < trip.points.size)
                    trip.points[playbackIndex] else null
                val currentSpeed = currentPoint?.speed ?: 0
                val currentTime = if (currentPoint?.time?.isNotEmpty() == true) currentPoint.time else trip.startTime
                val currentTripIdx = trips.indexOfFirst { it.id == selectedTrip?.id }
                val speedColor = when {
                    currentSpeed == 0 -> AppColors.Idle
                    currentSpeed < 30 -> AppColors.Online
                    currentSpeed < 80 -> AppColors.Indigo
                    currentSpeed < 120 -> Color(0xFFFF9800)
                    else -> AppColors.Offline
                }

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 3.dp)
                        .background(AppColors.Surface, RoundedCornerShape(8.dp))
                        .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(8.dp))
                ) {
                    // Speed graph
                    SpeedGraphBar(
                        points = trip.points,
                        playbackIndex = playbackIndex,
                        isActive = isPlaying || playbackIndex > 0,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(36.dp)
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    )

                    // Info row: speed badge + time + sefer + address
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 10.dp)
                            .padding(bottom = 6.dp)
                    ) {
                        // Compact speed badge
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .background(speedColor.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
                                .padding(horizontal = 8.dp, vertical = 3.dp)
                        ) {
                            Icon(Icons.Default.Speed, null, tint = speedColor, modifier = Modifier.size(10.dp))
                            Spacer(Modifier.width(3.dp))
                            Text("$currentSpeed km/h", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = speedColor)
                        }

                        Spacer(Modifier.width(8.dp))
                        Box(Modifier.width(1.dp).height(20.dp).background(AppColors.BorderSoft))
                        Spacer(Modifier.width(8.dp))

                        // Dynamic info
                        Column(modifier = Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Schedule, null, tint = AppColors.Indigo, modifier = Modifier.size(10.dp))
                                Spacer(Modifier.width(3.dp))
                                Text(currentTime, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                                Spacer(Modifier.width(6.dp))
                                Text("\u2022", fontSize = 8.sp, color = AppColors.TextMuted)
                                Spacer(Modifier.width(6.dp))
                                Text(
                                    "Sefer ${(currentTripIdx + 1).coerceAtLeast(1)}/${trips.size}",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = AppColors.Indigo
                                )
                                Spacer(Modifier.weight(1f))
                            }
                            Spacer(Modifier.height(2.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.LocationOn, null, tint = AppColors.TextMuted, modifier = Modifier.size(10.dp))
                                Spacer(Modifier.width(3.dp))
                                Text(
                                    trip.startAddress,
                                    fontSize = 10.sp,
                                    color = AppColors.TextMuted,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                        }
                    }
                }
            }

            // === COMPACT TRIP LIST - horizontal scrollable cards ===
            if (isLoadingRoutes) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.fillMaxWidth().height(60.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(color = AppColors.Indigo, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                        Spacer(Modifier.width(8.dp))
                        Text("Y\u00fckleniyor...", fontSize = 11.sp, color = AppColors.TextMuted)
                    }
                }
            } else if (errorMessage != null) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.fillMaxWidth().height(50.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.ErrorOutline, null, tint = AppColors.Offline, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(errorMessage ?: "Hata", fontSize = 11.sp, color = AppColors.TextMuted, maxLines = 1)
                    }
                }
            } else if (trips.isEmpty()) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.fillMaxWidth().height(50.dp)
                ) {
                    Text("Bu tarihte rota bulunamad\u0131", fontSize = 11.sp, color = AppColors.TextMuted)
                }
            } else {
                // Trip count label
                Text(
                    "Seferler (${trips.size})",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.TextMuted,
                    modifier = Modifier.padding(start = 12.dp, top = 4.dp, bottom = 2.dp)
                )

                // Horizontal scrollable trip chips with auto-scroll
                LazyRow(
                    state = tripListState,
                    contentPadding = PaddingValues(horizontal = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 8.dp)
                ) {
                    itemsIndexed(trips) { index, trip ->
                        CompactTripCard(
                            trip = trip,
                            index = index,
                            isSelected = selectedTrip?.id == trip.id,
                            onClick = { selectedTrip = trip }
                        )
                    }
                }
            }
        }
    }
}

/** Compact horizontal trip card - much smaller footprint */
@Composable
private fun CompactTripCard(trip: RouteTrip, index: Int, isSelected: Boolean, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .width(160.dp)
            .background(if (isSelected) AppColors.Indigo.copy(alpha = 0.04f) else AppColors.Surface, RoundedCornerShape(10.dp))
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = if (isSelected) AppColors.Indigo else AppColors.BorderSoft,
                shape = RoundedCornerShape(10.dp)
            )
            .clickable(onClick = onClick)
            .padding(10.dp)
    ) {
        // Header
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Sefer ${index + 1}", fontSize = 9.sp, fontWeight = FontWeight.Bold,
                color = if (isSelected) AppColors.Indigo else AppColors.TextMuted)
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(6.dp).clip(CircleShape).background(if (isSelected) AppColors.Indigo else AppColors.BorderSoft))
        }
        Spacer(Modifier.height(3.dp))
        // Time range
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(5.dp).clip(CircleShape).background(AppColors.Online))
            Spacer(Modifier.width(3.dp))
            Text(trip.startTime, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
            Text(" \u2192 ", fontSize = 9.sp, color = AppColors.TextMuted)
            Text(trip.endTime, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
        }

        Spacer(Modifier.height(4.dp))

        // Distance & Duration
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Route, null, tint = AppColors.Indigo, modifier = Modifier.size(10.dp))
                Spacer(Modifier.width(2.dp))
                Text(trip.distance, fontSize = 10.sp, color = AppColors.TextSecondary)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Schedule, null, tint = AppColors.Indigo, modifier = Modifier.size(10.dp))
                Spacer(Modifier.width(2.dp))
                Text(trip.duration, fontSize = 10.sp, color = AppColors.TextSecondary)
            }
        }

        Spacer(Modifier.height(3.dp))

        // Max speed
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.Speed, null, tint = AppColors.Indigo, modifier = Modifier.size(10.dp))
            Spacer(Modifier.width(2.dp))
            Text("Max: ${trip.maxSpeed}", fontSize = 9.sp, color = AppColors.TextMuted)
        }
    }
}

// MARK: - Speed Graph Bar (Canvas-based sparkline)
@Composable
private fun SpeedGraphBar(
    points: List<RoutePoint>,
    playbackIndex: Int,
    isActive: Boolean,
    modifier: Modifier = Modifier
) {
    if (points.size < 2) return

    val maxSpeed = points.maxOf { it.speed }.coerceAtLeast(1)
    val progress = playbackIndex.toFloat() / (points.size - 1).coerceAtLeast(1).toFloat()

    // Colors
    val fillGradientTop = AppColors.Indigo.copy(alpha = 0.15f)
    val fillGradientBottom = AppColors.Indigo.copy(alpha = 0.02f)
    val lineGreen = Color(0xFF22C55E)
    val lineAmber = Color(0xFFF59E0B)
    val lineRed = Color(0xFFEF4444)
    val indicatorColor = when {
        !isActive -> Color.Transparent
        else -> {
            val spd = points.getOrNull(playbackIndex)?.speed ?: 0
            when {
                spd == 0 -> AppColors.Idle
                spd < 30 -> AppColors.Online
                spd < 80 -> AppColors.Indigo
                spd < 120 -> Color(0xFFFF9800)
                else -> AppColors.Offline
            }
        }
    }

    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        val step = w / (points.size - 1).coerceAtLeast(1).toFloat()

        // Helper: y from speed
        fun yOf(speed: Int): Float = h - (speed.toFloat() / maxSpeed.toFloat()) * (h - 4f)

        // 1) Fill gradient under curve
        val fillPath = androidx.compose.ui.graphics.Path().apply {
            moveTo(0f, h)
            for (i in points.indices) {
                val x = i * step
                val y = yOf(points[i].speed)
                if (i == 0) {
                    lineTo(x, y)
                } else {
                    val prevX = (i - 1) * step
                    val prevY = yOf(points[i - 1].speed)
                    val midX = (prevX + x) / 2f
                    cubicTo(midX, prevY, midX, y, x, y)
                }
            }
            lineTo(w, h)
            close()
        }
        drawPath(
            path = fillPath,
            brush = Brush.verticalGradient(listOf(fillGradientTop, fillGradientBottom))
        )

        // 2) Speed line — gradient green→amber→red from bottom→top
        val linePath = androidx.compose.ui.graphics.Path().apply {
            for (i in points.indices) {
                val x = i * step
                val y = yOf(points[i].speed)
                if (i == 0) {
                    moveTo(x, y)
                } else {
                    val prevX = (i - 1) * step
                    val prevY = yOf(points[i - 1].speed)
                    val midX = (prevX + x) / 2f
                    cubicTo(midX, prevY, midX, y, x, y)
                }
            }
        }
        drawPath(
            path = linePath,
            brush = Brush.verticalGradient(listOf(lineRed, lineAmber, lineGreen)),
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2f)
        )

        // 3) Playback indicator — vertical line + dot
        if (isActive) {
            val posX = w * progress
            val currentSpd = points.getOrNull(playbackIndex)?.speed ?: 0
            val posY = yOf(currentSpd)

            // Vertical line
            drawLine(
                color = indicatorColor.copy(alpha = 0.4f),
                start = androidx.compose.ui.geometry.Offset(posX, 0f),
                end = androidx.compose.ui.geometry.Offset(posX, h),
                strokeWidth = 1.5f
            )

            // Dot
            drawCircle(
                color = indicatorColor,
                radius = 4f,
                center = androidx.compose.ui.geometry.Offset(posX, posY)
            )
            // Glow
            drawCircle(
                color = indicatorColor.copy(alpha = 0.3f),
                radius = 7f,
                center = androidx.compose.ui.geometry.Offset(posX, posY)
            )
        }
    }
}
