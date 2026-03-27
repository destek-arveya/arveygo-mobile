package com.arveya.arveygo.ui.screens.livemap

import android.content.Intent
import android.net.Uri
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.graphics.drawable.BitmapDrawable
import android.view.animation.AccelerateDecelerateInterpolator
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.models.Vehicle
import com.arveya.arveygo.models.VehicleStatus
import com.arveya.arveygo.services.WSConnectionStatus
import com.arveya.arveygo.ui.components.AvatarCircle
import com.arveya.arveygo.ui.components.StatusBadge
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.viewmodels.LiveMapViewModel
import androidx.compose.ui.graphics.vector.ImageVector
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline

// Animated Marker Wrapper - smoothly animates marker position
private class AnimatedMarker(
    private val mapView: MapView,
    val marker: Marker
) {
    private var animator: ValueAnimator? = null

    fun animateTo(target: GeoPoint) {
        val start = marker.position ?: target
        if (start.latitude == 0.0 && start.longitude == 0.0) {
            marker.position = target
            mapView.invalidate()
            return
        }
        if (start.latitude == target.latitude && start.longitude == target.longitude) return

        animator?.cancel()
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1000
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener { anim ->
                val t = anim.animatedFraction.toDouble()
                val lat = start.latitude + (target.latitude - start.latitude) * t
                val lng = start.longitude + (target.longitude - start.longitude) * t
                marker.position = GeoPoint(lat, lng)
                mapView.invalidate()
            }
            start()
        }
    }

    fun destroy() {
        animator?.cancel()
    }
}

// Vehicle Pin Bitmap Creator
private fun createVehiclePinBitmap(
    context: Context,
    statusColor: Int,
    direction: Float,
    plate: String,
    speed: String,
    isSelected: Boolean,
    isMotorcycle: Boolean = false
): Bitmap {
    val density = context.resources.displayMetrics.density
    val baseSize = if (isSelected) 52 else 42
    val pinPx = (baseSize * density).toInt()
    val plateH = if (plate.isNotEmpty()) (18 * density).toInt() else 0
    val speedH = if (speed.isNotEmpty()) (16 * density).toInt() else 0
    val totalH = pinPx + plateH + speedH + (6 * density).toInt()
    val totalW = maxOf(pinPx, (plate.length * 7 * density).toInt() + (16 * density).toInt())
    val bitmap = Bitmap.createBitmap(maxOf(totalW, pinPx), totalH, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)

    val cx = bitmap.width / 2f
    val cy = pinPx / 2f
    val radius = pinPx / 2f - 2 * density

    // Shadow
    val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.argb(50, 0, 0, 0)
        maskFilter = BlurMaskFilter(4 * density, BlurMaskFilter.Blur.NORMAL)
    }
    canvas.drawCircle(cx, cy + 2 * density, radius, shadowPaint)

    // Background circle
    val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = statusColor
        style = Paint.Style.FILL
    }
    canvas.drawCircle(cx, cy, radius, bgPaint)

    // White border
    val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 2.5f * density
    }
    canvas.drawCircle(cx, cy, radius, borderPaint)

    // Direction arrow or motorcycle icon
    val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.WHITE
        style = Paint.Style.FILL
    }
    canvas.save()
    canvas.rotate(direction, cx, cy)
    if (isMotorcycle) {
        // Draw motorcycle icon (simplified two-wheel shape)
        val mPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 2f * density
            strokeCap = Paint.Cap.ROUND
        }
        val r = radius * 0.28f
        // Front wheel
        canvas.drawCircle(cx, cy - radius * 0.25f, r, mPaint)
        // Rear wheel
        canvas.drawCircle(cx, cy + radius * 0.25f, r, mPaint)
        // Body line connecting wheels
        canvas.drawLine(cx, cy - radius * 0.25f + r, cx, cy + radius * 0.25f - r, mPaint)
        // Handlebar
        canvas.drawLine(cx - radius * 0.25f, cy - radius * 0.18f, cx + radius * 0.25f, cy - radius * 0.18f, mPaint)
    } else {
        val arrowPath = Path().apply {
            moveTo(cx, cy - radius * 0.5f)
            lineTo(cx - radius * 0.3f, cy + radius * 0.3f)
            lineTo(cx, cy + radius * 0.1f)
            lineTo(cx + radius * 0.3f, cy + radius * 0.3f)
            close()
        }
        canvas.drawPath(arrowPath, iconPaint)
    }
    canvas.restore()

    // Plate label (always shown)
    if (plate.isNotEmpty()) {
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.WHITE
            textSize = 9f * density
            typeface = Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }
        val bgRect = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.argb(230, 26, 35, 80) // Navy
        }
        val textWidth = textPaint.measureText(plate)
        val padH = 5 * density
        val padV = 2.5f * density
        val textY = pinPx + 12f * density
        val rectF = RectF(
            cx - textWidth / 2 - padH,
            textY - textPaint.textSize - padV,
            cx + textWidth / 2 + padH,
            textY + padV
        )
        canvas.drawRoundRect(rectF, 3f * density, 3f * density, bgRect)
        canvas.drawText(plate, cx, textY, textPaint)
    }

    // Speed label below plate
    if (speed.isNotEmpty()) {
        val speedTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.argb(220, 26, 35, 80) // Navy
            textSize = 8f * density
            typeface = Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }
        val speedBg = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.argb(230, 255, 255, 255)
        }
        val speedW = speedTextPaint.measureText(speed)
        val sPadH = 4 * density
        val sPadV = 2 * density
        val speedY = pinPx + plateH + 10f * density
        val sRectF = RectF(
            cx - speedW / 2 - sPadH,
            speedY - speedTextPaint.textSize - sPadV,
            cx + speedW / 2 + sPadH,
            speedY + sPadV
        )
        canvas.drawRoundRect(sRectF, 3f * density, 3f * density, speedBg)
        canvas.drawText(speed, cx, speedY, speedTextPaint)
    }

    return bitmap
}

