package com.arveya.arveygo.ui.screens.fleet

import android.content.Context
import android.graphics.Paint
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
import com.arveya.arveygo.models.Geofence
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.launch
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Polygon

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GeofencesScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val colors = MaterialTheme.colorScheme

    var geofences by remember { mutableStateOf<List<Geofence>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var selectedGeofence by remember { mutableStateOf<Geofence?>(null) }
    var mapView by remember { mutableStateOf<MapView?>(null) }

    // Initialize map config
    LaunchedEffect(Unit) {
        Configuration.getInstance().userAgentValue = context.packageName
    }

    // Fetch geofences
    LaunchedEffect(Unit) {
        isLoading = true
        try {
            geofences = APIService.fetchGeofences()
        } catch (e: Exception) {
            android.util.Log.e("Geofences", "Error fetching geofences", e)
        }
        isLoading = false
    }

    // Draw overlays when geofences change
    LaunchedEffect(geofences, mapView) {
        val mv = mapView ?: return@LaunchedEffect
        drawGeofenceOverlays(mv, geofences)
        if (geofences.isNotEmpty()) {
            fitMapToGeofences(mv, geofences)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            "Geofence",
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = colors.onSurface
                        )
                        Text(
                            "Bölge Takibi",
                            fontSize = 10.sp,
                            color = colors.onSurface.copy(alpha = 0.55f)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.background)
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Map
            AndroidView(
                factory = { ctx ->
                    MapView(ctx).apply {
                        setTileSource(TileSourceFactory.MAPNIK)
                        setMultiTouchControls(true)
                        controller.setZoom(6.0)
                        controller.setCenter(GeoPoint(39.9, 32.8))
                        mapView = this
                    }
                },
                modifier = Modifier.fillMaxSize()
            )

            // Bottom list panel
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = colors.surface),
                    elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
                ) {
                    Column {
                        // Drag indicator
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 8.dp, bottom = 8.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .width(36.dp)
                                    .height(4.dp)
                                    .clip(RoundedCornerShape(2.dp))
                                    .background(colors.onSurface.copy(alpha = 0.2f))
                            )
                        }

                        if (isLoading) {
                            Box(
                                contentAlignment = Alignment.Center,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 30.dp)
                            ) {
                                CircularProgressIndicator(
                                    color = AppColors.Indigo,
                                    modifier = Modifier.size(28.dp)
                                )
                            }
                        } else if (geofences.isEmpty()) {
                            // Empty state
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 30.dp)
                            ) {
                                Icon(
                                    Icons.Default.Hexagon, null,
                                    tint = AppColors.TextFaint,
                                    modifier = Modifier.size(32.dp)
                                )
                                Spacer(Modifier.height(8.dp))
                                Text(
                                    "Henüz bölge tanımlanmamış",
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = colors.onSurface.copy(alpha = 0.72f)
                                )
                                Text(
                                    "Bölge eklemek için web panelini kullanın",
                                    fontSize = 11.sp,
                                    color = colors.onSurface.copy(alpha = 0.45f)
                                )
                            }
                        } else {
                            // Header
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                            ) {
                                Icon(
                                    Icons.Default.Hexagon, null,
                                    tint = AppColors.Indigo,
                                    modifier = Modifier.size(14.dp)
                                )
                                Spacer(Modifier.width(6.dp))
                                Text(
                                    "Bölgeler",
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = colors.onSurface
                                )
                                Spacer(Modifier.weight(1f))
                                Text(
                                    "${geofences.size} bölge",
                                    fontSize = 11.sp,
                                    color = colors.onSurface.copy(alpha = 0.55f)
                                )
                            }

                            // List
                            LazyColumn(
                                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.heightIn(max = 250.dp)
                            ) {
                                items(geofences, key = { it.id }) { geofence ->
                                    GeofenceRow(
                                        geofence = geofence,
                                        isSelected = selectedGeofence?.id == geofence.id,
                                        onClick = {
                                            selectedGeofence = geofence
                                            focusGeofence(mapView, geofence)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun GeofenceRow(
    geofence: Geofence,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val color = geofence.composeColor
    val colors = MaterialTheme.colorScheme
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(if (isSelected) color.copy(alpha = 0.10f) else colors.surfaceVariant)
            .then(
                if (isSelected) Modifier.border(1.5.dp, color, RoundedCornerShape(10.dp))
                else Modifier.border(1.dp, colors.outline.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp)
    ) {
        // Color dot
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(color)
        )

        Spacer(Modifier.width(10.dp))

        // Icon
        Icon(
            if (geofence.isCircle) Icons.Default.RadioButtonUnchecked else Icons.Default.Hexagon,
            null,
            tint = color,
            modifier = Modifier.size(18.dp)
        )

        Spacer(Modifier.width(10.dp))

        // Text
        Column(modifier = Modifier.weight(1f)) {
            Text(
                geofence.name,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = colors.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Row {
                Text(
                    if (geofence.isCircle) "Daire" else "Poligon",
                    fontSize = 10.sp,
                    color = colors.onSurface.copy(alpha = 0.6f)
                )
                if (geofence.isCircle && geofence.radius != null) {
                    Text(
                        " · ${geofence.radius.toInt()}m",
                        fontSize = 10.sp,
                        color = colors.onSurface.copy(alpha = 0.6f)
                    )
                }
                if (!geofence.isCircle) {
                    Text(
                        " · ${geofence.points.size} nokta",
                        fontSize = 10.sp,
                        color = colors.onSurface.copy(alpha = 0.6f)
                    )
                }
            }
        }

        Icon(
            Icons.Default.ChevronRight, null,
            tint = colors.onSurface.copy(alpha = 0.4f),
            modifier = Modifier.size(14.dp)
        )
    }
}

// MARK: - Map Helpers

private fun drawGeofenceOverlays(mapView: MapView, geofences: List<Geofence>) {
    // Remove existing geofence overlays
    mapView.overlays.removeAll { it is Polygon }

    for (geofence in geofences) {
        val color = geofence.composeColor
        val argbColor = color.toArgb()
        val fillColor = color.copy(alpha = 0.2f).toArgb()

        if (geofence.isCircle && geofence.centerLat != null && geofence.centerLng != null && geofence.radius != null) {
            // Draw circle as a polygon approximation
            val circle = Polygon(mapView)
            circle.points = Polygon.pointsAsCircle(
                GeoPoint(geofence.centerLat, geofence.centerLng),
                geofence.radius
            )
            circle.fillPaint.color = fillColor
            circle.outlinePaint.color = argbColor
            circle.outlinePaint.strokeWidth = 3f
            circle.title = geofence.name
            mapView.overlays.add(circle)
        } else if (geofence.points.isNotEmpty()) {
            // Draw polygon
            val polygon = Polygon(mapView)
            polygon.points = geofence.points.map { GeoPoint(it.lat, it.lng) }.toMutableList().also {
                // Close the polygon
                if (it.isNotEmpty() && it.first() != it.last()) {
                    it.add(it.first())
                }
            }
            polygon.fillPaint.color = fillColor
            polygon.outlinePaint.color = argbColor
            polygon.outlinePaint.strokeWidth = 3f
            polygon.outlinePaint.style = Paint.Style.STROKE
            polygon.title = geofence.name
            mapView.overlays.add(polygon)

            // Also add the filled version
            val polygonFill = Polygon(mapView)
            polygonFill.points = polygon.points
            polygonFill.fillPaint.color = fillColor
            polygonFill.outlinePaint.color = android.graphics.Color.TRANSPARENT
            polygonFill.title = geofence.name
            mapView.overlays.add(0, polygonFill)
        }
    }
    mapView.invalidate()
}

private fun fitMapToGeofences(mapView: MapView, geofences: List<Geofence>) {
    val allPoints = mutableListOf<GeoPoint>()
    for (g in geofences) {
        if (g.isCircle && g.centerLat != null && g.centerLng != null) {
            allPoints.add(GeoPoint(g.centerLat, g.centerLng))
        }
        for (p in g.points) {
            allPoints.add(GeoPoint(p.lat, p.lng))
        }
    }
    if (allPoints.isEmpty()) return

    val minLat = allPoints.minOf { it.latitude }
    val maxLat = allPoints.maxOf { it.latitude }
    val minLng = allPoints.minOf { it.longitude }
    val maxLng = allPoints.maxOf { it.longitude }

    val center = GeoPoint((minLat + maxLat) / 2, (minLng + maxLng) / 2)
    val latSpan = maxLat - minLat
    val lngSpan = maxLng - minLng
    val maxSpan = maxOf(latSpan, lngSpan, 0.01)

    // Approximate zoom level
    val zoom = when {
        maxSpan > 5 -> 5.0
        maxSpan > 2 -> 7.0
        maxSpan > 1 -> 8.0
        maxSpan > 0.5 -> 9.0
        maxSpan > 0.1 -> 11.0
        maxSpan > 0.01 -> 13.0
        else -> 15.0
    }

    mapView.controller.setCenter(center)
    mapView.controller.setZoom(zoom)
}

private fun focusGeofence(mapView: MapView?, geofence: Geofence) {
    val mv = mapView ?: return
    if (geofence.isCircle && geofence.centerLat != null && geofence.centerLng != null) {
        val radius = geofence.radius ?: 500.0
        val zoom = when {
            radius > 5000 -> 10.0
            radius > 1000 -> 12.0
            radius > 500 -> 14.0
            else -> 16.0
        }
        mv.controller.animateTo(GeoPoint(geofence.centerLat, geofence.centerLng), zoom, 600L)
    } else if (geofence.points.isNotEmpty()) {
        val lats = geofence.points.map { it.lat }
        val lngs = geofence.points.map { it.lng }
        val center = GeoPoint(
            (lats.min() + lats.max()) / 2,
            (lngs.min() + lngs.max()) / 2
        )
        val span = maxOf(lats.max() - lats.min(), lngs.max() - lngs.min(), 0.01)
        val zoom = when {
            span > 1 -> 8.0
            span > 0.5 -> 9.0
            span > 0.1 -> 11.0
            span > 0.01 -> 13.0
            else -> 15.0
        }
        mv.controller.animateTo(center, zoom, 600L)
    }
}
