package com.arveya.arveygo.ui.screens.fleet

import android.graphics.*
import android.graphics.drawable.BitmapDrawable
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
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arveya.arveygo.models.*
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.viewmodels.DashboardViewModel
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline as OsmPolyline

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RouteHistoryScreen(onMenuClick: () -> Unit) {
    val context = LocalContext.current
    val vm: DashboardViewModel = viewModel()
    val vehicles by vm.vehicles.collectAsState()
    var selectedVehicle by remember { mutableStateOf<Vehicle?>(null) }
    var selectedTrip by remember { mutableStateOf<RouteTrip?>(null) }
    var showDatePicker by remember { mutableStateOf(false) }
    var dateRange by remember { mutableStateOf("Bug\u00fcn") }
    var isPlaying by remember { mutableStateOf(false) }

    val trips = remember {
        listOf(
            RouteTrip(
                "trip1", "Bugün", "10:15", "10:19",
                "Çanakkale Merkez", "Çanakkale Sahil",
                "0.14 km", "4dk 43sn", "12 km/h", "2 km/h", "0.1 L",
                listOf(
                    RoutePoint(40.13416, 26.41174, 0, "10:15"),
                    RoutePoint(40.13422, 26.41163, 3, "10:15"),
                    RoutePoint(40.13430, 26.41152, 7, "10:16"),
                    RoutePoint(40.13437, 26.41144, 8, "10:16"),
                    RoutePoint(40.13444, 26.41136, 10, "10:17"),
                    RoutePoint(40.13455, 26.41120, 8, "10:17"),
                    RoutePoint(40.13462, 26.41108, 3, "10:18"),
                    RoutePoint(40.13464, 26.41104, 0, "10:19"),
                )
            ),
            RouteTrip(
                "trip2", "Bugün", "10:25", "10:31",
                "Çanakkale Sahil", "Çanakkale Liman",
                "1.04 km", "5dk 58sn", "36 km/h", "11 km/h", "0.2 L",
                listOf(
                    RoutePoint(40.13464, 26.41104, 0, "10:25"),
                    RoutePoint(40.13510, 26.41020, 22, "10:26"),
                    RoutePoint(40.13560, 26.40960, 30, "10:26"),
                    RoutePoint(40.13610, 26.40900, 36, "10:27"),
                    RoutePoint(40.13660, 26.40850, 28, "10:27"),
                    RoutePoint(40.13720, 26.40800, 20, "10:28"),
                    RoutePoint(40.13770, 26.40760, 15, "10:28"),
                    RoutePoint(40.13810, 26.40730, 10, "10:29"),
                    RoutePoint(40.13840, 26.40710, 5, "10:30"),
                    RoutePoint(40.13855, 26.40700, 0, "10:31"),
                )
            ),
            RouteTrip(
                "trip3", "Bugün", "11:00", "11:05",
                "Çanakkale Liman", "Çanakkale İskele Cd.",
                "1.43 km", "4dk 55sn", "42 km/h", "17 km/h", "0.3 L",
                listOf(
                    RoutePoint(40.13855, 26.40700, 0, "11:00"),
                    RoutePoint(40.13920, 26.40560, 28, "11:01"),
                    RoutePoint(40.13970, 26.40480, 38, "11:01"),
                    RoutePoint(40.14030, 26.40400, 42, "11:02"),
                    RoutePoint(40.14090, 26.40330, 35, "11:02"),
                    RoutePoint(40.14140, 26.40270, 25, "11:03"),
                    RoutePoint(40.14180, 26.40220, 18, "11:03"),
                    RoutePoint(40.14210, 26.40180, 10, "11:04"),
                    RoutePoint(40.14240, 26.40140, 0, "11:05"),
                )
            ),
            RouteTrip(
                "trip4", "Bugün", "11:30", "11:38",
                "Çanakkale İskele Cd.", "Çanakkale Kordon",
                "1.32 km", "7dk 33sn", "38 km/h", "11 km/h", "0.2 L",
                listOf(
                    RoutePoint(40.14240, 26.40140, 0, "11:30"),
                    RoutePoint(40.14290, 26.40050, 18, "11:31"),
                    RoutePoint(40.14330, 26.39990, 28, "11:32"),
                    RoutePoint(40.14380, 26.39930, 38, "11:33"),
                    RoutePoint(40.14420, 26.39880, 30, "11:34"),
                    RoutePoint(40.14460, 26.39840, 22, "11:35"),
                    RoutePoint(40.14490, 26.39810, 15, "11:36"),
                    RoutePoint(40.14520, 26.39780, 0, "11:38"),
                )
            )
        )
    }

    LaunchedEffect(vehicles) {
        if (vehicles.isNotEmpty() && selectedVehicle == null) {
            selectedVehicle = vehicles.first()
        }
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
                                .clickable { dateRange = label; showDatePicker = false }
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