// Main Screen
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LiveMapScreen(
    onMenuClick: () -> Unit,
    onNavigateToRouteHistory: ((Vehicle) -> Unit)? = null,
    onNavigateToAlarms: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val authVM = LocalAuthViewModel.current
    val user by authVM.currentUser.collectAsState()
    val vm: LiveMapViewModel = viewModel()
    val vehicles by vm.vehicles.collectAsState()
    val vehicleVersion by vm.vehicleVersion.collectAsState()
    val statusFilter by vm.statusFilter.collectAsState()
    val wsStatus by vm.wsStatus.collectAsState()
    var selectedVehicle by remember { mutableStateOf<Vehicle?>(null) }
    var detailVehicle by remember { mutableStateOf<Vehicle?>(null) }
    var trackingVehicleId by remember { mutableStateOf<String?>(null) }

    // Trail history: keep last 20 positions per vehicle (persists through idle/rölanti)
    val trailHistory = remember { mutableMapOf<String, MutableList<GeoPoint>>() }
    val trailPolylines = remember { mutableMapOf<String, Polyline>() }

    // If detail vehicle is set, show VehicleDetailScreen
    detailVehicle?.let { vehicle ->
        com.arveya.arveygo.ui.screens.fleet.VehicleDetailScreen(
            vehicle = vehicle,
            onBack = { detailVehicle = null },
            onNavigateToRouteHistory = { v ->
                detailVehicle = null
                onNavigateToRouteHistory?.invoke(v)
            },
            onNavigateToAlarms = {
                detailVehicle = null
                onNavigateToAlarms?.invoke()
            }
        )
        return
    }

    LaunchedEffect(Unit) {
        authVM.connectWebSocket()
    }

    val filteredVehicles = vm.filteredVehicles()

    // osmdroid configuration
    LaunchedEffect(Unit) {
        Configuration.getInstance().apply {
            userAgentValue = context.packageName
        }
    }

    // MapView reference & animated markers map
    val mapViewRef = remember { mutableStateOf<MapView?>(null) }
    val animatedMarkers = remember { mutableMapOf<String, AnimatedMarker>() }

    // Geofences: fetch and draw on map
    var geofences by remember { mutableStateOf<List<com.arveya.arveygo.models.Geofence>>(emptyList()) }
    LaunchedEffect(Unit) {
        try {
            geofences = com.arveya.arveygo.services.APIService.fetchGeofences()
        } catch (e: Exception) {
            android.util.Log.e("LiveMap", "Geofence fetch error", e)
        }
    }
    LaunchedEffect(geofences, mapViewRef.value) {
        val mv = mapViewRef.value ?: return@LaunchedEffect
        mv.overlays.removeAll { it is org.osmdroid.views.overlay.Polygon }
        for (g in geofences) {
            val color = g.composeColor
            val argbColor = color.toArgb()
            val fillColor = color.copy(alpha = 0.15f).toArgb()
            if (g.isCircle && g.centerLat != null && g.centerLng != null && g.radius != null) {
                val circle = org.osmdroid.views.overlay.Polygon(mv)
                circle.points = org.osmdroid.views.overlay.Polygon.pointsAsCircle(
                    GeoPoint(g.centerLat, g.centerLng), g.radius
                )
                circle.fillPaint.color = fillColor
                circle.outlinePaint.color = argbColor
                circle.outlinePaint.strokeWidth = 2f
                circle.title = g.name
                mv.overlays.add(0, circle)
            } else if (g.points.isNotEmpty()) {
                val polygon = org.osmdroid.views.overlay.Polygon(mv)
                val pts = g.points.map { GeoPoint(it.lat, it.lng) }.toMutableList()
                if (pts.isNotEmpty() && pts.first() != pts.last()) pts.add(pts.first())
                polygon.points = pts
                polygon.fillPaint.color = fillColor
                polygon.outlinePaint.color = argbColor
                polygon.outlinePaint.strokeWidth = 2f
                polygon.title = g.name
                mv.overlays.add(0, polygon)
            }
        }
        mv.invalidate()
    }

    // Update markers when vehicle data changes (SMOOTH animation)
    LaunchedEffect(vehicleVersion, selectedVehicle, statusFilter) {
        val mapView = mapViewRef.value ?: return@LaunchedEffect
        val currentIds = filteredVehicles.map { it.id }.toSet()

        // Remove markers for vehicles no longer visible
        val toRemove = animatedMarkers.keys.filter { it !in currentIds }
        toRemove.forEach { id ->
            animatedMarkers[id]?.let { am ->
                am.destroy()
                mapView.overlays.remove(am.marker)
            }
            animatedMarkers.remove(id)
        }

        // Add or update markers
        filteredVehicles.forEach { vehicle ->
            val target = GeoPoint(vehicle.lat, vehicle.lng)
            val isSel = selectedVehicle?.id == vehicle.id
            val statusColor = when (vehicle.status) {
                VehicleStatus.ONLINE -> AppColors.Online.toArgb()
                VehicleStatus.OFFLINE -> AppColors.Offline.toArgb()
                VehicleStatus.IDLE -> AppColors.Idle.toArgb()
            }

            val existing = animatedMarkers[vehicle.id]
            if (existing != null) {
                val bmp = createVehiclePinBitmap(context, statusColor, vehicle.direction.toFloat(), vehicle.plate, vehicle.formattedSpeed, isSel, vehicle.isMotorcycle)
                existing.marker.icon = BitmapDrawable(context.resources, bmp)
                existing.marker.title = vehicle.plate
                existing.marker.snippet = "${vehicle.formattedSpeed} \u00b7 ${vehicle.status.label}"
                existing.marker.infoWindow = null
                // SMOOTH ANIMATE to new position
                existing.animateTo(target)
            } else {
                val marker = Marker(mapView).apply {
                    position = target
                    title = vehicle.plate
                    snippet = "${vehicle.formattedSpeed} \u00b7 ${vehicle.status.label}"
                    val bmp = createVehiclePinBitmap(context, statusColor, vehicle.direction.toFloat(), vehicle.plate, vehicle.formattedSpeed, isSel, vehicle.isMotorcycle)
                    icon = BitmapDrawable(context.resources, bmp)
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                    // Disable osmdroid's built-in info window to prevent double popup
                    infoWindow = null
                    setOnMarkerClickListener { _, _ ->
                        selectedVehicle = vehicle
                        true
                    }
                }
                mapView.overlays.add(marker)
                animatedMarkers[vehicle.id] = AnimatedMarker(mapView, marker)
            }
        }
        mapView.invalidate()

        // Update trail polylines for moving vehicles
        filteredVehicles.forEach { vehicle ->
            val pos = GeoPoint(vehicle.lat, vehicle.lng)
            if (vehicle.lat == 0.0 && vehicle.lng == 0.0) return@forEach
            val history = trailHistory.getOrPut(vehicle.id) { mutableListOf() }
            // Only add if position changed
            if (history.isEmpty() || history.last().latitude != pos.latitude || history.last().longitude != pos.longitude) {
                history.add(pos)
                if (history.size > 20) history.removeAt(0)
            }
            // Draw polyline if vehicle is online/idle and has 2+ points (keep trail during rölanti)
            if ((vehicle.status == VehicleStatus.ONLINE || vehicle.status == VehicleStatus.IDLE) && history.size >= 2) {
                val existing = trailPolylines[vehicle.id]
                if (existing != null) {
                    existing.setPoints(history.toList())
                } else {
                    val polyline = Polyline().apply {
                        setPoints(history.toList())
                        outlinePaint.color = vehicle.status.color.copy(alpha = 0.6f).toArgb()
                        outlinePaint.strokeWidth = 4f * context.resources.displayMetrics.density
                        outlinePaint.strokeCap = Paint.Cap.ROUND
                        outlinePaint.strokeJoin = Paint.Join.ROUND
                        outlinePaint.isAntiAlias = true
                    }
                    // Insert polylines below markers
                    val markerIndex = mapView.overlays.indexOfFirst { it is Marker }
                    if (markerIndex >= 0) {
                        mapView.overlays.add(markerIndex, polyline)
                    } else {
                        mapView.overlays.add(polyline)
                    }
                    trailPolylines[vehicle.id] = polyline
                }
            }
        }
        // Remove trails for vehicles no longer visible
        val currentTrailIds = filteredVehicles.map { it.id }.toSet()
        trailPolylines.keys.toList().forEach { id ->
            if (id !in currentTrailIds) {
                trailPolylines[id]?.let { mapView.overlays.remove(it) }
                trailPolylines.remove(id)
                trailHistory.remove(id)
            }
        }
        mapView.invalidate()

        // If tracking a vehicle, keep centering on it
        trackingVehicleId?.let { trackId ->
            filteredVehicles.find { it.id == trackId }?.let { trackedVehicle ->
                mapView.controller?.animateTo(GeoPoint(trackedVehicle.lat, trackedVehicle.lng), 16.0, 600L)
            }
        }
    }

    // Fit bounds on first load
    var hasFittedBounds by remember { mutableStateOf(false) }
    LaunchedEffect(filteredVehicles.size) {
        if (filteredVehicles.size > 1 && !hasFittedBounds) {
            val mapView = mapViewRef.value ?: return@LaunchedEffect
            try {
                val north = filteredVehicles.maxOf { it.lat }
                val south = filteredVehicles.minOf { it.lat }
                val east = filteredVehicles.maxOf { it.lng }
                val west = filteredVehicles.minOf { it.lng }
                val box = BoundingBox(north + 0.5, east + 0.5, south - 0.5, west - 0.5)
                mapView.zoomToBoundingBox(box, true, 80)
                hasFittedBounds = true
            } catch (_: Exception) {}
        }
    }

    // Cleanup
    DisposableEffect(Unit) {
        onDispose {
            animatedMarkers.values.forEach { it.destroy() }
            animatedMarkers.clear()
            trailPolylines.clear()
            trailHistory.clear()
            mapViewRef.value?.onDetach()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = {
                        selectedVehicle = null
                        onMenuClick()
                    }) {
                        Icon(Icons.Default.Menu, null, tint = AppColors.Navy)
                    }
                },
                title = {
                    Column {
                        Text("Canl\u0131 Harita", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        Text("Ara\u00e7 Takip / Canl\u0131 Harita", fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                },
                actions = {
                    WSStatusChip(wsStatus)
                    Spacer(Modifier.width(8.dp))
                    AvatarCircle(initials = user?.avatar ?: "A", size = 30.dp)
                    Spacer(Modifier.width(12.dp))
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = AppColors.Surface)
            )
        }
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {

            // osmdroid MapView (OpenStreetMap - FREE)
            AndroidView(
                factory = { ctx ->
                    MapView(ctx).apply {
                        setTileSource(TileSourceFactory.MAPNIK)
                        setMultiTouchControls(true)
                        controller.setZoom(6.0)
                        controller.setCenter(GeoPoint(39.0, 35.0))
                        zoomController.setVisibility(
                            org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER
                        )
                        mapViewRef.value = this
                    }
                },
                modifier = Modifier.fillMaxSize()
            )

            // Status filter chips
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                StatusFilterChip("T\u00fcm\u00fc (${vehicles.size})", null, statusFilter) { vm.setFilter(null) }
                StatusFilterChip("Aktif (${vm.onlineCount})", VehicleStatus.ONLINE, statusFilter) { vm.setFilter(VehicleStatus.ONLINE) }
                StatusFilterChip("\u00c7evrimd\u0131\u015f\u0131 (${vm.offlineCount})", VehicleStatus.OFFLINE, statusFilter) { vm.setFilter(VehicleStatus.OFFLINE) }
                StatusFilterChip("R\u00f6lanti (${vm.idleCount})", VehicleStatus.IDLE, statusFilter) { vm.setFilter(VehicleStatus.IDLE) }
            }

            // Zoom controls
            Column(
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(end = 12.dp)
            ) {
                FloatingActionButton(
                    onClick = { mapViewRef.value?.controller?.zoomIn() },
                    containerColor = AppColors.Surface,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(Icons.Default.Add, null, tint = AppColors.Navy, modifier = Modifier.size(16.dp))
                }
                Spacer(Modifier.height(4.dp))
                FloatingActionButton(
                    onClick = { mapViewRef.value?.controller?.zoomOut() },
                    containerColor = AppColors.Surface,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(Icons.Default.Remove, null, tint = AppColors.Navy, modifier = Modifier.size(16.dp))
                }
            }

            // Bottom controls
            Column(modifier = Modifier.align(Alignment.BottomCenter)) {
                // Live tracking badge (wide, readable)
                AnimatedVisibility(
                    visible = trackingVehicleId != null,
                    enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
                    exit = slideOutVertically(targetOffsetY = { it }) + fadeOut()
                ) {
                    val trackedPlate = vehicles.firstOrNull { it.id == trackingVehicleId }?.plate ?: ""
                    Surface(
                        onClick = { trackingVehicleId = null },
                        shape = RoundedCornerShape(14.dp),
                        color = AppColors.Online,
                        shadowElevation = 8.dp,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 4.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
                        ) {
                            // Pulsing red dot
                            Box(
                                modifier = Modifier
                                    .size(10.dp)
                                    .background(Color.Red, CircleShape)
                            )
                            Spacer(Modifier.width(10.dp))
                            Icon(
                                Icons.Default.MyLocation, null,
                                tint = Color.White,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(Modifier.width(10.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    "Canlı İzleme Aktif",
                                    color = Color.White,
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                if (trackedPlate.isNotEmpty()) {
                                    Text(
                                        trackedPlate,
                                        color = Color.White.copy(alpha = 0.9f),
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Medium
                                    )
                                }
                            }
                            Icon(
                                Icons.Default.Close, null,
                                tint = Color.White.copy(alpha = 0.8f),
                                modifier = Modifier.size(22.dp)
                            )
                        }
                    }
                }

                Row(
                    horizontalArrangement = Arrangement.End,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp)
                ) {
                }

                // Selected vehicle popup
                selectedVehicle?.let { sel ->
                    // Look up latest vehicle data for real-time updates
                    val liveVehicle = vehicles.firstOrNull { it.id == sel.id } ?: sel
                    VehiclePopupCard(
                        vehicle = liveVehicle,
                        onClose = { selectedVehicle = null },
                        onZoomTo = {
                            selectedVehicle = null
                            mapViewRef.value?.controller?.animateTo(GeoPoint(liveVehicle.lat, liveVehicle.lng), 16.0, 600L)
                        },
                        onLiveTrack = {
                            trackingVehicleId = liveVehicle.id
                            selectedVehicle = null
                            mapViewRef.value?.controller?.animateTo(GeoPoint(liveVehicle.lat, liveVehicle.lng), 16.0, 600L)
                        },
                        onDetail = {
                            val vehicleToOpen = liveVehicle
                            selectedVehicle = null
                            detailVehicle = vehicleToOpen
                        },
                        onNavigateToRouteHistory = { v ->
                            selectedVehicle = null
                            onNavigateToRouteHistory?.invoke(v)
                        },
                        onNavigateToAlarms = {
                            selectedVehicle = null
                            onNavigateToAlarms?.invoke()
                        }
                    )
                }
            }
        }
    }
}

// WS Status Chip
@Composable
private fun WSStatusChip(status: WSConnectionStatus) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .background(status.color.copy(alpha = 0.1f), RoundedCornerShape(20.dp))
            .border(1.dp, status.color.copy(alpha = 0.3f), RoundedCornerShape(20.dp))
            .padding(horizontal = 10.dp, vertical = 5.dp)
    ) {
        Box(Modifier.size(6.dp).clip(CircleShape).background(status.color))
        Spacer(Modifier.width(6.dp))
        Text(status.label, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, color = status.color)
    }
}

// Status filter chip
@Composable
private fun StatusFilterChip(
    label: String,
    status: VehicleStatus?,
    activeFilter: VehicleStatus?,
    onClick: () -> Unit
) {
    val isActive = activeFilter == status
    val color = status?.color ?: AppColors.Navy
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(if (isActive) color.copy(alpha = 0.15f) else AppColors.Surface.copy(alpha = 0.9f))
            .border(1.dp, if (isActive) color else AppColors.BorderSoft, RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 5.dp)
    ) {
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, color = if (isActive) color else AppColors.TextSecondary)
    }
}

// Open Maps Directions Helper
private fun openMapsDirectionsLiveMap(context: Context, lat: Double, lng: Double, label: String) {
    try {
        val gmmIntentUri = Uri.parse("google.navigation:q=$lat,$lng&mode=d")
        val mapIntent = Intent(Intent.ACTION_VIEW, gmmIntentUri).apply {
            setPackage("com.google.android.apps.maps")
        }
        if (mapIntent.resolveActivity(context.packageManager) != null) {
            context.startActivity(mapIntent)
        } else {
            val genericUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng($label)")
            context.startActivity(Intent(Intent.ACTION_VIEW, genericUri))
        }
    } catch (e: Exception) {
        val browserUri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng")
        context.startActivity(Intent(Intent.ACTION_VIEW, browserUri))
    }
}

// Vehicle Popup Sheet (redesigned to match VehicleDetailScreen identity card)
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun VehiclePopupCard(
    vehicle: Vehicle,
    onClose: () -> Unit,
    onZoomTo: () -> Unit,
    onLiveTrack: () -> Unit,
    onDetail: () -> Unit,
    onNavigateToRouteHistory: ((Vehicle) -> Unit)? = null,
    onNavigateToAlarms: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = sheetState,
        containerColor = AppColors.Surface,
        shape = RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp),
        dragHandle = {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Spacer(Modifier.height(8.dp))
                Box(
                    Modifier
                        .width(36.dp)
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(AppColors.BorderSoft)
                )
                Spacer(Modifier.height(8.dp))
            }
        }
    ) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(top = 4.dp)
    ) {
        // Identity Card (matching detail page)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .background(AppColors.Surface, RoundedCornerShape(14.dp))
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(48.dp)
                        .background(vehicle.status.color.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
                ) {
                    Icon(Icons.Default.DirectionsCar, null, tint = vehicle.status.color, modifier = Modifier.size(22.dp))
                }
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(vehicle.plate, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                        Spacer(Modifier.width(8.dp))
                        StatusBadge(vehicle.status)
                    }
                    Text(vehicle.model, fontSize = 11.sp, color = AppColors.TextMuted)
                    Spacer(Modifier.height(4.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        // Group tag
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .background(Color.Blue.copy(alpha = 0.08f), RoundedCornerShape(20.dp))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        ) {
                            Icon(Icons.Default.Folder, null, tint = Color.Blue, modifier = Modifier.size(8.dp))
                            Spacer(Modifier.width(3.dp))
                            Text(vehicle.group, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, color = Color.Blue)
                        }
                        // Type tag
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .background(Color(0xFF9C27B0).copy(alpha = 0.08f), RoundedCornerShape(20.dp))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        ) {
                            Icon(Icons.Default.DirectionsCar, null, tint = Color(0xFF9C27B0), modifier = Modifier.size(8.dp))
                            Spacer(Modifier.width(3.dp))
                            Text(vehicle.vehicleType, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF9C27B0))
                        }
                    }
                }
            }

            Spacer(Modifier.height(12.dp))
            HorizontalDivider(color = AppColors.BorderSoft)

            // Quick stats row (like detail page)
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                PopupStatItem(Icons.Default.Speed, vehicle.formattedSpeed, "H\u0131z", Color(0xFFFF9800))
                PopupStatItem(Icons.Default.Route, vehicle.formattedTodayKm, "Bug\u00fcn", AppColors.Indigo)
                PopupStatItem(Icons.Default.Person, run {
                    val name = if (vehicle.driverName.isNotEmpty()) vehicle.driverName else vehicle.driver
                    if (name.isEmpty()) "\u2014" else name.split(" ").firstOrNull() ?: "\u2014"
                }, "S\u00fcr\u00fcc\u00fc", AppColors.Online)
                PopupStatItem(Icons.Default.LocationOn, vehicle.city, "Konum", Color.Blue)
            }
        }

        Spacer(Modifier.height(12.dp))

        // Device Time (if available)
        if (vehicle.deviceTime != null) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .background(AppColors.Surface, RoundedCornerShape(10.dp))
                    .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(10.dp))
                    .padding(horizontal = 12.dp, vertical = 10.dp)
            ) {
                Icon(Icons.Default.Schedule, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(8.dp))
                Text("Son Bilgi Tarihi", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                Spacer(Modifier.weight(1f))
                Text(
                    "\u23f1 ${vehicle.formattedDeviceTime}",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.TextMuted,
                    modifier = Modifier
                        .background(AppColors.Bg, RoundedCornerShape(6.dp))
                        .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(6.dp))
                        .padding(horizontal = 8.dp, vertical = 3.dp)
                )
            }
            Spacer(Modifier.height(8.dp))
        }

        // Info grid (compact)
        Column(
            verticalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.padding(horizontal = 16.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                PopupInfoCell(Icons.Default.VpnKey, "Kontak", if (vehicle.kontakOn) "A\u00e7\u0131k" else "Kapal\u0131", if (vehicle.kontakOn) AppColors.Online else AppColors.Offline, Modifier.weight(1f))
                PopupInfoCell(Icons.Default.Speed, "Toplam Km", vehicle.formattedTotalKm + " km", AppColors.Navy, Modifier.weight(1f))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                PopupInfoCell(Icons.Default.CellTower, "Sinyal", if (vehicle.status == VehicleStatus.ONLINE) "G\u00fc\u00e7l\u00fc" else "Yok", if (vehicle.status == VehicleStatus.ONLINE) AppColors.Online else AppColors.TextFaint, Modifier.weight(1f))
                vehicle.temperatureC?.let { temp ->
                    PopupInfoCell(Icons.Default.LocalFireDepartment, "S\u0131cakl\u0131k", "${"%.1f".format(temp)}\u00b0C", if (temp < 0) Color.Blue else if (temp < 30) AppColors.Online else Color.Red, Modifier.weight(1f))
                } ?: Spacer(Modifier.weight(1f))
            }
        }

        Spacer(Modifier.height(12.dp))

        // Quick actions row
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(horizontal = 16.dp)
        ) {
            PopupQuickAction(Icons.Default.LocationOn, "Konuma Git", Color.Blue, Modifier.weight(1f)) {
                openMapsDirectionsLiveMap(context, vehicle.lat, vehicle.lng, vehicle.plate)
            }
            PopupQuickAction(Icons.Default.History, "Rota Ge\u00e7mi\u015fi", AppColors.Indigo, Modifier.weight(1f)) {
                onClose()
                onNavigateToRouteHistory?.invoke(vehicle)
            }
            PopupQuickAction(Icons.Default.Notifications, "Alarm Kur", Color(0xFFFF9800), Modifier.weight(1f)) {
                onClose()
                onNavigateToAlarms?.invoke()
            }
            PopupQuickAction(Icons.Default.Lock, "Blokaj", Color.Red, Modifier.weight(1f)) {}
        }

        Spacer(Modifier.height(12.dp))

        // CANLI İZLE Button
        Button(
            onClick = onLiveTrack,
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(containerColor = AppColors.Online),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .height(44.dp)
        ) {
            Icon(Icons.Default.MyLocation, null, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(8.dp))
            Text("Canl\u0131 \u0130zle", fontSize = 14.sp, fontWeight = FontWeight.Bold)
        }

        Spacer(Modifier.height(8.dp))

        // DETAY GÖR Button
        Button(
            onClick = onDetail,
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(containerColor = AppColors.Navy),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .height(50.dp)
        ) {
            Icon(Icons.Default.OpenInFull, null, modifier = Modifier.size(14.dp))
            Spacer(Modifier.width(8.dp))
            Text("Detay G\u00f6r", fontSize = 15.sp, fontWeight = FontWeight.Bold)
        }

        Spacer(Modifier.height(16.dp))
    }
    } // ModalBottomSheet
}

@Composable
private fun PopupStatItem(icon: ImageVector, value: String, label: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(icon, null, tint = color, modifier = Modifier.size(13.dp))
        Spacer(Modifier.height(2.dp))
        Text(value, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(label, fontSize = 8.sp, color = AppColors.TextMuted)
    }
}

@Composable
private fun PopupInfoCell(
    icon: ImageVector,
    label: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .background(AppColors.Bg, RoundedCornerShape(10.dp))
            .padding(12.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(32.dp)
                .background(color.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(14.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f, fill = false)) {
            Text(label, fontSize = 9.sp, fontWeight = FontWeight.Bold, color = AppColors.TextFaint, letterSpacing = 0.3.sp)
            Text(value, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

@Composable
private fun PopupQuickAction(
    icon: ImageVector,
    label: String,
    color: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier.clickable(onClick = onClick)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(42.dp)
                .background(color.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(16.dp))
        }
        Spacer(Modifier.height(4.dp))
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.Medium, color = AppColors.TextMuted, textAlign = TextAlign.Center, maxLines = 2, lineHeight = 11.sp)
    }
}

// Vehicle list sheet
@Composable
private fun VehicleListSheet(
    vehicles: List<Vehicle>,
    onSelect: (Vehicle) -> Unit,
    onClose: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .fillMaxHeight(0.35f)
            .background(AppColors.Surface, RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp))
            .padding(top = 8.dp)
    ) {
        Box(
            Modifier
                .width(36.dp)
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(AppColors.BorderSoft)
                .align(Alignment.CenterHorizontally)
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text("Ara\u00e7lar", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Spacer(Modifier.width(6.dp))
            Text(
                "${vehicles.size}",
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.TextMuted,
                modifier = Modifier
                    .background(AppColors.Bg, RoundedCornerShape(20.dp))
                    .padding(horizontal = 8.dp, vertical = 2.dp)
            )
            Spacer(Modifier.weight(1f))
            IconButton(onClick = onClose, modifier = Modifier.size(28.dp)) {
                Icon(Icons.Default.Close, null, tint = AppColors.TextMuted, modifier = Modifier.size(16.dp))
            }
        }
        HorizontalDivider(color = AppColors.BorderSoft)
        LazyColumn(modifier = Modifier.fillMaxSize()) {
            items(vehicles) { v ->
                VehicleListRow(v) { onSelect(v) }
            }
        }
    }
}

@Composable
private fun VehicleListRow(vehicle: Vehicle, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        Box(
            Modifier
                .width(3.dp)
                .height(34.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(vehicle.status.color)
        )
        Spacer(Modifier.width(10.dp))
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(32.dp)
                .background(vehicle.status.color.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
        ) {
            Icon(Icons.Default.DirectionsCar, null, tint = vehicle.status.color, modifier = Modifier.size(14.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(vehicle.plate, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Text(vehicle.model, fontSize = 10.sp, color = AppColors.TextMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(vehicle.formattedSpeed, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            StatusBadge(vehicle.status)
        }
    }
    HorizontalDivider(
        modifier = Modifier.padding(start = 60.dp),
        color = AppColors.BorderSoft.copy(alpha = 0.5f)
    )
}

// (VehiclePopupCard and related components are defined above VehicleListSheet)
